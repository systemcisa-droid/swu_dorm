import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../notices/pdf_viewer_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../utils/student_council_strings.dart';
import '../../models/comment_model.dart';
import '../../widgets/linkified_text.dart';
import 'package:swu_dormi2/services/term_service.dart';

/// 사생회 공지 화면. 사이드 메뉴의 "사생회" 아코디언에서 "공지"를 누르면 연다.
class CouncilNoticesScreen extends StatelessWidget {
  const CouncilNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabNotices)),
      body: _StudentCouncilShared.buildNoticesTab(s),
    );
  }
}

/// 사생회 캠페인 화면. 사이드 메뉴의 "사생회" 아코디언에서 "캠페인"을 누르면 연다.
class CouncilCampaignsScreen extends StatelessWidget {
  const CouncilCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabCampaigns)),
      body: _StudentCouncilShared.buildCampaignsTab(s),
    );
  }
}

/// 사생회 선거 화면. 사이드 메뉴의 "사생회" 아코디언에서 "선거"를 누르면 연다.
class CouncilElectionsScreen extends StatelessWidget {
  const CouncilElectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabElections)),
      body: _StudentCouncilShared.buildElectionsTab(s),
    );
  }
}

/// 사생회 회의록 화면. 사이드 메뉴의 "사생회" 아코디언에서 "회의록"을 누르면 연다.
/// 관리프로그램과 동일하게 연도/월을 고르고 주차(1~5번째주)별로 등록된 PDF를 확인하는
/// 슬롯 구조이다 (식단표와 동일한 방식). 학생은 읽기만 가능하다.
class CouncilMinutesScreen extends StatefulWidget {
  const CouncilMinutesScreen({super.key});

  @override
  State<CouncilMinutesScreen> createState() => _CouncilMinutesScreenState();
}

class _CouncilMinutesScreenState extends State<CouncilMinutesScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabMinutes)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  items: [
                    for (int y = DateTime.now().year - 2; y <= DateTime.now().year + 2; y++)
                      DropdownMenuItem(value: y, child: Text('$y년')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedYear = v);
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: [
                    for (int m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m월')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMonth = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('council_minutes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(s.loadError));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final minutesByWeek = <int, Map<String, dynamic>>{};
                for (final doc in snapshot.data?.docs ?? []) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['_id'] = doc.id;
                  final year = (data['year'] as num?)?.toInt();
                  final month = (data['month'] as num?)?.toInt();
                  final week = (data['weekNumber'] as num?)?.toInt();
                  if (year == _selectedYear && month == _selectedMonth && week != null) {
                    minutesByWeek[week] = data;
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final week = index + 1;
                    final data = minutesByWeek[week];
                    final isRegistered = data != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRegistered
                              ? Colors.teal.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          child: Icon(
                            isRegistered ? Icons.picture_as_pdf_outlined : Icons.lock_clock_outlined,
                            color: isRegistered ? Colors.teal : Colors.grey,
                          ),
                        ),
                        title: Text('$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $week번째주'),
                        subtitle: Text(
                          isRegistered ? s.registeredLabel : s.unregisteredLabel,
                          style: TextStyle(color: isRegistered ? Colors.teal : Colors.grey),
                        ),
                        trailing: isRegistered ? const Icon(Icons.chevron_right) : null,
                        onTap: isRegistered
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CouncilMinuteWeekDetailScreen(
                                      year: _selectedYear,
                                      month: _selectedMonth,
                                      week: week,
                                      data: data,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 공지 / 캠페인 / 선거 화면이 공유하는 목록·카드 빌더.
///
/// 각 목록은 Firestore 컬렉션을 그대로 읽어 표시하며,
/// 아직 등록된 문서가 없으면 빈 상태 안내를 보여준다.
///   - council_notices   : 사생회 공지
///   - council_campaigns : 캠페인
///   - council_elections : 선거
///   - council_minutes   : 회의록
class _StudentCouncilShared {
  static final _db = DatabaseService();

  // ── 공통 상태 위젯 ──────────────────────────────────────────
  static Widget _buildEmpty(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 컬렉션 하나를 읽어 목록으로 그리는 공통 StreamBuilder.
  static Widget _buildList({
    required String collection,
    required String orderBy,
    required IconData emptyIcon,
    required String emptyMessage,
    required String errorMessage,
    required Widget Function(BuildContext context, String id, Map<String, dynamic> data) itemBuilder,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy(orderBy, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmpty(Icons.error_outline, errorMessage);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data?.docs ?? [];
        // 고정 공지를 목록 상단에 올린다.
        docs = [...docs]..sort((a, b) {
            final ap = ((a.data() as Map<String, dynamic>?) ?? {})['isPinned'] == true;
            final bp = ((b.data() as Map<String, dynamic>?) ?? {})['isPinned'] == true;
            if (ap == bp) return 0;
            return ap ? -1 : 1;
          });
        if (docs.isEmpty) {
          return _buildEmpty(emptyIcon, emptyMessage);
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              ...docs.map((d) => itemBuilder(
                  context, d.id, (d.data() as Map<String, dynamic>?) ?? {})),
            ],
          ),
        );
      },
    );
  }

  // ── 공지 탭 ────────────────────────────────────────────────
  static Widget buildNoticesTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_notices',
      orderBy: 'createdAt',
      emptyIcon: Icons.inbox,
      emptyMessage: s.noticesEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildNoticeCard(context, id, data, s),
    );
  }

  static Widget _buildNoticeCard(BuildContext context, String id,
      Map<String, dynamic> data, StudentCouncilStrings s) {
    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
    final isPinned = data['isPinned'] == true;
    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final thumbnail = imageUrls.isNotEmpty ? imageUrls.first : null;

    return Column(
      children: [
        InkWell(
          onTap: () {
            // 공지사항과 동일하게 계정당 1회만 집계한다. 실패해도 열람은 막지 않는다.
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) _db.incrementCouncilNoticeViewCount(id, uid);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CouncilNoticeDetailScreen(id: id, data: data),
              ),
            );
          },
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail != null
                    ? Image.network(
                        thumbnail,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _noticeIconBox(),
                      )
                    : _noticeIconBox(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isPinned) ...[
                          Icon(Icons.push_pin,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '$viewCount',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (createdAt != null)
                          Text(
                            '  |  ${DateFormat('yyyy.MM.dd').format(createdAt)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
            ],
          ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  /// 이미지가 없는 공지의 기본 아이콘 박스
  static Widget _noticeIconBox() => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            Icon(Icons.campaign_outlined, color: Colors.indigo.shade300, size: 26),
      );

  // ── 캠페인 탭 ──────────────────────────────────────────────
  static Widget buildCampaignsTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_campaigns',
      orderBy: 'startDate',
      emptyIcon: Icons.volunteer_activism_outlined,
      emptyMessage: s.campaignsEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildCampaignCard(context, id, data, s),
    );
  }

  /// 캠페인 기간으로 진행 상태(라벨·색)를 계산한다. 목록 카드와 상세 화면이 함께 쓴다.
  static ({String label, Color color}) _campaignStatus(
      Map<String, dynamic> data, StudentCouncilStrings s) {
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    if (start != null && now.isBefore(start)) {
      return (label: s.statusUpcoming, color: const Color(0xFFFF9800));
    } else if (end != null && now.isAfter(end)) {
      return (label: s.statusClosed, color: const Color(0xFF757575));
    }
    return (label: s.statusOngoing, color: const Color(0xFF009688));
  }

  static Widget _buildCampaignCard(BuildContext context, String id,
      Map<String, dynamic> data, StudentCouncilStrings s) {
    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final status = _campaignStatus(data, s);
    final statusLabel = status.label;
    final statusColor = status.color;
    final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isLiked =
        myUid != null && ((data['likes'] as List?)?.contains(myUid) ?? false);

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (start != null) fmt.format(start),
      if (end != null) fmt.format(end),
    ].join(' ~ ');

    return Column(
      children: [
        InkWell(
          onTap: () {
            // 공지사항과 동일하게 계정당 1회만 집계한다. 실패해도 열람은 막지 않는다.
            if (myUid != null) _db.incrementCampaignViewCount(id, myUid);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampaignDetailScreen(id: id, data: data),
              ),
            );
          },
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
              if (period.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      period,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
              // 조회수 · 좋아요 (게시판 목록과 같은 표시 방식)
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('$viewCount',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(width: 12),
                  Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 13,
                      color: isLiked ? Colors.red : Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('$likeCount',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  // ── 선거 탭 ────────────────────────────────────────────────
  static Widget buildElectionsTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_elections',
      orderBy: 'startDate',
      emptyIcon: Icons.how_to_vote_outlined,
      emptyMessage: s.electionsEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildElectionCard(context, id, data, s),
    );
  }

  static Widget _buildElectionCard(
      BuildContext context, String id, Map<String, dynamic> data, StudentCouncilStrings s) {
    // 투표율 = 투표수 / 선거인 수. 관리자가 선거를 저장할 때 기록된다.
    // 진행 상태. 캠페인 카드와 같은 기준·색상을 쓴다.
    // 마감 시각은 관리 프로그램에서 설정한 종료일시를 그대로 따른다.
    final now = DateTime.now();
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    String statusLabel;
    Color statusColor;
    if (start != null && now.isBefore(start)) {
      statusLabel = s.statusUpcoming;
      statusColor = const Color(0xFFFF9800);
    } else if (end != null && now.isAfter(end)) {
      statusLabel = s.statusClosed;
      statusColor = const Color(0xFF757575);
    } else {
      statusLabel = s.statusOngoing;
      statusColor = const Color(0xFF009688);
    }

    final voteCount = (data['voteCount'] as num?)?.toInt() ?? 0;
    final eligibleCount = (data['eligibleCount'] as num?)?.toInt() ?? 0;
    final turnout =
        eligibleCount == 0 ? 0.0 : (voteCount / eligibleCount).clamp(0.0, 1.0);
    final title = (data['title'] ?? '').toString();
    final candidates = (data['candidates'] as List?)
            ?.map((c) => c.toString())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (start != null) fmt.format(start),
      if (end != null) fmt.format(end),
    ].join(' ~ ');

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ElectionDetailScreen(id: id, data: data),
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_vote_outlined,
                      size: 18, color: Colors.indigo.shade300),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: Colors.grey.shade400),
                ],
              ),
              if (period.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${s.electionPeriod}  $period',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (candidates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  s.electionCandidates,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in candidates)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
              // 투표율 (선거인 수가 등록된 경우에만 표시)
              if (eligibleCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: turnout,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.indigo.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.electionTurnout} ${(turnout * 100).toStringAsFixed(1)}%'
                      '  ($voteCount/$eligibleCount)',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

/// 선거 공고 상세 화면. 목록의 선거 카드를 누르면 열린다.
///
/// 비밀투표 구조:
///   council_elections/{id}/voters/{uid}   - 투표 여부만 기록 (선택 후보 없음)
///   council_elections/{id}/ballots/{auto} - 선택한 후보만 기록 (작성자 없음)
/// 두 문서를 연결할 수 없어 누가 누구를 뽑았는지 알 수 없다.
class ElectionDetailScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const ElectionDetailScreen({super.key, required this.id, required this.data});

  @override
  State<ElectionDetailScreen> createState() => _ElectionDetailScreenState();
}

class _ElectionDetailScreenState extends State<ElectionDetailScreen> {
  String? _selectedCandidate;
  bool _hasVoted = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkVoted();
    _maybeStartCountdownTimer();
  }

  /// 투표 시작 전이면 초 단위로 화면을 갱신해 실시간 카운트다운을 보여준다.
  /// 시작 시각이 지나면 스스로 멈춘다.
  void _maybeStartCountdownTimer() {
    final start = _startDate;
    if (start == null || !DateTime.now().isBefore(start)) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!DateTime.now().isBefore(start)) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 본인의 투표 여부만 확인한다 (규칙상 본인 문서만 읽을 수 있다).
  Future<void> _checkVoted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('council_elections')
          .doc(widget.id)
          .collection('voters')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _hasVoted = doc.exists;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 후보 이름 -> 소개글. 관리자가 입력하지 않은 후보는 키가 없다.
  Map<String, String> get _candidateProfiles =>
      (widget.data['candidateProfiles'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
      const {};

  /// 후보 이름 -> 소개글
  Map<String, String> get _candidateIntros =>
      (widget.data['candidateIntros'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
      const {};

  /// 후보 이름 -> 선거 포스터 PDF {url, name}
  Map<String, Map<String, String>> get _candidatePdfs =>
      (widget.data['candidatePdfs'] as Map?)?.map((k, v) {
            final m = (v as Map?) ?? const {};
            return MapEntry(k.toString(), {
              'url': (m['url'] ?? '').toString(),
              'name': (m['name'] ?? '').toString(),
            });
          }) ??
      const {};

  DateTime? get _startDate => (widget.data['startDate'] as Timestamp?)?.toDate();
  DateTime? get _endDate => (widget.data['endDate'] as Timestamp?)?.toDate();

  /// 투표 기간인지 판단한다. 관리 프로그램에서 설정한 종료일시가 마감 시각이다.
  bool get _isVotingOpen {
    final now = DateTime.now();
    final start = _startDate;
    final end = _endDate;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  Future<void> _submitVote(StudentCouncilStrings s) async {
    if (_isSubmitting) return;
    final candidate = _selectedCandidate;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (candidate == null || uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.voteConfirmTitle),
        content: Text(s.voteConfirmBody(candidate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.voteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.voteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final election = FirebaseFirestore.instance
          .collection('council_elections')
          .doc(widget.id);

      // 투표 표시를 먼저 만든다. 이미 투표했다면 규칙에서 막혀 여기서 실패하므로
      // 중복 투표가 표에 반영되지 않는다.
      await election.collection('voters').doc(uid).set({
        'votedAt': FieldValue.serverTimestamp(),
      });

      // 익명 표는 별도 문서로 저장한다 (작성자 정보를 담지 않는다).
      await election.collection('ballots').add({'candidate': candidate});

      // 투표율 표시용 합계. 합계만 담으므로 비밀투표에 영향이 없다.
      await election.update({'voteCount': FieldValue.increment(1)});

      if (!mounted) return;
      setState(() {
        _hasVoted = true;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.voteDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // permission-denied 는 "이미 투표함"일 수도, 규칙 미배포 같은 설정 문제일 수도
      // 있다. 투표 표시 문서가 실제로 있는지 확인해 둘을 구분한다.
      // (확인 없이 투표 완료로 처리하면 저장되지 않았는데도 완료로 보인다.)
      var alreadyVoted = false;
      final uid2 = FirebaseAuth.instance.currentUser?.uid;
      if (uid2 != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('council_elections')
              .doc(widget.id)
              .collection('voters')
              .doc(uid2)
              .get();
          alreadyVoted = doc.exists;
        } catch (_) {
          // 조회 자체가 막히면 설정 문제로 본다.
        }
      }

      if (!mounted) return;
      if (alreadyVoted) setState(() => _hasVoted = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(alreadyVoted ? s.voteAlreadyDone : s.voteFailed),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    final title = (widget.data['title'] ?? '').toString();
    final content = (widget.data['content'] ?? '').toString();
    final candidates = (widget.data['candidates'] as List?)
            ?.map((c) => c.toString())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (_startDate != null) fmt.format(_startDate!),
      if (_endDate != null) fmt.format(_endDate!),
    ].join(' ~ ');

    final timeFmt = DateFormat('HH:mm');
    final voteStartTime = _startDate != null ? timeFmt.format(_startDate!) : null;
    final voteCloseTime =
        _endDate != null ? timeFmt.format(_endDate!) : null;

    return Scaffold(
      appBar: AppBar(title: Text(s.electionDetailTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_vote_outlined,
                    size: 22, color: Colors.indigo.shade300),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (period.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${s.electionPeriod}  $period',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (voteStartTime != null && voteCloseTime != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    '$voteStartTime ~ $voteCloseTime',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            if (content.isNotEmpty) ...[
              Text(content, style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 20),
            ],
            _buildVoteSection(s, candidates),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteSection(StudentCouncilStrings s, List<String> candidates) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (candidates.isEmpty) {
      return _buildInfoBox(Icons.info_outline, s.voteNoCandidates);
    }

    // 투표 완료 / 기간 외에는 후보만 보여주고 선택은 막는다.
    final notStartedYet =
        _startDate != null && DateTime.now().isBefore(_startDate!);
    final String? closedMessage = _hasVoted
        ? s.voteAlreadyDone
        : notStartedYet
            ? null
            : !_isVotingOpen
                ? s.voteClosed
                : null;
    final canVote = !_hasVoted && !notStartedYet && _isVotingOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notStartedYet) ...[
          _buildCountdown(s),
          const SizedBox(height: 20),
        ],
        Text(
          canVote ? s.voteSelectCandidate : s.electionCandidates,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final c in candidates) _buildCandidateTile(c, canVote),
        const SizedBox(height: 20),
        if (canVote) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedCandidate == null || _isSubmitting)
                  ? null
                  : () => _submitVote(s),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(s.voteButton,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoBox(Icons.lock_outline, s.voteSecretNotice),
        ] else ...[
          if (!notStartedYet)
            _buildInfoBox(
              _hasVoted ? Icons.check_circle_outline : Icons.info_outline,
              closedMessage!,
            ),
          // 투표를 마친 학생에게만 결과 공표·이의 접수 안내를 보여준다.
          if (_hasVoted) ...[
            const SizedBox(height: 14),
            Text(
              s.voteResultNotice,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCandidateTile(String candidate, bool canVote) {
    final isSelected = _selectedCandidate == candidate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap:
            canVote ? () => setState(() => _selectedCandidate = candidate) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (canVote)
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? Colors.indigo : Colors.grey.shade400,
                )
              else
                Icon(Icons.person_outline,
                    size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  candidate,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.indigo.shade700 : null,
                  ),
                ),
              ),
              // 소개 버튼은 선택과 별개로 항상 누를 수 있다.
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CandidateProfileScreen(
                      name: candidate,
                      intro: _candidateIntros[candidate] ?? '',
                      videoUrl: _candidateProfiles[candidate] ?? '',
                      pdfUrl: _candidatePdfs[candidate]?['url'] ?? '',
                      pdfName: _candidatePdfs[candidate]?['name'] ?? '',
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      StudentCouncilStrings(
                              Provider.of<LocaleProvider>(context).isEnglish)
                          .candidateIntro,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 투표 시작까지 남은 시간을 초 단위까지 실시간으로 보여준다.
  Widget _buildCountdown(StudentCouncilStrings s) {
    final start = _startDate;
    if (start == null) return const SizedBox.shrink();
    var remaining = start.difference(DateTime.now());
    if (remaining.isNegative) remaining = Duration.zero;

    String two(int n) => n.toString().padLeft(2, '0');
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final clock = '${two(hours)}:${two(minutes)}:${two(seconds)}';
    final countdownText =
        days > 0 ? (s.isEnglish ? '${days}d $clock' : '$days일 $clock') : clock;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.voteStartsInLabel,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            countdownText,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 후보 소개 화면. 선거 상세의 후보 목록에서 "소개"를 누르면 열린다.
///
/// 표시 순서: 후보 소개글 → 유튜브 링크 → 선거 포스터(바로 렌더링)
class CandidateProfileScreen extends StatelessWidget {
  final String name;

  /// 유튜브 링크 (연설·공약 영상)
  final String videoUrl;

  /// 후보 소개글
  final String intro;

  final String pdfUrl;
  final String pdfName;

  const CandidateProfileScreen({
    super.key,
    required this.name,
    this.videoUrl = '',
    this.intro = '',
    this.pdfUrl = '',
    this.pdfName = '',
  });

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    return Scaffold(
      appBar: AppBar(title: Text(s.candidateIntroTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이름 ──
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(Icons.person,
                      size: 30, color: Colors.indigo.shade300),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── 후보 소개 (없으면 표시하지 않는다) ──
            if (intro.isNotEmpty)
              Text(
                intro,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),

            // ── 선거 포스터 (버튼 없이 바로 렌더링) ──
            if (pdfUrl.isNotEmpty) ...[
              // 위에 소개글이 있을 때만 간격을 준다.
              if (intro.isNotEmpty) const SizedBox(height: 24),
              Text(
                s.electionPoster,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // 스크롤 안에서 렌더링해야 하므로 높이를 고정한다.
              // 확대해서 보려면 우측 상단 버튼으로 전체 화면 뷰어를 연다.
              SizedBox(
                height: 480,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SfPdfViewer.network(
                          pdfUrl,
                          canShowScrollHead: false,
                          canShowScrollStatus: false,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfViewerScreen(
                                  pdfUrl: pdfUrl,
                                  pdfFileName: pdfName.isEmpty
                                      ? s.electionPoster
                                      : pdfName,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.fullscreen,
                                  size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── 유튜브 링크 ──
            if (videoUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(videoUrl);
                  final opened = uri == null
                      ? false
                      : await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.linkOpenFailed)),
                    );
                  }
                },
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: Text(s.candidateWatchVideo),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFFFF0000),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                videoUrl,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],

          ],
        ),
      ),
    );
  }
}

/// 사생회 공지 상세 화면. 이미지·PDF 첨부를 함께 보여준다.
class CouncilNoticeDetailScreen extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const CouncilNoticeDetailScreen(
      {super.key, required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final authorName = (data['authorName'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isPinned = data['isPinned'] == true;
    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final pdfFileName = (data['pdfFileName'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(s.noticeDetailTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPinned) ...[
                  Icon(Icons.push_pin, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    [
                      if (authorName.isNotEmpty) authorName,
                      if (createdAt != null)
                        DateFormat('yyyy.MM.dd HH:mm').format(createdAt),
                    ].join('  ·  '),
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                // 목록에서 넘어온 값은 본인 조회가 반영되기 전이므로 문서를 구독해 최신 값을 보여준다.
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('council_notices')
                      .doc(id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final live = snapshot.data?.data()?['viewCount'] as num?;
                    final count =
                        (live ?? data['viewCount'] as num?)?.toInt() ?? 0;
                    return Text(
                      '$count',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 첨부 이미지
            if (imageUrls.isNotEmpty) ...[
              for (final url in imageUrls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            if (content.isNotEmpty)
              Text(content, style: const TextStyle(fontSize: 15, height: 1.7)),

            // 첨부 PDF
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      pdfUrl: pdfUrl,
                      pdfFileName:
                          pdfFileName.isEmpty ? s.noticeDetailTitle : pdfFileName,
                    ),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  pdfFileName.isEmpty ? s.noticeOpenPdf : pdfFileName,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 사생회 회의록 주차별 상세 화면. 식단표와 동일하게 한 주차에 PDF 한 장만 있다.
class CouncilMinuteWeekDetailScreen extends StatelessWidget {
  final int year;
  final int month;
  final int week;
  final Map<String, dynamic> data;
  const CouncilMinuteWeekDetailScreen({
    super.key,
    required this.year,
    required this.month,
    required this.week,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final pdfFileName = (data['pdfFileName'] ?? '').toString();
    final slotName = '$year.${month.toString().padLeft(2, '0')} $week번째주 ${s.minuteDetailTitle}';

    return Scaffold(
      appBar: AppBar(title: Text(s.minuteDetailTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slotName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 16),
            if (pdfUrl.isEmpty)
              Expanded(child: Center(child: Text(s.minutesEmpty)))
            else ...[
              Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pdfFileName.isEmpty ? s.minuteDetailTitle : pdfFileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 확대해서 보려면 우측 상단 버튼으로 전체 화면 뷰어를 연다.
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SfPdfViewer.network(
                          pdfUrl,
                          canShowScrollHead: false,
                          canShowScrollStatus: false,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfViewerScreen(
                                  pdfUrl: pdfUrl,
                                  pdfFileName: pdfFileName.isEmpty ? s.minuteDetailTitle : pdfFileName,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.fullscreen, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 캠페인 상세 화면. 이미지·PDF 첨부, 조회수, 좋아요를 보여준다.
/// 조회수·좋아요는 다른 학생이 누를 때마다 바뀌므로 문서를 구독해 실시간으로 반영한다.
class CampaignDetailScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const CampaignDetailScreen({super.key, required this.id, required this.data});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final _db = DatabaseService();
  final _firestore = FirebaseFirestore.instance;
  final _commentController = TextEditingController();
  // 좋아요 처리 중 중복 탭 방지 (규칙이 likeCount 불일치 요청을 거부하므로 필요하다)
  bool _isLiking = false;
  bool _isLoadingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(bool currentlyLiked, StudentCouncilStrings s) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isLiking) return;
    setState(() => _isLiking = true);
    try {
      await _db.setCampaignLike(widget.id, uid, !currentlyLiked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.likeFailed)));
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _addComment(dynamic user, StudentCouncilStrings s) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (_isLoadingComment) return;

    setState(() => _isLoadingComment = true);
    try {
      final commentId = _firestore.collection('campaign_comments').doc().id;
      final comment = CommentModel(
        id: commentId,
        postId: widget.id,
        content: content,
        authorId: user.uid,
        authorName: user.nickname ?? user.name,
        authorProfileImageUrl: user.profileImageUrl,
        createdAt: DateTime.now(),
      );

      _commentController.clear();

      await _firestore
          .collection('campaign_comments')
          .doc(commentId)
          .set(comment.toMap());
      await _firestore.collection('council_campaigns').doc(widget.id).update({
        'commentCount': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.commentPosted), duration: const Duration(milliseconds: 1500)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.commentPostError(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoadingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId, StudentCouncilStrings s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteCommentTitle),
        content: Text(s.deleteCommentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _firestore.collection('campaign_comments').doc(commentId).delete();
      await _firestore.collection('council_campaigns').doc(widget.id).update({
        'commentCount': FieldValue.increment(-1),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.commentDeleted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.commentDeleteError(e))));
      }
    }
  }

  // 댓글 신고 다이얼로그. 게시판 댓글 신고와 동일한 사유 목록·저장 방식을 쓴다.
  Future<void> _showReportDialog({
    required String reporterId,
    required String commentId,
    required String targetAuthorId,
    required StudentCouncilStrings s,
  }) async {
    const reportReasonsKo = ['비방·욕설', '허위 사실 유포', '음란·불건전 내용', '개인정보 침해', '기타'];
    final reportReasons = s.reportReasons;
    String? selectedReasonKo;
    final etcController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.reportDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reportCommentPrompt, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                ...List.generate(reportReasonsKo.length, (i) {
                  final reasonKo = reportReasonsKo[i];
                  final reasonLabel = reportReasons[i];
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedReasonKo = reasonKo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            selectedReasonKo == reasonKo
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 20,
                            color: selectedReasonKo == reasonKo
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(reasonLabel, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReasonKo == '기타') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: etcController,
                    decoration: InputDecoration(
                      hintText: s.reportDetailHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: selectedReasonKo == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(s.report, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReasonKo == null) {
      etcController.dispose();
      return;
    }

    try {
      await TermService.instance.term('reports').add({
        'reporterId': reporterId,
        'targetId': commentId,
        'targetType': 'comment',
        'targetAuthorId': targetAuthorId,
        'reason': selectedReasonKo,
        'detail': selectedReasonKo == '기타' ? etcController.text.trim() : '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.reportSubmitted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.reportSubmitError(e))));
      }
    } finally {
      etcController.dispose();
    }
  }

  Future<void> _blockUser(String targetUid, StudentCouncilStrings s) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isBlocked = authProvider.blockedUsers.contains(targetUid);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? s.unblockTitle : s.blockTitle),
        content: Text(isBlocked ? s.unblockConfirm : s.blockConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBlocked ? s.unblockAction : s.blockAction,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = isBlocked
        ? await authProvider.unblockUser(targetUid)
        : await authProvider.blockUser(targetUid);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBlocked ? s.unblockedMessage : s.blockedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    final me = Provider.of<AuthProvider>(context).currentUser;
    final myUid = me?.uid ?? FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(s.campaignDetailTitle)),
      body: Column(
        children: [
          Expanded(child: _buildCampaignBody(context, s, myUid)),
          if (me != null) _buildCommentInput(me, s),
        ],
      ),
    );
  }

  Widget _buildCampaignBody(
      BuildContext context, StudentCouncilStrings s, String? myUid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('council_campaigns')
            .doc(widget.id)
            .snapshots(),
        builder: (context, snapshot) {
          // 아직 도착하지 않았거나 문서가 사라졌으면 목록에서 넘어온 값을 쓴다.
          final data = snapshot.data?.data() ?? widget.data;

          final title = (data['title'] ?? '').toString();
          final content = (data['content'] ?? '').toString();
          final start = (data['startDate'] as Timestamp?)?.toDate();
          final end = (data['endDate'] as Timestamp?)?.toDate();
          final imageUrls = (data['imageUrls'] as List?)
                  ?.map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [];
          final pdfUrl = (data['pdfUrl'] ?? '').toString();
          final pdfFileName = (data['pdfFileName'] ?? '').toString();
          final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
          final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
          final isLiked = myUid != null &&
              ((data['likes'] as List?)?.contains(myUid) ?? false);
          final status = _StudentCouncilShared._campaignStatus(data, s);

          final fmt = DateFormat('yyyy.MM.dd');
          final period = [
            if (start != null) fmt.format(start),
            if (end != null) fmt.format(end),
          ].join(' ~ ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (period.isNotEmpty) ...[
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          period,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.visibility_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text('$viewCount',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // 첨부 이미지
                if (imageUrls.isNotEmpty) ...[
                  for (final url in imageUrls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                if (content.isNotEmpty)
                  Text(content,
                      style: const TextStyle(fontSize: 15, height: 1.7)),

                // 첨부 PDF
                if (pdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          pdfUrl: pdfUrl,
                          pdfFileName: pdfFileName.isEmpty
                              ? s.campaignDetailTitle
                              : pdfFileName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(
                      pdfFileName.isEmpty ? s.noticeOpenPdf : pdfFileName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ],

                // 좋아요
                const SizedBox(height: 28),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: (myUid == null || _isLiking)
                        ? null
                        : () => _toggleLike(isLiked, s),
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: isLiked ? Colors.red : Colors.grey.shade600,
                    ),
                    label: Text('${s.likeLabel}  $likeCount'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 44),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildCommentsList(myUid, s),
              ],
            ),
          );
        },
      );
  }

  Widget _buildCommentsList(String? myUid, StudentCouncilStrings s) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('campaign_comments')
          .where('postId', isEqualTo: widget.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(s.commentsLoadError);
        }
        final blockedUsers =
            Provider.of<AuthProvider>(context, listen: false).blockedUsers;
        final docs = snapshot.data?.docs ?? [];
        final comments = docs
            .map((d) => CommentModel.fromMap(d.data() as Map<String, dynamic>))
            .where((c) => !blockedUsers.contains(c.authorId))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.commentsCount(comments.length),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(s.noCommentsYet,
                      style: const TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...comments.map((c) => _buildCommentItem(c, myUid, s)),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(
      CommentModel comment, String? myUid, StudentCouncilStrings s) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isAuthor = myUid != null && comment.authorId == myUid;

    if (isAuthor) {
      // 본인 댓글: 오른쪽 정렬 (게시판 댓글과 동일한 방식)
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteComment(comment.id, s),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(dateFormat.format(comment.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          comment.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LinkifiedText(
                        text: comment.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: comment.authorProfileImageUrl != null
                  ? NetworkImage(comment.authorProfileImageUrl!)
                  : null,
              child: comment.authorProfileImageUrl == null
                  ? Text(comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                      style: const TextStyle(fontSize: 12))
                  : null,
            ),
          ],
        ),
      );
    }

    // 타인 댓글: 왼쪽 정렬
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: comment.authorProfileImageUrl != null
                ? NetworkImage(comment.authorProfileImageUrl!)
                : null,
            child: comment.authorProfileImageUrl == null
                ? Text(comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                    style: const TextStyle(fontSize: 12))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateFormat.format(comment.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const Spacer(),
                    // ··· 신고/차단 버튼
                    if (myUid != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_horiz, color: Colors.grey.shade500, size: 18),
                        onSelected: (value) {
                          if (value == 'report') {
                            _showReportDialog(
                              reporterId: myUid,
                              commentId: comment.id,
                              targetAuthorId: comment.authorId,
                              s: s,
                            );
                          } else if (value == 'block') {
                            _blockUser(comment.authorId, s);
                          }
                        },
                        itemBuilder: (context) {
                          final isBlocked = Provider.of<AuthProvider>(context, listen: false)
                              .blockedUsers
                              .contains(comment.authorId);
                          return [
                            PopupMenuItem(
                              value: 'report',
                              child: Row(children: [
                                const Icon(Icons.flag_outlined, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(s.reportMenu, style: const TextStyle(color: Colors.red, fontSize: 14)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Row(children: [
                                Icon(isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Text(isBlocked ? s.unblockUser : s.blockUser,
                                    style: const TextStyle(color: Colors.orange, fontSize: 14)),
                              ]),
                            ),
                          ];
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LinkifiedText(
                      text: comment.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(dynamic user, StudentCouncilStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isLoadingComment,
                decoration: InputDecoration(
                  hintText: s.commentHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoadingComment ? null : () => _addComment(user, s),
              icon: _isLoadingComment
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
