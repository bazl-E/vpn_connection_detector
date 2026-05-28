// Regression tests for issue #13:
// VoWiFi / WiFi Calling carrier interfaces (e.g. `vowifi_tun0`, `epdg0`,
// `ims0`) must NOT be misidentified as user VPN connections.
//
// These tests pin the behaviour of the static interface-name classifier used
// by the Dart fallback. The Android native implementation duplicates the
// same logic in Kotlin (VpnConnectionDetectorPlugin.kt).

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_connection_detector/src/vpn_connection_detector_dart.dart';

void main() {
  group('DartVpnConnectionDetector.isVpnInterfaceName', () {
    group('real VPN interfaces ARE detected', () {
      const realVpnNames = <String>[
        'tun0', // OpenVPN, OpenConnect, generic VpnService
        'tun1',
        'tun42',
        'tap0', // OpenVPN bridged mode
        'wg0', // WireGuard
        'wg-mullvad',
        'ppp0', // PPP/PPTP
        'pptp0',
        'l2tp0',
        'ipsec0',
        'vpn0',
        'utun0', // macOS / iOS WireGuard, OpenVPN-Connect
        'wireguard0',
        'openvpn-tun0',
        'tailscale0',
        'zerotier-abc123',
        'nordlynx',
      ];

      for (final name in realVpnNames) {
        test('detects "$name" as VPN', () {
          expect(
            DartVpnConnectionDetector.isVpnInterfaceName(name, isIos: false),
            isTrue,
          );
        });
      }
    });

    group('carrier-managed (VoWiFi / IMS / cellular) interfaces are EXCLUDED',
        () {
      // These names are confirmed in OEM firmware dumps and the bug report
      // (issue #13). They are NOT user VPNs and must never be flagged.
      const carrierNames = <String>[
        // Xiaomi / Realme / Vivo VoWiFi
        'vowifi_tun0',
        'vowifi0',
        'vowifi_tun1',
        // 3GPP / Samsung ePDG
        'epdg0',
        'epdg_tun0',
        // IMS PDN
        'ims0',
        'ims_rmnet0',
        // Qualcomm cellular radio (not a VPN under any circumstance)
        'rmnet_data0',
        'rmnet0',
        'rmnet_ims0',
        // MediaTek cellular
        'ccmni0',
        'ccmni3',
      ];

      for (final name in carrierNames) {
        test('does NOT flag "$name" on Android', () {
          expect(
            DartVpnConnectionDetector.isVpnInterfaceName(name, isIos: false),
            isFalse,
            reason: '$name is a carrier-managed interface, not a user VPN',
          );
        });

        test('does NOT flag "$name" on iOS', () {
          expect(
            DartVpnConnectionDetector.isVpnInterfaceName(name, isIos: true),
            isFalse,
          );
        });
      }
    });

    group('non-VPN interfaces are not flagged', () {
      const nonVpnNames = <String>[
        'wlan0',
        'eth0',
        'lo',
        'en0',
        'en1',
        'dummy0',
        'docker0',
        'br-1234',
        'bond0',
        'wifi0',
      ];

      for (final name in nonVpnNames) {
        test('does NOT flag "$name"', () {
          expect(
            DartVpnConnectionDetector.isVpnInterfaceName(name, isIos: false),
            isFalse,
          );
        });
      }
    });

    group('iOS-specific false-positive filtering', () {
      // On iOS 17+, these tunnel-like interfaces appear even without an
      // active VPN, so the iOS path filters them out.
      test('ignores "utun6" on iOS', () {
        expect(
          DartVpnConnectionDetector.isVpnInterfaceName('utun6', isIos: true),
          isFalse,
        );
      });

      test('ignores "ipsec0" on iOS', () {
        expect(
          DartVpnConnectionDetector.isVpnInterfaceName('ipsec0', isIos: true),
          isFalse,
        );
      });

      test('still flags "tun0" on iOS (real VPN)', () {
        expect(
          DartVpnConnectionDetector.isVpnInterfaceName('tun0', isIos: true),
          isTrue,
        );
      });
    });

    test('is case-insensitive', () {
      expect(
        DartVpnConnectionDetector.isVpnInterfaceName('VOWIFI_TUN0',
            isIos: false),
        isFalse,
      );
      expect(
        DartVpnConnectionDetector.isVpnInterfaceName('TUN0', isIos: false),
        isTrue,
      );
    });
  });
}
