# Layout and resizing

Distilled from Apple's "Preparing your app for iPhone Duo" and the HIG page
"Designing for iPhone Duo". Verbatim copies are in `apple/`.

## The device, in one paragraph

iPhone Duo folds. It has a compact outer display (used when closed) and a large
inner display (used when open). The outer display is wider and shorter than
other iPhones. Each display has its own front camera: the outer one sits in a
corner and is always visible; the inner one is behind the display and hidden
until the camera is active. The device can be closed, fully open, partially
folded (like a book, flat on a table, or standing on an edge), and rotated in
any of those. Content moves between displays as the pose changes. Two apps can
also share the inner display with Split View multitasking, so your app can show
up at many sizes.

## Requirements

1. **Build with Xcode 27 or later.** Built with Xcode 26 or earlier, the app
   does not extend under the status bar and camera, so it does not get the full
   screen on iPhone Duo.
2. **The app must resize.** If it already works on iPad, on Mac, or in iPhone
   Mirroring, it is most of the way there.
3. **Prefer system containers**: split views, tab bars/tab views, navigation
   stacks, arrangement views. They already handle the outer display, the fully
   open and folded inner display, and camera occlusions.
4. **Size views relative to their container**, never to fixed iPhone dimensions.
5. **Do layout math from the scene or containing view's bounds**, never from
   screen dimensions.
6. **UIKit: use Auto Layout** so views are resizable.
7. **Branch on size classes, not on device or orientation.** Use
   `horizontalSizeClass` and `verticalSizeClass`. Apple says explicitly: do not
   use `userInterfaceIdiom` or `UIInterfaceOrientation` for layout decisions.
   Compact width for the outer display and regular width for the inner display
   cover the fundamentals of every pose. Do not design a custom layout per pose.
8. **UIKit: use automatic trait tracking or `registerForTraitChanges`**, not the
   deprecated `traitCollectionDidChange(_:)`. Reading a trait inside
   `layoutSubviews()` (and the other supported methods) makes UIKit re-run it
   when that trait changes. See `apple/documentation_uikit_automatic-trait-tracking.md`
   and `apple/documentation_uikit_adapting-your-app-when-traits-change.md`.
9. **Use layout margins and safe area insets.** Safe areas are asymmetric on
   iPhone Duo, because bars sit on one side. In Split View multitasking the
   other app's controls are on the opposite edge, so respect safe areas on both
   sides.
10. **Same functionality in every pose and on both displays.** Controls may
    overflow and content may move or resize, but nothing may become unreachable.
    Keep element state the same when the app moves between displays.
11. **Keep the information hierarchy.** It is fine to show one more level on the
    inner display (Mail shows list or message when closed, both when open).
12. **Avoid extreme layout changes while folding.** Move only what has to move
    to stay visible and tappable. In grids, prefer an even number of columns so
    content divides cleanly at the fold.
13. **Games**: locking to portrait or landscape is allowed, but fill the screen
    in every pose. Keep text and control sizes consistent when resizing. Prefer
    changing aspect ratio over letterboxing or pillarboxing. If bars are
    unavoidable, put artwork in the padding.

## What to look for when auditing

| Smell | Why it is a problem | Replace with |
| --- | --- | --- |
| `UIScreen.main.bounds`, `UIScreen.main.nativeBounds`, `UIScreen.main.scale` used for layout | Screen is not the scene. Two displays, Split View, poses | View or scene bounds, `GeometryReader`, `containerRelativeFrame`, Auto Layout |
| `UIDevice.current.userInterfaceIdiom == .phone` (or `.pad`) choosing a layout | Apple says not to use idiom for layout | `horizontalSizeClass` / `verticalSizeClass` |
| `UIInterfaceOrientation`, `UIDevice.current.orientation`, `.isLandscape`, `.isPortrait` choosing a layout | Apple says not to use orientation for layout | Size classes and container size |
| Hardcoded widths or heights that match a phone screen (320, 375, 390, 393, 402, 414, 430, 440, ...) | Fixed iPhone dimensions | Container-relative sizing |
| `traitCollectionDidChange(_:)` | Deprecated, called for every trait change | Automatic trait tracking, `registerForTraitChanges` |
| Frame-based manual layout in UIKit without `layoutSubviews` recalculation | Does not resize | Auto Layout |
| Custom sheets, popovers, or modals positioned by hand | Land in the fold, do not move for it | System sheets, alerts, context menus (they move for the fold automatically) |
| `UIRequiresFullScreen`, a single supported orientation in Info.plist (non-game) | Blocks resizing and multitasking | Remove unless the app is a game that locks orientation |

Related, from TN3210 (iPhone Mirroring, which Apple lists as related because the
same resizing work applies): `UIApplicationSupportsIndirectInputEvents` must not
be `NO`; custom sheets need `allowedScrollTypesMask` on their pan recognizer;
`deviceOwnerAuthenticationWithBiometrics` fails under Mirroring, use
`deviceOwnerAuthenticationWithBiometricsOrCompanion`. These are not iPhone Duo
requirements. Report them separately and at lower priority.

## Hinge state

For interactive effects that follow the fold. Layout should not depend on this:
use size classes, arrangement views, and reserved regions for layout. All
iOS 27.1. Verbatim pages: `apple/documentation_swiftui_view_onhingechange_isenabled.md`,
`apple/documentation_uikit_uihingeinteraction.md`, `apple/documentation_uikit_uihinge.md`.

| | SwiftUI | UIKit |
| --- | --- | --- |
| Observe | `.onHingeChange(isEnabled:) { oldContext, newContext in }` | `view.addInteraction(UIHingeInteraction { interaction, update in })` |
| Value | `newContext.hinge`, a `DeviceHinge?` | `update.hinge`, a `UIHinge?` |
| Status | `.closed`, `.partiallyOpen`, `.fullyOpen` | `.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen` |
| Angle | `hinge.angle`, an `Angle` | `hinge.angle`, a `CGFloat` in radians |

- The hinge is **optional**. It is nil on hardware without one, and in UIKit when
  the interaction leaves a hierarchy that provides hinge updates. Always handle
  nil, so the same code runs on every iPhone.
- Prefer `status` over `angle` when all you need is closed, partly open, or open.
  Update rate and precision of the angle are system policy and can change, so
  never depend on a particular frequency or granularity.

## Not documented yet

Apple's tech talk "Leverage multiple displays and scenes on iPhone Duo"
(tech-talks/111464) also covers requesting new scenes in side-by-side
multitasking and handling dynamic window sizes. No reference page for those was
linked from the iPhone Duo docs on 2026-09-19. Do not guess at API names. If a
task needs them, search the SDK (the hinge API above was found that way, see
`field-notes.md`), or ask the user to check the video.
