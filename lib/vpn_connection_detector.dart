library;

import 'dart:async';

import 'src/vpn_connection_detector_platform_interface.dart';

export 'src/vpn_connection_detector_platform_interface.dart' show VpnInfo;

/// The state of a VPN connection.
enum VpnConnectionState {
  /// The VPN is currently connected.
  connected,

  /// The VPN is currently disconnected.
  disconnected,
}

/// A detector for VPN connections that provides both one-time checks
/// and real-time streaming of connection status changes.
///
/// This is a singleton class that manages VPN detection across platforms.
/// On iOS and Android, it uses native platform APIs for accurate detection.
/// On other platforms (macOS, Windows, Linux), it falls back to a Dart
/// implementation that checks network interface names.
///
/// Example usage:
/// ```dart
/// // One-time check
/// final isActive = await VpnConnectionDetector.isVpnActive();
///
/// // Stream of status changes
/// final detector = VpnConnectionDetector();
/// detector.vpnConnectionStream.listen((state) {
///   print('VPN is ${state == VpnConnectionState.connected ? 'connected' : 'disconnected'}');
/// });
///
/// // Get detailed VPN info
/// final info = await VpnConnectionDetector.getVpnInfo();
/// print('Protocol: ${info?.vpnProtocol}');
/// ```
class VpnConnectionDetector {
  /// Creates or retrieves the singleton instance of [VpnConnectionDetector].
  factory VpnConnectionDetector() {
    _instance ??= VpnConnectionDetector._internal();
    return _instance!;
  }

  VpnConnectionDetector._internal() {
    _initialize();
  }

  static VpnConnectionDetector? _instance;

  final StreamController<VpnConnectionState> _stateController =
      StreamController<VpnConnectionState>.broadcast();

  StreamSubscription<bool>? _platformSubscription;

  VpnConnectionState? _lastState;

  void _initialize() {
    // Listen to platform stream and convert to VpnConnectionState
    _platformSubscription =
        VpnConnectionDetectorPlatform.instance.vpnStatusStream.listen(
      (isConnected) {
        final state = isConnected
            ? VpnConnectionState.connected
            : VpnConnectionState.disconnected;

        // Only emit if state changed
        if (_lastState != state) {
          _lastState = state;
          _stateController.add(state);
        }
      },
      onError: (error) {
        // On error, emit disconnected state
        if (_lastState != VpnConnectionState.disconnected) {
          _lastState = VpnConnectionState.disconnected;
          _stateController.add(VpnConnectionState.disconnected);
        }
      },
    );

    // Emit initial state
    _checkAndEmitInitialState();
  }

  Future<void> _checkAndEmitInitialState() async {
    final isActive = await VpnConnectionDetector.isVpnActive();
    final state = isActive
        ? VpnConnectionState.connected
        : VpnConnectionState.disconnected;
    _lastState = state;
    _stateController.add(state);
  }

  /// Returns `true` if a VPN connection is currently active.
  ///
  /// This is a static method that can be called without creating an instance
  /// of [VpnConnectionDetector]. It's useful for one-time checks.
  ///
  /// On iOS and Android, this uses native platform APIs for accurate detection.
  /// On other platforms, it falls back to checking network interface names.
  ///
  /// Example:
  /// ```dart
  /// if (await VpnConnectionDetector.isVpnActive()) {
  ///   print('VPN is active');
  /// }
  /// ```
  static Future<bool> isVpnActive() {
    return VpnConnectionDetectorPlatform.instance.isVpnActive();
  }

  /// Returns detailed information about the current VPN connection.
  ///
  /// Returns a [VpnInfo] object containing:
  /// - `isConnected`: Whether a VPN is connected
  /// - `interfaceName`: The name of the VPN interface (if available)
  /// - `vpnProtocol`: The VPN protocol being used (if detectable)
  ///
  /// Returns `null` if VPN info cannot be retrieved.
  ///
  /// Example:
  /// ```dart
  /// final info = await VpnConnectionDetector.getVpnInfo();
  /// if (info?.isConnected == true) {
  ///   print('Connected via ${info?.vpnProtocol ?? 'unknown protocol'}');
  /// }
  /// ```
  static Future<VpnInfo?> getVpnInfo() {
    return VpnConnectionDetectorPlatform.instance.getVpnInfo();
  }

  /// A stream of [VpnConnectionState] that emits whenever the VPN
  /// connection status changes.
  ///
  /// The stream emits:
  /// - [VpnConnectionState.connected] when a VPN connects
  /// - [VpnConnectionState.disconnected] when a VPN disconnects
  ///
  /// The stream also emits the current state immediately when first listened to.
  ///
  /// Example:
  /// ```dart
  /// final detector = VpnConnectionDetector();
  /// detector.vpnConnectionStream.listen((state) {
  ///   switch (state) {
  ///     case VpnConnectionState.connected:
  ///       print('VPN connected');
  ///       break;
  ///     case VpnConnectionState.disconnected:
  ///       print('VPN disconnected');
  ///       break;
  ///   }
  /// });
  /// ```
  Stream<VpnConnectionState> get vpnConnectionStream => _stateController.stream;

  /// The current VPN connection state, if known.
  ///
  /// Returns `null` if the state hasn't been determined yet.
  /// Use [isVpnActive] for a reliable one-time check.
  VpnConnectionState? get currentState => _lastState;

  /// Disposes of the [VpnConnectionDetector] and releases all resources.
  ///
  /// After calling this method, the singleton instance is cleared and
  /// a new instance will be created on the next call to the constructor.
  ///
  /// Only call this if you're using [vpnConnectionStream]. If you're only
  /// using [isVpnActive], you don't need to call dispose.
  void dispose() {
    _platformSubscription?.cancel();
    _platformSubscription = null;
    _stateController.close();
    _lastState = null;
    _instance = null;
  }
}
