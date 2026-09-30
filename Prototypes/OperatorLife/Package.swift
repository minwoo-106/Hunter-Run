// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "OperatorLifePrototype", products: [.library(name: "OperatorLifePrototypeCore", targets: ["OperatorLifePrototypeCore"])], targets: [
    .target(name: "OperatorLifePrototypeCore", path: "Core"),
    .testTarget(name: "OperatorLifePrototypeTests", dependencies: ["OperatorLifePrototypeCore"], path: "Tests")
])
