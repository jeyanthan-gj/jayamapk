import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _staffList = [];

  // Dialog state
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _editingStaff;
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _salaryController = TextEditingController();
  final _salaryDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _salaryController.dispose();
    _salaryDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final isAdmin = context.read<AuthService>().isAdmin;
    if (!isAdmin) return;

    setState(() => _loading = true);
    try {
      final staffData = await _supabase.from('staff').select('*').order('name');
      final usersData = await _supabase.from('users').select('username, avatar_url, birthday, email');

      final merged = staffData.map((s) {
        Map<String, dynamic>? profile;
        for (final u in usersData as List<dynamic>) {
          if (u['username'] == s['mobile_number']) {
            profile = u as Map<String, dynamic>;
            break;
          }
        }
        return {
          ...s as Map<String, dynamic>,
          if (profile != null) ...{
            'avatar_url': profile['avatar_url'],
            'birthday': profile['birthday'],
            'email': profile['email'],
          }
        };
      }).toList();

      if (mounted) {
        setState(() {
          _staffList = merged;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error fetching staff: $e\n$stack');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openDialog([Map<String, dynamic>? staff]) {
    setState(() {
      _editingStaff = staff;
      _nameController.text = staff?['name'] ?? '';
      _mobileController.text = staff?['mobile_number'] ?? '';
      _salaryController.text = staff?['salary']?.toString() ?? '';
      _salaryDateController.text = staff?['salary_date'] ?? '';
    });

    showDialog(
      context: context,
      builder: (ctx) => _buildDialog(ctx),
    );
  }

  Future<void> _selectSalaryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _salaryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSave(BuildContext dialogCtx) async {
    if (!_formKey.currentState!.validate()) return;
    
    Navigator.pop(dialogCtx); // close dialog
    setState(() => _loading = true);

    try {
      final staffData = {
        'name': _nameController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'salary': _salaryController.text.isNotEmpty ? int.parse(_salaryController.text) : null,
        'salary_date': _salaryDateController.text.isNotEmpty ? _salaryDateController.text : null,
      };

      if (_editingStaff != null) {
        await _supabase.from('staff').update(staffData).eq('id', _editingStaff!['id']);
      } else {
        await _supabase.from('staff').insert(staffData);
      }

      final userData = {
        'name': staffData['name'],
        'username': staffData['mobile_number'],
        'password': staffData['mobile_number'],
        'role': 'staff',
      };

      if (_editingStaff != null) {
        await _supabase.from('users').update(userData).eq('username', _editingStaff!['mobile_number']);
      } else {
        await _supabase.from('users').insert(userData).catchError((_) {
          // Ignore unique constraint error loosely based on React code
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingStaff != null ? 'Staff updated' : 'Staff created'), backgroundColor: AppTheme.primary)
      );
      _fetchData();
    } catch (e) {
      debugPrint('Error saving struct: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving staff'), backgroundColor: Colors.red));
      setState(() => _loading = false);
    }
  }

  Future<void> _handleDelete(dynamic id, String mobile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff?'),
        content: const Text('This will delete the staff member and their login account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _supabase.from('attendance').delete().eq('staff_id', id);
      await _supabase.from('staff').delete().eq('id', id);
      await _supabase.from('users').delete().eq('username', mobile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted'), backgroundColor: Colors.red));
      _fetchData();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
       setState(() => _loading = false);
    }
  }

  Widget _buildDialog(BuildContext dialogCtx) {
    return AlertDialog(
      title: Text(_editingStaff != null ? 'Edit Staff Member' : 'Add New Staff', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Mobile required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                     child: TextFormField(
                        controller: _salaryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Salary (₹)', border: OutlineInputBorder()),
                      ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: TextFormField(
                        controller: _salaryDateController,
                        readOnly: true,
                        onTap: () => _selectSalaryDate(dialogCtx),
                        decoration: const InputDecoration(
                          labelText: 'Salary Date',
                          border: OutlineInputBorder(),
                          hintText: 'Select Date',
                          suffixIcon: Icon(LucideIcons.calendar, size: 18),
                        ),
                      ),
                   )
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => _handleSave(dialogCtx), child: const Text('Save')),
      ],
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)
        ],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
           Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(staff['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff['name'], style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text('₹${staff['salary'] ?? 0}', style: const TextStyle(fontSize: 20, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(LucideIcons.edit, size: 20, color: Colors.grey), onPressed: () => _openDialog(staff)),
                    IconButton(icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red), onPressed: () => _handleDelete(staff['id'], staff['mobile_number'])),
                  ],
                )
             ],
           ),
           const SizedBox(height: 24),
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
             child: Row(
               children: [
                 const Icon(LucideIcons.phone, size: 16, color: AppTheme.primary),
                 const SizedBox(width: 8),
                 Text(staff['mobile_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
               ],
             )
           ),
           if (staff['email'] != null) ...[
             const SizedBox(height: 8),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
               child: Row(
                 children: [
                   const Icon(LucideIcons.mail, size: 16, color: AppTheme.primary),
                   const SizedBox(width: 8),
                   Expanded(child: Text(staff['email'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                 ],
               )
             )
           ],
           const SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SALARY DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(children: [const Icon(LucideIcons.calendar, size: 12, color: AppTheme.primary), const SizedBox(width: 4), Text(staff['salary_date'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])
                      ],
                    ),
                  ),
               ),
               const SizedBox(width: 8),
               Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BIRTHDAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(children: [const Icon(LucideIcons.calendar, size: 12, color: Colors.pink), const SizedBox(width: 4), Text(staff['birthday'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink))])
                      ],
                    ),
                  ),
               ),
             ],
           )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('ERROR: $_error', style: const TextStyle(color: Colors.red))));
    }
    if (_loading && _staffList.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Staff Management', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk')),
                      Text('${_staffList.length} total team members', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Add New Staff'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                    onPressed: () => _openDialog(),
                  )
                ],
              ),
              const SizedBox(height: 32),
              if (_staffList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.grey.withOpacity(0.2), style: BorderStyle.solid),
                  ),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.userX, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('NO STAFF MEMBERS FOUND', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: _staffList.map((staff) {
                    final cardWidth = constraints.maxWidth > 900
                        ? (constraints.maxWidth - 24 * 2) / 3
                        : constraints.maxWidth > 600
                            ? (constraints.maxWidth - 24) / 2
                            : constraints.maxWidth;
                    return SizedBox(
                      width: cardWidth,
                      child: _buildStaffCard(staff),
                    );
                  }).toList(),
                )
            ],
          ),
        );
      }
    );
  }
}
