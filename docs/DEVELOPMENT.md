# Development notes (Screen Time setup and device testing)

A SwiftUI proof of concept (iOS 16+) for solo app-blocking focus sessions, built on Apple's Screen Time APIs
(FamilyControls, ManagedSettings, DeviceActivity).

## Project layout

| Path | Target(s) | What it is |
|---|---|---|
| `FocusTogether/FocusTogetherApp.swift` | App | Entry point; creates the `BlockingManager` |
| `FocusTogether/Managers/BlockingManager.swift` | App | Authorization, selection, start / finish / give up, DeviceActivity scheduling |
| `FocusTogether/Models/FocusDuration.swift` | App | 25 / 50 / 90 min options (plus 15 min in Debug builds) |
| `FocusTogether/Views/` | App | `RootView` (routing), `OnboardingView`, `AppSelectionView` (FamilyActivityPicker), `FocusSetupView`, `CountdownView`, `CelebrationView`, `ConfettiView` |
| `Shared/` | App + Monitor | `AppGroup`, `FocusSession` model, `SharedStore` (App Group UserDefaults), `ShieldController` (named ManagedSettingsStore), `DeviceActivityName.focusSession` |
| `DeviceActivityMonitorExtension/` | Monitor | Clears shields in `intervalDidEnd`, even if the app was killed |
| `ShieldConfigurationExtension/` | Shield | The custom "You're in a focus session — back soon 💪" shield |
| `Config/` | — | `Signing.xcconfig`, three Info.plists and three entitlements files |

The folders are Xcode 16+ synchronized groups: any `.swift` file you add to a folder is picked up by that
folder's targets automatically.

### How a session works

1. **Start**: `BlockingManager.startSession` schedules a one-off `DeviceActivitySchedule` from now until the end
   time, then applies shields to the named `ManagedSettingsStore` and saves the `FocusSession` to the App Group.
2. **While it runs**: the app shows a countdown. Shields stay up whether the app is open, in the background or killed.
3. **End**: iOS wakes the monitor extension at the end time (`intervalDidEnd`) and it clears the shields.
   If the app is open it also clears them itself when the countdown reaches zero (both are safe to run).
   The next time the app is opened it sees that the stored session is over and shows "Well done!".
4. **Give up** clears shields and stops monitoring right away, with no celebration.

## What you must do by hand in Xcode

The capabilities and entitlements are already in the project. These steps need your Apple account, so only you can do them:

1. **Paid Apple Developer Program membership.** Family Controls doesn't work with a free Personal Team.
2. **Set your bundle ID prefix and team** in `Config/Signing.xcconfig`:
   ```
   BUNDLE_ID_PREFIX = com.yourname        // must be unique to you
   DEVELOPMENT_TEAM = ABCDE12345          // Xcode › Settings › Accounts, or developer.apple.com › Membership
   ```
   All bundle IDs and the App Group (`group.com.yourname.FocusTogether`) come from this value.
   Change the prefix here, not in the target's General tab: typing a bundle ID there overrides the shared value
   for that one target only.
3. **Open `FocusTogether.xcodeproj`** and, for **each of the 3 targets** (FocusTogether,
   DeviceActivityMonitorExtension, ShieldConfigurationExtension), go to **Signing & Capabilities**:
   - Check **Automatically manage signing** and pick your **Team** (if it isn't already picked up from the xcconfig).
   - Check that **Family Controls** and **App Groups** are listed. They come from the `.entitlements` files.
   - Under App Groups, make sure `group.<your prefix>.FocusTogether` is **checked**. If it shows in red, or Xcode
     says the group isn't registered, click the refresh button. If that doesn't fix it, click **+** and add
     exactly `group.<your prefix>.FocusTogether`. It must be identical in all 3 targets and must match
     `FTAppGroupIdentifier` (which the build fills in for you).
   - Wait until all 3 targets show a valid provisioning profile with no red errors.
4. **Distribution (only for TestFlight or the App Store):** Development builds work right away. To distribute,
   request the *Family Controls (Distribution)* entitlement at
   <https://developer.apple.com/contact/request/family-controls-distribution>. Request it for **all three bundle IDs**
   (the app and both extensions). Approval can take days or weeks.

## Testing on a real device

Screen Time APIs don't work in the Simulator: the project builds there, but authorization fails and the picker is empty.

**Device prerequisites**
- iPhone on iOS 16 or later, signed in with an Apple ID. `.individual` authorization asks for Face ID / passcode
  and doesn't work for child accounts managed by Family Sharing.
- **Developer Mode** on (Settings › Privacy & Security › Developer Mode). This appears after the device is first
  connected to Xcode.
- Select the **FocusTogether** scheme and your iPhone, then Run.

**Test checklist**
1. **Onboarding**: on first launch you see the explainer. Tap *Allow*, approve the system prompt, and you land on the Focus screen.
2. **Selection**: tap *Choose*, pick a couple of apps (e.g. Safari) and a category, then tap Done. Icons appear in the card.
   Force-quit and relaunch: the selection should still be there (it's saved in the App Group).
3. **Shield**: start a session, go Home and open a blocked app. You should see the custom shield with
   "You're in a focus session — back soon 💪".
4. **Survives the app being killed** (the key test): start the **15-minute "Test"** session (Debug builds only),
   then swipe FocusTogether away in the app switcher. Wait about 15 minutes. The blocked apps should open again,
   showing the monitor extension cleared the shields. Open FocusTogether: you get the *Well done!* screen with "15 minutes".
5. **Foreground completion**: keep the app open through a session. Confetti appears when the countdown hits zero.
6. **Give up**: start a session, tap *Give up* and confirm. Apps unblock straight away.

**Good to know**
- **15-minute minimum.** `DeviceActivityCenter.startMonitoring` rejects intervals shorter than 15 minutes
  (`intervalTooShort`). That's why the shortest test session is 15 minutes. You can't test the end-of-session
  path any faster.
- **Debugging extensions.** Breakpoints in the app don't reach the extensions. To debug one, run the extension's own
  scheme (Xcode asks which app to run; choose FocusTogether), or use **Debug › Attach to Process by PID or Name…**
  with `DeviceActivityMonitorExtension`. The monitor logs through `os.Logger` (subsystem `FocusTogether`), so you
  can also watch **Console.app** with your iPhone selected.
- **Shield changes may not show.** iOS caches the shield extension. If an edited message doesn't appear, delete
  the app from the iPhone and reinstall it, or restart the phone.
- **Monitor extensions have a small memory limit** (a few MB). Keep `DeviceActivityMonitorExtension` light: it only
  touches UserDefaults and ManagedSettings.
- **Deleting the app** removes every shield it set, so it's a quick way to recover if testing leaves something stuck.
- **Timing.** `intervalDidEnd` can arrive a little late, from seconds up to about a minute.
