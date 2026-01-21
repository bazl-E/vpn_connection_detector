import 'package:flutter/material.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN Connection Detector Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _vpnDetector = VpnConnectionDetector();
  VpnInfo? _vpnInfo;
  bool _isChecking = false;

  @override
  void dispose() {
    _vpnDetector.dispose();
    super.dispose();
  }

  Future<void> _checkVpnInfo() async {
    setState(() => _isChecking = true);

    final info = await VpnConnectionDetector.getVpnInfo();

    setState(() {
      _vpnInfo = info;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('VPN Connection Detector'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stream-based detection
            _buildCard(
              title: 'Real-time VPN Status (Stream)',
              icon: Icons.stream,
              child: StreamBuilder<VpnConnectionState>(
                stream: _vpnDetector.vpnConnectionStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildStatusChip(
                      'Error: ${snapshot.error}',
                      Colors.red,
                      Icons.error,
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final isConnected =
                      snapshot.data == VpnConnectionState.connected;
                  return _buildStatusChip(
                    isConnected ? 'VPN Connected' : 'VPN Disconnected',
                    isConnected ? Colors.green : Colors.orange,
                    isConnected ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // One-time check
            _buildCard(
              title: 'One-time VPN Check (Static)',
              icon: Icons.check_circle_outline,
              child: FutureBuilder<bool>(
                future: VpnConnectionDetector.isVpnActive(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final isActive = snapshot.data ?? false;
                  return _buildStatusChip(
                    isActive ? 'VPN Active' : 'VPN Inactive',
                    isActive ? Colors.green : Colors.orange,
                    isActive ? Icons.check_circle : Icons.cancel,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Detailed VPN Info
            _buildCard(
              title: 'Detailed VPN Information',
              icon: Icons.info_outline,
              child: Column(
                children: [
                  if (_isChecking)
                    const CircularProgressIndicator()
                  else if (_vpnInfo != null)
                    _buildVpnInfoDetails(_vpnInfo!)
                  else
                    const Text('Tap button below to check VPN details'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkVpnInfo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Get VPN Info'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Current state
            _buildCard(
              title: 'Current Cached State',
              icon: Icons.cached,
              child: Text(
                _vpnDetector.currentState?.name ?? 'Not determined yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            Center(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  Widget _buildVpnInfoDetails(VpnInfo info) {
    return Column(
      children: [
        _buildInfoRow(
          'Status',
          info.isConnected ? 'Connected' : 'Disconnected',
          info.isConnected ? Colors.green : Colors.orange,
        ),
        if (info.interfaceName != null)
          _buildInfoRow('Interface', info.interfaceName!, Colors.blue),
        if (info.vpnProtocol != null)
          _buildInfoRow('Protocol', info.vpnProtocol!, Colors.purple),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
