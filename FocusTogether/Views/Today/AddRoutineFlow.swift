import SwiftUI

/// Adding a routine: pick a kind (Prayer, Habits, Study, Custom). Prayer asks for a tradition;
/// Islam goes on to location-based Salah times. Everything ends in the editor or adds directly.
struct AddRoutineFlow: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Step] = []

    enum Step: Hashable {
        case tradition
        case salahSetup
        case editor(Routine)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ChoiceList(
                title: "What do you want to track?",
                options: RoutineKind.allCases.map { Choice(id: "\($0)", title: $0.title, subtitle: $0.subtitle, symbol: $0.symbol) }
            ) { index in
                switch RoutineKind.allCases[index] {
                case .prayer: path.append(.tradition)
                case .habits: path.append(.editor(RoutineDrafts.habits))
                case .study: path.append(.editor(RoutineDrafts.study))
                case .fitness: path.append(.editor(RoutineDrafts.fitness))
                case .custom: path.append(.editor(RoutineDrafts.custom))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .tradition:
                    ChoiceList(
                        title: "Which tradition?",
                        options: Tradition.allCases.map { Choice(id: "\($0)", title: $0.title, subtitle: $0.subtitle, symbol: nil) }
                    ) { index in
                        switch Tradition.allCases[index] {
                        case .islam: path.append(.salahSetup)
                        case .christian: path.append(.editor(RoutineDrafts.christianPrayer))
                        case .other: path.append(.editor(RoutineDrafts.otherPrayer))
                        }
                    }
                case .salahSetup:
                    SalahSetupView { routine in
                        store.save(routine)
                        dismiss()
                    }
                case .editor(let draft):
                    RoutineEditorView(mode: .create(draft)) { dismiss() }
                }
            }
        }
    }
}

private struct Choice: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String?
}

private struct ChoiceList: View {
    let title: String
    let options: [Choice]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .padding(.bottom, 8)

                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        Haptics.select()
                        onSelect(index)
                    } label: {
                        HStack(spacing: 14) {
                            if let symbol = option.symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 44, height: 44)
                                    .background(Theme.background, in: Circle())
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title).font(.headline)
                                Text(option.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .card(padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.gutter)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
