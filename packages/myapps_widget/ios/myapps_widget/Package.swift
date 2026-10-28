// swift-tools-version: 5.9
// MyApps-Widget's iOS bridge: stores widget envelopes in the app's App Group
// and reloads WidgetKit timelines. See doc/en-us/architecture.md.

import PackageDescription

let package = Package(
    name: "myapps_widget",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "myapps-widget", targets: ["myapps_widget"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "myapps_widget",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
            // WidgetKit is referenced only behind `#available(iOS 14.0, *)`,
            // so the linker weak-links it without a linker setting.
        )
    ]
)
