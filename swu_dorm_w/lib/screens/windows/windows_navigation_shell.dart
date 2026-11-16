import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart'
    hide
        Colors,
        FilledButton,
        IconButton,
        Card,
        ListTile,
        showDialog,
        Divider,
        Checkbox,
        Tooltip,
        ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/models/user_model.dart';
import 'package:swu_dormi_admin/models/excel_student_row.dart';
import 'package:swu_dormi_admin/constants/floor_captain_accounts.dart';
import 'package:swu_dormi_admin/utils/xlsx_repair.dart';
import 'package:swu_dormi_admin/screens/windows/windows_dashboard.dart';
import 'package:swu_dormi_admin/screens/windows/windows_notices_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_student_council_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_meals_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_facilities_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_students_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_message_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_bulk_points_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_login_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart'
    show WindowsInspectionTabScreen;
import 'package:swu_dormi_admin/screens/windows/windows_attendance_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_work_schedule_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_board_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_interns_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_reports_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_reservations_screen.dart';
import 'package:swu_dormi_admin/services/term_service.dart';

class WindowsNavigationShell extends StatefulWidget {
  const WindowsNavigationShell({super.key});

  @override
  State<WindowsNavigationShell> createState() => _WindowsNavigationShellState();
}

class _WindowsNavigationShellState extends State<WindowsNavigationShell> with WindowListener {
  final _authService = AuthService();
  int _currentIndex = 0;
  bool _isCompact = false;

  final List<NavigationPaneItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initNavigationItems();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _initNavigationItems() {
    _navigationItems.addAll([
      PaneItem(
        icon: const Icon(FluentIcons.home),
        title: const Text('대시보드'),
        body: WindowsDashboard(
          onNavigate: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.megaphone),
        title: const Text('공지사항/월간계획'),
        body: const WindowsNoticesTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.search),
        title: const Text('게시판'),
        body: const WindowsBoardScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.cafe),
        title: const Text('식단표'),
        body: const WindowsMealsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.repair),
        title: const Text('수리 보수'),
        body: const WindowsFacilitiesScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
        infoBadge: StreamBuilder<QuerySnapshot>(
          stream: TermService.instance.term('facility_reports')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return InfoBadge(source: Text('$count'));
          },
        ),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.calendar_agenda),
        title: const Text('단위실 월검사'),
        body: const WindowsInspectionTabScreen(inspectionType: 'monthly'),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.move_to_folder),
        title: const Text('단위실 퇴사검사'),
        body: const WindowsInspectionTabScreen(inspectionType: 'move_out'),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.check_list),
        title: const Text('인원점검(화재대피)'),
        body: const WindowsAttendanceTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.event_date),
        title: const Text('세미나실 예약'),
        body: const WindowsReservationsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.people),
        title: const Text('학생 관리'),
        body: const WindowsStudentsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.green.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.message),
        title: const Text('메시지 전송'),
        body: const WindowsMessageScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.certificate),
        title: const Text('상벌 관리'),
        body: const WindowsPointsManagementTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.people_add),
        title: const Text('행정실 근무자 현황'),
        body: const WindowsWorkScheduleScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.education),
        title: const Text('인턴 관리'),
        body: const WindowsInternManagementTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
        infoBadge: const _InternUnreadBadge(),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.group),
        title: const Text('사생회'),
        body: const WindowsStudentCouncilTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.flag),
        title: const Text('게시판 신고 관리'),
        body: const WindowsReportsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
        infoBadge: StreamBuilder<QuerySnapshot>(
          stream: TermService.instance.term('reports')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return InfoBadge(source: Text('$count'));
          },
        ),
      ),
    ]);
  }

  Future<void> _handleLogout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          FilledButton(
            child: const Text('로그아웃'),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(FluentPageRoute(builder: (context) => const WindowsLoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final brightness = FluentTheme.of(context).brightness;

    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: DragToMoveArea(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    'SWU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('샬롬하우스 관리 시스템'),
              const SizedBox(width: 8),
              const _CurrentTermLabel(),
              const Spacer(),
            ],
          ),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 사용자 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(FluentIcons.contact, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser?.email?.split('@').first ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            // 로그아웃 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(FluentIcons.sign_out, size: 16),
                onPressed: _handleLogout,
              ),
            ),
            // 창 컨트롤 버튼들
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.chrome_minimize, size: 12),
              onPressed: () => windowManager.minimize(),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_restore, size: 12),
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.restore();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: () => windowManager.close(),
              ),
            ),
          ],
        ),
      ),
      pane: NavigationPane(
        selected: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        displayMode: _isCompact ? PaneDisplayMode.compact : PaneDisplayMode.open,
        toggleable: true,
        size: const NavigationPaneSize(openMaxWidth: 250, openMinWidth: 200, compactWidth: 48),
        items: _navigationItems,
        footerItems: [
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('설정'),
            body: const _SettingsPage(),
            selectedTileColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.1)),
          ),
        ],
      ),
      paneBodyBuilder: (item, body) {
        return Column(
          children: [
            const _TermViewOverrideBanner(),
            Expanded(child: body ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  @override
  void onWindowResize() {
    setState(() {
      // 창 크기에 따라 네비게이션 모드 변경
      windowManager.getSize().then((size) {
        if (size.width < 900) {
          _isCompact = true;
        } else {
          _isCompact = false;
        }
      });
    });
  }
}

/// 관리프로그램이 "조회 학기"(과거 학기 조회 모드)에 들어가 있을 때 모든 화면
/// 위에 띄우는 경고 배너. 이 상태에서는 화면에 보이는 데이터와(어쩌면 여기서
/// 하는 수정도) 현재 학기가 아니라 선택한 과거 학기를 향한다.
class _TermViewOverrideBanner extends StatelessWidget {
  const _TermViewOverrideBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: TermService.instance.viewOverride,
      builder: (context, overrideTermId, _) {
        if (overrideTermId == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(FluentIcons.warning, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '지금 "$overrideTermId" 학기 자료를 조회 중입니다 (현재 운영 학기 아님)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Button(
                onPressed: () => TermService.instance.clearViewOverride(),
                child: const Text('현재 학기로 돌아가기'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 상단 타이틀 옆에 "(현재 학기)"를 표시한다. settings/current_term을 실시간으로
/// 구독해 termId가 바뀌면 term_list에서 표시 이름을 다시 찾아온다.
class _CurrentTermLabel extends StatefulWidget {
  const _CurrentTermLabel();

  @override
  State<_CurrentTermLabel> createState() => _CurrentTermLabelState();
}

class _CurrentTermLabelState extends State<_CurrentTermLabel> {
  String? _label;
  String? _loadedForTermId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('current_term')
          .snapshots(),
      builder: (context, snapshot) {
        final termId = snapshot.data?.data()?['termId'] as String?;
        if (termId == null || termId.isEmpty) return const SizedBox.shrink();

        if (termId != _loadedForTermId) {
          _loadedForTermId = termId;
          FirebaseFirestore.instance.collection('term_list').doc(termId).get().then((doc) {
            if (!mounted || _loadedForTermId != termId) return;
            setState(() => _label = (doc.data()?['label'] as String?) ?? termId);
          });
        }

        if (_label == null) return const SizedBox.shrink();
        return Text(
          '($_label)',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        );
      },
    );
  }
}

/// "인턴 관리" 사이드바 항목에 붙는 빨간 배지. 층장단톡방에서 아직 안 읽은
/// 메시지가 있으면 그 총 개수를 보여준다. 인턴 관리 화면(windows_interns_screen.dart)의
/// 안 읽은 메시지 계산과 같은 방식이며, 사이드바에 항상 떠 있어야 하므로 화면을
/// 열지 않아도 보이도록 여기서 별도로(주기적으로) 계산한다.
class _InternUnreadBadge extends StatefulWidget {
  const _InternUnreadBadge();

  @override
  State<_InternUnreadBadge> createState() => _InternUnreadBadgeState();
}

class _InternUnreadBadgeState extends State<_InternUnreadBadge> {
  final _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  int _unreadTotal = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final usersSnap =
          await _firestore.collection('admin').where('role', isEqualTo: 'admin_m').get();

      // 담당 구역 → 층장 uid 목록 (windows_interns_screen.dart와 동일한 방식)
      final captainsByFloor = <String, List<String>>{};
      for (final doc in usersSnap.docs) {
        final email = doc.data()['email'] as String? ?? '';
        final floor = (kFloorCaptainAccounts[email] ?? '').trim();
        if (floor.isEmpty) continue;
        captainsByFloor.putIfAbsent(floor, () => []).add(doc.id);
      }
      if (captainsByFloor.isEmpty) {
        if (mounted) setState(() => _unreadTotal = 0);
        return;
      }

      final roomsSnap = await TermService.instance.term('floor_chats').get();
      var total = 0;
      for (final room in roomsSnap.docs) {
        final stored = (room.data()['roomId'] as String?) ?? room.id;
        final parts = stored.split('_');
        if (parts.length < 3) continue;
        final dormBuilding = parts[0];
        final wing = parts[1];
        final digits = RegExp(r'\d+').firstMatch(parts[2])?.group(0);
        if (digits == null) continue;
        final floorNum = (int.tryParse(digits) ?? 0) ~/ 100;
        final floorLabel = '$dormBuilding $wing $floorNum층';

        final uids = captainsByFloor[floorLabel];
        if (uids == null || uids.isEmpty) continue;

        // 한 구역에 담당자가 여러 명 배정된 경우(예: 방학 인턴 복수 배정) 메시지 1건을
        // 인원 수만큼 중복 집계하지 않도록, 구역당 메시지 1건은 1건으로만 센다.
        // (배정된 담당자 중 아직 한 명이라도 읽지 않았으면 그 구역의 미읽음 1건으로 간주)
        final msgsSnap = await room.reference.collection('messages').get();
        for (final m in msgsSnap.docs) {
          final data = m.data();
          final readBy = (data['readBy'] as List<dynamic>?) ?? const [];
          final senderId = data['senderId'] as String?;
          final recipients = uids.where((uid) => uid != senderId);
          if (recipients.isEmpty) continue;
          final allRead = recipients.every((uid) => readBy.contains(uid));
          if (!allRead) total++;
        }
      }

      if (mounted) setState(() => _unreadTotal = total);
    } catch (_) {
      // 배지는 부가 기능이므로 실패해도 조용히 무시한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unreadTotal == 0) return const SizedBox.shrink();
    return InfoBadge(source: Text('$_unreadTotal'), color: Colors.red);
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _storageService = StorageService();
  String? _currentBannerUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  String? _studentInfoExcelUrl;
  DateTime? _studentInfoExcelUploadedAt;
  bool _isUploadingStudentInfo = false;
  bool _isLoadingStudentInfoView = false;

  // 학기 관리
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _terms = [];
  String? _currentTermId;
  bool _isLoadingTerms = true;
  bool _isSwitchingTerm = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBanner();
    _loadStudentInfoExcelMeta();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final listSnap = await FirebaseFirestore.instance
          .collection('term_list')
          .orderBy('order')
          .get();
      final currentSnap =
          await FirebaseFirestore.instance.collection('settings').doc('current_term').get();
      setState(() {
        _terms = listSnap.docs;
        _currentTermId = currentSnap.data()?['termId'] as String?;
        _isLoadingTerms = false;
      });
    } catch (e) {
      debugPrint('학기 목록 로드 오류: $e');
      setState(() => _isLoadingTerms = false);
    }
  }

  Future<void> _switchTerm(String termId) async {
    if (termId == _currentTermId) return;
    setState(() => _isSwitchingTerm = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('current_term').set({
        'termId': termId,
      }, SetOptions(merge: true));
      setState(() => _currentTermId = termId);
      if (mounted) await _showRestartDialog();
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('오류'),
            content: Text('학기 전환 실패: $e'),
            actions: [Button(child: const Text('확인'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitchingTerm = false);
    }
  }

  /// 학기 전환 직후, 이미 열려 있는 화면들이 들고 있는 이전 학기 Firestore 참조는
  /// 자동으로 갱신되지 않으므로 프로그램을 재시작해야 완전히 반영된다는 걸 알리고,
  /// 확인을 누르면 실제로 새 프로세스를 띄운 뒤 현재 프로세스를 종료한다.
  Future<void> _showRestartDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ContentDialog(
        title: const Text('학기 전환 완료'),
        content: const Text(
          '학기가 전환되었습니다.\n변경 사항을 완전히 반영하기 위해 프로그램이 재시작됩니다.',
        ),
        actions: [
          FilledButton(
            child: const Text('확인'),
            onPressed: () {
              Navigator.pop(context);
              _restartApp();
            },
          ),
        ],
      ),
    );
  }

  void _restartApp() {
    try {
      Process.start(Platform.resolvedExecutable, [], mode: ProcessStartMode.detached);
    } catch (e) {
      debugPrint('프로그램 재시작 실패: $e');
    }
    exit(0);
  }

  /// 연도별 1학기/여름방학/2학기/겨울방학 후보를 만들고, 이미 term_list에 있는 건 뺀다.
  List<({String id, String label})> _termCandidates() {
    final existingIds = _terms.map((d) => d.id).toSet();
    final thisYear = DateTime.now().year;
    final candidates = <({String id, String label})>[];
    for (var y = thisYear - 1; y <= thisYear + 3; y++) {
      candidates.addAll([
        (id: '$y-1', label: '$y년 1학기'),
        (id: '$y-summer', label: '$y년 여름방학'),
        (id: '$y-2', label: '$y년 2학기'),
        (id: '$y-winter', label: '$y년 겨울방학'),
      ]);
    }
    return candidates.where((c) => !existingIds.contains(c.id)).toList();
  }

  Future<void> _showAddTermDialog() async {
    final candidates = _termCandidates();
    if (candidates.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('알림'),
          content: const Text('추가할 수 있는 학기 후보가 없습니다.'),
          actions: [Button(child: const Text('확인'), onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }

    var selected = candidates.first;
    final labelController = TextEditingController(text: selected.label);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('새 학기 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('학기'),
              const SizedBox(height: 4),
              ComboBox<({String id, String label})>(
                isExpanded: true,
                value: selected,
                items: candidates
                    .map((c) => ComboBoxItem(value: c, child: Text('${c.label} (${c.id})')))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selected = value;
                    labelController.text = value.label;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('표시 이름'),
              const SizedBox(height: 4),
              TextBox(controller: labelController),
            ],
          ),
          actions: [
            Button(child: const Text('취소'), onPressed: () => Navigator.pop(context, false)),
            FilledButton(child: const Text('추가'), onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (result != true) return;

    final termId = selected.id;
    final label = labelController.text.trim();
    if (termId.isEmpty || label.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('term_list').doc(termId).set({
        'label': label,
        'order': _terms.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadTerms();
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('오류'),
            content: Text('학기 추가 실패: $e'),
            actions: [Button(child: const Text('확인'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    }
  }

  Future<void> _loadCurrentBanner() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('home').get();
      if (doc.exists) {
        setState(() {
          _currentBannerUrl = doc.data()?['bannerImageUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('배너 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final downloadUrl = await _storageService.uploadHomeBanner(file);
      await FirebaseFirestore.instance.collection('settings').doc('home').set({
        'bannerImageUrl': downloadUrl,
      }, SetOptions(merge: true));
      setState(() => _currentBannerUrl = downloadUrl);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('완료'),
            content: const Text('배너 이미지가 성공적으로 업데이트되었습니다.'),
            actions: [
              FilledButton(child: const Text('확인'), onPressed: () => Navigator.pop(context)),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('오류'),
            content: Text('배너 업로드 실패: $e'),
            actions: [Button(child: const Text('확인'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _loadStudentInfoExcelMeta() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('home').get();
      if (doc.exists) {
        final data = doc.data();
        final ts = data?['studentInfoExcelUploadedAt'] as Timestamp?;
        setState(() {
          _studentInfoExcelUrl = data?['studentInfoExcelUrl'] as String?;
          _studentInfoExcelUploadedAt = ts?.toDate();
        });
      }
    } catch (e) {
      debugPrint('사생 기본 정보 엑셀 메타 로드 오류: $e');
    }
  }

  Future<void> _pickAndUploadStudentInfoExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isUploadingStudentInfo = true);
    try {
      final file = File(path);
      final originalBytes = await file.readAsBytes();

      // 업로드 전 형식 검증 (.xlsx가 아니거나 손상된 파일이면 업로드하지 않음)
      Excel? excel;
      Object? decodeError;
      try {
        excel = Excel.decodeBytes(originalBytes);
      } catch (e) {
        decodeError = e;
      }

      // 엑셀이 아닌 프로그램(메신저 미리보기, 한컴/WPS, 변환기 등)으로 저장한 .xlsx는 같은 문자열이
      // 중복 등록되어 있어 엑셀 패키지가 읽지 못하는 경우가 있다. 중복을 정리한 사본으로 다시 시도하고,
      // 성공하면 정리된 파일을 올린다 (이 파일을 읽는 다른 화면과 층장앱도 함께 정상 동작하도록).
      var uploadFile = file;
      var repaired = false;
      if (excel == null) {
        for (final byText in [false, true]) {
          try {
            final fixed = dedupeSharedStrings(originalBytes, matchByText: byText);
            if (fixed == null) continue;
            final decoded = Excel.decodeBytes(fixed);
            final tmp = File(
                '${Directory.systemTemp.path}${Platform.pathSeparator}student_info_repaired.xlsx');
            await tmp.writeAsBytes(fixed, flush: true);
            excel = decoded;
            uploadFile = tmp;
            repaired = true;
            break;
          } catch (_) {}
        }
      }

      if (excel == null) {
        final detail = '$decodeError';
        if (mounted) {
          await displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('오류'),
              content: Text('엑셀 파일을 읽지 못했습니다. .xlsx 형식(구형 .xls 불가)이고 손상되지 않은 파일인지 '
                  '확인해주세요. 엑셀에서 열어 "다른 이름으로 저장(.xlsx)" 후 다시 시도하면 해결되는 경우가 많습니다.\n'
                  '(상세: ${detail.length > 120 ? '${detail.substring(0, 120)}…' : detail})'),
              severity: InfoBarSeverity.error,
              action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
            ),
          );
        }
        return;
      }

      final downloadUrl = await _storageService.uploadStudentInfoExcel(uploadFile);
      if (repaired) {
        try {
          await uploadFile.delete();
        } catch (_) {}
      }
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('settings').doc('home').set({
        'studentInfoExcelUrl': downloadUrl,
        'studentInfoExcelUploadedAt': now,
      }, SetOptions(merge: true));
      setState(() {
        _studentInfoExcelUrl = downloadUrl;
        _studentInfoExcelUploadedAt = now.toDate();
      });
      // 학생앱 회원가입 시 "명단에 있는 학번인지" 확인하는 데 쓰는 학번 목록을 함께 갱신한다.
      final rosterCount = await _syncStudentRoster(excel);
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(rosterCount > 0 ? '완료' : '업로드 완료 (주의)'),
            content: Text(rosterCount > 0
                ? '사생 기본 정보 엑셀이 업로드되었습니다. (회원가입 검증용 학번 $rosterCount건 반영)'
                    '${repaired ? '\n파일 안의 중복 문자열을 자동으로 정리해서 올렸습니다.' : ''}'
                : '엑셀은 업로드되었지만 학번 열을 찾지 못해 회원가입 검증용 학번 명단은 갱신하지 않았습니다.'),
            severity: rosterCount > 0 ? InfoBarSeverity.success : InfoBarSeverity.warning,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('엑셀 업로드 실패: $e'),
            severity: InfoBarSeverity.error,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingStudentInfo = false);
    }
  }

  /// 엑셀의 학번을 student_roster/{학번} 문서로 동기화한다 (학생앱 회원가입 시 명단 확인용).
  /// 학번 외 개인정보는 저장하지 않고, 이번 엑셀에 없는 학번 문서는 지워 명단을 최신 상태로 맞춘다.
  /// 학번을 하나도 찾지 못하면(열 인식 실패 등) 기존 명단을 건드리지 않고 0을 반환한다.
  Future<int> _syncStudentRoster(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    if (rows.isEmpty) return 0;
    final headerIdx = ExcelStudentRow.findHeaderRowIndex(rows);
    final header = rows[headerIdx];
    final ids = <String>{};
    for (final row in rows.skip(headerIdx + 1)) {
      // 숫자 셀은 '2026123456.0'처럼 읽힐 수 있어 소수점 이하를 떼어낸다.
      final id = (ExcelStudentRow.fromRow(header, row).studentId ?? '')
          .trim()
          .replaceFirst(RegExp(r'\.0+$'), '');
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return 0;

    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('student_roster');
    final existing = await col.get();
    var batch = firestore.batch();
    var ops = 0;
    Future<void> flushIfFull() async {
      // Firestore batch는 500건 제한이 있어 넉넉히 400건마다 커밋한다.
      if (ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    for (final doc in existing.docs) {
      if (doc.id == '_meta' || ids.contains(doc.id)) continue;
      batch.delete(doc.reference);
      ops++;
      await flushIfFull();
    }
    for (final id in ids) {
      batch.set(col.doc(id), {'updatedAt': FieldValue.serverTimestamp()});
      ops++;
      await flushIfFull();
    }
    batch.set(col.doc('_meta'), {
      'count': ids.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ids.length;
  }

  Future<void> _viewStudentInfoExcel() async {
    if (_studentInfoExcelUrl == null) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('알림'),
          content: const Text('업로드된 사생 기본 정보 엑셀이 없습니다.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ),
      );
      return;
    }

    setState(() => _isLoadingStudentInfoView = true);
    try {
      final response = await http.get(Uri.parse(_studentInfoExcelUrl!));
      if (response.statusCode != 200) {
        throw Exception('파일 다운로드 실패 (${response.statusCode})');
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();

      if (!mounted) return;
      if (rows.isEmpty) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('알림'),
            content: const Text('엑셀 파일에 데이터가 없습니다.'),
            severity: InfoBarSeverity.warning,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
        return;
      }

      // 엑셀 첫 줄이 '2026학년도 2학기 학생정보' 같은 제목 행일 수 있으므로,
      // '학번' 열이 있는 행을 실제 헤더로 찾는다. (없으면 첫 줄을 헤더로 사용)
      int headerRowIndex = rows.indexWhere(
        (r) => r.any((h) => h.replaceAll(' ', '').contains('학번')),
      );
      if (headerRowIndex == -1) headerRowIndex = 0;

      final excelHeader = rows[headerRowIndex];
      final excelDataRows = rows.skip(headerRowIndex + 1).toList();

      // 학번 열 인덱스 탐색 (공백 제거 후 비교)
      final studentIdColIndex = excelHeader.indexWhere((h) => h.replaceAll(' ', '').contains('학번'));

      // users 컬렉션 전체를 학번 기준으로 조회 (인실/학과/휴대폰/자리번호 조인용)
      final Map<String, Map<String, dynamic>> usersByStudentId = {};
      if (studentIdColIndex != -1) {
        final usersSnap = await FirebaseFirestore.instance
            .collection('student')
            .where('role', isEqualTo: 'student')
            .get();
        for (final doc in usersSnap.docs) {
          // 필드가 하나도 없는 문서는 data()가 null을 반환해 크래시하므로 건너뛴다.
          final userData = doc.data() as Map<String, dynamic>?;
          if (userData == null) continue;
          final sid = userData['studentId']?.toString().trim() ?? '';
          if (sid.isNotEmpty) usersByStudentId[sid] = userData;
        }
      }

      // 엑셀 원본에 이미 있는 열은 앱에서 다시 붙이지 않는다.
      // (엑셀에 '인실/학과/휴대폰/자리번호'가 이미 있어 중복 표시되던 문제)
      String norm(String s) => s.replaceAll(RegExp(r'\s+'), '');
      bool excelHas(List<String> keywords) =>
          excelHeader.any((h) => keywords.any((k) => norm(h).contains(k)));

      final extraLabels = <String>[];
      final extraGetters = <String Function(UserModel)>[];
      void addExtra(String label, List<String> keys, String Function(UserModel) get) {
        if (excelHas(keys)) return;
        extraLabels.add(label);
        extraGetters.add(get);
      }

      addExtra('인실', ['인실'], (u) => u.roomCapacity);
      addExtra('학과', ['학과', '학부'], (u) => u.department ?? '');
      addExtra('휴대폰', ['휴대폰', '전화'], (u) => u.phoneNumber);
      addExtra('자리번호', ['자리번호'], (u) => u.seatNumber ?? '');

      final header = studentIdColIndex != -1
          ? [...excelHeader, ...extraLabels]
          : excelHeader;

      // 학번이 users에 존재하는지를 별도로 기록한다.
      // (조회된 값이 비어 있어도 '매칭'은 성공한 것으로 세야 한다)
      final matchedFlags = <bool>[];
      final dataRows = excelDataRows.map((row) {
        if (studentIdColIndex == -1) {
          matchedFlags.add(false);
          return row;
        }
        final sid = (studentIdColIndex < row.length ? row[studentIdColIndex] : '').trim();
        final userData = usersByStudentId[sid];
        matchedFlags.add(userData != null);
        if (userData == null) {
          return [...row, ...extraLabels.map((_) => '')];
        }
        final user = UserModel.fromMap(userData);
        return [...row, ...extraGetters.map((g) => g(user))];
      }).toList();

      final matchedCount = matchedFlags.where((m) => m).length;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final screenSize = MediaQuery.of(dialogContext).size;
          final dialogWidth = (screenSize.width * 0.9).clamp(600.0, 1400.0);
          final dialogHeight = (screenSize.height * 0.85).clamp(400.0, 900.0);
          return ContentDialog(
            constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight),
            title: const Text('사생 기본 정보'),
            content: SizedBox(
              width: dialogWidth - 40,
              height: dialogHeight - 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (studentIdColIndex != -1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '학번 매칭: $matchedCount / ${dataRows.length}명 (인실/학과/휴대폰/자리번호 조회됨)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '엑셀에서 "학번" 열을 찾지 못해 추가 정보를 표시할 수 없습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 10,
                          horizontalMargin: 8,
                          headingRowHeight: 36,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 40,
                          columns: header
                              .map(
                                (h) => DataColumn(
                                  label: Text(
                                    h,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          rows: dataRows
                              .map(
                                (row) => DataRow(
                                  cells: List.generate(
                                    header.length,
                                    (i) => DataCell(
                                      Text(
                                        i < row.length ? row[i] : '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('엑셀 파일을 불러오는 중 오류가 발생했습니다: $e'),
            severity: InfoBarSeverity.error,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStudentInfoView = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('설정')),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 학기 관리 - 전체 시스템(학생앱·층장앱 포함)이 보는 '현재 학기'를 전환한다.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.calendar),
                        SizedBox(width: 8),
                        Text(
                          '학기 관리',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '현재 학기를 전환하면 학생앱·층장앱을 포함한 전체 시스템이 해당 학기의 운영 데이터(출결·청소점검·식단표·메시지 등)를 보고 씁니다. '
                      '계정 정보와 게시판은 학기와 무관하게 유지됩니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingTerms)
                      const Center(child: ProgressRing())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ComboBox<String>(
                              placeholder: const Text('학기를 선택하세요'),
                              value: _currentTermId,
                              items: _terms
                                  .map((doc) => ComboBoxItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          '${doc.data()['label'] ?? doc.id}${doc.id == _currentTermId ? ' (현재)' : ''}',
                                        ),
                                      ))
                                  .toList(),
                              onChanged: _isSwitchingTerm
                                  ? null
                                  : (value) {
                                      if (value != null) _switchTerm(value);
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_isSwitchingTerm) const ProgressRing() else const SizedBox.shrink(),
                          const SizedBox(width: 12),
                          Button(
                            onPressed: _showAddTermDialog,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.add, size: 14),
                                SizedBox(width: 6),
                                Text('새 학기 추가'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      '과거 학기 조회',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '이 프로그램에서만 다른 학기의 자료를 들여다봅니다. 학생앱·층장앱 등 다른 앱과 '
                      '"현재 학기"에는 전혀 영향이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String?>(
                      valueListenable: TermService.instance.viewOverride,
                      builder: (context, overrideTermId, _) => Row(
                        children: [
                          Expanded(
                            child: ComboBox<String>(
                              placeholder: const Text('조회할 학기를 선택하세요'),
                              value: overrideTermId,
                              items: _terms
                                  .map((doc) => ComboBoxItem<String>(
                                        value: doc.id,
                                        child: Text('${doc.data()['label'] ?? doc.id}'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                TermService.instance.setViewOverride(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Button(
                            onPressed: overrideTermId == null
                                ? null
                                : () => TermService.instance.clearViewOverride(),
                            child: const Text('조회 중지'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 홈 배너 이미지 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.picture_fill),
                        SizedBox(width: 8),
                        Text(
                          '홈 배너 이미지',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '학생 앱 홈 화면에 표시될 배너 이미지를 설정합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: ProgressRing())
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 현재 배너 미리보기 (실제 배너는 1080x1920 세로형이므로 9:16 비율로 보여준다)
                          Container(
                            width: 180,
                            height: 320,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                            child: _currentBannerUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      _currentBannerUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(FluentIcons.picture_fill, size: 40),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(FluentIcons.picture_fill, size: 40),
                                        SizedBox(height: 8),
                                        Text('배너 이미지 없음'),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('권장 크기: 1080 x 1920px (세로형)'),
                              const Text('지원 형식: JPG, PNG, WEBP'),
                              const SizedBox(height: 16),
                              if (_isUploading)
                                const Row(
                                  children: [ProgressRing(), SizedBox(width: 12), Text('업로드 중...')],
                                )
                              else
                                FilledButton(
                                  onPressed: _pickAndUploadBanner,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.upload, size: 16),
                                      SizedBox(width: 8),
                                      Text('이미지 선택 및 업로드'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 사생 기본 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.excel_document),
                        SizedBox(width: 8),
                        Text(
                          '사생 기본 정보',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _studentInfoExcelUploadedAt != null
                          ? '마지막 업로드: ${_studentInfoExcelUploadedAt!.toString().substring(0, 16)}'
                          : '업로드된 사생 기본 정보 엑셀이 없습니다.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_isUploadingStudentInfo)
                          const Row(
                            children: [ProgressRing(), SizedBox(width: 12), Text('업로드 중...')],
                          )
                        else
                          FilledButton(
                            onPressed: _pickAndUploadStudentInfoExcel,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.upload, size: 16),
                                SizedBox(width: 8),
                                Text('엑셀업로드'),
                              ],
                            ),
                          ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed: _isLoadingStudentInfoView ? null : _viewStudentInfoExcel,
                          child: _isLoadingStudentInfoView
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: ProgressRing(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('불러오는 중...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FluentIcons.table, size: 16),
                                    SizedBox(width: 8),
                                    Text('사생기본 정보 보기'),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(FluentIcons.info),
                title: const Text('버전 정보'),
                subtitle: const Text('SWU 샬롬하우스 관리 시스템 v1.0.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
