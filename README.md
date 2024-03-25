# VPN Connection Detector

The `vpn_connection_detector` package provides a simple and efficient way to detect VPN connection status in a Dart/Flutter application. It includes a singleton class, `VpnConnectionDetector`, that offers a stream of VPN connection states and a method to check the VPN connection status.

## Features

- Detect VPN connection status with ease.
- Detect changes in VPN connectivity and trigger events accordingly.
- Designed as a singleton for efficient resource management.

## Getting Started

### Installation

Add the `vpn_connection_detector` package to your `pubspec.yaml`:

```yaml
dependencies:
  vpn_connection_detector: ^1.0.7 # Use the latest version
```

### Usage
Import the `package` package in your `Dart/Flutter` file:
```
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
```

Create a `VpnConnectionDetector` Instance
```
final vpnDetector = VpnConnectionDetector();
```
### Access the VPN Connection Stream
```
vpnDetector.vpnConnectionStream.listen((state) {
  if (state == VpnConnectionState.connected) {
    print("VPN connected.");
    // Handle VPN connected event
  } else {
    print("VPN disconnected.");
    // Handle VPN disconnected event
  }
});
```
### Check the VPN Connection Status Manually
```
bool isVpnConnected = await VpnConnectionDetector.isVpnActive();
```

### Dispose of the VpnConnectionDetector Instance
If using `vpnConnectionStream`, remember to `dispose`. Otherwise, use `VpnConnectionDetector.isVpnActive()` function without concerns.
```
vpnDetector.dispose();
```
### Example

For a complete example of how to use this package, please refer to the example directory.

### Contributions

Contributions are welcome! If you encounter any issues, have suggestions, or want to contribute to the project, please feel free to create issues, submit pull requests, or reach out to us.

### License

This package is distributed under the MIT License. See LICENSE for more details.

Enjoy detecting your VPN connections with ease using the `vpn_connection_detector` package!
