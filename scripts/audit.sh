#!/usr/bin/env bash
# Static scan of an iOS project for iPhone Duo readiness.
#
#   audit.sh [project-dir]        (defaults to the current directory)
#
# This finds candidates, not verdicts. Every hit needs a human or Claude to read
# the surrounding code: UIScreen.main.scale for image rendering is fine,
# UIScreen.main.bounds.width for layout is not. Requirement details live in
# ../references/*.md.

set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 2; }

EXCLUDES=(--glob '!**/Pods/**' --glob '!**/Carthage/**' --glob '!**/.build/**'
          --glob '!**/build/**' --glob '!**/DerivedData/**' --glob '!**/node_modules/**'
          --glob '!**/*.xcassets/**' --glob '!**/SourcePackages/**')

if command -v rg >/dev/null 2>&1; then
  search() { rg --no-heading -n -g '*.swift' -g '*.m' -g '*.mm' -g '*.h' "${EXCLUDES[@]}" -e "$1" . 2>/dev/null; }
  search_any() { rg --no-heading -n "${EXCLUDES[@]}" -g "$2" -e "$1" . 2>/dev/null; }
else
  search() { grep -rnE --include='*.swift' --include='*.m' --include='*.mm' --include='*.h' \
               --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=.build --exclude-dir=build \
               --exclude-dir=DerivedData --exclude-dir=SourcePackages -e "$1" . 2>/dev/null; }
  search_any() { grep -rnE --include="$2" --exclude-dir=Pods --exclude-dir=build \
               --exclude-dir=DerivedData -e "$1" . 2>/dev/null; }
fi

MAX=25
check() { # severity, title, regex, reference
  local hits count
  hits="$(search "$3")"
  [ -z "$hits" ] && return
  count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  printf '\n[%s] %s  (%s hits)  -> %s\n' "$1" "$2" "$count" "$4"
  printf '%s\n' "$hits" | head -n "$MAX" | sed 's/^/    /'
  [ "$count" -gt "$MAX" ] && printf '    ... %s more\n' "$((count - MAX))"
}

echo "iPhone Duo static audit: $(pwd)"
echo "=========================================================="

echo
echo "## Toolchain"
xcodebuild -version 2>/dev/null | sed 's/^/    /' || echo "    xcodebuild not found"
XV="$(xcodebuild -version 2>/dev/null | awk '/^Xcode/{print int($2)}')"
if [ -n "${XV:-}" ] && [ "$XV" -lt 27 ]; then
  echo "    [HIGH] Xcode $XV: apps built with Xcode 26 or earlier do not extend under the status bar and camera on iPhone Duo."
fi
if xcrun simctl list devicetypes 2>/dev/null | grep -qi 'iPhone Duo'; then
  echo "    iPhone Duo simulator device type: available"
else
  echo "    [NOTE] no iPhone Duo simulator device type installed"
fi
printf '    Deployment targets: '
search_any 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+' '*.pbxproj' | sed -E 's/.*= ([0-9.]+).*/\1/' | sort -u | tr '\n' ' '
echo
echo "    (Most Duo APIs are iOS 27.1. A lower target means #available / @available guards.)"

echo
echo "## Frameworks in use"
printf '    SwiftUI files: %s\n' "$(search '^import SwiftUI' | wc -l | tr -d ' ')"
printf '    UIKit files:   %s\n' "$(search '^(import UIKit|#import <UIKit)' | wc -l | tr -d ' ')"
printf '    Capture files: %s\n' "$(search 'AVCaptureSession|AVCaptureDevice' | cut -d: -f1 | sort -u | wc -l | tr -d ' ')"

echo
echo "## Layout and resizing                        (references/layout-and-resizing.md)"
check HIGH "Screen-based layout math"            'UIScreen\.main\.(bounds|nativeBounds)|UIScreen\.main\b.*\.(width|height)' layout-and-resizing.md
check HIGH "Idiom used (check if it drives layout)" 'userInterfaceIdiom|UI_USER_INTERFACE_IDIOM' layout-and-resizing.md
check HIGH "Orientation used (check if it drives layout)" 'UIInterfaceOrientation|UIDeviceOrientation|UIDevice\.current\.orientation|interfaceOrientation|\.isLandscape|\.isPortrait' layout-and-resizing.md
check MED  "Hardcoded phone-sized dimensions"    '(width|height|Width|Height)[A-Za-z]*\s*[:=]\s*(320|375|390|393|402|414|428|430|440|568|667|736|812|844|852|874|896|926|932|956)(\.0)?\b' layout-and-resizing.md
check MED  "Deprecated traitCollectionDidChange" 'traitCollectionDidChange' layout-and-resizing.md
check LOW  "Manual frames (check they recompute on layout)" '\.frame\s*=\s*CGRect\(|CGRect\(x:\s*[0-9]' layout-and-resizing.md

echo
echo "## Bars                                       (references/bars.md)"
check HIGH "Hand-built UIKit bars"               '\b(UIToolbar|UINavigationBar|UITabBar)\s*\(' bars.md
check HIGH "Bar items that cannot go vertical (custom view)" 'UIBarButtonItem\(customView:' bars.md
check MED  "Bar items that cannot go vertical (title only, confirm no image)" 'UIBarButtonItem\(title:' bars.md
check MED  "Hidden system navigation bar (is there a homemade replacement?)" 'navigationBarHidden\(true\)|\.toolbar\(\.hidden|toolbarVisibility\(\.hidden|setNavigationBarHidden\(true|isNavigationBarHidden\s*=\s*true' bars.md
check MED  "Possible faux SwiftUI bar"           'safeAreaInset\(edge:\s*\.(top|bottom)' bars.md
check MED  "Homemade ellipsis / more menu (move into system overflow)" 'systemImage:\s*"ellipsis|systemName:\s*"ellipsis' bars.md
check LOW  "Manual toolbar spacing (prefer groups)" '\.fixedSpace|\.flexibleSpace|fixedSpace\(|flexibleSpace\(' bars.md
# Text-only buttons in files that declare a toolbar. Rough: it cannot tell whether
# the button is inside the .toolbar block, so read each one. Buttons with a role:
# are skipped because those are nearly always alert and dialog buttons.
TB_FILES="$(search '\.toolbar\s*\{|ToolbarItem(Group)?\(' | cut -d: -f1 | sort -u)"
if [ -n "$TB_FILES" ]; then
  TEXT_ONLY="$(printf '%s\n' "$TB_FILES" | while IFS= read -r f; do
      grep -nE 'Button\("[^"]+"\)[[:space:]]*\{|Button\("[^"]+", action:' "$f" 2>/dev/null | sed "s|^|$f:|"
    done)"
  if [ -n "$TEXT_ONLY" ]; then
    n="$(printf '%s\n' "$TEXT_ONLY" | wc -l | tr -d ' ')"
    printf '\n[MED] Text-only buttons in files with toolbars (no systemImage; will not go in a vertical bar if they are toolbar items)  (%s hits)  -> bars.md\n' "$n"
    printf '%s\n' "$TEXT_ONLY" | head -n "$MAX" | sed 's/^/    /'
  fi
  TB_COUNT="$(search 'ToolbarItem(Group)?\(' | wc -l | tr -d ' ')"
  PRI_COUNT="$(search 'visibilityPriority' | wc -l | tr -d ' ')"
  if [ "$TB_COUNT" -gt 3 ] && [ "$PRI_COUNT" -eq 0 ]; then
    printf '\n[MED] %s toolbar items and no visibilityPriority anywhere: overflow order on the outer display is the default (bottom to top), not a choice  -> bars.md\n' "$TB_COUNT"
  fi
fi
check INFO "SwiftUI toolbars to review for icon + title, placement, priority" '\.toolbar\s*\{|ToolbarItem(Group)?\(' bars.md

echo
echo "## Fold and cameras                           (references/arrangement-and-reserved-regions.md)"
check INFO "Two-pane or layered custom layouts that may suit an arrangement view" 'UISplitViewController|NavigationSplitView|addChild\(' arrangement-and-reserved-regions.md
check INFO "Full-screen custom surfaces (need reserved regions?)" 'ignoresSafeArea|edgesIgnoringSafeArea|Canvas\s*\{|MTKView|SKView|SCNView|ARView|AVPlayerLayer|VideoPlayer\(' arrangement-and-reserved-regions.md

echo
echo "## Camera                                     (references/camera.md)"
check HIGH "Camera position used (direction, mirroring, selfie UI?)" 'position\s*==\s*\.(front|back)|position:\s*\.(front|back)|\.position\s*!=\s*\.(front|back)' camera.md
check HIGH "Manual mirroring"                    'isVideoMirrored|automaticallyAdjustsVideoMirroring' camera.md
check MED  "Rotation handling"                   'videoOrientation|videoRotationAngle|RotationCoordinator' camera.md
check MED  "Multicam session (not needed for display switching)" 'AVCaptureMultiCamSession' camera.md

echo
echo "## Info.plist and project settings"
for key in UIRequiresFullScreen UISupportedInterfaceOrientations UIApplicationSupportsIndirectInputEvents UIApplicationSceneManifest; do
  hits="$(search_any "$key" '*.plist'; search_any "INFOPLIST_KEY_${key}" '*.pbxproj')"
  if [ -n "$hits" ]; then
    printf '    %s:\n' "$key"; printf '%s\n' "$hits" | head -n 6 | sed 's/^/        /'
  else
    printf '    %s: not found\n' "$key"
  fi
done
echo "    How to read these: UIRequiresFullScreen or a single orientation blocks resizing (fine only for"
echo "    games that lock orientation). A UIKit app with no scene manifest is not scene-based, and the"
echo "    scene lifecycle is what enables resizing and multitasking. SwiftUI App lifecycle needs no manifest."

echo
echo "## Related, lower priority: iPhone Mirroring   (references/layout-and-resizing.md)"
MIRROR="$(search 'deviceOwnerAuthenticationWithBiometrics\b')"
if [ -n "$MIRROR" ]; then
  check LOW "Biometrics policy that fails under Mirroring" 'deviceOwnerAuthenticationWithBiometrics\b' layout-and-resizing.md
else
  echo "    none found"
fi

echo
echo "## Already adopted"
for api in ArrangementView UIArrangementViewController reservedRegions toolbarVerticalEdge verticalBarEdge \
           toolbarVerticalBehavior preferredVerticalBarBehavior toolbarVerticalCompressionBehavior verticalBarCompressionBehavior \
           visibilityPriority axisBehavior ToolbarOverflowMenu additionalOverflowItems topBarPinnedTrailing pinnedTrailingGroup \
           presentationPlacement preferredPlacement backgroundExtensionEffect UIBackgroundExtensionView \
           AVCaptureDeviceDirectionCoordinator CameraCaptureAccessory registerSceneAccessory registerForTraitChanges; do
  n="$(search "\\b${api}\\b" | wc -l | tr -d ' ')"
  [ "$n" -gt 0 ] && { printf '    %-40s %s\n' "$api" "$n"; ADOPTED=1; }
done
[ -z "${ADOPTED:-}" ] && echo "    none of the iPhone Duo APIs are in use yet"

echo
echo "=========================================================="
echo "Static scan finished. It cannot see the fold. Read each hit, then validate"
echo "on the iPhone Duo simulator or a device: references/testing.md"
