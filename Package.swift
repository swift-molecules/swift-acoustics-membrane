// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-acoustics-membrane",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Acoustics Membrane", targets: ["Acoustics Membrane"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-molecules/swift-acoustics.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-bessel.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-angle.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-decay.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-density.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-frequency.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-space.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-wavenumber.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Acoustics Membrane",
            dependencies: [
                .product(name: "Acoustics", package: "swift-acoustics"),
                .product(name: "Bessel", package: "swift-bessel"),
                .product(name: "Cardinal", package: "swift-cardinal"),
                .product(name: "Angle", package: "swift-angle"),
                .product(name: "Decay", package: "swift-decay"),
                .product(name: "Density", package: "swift-density"),
                .product(name: "Frequency", package: "swift-frequency"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "Space", package: "swift-space"),
                .product(name: "Wavenumber", package: "swift-wavenumber"),
            ]
        ),
        .testTarget(
            name: "Acoustics Membrane Tests",
            dependencies: [
                .target(name: "Acoustics Membrane")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
