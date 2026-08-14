// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeriMediDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PeriMediDomain", targets: ["PeriMediDomain"]),
    ],
    targets: [
        .target(name: "PeriMediDomain"),
        .testTarget(
            name: "PeriMediDomainTests",
            dependencies: ["PeriMediDomain"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
