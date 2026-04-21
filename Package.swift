// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExDisj",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ExDisj",
            targets: ["ExDisj"]
        ),
        .library(
            name: "HelpKit",
            targets: ["HelpKit"]
        ),
        .library(
            name: "UniqueKit",
            targets: ["UniqueKit"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ExDisj"
        ),
        .target(
            name: "HelpKit",
            dependencies: [.byNameItem(name: "ExDisj", condition: nil)]
        ),
        .target(
            name: "UniqueKit",
            dependencies: [.byNameItem(name: "ExDisj", condition: nil)]
        ),
        .testTarget(
            name: "Tests",
            dependencies: [
                .byNameItem(name: "ExDisj", condition: nil),
                .byNameItem(name: "UniqueKit", condition: nil),
                .byNameItem(name: "HelpKit", condition: nil)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
