package com.bazle.vpn_connection_detector

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.NetworkInterface
import java.util.Collections

/** VpnConnectionDetectorPlugin */
class VpnConnectionDetectorPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    
    private var eventSink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var connectivityManager: ConnectivityManager? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn_connection_detector")
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "vpn_connection_detector/status")
        eventChannel.setStreamHandler(this)
        
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isVpnActive" -> {
                result.success(isVpnConnected())
            }
            "getVpnInfo" -> {
                result.success(getVpnInfo())
            }
            "isProxyActive" -> {
                result.success(isProxyConfigured())
            }
            "getProxyInfo" -> {
                result.success(getProxyInfo())
            }
            "isTrafficInterceptionActive" -> {
                result.success(isVpnConnected() || isProxyConfigured())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopMonitoring()
    }

    // MARK: - VPN Detection Methods

    private fun isVpnConnected(): Boolean {
        // Method 1: Check using NetworkCapabilities (API 23+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val cm = connectivityManager ?: return checkNetworkInterfaces()
            val activeNetwork = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return false
            
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return true
            }
        }
        
        // Method 2: Fallback to checking network interfaces
        return checkNetworkInterfaces()
    }

    /**
     * Interface name prefixes used by carrier-managed tunnels (VoWiFi / WiFi
     * Calling / ePDG / IMS PDN / cellular modem channels). These are NOT user
     * VPNs and must be skipped during interface scanning to avoid false
     * positives.
     *
     * Background: VoWiFi (Voice-over-WiFi / WiFi Calling) is implemented as an
     * IKEv2/IPsec tunnel to the carrier's ePDG (Evolved Packet Data Gateway).
     * The resulting network interface name is OEM-specific:
     *   - Xiaomi / Realme / Vivo:  vowifi_tun0
     *   - Samsung / Stock 3GPP:    epdg0, epdg_tun0
     *   - General IMS PDN:         ims*
     *   - Qualcomm cellular modem: rmnet*
     *   - MediaTek cellular modem: ccmni*
     *
     * Reported in issue #13.
     */
    private val carrierManagedPrefixes = listOf(
        "vowifi",
        "epdg",
        "ims",
        "rmnet",
        "ccmni",
    )

    /**
     * Real Android VPN apps go through VpnService, which always creates kernel
     * TUN devices named exactly tun0, tun1, etc. (and similar for tap, ppp,
     * wireguard's wg0 etc.). Using startsWith() instead of contains() rejects
     * carrier interfaces like "vowifi_tun0" that happen to embed the word
     * "tun" in their name.
     */
    private val vpnInterfacePrefixes = listOf(
        "tun", "utun", "tap", "ppp", "pptp", "l2tp", "ipsec", "vpn", "wg",
    )

    /** Distinctive substrings that are safe to substring-match. */
    private val vpnInterfaceSubstrings = listOf(
        "wireguard", "openvpn", "tailscale", "zerotier", "nordlynx",
    )

    private fun isVpnInterfaceName(name: String): Boolean {
        val lower = name.lowercase()
        // Defense-in-depth: never treat a known carrier-managed interface as VPN.
        if (carrierManagedPrefixes.any { lower.startsWith(it) }) return false
        if (vpnInterfacePrefixes.any { lower.startsWith(it) }) return true
        if (vpnInterfaceSubstrings.any { lower.contains(it) }) return true
        return false
    }

    private fun checkNetworkInterfaces(): Boolean {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())

            for (networkInterface in interfaces) {
                if (!networkInterface.isUp) continue
                if (isVpnInterfaceName(networkInterface.name)) {
                    return true
                }
            }
        } catch (e: Exception) {
            // If we can't list interfaces, fall through
        }

        return false
    }

    private fun getVpnInfo(): Map<String, Any?> {
        val isConnected = isVpnConnected()
        val info = mutableMapOf<String, Any?>(
            "isConnected" to isConnected
        )

        if (isConnected) {
            try {
                val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())

                for (networkInterface in interfaces) {
                    if (!networkInterface.isUp) continue
                    val name = networkInterface.name
                    if (isVpnInterfaceName(name)) {
                        info["interfaceName"] = name
                        info["vpnProtocol"] = guessProtocol(name.lowercase())
                        return info
                    }
                }
            } catch (e: Exception) {
                // Ignore
            }
        }

        return info
    }

    private fun guessProtocol(interfaceName: String): String? {
        val name = interfaceName.lowercase()
        
        return when {
            name.contains("wireguard") || name.contains("wg") -> "WireGuard"
            name.contains("ipsec") -> "IPsec"
            name.contains("l2tp") -> "L2TP"
            name.contains("pptp") -> "PPTP"
            name.contains("ppp") -> "PPP"
            name.contains("tun") || name.contains("tap") -> "TUN/TAP"
            else -> null
        }
    }

    // MARK: - Proxy Detection Methods

    /// Reads the system-wide default proxy via ConnectivityManager.getDefaultProxy().
    /// Available on API 23 (Android 6.0 Marshmallow) and above.
    /// Reference: https://developer.android.com/reference/android/net/ConnectivityManager#getDefaultProxy()
    /// On older devices (API 21-22) this returns false because Android does not
    /// expose a reliable public API to query the system proxy.
    private fun isProxyConfigured(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val cm = connectivityManager ?: return false
        val proxy = cm.defaultProxy ?: return false
        // ProxyInfo.isValid() validates that either host:port OR PAC URL is set.
        return proxy.isValid
    }

    private fun getProxyInfo(): Map<String, Any?> {
        val info = mutableMapOf<String, Any?>("isActive" to false)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return info
        val cm = connectivityManager ?: return info
        val proxy = cm.defaultProxy ?: return info
        if (!proxy.isValid) return info

        info["isActive"] = true
        val pacUrl = proxy.pacFileUrl
        // Uri.EMPTY is returned when no PAC file is set.
        val pacString = pacUrl?.toString()?.takeIf { it.isNotEmpty() }
        if (pacString != null) {
            info["proxyType"] = "pac"
            info["pacUrl"] = pacString
        } else {
            // Android only exposes a single host/port pair; treat as HTTP
            // (system proxy applies to HTTP and HTTPS traffic alike).
            info["proxyType"] = "http"
            info["host"] = proxy.host
            info["port"] = proxy.port
        }
        return info
    }

    // MARK: - EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        
        // Send initial status
        events?.success(isVpnConnected())
        
        // Start monitoring
        startMonitoring()
    }

    override fun onCancel(arguments: Any?) {
        stopMonitoring()
        eventSink = null
    }

    private fun startMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val cm = connectivityManager ?: return
            
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    notifyStatusChange()
                }

                override fun onLost(network: Network) {
                    notifyStatusChange()
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities
                ) {
                    notifyStatusChange()
                }
            }

            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
                .build()

            try {
                cm.registerNetworkCallback(request, networkCallback!!)
            } catch (e: Exception) {
                // Permission might be missing
            }

            // Also register for default network changes
            val defaultCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    notifyStatusChange()
                }

                override fun onLost(network: Network) {
                    notifyStatusChange()
                }
            }

            try {
                cm.registerDefaultNetworkCallback(defaultCallback)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private fun stopMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && networkCallback != null) {
            try {
                connectivityManager?.unregisterNetworkCallback(networkCallback!!)
            } catch (e: Exception) {
                // Ignore
            }
            networkCallback = null
        }
    }

    private fun notifyStatusChange() {
        // Post to main thread
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(isVpnConnected())
        }
    }
}
