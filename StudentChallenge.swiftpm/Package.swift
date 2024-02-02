// swift-tools-version: 5.8

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "StudentChallenge",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "StudentChallenge",
            targets: ["AppModule"],
            bundleIdentifier: "dev.stackotter.StudentChallenge",
            teamIdentifier: "2W73HS7DLT",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .map),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            appCategory: .developerTools
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)