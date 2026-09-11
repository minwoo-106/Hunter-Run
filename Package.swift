// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HunterRun", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "HunterCore", targets: ["HunterCore"])], targets: [.target(name: "HunterCore"), .testTarget(name: "HunterCoreTests", dependencies: ["HunterCore"])])

