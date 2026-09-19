# Field notes

Things observed at runtime or in the SDK that Apple's docs do not say, or say
differently. iPhone Duo is greenfield, so this file is how sessions pass what
they learned to the next one.

Rules for adding a note: only what you actually observed, with the date, the
Xcode and iOS versions, and how you observed it. Mark guesses as guesses. When a
later version changes the behavior, update the note instead of stacking a new
one on top. Ask the user before editing this file from inside another project's
session.

## Tooling

- **2026-09-19, Xcode 27.1 (27A9269), iOS 27.1 simulator.** The iPhone Duo
  simulator exposes both displays to `simctl io`. `enumerate` showed Screen ID 1
  `LCD` at 1398 x 2034 (outer) and Screen ID 3 `LCD-1` at 2007 x 2853 (inner).
  Confirmed by screenshot: with the device closed, display 1 showed the running
  app with vertical bars on the trailing side, and display 3 was solid black.
- **Same setup.** `simctl io booted screenshot` without `--display`, and with
  `--display=internal`, both capture the inner display. With the device closed
  that is a black image. Always pass `--display=<id>`.
- **Same setup.** `simctl` has no subcommand for pose, fold angle, or open and
  close (`simctl help` lists none; `simctl ui` only has appearance, contrast,
  and content size). Poses are changed in the Device Hub window. The macOS
  process name is `DeviceHub`.

## Docs

- **2026-09-19.** `reservedRegions(kind:options:...)` is documented as returning
  every intersecting region "regardless of whether they are currently active",
  yet a `QueryOptions.includeInactive` option exists. Which one is true at
  runtime is **not yet verified**. Filter on `isActive` explicitly until someone
  logs the real behavior here.
- **2026-09-19.** The hinge API (`onHingeChange`, `DeviceHinge`,
  `UIHingeInteraction`, `UIHinge`) has doc pages but is not linked from the
  "Preparing your app for iPhone Duo" overview or the HIG page. It was found by
  grepping the iOS 27.1 SDK for "hinge" (`UIKit.framework/Headers/UIHinge.h` and
  the SwiftUICore `.swiftinterface`). The same approach is worth trying for the
  scene APIs the tech talks mention.

## Runtime behavior

Nothing recorded yet.
