// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FileTransferApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FileTransferApp", targets: ["FileTransferApp"])
    ],
    targets: [
        .executableTarget(name: "FileTransferApp")
    ]
)
