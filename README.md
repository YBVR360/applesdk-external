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
[ybvr360.github.io/AppleSDK](https://ybvr360.github.io/AppleSDK/).

## Examples

`Examples/` contains demo apps for iOS and visionOS. They use the package from
this repository, so open `Examples/iOS/DemoApp/DemoApp.xcodeproj` or
`Examples/visionOS/DemoApp/DemoApp.xcodeproj` in Xcode and run.
