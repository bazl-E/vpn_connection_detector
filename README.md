# VPN Connection Detector

**The most accurate VPN detection package for Flutter** — with native iOS & Android implementations that detect both system-configured VPNs and third-party VPN apps like NordVPN, ExpressVPN, ProtonVPN, and more.

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
- ✅ **Dart fallback** for desktop platforms (macOS, Windows, Linux)
- ✅ **Real-time streaming** of VPN connection status changes
- ✅ **One-time checks** via static method
- ✅ **Detailed VPN info** including interface name and protocol
- ✅ **Singleton pattern** for efficient resource management
- ✅ **App Store safe** — no private APIs or restricted entitlements required

## Platform Support

| Platform | Native | Accuracy | Notes |
|----------|--------|----------|-------|
| iOS | ✅ | ~95% | Uses CFNetworkCopySystemProxySettings & NWPathMonitor |
| Android | ✅ | ~95% | Uses NetworkCapabilities API |
| macOS | ❌ | ~70-80% | Dart fallback (interface name matching) |
| Windows | ❌ | ~70-80% | Dart fallback |
| Linux | ❌ | ~70-80% | Dart fallback |

## Getting Started

### Installation

Add `vpn_connection_detector` to your `pubspec.yaml`:

```yaml
dependencies:
  vpn_connection_detector: ^2.0.1
```

### Android Setup

Add the following permission to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS Setup

No additional setup required. The plugin uses system frameworks that are available by default.

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

### Detect System Proxies (NEW in 2.1.0)

A proxy is **not** the same as a VPN. `isVpnActive()` will return `false` for a
device that only has an HTTP proxy configured (e.g. Charles, mitmproxy,
corporate proxy). Use the dedicated proxy APIs for that:

```dart
// Quick check: is there an HTTP / HTTPS / SOCKS / PAC proxy configured?
final hasProxy = await VpnConnectionDetector.isProxyActive();

// Detailed info
final proxy = await VpnConnectionDetector.getProxyInfo();
if (proxy != null && proxy.isActive) {
  print('Proxy: ${proxy.host}:${proxy.port} (${proxy.proxyType?.name})');
  if (proxy.pacUrl != null) print('PAC: ${proxy.pacUrl}');
}

// Security check: detect ANY form of traffic interception (VPN or proxy)
if (await VpnConnectionDetector.isTrafficInterceptionActive()) {
  // Warn the user that their traffic may be inspected.
}
```

**How it works:**

| Platform | Proxy API |
|----------|-----------|
| iOS / macOS | `CFNetworkCopySystemProxySettings()` + official `kCFNetworkProxies*` constants |
| Android (API 23+) | `ConnectivityManager.getDefaultProxy()` |
| Desktop / fallback | `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` env vars |

### Access Current Cached State

```dart
final vpnDetector = VpnConnectionDetector();

// Get the last known state (may be null if not yet determined)
final currentState = vpnDetector.currentState;
print('Current state: ${currentState?.name ?? "unknown"}');
```

## API Reference

### VpnConnectionDetector

| Method/Property | Type | Description |
|----------------|------|-------------|
| `isVpnActive()` | `static Future<bool>` | One-time check if VPN is active |
| `getVpnInfo()` | `static Future<VpnInfo?>` | Get detailed VPN information |
| `isProxyActive()` | `static Future<bool>` | One-time check if a system proxy is configured |
| `getProxyInfo()` | `static Future<ProxyInfo?>` | Get detailed system-proxy information |
| `isTrafficInterceptionActive()` | `static Future<bool>` | `true` when **either** VPN or proxy is active |
| `vpnConnectionStream` | `Stream<VpnConnectionState>` | Real-time status stream |
| `currentState` | `VpnConnectionState?` | Last known VPN state |
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
}
```

### ProxyInfo & ProxyType

```dart
enum ProxyType { http, https, socks, pac }

class ProxyInfo {
  final bool isActive;          // Whether a system proxy is configured
  final String? host;           // Proxy host (null for PAC)
  final int? port;              // Proxy port (null for PAC)
  final ProxyType? proxyType;   // http / https / socks / pac
  final String? pacUrl;         // PAC script URL (only for ProxyType.pac)
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

### Desktop (Fallback)
Inspects network interface names for common VPN patterns (`tun`, `tap`, `ppp`, `wireguard`, etc.).

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
