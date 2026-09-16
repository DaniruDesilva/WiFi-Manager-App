
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../providers/wifi_analyzer_provider.dart';
import '../models/wifi_access_point.dart';

class WifiAnalyzerScreen extends StatefulWidget {
  const WifiAnalyzerScreen({super.key});

  @override
  State<WifiAnalyzerScreen> createState() => _WifiAnalyzerScreenState();
}

class _WifiAnalyzerScreenState extends State<WifiAnalyzerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBand = '2.4 GHz';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WifiAnalyzerProvider>().startScanning();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Analyzer', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
            onPressed: () {
              context.read<WifiAnalyzerProvider>().forceScan();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Signal Meter'),
            Tab(text: 'Channel Graph'),
          ],
        ),
      ),
      body: Consumer<WifiAnalyzerProvider>(
        builder: (context, analyzer, child) {
          if (!analyzer.isSupported) {
            return _buildUnsupportedState(context);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildSignalMeterTab(context, analyzer),
              _buildChannelGraphTab(context, analyzer),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnsupportedState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.error_circle_24_regular, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Not Available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Wi-Fi scanning is only supported on Android.\nThis feature requires Android-specific APIs.',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSignalMeterTab(BuildContext context, WifiAnalyzerProvider analyzer) {
    final connected = analyzer.connectedNetwork;

    if (connected == null) {
      if (analyzer.isScanning) {
        return _buildLoadingState();
      }
      return _buildEmptyState(context, analyzer);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await analyzer.forceScan();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Signal Gauge
            _buildSignalGauge(context, connected).animate().fade().scale(),
            const SizedBox(height: 32),

            // Connection Info Cards
            Row(
              children: [
                _buildStatCard(context, 'Channel', '${connected.channel}', FluentIcons.channel_24_regular),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Frequency', '${connected.frequency} MHz', FluentIcons.pulse_24_regular),
              ],
            ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard(context, 'Band', connected.band, FluentIcons.cellular_data_1_24_regular),
                const SizedBox(width: 12),
                _buildStatCard(context, 'RSSI', '${connected.rssi} dBm', FluentIcons.cellular_data_1_24_regular),
              ],
            ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 24),

            // Nearby Networks List
            if (analyzer.accessPoints.length > 1) ...[
              Row(
                children: [
                  Text(
                    'Nearby Networks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${analyzer.accessPoints.length} found',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...analyzer.accessPoints.map((ap) => _buildNetworkTile(context, ap, ap == connected)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalGauge(BuildContext context, WifiAccessPointModel network) {
    final percent = network.signalPercent;
    final color = _getSignalColor(network.rssi);

    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 16,
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${percent.round()}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    network.signalQuality,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          network.ssid,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTile(BuildContext context, WifiAccessPointModel ap, bool isConnected) {
    final color = _getSignalColor(ap.rssi);
    return GestureDetector(
      onTap: () => _showConnectDialog(context, ap),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isConnected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ap.ssid,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Connected',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ch ${ap.channel} • ${ap.band} • ${ap.rssi} dBm',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Action or Mini signal bars
            if (!isConnected)
              Icon(FluentIcons.plug_connected_24_regular, color: Theme.of(context).colorScheme.primary, size: 20)
            else
              _buildMiniSignalBars(ap.signalPercent, color),
          ],
        ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context, WifiAccessPointModel ap) {
    final passwordController = TextEditingController();
    bool isConnecting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Connect to ${ap.ssid}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnecting)
                    const CircularProgressIndicator()
                  else
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(FluentIcons.password_24_regular),
                      ),
                      obscureText: true,
                    ),
                ],
              ),
              actions: [
                if (!isConnecting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                if (!isConnecting)
                  ElevatedButton(
                    onPressed: () async {
                      setState(() => isConnecting = true);
                      final success = await WiFiForIoTPlugin.connect(
                        ap.ssid,
                        password: passwordController.text.isNotEmpty ? passwordController.text : null,
                        security: passwordController.text.isNotEmpty ? NetworkSecurity.WPA : NetworkSecurity.NONE,
                        joinOnce: false,
                      );
                      setState(() => isConnecting = false);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Connected successfully' : 'Failed to connect'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                        if (success) {
                          context.read<WifiAnalyzerProvider>().forceScan();
                        }
                      }
                    },
                    child: const Text('Connect'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniSignalBars(double percent, Color color) {
    const bars = 4;
    final filledBars = (percent / 25).ceil().clamp(0, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars, (i) {
        final height = 8.0 + (i * 5);
        return Container(
          width: 4,
          height: height,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: i < filledBars ? color : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildChannelGraphTab(BuildContext context, WifiAnalyzerProvider analyzer) {
    if (analyzer.accessPoints.isEmpty) {
      if (analyzer.isScanning) {
        return _buildLoadingState();
      }
      return _buildEmptyState(context, analyzer);
    }

    final bandAPs = analyzer.getByBand(_selectedBand);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Band toggle
          Row(
            children: [
              _buildBandChip('2.4 GHz'),
              const SizedBox(width: 8),
              _buildBandChip('5 GHz'),
            ],
          ).animate().fade(),
          const SizedBox(height: 24),

          // Channel chart
          Expanded(
            child: bandAPs.isEmpty
                ? Center(
                    child: Text(
                      'No networks found on $_selectedBand band.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : _buildChannelChart(context, bandAPs, analyzer),
          ),

          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: bandAPs.take(6).map((ap) {
              final color = _getNetworkColor(bandAPs.indexOf(ap));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ap.ssid.length > 15 ? '${ap.ssid.substring(0, 15)}...' : ap.ssid,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBandChip(String band) {
    final isSelected = _selectedBand == band;
    return GestureDetector(
      onTap: () => setState(() => _selectedBand = band),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Text(
          band,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelChart(BuildContext context, List<WifiAccessPointModel> aps, WifiAnalyzerProvider analyzer) {
    final maxChannel = _selectedBand == '2.4 GHz' ? 14.0 : 165.0;
    final minChannel = _selectedBand == '2.4 GHz' ? 1.0 : 36.0;

    return LineChart(
      LineChartData(
        minX: minChannel - 2,
        maxX: maxChannel + 2,
        minY: -100,
        maxY: -20,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Channel', style: TextStyle(fontSize: 12)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _selectedBand == '2.4 GHz' ? 1 : 20,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: aps.asMap().entries.map((entry) {
          final index = entry.key;
          final ap = entry.value;
          final color = _getNetworkColor(index);
          final isConnected = ap == analyzer.connectedNetwork;
          final ch = ap.channel.toDouble();
          final width = _selectedBand == '2.4 GHz' ? 2.5 : 5.0;
          
          final peakRssi = ap.rssi.toDouble();
          const baseRssi = -100.0;
          
          // Generate points for a smooth parabola (bell-like curve)
          List<FlSpot> spots = [];
          const numPoints = 15;
          final a = (baseRssi - peakRssi) / (width * width);
          
          for (int i = 0; i <= numPoints; i++) {
            final x = (ch - width) + (2 * width * (i / numPoints));
            final y = a * (x - ch) * (x - ch) + peakRssi;
            spots.add(FlSpot(x, y));
          }

          return LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2, // Smoother than before
            color: color,
            barWidth: isConnected ? 3 : 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2), // Slightly more opaque
            ),
          );
        }).toList(),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  Color _getNetworkColor(int index) {
    const colors = [
      Color(0xFF00D4FF), // Electric Blue (user's network)
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFFD97706),
      Color(0xFFEC4899),
      Color(0xFF0EA5E9),
      Color(0xFF8B5CF6),
    ];
    return colors[index % colors.length];
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Scanning for networks...', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WifiAnalyzerProvider analyzer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.wifi_off_24_regular, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('No Wi-Fi detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              analyzer.errorMessage != null ? 'Unable to scan networks' : 'Connect to a Wi-Fi network to analyze', 
              style: TextStyle(color: Colors.grey.shade500)
            ),
            const SizedBox(height: 24),
            if (analyzer.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(FluentIcons.error_circle_24_regular, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        analyzer.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
