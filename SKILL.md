---
name: iphone-duo
description: >-
  Audit an iOS app against Apple's iPhone Duo requirements (Apple's foldable iPhone with an outer and an inner display) and update the code to meet them, then validate the result by running it on the iPhone Duo simulator or a device. Use whenever the user mentions iPhone Duo, the foldable or folding iPhone, the fold, hinge, poses, inner or outer display, or asks to "get ready for Duo", "support the fold", or check Duo readiness. Also use when writing or changing iOS code that touches vertical toolbars or tab bars, toolbar overflow and visibility priority, ArrangementView or UIArrangementViewController, reserved regions, sheet placement, AVCaptureDeviceDirectionCoordinator, camera capture accessories, or layout driven by UIScreen bounds, interface idiom, or orientation. These APIs shipped in iOS 27.0 and 27.1 and are newer than your training data, so read the bundled Apple docs instead of guessing.
---

# iPhone Duo: audit, update, validate

iPhone Duo is Apple's folding iPhone: a compact outer display, a large inner
display, a hinge, and a front camera on each display. The app moves between
displays as the device opens, closes, folds partway, and rotates. Apple's
requirements come down to five things:

1. The app resizes cleanly (size classes and container bounds, never screen
   size, idiom, or orientation).
2. Bars are system bars, so the system can stack them vertically on the side,
   and their items are built to survive that (icon plus title, semantic
   placement, overflow priority).
3. Two-pane and layered screens adapt to the fold, ideally with an arrangement
   view.
4. Custom views stay out of reserved regions: the fold and the cameras.
5. Capture apps choose cameras by the direction they face, not their position.

Everything here was built from Apple's documentation fetched on 2026-09-19. The
APIs are new (iOS 27.0 and 27.1, the latter still beta on that date) and are
not in your training data. **Do not write any of these APIs from memory or by
analogy.** Look up the exact signature in `references/` first. If it is not
there, fetch it (see "Refreshing the docs") or say you cannot find it.

## References

Read the ones that match the work. Each ends with an audit checklist.

| File | Read when |
| --- | --- |
| `references/layout-and-resizing.md` | Always. Device model, resizing rules, smells to replace, hinge state API |
| `references/bars.md` | The app has navigation bars, toolbars, tab bars, or sheets with bars (nearly always) |
| `references/arrangement-and-reserved-regions.md` | Two-pane or layered screens, custom full-screen views, anything that could sit in the fold or under a camera |
| `references/camera.md` | The app uses AVFoundation or AVKit capture. Otherwise skip |
| `references/testing.md` | Always, before claiming anything works |
| `references/field-notes.md` | Always. Runtime behavior that earlier sessions observed and the docs do not say |
| `references/apple/*.md` | Verbatim Apple pages with declarations, availability, and sample code. Grep here for any symbol before using it |

`references/apple/` is not checked in, because the pages are Apple's. If the
folder is missing or empty, run `python3 scripts/fetch-docs.py` from the skill's
directory before anything else. It downloads every page in `scripts/sources.txt`.

## Workflow

Post a checklist of these phases and keep it updated, since this is multi-step
work.

### 1. Scope

Find the iOS targets, whether the UI is SwiftUI, UIKit, or mixed, the deployment
target, and whether the app captures from the camera. If the user asked for an
audit only, stop after phase 3. If they asked for one specific thing ("fix the
toolbars for Duo"), do that slice of each phase rather than the whole app.

### 2. Static audit

```bash
scripts/audit.sh /path/to/project
```

Script and reference paths in this file are relative to the skill's directory,
the folder that holds this `SKILL.md`. Prefix them with wherever it is installed.

The script lists candidates grouped by requirement, with severity and the
reference file to read. It produces candidates, not findings. Open each hit and
decide: `UIScreen.main.scale` for rendering a thumbnail is fine; an idiom check
inside a screenshot test is fine; `UIScreen.main.bounds.width / 2` for a column
width is a real finding. Then go past the script, because grep cannot see
structure. Walk the app's screens in code and answer the checklist at the bottom
of each reference file. Toolbars need particular care: for each `.toolbar` or
`navigationItem`, check that items have both an icon and a title, that Done,
Close, and Back use semantic placements, and that the actions people use most
would survive overflow on the narrow outer display.

### 3. Look at the app running before changing it

Build and run on the iPhone Duo simulator (`references/testing.md`) and capture
the current state of the main screens on both displays. This is the baseline. It
often reorders the static findings: a smell that looks bad in code may be
harmless on screen, and the worst problem may be one grep never flagged.

Then report findings grouped as:

- **Blocking**: functionality lost or unreachable in some pose, content in the
  fold or under a camera, app not full screen, wrong camera or mirroring.
- **Should fix**: bars not going vertical, text-only or custom-view items that
  drop out of the vertical bar, no overflow priorities, layout math from screen
  size, idiom, or orientation.
- **Opportunities**: arrangement views, sheet placement, background extension
  under the bar, camera capture accessory.
- **Related, not Duo**: iPhone Mirroring items from TN3210.

Give `file:line` for each, the requirement it breaks, and the proposed fix. For
an audit-only request, this report is the deliverable.

### 4. Update

Work in the order above, smallest safe change first.

- **Availability.** Most Duo APIs are iOS 27.1, some 27.0 (each reference notes
  which, and every `apple/` page has an Availability line). If the deployment
  target is lower, wrap calls in `if #available(iOS 27.1, *)` or put them in an
  `@available` view modifier or extension, and keep the existing behavior as the
  fallback. Toolbar modifiers cannot be guarded inline, so use the wrapper
  pattern in `references/bars.md`. Do not raise the deployment target without
  asking.
- **Prefer deleting custom code to adding Duo code.** Replacing a homemade bar
  with `.toolbar`, or a hand-placed modal with a system sheet, fixes Duo and
  everything else at once. Reach for reserved regions last.
- **Do not redesign.** Apple's guidance is to let the existing layout expand,
  not to invent a layout per pose, and to move only what must move when folding.
- **Do not opt out of vertical bars** to make a problem go away. That is only
  for player-style and calculator-style screens.
- Match the surrounding code's style. Any user-facing strings you add (toolbar
  item titles, for example) follow the project's and the user's copy rules.
- Build after each step, and commit each completed step separately if the user
  works that way.

### 5. Validate at runtime (not optional)

This is greenfield. There is no established understanding of what should and
should not work on this device, the APIs are beta, and the docs have gaps and at
least one contradiction. So the code reading correctly is not evidence. Whenever
it is possible, **build, run on the iPhone Duo simulator or a connected device,
and click through the UI** to confirm each change does what you expected from
the code. Follow `references/testing.md`:

- Before each check, state what the code should produce. Then look. When they
  differ, find out why before moving on.
- Cover the poses: closed (outer display), open flat in portrait and landscape,
  partially folded, the open/close transition mid-task, and Split View.
- Tap things. Every toolbar action from the vertical bar and from overflow,
  every sheet, alert, popover, and menu you touched.
- Screenshot both displays with `--display` (a default screenshot of a closed
  device is black, and that is not a crash).
- `simctl` cannot change poses. Use a GUI automation tool on Device Hub if you
  have one in this session, otherwise ask the user to set the pose and carry on.
- Camera behavior needs a physical device. The simulator has no camera.

If you learn something the docs did not tell you, offer to add it to
`references/field-notes.md` so the next session starts with it.

### 6. Report

Say what changed and why, what you verified at runtime and in which poses (with
the screenshots), and under a plain "Not verified at runtime" heading, anything
you could not exercise and the reason. Never write that something works on
iPhone Duo when you only read the code.

## Refreshing the docs

Apple is still revising these pages. `developer.apple.com` renders client-side,
so fetching a doc URL as HTML returns an empty shell. The script reads the JSON
behind each page instead.

```bash
cd /path/to/this/skill
python3 scripts/fetch-docs.py --check      # what changed upstream, writes nothing
python3 scripts/fetch-docs.py              # refresh references/apple/
python3 scripts/fetch-docs.py /documentation/swiftui/arrangementviewstyle   # print any one page
```

Run `--check` when the snapshot is more than a few weeks old, when an API here
fails to compile, or when the user mentions a new beta. `--check` lists the
pages that changed. Refresh, re-read those pages, update the curated reference
files to match, and tell the user what moved. To cover a new page, add its path
to `scripts/sources.txt`. If the skill's directory is a git checkout, leave
committing and pushing to the user unless asked.

Known gap: requesting scenes for side-by-side multitasking and other
multi-display scene work are covered only in Apple's tech talk "Leverage
multiple displays and scenes on iPhone Duo"
(developer.apple.com/videos/play/tech-talks/111464). No reference page was
linked from the Duo docs on 2026-09-19. Do not guess those API names. Search the
installed SDK, which is how the hinge API in `references/layout-and-resizing.md`
was found, then fetch the matching doc page:

```bash
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
grep -rli "keyword" "$SDK/System/Library/Frameworks/UIKit.framework/Headers"
grep -n -i "keyword" "$(find "$SDK/System/Library/Frameworks/SwiftUICore.framework" -name 'arm64e-apple-ios.swiftinterface' | head -1)"
```
