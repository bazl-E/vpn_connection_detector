import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'vpn_connection_detector_platform_interface.dart';

/// A pure Dart implementation of VPN detection.
///
/// This is used as a fallback for platforms that don't have native support
/// (Linux, Windows, macOS) or when native implementation fails.
class DartVpnConnectionDetector extends VpnConnectionDetectorPlatform {
  /// Stream controller for VPN status changes
  StreamController<bool>? _statusController;

  /// Connectivity subscription
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Cached status stream
  Stream<bool>? _statusStream;

  /// Last known VPN status
  bool _lastKnownStatus = false;

  /// Common VPN interface name patterns
  static final List<String> _vpnInterfacePatterns = [
    'tun', // Linux/Unix TUN interface
    'tap', // Linux/Unix TAP interface
    'ppp', // Point-to-Point Protocol
    'pptp', // PPTP VPN
    'l2tp', // L2TP VPN
    'ipsec', // IPsec VPN
    'vpn', // Generic "VPN" keyword
    'wireguard', // WireGuard VPN
    'wg', // WireGuard shorthand
    'openvpn', // OpenVPN
    'softether', // SoftEther VPN
    'nordlynx', // NordVPN's WireGuard implementation
    'proton', // ProtonVPN
    'mullvad', // Mullvad VPN
    'tailscale', // Tailscale
    'zerotier', // ZeroTier
    'gpd', // Global Protect
    'cisco', // Cisco AnyConnect
    'fortinet', // Fortinet VPN
    'forticlient', // FortiClient
  ];

  /// iOS-specific patterns to ignore (these appear even without VPN on iOS 17+)
  static final List<String> _iosIgnorePatterns = [
    'ipsec',
    'utun6',
    'ikev2',
    'l2tp',
  ];

  @override
  Future<bool> isVpnActive() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );

      final isIos = Platform.isIOS;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Check if this interface matches any VPN pattern
        for (final pattern in _vpnInterfacePatterns) {
          if (name.contains(pattern)) {
            // On iOS, skip known false-positive patterns
            if (isIos && _shouldIgnoreOnIos(name)) {
              continue;
            }
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      // If we can't list interfaces, assume no VPN
      return false;
    }
  }

  /// Check if the interface should be ignored on iOS
  bool _shouldIgnoreOnIos(String interfaceName) {
    return _iosIgnorePatterns.any((pattern) => interfaceName.contains(pattern));
  }

  @override
  Stream<bool> get vpnStatusStream {
    if (_statusStream != null) {
      return _statusStream!;
    }

    _statusController = StreamController<bool>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );

    _statusStream = _statusController!.stream;
    return _statusStream!;
  }

  Future<void> _startListening() async {
    // Emit initial status
    _lastKnownStatus = await isVpnActive();
    _statusController?.add(_lastKnownStatus);

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) async {
      await _checkAndEmitStatus();
    });
  }

  Future<void> _checkAndEmitStatus() async {
    final currentStatus = await isVpnActive();
    if (currentStatus != _lastKnownStatus) {
      _lastKnownStatus = currentStatus;
      _statusController?.add(currentStatus);
    }
  }

  void _stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _statusController?.close();
    _statusController = null;
    _statusStream = null;
  }

  @override
  Future<VpnInfo?> getVpnInfo() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );

      final isIos = Platform.isIOS;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        for (final pattern in _vpnInterfacePatterns) {
          if (name.contains(pattern)) {
            if (isIos && _shouldIgnoreOnIos(name)) {
              continue;
            }
            return VpnInfo(
              isConnected: true,
              interfaceName: interface.name,
              vpnProtocol: _guessProtocol(name),
            );
          }
        }
      }
      return VpnInfo(isConnected: false);
    } catch (e) {
      return VpnInfo(isConnected: false);
    }
  }

  /// Try to guess the VPN protocol from the interface name
  String? _guessProtocol(String interfaceName) {
    final name = interfaceName.toLowerCase();

    if (name.contains('wireguard') ||
        name.contains('wg') ||
        name.contains('nordlynx')) {
      return 'WireGuard';
    }
    if (name.contains('openvpn')) {
      return 'OpenVPN';
    }
    if (name.contains('ipsec') || name.contains('ikev2')) {
      return 'IKEv2/IPsec';
    }
    if (name.contains('l2tp')) {
      return 'L2TP';
    }
    if (name.contains('pptp')) {
      return 'PPTP';
    }
    if (name.contains('ppp')) {
      return 'PPP';
    }
    if (name.contains('tun') || name.contains('tap')) {
      return 'TUN/TAP';
    }
    if (name.contains('tailscale')) {
      return 'Tailscale';
    }
    if (name.contains('zerotier')) {
      return 'ZeroTier';
    }

    return null;
  }
}
