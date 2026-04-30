import Flutter
import UIKit
import Network
import SystemConfiguration

public class VpnConnectionDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.vpnconnectiondetector.monitor")
    
    // Enable debug logging
    private let debugEnabled = false
    
    private func log(_ message: String) {
        if debugEnabled {
            print("[VPN_DETECTOR] \(message)")
        }
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "vpn_connection_detector", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "vpn_connection_detector/status", binaryMessenger: registrar.messenger())
        
        let instance = VpnConnectionDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isVpnActive":
            let isActive = isVpnConnected()
            log("isVpnActive called, result: \(isActive)")
            result(isActive)
        case "getVpnInfo":
            let info = getVpnInfo()
            log("getVpnInfo called, result: \(info)")
            result(info)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - VPN Detection Methods
    
    private func isVpnConnected() -> Bool {
        log("=== Starting VPN detection ===")
        
        // Check for VPN interfaces in CFNetwork SCOPED dictionary
        // This is the MOST RELIABLE method for detecting both system VPNs
        // and third-party VPN apps (NordVPN, ExpressVPN, ProtonVPN, etc.)
        // Does NOT require NetworkExtension entitlement.
        let scopedResult = checkScopedVPNInterfaces()
        log("SCOPED VPN Interfaces: \(scopedResult)")
        
        if !scopedResult {
            log("=== VPN detection complete: NOT CONNECTED ===")
        }
        
        return scopedResult
    }
    
    /// The most reliable VPN detection method for iOS
    /// When a VPN is active, it appears in the __SCOPED__ section of CFNetworkCopySystemProxySettings
    /// The key difference between VPN and system utun interfaces is:
    /// - System utun (iCloud Relay, Push, etc.) do NOT appear in __SCOPED__
    /// - VPN utun interfaces DO appear in __SCOPED__ because they handle routing
    private func checkScopedVPNInterfaces() -> Bool {
        log("  Checking SCOPED interfaces for VPN...")
        
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            log("  Could not get proxy settings")
            return false
        }
        
        // Log all top-level keys for debugging
        let topLevelKeys = cfDict.keys.sorted().joined(separator: ", ")
        log("  CFNetwork top-level keys: \(topLevelKeys)")
        
        // Get the __SCOPED__ dictionary - this contains active network interfaces
        guard let scoped = cfDict["__SCOPED__"] as? [String: Any] else {
            log("  No __SCOPED__ dictionary found")
            return false
        }
        
        let scopedInterfaces = scoped.keys.sorted().joined(separator: ", ")
        log("  SCOPED interfaces: \(scopedInterfaces)")
        
        // Check each interface in SCOPED
        for (interface, config) in scoped {
            let interfaceLower = interface.lowercased()
            
            // Log the interface configuration
            if let configDict = config as? [String: Any] {
                let configKeys = configDict.keys.sorted().joined(separator: ", ")
                log("    \(interface): \(configKeys)")
            }
            
            // Skip known non-VPN interfaces
            // These are standard iOS network interfaces
            if interfaceLower.hasPrefix("en") ||        // WiFi/Ethernet (en0, en1, etc.)
               interfaceLower.hasPrefix("pdp_ip") ||    // Cellular data
               interfaceLower.hasPrefix("bridge") ||    // Bridge interfaces
               interfaceLower.hasPrefix("ap") ||        // Access point
               interfaceLower.hasPrefix("awdl") ||      // Apple Wireless Direct Link
               interfaceLower.hasPrefix("llw") ||       // Low Latency WLAN
               interfaceLower.hasPrefix("lo") {         // Loopback
                log("    Skipping known non-VPN interface: \(interface)")
                continue
            }
            
            // VPN interfaces that appear in SCOPED:
            // - utun* (OpenVPN, WireGuard, IPSec tunnel, etc.)
            // - ipsec* (IPSec)
            // - tun* (not utun - generic TUN)
            // - tap* (TAP interfaces)
            // - ppp* (PPP/L2TP)
            
            // If a utun/ipsec/tun/tap/ppp interface appears in SCOPED, it's a VPN
            // System utun interfaces (iCloud Relay, Push) do NOT appear in SCOPED
            if interfaceLower.hasPrefix("utun") ||
               interfaceLower.hasPrefix("ipsec") ||
               (interfaceLower.hasPrefix("tun") && !interfaceLower.hasPrefix("utun")) ||
               interfaceLower.hasPrefix("tap") ||
               interfaceLower.hasPrefix("ppp") {
                log("  ✓ Found VPN interface in SCOPED: \(interface)")
                return true
            }
        }
        
        log("  No VPN interfaces found in SCOPED")
        return false
    }
    
    private func getVpnInfo() -> [String: Any] {
        let isConnected = isVpnConnected()
        var info: [String: Any] = ["isConnected": isConnected]
        
        if isConnected {
            // Get interface name from SCOPED
            if let interfaceName = findActiveVpnInterface() {
                info["interfaceName"] = interfaceName
                
                // Guess protocol from interface name
                let lower = interfaceName.lowercased()
                if lower.hasPrefix("utun") {
                    info["vpnProtocol"] = "Tunnel"
                } else if lower.hasPrefix("ppp") {
                    info["vpnProtocol"] = "PPP"
                } else if lower.hasPrefix("tun") {
                    info["vpnProtocol"] = "TUN"
                } else if lower.hasPrefix("tap") {
                    info["vpnProtocol"] = "TAP"
                } else if lower.hasPrefix("ipsec") {
                    info["vpnProtocol"] = "IPSec"
                }
            }
        }
        
        return info
    }
    
    private func findActiveVpnInterface() -> String? {
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = cfDict["__SCOPED__"] as? [String: Any] else {
            return nil
        }
        
        for interface in scoped.keys {
            let interfaceLower = interface.lowercased()
            
            // Skip known non-VPN interfaces
            if interfaceLower.hasPrefix("en") ||
               interfaceLower.hasPrefix("pdp_ip") ||
               interfaceLower.hasPrefix("bridge") ||
               interfaceLower.hasPrefix("ap") ||
               interfaceLower.hasPrefix("awdl") ||
               interfaceLower.hasPrefix("llw") ||
               interfaceLower.hasPrefix("lo") {
                continue
            }
            
            // Return VPN interface names
            if interfaceLower.hasPrefix("utun") ||
               interfaceLower.hasPrefix("ipsec") ||
               (interfaceLower.hasPrefix("tun") && !interfaceLower.hasPrefix("utun")) ||
               interfaceLower.hasPrefix("tap") ||
               interfaceLower.hasPrefix("ppp") {
                return interface
            }
        }
        
        return nil
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // Send initial status
        events(isVpnConnected())
        
        // Start monitoring VPN status changes
        startMonitoring()
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopMonitoring()
        eventSink = nil
        return nil
    }
    
    private func startMonitoring() {
        // Monitor network path changes (this catches VPN connect/disconnect events)
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.notifyStatusChange()
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    private func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    private func notifyStatusChange() {
        let isConnected = isVpnConnected()
        log("Status change notification, VPN connected: \(isConnected)")
        eventSink?(isConnected)
    }
}
