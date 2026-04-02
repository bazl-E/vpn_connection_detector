import FlutterMacOS
import Network
import SystemConfiguration

public class VpnConnectionDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.vpnconnectiondetector.monitor")
    
    /// Track last emitted VPN state to avoid sending duplicate events
    private var lastEmittedVpnStatus: Bool?
    
    /// Known non-VPN interface prefixes
    private static let nonVpnPrefixes = [
        "en", "bridge", "ap", "awdl", "llw", "lo",  // Common to iOS/macOS
        "vmnet", "vboxnet",                           // Virtual machine interfaces (macOS)
        "gif", "stf", "anpi",                         // macOS system interfaces
    ]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "vpn_connection_detector", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "vpn_connection_detector/status", binaryMessenger: registrar.messenger)
        
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
        case "getAllVpnInfo":
            result(getAllVpnInfo())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - VPN Detection Methods
    
    /// Returns the SCOPED dictionary from CFNetworkCopySystemProxySettings, or nil.
    private func getScopedInterfaces() -> [String: Any]? {
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return cfDict["__SCOPED__"] as? [String: Any]
    }
    
    /// Checks if an interface name is a known non-VPN interface.
    private static func isNonVpnInterface(_ interfaceName: String) -> Bool {
        let lower = interfaceName.lowercased()
        return nonVpnPrefixes.contains { lower.hasPrefix($0) }
    }
    
    /// Checks if an interface name matches a known VPN pattern.
    private static func isVpnInterface(_ interfaceName: String) -> Bool {
        let lower = interfaceName.lowercased()
        return lower.hasPrefix("utun") ||
               lower.hasPrefix("ipsec") ||
               (lower.hasPrefix("tun") && !lower.hasPrefix("utun")) ||
               lower.hasPrefix("tap") ||
               lower.hasPrefix("ppp")
    }
    
    /// Guesses the VPN protocol from an interface name.
    private static func guessProtocol(_ interfaceName: String) -> String? {
        let lower = interfaceName.lowercased()
        if lower.hasPrefix("utun")  { return "Tunnel" }
        if lower.hasPrefix("ppp")   { return "PPP" }
        if lower.hasPrefix("ipsec") { return "IPSec" }
        if lower.hasPrefix("tap")   { return "TAP" }
        if lower.hasPrefix("tun")   { return "TUN" }
        return nil
    }
    
    /// Finds the first active VPN interface name from the given SCOPED dictionary.
    private func findVpnInterface(in scoped: [String: Any]) -> String? {
        for interface in scoped.keys {
            if VpnConnectionDetectorPlugin.isNonVpnInterface(interface) {
                continue
            }
            if VpnConnectionDetectorPlugin.isVpnInterface(interface) {
                return interface
            }
        }
        return nil
    }
    
    /// Finds all active VPN interface names from the given SCOPED dictionary.
    private func findAllVpnInterfaces(in scoped: [String: Any]) -> [String] {
        var results: [String] = []
        for interface in scoped.keys {
            if VpnConnectionDetectorPlugin.isNonVpnInterface(interface) {
                continue
            }
            if VpnConnectionDetectorPlugin.isVpnInterface(interface) {
                results.append(interface)
            }
        }
        return results
    }
    
    private func isVpnConnected() -> Bool {
        guard let scoped = getScopedInterfaces() else {
            return false
        }
        return findVpnInterface(in: scoped) != nil
    }
    
    private func getVpnInfo() -> [String: Any] {
        guard let scoped = getScopedInterfaces(),
              let interfaceName = findVpnInterface(in: scoped) else {
            return ["isConnected": false]
        }
        
        var info: [String: Any] = ["isConnected": true, "interfaceName": interfaceName]
        
        if let protocol_ = VpnConnectionDetectorPlugin.guessProtocol(interfaceName) {
            info["vpnProtocol"] = protocol_
        }
        
        return info
    }
    
    private func getAllVpnInfo() -> [[String: Any]] {
        guard let scoped = getScopedInterfaces() else {
            return []
        }
        
        let interfaces = findAllVpnInterfaces(in: scoped)
        return interfaces.map { interfaceName in
            var info: [String: Any] = ["isConnected": true, "interfaceName": interfaceName]
            if let protocol_ = VpnConnectionDetectorPlugin.guessProtocol(interfaceName) {
                info["vpnProtocol"] = protocol_
            }
            return info
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        let initialStatus = isVpnConnected()
        lastEmittedVpnStatus = initialStatus
        events(initialStatus)
        
        startMonitoring()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopMonitoring()
        eventSink = nil
        lastEmittedVpnStatus = nil
        return nil
    }
    
    private func startMonitoring() {
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
        if isConnected != lastEmittedVpnStatus {
            lastEmittedVpnStatus = isConnected
            eventSink?(isConnected)
        }
    }
}
