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

  /// Returns `true` if a system HTTP/HTTPS/SOCKS/PAC proxy is currently
  /// configured on the device.
  ///
  /// Note: A proxy is *not* the same as a VPN. Use [isVpnActive] for VPN
  /// detection and [isTrafficInterceptionActive] for a combined check.
  Future<bool> isProxyActive() {
    throw UnimplementedError('isProxyActive() has not been implemented.');
  }

  /// Returns detailed information about the current system proxy.
  /// Returns `null` if no proxy is active.
  Future<ProxyInfo?> getProxyInfo() {
    throw UnimplementedError('getProxyInfo() has not been implemented.');
  }

  /// Returns `true` if either a VPN or a system proxy is currently active.
  /// Useful for security-focused checks that want to detect any form of
  /// traffic interception.
  Future<bool> isTrafficInterceptionActive() async {
    final results = await Future.wait([isVpnActive(), isProxyActive()]);
    return results[0] || results[1];
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

/// The type of system proxy that is configured.
enum ProxyType {
  /// HTTP proxy (Settings → Wi-Fi → Configure Proxy → Manual, HTTP).
  http,

  /// HTTPS proxy (Settings → Wi-Fi → Configure Proxy → Manual, HTTPS).
  https,

  /// SOCKS proxy (macOS, desktop).
  socks,

  /// Proxy Auto-Configuration script (PAC).
  pac,
}

/// Detailed information about a system proxy configuration.
///
/// A proxy is a server that intercepts and routes HTTP/HTTPS (or other)
/// traffic on behalf of the device. Unlike a VPN, a proxy does not create
/// a network tunnel and only affects apps that honor the system proxy
/// configuration.
class ProxyInfo {
  /// Creates a new [ProxyInfo] instance.
  const ProxyInfo({
    required this.isActive,
    this.host,
    this.port,
    this.proxyType,
    this.pacUrl,
  });

  /// Creates a [ProxyInfo] from a map (used for platform channel communication).
  factory ProxyInfo.fromMap(Map<String, dynamic> map) {
    final typeString = map['proxyType'] as String?;
    return ProxyInfo(
      isActive: map['isActive'] as bool? ?? false,
      host: map['host'] as String?,
      port: map['port'] as int?,
      proxyType: _parseProxyType(typeString),
      pacUrl: map['pacUrl'] as String?,
    );
  }

  static ProxyType? _parseProxyType(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'http':
        return ProxyType.http;
      case 'https':
        return ProxyType.https;
      case 'socks':
        return ProxyType.socks;
      case 'pac':
        return ProxyType.pac;
      default:
        return null;
    }
  }

  /// Whether a system proxy is currently active.
  final bool isActive;

  /// The proxy host (e.g., `127.0.0.1`). May be null for PAC proxies.
  final String? host;

  /// The proxy port. May be null for PAC proxies.
  final int? port;

  /// The kind of proxy configured.
  final ProxyType? proxyType;

  /// The URL of the proxy auto-configuration (PAC) script, if applicable.
  final String? pacUrl;

  /// Converts this [ProxyInfo] to a map.
  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'host': host,
      'port': port,
      'proxyType': proxyType?.name,
      'pacUrl': pacUrl,
    };
  }

  @override
  String toString() {
    return 'ProxyInfo(isActive: $isActive, host: $host, port: $port, '
        'proxyType: ${proxyType?.name}, pacUrl: $pacUrl)';
  }
}
