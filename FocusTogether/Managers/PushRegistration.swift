import Supabase
import UIKit

/// Gets this device's APNs token and saves it to the server, so friends' requests,
/// group invites and group lock-ins can reach you while Lockin is closed.
enum PushRegistration {
    private static let key = "lockin.pushToken"

    static var token: String? { UserDefaults.standard.string(forKey: key) }

    static func didReceive(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: key)
        #if DEBUG
        print("[Push] got device token \(token.prefix(8))…")
        #endif
        Task { await upload() }
    }

    /// Saves the token for the signed-in user. Needs a profile, so it's also called after naming.
    static func upload() async {
        guard let client = Backend.client, let token else { return }
        guard (try? await client.auth.session) != nil else {
            #if DEBUG
            print("[Push] not signed in yet; will upload after sign-in")
            #endif
            return
        }
        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        struct Params: Encodable { let token: String; let sandbox: Bool }
        do {
            try await client.rpc("save_push_token", params: Params(token: token, sandbox: sandbox)).execute()
            #if DEBUG
            print("[Push] token saved")
            #endif
        } catch {
            #if DEBUG
            print("[Push] save failed: \(error)")
            #endif
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must happen after launch; asking from the SwiftUI App initializer is too early.
        if Backend.client != nil { application.registerForRemoteNotifications() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistration.didReceive(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[Push] registration failed: \(error.localizedDescription)")
        #endif
    }
}
