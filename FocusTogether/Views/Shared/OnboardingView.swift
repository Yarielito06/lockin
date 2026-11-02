import FamilyControls
import SwiftUI

/// Explains why Lockin needs Screen Time access, then requests `.individual` authorization.
struct OnboardingView: View {
    @EnvironmentObject private var blocking: BlockingManager
    @State private var isRequesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 64, height: 64)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Lockin")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Put distractions away and focus — alone or with friends.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 22) {
                reason("app.badge.checkmark", "You choose the apps", "Pick the apps that pull you away.")
                reason("lock", "They pause while you focus", "Blocked until your session ends.")
                reason("eye.slash", "Your choices stay private", "Apple only shares anonymous tokens with us — never your usage.")
            }

            Spacer()

            VStack(spacing: 12) {
                if blocking.authorizationStatus == .denied {
                    Text("Access was denied. You can allow it in Settings › Screen Time, or try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    isRequesting = true
                    Task {
                        await blocking.requestAuthorization()
                        isRequesting = false
                    }
                } label: {
                    if isRequesting {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(.primary)
                .disabled(isRequesting)

                Text("Lockin uses Apple's Screen Time to block apps.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    private func reason(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
