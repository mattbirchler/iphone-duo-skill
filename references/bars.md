# Vertical bars: navigation bars, toolbars, tab bars

On iPhone Duo the system stacks the Dynamic Island, status bar, toolbar
(including navigation buttons), and tab bar **vertically along one side** of the
display in some poses. This is one of the core patterns of the device. Verbatim
Apple pages are in `apple/`.

## When bars go vertical

- Outer display (device closed): vertical.
- Inner display, landscape: vertical, so the experience is continuous with the
  outer display.
- Inner display, portrait: standard horizontal bars. There is enough height.
- Inspectors: always horizontal.
- Split views showing multiple columns: horizontal for the sidebar and content
  columns, vertical for the detail column.
- Sheets on the outer display: vertical by default.
- Sheets on the inner display: horizontal for centered or leading placement,
  vertical for trailing placement.
- Split View multitasking: each app's bar is on its outer edge (left app, left
  side).
- Vertical bars stay aligned with the hardware. They do not flip sides in
  right-to-left languages.

## Requirement 1: use the system's bars

The system can only move bars it owns.

- SwiftUI: put `.toolbar { }` on content inside a `NavigationStack` or
  `NavigationSplitView`. Use `TabView` for tabs.
- UIKit: set items on a view controller that lives in a `UINavigationController`
  (`navigationItem`, `toolbarItems`). Use `UITabBarController`.
- Do not build your own bar from `UIToolbar`, `UINavigationBar`, or `UITabBar`,
  and do not fake a bar in SwiftUI with an `HStack` pinned to an edge.

If bars do not go vertical in the simulator on the outer display, this is the
first thing to check.

## Requirement 2: give every item a title and an icon

How the system shows an item depends on where it ends up:

| Where | Shows |
| --- | --- |
| Vertical bar | Icon |
| Horizontal bar | Icon or title, icon preferred |
| Overflow menu | Icon and title |

- An item with a title and **no icon is never placed in a vertical bar**.
- An item with a **custom view is never placed in a vertical bar**.
- Keep text-only buttons to a minimum. Prefer a symbol wherever one works.
- Always include the title even when the symbol is what shows. Overflow menus
  and expanded forms use it.

SwiftUI: `Button("Share", systemImage: "square.and.arrow.up") { }` or a `Label`.
UIKit: set both `title` and `image` on the `UIBarButtonItem`.

**Text-only items, including Done and Cancel in sheets.** Apple's wording is
narrower than "every item needs both": the HIG asks for a title and a symbol on
each item "that isn't text-only", asks you to keep text-based buttons to a
minimum, and says labels that include text stay in a horizontal bar. The docs do
**not** say what happens to a text-only item when only a vertical bar is showing
(overflow menu, or not shown). So:

- Give Done, Cancel, Close, and Add their semantic placements
  (`.confirmationAction`, `.cancellationAction`, `.topBarPinnedTrailing`) so the
  system knows what they are. Do not swap their text for a symbol on a guess.
- Then look at the sheet on the outer display in the simulator and see where the
  item went. This is one of the first things to verify in any app, since almost
  every app has a sheet with a text Done or Cancel. Record what you see in
  `field-notes.md`.
- For ordinary actions (Share, Filter, Sort), add the symbol. That case is clear.

## Requirement 3: order and group items semantically

Top of the vertical axis is for primary navigation (Back, Close), then prominent
actions (Done). A navigation controller adds Back for you. Keep the remaining
items in their original groups; the system inserts a gap between items that came
from the top bar and items from the bottom bar.

| Purpose | SwiftUI | UIKit |
| --- | --- | --- |
| Prominent trailing action such as Done | `ToolbarItem(placement: .topBarPinnedTrailing)` (iOS 27.0) | `navigationItem.pinnedTrailingGroup` (iOS 16.0) |
| Custom Back or Close | `ToolbarItem(placement: .cancellationAction)` | an item in `navigationItem.leadingItemGroups` |
| Related items | `ToolbarItemGroup` | `UIBarButtonItemGroup` |

Pinned items only move to overflow when search is active and space runs out.
In UIKit the pinned trailing group cannot overflow at all, so if it holds more
than one item give the group a `representativeItem`.

Use groups instead of manual spacers. Groups space themselves and adapt.

Keep controls near the content they affect. Controls for a list in the leading
pane stay above that pane. Do not push them to the side bar.

## Requirement 4: decide what overflows

Items overflow from bottom to top by default. Frequently used actions (Compose,
New Note) and items that show status (badges) should stay visible longest.

| Purpose | SwiftUI | UIKit |
| --- | --- | --- |
| Overflow order | `.visibilityPriority(.high / .low / .automatic)` on toolbar content, plus `ToolbarItemVisibilityPriority(higherThan:)` and `(lowerThan:)` (iOS 27.0) | `UIBarButtonItem.visibilityPriority` with `.high / .standard / .low`, `init(higherThan:)`, `init(lowerThan:)` (iOS 27.0). An implicit group inherits its item's priority |
| Which axes an item may appear on | `.axisBehavior(.automatic / .horizontalOnly / .verticalPreferred)` (iOS 27.1) | `UIBarButtonItem.axisBehavior` with the same three cases (iOS 27.1) |
| Always in the overflow menu | `ToolbarOverflowMenu { Button... }` inside `.toolbar` (iOS 27.0) | `navigationItem.additionalOverflowItems` (a `UIDeferredMenuElement`, iOS 16.0) |
| Toolbar vs tab bar when both are squeezed | `.toolbarVerticalCompressionBehavior(.automatic / .prefersTabBar / .prefersToolbarItems)` (iOS 27.1) | `navigationItem.verticalBarCompressionBehavior` with `.automatic / .prefersTabBar / .prefersBarItems` (iOS 27.1) |

### Availability guards for toolbar modifiers

`visibilityPriority` and `ToolbarOverflowMenu` are iOS 27.0; `axisBehavior` and
the vertical bar modifiers are iOS 27.1. With a lower deployment target you
cannot put `if #available` around a modifier in a chain, so wrap it once. This
pattern type-checks against the iOS 27.1 SDK with a 26.0 target:

```swift
extension ToolbarContent {
    @ToolbarContentBuilder
    func duoVisibilityPriority(keepVisible: Bool) -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            self.visibilityPriority(keepVisible ? .high : .low)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func duoPrefersToolbarItems() -> some View {
        if #available(iOS 27.1, *) {
            self.toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        } else {
            self
        }
    }
}
```

Use the project's naming, not these names. Note that a `@ViewBuilder`
`if #available` changes view identity between branches, which is harmless here
because the branch never changes while the app runs. In UIKit, plain
`if #available(iOS 27.1, *) { item.axisBehavior = ... }` is enough.

Heads-up when reading `apple/`: the `ToolbarItemVisibilityPriority` page
introduces its sample as "keep a share button visible longer than an archive
button" but the code shows generic `PrimaryControl` and `SecondaryControl`. The
API usage is right; the prose and sample just do not match.

Notes:

- `horizontalOnly` items are **not shown at all** when there is no horizontal
  bar. Use it sparingly, and make sure the action is reachable another way.
- Lower priority moves to overflow first. Set priority on whole groups first,
  then on individual items if finer control is needed.
- Default compression keeps the tab bar and overflows toolbar items. That suits
  navigation-focused screens. For task-focused screens, prefer toolbar items and
  let the tab bar minimize.
- If the app has its own "more" menu, move those actions into the system
  overflow menu. Reserve the ellipsis symbol for overflow and give other menus a
  different symbol.

## Requirement 5: opt out of vertical bars only when the UI calls for it

In general, do not override bar placement. Opt out only for UIs that are better
with horizontal bars: a fullscreen video player with toolbar controls, or a
non-scrolling layout such as a calculator where width is precious.

- SwiftUI: `.toolbarVerticalBehavior(.disabled)` (iOS 27.1). Resolved per window
  or presentation. `NavigationStack` uses its top view, `TabView` its selected
  view, `NavigationSplitView` its trailing-most column.
- UIKit: override `preferredVerticalBarBehavior` and return `.disabled`
  (iOS 27.1). Containers forward through `childForPreferredVerticalBarBehavior`.
  Call `setNeedsUpdateOfVerticalBarConfiguration()` when the answer changes.

Treat it as a stable choice. Do not flip it as the user navigates or as a
function of one view's state. To hide bars on one screen, use the visibility
APIs (`toolbarVisibility(_:for:)`), not this.

## Requirement 6: sheets

- Opt a sheet out of vertical bars with the same two APIs above.
- Choose where the sheet sits on the inner display:
  `.presentationPlacement(.automatic / .center / .leading / .trailing)` in
  SwiftUI, `UISheetPresentationController.preferredPlacement` in UIKit
  (iOS 27.0). Only sheets respect this. Trailing placement gets a vertical bar;
  center and leading get a horizontal one.

## Requirement 7: custom views must know about the vertical bar

- SwiftUI: `@Environment(\.toolbarVerticalEdge) var edge: HorizontalEdge?`
  (iOS 27.1).
- UIKit: `traitCollection.verticalBarEdge`, a `UIVerticalBarEdge` of `.leading`,
  `.trailing`, or `.unspecified` (iOS 27.1).

Both report the system's **preferred** edge whether or not a vertical bar is
currently visible, and `nil` / `.unspecified` where a vertical bar is never
used. Use them to place floating palettes or custom controls on the matching
side. Use safe areas, not this value, to keep content out from under the bar.

## Requirement 8: backgrounds extend under the vertical bar

A hero or background image should run under the vertical bar instead of stopping
at it: `backgroundExtensionEffect()` in SwiftUI, `UIBackgroundExtensionView` in
UIKit (both iOS 26.0). Scrollable content stays inset.

Full-width layouts with no bars are fine for immersive, non-scrolling UIs
(Calculator does this), as long as nothing collides with the Dynamic Island or
status bar.

## Audit checklist

- [ ] Every screen's bar items come from `.toolbar`, `navigationItem`,
      `toolbarItems`, `TabView`, or `UITabBarController`
- [ ] No `UIToolbar(`, `UINavigationBar(`, `UITabBar(` instantiated by hand, no
      faux SwiftUI bars, no hidden navigation bar with a homemade replacement
- [ ] Every item has an icon and a title; no `UIBarButtonItem(customView:)` or
      text-only items for actions that matter on the outer display
- [ ] Done / Close / Back use semantic placements
- [ ] Related items are grouped, no manual spacers
- [ ] Important actions have `.high` visibility priority; rarely used ones `.low`
- [ ] Any homemade ellipsis menu is folded into the system overflow menu
- [ ] Vertical bar opt-outs are limited to player or calculator style screens
- [ ] Hero images use the background extension effect
