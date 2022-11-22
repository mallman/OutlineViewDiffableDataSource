// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OutlineViewDiffableDataSource",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OutlineViewDiffableDataSource",
            targets: ["OutlineViewDiffableDataSource"]
        )
    ],
    targets: [
        .target(
            name: "OutlineViewDiffableDataSource",
            path: "Sources"
        ),
        .testTarget(
            name: "OutlineViewDiffableDataSourceTests",
            dependencies: [
                .target(name: "OutlineViewDiffableDataSource")
            ],
            path: "Tests"
        )
    ]
)
