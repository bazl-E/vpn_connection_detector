import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// [VpnConnectionState] enum defines the state of the VPN connection:
/// - [connected]: Indicates the VPN is currently active.
/// - [disconnected]: Indicates the VPN is not active.
enum VpnConnectionState {
  connected,
  disconnected
}

/// [VpnConnectionDetector] is a singleton class responsible for detecting VPN connections
/// in a Flutter application. It listens to network connectivity changes, checks the VPN
/// status periodically, and provides a real-time stream of the VPN connection state.
/// 
/// This class can be used to:
/// - Check if a VPN connection is currently active.
/// - Provide real-time updates of the VPN status using a stream.
/// - Customize detection with additional VPN interface patterns.
///
/// The class uses [NetworkInterface.list()] to retrieve network interfaces and compares
/// their names with common VPN-related keywords to determine if a VPN is active.
///
/// **Usage Example:**
///
/// ```dart
/// final vpnDetector = VpnConnectionDetector();
/// 
/// // Listen to VPN connection state changes
/// vpnDetector.vpnConnectionStream.listen((state) {
///   if (state == VpnConnectionState.connected) {
///     print("VPN is connected.");
///   } else {
///     print("VPN is disconnected.");
///   }
/// });
/// 
/// // Check VPN status one time
/// bool isVpnActive = await VpnConnectionDetector.isVpnActive();
/// print('Is VPN active? $isVpnActive');
/// ```
///
/// The class also allows adding custom VPN patterns with the `addVpnPattern` method if
/// your application needs to detect additional VPN interface names.
class VpnConnectionDetector {
  /// Singleton instance of [VpnConnectionDetector].
  static VpnConnectionDetector? _instance;

  /// Factory constructor to create or retrieve the singleton instance of [VpnConnectionDetector].
  factory VpnConnectionDetector() {
    _instance ??= VpnConnectionDetector._private();
    return _instance!;
  }

  // Private constructor to enforce the singleton pattern.
  VpnConnectionDetector._private() {
    // Listen to connectivity changes (Wi-Fi, Mobile Data, etc.)
    // and trigger a VPN status check on each connectivity change.
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      await _checkVpnStatus();
    });

    // Periodic VPN status check, set to every 30 seconds to capture VPN changes.
    _vpnCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkVpnStatus();
    });
  }

  // Stream controller for broadcasting VPN connection states.
  final StreamController<VpnConnectionState> _controller =
      StreamController.broadcast();

  // Subscription to connectivity changes from the connectivity_plus package.
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Timer for periodically checking VPN status, in addition to connectivity change detection.
  Timer? _vpnCheckTimer;

  // List of common network interface names used by VPN services.
  // This list can be extended dynamically by calling `addVpnPattern()`.
  static final List<String> _commonVpnInterfaceNamePatterns = [
    'tun',          // Linux/Unix TUN interface
    'tap',          // Linux/Unix TAP interface
    'ppp',          // Point-to-Point Protocol (VPN tunneling)
    'pptp',         // Point-to-Point Tunneling Protocol (legacy VPN protocol)
    'l2tp',         // Layer 2 Tunneling Protocol
    'ipsec',        // Internet Protocol Security (commonly used with L2TP)
    'vpn',          // Generic "VPN" keyword
    'wireguard',    // WireGuard VPN
    'openvpn',      // OpenVPN interface
    'softether',    // SoftEther VPN
    'sstp',         // Secure Socket Tunneling Protocol (Microsoft VPN)
    'gre',          // Generic Routing Encapsulation
    'vxlan',        // Virtual Extensible LAN (used in some tunneling protocols)
    'udpvpn',       // UDP-based VPN
    'tcpvpn',       // TCP-based VPN
    'utun',         // VPN tunnel used in macOS
    'vti',          // Virtual Tunnel Interface (IPsec VPN)
    'gretap',       // GRE Tunneling interface
    'ovpn',         // Abbreviation for OpenVPN
    'htun',         // Hamachi TUN (LogMeIn Hamachi VPN)
    'ipip',         // IP in IP tunneling (used in VPNs)
    'encap',        // Encapsulation interface (used in VPNs)
    'isatap',       // Intra-Site Automatic Tunnel Addressing Protocol
    'ipcomp',       // IP Payload Compression Protocol
    'ipsec0',       // Common IPsec interface
    'utap',         // Generic tap for VPNs
    'wg',           // WireGuard abbreviation
    'vmnet',        // Used in virtual machines (can also appear in VPN setups)
    'vlan',         // Virtual LAN, sometimes used in VPN setups
  ];

  /// Returns a broadcast stream of [VpnConnectionState], which provides real-time updates
  /// on the VPN connection status.
  ///
  /// - [VpnConnectionState.connected]: VPN is currently active.
  /// - [VpnConnectionState.disconnected]: VPN is not active.
  ///
  /// Example:
  ///
  /// ```dart
  /// vpnDetector.vpnConnectionStream.listen((state) {
  ///   if (state == VpnConnectionState.connected) {
  ///     print("VPN is connected.");
  ///   } else {
  ///     print("VPN is disconnected.");
  ///   }
  /// });
  /// ```
  Stream<VpnConnectionState> get vpnConnectionStream =>
      _controller.stream.asBroadcastStream();

  /// Static method to check if a VPN is currently active by looking at
  /// the available network interfaces and matching them against common VPN interface names.
  ///
  /// Returns `true` if a VPN is detected, otherwise `false`.
  ///
  /// Example:
  /// ```dart
  /// bool isVpnActive = await VpnConnectionDetector.isVpnActive();
  /// print('Is VPN active? $isVpnActive');
  /// ```
  static Future<bool> isVpnActive() async {
    try {
      // Retrieve a list of network interfaces
      final interfaces = await NetworkInterface.list();
      // Match interface names with common VPN patterns
      return interfaces.any((interface) =>
          _commonVpnInterfaceNamePatterns.any(
              (pattern) => interface.name.toLowerCase().contains(pattern)));
    } catch (e) {
      // Handle exceptions in case network interfaces cannot be retrieved
      return false;
    }
  }

  /// Private method to check VPN status and broadcast the current state
  /// via the [_controller] stream.
  Future<void> _checkVpnStatus() async {
    final bool vpnActive = await isVpnActive();
    final VpnConnectionState state = vpnActive
        ? VpnConnectionState.connected
        : VpnConnectionState.disconnected;
    _controller.add(state);
  }

  /// Allows dynamic addition of custom VPN interface patterns to detect VPNs that
  /// may not be covered by the default patterns.
  ///
  /// Example:
  /// ```dart
  /// vpnDetector.addVpnPattern('customvpn');
  /// ```
  void addVpnPattern(String pattern) {
    _commonVpnInterfaceNamePatterns.add(pattern.toLowerCase());
  }

  /// Disposes of the stream controller, connectivity subscription, and periodic timer
  /// to clean up resources when the detector is no longer needed.
  ///
  /// This should be called when the VPN detection is no longer required to avoid memory leaks.
  ///
  /// Example:
  /// ```dart
  /// vpnDetector.dispose();
  /// ```
  void dispose() {
    _connectivitySubscription?.cancel();
    _vpnCheckTimer?.cancel();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
