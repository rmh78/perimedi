// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeriDesign",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "PeriDesign", targets: ["PeriDesign"]),
    ],
    targets: [
        .target(name: "PeriDesign"),
    ]
)
