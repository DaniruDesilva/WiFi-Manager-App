import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/router_defaults_service.dart';
import '../models/router_credential.dart';

class RouterPasswordsScreen extends StatefulWidget {
  const RouterPasswordsScreen({super.key});

  @override
  State<RouterPasswordsScreen> createState() => _RouterPasswordsScreenState();
}

class _RouterPasswordsScreenState extends State<RouterPasswordsScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Default Router Passwords', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by brand or model...',
                prefixIcon: const Icon(FluentIcons.search_24_regular),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ).animate().fade().slideY(begin: -0.2),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  '${_results.length} router${_results.length != 1 ? 's' : ''} found',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: !_isLoaded
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.search_24_regular, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text('No matching routers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different brand or model name.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : _buildGroupedList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    // Group by brand
    final Map<String, List<RouterCredential>> grouped = {};
    for (final cred in _results) {
      grouped.putIfAbsent(cred.brand, () => []).add(cred);
    }

    final sortedBrands = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: sortedBrands.length,
      itemBuilder: (context, brandIndex) {
        final brand = sortedBrands[brandIndex];
        final creds = grouped[brand]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (brandIndex > 0) const SizedBox(height: 8),
            // Brand header
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                brand,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...creds.asMap().entries.map((entry) {
              final cred = entry.value;
              return _buildCredentialCard(context, cred, brandIndex * 10 + entry.key);
            }),
          ],
        );
      },
    );
  }

  Widget _buildCredentialCard(BuildContext context, RouterCredential cred, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Models
          Text(
            cred.modelsDisplay,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCopyableField(context, 'Username', cred.defaultUsername)),
              const SizedBox(width: 10),
              Expanded(child: _buildCopyableField(context, 'Password', cred.defaultPassword)),
            ],
          ),
          if (cred.defaultLoginUrl != null) ...[
            const SizedBox(height: 8),
            _buildCopyableField(context, 'Login URL', cred.defaultLoginUrl!),
          ],
        ],
      ),
    ).animate().fade(delay: Duration(milliseconds: (index * 30).clamp(0, 300))).slideX(begin: 0.05);
  }

  Widget _buildCopyableField(BuildContext context, String label, String value) {
    final isCopyable = value != '(none)' &&
        value != '(blank)' &&
        value != '(set during setup)' &&
        value != '(on device label)' &&
        value != '(use Google Home app)' &&
        value != '(use Eero app)';

    return GestureDetector(
      onTap: isCopyable
          ? () {
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
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            if (isCopyable)
              Icon(FluentIcons.copy_24_regular, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
