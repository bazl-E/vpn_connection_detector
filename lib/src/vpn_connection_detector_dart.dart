import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:meta/meta.dart';

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

  /// Interface name prefixes that must match the START of the name. Real
  /// VPN apps using `VpnService` always create kernel TUN/TAP/PPP devices
  /// whose names START with one of these tokens (e.g. `tun0`, `wg0`).
  /// Using prefix matching (rather than substring matching) avoids false
  /// positives like `vowifi_tun0` and `epdg_tun0` which embed the word
  /// `tun` inside an OEM-specific carrier interface name.
  static const List<String> _vpnInterfacePrefixes = [
    'tun', // Linux/Unix TUN interface, OpenVPN, OpenConnect, etc.
    'utun', // macOS / iOS WireGuard, OpenVPN-Connect, etc.
    'tap', // Linux/Unix TAP interface
    'ppp', // Point-to-Point Protocol
    'pptp', // PPTP VPN
    'l2tp', // L2TP VPN
    'ipsec', // IPsec VPN
    'vpn', // Generic "VPN" prefix
    'wg', // WireGuard kernel module (wg0, wg1, ...)
  ];

  /// Distinctive vendor substrings that are safe to substring-match because
  /// they don't collide with carrier-managed interface names.
  static const List<String> _vpnInterfaceSubstrings = [
    'wireguard',
    'openvpn',
    'softether',
    'nordlynx',
    'proton',
    'mullvad',
    'tailscale',
    'zerotier',
    'forticlient',
    'fortinet',
  ];

  /// Interface name prefixes used by carrier-managed tunnels (VoWiFi / WiFi
  /// Calling / ePDG / IMS PDN / cellular modem channels). These are NOT user
  /// VPNs and must be skipped to avoid false positives — see issue #13.
  ///
  /// - `vowifi*` — Xiaomi / Realme / Vivo OEM naming for VoWiFi tunnels
  /// - `epdg*`   — Samsung / 3GPP standard ePDG gateway
  /// - `ims*`    — IMS PDN (IP Multimedia Subsystem)
  /// - `rmnet*`  — Qualcomm Radio Modem cellular data channels
  /// - `ccmni*`  — MediaTek cellular interface
  static const List<String> _carrierManagedPrefixes = [
    'vowifi',
    'epdg',
    'ims',
    'rmnet',
    'ccmni',
  ];

  /// iOS-specific patterns to ignore (these appear even without VPN on iOS 17+)
  static final List<String> _iosIgnorePatterns = [
    'ipsec',
    'utun6',
    'ikev2',
    'l2tp',
  ];

  /// Returns true if [interfaceName] looks like a real user VPN interface,
  /// excluding known carrier-managed (VoWiFi / IMS) tunnels.
  ///
  /// Exposed for tests. The [isIos] flag enables iOS-specific filtering of
  /// system tunnels that appear on iOS 17+ even without an active VPN.
  @visibleForTesting
  static bool isVpnInterfaceName(String interfaceName, {required bool isIos}) {
    final lower = interfaceName.toLowerCase();
    // Defense-in-depth: never treat a carrier-managed interface as VPN.
    if (_carrierManagedPrefixes.any(lower.startsWith)) return false;
    if (_vpnInterfacePrefixes.any(lower.startsWith)) {
      if (isIos && _shouldIgnoreOnIosStatic(lower)) return false;
      return true;
    }
    if (_vpnInterfaceSubstrings.any(lower.contains)) {
      if (isIos && _shouldIgnoreOnIosStatic(lower)) return false;
      return true;
    }
    return false;
  }

  static bool _shouldIgnoreOnIosStatic(String interfaceName) =>
      _iosIgnorePatterns.any(interfaceName.contains);

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
        if (isVpnInterfaceName(interface.name, isIos: isIos)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // If we can't list interfaces, assume no VPN
      return false;
    }
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
        if (isVpnInterfaceName(interface.name, isIos: isIos)) {
          return VpnInfo(
            isConnected: true,
            interfaceName: interface.name,
            vpnProtocol: _guessProtocol(interface.name.toLowerCase()),
          );
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

  // ---------------------------------------------------------------------------
  // Proxy detection (best-effort, desktop fallback)
  // ---------------------------------------------------------------------------
  //
  // There is no cross-platform Dart API to query system proxy settings, so this
  // implementation inspects the standard environment variables honored by most
  // Unix tools and HTTP libraries: HTTP_PROXY, HTTPS_PROXY and ALL_PROXY (and
  // their lower-case variants). This catches proxies configured in the shell
  // environment but will NOT catch GUI-configured system proxies on
  // macOS/Windows/Linux. For those, use the native iOS/Android plugins or call
  // into platform-specific code from the host application.

  static const List<String> _proxyEnvKeys = [
    'HTTPS_PROXY',
    'https_proxy',
    'HTTP_PROXY',
    'http_proxy',
    'ALL_PROXY',
    'all_proxy',
  ];

  @override
  Future<bool> isProxyActive() async {
    return _readProxyFromEnv() != null;
  }

  @override
  Future<ProxyInfo?> getProxyInfo() async {
    final entry = _readProxyFromEnv();
    if (entry == null) return ProxyInfo(isActive: false);
    final parsed = _parseProxyUrl(entry.value);
    return ProxyInfo(
      isActive: true,
      host: parsed?.host,
      port: parsed?.port,
      proxyType: _proxyTypeForEnvKey(entry.key, parsed),
    );
  }

  MapEntry<String, String>? _readProxyFromEnv() {
    try {
      final env = Platform.environment;
      for (final key in _proxyEnvKeys) {
        final value = env[key];
        if (value != null && value.trim().isNotEmpty) {
          return MapEntry(key, value.trim());
        }
      }
    } catch (_) {
      // Platform.environment is unavailable on web; ignore.
    }
    return null;
  }

  Uri? _parseProxyUrl(String value) {
    try {
      // Accept values like "http://host:8080", "host:8080", "socks5://host:1080".
      final hasScheme = value.contains('://');
      final normalized = hasScheme ? value : 'http://$value';
      final uri = Uri.parse(normalized);
      if (uri.host.isEmpty) return null;
      return uri;
    } catch (_) {
      return null;
    }
  }

  ProxyType? _proxyTypeForEnvKey(String envKey, Uri? uri) {
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != null && scheme.startsWith('socks')) return ProxyType.socks;
    if (scheme == 'https') return ProxyType.https;
    if (scheme == 'http') {
      // Differentiate based on the env var name when scheme is generic http://.
      if (envKey.toLowerCase() == 'https_proxy') return ProxyType.https;
      return ProxyType.http;
    }
    return ProxyType.http;
  }
}
