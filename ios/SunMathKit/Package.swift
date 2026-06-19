// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SunMathKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "SunMathKit", targets: ["SunMathKit"])],
    targets: [
        .target(name: "SunMathKit"),
        .testTarget(name: "SunMathKitTests", dependencies: ["SunMathKit"]),
    ]
)
