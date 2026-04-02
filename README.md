# VPN Connection Detector

**The most accurate VPN detection package for Flutter** — with native iOS, Android & macOS implementations that detect both system-configured VPNs and third-party VPN apps like NordVPN, ExpressVPN, ProtonVPN, and more.

[![pub package](https://img.shields.io/pub/v/vpn_connection_detector.svg)](https://pub.dev/packages/vpn_connection_detector)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Why This Package?

Most VPN detection solutions only check for system-configured VPNs, missing the majority of users who use third-party VPN apps. This package uses **platform-native APIs** to detect VPNs with ~95% accuracy:

- 🔍 **Detects third-party VPN apps** (NordVPN, ExpressVPN, Surfshark, ProtonVPN, etc.)
- 🔍 **Detects system-configured VPNs** (IKEv2, IPSec, WireGuard profiles)
- 🔍 **Detects corporate VPNs** (Cisco AnyConnect, OpenVPN, etc.)
- ⚡ **Real-time monitoring** with stream-based updates
- 🎯 **No false positives** from system network interfaces

## Features

- ✅ **Native iOS detection** using `CFNetworkCopySystemProxySettings` and `NWPathMonitor`
- ✅ **Native Android detection** using `NetworkCapabilities.TRANSPORT_VPN`
- ✅ **Native macOS detection** using `CFNetworkCopySystemProxySettings` and `NWPathMonitor`
- ✅ **Dart fallback** for desktop platforms (Windows, Linux)
- ✅ **Real-time streaming** of VPN connection status changes
- ✅ **One-time checks** via static method
- ✅ **Detailed VPN info** including interface name and protocol
- ✅ **Multiple VPN detection** — detect all active VPN connections simultaneously
- ✅ **Connection tracking** — know when VPN was first detected
- ✅ **Singleton pattern** for efficient resource management
- ✅ **App Store safe** — no private APIs or restricted entitlements required

## Platform Support

| Platform | Native | Accuracy | Notes |
|----------|--------|----------|-------|
| iOS | ✅ | ~95% | Uses CFNetworkCopySystemProxySettings & NWPathMonitor |
| Android | ✅ | ~95% | Uses NetworkCapabilities API |
| macOS | ✅ | ~95% | Uses CFNetworkCopySystemProxySettings & NWPathMonitor |
| Windows | ❌ | ~70-80% | Dart fallback |
| Linux | ❌ | ~70-80% | Dart fallback |

## Getting Started

### Installation

Add `vpn_connection_detector` to your `pubspec.yaml`:

```yaml
dependencies:
  vpn_connection_detector: ^2.0.3
```

### Android Setup

Add the following permission to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS Setup

No additional setup required. The plugin uses system frameworks that are available by default.

### macOS Setup

No additional setup required. The plugin uses the same system frameworks as iOS.

## Usage

### Import the package

```dart
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
```

### One-time VPN Check

```dart
// Check if VPN is currently active
bool isVpnConnected = await VpnConnectionDetector.isVpnActive();

if (isVpnConnected) {
  print('VPN is connected');
} else {
  print('VPN is not connected');
}
```

### Real-time VPN Status Stream

```dart
final vpnDetector = VpnConnectionDetector();

// Listen to VPN status changes
vpnDetector.vpnConnectionStream.listen((state) {
  switch (state) {
    case VpnConnectionState.connected:
      print('VPN connected');
      break;
    case VpnConnectionState.disconnected:
      print('VPN disconnected');
      break;
  }
});

// Don't forget to dispose when done
vpnDetector.dispose();
```

### Get Detailed VPN Information

```dart
final info = await VpnConnectionDetector.getVpnInfo();

if (info != null && info.isConnected) {
  print('VPN Connected');
  print('Interface: ${info.interfaceName}');  // e.g., 'utun3', 'tun0'
  print('Protocol: ${info.vpnProtocol}');     // e.g., 'WireGuard', 'IKEv2'
}
```

### Access Current Cached State

```dart
final vpnDetector = VpnConnectionDetector();

// Get the last known state (may be null if not yet determined)
final currentState = vpnDetector.currentState;
print('Current state: ${currentState?.name ?? "unknown"}');
```

### Get All Active VPN Connections

```dart
// Useful when device has multiple VPNs (e.g., corporate + personal)
final vpns = await VpnConnectionDetector.getAllVpnInfo();

for (final vpn in vpns) {
  print('Interface: ${vpn.interfaceName}, Protocol: ${vpn.vpnProtocol}');
}
```

### Connection Event Callbacks

```dart
final vpnDetector = VpnConnectionDetector();

// Register callback for VPN connect events
final connectSub = vpnDetector.onVpnConnected(() {
  print('VPN just connected!');
  print('Connected since: ${vpnDetector.connectedSince}');
});

// Register callback for VPN disconnect events
final disconnectSub = vpnDetector.onVpnDisconnected(() {
  print('VPN just disconnected!');
});

// Don't forget to cancel subscriptions when done
connectSub.cancel();
disconnectSub.cancel();
```

### Track Connection Duration

```dart
final vpnDetector = VpnConnectionDetector();

// Get when the current VPN connection was first detected
if (vpnDetector.connectedSince != null) {
  final duration = DateTime.now().difference(vpnDetector.connectedSince!);
  print('VPN has been connected for ${duration.inMinutes} minutes');
}
```

## API Reference

### VpnConnectionDetector

| Method/Property | Type | Description |
|----------------|------|-------------|
| `isVpnActive()` | `static Future<bool>` | One-time check if VPN is active |
| `getVpnInfo()` | `static Future<VpnInfo?>` | Get detailed VPN information |
| `getAllVpnInfo()` | `static Future<List<VpnInfo>>` | Get all active VPN connections |
| `vpnConnectionStream` | `Stream<VpnConnectionState>` | Real-time status stream |
| `currentState` | `VpnConnectionState?` | Last known VPN state |
| `connectedSince` | `DateTime?` | When current VPN was first detected |
| `onVpnConnected()` | `StreamSubscription` | Callback when VPN connects |
| `onVpnDisconnected()` | `StreamSubscription` | Callback when VPN disconnects |
| `dispose()` | `void` | Clean up resources |

### VpnConnectionState

```dart
enum VpnConnectionState {
  connected,    // VPN is currently connected
  disconnected, // VPN is currently disconnected
}
```

### VpnInfo

```dart
class VpnInfo {
  final bool isConnected;       // Whether VPN is connected
  final String? interfaceName;  // Network interface name (e.g., 'utun3')
  final String? vpnProtocol;    // Detected VPN protocol (e.g., 'WireGuard')
  final DateTime? connectedSince; // When the connection was first detected
}
```

## Example

See the [example](example/) directory for a complete sample app.

```dart
import 'package:flutter/material.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

class VpnStatusWidget extends StatelessWidget {
  final _vpnDetector = VpnConnectionDetector();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VpnConnectionState>(
      stream: _vpnDetector.vpnConnectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data == VpnConnectionState.connected;
        
        return Icon(
          isConnected ? Icons.vpn_lock : Icons.vpn_lock_outlined,
          color: isConnected ? Colors.green : Colors.grey,
        );
      },
    );
  }
}
```

## Migration from v1.x

Version 2.0 introduces native platform support with a cleaner API:

```dart
// v1.x (still works)
final isActive = await VpnConnectionDetector.isVpnActive();
final detector = VpnConnectionDetector();
detector.vpnConnectionStream.listen((state) { ... });

// v2.0 (new features)
final info = await VpnConnectionDetector.getVpnInfo();
print('Protocol: ${info?.vpnProtocol}');
```

**Breaking changes:**
- Minimum iOS version: 12.0
- Minimum Android SDK: 21
- Removed web platform support (not possible to detect VPN in browsers)

## How It Works

### iOS
1. **VPN detection**: Uses `CFNetworkCopySystemProxySettings` to inspect the `__SCOPED__` dictionary, which only contains active VPN network interfaces — this reliably detects both system-configured VPNs and third-party apps like NordVPN, ExpressVPN, ProtonVPN, Surfshark, etc.
2. **Real-time monitoring**: Uses `NWPathMonitor` to detect network changes and re-evaluate VPN status
3. **App Store safe**: Does not use `NEVPNManager` or any APIs that require the Network Extension entitlement

### Android
Uses `ConnectivityManager` with `NetworkCapabilities.TRANSPORT_VPN` for accurate VPN detection on API 23+. This detects all VPN connections regardless of the VPN app used.

### macOS
Uses the same `CFNetworkCopySystemProxySettings` SCOPED dictionary approach as iOS, providing accurate detection of all VPN types on macOS. Real-time monitoring via `NWPathMonitor`.

### Desktop Fallback (Windows, Linux)
Inspects network interface names for common VPN patterns (`tun`, `tap`, `ppp`, `wireguard`, etc.).

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
