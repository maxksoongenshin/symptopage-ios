// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "SymptoPage", platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "SymptoCore", targets: ["SymptoCore"]),
    .executable(name: "SymptoPagePreview", targets: ["SymptoPagePreview"]),
  ],
  targets: [
    .target(name: "SymptoCore", path: "Core"),
    .executableTarget(
      name: "SymptoPagePreview", dependencies: ["SymptoCore"], path: "App", exclude: ["Resources"]),
    .testTarget(name: "SymptoCoreTests", dependencies: ["SymptoCore"], path: "Tests"),
  ])
