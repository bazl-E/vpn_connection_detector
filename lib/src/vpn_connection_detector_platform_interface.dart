import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'vpn_connection_detector_method_channel.dart';

/// The interface that implementations of vpn_connection_detector must implement.
///
/// Platform implementations should extend this class rather than implement it as `vpn_connection_detector`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [VpnConnectionDetectorPlatform] methods.
abstract class VpnConnectionDetectorPlatform extends PlatformInterface {
  /// Constructs a VpnConnectionDetectorPlatform.
  VpnConnectionDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static VpnConnectionDetectorPlatform _instance =
      MethodChannelVpnConnectionDetector();

  /// The default instance of [VpnConnectionDetectorPlatform] to use.
  ///
  /// Defaults to [MethodChannelVpnConnectionDetector].
  static VpnConnectionDetectorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VpnConnectionDetectorPlatform] when
  /// they register themselves.
  static set instance(VpnConnectionDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns `true` if a VPN connection is currently active.
  Future<bool> isVpnActive() {
    throw UnimplementedError('isVpnActive() has not been implemented.');
  }

  /// Returns a stream of VPN connection status changes.
  /// Emits `true` when VPN connects, `false` when disconnects.
  Stream<bool> get vpnStatusStream {
    throw UnimplementedError('vpnStatusStream has not been implemented.');
  }

  /// Returns detailed information about the current VPN connection.
  /// Returns `null` if no VPN is connected.
  Future<VpnInfo?> getVpnInfo() {
    throw UnimplementedError('getVpnInfo() has not been implemented.');
  }

  /// Returns a list of all active VPN connections.
  /// Returns an empty list if no VPNs are connected.
  Future<List<VpnInfo>> getAllVpnInfo() {
    throw UnimplementedError('getAllVpnInfo() has not been implemented.');
  }
}

/// Detailed information about a VPN connection.
class VpnInfo {
  /// Creates a new [VpnInfo] instance.
  const VpnInfo({
    required this.isConnected,
    this.interfaceName,
    this.vpnProtocol,
    this.connectedSince,
  });

  /// Creates a [VpnInfo] from a map (used for platform channel communication).
  factory VpnInfo.fromMap(Map<String, dynamic> map) {
    DateTime? connectedSince;
    final sinceMs = map['connectedSince'] as int?;
    if (sinceMs != null) {
      connectedSince = DateTime.fromMillisecondsSinceEpoch(sinceMs);
    }

    return VpnInfo(
      isConnected: map['isConnected'] as bool? ?? false,
      interfaceName: map['interfaceName'] as String?,
      vpnProtocol: map['vpnProtocol'] as String?,
      connectedSince: connectedSince,
    );
  }

  /// Whether a VPN is currently connected.
  final bool isConnected;

  /// The name of the VPN interface (e.g., 'tun0', 'utun3').
  final String? interfaceName;

  /// The VPN protocol being used (e.g., 'IKEv2', 'WireGuard', 'OpenVPN').
  final String? vpnProtocol;

  /// When this VPN connection was first detected.
  ///
  /// This is set when the VPN is first detected as connected, not necessarily
  /// when the VPN actually connected. It can be `null` for one-time checks
  /// where connection start time is unknown.
  final DateTime? connectedSince;

  /// Converts this [VpnInfo] to a map.
  Map<String, dynamic> toMap() {
    return {
      'isConnected': isConnected,
      'interfaceName': interfaceName,
      'vpnProtocol': vpnProtocol,
      if (connectedSince != null)
        'connectedSince': connectedSince!.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this [VpnInfo] with the given fields replaced.
  VpnInfo copyWith({
    bool? isConnected,
    String? interfaceName,
    String? vpnProtocol,
    DateTime? connectedSince,
  }) {
    return VpnInfo(
      isConnected: isConnected ?? this.isConnected,
      interfaceName: interfaceName ?? this.interfaceName,
      vpnProtocol: vpnProtocol ?? this.vpnProtocol,
      connectedSince: connectedSince ?? this.connectedSince,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VpnInfo &&
        other.isConnected == isConnected &&
        other.interfaceName == interfaceName &&
        other.vpnProtocol == vpnProtocol &&
        other.connectedSince == connectedSince;
  }

  @override
  int get hashCode =>
      Object.hash(isConnected, interfaceName, vpnProtocol, connectedSince);

  @override
  String toString() {
    return 'VpnInfo(isConnected: $isConnected, interfaceName: $interfaceName, vpnProtocol: $vpnProtocol, connectedSince: $connectedSince)';
  }
}
