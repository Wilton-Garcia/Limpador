// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Limpador",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Limpador", targets: ["Limpador"])],
    targets: [.executableTarget(name: "Limpador"), .testTarget(name: "LimpadorTests", dependencies: ["Limpador"])]
)
