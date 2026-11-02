import FamilyControls
import SwiftUI

/// A compact row showing which apps are blocked; tapping opens Apple's FamilyActivityPicker.
/// The selection is saved to the App Group by `BlockingManager` whenever it changes.
struct AppSelectionView: View {
    @EnvironmentObject private var blocking: BlockingManager
    @State private var isPickerPresented = false

    private var selection: FamilyActivitySelection { blocking.selection }

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "app.badge")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked apps")
                        .font(.subheadline.weight(.semibold))
                    Text(blocking.hasSelection ? summary : "Choose what distracts you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: -6) {
                    ForEach(Array(selection.applicationTokens.prefix(3)), id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .scaleEffect(1.1)
                            .frame(width: 26, height: 26)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .card(padding: 14)
        }
        .buttonStyle(.plain)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $blocking.selection)
    }

    private var summary: String {
        var parts: [String] = []
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        if sites > 0 { parts.append("\(sites) site\(sites == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}
