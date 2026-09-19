# Validating on the iPhone Duo simulator and device

iPhone Duo is greenfield. Nobody, including you, has reliable intuition for what
these APIs do at runtime, the APIs are beta, and Apple's docs are thin in places.
Code that compiles and reads correctly proves nothing here. **Whenever it is
possible, build, run, and click through the real UI, and compare what you see
with what the code led you to expect.** A mismatch is a finding, not an
annoyance: either the code is wrong or your model of the platform is, and both
are worth knowing.

## 1. Build and launch

Check the toolchain first. Xcode 27 or later is a hard requirement, and most
iPhone Duo APIs need the iOS 27.1 SDK.

```bash
xcodebuild -version
xcrun simctl list devices available | grep -i duo
```

The second command lists simulator **instances**. If the device type exists but
no instance does, create one: `xcrun simctl create "iPhone Duo" "iPhone Duo"`.
If the name is ambiguous or differs, use the UDID from the list in
`-destination 'platform=iOS Simulator,id=<UDID>'`.

If there is no iPhone Duo simulator at all, tell the user (they can add one in Xcode's
Device Hub) and fall back to the closest stand-ins listed in section 6.

```bash
# Use the project's own scheme. -workspace instead of -project where needed.
xcodebuild -project App.xcodeproj -scheme App \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath build/duo build

xcrun simctl boot "iPhone Duo" 2>/dev/null || true
open -a DeviceHub     # Xcode 27's device window; this is where poses are changed
xcrun simctl install booted build/duo/Build/Products/Debug-iphonesimulator/App.app
xcrun simctl launch --console-pty booted com.example.App
```

If the project has a Makefile, Fastlane lane, or an existing run skill, use that
instead of inventing a command.

## 2. Screenshots: there are two displays

The iPhone Duo simulator exposes both screens. Checked on Xcode 27.1:

```bash
xcrun simctl io booted enumerate | grep -E "Screen ID|Name:|Pixel Size"
#   Screen ID: 1  LCD    {1398, 2034}   outer display
#   Screen ID: 3  LCD-1  {2007, 2853}   inner display

xcrun simctl io booted screenshot --display=1 outer.png
xcrun simctl io booted screenshot --display=3 inner.png
```

**Gotcha:** a plain `simctl io booted screenshot` with no `--display` captures
the inner display. When the device is closed that image is solid black, which
looks like a crashed app and is not. Always pass `--display`, and treat an
all-black image as "this display is off in the current pose". Re-run `enumerate`
rather than trusting the IDs above, since they can differ between runtimes.

Look at every screenshot you take. Downscale first if needed
(`sips -Z 900 in.png --out small.png`).

## 3. Changing poses

As of Xcode 27.1, `simctl` has **no command for pose, fold angle, or
open/close**. Poses are changed in the Device Hub window. Options, best first:

1. If you have a computer-control or GUI automation tool in this session (for
   example a computer-use skill, or another desktop automation tool), use it to
   operate Device Hub: open, close, partially fold, rotate.
2. Ask the user to set the pose, then take the screenshots yourself. Be specific:
   "Please close the device in Device Hub and tell me when it is done."
3. Rotation alone is available from the Device Hub rotate button and the
   Device > Orientation menu.

Do not claim a pose was tested unless a screenshot taken in that pose exists.

## 4. Clicking through the UI

Pick whatever this session can actually do:

- **GUI automation tool available:** click in the Device Hub canvas. A click is
  a tap, click-and-hold is touch-and-hold, drag is drag.
- **XCUITest:** if the project has a UI test target, write a short UI test that
  walks the main flows and attaches screenshots, and run it with
  `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone Duo'`.
  Good for repeatable passes and for apps you will revisit.
- **Deep links and launch arguments:** `xcrun simctl openurl booted myapp://...`
  or launch arguments can jump straight to a screen for a screenshot. This
  checks layout but not interaction.
- **Nothing available:** hand the user a short, numbered click-through script
  and ask for screenshots or observations. Then report the results as theirs.

## 5. The pass to run

For each pose, walk **every screen, sheet, popover, and menu** you touched, plus
the app's main flows.

| Pose | What to look at |
| --- | --- |
| Closed, outer display, portrait | Bars vertical on the side? Every toolbar action reachable, either visible or in overflow? Anything under the camera corner? Text-only items missing? |
| Closed, outer display, rotated | Same again. Layout uses the width. |
| Open flat, portrait | Standard horizontal bars. Regular-width layout kicks in. Extra hierarchy level shown where intended. |
| Open flat, landscape | Bars vertical again. Split view columns sensible. Hero images run under the bar. |
| Partially folded, both orientations | Nothing important or tappable in the fold. Sheets, alerts, popovers, and menus clear of it. Arrangement views moved primary and secondary to opposite sides. Centered elements did not get cut in half. |
| Transition open to closed and back, mid-task | State survives: scroll position, selection, text being typed, a presented sheet, playback. No relaunch-style reset. |
| Split View multitasking on the inner display | App works at the narrower size. Content respects safe areas on both edges. |
| Dynamic Type at a large size, and right-to-left | Bars still usable. Reserved region logic still correct in RTL (vertical bars do not flip sides; mirrored region frames do). |

While walking the flows, actually tap things. For each toolbar item confirm it
fires from the vertical bar **and** from the overflow menu. Open every sheet and
dismiss it. Trigger every alert and context menu you can reach.

### Expect, then observe

Before each check, write down one line of what the code should produce ("Done
is pinned trailing, so it should sit near the top of the vertical bar, under
Back"). Then look. Record the result either way. When they differ:

1. Re-read the verbatim Apple page in `apple/` for that API.
2. Add a temporary log or on-screen debug label to see the real values
   (size class, `toolbarVerticalEdge`, the reserved regions and their
   `isActive`, the arrangement `ViewState`).
3. Fix the code, or correct your understanding and say so in the report.
4. Remove the debug output.

If the platform genuinely behaves differently from the docs, tell the user and
offer to record it in this skill's `references/field-notes.md` so the next
session starts from it.

## 6. When you cannot fully validate

- **No iPhone Duo simulator:** an iPad simulator with Split View and Stage
  Manager resizing, plus iPhone Mirroring resizing, exercises the resizing and
  size class work. It does **not** exercise vertical bars, the fold, or reserved
  regions.
- **Physical device:** preferred when the user has one connected, and required
  for camera work since the simulator has no camera. `xcrun devicectl list
  devices` shows what is paired. Device Hub cannot use the device's camera or
  microphone while it mirrors the screen, so camera flows are driven on the
  device by the user.
- **Cannot build at all:** fix that first if it is in scope. Otherwise stop
  calling the work validated.

Whatever was not exercised gets listed in the final report under a plain
heading such as "Not verified at runtime", with the reason. Never write "works
on iPhone Duo" for something you only read.
