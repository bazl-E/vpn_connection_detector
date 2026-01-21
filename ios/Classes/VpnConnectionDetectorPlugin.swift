import Flutter
import UIKit
import NetworkExtension
import Network

public class VpnConnectionDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var vpnStatusObserver: NSObjectProtocol?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.vpnconnectiondetector.monitor")
    
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
            result(isVpnConnected())
        case "getVpnInfo":
            result(getVpnInfo())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - VPN Detection Methods
    
    private func isVpnConnected() -> Bool {
        // Method 1: Check NEVPNManager status
        if checkNEVPNStatus() {
            return true
        }
        
        // Method 2: Check network interfaces
        if checkNetworkInterfaces() {
            return true
        }
        
        // Method 3: Check NWPath (iOS 12+)
        if checkNWPath() {
            return true
        }
        
        return false
    }
    
    private func checkNEVPNStatus() -> Bool {
        let vpnManager = NEVPNManager.shared()
        let status = vpnManager.connection.status
        return status == .connected || status == .connecting
    }
    
    private func checkNetworkInterfaces() -> Bool {
        guard let cfAddresses = CFCopyIfAddresses()?.takeRetainedValue() else {
            return false
        }
        
        let interfaces = cfAddresses as NSArray
        
        for interface in interfaces {
            guard let interfaceDict = interface as? [String: Any],
                  let interfaceName = interfaceDict["ifname"] as? String else {
                continue
            }
            
            let lowercaseName = interfaceName.lowercased()
            
            // Common VPN interface patterns
            let vpnPatterns = ["tun", "tap", "ppp", "ipsec", "utun", "vpn"]
            
            // Skip interfaces that are always present on iOS (false positives)
            let ignorePatterns = ["utun0", "utun1", "utun2"]
            
            if ignorePatterns.contains(lowercaseName) {
                continue
            }
            
            for pattern in vpnPatterns {
                if lowercaseName.contains(pattern) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func checkNWPath() -> Bool {
        var isVPN = false
        let semaphore = DispatchSemaphore(value: 0)
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            // Check if the path uses a VPN interface
            isVPN = path.usesInterfaceType(.other) && path.status == .satisfied
            
            // Additional check: if we have both WiFi/Cellular and "other", likely VPN
            if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular) {
                if path.usesInterfaceType(.other) {
                    isVPN = true
                }
            }
            
            monitor.cancel()
            semaphore.signal()
        }
        
        monitor.start(queue: monitorQueue)
        
        // Wait with timeout
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        return isVPN
    }
    
    private func getVpnInfo() -> [String: Any] {
        let isConnected = isVpnConnected()
        var info: [String: Any] = ["isConnected": isConnected]
        
        if isConnected {
            // Try to get more info from NEVPNManager
            let vpnManager = NEVPNManager.shared()
            if let proto = vpnManager.protocolConfiguration {
                if proto is NEVPNProtocolIKEv2 {
                    info["vpnProtocol"] = "IKEv2"
                } else if proto is NEVPNProtocolIPSec {
                    info["vpnProtocol"] = "IPSec"
                }
            }
            
            // Try to get interface name
            if let interfaceName = findVpnInterface() {
                info["interfaceName"] = interfaceName
            }
        }
        
        return info
    }
    
    private func findVpnInterface() -> String? {
        guard let cfAddresses = CFCopyIfAddresses()?.takeRetainedValue() else {
            return nil
        }
        
        let interfaces = cfAddresses as NSArray
        
        for interface in interfaces {
            guard let interfaceDict = interface as? [String: Any],
                  let interfaceName = interfaceDict["ifname"] as? String else {
                continue
            }
            
            let lowercaseName = interfaceName.lowercased()
            let vpnPatterns = ["tun", "tap", "ppp", "ipsec", "utun", "vpn"]
            let ignorePatterns = ["utun0", "utun1", "utun2"]
            
            if ignorePatterns.contains(lowercaseName) {
                continue
            }
            
            for pattern in vpnPatterns {
                if lowercaseName.contains(pattern) {
                    return interfaceName
                }
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
        // Monitor NEVPNManager status changes
        vpnStatusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notifyStatusChange()
        }
        
        // Monitor network path changes
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.notifyStatusChange()
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    private func stopMonitoring() {
        if let observer = vpnStatusObserver {
            NotificationCenter.default.removeObserver(observer)
            vpnStatusObserver = nil
        }
        
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    private func notifyStatusChange() {
        eventSink?(isVpnConnected())
    }
}

// Helper function to get network interfaces
private func CFCopyIfAddresses() -> Unmanaged<CFArray>? {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    
    guard getifaddrs(&addrs) == 0, let firstAddr = addrs else {
        return nil
    }
    
    var interfaces: [[String: Any]] = []
    var ptr = firstAddr
    
    while true {
        let interface = ptr.pointee
        let name = String(cString: interface.ifa_name)
        
        interfaces.append(["ifname": name])
        
        if let next = interface.ifa_next {
            ptr = next
        } else {
            break
        }
    }
    
    freeifaddrs(addrs)
    
    return Unmanaged.passRetained(interfaces as CFArray)
}
