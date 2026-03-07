import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = false;
  bool _pwdLoading = false;
  bool _uploading = false;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdayController = TextEditingController();
  String _avatarUrl = '';

  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    if (user != null) {
      _usernameController.text = user.username;
      _emailController.text = user.email ?? '';
      _birthdayController.text = user.birthday ?? '';
      _avatarUrl = user.avatarUrl ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoUpload() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _uploading = true);

    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = 'avatars/$fileName';

      await _supabase.storage.from('images').uploadBinary(filePath, bytes);
      final publicUrl = _supabase.storage.from('images').getPublicUrl(filePath);

      setState(() => _avatarUrl = publicUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded! Click update to save.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _handleSave() async {
    final authService = context.read<AuthService>();
    final user = authService.user;
    if (user == null) return;

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number cannot be empty'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _loading = true);

    try {
      if (_usernameController.text.trim() != user.username) {
        final existing = await _supabase.from('users').select('id').eq('username', _usernameController.text.trim()).maybeSingle();
        if (existing != null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number already in use'), backgroundColor: Colors.red));
           setState(() => _loading = false);
           return;
        }
      }

      if (user.role == 'staff') {
        await _supabase.from('staff').update({'mobile_number': _usernameController.text.trim()}).eq('mobile_number', user.username);
      }

      await _supabase.from('users').update({
        'username': _usernameController.text.trim(),
        'birthday': _birthdayController.text.trim().isEmpty ? null : _birthdayController.text.trim(),
        'email': _emailController.text.trim(),
        'avatar_url': _avatarUrl,
      }).eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      
      // Update local context and restart to reflect if needed or handle properly
      // We will reload by re-navigating to dashboard for simplicity
    } catch (e) {
      debugPrint('Save error $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;

    if (_oldPwdController.text.isEmpty || _newPwdController.text.isEmpty || _confirmPwdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all password fields'), backgroundColor: Colors.red));
      return;
    }

    if (_newPwdController.text != _confirmPwdController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _pwdLoading = true);

    try {
      final userData = await _supabase.from('users').select('password').eq('id', user.id).single();

      if (userData['password'] != _oldPwdController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect old password'), backgroundColor: Colors.red));
        setState(() => _pwdLoading = false);
        return;
      }

      await _supabase.from('users').update({'password': _newPwdController.text}).eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green));
      _oldPwdController.clear();
      _newPwdController.clear();
      _confirmPwdController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to change password'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _pwdLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Profile', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk')),
          const Text('MANAGE YOUR PERSONAL INFORMATION', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 32),

          // Profile Edit Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.05), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.background, width: 4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _avatarUrl.isNotEmpty 
                              ? Image.network(_avatarUrl, fit: BoxFit.cover)
                              : Center(child: Text(user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))),
                          ),
                        ),
                        Positioned(
                          bottom: -4, right: -4,
                          child: InkWell(
                            onTap: _handlePhotoUpload,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                              child: _uploading ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(color:Colors.white, strokeWidth:2)) : const Icon(LucideIcons.camera, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: user.role == 'admin' ? AppTheme.primary : Colors.grey, borderRadius: BorderRadius.circular(12)),
                                child: Text(user.role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          Text('@${user.username}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 32),
                
                LayoutBuilder(
                  builder: (ctx, c) {
                    final narrow = c.maxWidth < 450;
                    Widget mobileField = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(LucideIcons.phone, size:14, color:AppTheme.primary), SizedBox(width:6), Text('MOBILE NUMBER', style: TextStyle(fontSize:9, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 10),
                          TextField(controller: _usernameController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    );
                    Widget birthdayField = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(LucideIcons.calendar, size:14, color:Colors.pink), SizedBox(width:6), Text('BIRTHDAY', style: TextStyle(fontSize:9, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 10),
                          TextField(controller: _birthdayController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'YYYY-MM-DD', isDense: true)),
                        ],
                      ),
                    );
                    if (narrow) {
                      return Column(children: [mobileField, const SizedBox(height: 12), birthdayField]);
                    }
                    return Row(children: [Expanded(child: mobileField), const SizedBox(width: 12), Expanded(child: birthdayField)]);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(LucideIcons.mail, size:16, color:Colors.blue), SizedBox(width:8), Text('EMAIL ADDRESS', style: TextStyle(fontSize:10, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 12),
                      TextField(controller: _emailController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'yourname@gmail.com')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: _loading ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white, strokeWidth:2)) : const Icon(LucideIcons.save),
                    label: const Text('UPDATE PROFILE'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: _loading ? null : _handleSave,
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Security Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.lock, color: AppTheme.primary)),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('UPDATE YOUR SECURITY CREDENTIALS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2))
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CURRENT PASSWORD', style: TextStyle(fontSize:10, fontWeight:FontWeight.bold, color:Colors.grey)), const SizedBox(height:8), TextField(controller: _oldPwdController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder()))])),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NEW PASSWORD', style: TextStyle(fontSize:10, fontWeight:FontWeight.bold, color:Colors.grey)), const SizedBox(height:8), TextField(controller: _newPwdController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder()))])),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CONFIRM PASSWORD', style: TextStyle(fontSize:10, fontWeight:FontWeight.bold, color:Colors.grey)), const SizedBox(height:8), TextField(controller: _confirmPwdController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder()))])),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: _pwdLoading ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white, strokeWidth:2)) : const Icon(LucideIcons.shieldCheck),
                    label: const Text('UPDATE PASSWORD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: _pwdLoading ? null : _handleChangePassword,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
