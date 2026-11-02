import MultipeerConnectivity
import NearbyInteraction
import UIKit

/// "Add nearby": two phones running Lockin find each other over the local network
/// (MultipeerConnectivity), swap invite codes, and — on phones with the U1/U2 chip — use
/// Nearby Interaction to measure distance. Holding them together sends a friend request
/// from both sides at once, so it's accepted immediately.
@MainActor
final class NearbyManager: NSObject, ObservableObject {
    enum Phase: Equatable {
        case searching
        case found(name: String)
        case adding(name: String)
        case done(message: String)
        case failed(message: String)
    }

    @Published private(set) var phase: Phase = .searching
    /// Live distance to the other phone in metres, when Nearby Interaction is available.
    @Published private(set) var distance: Float?

    let supportsDistance = NISession.deviceCapabilities.supportsPreciseDistanceMeasurement

    private static let serviceType = "lockin-near"
    /// Close enough to count as "phones together".
    private static let tapDistance: Float = 0.2

    private let myName: String
    private let myCode: String
    private let onMatch: (String) async -> String?

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    /// Decides which side sends the invitation, so the two phones don't invite each other twice.
    private let nonce = UUID().uuidString

    private var niSession: NISession?
    private var peerCode: String?
    private var lastHapticBand = 0

    /// - Parameter onMatch: sends a friend request to the given invite code; returns a message to show.
    init(name: String, code: String, onMatch: @escaping (String) async -> String?) {
        myName = name
        myCode = code
        self.onMatch = onMatch
        peerID = MCPeerID(displayName: String(name.prefix(60)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["n": nonce], serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        if supportsDistance {
            let ni = NISession()
            ni.delegate = self
            niSession = ni
        }
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        niSession?.invalidate()
        niSession = nil
    }

    /// For phones without distance measurement, or when it isn't available: add with a tap.
    func addFoundPeer() {
        guard case .found = phase else { return }
        match()
    }

    // MARK: Hand-shake

    private struct Hello: Codable {
        let name: String
        let code: String
        let token: Data?
    }

    private func sendHello(to peer: MCPeerID) {
        let token = niSession?.discoveryToken.flatMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
        }
        guard let data = try? JSONEncoder().encode(Hello(name: myName, code: myCode, token: token)) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func receive(_ hello: Hello) {
        guard case .searching = phase else { return }
        peerCode = hello.code
        phase = .found(name: hello.name)
        Haptics.select()

        guard let niSession, let data = hello.token,
              let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
        else { return }
        niSession.run(NINearbyPeerConfiguration(peerToken: token))
    }

    private func update(distance newDistance: Float) {
        distance = newDistance
        guard case .found = phase else { return }

        // A light tap each time you get noticeably closer.
        let band = newDistance < 0.5 ? (newDistance < 0.35 ? 2 : 1) : 0
        if band > lastHapticBand { Haptics.tap() }
        lastHapticBand = band

        if newDistance <= Self.tapDistance { match() }
    }

    private func match() {
        guard case .found(let name) = phase, let code = peerCode else { return }
        phase = .adding(name: name)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            if let message = await onMatch(code) {
                Haptics.success()
                phase = .done(message: message)
            } else {
                phase = .failed(message: "Couldn't add \(name). Try again.")
            }
            niSession?.invalidate()
        }
    }
}

// MARK: - Delegates (called on background queues; hop to the main actor)

extension NearbyManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .connected else { return }
        Task { @MainActor in self.sendHello(to: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let hello = try? JSONDecoder().decode(Hello.self, from: data) else { return }
        Task { @MainActor in self.receive(hello) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension NearbyManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            // Only the side with the smaller nonce invites.
            guard let theirs = info?["n"], self.nonce < theirs else { return }
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension NearbyManager: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let distance = nearbyObjects.first?.distance else { return }
        Task { @MainActor in self.update(distance: distance) }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        // Permission denied or unsupported: the found person can still be added with a tap.
        Task { @MainActor in self.distance = nil }
    }
}
