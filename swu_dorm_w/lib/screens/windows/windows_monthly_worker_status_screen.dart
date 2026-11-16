import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/services/term_service.dart';

const _shiftColors = {
  '주간': Color(0xFF2196F3),
  '야간': Color(0xFF3F51B5),
  '반차': Color(0xFF8BC34A),
  '당직': Color(0xFFFF9800),
  '휴무': Color(0xFFFFC107),
};

const _internColor = Color(0xFF6A1B9A);

final _zoneRegex = RegExp(r'^([A-Za-z]+)(\d+)');

/// 이름 앞의 호실(샬롬A2, 샬롬B7 등) 표기를 기준으로 동(알파벳)→호수(숫자) 순으로
/// 정렬한다. 호실 표기가 없는 이름은 맨 뒤로 보낸다.
int _compareByZone(String a, String b) {
  final ma = _zoneRegex.firstMatch(a);
  final mb = _zoneRegex.firstMatch(b);
  if (ma == null && mb == null) return a.compareTo(b);
  if (ma == null) return 1;
  if (mb == null) return -1;
  final letterCmp = ma.group(1)!.compareTo(mb.group(1)!);
  if (letterCmp != 0) return letterCmp;
  final numCmp = int.parse(ma.group(2)!).compareTo(int.parse(mb.group(2)!));
  if (numCmp != 0) return numCmp;
  return a.compareTo(b);
}

/// 대시보드의 "오늘 근무자현황"을 눌렀을 때 이동하는, 월 단위로 모든 날짜의
/// 직원(행정실 근무자현황)·근로학생(인턴근무일지) 근무 현황을 한눈에 보여주는
/// 읽기 전용 화면.
class WindowsMonthlyWorkerStatusScreen extends StatefulWidget {
  const WindowsMonthlyWorkerStatusScreen({super.key});

  @override
  State<WindowsMonthlyWorkerStatusScreen> createState() =>
      _WindowsMonthlyWorkerStatusScreenState();
}

class _WindowsMonthlyWorkerStatusScreenState
    extends State<WindowsMonthlyWorkerStatusScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _isLoading = true;

  Map<DateTime, List<Map<String, dynamic>>> _schedulesByDay = {};
  Map<DateTime, List<Map<String, dynamic>>> _internLogsByDay = {};

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMonth() async {
    setState(() => _isLoading = true);
    try {
      final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);

      final results = await Future.wait([
        TermService.instance
            .term('work_schedules')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
            )
            .where('date', isLessThan: Timestamp.fromDate(monthEnd))
            .get(),
        TermService.instance.term('organization').get(),
        TermService.instance
            .term('intern_logs')
            .where(
              'workDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
            )
            .where('workDate', isLessThan: Timestamp.fromDate(monthEnd))
            .get(),
        FirebaseFirestore.instance
            .collection('admin')
            .where('role', isEqualTo: 'admin_m')
            .get(),
      ]);

      if (!mounted) return;

      final roleMap = <String, String>{};
      for (final doc in (results[1] as QuerySnapshot).docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        if (name.isNotEmpty) roleMap[name] = data['role'] as String? ?? '';
      }

      final nameByUid = <String, String>{};
      for (final doc in (results[3] as QuerySnapshot).docs) {
        final data = doc.data() as Map<String, dynamic>;
        nameByUid[doc.id] = data['name'] as String? ?? '';
      }

      final schedulesByDay = <DateTime, List<Map<String, dynamic>>>{};
      for (final doc in (results[0] as QuerySnapshot).docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['date'] as Timestamp?;
        if (ts == null) continue;
        // 과거에 남아있는 근로학생 근무일정은 인턴근무일지로 대체했으므로 제외한다.
        final workerName = data['workerName'] as String? ?? '';
        if ((roleMap[workerName] ?? '') == '근로학생') continue;
        schedulesByDay.putIfAbsent(_dayKey(ts.toDate()), () => []).add(data);
      }

      final internLogsByDay = <DateTime, List<Map<String, dynamic>>>{};
      for (final doc in (results[2] as QuerySnapshot).docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['workDate'] as Timestamp?;
        if (ts == null) continue;
        internLogsByDay.putIfAbsent(_dayKey(ts.toDate()), () => []).add({
          ...data,
          'internName': nameByUid[data['uid'] as String? ?? ''] ?? '이름 없음',
        });
      }
      for (final list in schedulesByDay.values) {
        list.sort(
          (a, b) => (a['startTime'] as String? ?? '').compareTo(
            b['startTime'] as String? ?? '',
          ),
        );
      }
      for (final list in internLogsByDay.values) {
        list.sort(
          (a, b) => _compareByZone(
            a['internName'] as String? ?? '',
            b['internName'] as String? ?? '',
          ),
        );
      }

      setState(() {
        _schedulesByDay = schedulesByDay;
        _internLogsByDay = internLogsByDay;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(
      () =>
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
    );
    _loadMonth();
  }

  void _nextMonth() {
    setState(
      () =>
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
    );
    _loadMonth();
  }

  List<DateTime> _daysOfMonth() {
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    return List.generate(
      daysInMonth,
      (i) => DateTime(_focusedMonth.year, _focusedMonth.month, i + 1),
    );
  }

  static const _dowLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            const Text('근무자 현황 (월별)'),
          ],
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: _prevMonth,
            ),
            SizedBox(
              width: 100,
              child: Text(
                DateFormat('yyyy년 M월').format(_focusedMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chevron_right),
              onPressed: _nextMonth,
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _daysOfMonth().length,
              itemBuilder: (context, i) {
                final day = _daysOfMonth()[i];
                final key = _dayKey(day);
                final schedules = _schedulesByDay[key] ?? [];
                final internLogs = _internLogsByDay[key] ?? [];
                return _buildDayCard(day, schedules, internLogs);
              },
            ),
    );
  }

  Widget _buildDayCard(
    DateTime day,
    List<Map<String, dynamic>> schedules,
    List<Map<String, dynamic>> internLogs,
  ) {
    final isToday = _dayKey(DateTime.now()) == _dayKey(day);
    final isSunday = day.weekday == 7;
    final isSaturday = day.weekday == 6;
    final dowColor = isSunday
        ? Colors.red
        : isSaturday
        ? Colors.blue
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.green.withValues(alpha: 0.06)
            : FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isToday
              ? Colors.green.withValues(alpha: 0.4)
              : FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${day.day}일 (${_dowLabels[day.weekday - 1]})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: dowColor,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '오늘',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '직원 ${schedules.length}명  근로학생 ${internLogs.length}명',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          if (schedules.isEmpty && internLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '등록된 근무 일정이 없습니다',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.45),
                ),
              ),
            )
          else ...[
            if (schedules.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildScheduleGroup(schedules),
            ],
            if (internLogs.isNotEmpty) ...[
              if (schedules.isNotEmpty) const SizedBox(height: 6),
              _buildInternLogGroup(internLogs),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleGroup(List<Map<String, dynamic>> schedules) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: schedules.map((s) {
        final shift = s['shift'] as String? ?? '주간';
        final color = _shiftColors[shift] ?? const Color(0xFF9E9E9E);
        final name = s['workerName'] as String? ?? '';
        final start = s['startTime'] as String? ?? '';
        final end = s['endTime'] as String? ?? '';
        final timeStr = (start.isNotEmpty && end.isNotEmpty)
            ? '$start~$end'
            : '';
        return _chip(
          name: name,
          timeStr: timeStr,
          color: color,
          suffix: '[$shift]',
        );
      }).toList(),
    );
  }

  Widget _buildInternLogGroup(List<Map<String, dynamic>> logs) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: logs.map((log) {
        final name = log['internName'] as String? ?? '이름 없음';
        final start = log['startTime'] as String? ?? '';
        final end = log['endTime'] as String? ?? '';
        final timeStr = (start.isNotEmpty && end.isNotEmpty)
            ? '$start~$end'
            : '';
        return _chip(name: name, timeStr: timeStr, color: _internColor);
      }).toList(),
    );
  }

  Widget _chip({
    required String name,
    required String timeStr,
    required Color color,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(
              suffix,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
