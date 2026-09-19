# Arrangement views and reserved regions

Two new tools for the fold and the cameras. All of it is iOS 27.1 (beta as of
2026-09-19), so guard with availability checks when the deployment target is
lower. Verbatim Apple pages are in `apple/`.

## Order of preference

1. A system container that already adapts (`NavigationSplitView` /
   `UISplitViewController`, tab views, navigation stacks, system sheets, alerts,
   context menus). Split views adjust column width and margins for the fold on
   their own.
2. An arrangement view, when the screen is two pieces of content.
3. Reserved regions, for custom views nothing else covers.

## Arrangement views

A layout container with a **primary** and a **secondary** view. It picks a layout
from the available size, size class, and hardware features such as the fold.

| | SwiftUI | UIKit |
| --- | --- | --- |
| Container | `ArrangementView { primary } secondary: { secondary }` | `UIArrangementViewController`, `setViewController(_:for: .primary / .secondary, animated:)` |
| Choose a style | `.arrangementViewStyle(.split)` or `.overlay` | `updateArrangement(.split, animated:)` or `.overlay` |
| Limit axes | `.split.axes(.horizontal)`, `.overlay.axes(.horizontal)` | `.split.axes(.horizontal)`, `.overlay.axes(.horizontal)` |
| Default | automatic, which resolves to split | `UISplitArrangement` |

### Split

Side by side when the container is wider than tall, primary on top of secondary
when taller than wide. Placement moves to respect reserved regions such as the
fold. Use it where the code is an `HStack` or `VStack` of two panes today (a
player next to lyrics, a conversation next to photos).

Sizing, SwiftUI, applied to the primary or secondary view:

- `.splitArrangementLayoutRatio(0.3)`
- `.splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)`
- `.splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)`
- `.splitArrangementFixedLayoutSize(horizontal:vertical:)`

The view with the highest `layoutPriority` is sized first. UIKit has
`UISplitArrangement.Dimension` and `DimensionRange` for the same job.

### Overlay

Primary is layered on top of secondary in z-order while no division region is
active (device closed, or fully open). When partially folded, primary goes to
the trailing or bottom side of the fold and secondary to the leading or top
side. Use it where the code is a `ZStack` today (playback controls over video).

- `.overlayArrangementEdge(.leading / .trailing)` on a child picks which side it
  takes when the overlay goes horizontal.
- The HIG says you can collapse the secondary view in an overlay arrangement
  when you do not want it to appear, but no API for that is named in the docs or
  visible in the iOS 27.1 SDK interfaces as of 2026-09-19. Limiting `axes` is
  the documented control. UIKit can read the result through
  `state(for:).isHidden`. Do not invent a modifier for this.

### UIKit state

`state(for: placement)` returns a `ViewState` with `isHidden`, `splitAxis`, and
`zIndex`, so a child controller can adapt to how it is currently arranged.

### Rules

- **Do not put an arrangement view inside** a navigation split view, list, scroll
  view, or any container that could make part of it unreachable.
- **Navigation goes outside.** Arrangement views lay out content and do not
  navigate. Wrap them in a `NavigationStack`, `NavigationSplitView`, or
  `TabView`, never the other way round.
- To show only the primary in vertical layouts and both side by side in
  horizontal layouts, restrict the split to `.axes(.horizontal)`.

```swift
ArrangementView {
    PlayerControls()
} secondary: {
    VideoPlayer()
}
.arrangementViewStyle(.overlay)
```

```swift
let arrangementVC = UIArrangementViewController()
arrangementVC.setViewController(PrimaryViewController(), for: .primary)
arrangementVC.setViewController(SecondaryViewController(), for: .secondary)
arrangementVC.updateArrangement(.split.axes(.horizontal))
```

## Reserved regions

Areas inside a view's coordinate space that something else owns. Custom views
query them and move content out of the way. Standard containers already do.

Two kinds:

- `.occlusion`: something covers content. Dynamic Island, a camera, window
  controls on iPad. On iPhone Duo the **outer camera is always an occlusion**
  (and grows into the Dynamic Island for Live Activities). The **inner camera is
  an occlusion only while the camera is active**.
- `.division`: content splits into separate areas. The fold. **Active only when
  the device is partially open**; inactive when fully open.

Each region has `frame` (in the view's coordinate space, margins included),
`margins` (the padding for interactive content that is already part of the
frame), `isActive`, `kind`, and in SwiftUI an `id`.

| | SwiftUI | UIKit |
| --- | --- | --- |
| Query | `proxy.reservedRegions(kind:options:layoutDirectionBehavior:)` on a `GeometryProxy` | `view.reservedRegions(kind:options:)` on any `UIView` |
| Options | `ReservedRegion.QueryOptions.includeInactive` | `UIView.ReservedRegion.QueryOptions.includeInactive` |

```swift
GeometryReader { proxy in
    RegionAvoidingLayout(regions: proxy.reservedRegions(kind: .occlusion)) {
        ForEach(items) { ItemView($0) }
    }
}
```

Things that are easy to get wrong:

- **Check `isActive`, and verify what the query returns.** Apple's docs disagree
  with themselves here: the method discussion says it returns every region that
  intersects the view "regardless of whether they are currently active", while
  `QueryOptions.includeInactive` implies inactive regions are left out unless
  you ask. Do not assume either. Log the regions on the simulator in the flat
  and partially folded poses and see what comes back, then filter on `isActive`
  explicitly so the code is right under both readings. Apple's design guidance
  is to move only what is necessary, so a flat screen should not rearrange
  itself around an inactive fold.
- **Right-to-left.** Hardware does not flip with language, but by default
  SwiftUI mirrors region frames (`layoutDirectionBehavior: .mirrors`) so a
  `Layout`, which also mirrors its subviews, can compare frames directly. Pass
  `.fixed` only when doing absolute positioning yourself.
- **Re-query on layout.** Regions change with pose, rotation, and camera use.
  In UIKit, query inside `layoutSubviews()` or `viewDidLayoutSubviews()`.
- Keep important elements, and especially tap targets, clear of the fold.
  Controls that land in the fold are hard to see and hard to hit.

## Audit checklist

- [ ] Two-pane screens built from `HStack` / `VStack` / `ZStack` or a custom
      container controller: would an arrangement view do this better?
- [ ] No arrangement view nested in a list, scroll view, or split view
- [ ] Custom full-screen views (canvases, media, maps with overlays, games,
      custom grids) query reserved regions
- [ ] Centered elements on wide layouts (a centered button, logo, or divider)
      do not sit in the fold when partially folded
- [ ] Nothing important sits under the outer camera corner
- [ ] Grids use an even column count on the inner display
