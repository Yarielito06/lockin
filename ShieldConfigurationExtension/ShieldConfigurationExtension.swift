import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customises the screen iOS shows when the user opens a blocked app or website.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        focusShield
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        focusShield
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        focusShield
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        focusShield
    }

    private var focusShield: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "lock.fill")?.withTintColor(.label, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(
                text: "You're locked in — back soon 💪",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is paused until your session ends.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .systemBackground),
            primaryButtonBackgroundColor: .label
        )
    }
}
