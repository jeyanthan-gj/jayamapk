import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class SmartphoneDetailScreen extends StatefulWidget {
  final String id;
  const SmartphoneDetailScreen({super.key, required this.id});

  @override
  State<SmartphoneDetailScreen> createState() => _SmartphoneDetailScreenState();
}

class _SmartphoneDetailScreenState extends State<SmartphoneDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _model;
  Map<String, dynamic>? _selectedVariant;
  String _brandName = '';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final res = await Supabase.instance.client.from('models').select('*, variants(*)').eq('id', widget.id).single();
      
      String bName = 'Unknown';
      if (res['brand_id'] != null) {
        final brandRes = await Supabase.instance.client.from('brands').select('name').eq('id', res['brand_id']).maybeSingle();
        if (brandRes != null) bName = brandRes['name'] ?? 'Unknown';
      }

      if (mounted) {
        setState(() {
          _model = res;
          _brandName = bName;
          final variants = List<Map<String,dynamic>>.from(res['variants'] ?? []);
          if (variants.isNotEmpty) {
            _selectedVariant = variants[0];
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching detail: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSpecItem(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    if (_model == null) return const Scaffold(body: Center(child: Text('Model not found')));

    final variants = List<Map<String,dynamic>>.from(_model!['variants'] ?? []);
    final imageUrl = _selectedVariant?['image_url'] ?? _model!['image_url'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop()),
        title: const Text('Back to Smartphones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 600;
                  final content = [
                    Container(
                      width: isDesktop ? constraints.maxWidth / 3 : double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: imageUrl != null 
                          ? Image.network(imageUrl, fit: BoxFit.contain)
                          : const Icon(LucideIcons.smartphone, size: 64, color: Colors.grey),
                      ),
                    ),
                    if (isDesktop) const SizedBox(width: 48) else const SizedBox(height: 32),
                    Expanded(
                      flex: isDesktop ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_brandName.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(_model!['name'], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk')),
                          const SizedBox(height: 32),
                          const Text('SELECT VARIANT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12, runSpacing: 12,
                            children: variants.map((v) {
                              final isSelected = _selectedVariant?['id'] == v['id'];
                              return GestureDetector(
                                onTap: () => setState(() => _selectedVariant = v),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent, width: 2),
                                  ),
                                  child: Text('${v['ram_rom']} • ${v['color']}', style: TextStyle(color: isSelected ? AppTheme.primary : Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          const Text('PRICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text('₹${_selectedVariant?['price'] ?? 'N/A'}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                        ],
                      ),
                    )
                  ];

                  if (isDesktop) {
                     return Row(crossAxisAlignment: CrossAxisAlignment.start, children: content);
                  } else {
                     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content);
                  }
                }
              ),
              const SizedBox(height: 48),
              const Row(
                children: [
                  Icon(LucideIcons.monitor, color: AppTheme.primary),
                  SizedBox(width: 12),
                  Text('Technical Specifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk')),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                   final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 1;
                   final spacing = 16.0;
                   // To avoid layout errors when calculating width, we subtract an extra pixel to be safe.
                   final cardWidth = (constraints.maxWidth - spacing * (cols - 1) - 1) / cols;
                   final items = [
                     _buildSpecItem(LucideIcons.monitor, 'DISPLAY', _selectedVariant?['display'] ?? _model!['display']),
                     _buildSpecItem(LucideIcons.hardDrive, 'RAM / ROM', _selectedVariant?['ram_rom']),
                     _buildSpecItem(LucideIcons.palette, 'COLOR', _selectedVariant?['color']),
                     _buildSpecItem(LucideIcons.battery, 'BATTERY', _selectedVariant?['battery'] ?? _model!['battery']),
                     _buildSpecItem(LucideIcons.zap, 'CHARGING', _selectedVariant?['charging_speed'] ?? _model!['charging_speed']),
                     _buildSpecItem(LucideIcons.camera, 'FRONT CAMERA', _selectedVariant?['front_camera'] ?? _model!['front_camera']),
                     _buildSpecItem(LucideIcons.camera, 'BACK CAMERA', _selectedVariant?['back_camera'] ?? _model!['back_camera']),
                     _buildSpecItem(LucideIcons.cpu, 'PROCESSOR', _selectedVariant?['processor'] ?? _model!['processor']),
                   ].where((w) => w is! SizedBox).toList();
                   
                   return Wrap(
                     spacing: spacing,
                     runSpacing: spacing,
                     children: items.map((w) => SizedBox(width: cardWidth, child: w)).toList(),
                   );
                }
              )
            ],
          ),
        ),
      ),
    );
  }
}
