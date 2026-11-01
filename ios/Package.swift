// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "XtlLiveness",
    platforms: [.iOS(.v13), .macOS(.v11)],   // macOS only so the rules can be tested with `swift test` on a Mac
    products: [.library(name: "XtlLiveness", targets: ["XtlLiveness"])],
    targets: [
        .target(name: "XtlLiveness"),
        .testTarget(name: "XtlLivenessTests", dependencies: ["XtlLiveness"]),
    ]
)
