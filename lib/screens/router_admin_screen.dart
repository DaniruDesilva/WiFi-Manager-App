import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/router_defaults_service.dart';
import '../models/router_credential.dart';

class RouterAdminScreen extends StatefulWidget {
  final String? gatewayIp;

  const RouterAdminScreen({super.key, this.gatewayIp});

  @override
  State<RouterAdminScreen> createState() => _RouterAdminScreenState();
}

class _RouterAdminScreenState extends State<RouterAdminScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Could not load router page.\n${error.description}';
            });
          },
        ),
      );

    _detectAndLoadGateway();
  }

  Future<void> _detectAndLoadGateway() async {
    String? gateway = widget.gatewayIp;

    if (gateway == null || gateway.isEmpty) {
      try {
        final info = NetworkInfo();
        gateway = await info.getWifiGatewayIP();
      } catch (_) {}
    }

    if (gateway != null && gateway.isNotEmpty) {
      final url = 'http://$gateway';
      _urlController.text = url;
      _webViewController.loadRequest(Uri.parse(url));
    } else {
      setState(() {
        _errorMessage = 'Could not detect router IP.\nPlease enter the URL manually.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Router Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_counterclockwise_24_regular),
            onPressed: () => _webViewController.reload(),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.arrow_left_24_regular, size: 20),
                  onPressed: () => _webViewController.goBack(),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.arrow_right_24_regular, size: 20),
                  onPressed: () => _webViewController.goForward(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.1',
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(FluentIcons.arrow_right_24_regular, size: 18),
                        onPressed: () {
                          final url = _urlController.text.trim();
                          if (url.isNotEmpty) {
                            final fullUrl = url.startsWith('http') ? url : 'http://$url';
                            _webViewController.loadRequest(Uri.parse(fullUrl));
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    onSubmitted: (url) {
                      if (url.isNotEmpty) {
                        final fullUrl = url.startsWith('http') ? url : 'http://$url';
                        _webViewController.loadRequest(Uri.parse(fullUrl));
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
            ),

          // WebView or Error
          Expanded(
            child: _errorMessage != null
                ? _buildErrorState(context)
                : WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPasswordSheet(context),
        icon: const Icon(FluentIcons.key_24_filled),
        label: const Text('Default Passwords', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ).animate().slideY(begin: 2, delay: 500.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.globe_24_regular, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Router Unreachable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _detectAndLoadGateway,
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PasswordBottomSheet(),
    );
  }
}

class _PasswordBottomSheet extends StatefulWidget {
  @override
  State<_PasswordBottomSheet> createState() => _PasswordBottomSheetState();
}

class _PasswordBottomSheetState extends State<_PasswordBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<RouterCredential> _results = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = RouterDefaultsService.instance;
    await service.loadDatabase();
    setState(() {
      _results = service.getAll();
      _isLoaded = true;
    });
  }

  void _onSearch(String query) {
    final service = RouterDefaultsService.instance;
    setState(() {
      _results = service.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Default Router Passwords',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search by brand or model...',
                  prefixIcon: const Icon(FluentIcons.search_24_regular),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Results
            Expanded(
              child: !_isLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text('No results found.', style: TextStyle(color: Colors.grey.shade500)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _results.length,
                          itemBuilder: (ctx, index) {
                            final cred = _results[index];
                            return _buildCredentialTile(ctx, cred);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialTile(BuildContext context, RouterCredential cred) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cred.brand, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            cred.modelsDisplay,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCopyField(context, 'User', cred.defaultUsername),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCopyField(context, 'Pass', cred.defaultPassword),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(BuildContext context, String label, String value) {
    return GestureDetector(
      onTap: () {
        if (value != '(none)' && value != '(blank)' && value != '(set during setup)' && value != '(on device label)' && value != '(use Google Home app)' && value != '(use Eero app)') {
          // ignore system clipboard import - it's in the parent file's scope
          // We'll use the Clipboard from services
          _copyToClipboard(context, label, value);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            Icon(FluentIcons.copy_24_regular, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
