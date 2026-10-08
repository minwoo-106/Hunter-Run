// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "HunterRun", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "HunterCore", targets: ["HunterCore"]),
               .library(name: "OperatorLifeCore", targets: ["OperatorLifeCore"])],
    targets: [.target(name: "HunterCore"), .target(name: "OperatorLifeCore"),
              .testTarget(name: "HunterCoreTests", dependencies: ["HunterCore"], exclude: ["Fixtures"]),
              .testTarget(name: "OperatorLifeCoreTests", dependencies: ["OperatorLifeCore"])])
