import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
import 'package:vpn_connection_detector/src/vpn_connection_detector_platform_interface.dart';

class MockVpnConnectionDetectorPlatform
    with MockPlatformInterfaceMixin
    implements VpnConnectionDetectorPlatform {
  bool _mockVpnStatus = false;

  void setMockVpnStatus(bool status) {
    _mockVpnStatus = status;
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
}
