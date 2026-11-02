import ActivityKit
import SwiftUI
import WidgetKit

/// "Locked in" on the lock screen and in the Dynamic Island, counting down to the end time.
struct LockinLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockinActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state, isStale: Self.isStale(context))
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Locked in").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "lock.fill").foregroundStyle(Brand.orange)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(state)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.openEnded != true {
                            ProgressView(timerInterval: state.startDate...state.endDate, countsDown: false) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(Brand.orange)
                        }
                        Text(state.openEnded == true ? "Free time — until you stop" : state.groupName.map { "With \($0)" } ?? "Stay focused — apps are blocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "lock.fill").foregroundStyle(Brand.orange)
            } compactTrailing: {
                countdown(state)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "lock.fill").foregroundStyle(Brand.orange)
            }
            .keylineTint(Brand.orange)
        }
    }

    /// Stale once the end time passes (set when the activity starts); iOS 16.1 has no stale flag.
    private static func isStale(_ context: ActivityViewContext<LockinActivityAttributes>) -> Bool {
        if context.state.openEnded == true { return false }
        if #available(iOS 16.2, *) { return context.isStale }
        return context.state.openEnded != true && context.state.endDate <= .now
    }

    private func countdown(_ state: LockinActivityAttributes.ContentState) -> some View {
        Group {
            if state.openEnded == true {
                Text(state.startDate, style: .timer)
            } else {
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

private struct LockScreenActivityView: View {
    let state: LockinActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isStale ? "checkmark" : "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Brand.orange, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(isStale ? "Session complete" : "Locked in")
                    .font(.headline)
                    .foregroundStyle(.white)
                if isStale {
                    Text("Well done — your apps are unlocked.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    if state.openEnded != true {
                        ProgressView(timerInterval: state.startDate...state.endDate, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(Brand.orange)
                    }
                    Text(state.openEnded == true ? "Free time — until you stop" : (state.groupName.map { "With \($0)" } ?? "Stay focused"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer(minLength: 8)

            if !isStale {
                Group {
                    if state.openEnded == true {
                        Text(state.startDate, style: .timer)
                    } else {
                        Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                    }
                }
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
        }
        .padding(16)
    }
}
