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
}

/// Detailed information about a VPN connection.
class VpnInfo {
  /// Creates a new [VpnInfo] instance.
  const VpnInfo({
    required this.isConnected,
    this.interfaceName,
    this.vpnProtocol,
  });

  /// Creates a [VpnInfo] from a map (used for platform channel communication).
  factory VpnInfo.fromMap(Map<String, dynamic> map) {
    return VpnInfo(
      isConnected: map['isConnected'] as bool? ?? false,
      interfaceName: map['interfaceName'] as String?,
      vpnProtocol: map['vpnProtocol'] as String?,
    );
  }

  /// Whether a VPN is currently connected.
  final bool isConnected;

  /// The name of the VPN interface (e.g., 'tun0', 'utun3').
  final String? interfaceName;

  /// The VPN protocol being used (e.g., 'IKEv2', 'WireGuard', 'OpenVPN').
  final String? vpnProtocol;

  /// Converts this [VpnInfo] to a map.
  Map<String, dynamic> toMap() {
    return {
      'isConnected': isConnected,
      'interfaceName': interfaceName,
      'vpnProtocol': vpnProtocol,
    };
  }

  @override
  String toString() {
    return 'VpnInfo(isConnected: $isConnected, interfaceName: $interfaceName, vpnProtocol: $vpnProtocol)';
  }
}
