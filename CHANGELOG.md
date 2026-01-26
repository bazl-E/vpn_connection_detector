# Changelog

All notable changes to the `vpn_connection_detector` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Released]

## [2.0.1] - 2026-01-21
### Added
- **Native iOS implementation** using `NEVPNManager` for system VPNs and `CFNetworkCopySystemProxySettings` SCOPED dictionary for third-party VPN apps (NordVPN, ExpressVPN, ProtonVPN, etc.) — ~95% accuracy
- **Native Android implementation** using `NetworkCapabilities.TRANSPORT_VPN` API — ~95% accuracy
- New `getVpnInfo()` method to get detailed VPN information (interface name, protocol)
- New `VpnInfo` class with `isConnected`, `interfaceName`, and `vpnProtocol` properties
- New `currentState` getter for accessing cached VPN state
- Platform interface architecture for better maintainability
- Dart fallback for desktop platforms (macOS, Windows, Linux)
- Real-time VPN status monitoring with `NWPathMonitor` (iOS) and network callbacks (Android)
- Comprehensive unit tests

### Changed
- Singleton now properly resets after `dispose()` is called
- Stream now emits initial state immediately on subscription
- Improved VPN interface pattern matching with more VPN types (NordVPN, ProtonVPN, Tailscale, etc.)
- Updated minimum iOS version to 12.0
- Updated minimum Android SDK to 21

### Removed
- Web platform support (VPN detection is not possible in browsers)

### Fixed
- Fixed singleton not being recreatable after dispose
- Fixed stream not emitting initial state

## [1.0.11] - 2026-01-21
### Changed
- Bumped package version to `1.0.11`.
- Updated dependency: `connectivity_plus` -> `^7.0.0`.



## [1.0.10] - 2025-07-23
### Fixed
- connectivity_plus updated to 6.1.4
## [1.0.9] - 2024-09-27
### Fixed
- ignore false detection by mistake in iOS 17.0 and later

- connectivity_plus updated to 6.0.5

## [1.0.8] - 2024-03-26
### Fixed
- ignore false detection by mistake in iOS 17.0 and later

- connectivity_plus updated to 6.0.1.

## [1.0.7] - 2024-03-26
### Updated

- connectivity_plus updated to 6.0.1.

## [1.0.6] - 2023-10-17
### Updated

- connectivity_plus updated to 5.0.2.

## [1.0.5] - 2023-10-17
### Updated

- connectivity_plus updated to 5.0.1.

## [1.0.4] - 2023-08-21
### Fixed

- Improved code.
- Updated Documentation.

## [1.0.3] - 2023-08-21
### Fixed

- Fixed a bug .
## [1.0.2] - 2023-08-21

### Added

- Initial release of the `vpn_connection_detector` package.
- Detects VPN connection status.
- Detects changes in VPN connectivity.
- Allows custom time intervals for checking VPN status.
- Designed as a singleton for efficient resource management.

## [0.1.0] - 2023-08-21

### Added

- Created the project repository on GitHub.

### Changed

- Updated the project structure.

### Fixed

- Fixed a bug related to VPN status detection.

[Released]: https://github.com/bazl-E/vpn_connection_detector/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/bazl-E/vpn_connection_detector/releases/tag/v1.0.0
