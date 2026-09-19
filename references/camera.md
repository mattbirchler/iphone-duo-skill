# Camera on iPhone Duo

Only relevant when the app uses AVFoundation or AVKit capture. If the app only
uses `PhotosPicker`, `UIImagePickerController`, or the system camera UI, skip
this file. Verbatim Apple pages, including full sample code, are in `apple/`:

- `apple/documentation_avkit_choosing-a-camera-by-the-direction-it-faces.md`
- `apple/documentation_avfoundation_registering-a-camera-capture-accessory-on-iphone-duo.md`
- `apple/documentation_avkit_avcapturedevicedirectioncoordinator.md`

## What changed

iPhone Duo has three capture locations: outer display camera, inner display
camera, rear cameras. On a normal iPhone, `AVCaptureDevice.position` tells you
both where a camera sits and which way it points. On iPhone Duo it only tells
you **where it sits**. Which way it faces depends on which display the app is
on. Open or close the device and a camera that faced the user now faces away. A
rear camera can be the one facing the user, which is how a rear-camera selfie
works.

## Level 1: existing front-camera apps keep working

Discover the front camera the usual way:

```swift
AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
    mediaType: .video,
    position: .front)
```

On iPhone Duo those types return the **virtual front camera**. It streams from
the camera above whichever display the app is on and follows the app as the
device opens and closes. `isVirtualDevice` is `true`; `activePrimaryConstituent`
says which physical camera is streaming (nil until the session runs). Its
capabilities are the intersection of both cameras.

Audit point: code that assumes the front camera is not a virtual device, or
that force-unwraps a specific constituent, needs attention.

## Level 2: capture-first apps follow direction themselves

Use the physical cameras `.builtInOuterUltraWideCamera` and
`.builtInInnerUltraWideCamera` for full capabilities, and an
`AVCaptureDeviceDirectionCoordinator` (AVKit, iOS 27.1) to learn which way each
camera faces relative to your preview view.

Rules from Apple's article:

- Create the coordinator **on the main actor**, passing the preview view, every
  built-in device type you capture from **including rear cameras**, and a change
  handler. Hold a strong reference while the view is onscreen.
- The coordinator ignores external, Continuity, and Desk View cameras, and
  leaves out the virtual front camera. List the two physical front cameras
  instead.
- One coordinator per preview view. An app previewing on both displays needs
  two, and the same rear camera will be forward facing for one and backward
  facing for the other.
- The handler fires once soon after creation, then on every change. Until then
  `deviceDirections` is an empty map.
- The map has `forwardFacingDeviceDescriptors` and
  `backwardFacingDeviceDescriptors`. "Forward" means facing the same way as your
  view, which is **not** the same as `position == .front`.
- When the active camera is no longer in the forward array, pick a replacement
  from it. Handle the case where nothing faces forward.
- **Do not call AVFoundation from the change handler.** Descriptors and maps are
  `Sendable`. Pass the descriptor to the actor that owns the session and resolve
  it there with `AVCaptureDevice(uniqueID:)`. That can return nil because the
  camera set may have changed again, so never force-unwrap.
- Swap a single video input. Do not reach for a multicam session for this.

## Mirroring

Decide mirroring from the direction map, not from `position`. The connection
auto-mirrors anything with `position == .front`, which is wrong when position
and direction disagree.

- Rear camera facing forward: mirror it yourself so the selfie looks right.
- Front camera facing backward: show it unmirrored.
- Set `automaticallyAdjustsVideoMirroring = false` **before** assigning
  `isVideoMirrored`, or it raises an exception. Check
  `isVideoMirroringSupported` first.
- Reapply on every new map **and** after swapping inputs, because a new input
  creates a new preview connection without your override.

## Rotation and switching

- Use `AVCaptureDevice.RotationCoordinator` for preview and capture angles. The
  angle also changes when the app moves between displays. Create a **new
  rotation coordinator every time the camera changes**.
- Switching cameras takes time and stale frames leak through. Mask the preview
  when the handler fires and unmask after the new device delivers frames.
- Write one code path. On single-display iPhones the coordinator reports front
  cameras as forward, back cameras as backward, and calls the handler once.

## Camera capture accessory: content on the outer display

When the device is fully open and the app is capturing, the system can show
your content on the outer display, facing the subject (a teleprompter, a
countdown, a framing preview).

| | SwiftUI | UIKit |
| --- | --- | --- |
| Declare | `.sceneAccessory { CameraCaptureAccessory { ScriptView(model: m) } }` on the capture view | `registerSceneAccessory(UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:))` on the capture view controller |
| Availability | `.onAvailabilityChange { isAvailable in ... }` | `registration.isAvailable`, observable, read it in `updateProperties()` |
| User toggle | `CameraCaptureAccessory(isEnabled: $binding) { ... }` | `registration.isEnabled` |

Rules:

- The system decides when and where to present. The app passes no display,
  session, or camera. Presentation needs: device open, app in foreground,
  capture session running, capture UI on the inner display.
- It is an enhancement. Every essential control stays in the main capture UI.
  The system can withdraw the accessory at any time.
- Touch works, but keep interaction minimal (tap to focus, play/pause).
- Share one model object between the capture UI and the accessory instead of
  messaging. In UIKit pass it as `userInfo`, read it back from
  `connectionOptions.sceneAccessoryUserInfo`, and keep your own strong
  reference.
- UIKit: hold the `UISceneAccessoryRegistration` strongly. Call
  `unregisterSceneAccessory(_:)` when the feature goes away; use `isEnabled`
  for a user-facing off switch. Accessory scenes have no scene manifest entry.
  Identify them by session role `.windowCameraCaptureAccessory`.
- The top-most registration wins. Navigating to another view that registers
  one makes the previous one unavailable until you come back.

## Testing limits

The simulator has no camera. Accessory layout and shared state can be checked in
previews and the simulator, but anything that depends on capture (direction
changes, mirroring, the accessory actually appearing) **must be tested on a real
iPhone Duo**. Note too that Device Hub cannot use the camera or microphone while
it is mirroring a physical device's screen, so drive camera tests on the device
itself. If no device is available, say so plainly in the report and list exactly
what was not verified.

## Audit checklist

- [ ] Any `position == .front` / `.back` check used to decide **direction**,
      mirroring, or UI ("selfie mode")
- [ ] `isVideoMirrored` set without the direction map
- [ ] Rotation handled with a coordinator that is recreated on camera switch
- [ ] Camera switch UI assumes exactly two cameras (front, back)
- [ ] Force-unwrapped `AVCaptureDevice` lookups
- [ ] AVFoundation work done on the main actor from UI callbacks
- [ ] Would a camera capture accessory help this app's subject?
