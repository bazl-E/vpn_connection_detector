import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vpn_connection_detector/src/vpn_connection_detector_platform_interface.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

class MockVpnConnectionDetectorPlatform
    with MockPlatformInterfaceMixin
    implements VpnConnectionDetectorPlatform {
  bool _mockVpnStatus = false;
  bool _mockProxyStatus = false;

  void setMockVpnStatus(bool status) {
    _mockVpnStatus = status;
  }

  void setMockProxyStatus(bool status) {
    _mockProxyStatus = status;
  }

  @override
  Future<bool> isVpnActive() async {
    return _mockVpnStatus;
  }

  @override
  Stream<bool> get vpnStatusStream => Stream.value(_mockVpnStatus);

  @override
  Future<VpnInfo?> getVpnInfo() async {
    return VpnInfo(
      isConnected: _mockVpnStatus,
      interfaceName: _mockVpnStatus ? 'tun0' : null,
      vpnProtocol: _mockVpnStatus ? 'WireGuard' : null,
    );
  }

  @override
  Future<bool> isProxyActive() async => _mockProxyStatus;

  @override
  Future<ProxyInfo?> getProxyInfo() async {
    if (!_mockProxyStatus) return const ProxyInfo(isActive: false);
    return const ProxyInfo(
      isActive: true,
      host: '127.0.0.1',
      port: 8080,
      proxyType: ProxyType.http,
    );
  }

  @override
  Future<bool> isTrafficInterceptionActive() async {
    return _mockVpnStatus || _mockProxyStatus;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnInfo', () {
    test('creates VpnInfo from map', () {
      final map = {
        'isConnected': true,
        'interfaceName': 'utun3',
        'vpnProtocol': 'IKEv2',
      };

      final info = VpnInfo.fromMap(map);

      expect(info.isConnected, true);
      expect(info.interfaceName, 'utun3');
      expect(info.vpnProtocol, 'IKEv2');
    });

    test('creates VpnInfo from map with missing fields', () {
      final map = <String, dynamic>{
        'isConnected': false,
      };

      final info = VpnInfo.fromMap(map);

      expect(info.isConnected, false);
      expect(info.interfaceName, isNull);
      expect(info.vpnProtocol, isNull);
    });

    test('converts VpnInfo to map', () {
      const info = VpnInfo(
        isConnected: true,
        interfaceName: 'wg0',
        vpnProtocol: 'WireGuard',
      );

      final map = info.toMap();

      expect(map['isConnected'], true);
      expect(map['interfaceName'], 'wg0');
      expect(map['vpnProtocol'], 'WireGuard');
    });

    test('VpnInfo toString', () {
      const info = VpnInfo(
        isConnected: true,
        interfaceName: 'tun0',
        vpnProtocol: 'OpenVPN',
      );

      expect(
        info.toString(),
        'VpnInfo(isConnected: true, interfaceName: tun0, vpnProtocol: OpenVPN)',
      );
    });
  });

  group('VpnConnectionState', () {
    test('has correct values', () {
      expect(VpnConnectionState.values.length, 2);
      expect(VpnConnectionState.connected.name, 'connected');
      expect(VpnConnectionState.disconnected.name, 'disconnected');
    });
  });

  group('VpnConnectionDetectorPlatform', () {
    test('default instance is MethodChannelVpnConnectionDetector', () {
      expect(
        VpnConnectionDetectorPlatform.instance,
        isNotNull,
      );
    });

    test('can set mock platform instance', () {
      final mockPlatform = MockVpnConnectionDetectorPlatform();
      VpnConnectionDetectorPlatform.instance = mockPlatform;

      expect(
        VpnConnectionDetectorPlatform.instance,
        mockPlatform,
      );
    });
  });

  group('VpnConnectionDetector with mock platform', () {
    late MockVpnConnectionDetectorPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockVpnConnectionDetectorPlatform();
      VpnConnectionDetectorPlatform.instance = mockPlatform;
    });

    test('isVpnActive returns false when VPN is not connected', () async {
      mockPlatform.setMockVpnStatus(false);

      final result = await VpnConnectionDetector.isVpnActive();

      expect(result, false);
    });

    test('isVpnActive returns true when VPN is connected', () async {
      mockPlatform.setMockVpnStatus(true);

      final result = await VpnConnectionDetector.isVpnActive();

      expect(result, true);
    });

    test('getVpnInfo returns info when VPN is connected', () async {
      mockPlatform.setMockVpnStatus(true);

      final info = await VpnConnectionDetector.getVpnInfo();

      expect(info, isNotNull);
      expect(info!.isConnected, true);
      expect(info.interfaceName, 'tun0');
      expect(info.vpnProtocol, 'WireGuard');
    });

    test('getVpnInfo returns disconnected info when VPN is not connected',
        () async {
      mockPlatform.setMockVpnStatus(false);

      final info = await VpnConnectionDetector.getVpnInfo();

      expect(info, isNotNull);
      expect(info!.isConnected, false);
      expect(info.interfaceName, isNull);
    });
  });

  group('ProxyInfo', () {
    test('creates ProxyInfo from map (http)', () {
      final map = {
        'isActive': true,
        'host': '10.0.0.1',
        'port': 3128,
        'proxyType': 'http',
      };
      final info = ProxyInfo.fromMap(map);
      expect(info.isActive, true);
      expect(info.host, '10.0.0.1');
      expect(info.port, 3128);
      expect(info.proxyType, ProxyType.http);
      expect(info.pacUrl, isNull);
    });

    test('creates ProxyInfo from map (pac)', () {
      final map = {
        'isActive': true,
        'proxyType': 'pac',
        'pacUrl': 'http://example.com/proxy.pac',
      };
      final info = ProxyInfo.fromMap(map);
      expect(info.isActive, true);
      expect(info.proxyType, ProxyType.pac);
      expect(info.pacUrl, 'http://example.com/proxy.pac');
      expect(info.host, isNull);
    });

    test('round-trips through toMap/fromMap', () {
      const original = ProxyInfo(
        isActive: true,
        host: '127.0.0.1',
        port: 1080,
        proxyType: ProxyType.socks,
      );
      final restored = ProxyInfo.fromMap(original.toMap());
      expect(restored.isActive, original.isActive);
      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.proxyType, original.proxyType);
    });

    test('unknown proxyType returns null', () {
      final info = ProxyInfo.fromMap({'isActive': true, 'proxyType': 'weird'});
      expect(info.proxyType, isNull);
    });
  });

  group('Proxy detection with mock platform', () {
    late MockVpnConnectionDetectorPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockVpnConnectionDetectorPlatform();
      VpnConnectionDetectorPlatform.instance = mockPlatform;
    });

    test('isProxyActive returns false when no proxy', () async {
      mockPlatform.setMockProxyStatus(false);
      expect(await VpnConnectionDetector.isProxyActive(), false);
    });

    test('isProxyActive returns true when proxy configured', () async {
      mockPlatform.setMockProxyStatus(true);
      expect(await VpnConnectionDetector.isProxyActive(), true);
    });

    test('getProxyInfo returns details when proxy active', () async {
      mockPlatform.setMockProxyStatus(true);
      final info = await VpnConnectionDetector.getProxyInfo();
      expect(info, isNotNull);
      expect(info!.isActive, true);
      expect(info.host, '127.0.0.1');
      expect(info.port, 8080);
      expect(info.proxyType, ProxyType.http);
    });

    test('isTrafficInterceptionActive true when only VPN active', () async {
      mockPlatform.setMockVpnStatus(true);
      mockPlatform.setMockProxyStatus(false);
      expect(await VpnConnectionDetector.isTrafficInterceptionActive(), true);
    });

    test('isTrafficInterceptionActive true when only proxy active', () async {
      mockPlatform.setMockVpnStatus(false);
      mockPlatform.setMockProxyStatus(true);
      expect(await VpnConnectionDetector.isTrafficInterceptionActive(), true);
    });

    test('isTrafficInterceptionActive false when neither active', () async {
      mockPlatform.setMockVpnStatus(false);
      mockPlatform.setMockProxyStatus(false);
      expect(await VpnConnectionDetector.isTrafficInterceptionActive(), false);
    });
  });
}
