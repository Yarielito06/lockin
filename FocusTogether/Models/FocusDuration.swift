import Foundation

/// The session lengths offered on the focus screen.
enum FocusDuration: Int, Identifiable {
    /// DeviceActivity's minimum interval; handy for testing on a device.
    case quickTest = 15
    case pomodoro = 25
    case deep = 50
    case marathon = 90

    static var options: [FocusDuration] {
        #if DEBUG
        [.quickTest, .pomodoro, .deep, .marathon]
        #else
        [.pomodoro, .deep, .marathon]
        #endif
    }

    var id: Int { rawValue }

    var minutes: Int { rawValue }

    var title: String {
        switch self {
        case .quickTest: "Test"
        case .pomodoro: "Pomodoro"
        case .deep: "Deep work"
        case .marathon: "Marathon"
        }
    }
}
