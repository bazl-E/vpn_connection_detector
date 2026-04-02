import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vpn_connection_detector_dart.dart';
import 'vpn_connection_detector_platform_interface.dart';

/// An implementation of [VpnConnectionDetectorPlatform] that uses method channels.
class MethodChannelVpnConnectionDetector extends VpnConnectionDetectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('vpn_connection_detector');

  /// The event channel used to receive VPN status updates from native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('vpn_connection_detector/status');

  /// Cached broadcast stream from the event channel
  Stream<bool>? _eventChannelStream;

  /// Dart fallback implementation for unsupported platforms
  final _dartFallback = DartVpnConnectionDetector();

  /// Whether to use native implementation
  bool get _useNative =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  @override
  Future<bool> isVpnActive() async {
    if (!_useNative) {
      return _dartFallback.isVpnActive();
    }

    try {
      final result = await methodChannel.invokeMethod<bool>('isVpnActive');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('VpnConnectionDetector: Native call failed: ${e.message}');
      // Fallback to Dart implementation if native fails
      return _dartFallback.isVpnActive();
    } on MissingPluginException {
      // Native plugin not available, use Dart fallback
      return _dartFallback.isVpnActive();
    }
  }

  @override
  Stream<bool> get vpnStatusStream {
    if (!_useNative) {
      return _dartFallback.vpnStatusStream;
    }

    // Cache the broadcast stream so multiple listeners can subscribe/unsubscribe
    // without breaking the underlying event channel connection.
    _eventChannelStream ??=
        eventChannel.receiveBroadcastStream().map<bool>((dynamic event) {
      if (event is bool) {
        return event;
      } else if (event is Map) {
        return event['isConnected'] as bool? ?? false;
      }
      return false;
    }).handleError((dynamic error) {
      debugPrint('VpnConnectionDetector: Stream error: $error');
      // Return false (disconnected) on error - stream will continue
      return false;
    }).asBroadcastStream();

    return _eventChannelStream!;
  }

  @override
  Future<VpnInfo?> getVpnInfo() async {
    if (!_useNative) {
      return _dartFallback.getVpnInfo();
    }

    try {
      final result =
          await methodChannel.invokeMapMethod<String, dynamic>('getVpnInfo');
      if (result == null) return null;
      return VpnInfo.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint('VpnConnectionDetector: getVpnInfo failed: ${e.message}');
      return _dartFallback.getVpnInfo();
    } on MissingPluginException {
      return _dartFallback.getVpnInfo();
    }
  }

  @override
  Future<List<VpnInfo>> getAllVpnInfo() async {
    if (!_useNative) {
      return _dartFallback.getAllVpnInfo();
    }

    try {
      final result = await methodChannel.invokeListMethod<Map>('getAllVpnInfo');
      if (result == null) return [];
      return result
          .map((item) => VpnInfo.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('VpnConnectionDetector: getAllVpnInfo failed: ${e.message}');
      return _dartFallback.getAllVpnInfo();
    } on MissingPluginException {
      return _dartFallback.getAllVpnInfo();
    }
  }
}
