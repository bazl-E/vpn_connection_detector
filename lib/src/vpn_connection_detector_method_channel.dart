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

  /// Stream controller for VPN status
  StreamController<bool>? _statusController;

  /// Cached stream
  Stream<bool>? _statusStream;

  /// Dart fallback implementation for unsupported platforms
  final _dartFallback = DartVpnConnectionDetector();

  /// Whether to use native implementation
  bool get _useNative => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

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

  void _startListening() {
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is bool) {
          _statusController?.add(event);
        } else if (event is Map) {
          _statusController?.add(event['isConnected'] as bool? ?? false);
        }
      },
      onError: (dynamic error) {
        debugPrint('VpnConnectionDetector: Stream error: $error');
        // On error, switch to Dart fallback
        _dartFallback.vpnStatusStream.listen((status) {
          _statusController?.add(status);
        });
      },
    );
  }

  void _stopListening() {
    _statusController?.close();
    _statusController = null;
    _statusStream = null;
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
}
