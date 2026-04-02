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

  @override
  Future<List<VpnInfo>> getAllVpnInfo() async {
    if (!_mockVpnStatus) return [];
    return [
      const VpnInfo(
        isConnected: true,
        interfaceName: 'tun0',
        vpnProtocol: 'WireGuard',
      ),
    ];
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
        'VpnInfo(isConnected: true, interfaceName: tun0, vpnProtocol: OpenVPN, connectedSince: null)',
      );
    });

    test('VpnInfo connectedSince from map', () {
      final now = DateTime.now();
      final map = {
        'isConnected': true,
        'interfaceName': 'utun3',
        'vpnProtocol': 'Tunnel',
        'connectedSince': now.millisecondsSinceEpoch,
      };

      final info = VpnInfo.fromMap(map);

      expect(info.connectedSince, isNotNull);
      expect(
        info.connectedSince!.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('VpnInfo copyWith connectedSince', () {
      final now = DateTime.now();
      const info = VpnInfo(isConnected: true, interfaceName: 'tun0');
      final updated = info.copyWith(connectedSince: now);

      expect(updated.connectedSince, now);
      expect(updated.isConnected, true);
      expect(updated.interfaceName, 'tun0');
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

    test('getAllVpnInfo returns list when VPN is connected', () async {
      mockPlatform.setMockVpnStatus(true);

      final vpns = await VpnConnectionDetector.getAllVpnInfo();

      expect(vpns, isNotEmpty);
      expect(vpns.first.isConnected, true);
      expect(vpns.first.interfaceName, 'tun0');
      expect(vpns.first.vpnProtocol, 'WireGuard');
    });

    test('getAllVpnInfo returns empty list when VPN is not connected',
        () async {
      mockPlatform.setMockVpnStatus(false);

      final vpns = await VpnConnectionDetector.getAllVpnInfo();

      expect(vpns, isEmpty);
    });
  });
}
