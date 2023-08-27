import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

///[VpnConnectionState] has two values [connected],[disconnected]
///return [VpnConnectionState.connected] if vpn connection is active
///return [VpnConnectionState.disconnected] if vpn not available or disconnected

enum VpnConnectionState {
  /// The VPN is currently connected.
  connected,

  /// The VPN is currently disconnected.
  disconnected
}

///[VpnConnectionDetector]Singleton class which includes stream of vpn connection states
///also includes a single time check method [Future<bool> isVpnActive()]
class VpnConnectionDetector {
  /// Creates or retrieves an instance of the VpnConnectionDetector singleton.
  factory VpnConnectionDetector() {
    _instance ??= VpnConnectionDetector._private();
    return _instance!;
  }
  // Private constructor for the singleton
  VpnConnectionDetector._private() {
    // Listen to network connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      await _checkVpnStatus();
    });
  }
  final StreamController<VpnConnectionState> _controller =
      StreamController.broadcast();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  ///Check weather a vpn is connected or not which returns a bool
  ///No need to use [dispose] if you are only using [isVpnActive] it is static method
  ///if you are using the [vpnConnectionStream] u have to call [dispose]
  static Future<bool> isVpnActive() async {
    try {
      final interfaces = await NetworkInterface.list();

      return interfaces.any((interface) => _commonVpnInterfaceNamePatterns
          .any((pattern) => interface.name.toLowerCase().contains(pattern)));
    } catch (e) {
      // Handle exceptions, e.g., if the network interface list cannot be retrieved
      return false;
    }
  }

  // Singleton instance
  static VpnConnectionDetector? _instance;

  /// Returns a stream of [VpnConnectionState]s that updates whenever there's an update in VPN connection status =
  Stream<VpnConnectionState> get vpnConnectionStream =>
      _controller.stream.asBroadcastStream();

  Future<void> _checkVpnStatus() async {
    final currentVpnStatus = await isVpnActive();
    if (currentVpnStatus) {
      _controller.add(VpnConnectionState.connected);
    } else {
      _controller.add(VpnConnectionState.disconnected);
    }
  }

  /// Dispose all the Connection streams
  /// use [dispose] only if you are using the [vpnConnectionStream]
  void dispose() {
    _controller.close();
    _connectivitySubscription?.cancel();
  }

  static final List<String> _commonVpnInterfaceNamePatterns = [
    'tun', // Linux/Unix TUN interface
    'tap', // Linux/Unix TAP interface
    'ppp', // Point-to-Point Protocol
    'pptp', // PPTP VPN
    'l2tp', // L2TP VPN
    'ipsec', // IPsec VPN
    'vpn', // Generic "VPN" keyword
    'wireguard', // WireGuard VPN
    'openvpn', // OpenVPN VPN
    'softether', // SoftEther VPN
  ];
}
