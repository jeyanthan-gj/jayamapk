import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String username;
  final String name;
  final String role;
  final String? birthday;
  final String? avatarUrl;
  final String? email;

  UserProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.birthday,
    this.avatarUrl,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] is String ? json['id'] : json['id'].toString(),
      username: json['username'],
      name: json['name'],
      role: json['role'] ?? 'staff',
      birthday: json['birthday'],
      avatarUrl: json['avatar_url'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'birthday': birthday,
      'avatar_url': avatarUrl,
      'email': email,
    };
  }
}

class AuthService extends ChangeNotifier {
  UserProfile? _user;
  bool _loading = true;

  UserProfile? get user => _user;
  bool get loading => _loading;
  bool get isAdmin => _user?.role == 'admin';

  final SupabaseClient _supabase = Supabase.instance.client;

  AuthService() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserStr = prefs.getString('jayam_user');
      
      if (savedUserStr != null) {
        final Map<String, dynamic> userMap = json.decode(savedUserStr);
        _user = UserProfile.fromJson(userMap);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn(String username, String password) async {
    try {
      // Direct table query for login just like the React app
      final data = await _supabase
          .from('users')
          .select('*')
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (data == null) {
        return 'Invalid username or password';
      }

      final profile = UserProfile.fromJson(data);
      _user = profile;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jayam_user', json.encode(profile.toJson()));
      
      notifyListeners();
      return null; // Return null on success
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (e is PostgrestException) {
        return 'Server Error: ${e.message}';
      }
      return 'Error: ${e.toString()}';
    }
  }

  Future<String?> signUp(String username, String password, String name, String role) async {
    try {
      await _supabase.from('users').insert({
        'username': username,
        'password': password,
        'name': name,
        'role': role,
      });
      return null;
    } catch (e) {
      debugPrint('Sign up error: $e');
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jayam_user');
    _user = null;
    notifyListeners();
  }
}
