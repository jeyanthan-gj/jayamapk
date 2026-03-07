import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _creating = false;
  List<Map<String, dynamic>> _users = [];

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'staff';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final isAdmin = context.read<AuthService>().isAdmin;
    if (!isAdmin) return;

    setState(() => _loading = true);
    try {
      final res = await _supabase.from('users').select('id, name, username, role').order('name');
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCreateUser() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _creating = true);
    try {
      await _supabase.from('users').insert({
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'name': _nameController.text.trim(),
        'role': _role,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created for ${_nameController.text}'), backgroundColor: Colors.green));
      _nameController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _role = 'staff';
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _handleDeleteUser(String id, String name) async {
    if (name.toLowerCase() == 'admin' || name == 'Shop Admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete primary admin'), backgroundColor: Colors.red));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete login account for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await _supabase.from('users').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthService>().isAdmin) {
      return const Center(child: Text('Access Restricted'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Management', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk')),
              const Text('Manage local login accounts (No email needed)', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isDesktop ? constraints.maxWidth / 3 : double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk')),
                        const SizedBox(height: 24),
                        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'staff', child: Text('Staff')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: _creating ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white, strokeWidth:2)) : const Icon(LucideIcons.userPlus),
                            label: const Text('SAVE USER'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            onPressed: _creating ? null : _handleCreateUser,
                          ),
                        )
                      ],
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 32) else const SizedBox(height: 32),
                  Expanded(
                    flex: isDesktop ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Existing Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Space Grotesk')),
                              IconButton(icon: const Icon(LucideIcons.refreshCw, size: 20), onPressed: _fetchUsers),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (_loading && _users.isEmpty) const Center(child: CircularProgressIndicator())
                          else ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5))
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: u['role'] == 'admin' ? AppTheme.primary : Colors.grey.withOpacity(0.2),
                                      child: Text(u['name'].toString().substring(0, 1).toUpperCase(), style: TextStyle(color: u['role'] == 'admin' ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('User: ${u['username']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                       child: Text(u['role'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
                                      onPressed: () => _handleDeleteUser(u['id'], u['name']),
                                    )
                                  ],
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      }
    );
  }
}
