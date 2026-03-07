import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const double _shopLat = 8.149201;
  static const double _shopLng = 77.5716038;
  static const double _radiusKm = 1.0;

  bool _loading = true;
  bool _marking = false;
  double? _distance;
  Map<String, dynamic>? _todaysAttendance;
  List<dynamic> _allAttendance = [];
  List<dynamic> _staffList = [];
  List<dynamic> _dailyAttendance = [];

  String? _selectedStaffId;
  Map<String, dynamic>? _targetStaff;

  String _filterType = 'month';
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _fetchData();
  }

  double _calcDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _fetchData() async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    final isAdmin = auth.isAdmin;
    if (user == null) return;
    if (mounted) setState(() => _loading = true);

    try {
      final staffs = await _supabase.from('staff').select('*').order('name');
      _staffList = staffs;

      if (isAdmin) {
        _dailyAttendance = await _supabase.from('attendance').select('*').eq('date', _selectedDate);
      }

      String? staffIdToFetch = _selectedStaffId;
      if (!isAdmin) {
        for (final s in _staffList.cast<Map<String, dynamic>>()) {
          if (s['mobile_number'] == user.username) {
            staffIdToFetch = s['id'].toString();
            break;
          }
        }
      }

      if (staffIdToFetch != null) {
        for (final s in _staffList.cast<Map<String, dynamic>>()) {
          if (s['id'].toString() == staffIdToFetch) { _targetStaff = s; break; }
        }
        _allAttendance = await _supabase.from('attendance').select('*').eq('staff_id', staffIdToFetch).order('date', ascending: false);
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _todaysAttendance = null;
        for (final a in _allAttendance) {
          if (a['date'] == todayStr) { _todaysAttendance = a; break; }
        }
      } else {
        _allAttendance = [];
        _todaysAttendance = null;
        _targetStaff = null;
      }

      if (!isAdmin) _handleGetLocation();
    } catch (e) {
      debugPrint('Attendance fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGetLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS')));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _distance = _calcDistance(pos.latitude, pos.longitude, _shopLat, _shopLng));
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _markAttendance() async {
    final auth = context.read<AuthService>();
    if (auth.user == null || _distance == null || _distance! > _radiusKm) return;
    setState(() => _marking = true);
    try {
      final staffData = await _supabase.from('staff').select('id').eq('mobile_number', auth.user!.username).maybeSingle();
      if (staffData != null) {
        await _supabase.from('attendance').insert({'staff_id': staffData['id'], 'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'status': 'present'});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Marked! ✅'), backgroundColor: Colors.green));
        _fetchData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to mark attendance'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  // ── Stats calculation identical to React ──────────────────────────────────
  Map<String, dynamic> _calcStats() {
    if (_targetStaff == null) return {'present': 0, 'absent': 0, 'avgTime': 'N/A', 'score': '0%'};

    DateTime startBound;
    DateTime endBound = DateTime.now();
    final joined = DateTime.tryParse(_targetStaff!['created_at'] ?? '') ?? DateTime(2024);

    if (_filterType == 'lifetime') {
      startBound = joined;
    } else if (_filterType == 'year') {
      final y = int.tryParse(_selectedYear) ?? DateTime.now().year;
      startBound = DateTime(y, 1, 1);
      endBound = DateTime(y, 12, 31, 23, 59, 59);
      if (endBound.isAfter(DateTime.now())) endBound = DateTime.now();
    } else {
      final parts = _selectedMonth.split('-');
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
      startBound = DateTime(y, m, 1);
      endBound = DateTime(y, m + 1, 0, 23, 59, 59); // last day of month
      if (endBound.isAfter(DateTime.now())) endBound = DateTime.now();
    }
    if (startBound.isBefore(joined)) startBound = joined;
    if (startBound.isAfter(endBound)) return {'present': 0, 'absent': 0, 'avgTime': 'N/A', 'score': '0%'};

    int presentCount = 0, absentCount = 0, totalMinutes = 0, totalWithTime = 0;
    DateTime day = DateTime(startBound.year, startBound.month, startBound.day);
    final endDay = DateTime(endBound.year, endBound.month, endBound.day);

    while (!day.isAfter(endDay)) {
      final dStr = DateFormat('yyyy-MM-dd').format(day);
      Map<String, dynamic>? record;
      for (final a in _allAttendance.cast<Map<String, dynamic>>()) {
        if (a['date'] == dStr) { record = a; break; }
      }
      if (record?['status'] == 'present') {
        presentCount++;
        if (record!['created_at'] != null) {
          final t = DateTime.tryParse(record['created_at']);
          if (t != null) { totalMinutes += t.hour * 60 + t.minute; totalWithTime++; }
        }
      } else if (day.isBefore(DateTime.now()) && dStr != DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        absentCount++;
      }
      day = day.add(const Duration(days: 1));
    }

    String avgTime = 'N/A';
    if (totalWithTime > 0) {
      final avg = totalMinutes ~/ totalWithTime;
      final h = avg ~/ 60;
      final m = avg % 60;
      final disp = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      avgTime = '$disp:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
    }

    final total = presentCount + absentCount;
    final scoreStr = total > 0 ? '${((presentCount / total) * 100).round()}%' : '0%';
    return {'present': presentCount, 'absent': absentCount, 'avgTime': avgTime, 'score': scoreStr};
  }

  // ── Widgets ───────────────────────────────────────────────────────────────
  Widget _badge(String txt, bool isPresent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPresent ? Colors.green : Colors.red).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPresent ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 12, color: isPresent ? Colors.green : Colors.red),
        const SizedBox(width: 4),
        Text(isPresent ? 'Present' : 'Absent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPresent ? Colors.green : Colors.red)),
      ]),
    );
  }

  Widget _adminSummaryCard(String label, String value, Color bgColor, Color fgColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: bgColor.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fgColor, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: fgColor)),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: fgColor)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAdminOverview() {
    final presentCount = _dailyAttendance.where((a) => a['status'] == 'present').length;
    final absentCount = _staffList.length - presentCount;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isToday = _selectedDate == todayStr;
    final dateLabel = isToday ? 'TODAY' : _selectedDate;

    return Column(children: [
      // ── Summary Card ──
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 12, runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Attendance Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('Live status of all members', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic, letterSpacing: 1)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (!isToday)
                  GestureDetector(
                    onTap: () => setState(() { _selectedDate = todayStr; _fetchData(); }),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary))),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final dt = await showDatePicker(context: context, initialDate: DateTime.parse(_selectedDate), firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (dt != null) setState(() { _selectedDate = DateFormat('yyyy-MM-dd').format(dt); _fetchData(); });
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(LucideIcons.calendar, size: 14), const SizedBox(width: 6), Text(dateLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))])),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          // 3 summary stat boxes
          LayoutBuilder(builder: (ctx, c) {
            final narrow = c.maxWidth < 450;
            final cards = [
              _adminSummaryCard(isToday ? 'PRESENT TODAY' : 'PRESENT ON DATE', '$presentCount', Colors.green, Colors.green, LucideIcons.userCheck),
              _adminSummaryCard(isToday ? 'ABSENT TODAY' : 'ABSENT ON DATE', '$absentCount', Colors.red, Colors.red, LucideIcons.xCircle),
              _adminSummaryCard('TOTAL STAFF', '${_staffList.length}', AppTheme.primary, AppTheme.primary, LucideIcons.users),
            ];
            if (narrow) {
              return Column(children: [
                for (int i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 8), Row(children: [cards[i]])],
              ]);
            }
            return Row(children: [cards[0], const SizedBox(width: 10), cards[1], const SizedBox(width: 10), cards[2]]);
          }),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Daily Log Table ──
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('DAILY LOG: ${DateFormat('MMMM dd, yyyy').format(DateTime.parse(_selectedDate)).toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Row(children: [const Icon(LucideIcons.clock, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(DateFormat('hh:mm a').format(DateTime.now()), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey))]),
          ]),
          const SizedBox(height: 16),
          if (_staffList.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No staff found', style: TextStyle(color: Colors.grey))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _staffList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final staff = _staffList[i] as Map<String, dynamic>;
                Map<String, dynamic>? record;
                for (final a in _dailyAttendance.cast<Map<String, dynamic>>()) {
                  if (a['staff_id'].toString() == staff['id'].toString()) { record = a; break; }
                }
                final isPresent = record?['status'] == 'present';
                final checkInTime = (isPresent && record?['created_at'] != null)
                    ? DateFormat('hh:mm a').format(DateTime.tryParse(record!['created_at']) ?? DateTime.now())
                    : '--:--';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      child: Text(staff['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
                    ),
                    title: Text(staff['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(staff['role'] ?? 'Staff', style: const TextStyle(fontSize: 10)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _badge(isPresent ? 'Present' : 'Absent', isPresent),
                      const SizedBox(width: 8),
                      Text(checkInTime, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () { setState(() => _selectedStaffId = staff['id'].toString()); _fetchData(); },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: _selectedStaffId == staff['id'].toString() ? AppTheme.primary : null,
                          foregroundColor: _selectedStaffId == staff['id'].toString() ? Colors.white : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Review', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)), Icon(LucideIcons.arrowRight, size: 10)]),
                      ),
                    ]),
                  ),
                );
              },
            ),
        ]),
      ),
    ]);
  }

  Widget _buildStaffMarker() {
    final isInside = _distance != null && _distance! <= _radiusKm;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ── Radar circle ──
          SizedBox(
            width: 200, height: 200,
            child: Stack(alignment: Alignment.center, children: [
              // outer ping ring
              if (_distance != null && _todaysAttendance == null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.7, end: 1.0), duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => Container(
                    width: 180 * v, height: 180 * v,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (isInside ? Colors.green : AppTheme.primary).withOpacity(1 - v), width: 2)),
                  ),
                ),
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: _todaysAttendance != null ? Colors.green : (isInside ? Colors.green : AppTheme.primary).withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: (isInside ? Colors.green : AppTheme.primary).withOpacity(0.08), blurRadius: 30, spreadRadius: 8)],
                ),
                child: Center(child: _distance == null
                  ? const CircularProgressIndicator(color: AppTheme.primary)
                  : _todaysAttendance != null
                    ? const Icon(LucideIcons.checkCircle2, size: 64, color: Colors.green)
                    : Icon(isInside ? LucideIcons.navigation : LucideIcons.mapPin, size: 64, color: isInside ? Colors.green : AppTheme.primary)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          // Status text
          if (_todaysAttendance != null) ...[
            const Text('VERIFIED', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green, letterSpacing: 2)),
            Text(DateFormat('hh:mm a').format(DateTime.tryParse(_todaysAttendance!['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ] else if (_distance != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_distance!.toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const Text(' KM', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(LucideIcons.rotateCw, size: 18), onPressed: _handleGetLocation),
            ]),
            const SizedBox(height: 12),
            if (!isInside)
              const Text('Move closer to the shop to mark attendance', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                icon: _marking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(LucideIcons.shieldCheck),
                label: const Text('MARK PRESENCE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInside ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _marking || !isInside ? null : _markAttendance,
              ),
            ),
          ] else ...[
            const Text('Radar search...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }

  Widget _buildTargetStats() {
    if (_targetStaff == null) return const SizedBox.shrink();
    final stats = _calcStats();
    final present = stats['present'] as int;
    final absent = stats['absent'] as int;
    final avgTime = stats['avgTime'] as String;
    final score = stats['score'] as String;
    final total = present + absent;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 32),
      const Divider(),
      const SizedBox(height: 24),

      // Header + Filter row
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.barChart3, color: AppTheme.primary, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${_targetStaff!['name']}'s Stats", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('PERFORMANCE HISTORY DETAIL', style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic, letterSpacing: 1.5)),
          ]),
        ]),
        // Filter controls
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
          child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<String>(
              value: _filterType,
              isDense: true, underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'month', child: Text('Monthly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'year', child: Text('Yearly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'lifetime', child: Text('Lifetime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
              onChanged: (v) { if (v != null) setState(() => _filterType = v); },
            ),
            if (_filterType == 'month')
              DropdownButton<String>(
                value: _selectedMonth,
                isDense: true, underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                items: List.generate(12, (i) {
                  final d = DateTime.now().subtract(Duration(days: i * 30));
                  final val = DateFormat('yyyy-MM').format(d);
                  return DropdownMenuItem(value: val, child: Text(DateFormat('MMM yyyy').format(d), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
                }),
                onChanged: (v) { if (v != null) setState(() => _selectedMonth = v); },
              ),
            if (_filterType == 'year')
              DropdownButton<String>(
                value: _selectedYear,
                isDense: true, underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                items: List.generate(DateTime.now().year - 2023, (i) {
                  final y = (DateTime.now().year - i).toString();
                  return DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
                }),
                onChanged: (v) { if (v != null) setState(() => _selectedYear = v); },
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 20),

      // 4 stat cards
      LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth < 500 ? 2 : 4;
        final sp = 12.0;
        final w = (c.maxWidth - sp * (cols - 1)) / cols;
        final cards = [
          _statCard('AVG CHECK-IN', avgTime, AppTheme.primary, LucideIcons.clock, 'Punctual'),
          _statCard('PRESENT DAYS', '$present Days', Colors.green, LucideIcons.checkCircle2, 'Verified'),
          _statCard('ABSENT DAYS', '$absent Days', Colors.red, LucideIcons.xCircle, 'Unverified'),
          _scoreCard(score),
        ];
        return Wrap(spacing: sp, runSpacing: sp, children: cards.map((c) => SizedBox(width: w, child: c)).toList());
      }),
      const SizedBox(height: 20),

      // Charts row
      if (total > 0)
        LayoutBuilder(builder: (ctx, c) {
          final narrow = c.maxWidth < 600;
          Widget barChart = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PERFORMANCE CHART', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: BarChart(BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    return Text(v == 0 ? 'Present' : 'Absent', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900));
                  })),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: present.toDouble(), color: Colors.green, width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: absent.toDouble(), color: Colors.red, width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))]),
                ],
              ))),
            ]),
          );
          Widget pieChart = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              SizedBox(height: 200, child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  sectionsSpace: 6, centerSpaceRadius: 55,
                  sections: [
                    PieChartSectionData(value: present.toDouble(), color: Colors.green, radius: 30, title: ''),
                    PieChartSectionData(value: absent.toDouble(), color: Colors.red, radius: 30, title: ''),
                  ],
                )),
                Text(score, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ])),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _dot(Colors.green), const SizedBox(width: 4), const Text('Present', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                _dot(Colors.red), const SizedBox(width: 4), const Text('Absent', style: TextStyle(fontSize: 11)),
              ]),
            ]),
          );
          if (narrow) return Column(children: [barChart, const SizedBox(height: 12), pieChart]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: barChart), const SizedBox(width: 12), Expanded(child: pieChart)]);
        }),
    ]);
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _statCard(String label, String value, Color accent, IconData icon, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, size: 14, color: accent),
          Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _scoreCard(String score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.black54 : Colors.white70, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(score, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.black : Colors.white)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(LucideIcons.shieldCheck, size: 14, color: isDark ? Colors.black54 : Colors.white54),
          Text('Trust Index', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.black54 : Colors.white70)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _staffList.isEmpty) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    final isAdmin = context.watch<AuthService>().isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Header
        Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isAdmin ? LucideIcons.users : LucideIcons.mapPin, size: 14, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(isAdmin ? 'STAFF ATTENDANCE MONITOR' : 'LOCATION VERIFICATION LOCK', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
            ]),
          ),
          const SizedBox(height: 16),
          Text(isAdmin ? 'Attendance Terminal' : 'Daily Presence', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
        ]),
        const SizedBox(height: 32),

        if (isAdmin) _buildAdminOverview() else _buildStaffMarker(),

        if (_targetStaff != null) _buildTargetStats()
        else if (isAdmin)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(32), border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid)),
            child: Column(children: [
              Icon(LucideIcons.users, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Select a member above to see detailed history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey[500]), textAlign: TextAlign.center),
            ]),
          ),
      ]),
    );
  }
}
