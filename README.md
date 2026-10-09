# YBVRAppleSDK

YBVRAppleSDK plays YBVR multi-camera and immersive video in iOS and visionOS apps.

## Requirements

- iOS 17 or later, or visionOS 26 or later
- Xcode 26 or later

## Installation

The SDK is distributed as a Swift package of prebuilt frameworks.

### Xcode

1. Choose **File › Add Package Dependencies…**
2. Enter `https://github.com/YBVR360/applesdk-external`.
3. Choose a version rule. **Up to Next Major Version** is recommended.
4. Add the **YBVRAppleSDK** library to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/YBVR360/applesdk-external", from: "30.1.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "YBVRAppleSDK", package: "applesdk-external")
        ]
    )
]
```

Replace `30.1.0` with the version you want to use. Available versions are listed
on the [Releases](https://github.com/YBVR360/applesdk-external/releases) page.

Then import the SDK:

```swift
import YBVRAppleSDK
```

## Documentation

The API reference and guides are at
[ybvr360.github.io/applesdk-external](https://ybvr360.github.io/applesdk-external/),
with the visionOS reference at
[ybvr360.github.io/applesdk-external/visionos](https://ybvr360.github.io/applesdk-external/visionos/).
They describe the latest release. Each release also includes its documentation in
`docs/`.

## Examples

`Examples/` contains the Sample Scene app for iOS and visionOS. It uses the
package from this repository, so clone it and open the app in Xcode:

```sh
git clone https://github.com/YBVR360/applesdk-external
open applesdk-external/Examples/iOS/SampleScene/SampleScene-iOS.xcodeproj
```

For visionOS, open `Examples/visionOS/SampleScene/SampleScene-VisionOS.xcodeproj`
instead.

Open the app from a clone, not from the copy Xcode downloads when you add the
package to your app. Xcode keeps that copy read-only, so it reports that
`project.xcworkspace` could not be unlocked.

To run the app on a device:

1. Select your own team under **Signing & Capabilities**.
2. Set `BUNDLE_ID` in `Examples/SampleScene.xcconfig` to a bundle identifier of
   your own. The one it ships with belongs to YBVR, so Xcode can't sign it for
   your team.
