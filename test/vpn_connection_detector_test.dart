import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnConnectionDetector Tests', () {
    late VpnConnectionDetector vpnConnectionDetector;

    setUp(() {
      vpnConnectionDetector = VpnConnectionDetector();
    });

    tearDown(() {
      vpnConnectionDetector.dispose();
    });

    test('Initial connection status is disconnected', () {
      /** vpnConnectionStream is not returning any value, to get a value, there is a need to call
      checkVpnStatus by making it public **/
      vpnConnectionDetector.checkVpnStatus();

      expect(vpnConnectionDetector.vpnConnectionStream,
          emits(VpnConnectionState.disconnected));
    });

    test('Check VPN status when not connected', () async {
      final isConnected = await VpnConnectionDetector.isVpnActive();
      expect(isConnected, false);
    });
  });
}
