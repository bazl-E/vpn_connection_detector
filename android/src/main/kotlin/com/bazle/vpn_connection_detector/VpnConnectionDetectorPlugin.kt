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

    private fun checkNetworkInterfaces(): Boolean {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            
            for (networkInterface in interfaces) {
                val name = networkInterface.name.lowercase()
                
                // Common VPN interface patterns
                val vpnPatterns = listOf("tun", "tap", "ppp", "pptp", "l2tp", "ipsec", "vpn", "wireguard", "wg")
                
                for (pattern in vpnPatterns) {
                    if (name.contains(pattern) && networkInterface.isUp) {
                        return true
                    }
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
            // Try to get interface name and protocol
            try {
                val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
                
                for (networkInterface in interfaces) {
                    val name = networkInterface.name.lowercase()
                    val vpnPatterns = listOf("tun", "tap", "ppp", "pptp", "l2tp", "ipsec", "vpn", "wireguard", "wg")
                    
                    for (pattern in vpnPatterns) {
                        if (name.contains(pattern) && networkInterface.isUp) {
                            info["interfaceName"] = networkInterface.name
                            info["vpnProtocol"] = guessProtocol(name)
                            return info
                        }
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
