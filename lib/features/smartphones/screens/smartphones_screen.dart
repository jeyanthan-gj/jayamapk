import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class SmartphonesScreen extends StatefulWidget {
  const SmartphonesScreen({super.key});
  @override
  State<SmartphonesScreen> createState() => _SmartphonesScreenState();
}

class _SmartphonesScreenState extends State<SmartphonesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];

  String _search = '';
  String _brandFilter = 'all';
  String _ramFilter = '';
  String _processorFilter = '';
  String _priceMin = '';
  String _priceMax = '';
  String _sortOrder = 'newest';
  bool _showFilters = false;

  // Brand dialog
  bool _brandDialogOpen = false;
  String _newBrandName = '';
  XFile? _brandFile;
  Map<String, dynamic>? _editingBrand;

  // Model dialog
  bool _modelDialogOpen = false;
  Map<String, dynamic>? _editingModel;
  XFile? _modelFile;
  List<Map<String, dynamic>> _variants = [];
  List<XFile?> _variantFiles = [];
  Map<String, String> _modelForm = {
    'brand_id': '', 'name': '', 'display': '', 'battery': '',
    'charging_speed': '', 'front_camera': '', 'back_camera': '', 'processor': '',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final brandsRes = await _supabase.from('brands').select('*').order('name');
      final modelsRes = await _supabase.from('models').select('*, variants(*)').order('name');
      if (mounted) {
        setState(() {
          _brands = List<Map<String, dynamic>>.from(brandsRes);
          _models = List<Map<String, dynamic>>.from(modelsRes);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getBrandName(String? brandId) {
    if (brandId == null) return 'Unknown';
    for (final b in _brands) {
      if (b['id'].toString() == brandId) return b['name'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  Future<String?> _uploadImage(XFile file, String folder) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '$folder/$fileName';
      await _supabase.storage.from('images').uploadBinary(filePath, bytes);
      return _supabase.storage.from('images').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _deleteImageFromStorage(String? url) async {
    if (url == null) return;
    try {
      final parts = url.split('/storage/v1/object/public/images/');
      if (parts.length > 1) await _supabase.storage.from('images').remove([parts[1]]);
    } catch (e) {
      debugPrint('Delete image error: $e');
    }
  }

  // ── Brand CRUD ────────────────────────────────────────────────────────────
  void _openBrandDialog([Map<String, dynamic>? brand]) {
    setState(() {
      _editingBrand = brand;
      _newBrandName = brand?['name'] ?? '';
      _brandFile = null;
      _brandDialogOpen = true;
    });
  }

  Future<void> _handleSaveBrand() async {
    if (_newBrandName.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      String? logoUrl = _editingBrand?['logo_url'];
      if (_brandFile != null) {
        if (_editingBrand?['logo_url'] != null) await _deleteImageFromStorage(_editingBrand!['logo_url']);
        logoUrl = await _uploadImage(_brandFile!, 'brands');
      }
      if (_editingBrand != null) {
        await _supabase.from('brands').update({'name': _newBrandName.trim(), 'logo_url': logoUrl}).eq('id', _editingBrand!['id']);
      } else {
        await _supabase.from('brands').insert({'name': _newBrandName.trim(), 'logo_url': logoUrl});
      }
      if (mounted) {
        setState(() => _brandDialogOpen = false);
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brand saved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteBrand(Map<String, dynamic> brand) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Delete ${brand['name']}?'),
      content: const Text('This will also delete all related models.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;

    try {
      final relModels = await _supabase.from('models').select('image_url').eq('brand_id', brand['id']);
      for (final m in relModels) { await _deleteImageFromStorage(m['image_url']); }
      await _deleteImageFromStorage(brand['logo_url']);
      await _supabase.from('brands').delete().eq('id', brand['id']);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brand deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  // ── Model CRUD ────────────────────────────────────────────────────────────
  void _openModelDialog([Map<String, dynamic>? model]) {
    if (model != null) {
      final existingVariants = List<Map<String, dynamic>>.from(model['variants'] ?? []);
      setState(() {
        _editingModel = model;
        _modelForm = {
          'brand_id': model['brand_id']?.toString() ?? '',
          'name': model['name'] ?? '',
          'display': model['display'] ?? '',
          'battery': model['battery'] ?? '',
          'charging_speed': model['charging_speed'] ?? '',
          'front_camera': model['front_camera'] ?? '',
          'back_camera': model['back_camera'] ?? '',
          'processor': model['processor'] ?? '',
        };
        _variants = existingVariants.map((v) => Map<String, dynamic>.from(v)).toList();
        _variantFiles = List.filled(_variants.length, null);
        _modelFile = null;
        _modelDialogOpen = true;
      });
    } else {
      setState(() {
        _editingModel = null;
        _modelForm = {
          'brand_id': _brands.isNotEmpty ? _brands[0]['id'].toString() : '',
          'name': '', 'display': '', 'battery': '',
          'charging_speed': '', 'front_camera': '', 'back_camera': '', 'processor': '',
        };
        _variants = [{'ram_rom': '', 'color': '', 'price': 0, 'display': '', 'battery': '', 'processor': '', 'charging_speed': '', 'front_camera': '', 'back_camera': '', 'image_url': null}];
        _variantFiles = [null];
        _modelFile = null;
        _modelDialogOpen = true;
      });
    }
  }

  Future<void> _handleSaveModel() async {
    if (_modelForm['name']!.trim().isEmpty || _modelForm['brand_id']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Brand are required'), backgroundColor: Colors.red));
      return;
    }
    if (_variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one variant is required'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Upload model image
      String? imageUrl = _editingModel?['image_url'];
      if (_modelFile != null) {
        if (_editingModel?['image_url'] != null) await _deleteImageFromStorage(_editingModel!['image_url']);
        imageUrl = await _uploadImage(_modelFile!, 'models');
      }

      final modelData = {
        'brand_id': _modelForm['brand_id'],
        'name': _modelForm['name']!.trim(),
        'display': _modelForm['display'],
        'battery': _modelForm['battery'],
        'charging_speed': _modelForm['charging_speed'],
        'front_camera': _modelForm['front_camera'],
        'back_camera': _modelForm['back_camera'],
        'processor': _modelForm['processor'],
        'image_url': imageUrl,
      };

      String? modelId;
      if (_editingModel != null) {
        await _supabase.from('models').update(modelData).eq('id', _editingModel!['id']);
        modelId = _editingModel!['id'].toString();
        await _supabase.from('variants').delete().eq('model_id', modelId);
      } else {
        final res = await _supabase.from('models').insert(modelData).select('id').single();
        modelId = res['id'].toString();
      }

      // Insert variants with image uploads
      final variantsToInsert = <Map<String, dynamic>>[];
      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        String? variantImageUrl = v['image_url'];
        if (_variantFiles.length > i && _variantFiles[i] != null) {
          variantImageUrl = await _uploadImage(_variantFiles[i]!, 'variants');
        }
        variantsToInsert.add({
          'model_id': modelId,
          'ram_rom': v['ram_rom'] ?? '',
          'color': v['color'] ?? '',
          'price': (v['price'] as num?)?.toInt() ?? 0,
          'display': v['display'] ?? _modelForm['display'],
          'battery': v['battery'] ?? _modelForm['battery'],
          'processor': v['processor'] ?? _modelForm['processor'],
          'charging_speed': v['charging_speed'] ?? _modelForm['charging_speed'],
          'front_camera': v['front_camera'] ?? _modelForm['front_camera'],
          'back_camera': v['back_camera'] ?? _modelForm['back_camera'],
          'image_url': variantImageUrl,
        });
      }
      await _supabase.from('variants').insert(variantsToInsert);

      if (mounted) {
        setState(() => _modelDialogOpen = false);
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingModel != null ? 'Model updated!' : 'Model added!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Save model error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteModel(Map<String, dynamic> model) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Delete ${model['name']}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    try {
      await _deleteImageFromStorage(model['image_url']);
      await _supabase.from('models').delete().eq('id', model['id']);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  // ── Filter logic (matching React) ─────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredModels {
    var list = _models.where((m) {
      final matchSearch = m['name'].toString().toLowerCase().contains(_search.toLowerCase());
      final matchBrand = _brandFilter == 'all' || m['brand_id'].toString() == _brandFilter;
      final variants = List<Map<String, dynamic>>.from(m['variants'] ?? []);
      final minP = double.tryParse(_priceMin) ?? 0;
      final maxP = double.tryParse(_priceMax);
      final matchPrice = (_priceMin.isEmpty && _priceMax.isEmpty) || variants.any((v) {
        final p = (v['price'] as num?)?.toDouble() ?? 0;
        return p >= minP && (maxP == null || p <= maxP);
      });
      final matchRam = _ramFilter.isEmpty || variants.any((v) => (v['ram_rom'] ?? '').toString().toLowerCase().contains(_ramFilter.toLowerCase()));
      final matchProc = _processorFilter.isEmpty ||
          (m['processor'] ?? '').toString().toLowerCase().contains(_processorFilter.toLowerCase()) ||
          variants.any((v) => (v['processor'] ?? '').toString().toLowerCase().contains(_processorFilter.toLowerCase()));
      return matchSearch && matchBrand && matchPrice && matchRam && matchProc;
    }).toList();

    if (_sortOrder == 'price-asc') {
      list.sort((a, b) {
        final va = List<Map<String, dynamic>>.from(a['variants'] ?? []);
        final vb = List<Map<String, dynamic>>.from(b['variants'] ?? []);
        final minA = va.isEmpty ? 0 : va.map((v) => (v['price'] as num?)?.toInt() ?? 0).reduce((x, y) => x < y ? x : y);
        final minB = vb.isEmpty ? 0 : vb.map((v) => (v['price'] as num?)?.toInt() ?? 0).reduce((x, y) => x < y ? x : y);
        return minA.compareTo(minB);
      });
    } else if (_sortOrder == 'price-desc') {
      list.sort((a, b) {
        final va = List<Map<String, dynamic>>.from(a['variants'] ?? []);
        final vb = List<Map<String, dynamic>>.from(b['variants'] ?? []);
        final maxA = va.isEmpty ? 0 : va.map((v) => (v['price'] as num?)?.toInt() ?? 0).reduce((x, y) => x > y ? x : y);
        final maxB = vb.isEmpty ? 0 : vb.map((v) => (v['price'] as num?)?.toInt() ?? 0).reduce((x, y) => x > y ? x : y);
        return maxB.compareTo(maxA);
      });
    } else if (_sortOrder == 'name-asc') {
      list.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    }
    return list;
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────
  InputDecoration _inputDec(String label, {String hint = ''}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );

  Widget _labelText(String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(txt, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)),
  );

  // ── Brand Dialog ──────────────────────────────────────────────────────────
  Widget _buildBrandDialog() {
    return StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(_editingBrand != null ? 'Edit Brand' : 'Add Brand', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _labelText('BRAND NAME'),
        TextField(
          controller: TextEditingController(text: _newBrandName)..selection = TextSelection.collapsed(offset: _newBrandName.length),
          decoration: _inputDec('Brand Name', hint: 'e.g. Samsung'),
          onChanged: (v) => _newBrandName = v,
        ),
        const SizedBox(height: 16),
        _labelText('BRAND LOGO'),
        GestureDetector(
          onTap: () async {
            final file = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (file != null) { setSt(() => _brandFile = file); setState(() => _brandFile = file); }
          },
          child: Container(
            width: double.infinity, height: 100,
            decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withOpacity(0.3), style: BorderStyle.solid, width: 2), borderRadius: BorderRadius.circular(16)),
            child: Center(child: _brandFile != null
              ? const Icon(LucideIcons.image, color: AppTheme.primary, size: 32)
              : _editingBrand?['logo_url'] != null
                ? Image.network(_editingBrand!['logo_url'], height: 60, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(LucideIcons.image, size: 32))
                : const Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.upload, color: AppTheme.primary, size: 24), SizedBox(height: 4), Text('SELECT LOGO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary))])),
          ),
        ),
        if (_brandFile != null) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(LucideIcons.checkCircle2, size: 14, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text(_brandFile!.name, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))])),
      ])),
      actions: [
        TextButton(onPressed: () => setState(() => _brandDialogOpen = false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _isSaving ? null : () async { setState(() => _brandDialogOpen = false); await _handleSaveBrand(); },
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Brand', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    ));
  }

  // ── Model Dialog ──────────────────────────────────────────────────────────
  Widget _buildModelDialog() {
    return StatefulBuilder(builder: (ctx, setSt) {
      void setField(String key, String val) => setSt(() => _modelForm[key] = val);
      void setVariant(int i, String key, dynamic val) => setSt(() { final n = List<Map<String, dynamic>>.from(_variants); n[i][key] = val; _variants = n; });

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primary.withOpacity(0.1), Colors.transparent]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_editingModel != null ? 'Update Model' : 'Create New Model', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                IconButton(icon: const Icon(LucideIcons.x), onPressed: () => setState(() => _modelDialogOpen = false)),
              ]),
            ),
            // Content
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: LayoutBuilder(builder: (ctx2, c) {
              final wide = c.maxWidth > 600;
              // Left col: brand, name, image
              Widget leftCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _labelText('BRAND'),
                DropdownButtonFormField<String>(
                  value: _modelForm['brand_id']!.isNotEmpty ? _modelForm['brand_id'] : null,
                  decoration: _inputDec('Brand'),
                  borderRadius: BorderRadius.circular(12),
                  items: _brands.map((b) => DropdownMenuItem<String>(value: b['id'].toString(), child: Text(b['name'] ?? ''))).toList(),
                  onChanged: (v) => setSt(() => _modelForm['brand_id'] = v ?? ''),
                ),
                const SizedBox(height: 12),
                _labelText('MODEL NAME'),
                TextField(
                  controller: TextEditingController(text: _modelForm['name'])..selection = TextSelection.collapsed(offset: _modelForm['name']!.length),
                  decoration: _inputDec('Model Name', hint: 'e.g. iPhone 15 Pro'),
                  onChanged: (v) => setField('name', v),
                ),
                const SizedBox(height: 12),
                _labelText('SMARTPHONE IMAGE'),
                GestureDetector(
                  onTap: () async {
                    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (f != null) { setSt(() => _modelFile = f); setState(() => _modelFile = f); }
                  },
                  child: Container(
                    width: double.infinity, height: 160,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), border: Border.all(color: AppTheme.primary.withOpacity(0.2), style: BorderStyle.solid, width: 2), borderRadius: BorderRadius.circular(20)),
                    child: _modelFile != null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.image, color: AppTheme.primary, size: 40), const SizedBox(height: 4), Text(_modelFile!.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)])
                      : (_editingModel?['image_url'] != null
                        ? Image.network(_editingModel!['image_url'], fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(LucideIcons.smartphone, size: 40, color: Colors.grey))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.upload, color: AppTheme.primary, size: 32), SizedBox(height: 8), Text('UPLOAD HQ IMAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary))])),
                  ),
                ),
              ]);

              // Right col: variants
              Widget rightCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('CONFIGURATIONS & VARIANTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  TextButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add Variant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setSt(() {
                      final last = _variants.isNotEmpty ? Map<String, dynamic>.from(_variants.last) : <String, dynamic>{};
                      last['color'] = ''; last['image_url'] = null;
                      _variants.add(last);
                      _variantFiles.add(null);
                    }),
                  ),
                ]),
                const SizedBox(height: 12),
                ..._variants.asMap().entries.map((entry) {
                  final i = entry.key;
                  final v = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: AppTheme.primary.withOpacity(0.1)), borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Variant ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        IconButton(icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red), onPressed: () => setSt(() { _variants.removeAt(i); if (_variantFiles.length > i) _variantFiles.removeAt(i); })),
                      ]),
                      // Variant image picker
                      GestureDetector(
                        onTap: () async {
                          final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (f != null) setSt(() { while (_variantFiles.length <= i) _variantFiles.add(null); _variantFiles[i] = f; });
                        },
                        child: Container(
                          height: 80, width: double.infinity,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), border: Border.all(color: AppTheme.primary.withOpacity(0.2), style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: (_variantFiles.length > i && _variantFiles[i] != null)
                            ? Text(_variantFiles[i]!.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)
                            : v['image_url'] != null
                              ? Image.network(v['image_url'], height: 60, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(LucideIcons.smartphone, size: 24, color: Colors.grey))
                              : const Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.smartphone, size: 20, color: Colors.grey), SizedBox(height: 4), Text('Photo', style: TextStyle(fontSize: 9, color: Colors.grey))])),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_labelText('MEMORY'), TextField(controller: TextEditingController(text: v['ram_rom'] ?? '')..selection = TextSelection.collapsed(offset: (v['ram_rom'] ?? '').length), decoration: _inputDec('', hint: '8/256GB'), onChanged: (val) => setVariant(i, 'ram_rom', val))])),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_labelText('COLOR'), TextField(controller: TextEditingController(text: v['color'] ?? '')..selection = TextSelection.collapsed(offset: (v['color'] ?? '').length), decoration: _inputDec('', hint: 'Titanium'), onChanged: (val) => setVariant(i, 'color', val))])),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_labelText('PRICE ₹'), TextField(controller: TextEditingController(text: (v['price'] ?? 0).toString())..selection = TextSelection.collapsed(offset: (v['price'] ?? 0).toString().length), decoration: _inputDec('', hint: '0'), keyboardType: TextInputType.number, onChanged: (val) => setVariant(i, 'price', int.tryParse(val) ?? 0))])),
                      ]),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final field in [['display', '6.7 OLED', 'DISPLAY'], ['battery', '5000mAh', 'BATTERY'], ['processor', 'A17 Pro', 'PROCESSOR'], ['charging_speed', '80W Fast', 'CHARGING'], ['front_camera', '12MP', 'FRONT CAM'], ['back_camera', '50+12MP', 'BACK CAM']])
                          SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _labelText(field[2]),
                            TextField(
                              controller: TextEditingController(text: (v[field[0]] ?? '').toString())..selection = TextSelection.collapsed(offset: (v[field[0]] ?? '').toString().length),
                              decoration: _inputDec('', hint: field[1]),
                              onChanged: (val) => setVariant(i, field[0], val),
                            ),
                          ])),
                      ]),
                    ]),
                  );
                }),
              ]);

              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 220, child: leftCol), const SizedBox(width: 20), Expanded(child: rightCol)]);
              }
              return Column(children: [leftCol, const SizedBox(height: 16), rightCol]);
            }))),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => setState(() => _modelDialogOpen = false), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _isSaving ? null : () async { setState(() => _modelDialogOpen = false); await _handleSaveModel(); },
                  child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Finalize & Save', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  // ── Model Card ─────────────────────────────────────────────────────────────
  Widget _buildModelCard(Map<String, dynamic> model, bool isAdmin) {
    final variants = List<Map<String, dynamic>>.from(model['variants'] ?? []);
    final prices = variants.map((v) => (v['price'] as num?)?.toInt() ?? 0);
    final startingPrice = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);

    return GestureDetector(
      onTap: () => context.push('/smartphones/${model['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Image area
          SizedBox(height: 180, child: Stack(children: [
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Center(child: model['image_url'] != null
                ? Image.network(model['image_url'], fit: BoxFit.contain, height: 140, errorBuilder: (_,__,___) => const Icon(LucideIcons.smartphone, size: 48, color: Colors.grey))
                : const Icon(LucideIcons.smartphone, size: 48, color: Colors.grey)),
            ),
            if (isAdmin)
              Positioned(top: 8, right: 8, child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => _openModelDialog(model),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).dividerColor)), child: const Icon(LucideIcons.edit, size: 14)),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _handleDeleteModel(model),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).dividerColor)), child: const Icon(LucideIcons.trash2, size: 14, color: Colors.red)),
                ),
              ])),
          ])),
          // Info
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(_getBrandName(model['brand_id']?.toString()).toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 1))),
            const SizedBox(height: 6),
            Text(model['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text('STARTING FROM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
            Text(
              startingPrice > 0 ? '₹${startingPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}' : 'N/A',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary),
            ),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _models.isEmpty) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    final isAdmin = context.watch<AuthService>().isAdmin;
    final filtered = _filteredModels;

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Smartphones', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text('${filtered.length} models available', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ]),
            if (isAdmin)
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('Brand'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), foregroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => setState(() { _openBrandDialog(); }),
                ),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('Add Model'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => setState(() { _openModelDialog(); }),
                ),
              ]),
          ]),
          const SizedBox(height: 24),

          // Search + Filter toggle
          Row(children: [
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search models by name...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            )),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(color: _showFilters ? AppTheme.primary : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _showFilters ? AppTheme.primary : Theme.of(context).dividerColor)),
              child: IconButton(icon: Icon(LucideIcons.filter, color: _showFilters ? Colors.white : null), onPressed: () => setState(() => _showFilters = !_showFilters)),
            ),
          ]),

          // Filters Panel
          if (_showFilters) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 16, runSpacing: 16, children: [
                  SizedBox(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _labelText('FILTER BY BRAND'),
                    DropdownButtonFormField<String>(
                      value: _brandFilter,
                      decoration: _inputDec(''),
                      borderRadius: BorderRadius.circular(12),
                      items: [const DropdownMenuItem(value: 'all', child: Text('All Brands')), ..._brands.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'] ?? '')))],
                      onChanged: (v) => setState(() => _brandFilter = v ?? 'all'),
                    ),
                  ])),
                  SizedBox(width: 160, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _labelText('MEMORY (RAM/ROM)'),
                    TextField(controller: TextEditingController(text: _ramFilter), decoration: _inputDec('', hint: 'e.g. 8GB'), onChanged: (v) => setState(() => _ramFilter = v)),
                  ])),
                  SizedBox(width: 160, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _labelText('PROCESSOR / CPU'),
                    TextField(controller: TextEditingController(text: _processorFilter), decoration: _inputDec('', hint: 'e.g. Snapdragon'), onChanged: (v) => setState(() => _processorFilter = v)),
                  ])),
                  SizedBox(width: 160, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _labelText('SORT ORDER'),
                    DropdownButtonFormField<String>(
                      value: _sortOrder,
                      decoration: _inputDec(''),
                      borderRadius: BorderRadius.circular(12),
                      items: const [DropdownMenuItem(value: 'newest', child: Text('Newest First')), DropdownMenuItem(value: 'price-asc', child: Text('Price: Low→High')), DropdownMenuItem(value: 'price-desc', child: Text('Price: High→Low')), DropdownMenuItem(value: 'name-asc', child: Text('Name A–Z'))],
                      onChanged: (v) => setState(() => _sortOrder = v ?? 'newest'),
                    ),
                  ])),
                ]),
                const Divider(height: 24),
                Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
                  SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_labelText('MIN PRICE'), TextField(controller: TextEditingController(text: _priceMin), decoration: _inputDec('', hint: '0'), keyboardType: TextInputType.number, onChanged: (v) => setState(() => _priceMin = v))])),
                  SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_labelText('MAX PRICE'), TextField(controller: TextEditingController(text: _priceMax), decoration: _inputDec('', hint: 'Any'), keyboardType: TextInputType.number, onChanged: (v) => setState(() => _priceMax = v))])),
                  TextButton.icon(
                    icon: const Icon(LucideIcons.x, size: 14),
                    label: const Text('Reset All Filters'),
                    onPressed: () => setState(() { _brandFilter = 'all'; _priceMin = ''; _priceMax = ''; _ramFilter = ''; _processorFilter = ''; _sortOrder = 'newest'; }),
                  ),
                ]),
              ]),
            ),
          ],

          // Brands section
          if (_brands.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(children: [const SizedBox(width: 32, height: 1, child: Divider()), const SizedBox(width: 8), const Text('FEATURED BRANDS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2))]),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _brands.map((brand) {
              final isSelected = _brandFilter == brand['id'].toString();
              return GestureDetector(
                onTap: () => setState(() => _brandFilter = isSelected ? 'all' : brand['id'].toString()),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.primary : Theme.of(context).dividerColor, width: isSelected ? 2 : 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (brand['logo_url'] != null)
                      Padding(padding: const EdgeInsets.only(right: 10), child: Image.network(brand['logo_url'], width: 28, height: 28, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(LucideIcons.image, size: 20)))
                    else
                      const Padding(padding: EdgeInsets.only(right: 8), child: Icon(LucideIcons.image, size: 20)),
                    Text(brand['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () { setState(() {}); _openBrandDialog(brand); },
                        child: const Icon(LucideIcons.edit, size: 12, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleDeleteBrand(brand),
                        child: const Icon(LucideIcons.trash2, size: 12, color: Colors.red),
                      ),
                    ],
                  ]),
                ),
              );
            }).toList())),
          ],

          // Models grid
          const SizedBox(height: 28),
          if (filtered.isEmpty)
            Center(child: Container(padding: const EdgeInsets.all(48), child: Column(children: [const Icon(LucideIcons.smartphone, size: 48, color: Colors.grey), const SizedBox(height: 16), Text('No models found', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))])))
          else
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
              final sp = 20.0;
              final cardW = (c.maxWidth - sp * (cols - 1)) / cols;
              return Wrap(spacing: sp, runSpacing: sp, children: filtered.map((m) => SizedBox(width: cardW, child: _buildModelCard(m, isAdmin))).toList());
            }),
          const SizedBox(height: 40),
        ]),
      ),

      // Dialogs shown as overlays
      if (_brandDialogOpen) _BrandDialogOverlay(child: _buildBrandDialog()),
      if (_modelDialogOpen) _BrandDialogOverlay(child: _buildModelDialog()),
    ]);
  }
}

// Simple overlay wrapper so dialogs can ref parent state
class _BrandDialogOverlay extends StatelessWidget {
  final Widget child;
  const _BrandDialogOverlay({required this.child});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(child: child),
    );
  }
}
