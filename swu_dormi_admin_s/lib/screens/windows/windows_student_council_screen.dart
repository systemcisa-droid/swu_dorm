import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_council_notice_create_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_council_minutes_screen.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// 사생회 공지 관리 화면 (사이드바 독립 메뉴).
class WindowsCouncilNoticesTabScreen extends StatelessWidget {
  const WindowsCouncilNoticesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CouncilSection(kind: _CouncilKind.notice);
  }
}

/// 사생회 캠페인 관리 화면 (사이드바 독립 메뉴).
class WindowsCouncilCampaignsTabScreen extends StatelessWidget {
  const WindowsCouncilCampaignsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CouncilSection(kind: _CouncilKind.campaign);
  }
}

/// 사생회 회의록 관리 화면 (사이드바 독립 메뉴). 식단표와 같은 연도/월/주차
/// 슬롯 구조를 쓰므로 공지/캠페인이 공유하는 목록+상세 패널 구조와는 별개다.
class WindowsCouncilMinutesTabScreen extends StatelessWidget {
  const WindowsCouncilMinutesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WindowsCouncilMinutesScreen();
  }
}

// ── 탭 종류별 설정 ────────────────────────────────────────────────
enum _CouncilKind { notice, campaign }

extension _CouncilKindInfo on _CouncilKind {
  String get collection => switch (this) {
        _CouncilKind.notice => 'council_notices',
        _CouncilKind.campaign => 'council_campaigns',
      };

  /// 목록 정렬 기준 필드. 공지는 작성일, 캠페인은 시작일 기준이다.
  String get orderByField =>
      this == _CouncilKind.notice ? 'createdAt' : 'startDate';

  String get label => switch (this) {
        _CouncilKind.notice => '공지',
        _CouncilKind.campaign => '캠페인',
      };

  IconData get icon => switch (this) {
        _CouncilKind.notice => FluentIcons.megaphone,
        _CouncilKind.campaign => FluentIcons.party_leader,
      };

  /// 기간(시작일/종료일) 입력이 필요한지 여부
  bool get hasPeriod => this == _CouncilKind.campaign;

  /// 이미지·PDF 첨부 입력이 필요한지 여부 (캠페인 홍보물)
  bool get hasAttachments => this == _CouncilKind.campaign;

  /// 공지와 동일한 전체 화면 작성 페이지(이미지·PDF 첨부, 고정)를 쓰는지 여부
  bool get usesNoticeStyleEditor => this == _CouncilKind.notice;
}

// ── 목록 + 상세 패널 ──────────────────────────────────────────────
class _CouncilSection extends StatefulWidget {
  final _CouncilKind kind;
  const _CouncilSection({required this.kind});

  @override
  State<_CouncilSection> createState() => _CouncilSectionState();
}

class _CouncilSectionState extends State<_CouncilSection> {
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  _CouncilItem? _selected;
  String _searchQuery = '';

  Stream<List<_CouncilItem>> _stream() {
    return FirebaseFirestore.instance
        .collection(widget.kind.collection)
        .orderBy(widget.kind.orderByField, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_CouncilItem.fromDoc).toList());
  }

  void _openDialog({_CouncilItem? editing}) {
    // 공지·회의록은 기숙사 공지사항과 동일한 전체 화면 작성 페이지를 쓴다
    // (이미지·PDF 첨부, 고정).
    final Future<dynamic> future = widget.kind.usesNoticeStyleEditor
        ? Navigator.push(
            context,
            FluentPageRoute(
              builder: (ctx) => WindowsCouncilNoticeCreateScreen(
                noticeId: editing?.id,
                notice: editing?.raw,
                collection: widget.kind.collection,
                kindLabel: widget.kind.label,
              ),
            ),
          )
        : showDialog(
            context: context,
            builder: (ctx) =>
                _CouncilDialog(kind: widget.kind, editing: editing),
          );
    future.then((_) {
      // 수정 후 상세 패널이 옛 데이터를 들고 있지 않도록 선택을 비운다.
      if (editing != null && _selected?.id == editing.id) {
        setState(() => _selected = null);
      }
    });
  }

  Future<void> _delete(_CouncilItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('${widget.kind.label} 삭제'),
        content: Text('「${item.title}」을(를) 삭제하시겠습니까?'),
        actions: [
          Button(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection(widget.kind.collection)
          .doc(item.id)
          .delete();
      if (_selected?.id == item.id) {
        setState(() => _selected = null);
      }
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('삭제 완료'),
                  severity: InfoBarSeverity.success,
                  action: IconButton(
                      icon: const Icon(FluentIcons.clear), onPressed: close),
                ));
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('삭제 실패'),
                  content: Text('$e'),
                  severity: InfoBarSeverity.error,
                  action: IconButton(
                      icon: const Icon(FluentIcons.clear), onPressed: close),
                ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text('사생회 ${widget.kind.label}'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: Text('${widget.kind.label} 작성'),
              onPressed: () => _openDialog(),
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextBox(
                    placeholder: '제목 검색',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                Expanded(child: _buildList()),
              ],
            ),
          ),
          const Divider(direction: Axis.vertical),
          Expanded(
            child: _selected == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.kind.icon,
                            size: 56, color: Colors.grey[80]),
                        const SizedBox(height: 16),
                        Text('${widget.kind.label}을(를) 선택하세요',
                            style: TextStyle(
                                color: Colors.grey[100], fontSize: 15)),
                      ],
                    ),
                  )
                : _buildDetail(_selected!),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<_CouncilItem>>(
      stream: _stream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        final all = snapshot.data ?? [];

        // 학생이 조회·좋아요를 누를 때마다 숫자가 바뀌므로, 열어 둔 상세 화면의 숫자도 목록과 맞춰 갱신한다.
        final selected = _selected;
        if (selected != null &&
            (widget.kind == _CouncilKind.notice ||
                widget.kind == _CouncilKind.campaign)) {
          final latest = all.where((n) => n.id == selected.id).firstOrNull;
          if (latest != null &&
              (latest.viewCount != selected.viewCount ||
                  latest.likeCount != selected.likeCount)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selected?.id == latest.id) {
                setState(() => _selected = latest);
              }
            });
          }
        }

        final filtered = _searchQuery.isEmpty
            ? all
            : all.where((n) => n.title.contains(_searchQuery)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.kind.icon, size: 48),
                const SizedBox(height: 12),
                Text('등록된 ${widget.kind.label}이(가) 없습니다.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final n = filtered[i];
            final isSelected = _selected?.id == n.id;
            final status = n.statusOf(widget.kind);
            return Card(
              backgroundColor: isSelected
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                  : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onPressed: () => setState(() => _selected = n),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.kind.icon,
                      color: Colors.purple, size: 18),
                ),
                title: Text(
                  n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _subtitleOf(n),
                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                ),
                trailing: widget.kind == _CouncilKind.notice
                    // 일반 공지 목록과 같은 형태로 조회수를 보여준다.
                    ? Text(
                        '조회 ${n.viewCount}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                      )
                    : status == null
                        ? null
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status.color,
                                  ),
                                ),
                              ),
                              // 캠페인은 학생 반응(조회수·좋아요)도 함께 보여준다.
                              if (widget.kind == _CouncilKind.campaign) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '조회 ${n.viewCount} · 좋아요 ${n.likeCount}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[80]),
                                ),
                              ],
                            ],
                          ),
              ),
            );
          },
        );
      },
    );
  }

  String _subtitleOf(_CouncilItem n) {
    if (widget.kind.hasPeriod) {
      final parts = [
        if (n.startDate != null) _dateFormat.format(n.startDate!),
        if (n.endDate != null) _dateFormat.format(n.endDate!),
      ];
      if (parts.isNotEmpty) return parts.join(' ~ ');
    }
    return '${n.authorName}  ·  ${_dateFormat.format(n.createdAt)}';
  }

  void _showImageFullscreen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
        content: Stack(
          children: [
            Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: ProgressRing());
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(FluentIcons.cancel, size: 16),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(_CouncilItem n) {
    final status = n.statusOf(widget.kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: status.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(status.label,
                      style: TextStyle(
                          color: status.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  n.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.edit, size: 14),
                    SizedBox(width: 6),
                    Text('수정')
                  ],
                ),
                onPressed: () => _openDialog(editing: n),
              ),
              const SizedBox(width: 8),
              Button(
                style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Colors.red.withValues(alpha: 0.1))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onPressed: () => _delete(n),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${n.authorName}  ·  ${DateFormat('yyyy-MM-dd HH:mm').format(n.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[100]),
              ),
              if (widget.kind == _CouncilKind.notice ||
                  widget.kind == _CouncilKind.campaign) ...[
                const SizedBox(width: 16),
                Icon(FluentIcons.view, size: 14, color: Colors.grey[100]),
                const SizedBox(width: 6),
                Text(
                  '조회 ${n.viewCount}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                ),
              ],
              if (widget.kind == _CouncilKind.campaign) ...[
                const SizedBox(width: 16),
                Icon(FluentIcons.heart, size: 14, color: Colors.grey[100]),
                const SizedBox(width: 6),
                Text(
                  '좋아요 ${n.likeCount}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                ),
              ],
            ],
          ),
          if (widget.kind.hasPeriod && n.startDate != null) ...[
            const SizedBox(height: 6),
            Text(
              '기간  ${_dateFormat.format(n.startDate!)}'
              '${n.endDate != null ? ' ~ ${_dateFormat.format(n.endDate!)}' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey[100]),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (n.content.isNotEmpty)
            Text(n.content,
                style: const TextStyle(fontSize: 15, height: 1.7)),
          if (n.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '첨부 이미지',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Column(
              children: n.imageUrls.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _showImageFullscreen(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const ProgressRing(),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[20],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(FluentIcons.photo2,
                              size: 40, color: Colors.grey[80]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (n.pdfUrl != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(FluentIcons.document, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  n.pdfFileName ?? 'PDF 파일',
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 600,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[30]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SfPdfViewer.network(
                  n.pdfUrl!,
                  key: ValueKey(n.pdfUrl),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 진행 상태 ─────────────────────────────────────────────────────
class _Status {
  final String label;
  final Color color;
  const _Status(this.label, this.color);
}

// ── 데이터 모델 ───────────────────────────────────────────────────
class _CouncilItem {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  /// 조회수. 공지·캠페인만 학생앱에서 계정당 1회씩 집계한다 (viewCount/viewedUsers).
  final int viewCount;
  /// 좋아요 수. 캠페인만 학생앱에서 집계한다 (likes/likeCount).
  final int likeCount;
  final List<String> imageUrls;
  final String? pdfUrl;
  final String? pdfFileName;
  /// 원본 문서 데이터 (공지 수정 화면에 그대로 넘긴다)
  final Map<String, dynamic> raw;

  _CouncilItem({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.viewCount = 0,
    this.likeCount = 0,
    this.imageUrls = const [],
    this.pdfUrl,
    this.pdfFileName,
    this.raw = const {},
  });

  factory _CouncilItem.fromDoc(DocumentSnapshot doc) {
    // 빈 문서는 data() 가 null 을 반환할 수 있다.
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return _CouncilItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      authorName: (data['authorName'] ?? '관리자').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      imageUrls: (data['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      pdfUrl: (data['pdfUrl'] as String?)?.isNotEmpty == true
          ? data['pdfUrl'] as String
          : null,
      pdfFileName: data['pdfFileName'] as String?,
      raw: data,
    );
  }

  /// 기간을 가진 항목(캠페인)만 진행 상태를 갖는다.
  /// 학생앱의 색상·판정 기준과 동일하게 맞춘다.
  _Status? statusOf(_CouncilKind kind) {
    if (!kind.hasPeriod) return null;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) {
      return const _Status('예정', Color(0xFFFF9800));
    }
    if (endDate != null && now.isAfter(endDate!)) {
      return const _Status('종료', Color(0xFF757575));
    }
    return const _Status('진행중', Color(0xFF009688));
  }
}

// ── 작성/수정 다이얼로그 ──────────────────────────────────────────
class _CouncilDialog extends StatefulWidget {
  final _CouncilKind kind;
  final _CouncilItem? editing;
  const _CouncilDialog({required this.kind, this.editing});

  @override
  State<_CouncilDialog> createState() => _CouncilDialogState();
}

class _CouncilDialogState extends State<_CouncilDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  final _auth = AuthService();
  final _storage = StorageService();

  // 캠페인 홍보물 첨부 (공지 작성 화면과 동일한 스키마: imageUrls / pdfUrl / pdfFileName)
  final List<File> _selectedImages = []; // 새로 추가할 이미지 파일
  List<String> _existingImageUrls = []; // 기존 이미지 URL (수정 모드)
  File? _selectedPdf; // 새로 선택한 PDF 파일
  String? _selectedPdfName;
  String? _existingPdfUrl; // 기존 PDF URL (수정 모드)
  String? _existingPdfFileName; // 기존 PDF 파일명 (수정 모드)

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _existingImageUrls = (e.raw['imageUrls'] as List?)
              ?.map((v) => v.toString())
              .where((v) => v.isNotEmpty)
              .toList() ??
          [];
      final pdfUrl = (e.raw['pdfUrl'] ?? '').toString();
      if (pdfUrl.isNotEmpty) {
        _existingPdfUrl = pdfUrl;
        _existingPdfFileName = (e.raw['pdfFileName'] ?? '').toString();
      }
    }
  }

  /// 시(10~23시)와 분(15분 단위)을 ComboBox로 고르게 한다.
  /// fluent_ui TimePicker의 끝없이 도는 휠 대신 끝이 있는 목록을 쓰고,
  /// 09시 이전 시간은 선택지에서 아예 제외한다.
  Widget _buildTimeCombo(DateTime? value, ValueChanged<DateTime> onPick) {
    return Row(
      children: [
        Expanded(
          child: ComboBox<int>(
            value: value?.hour,
            placeholder: const Text('시'),
            isExpanded: true,
            items: [
              for (int h = 10; h <= 23; h++)
                ComboBoxItem(value: h, child: Text('$h시')),
            ],
            onChanged: (h) {
              if (h == null) return;
              final base = value ?? DateTime.now();
              onPick(DateTime(
                  base.year, base.month, base.day, h, value?.minute ?? 0));
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ComboBox<int>(
            value: value?.minute,
            placeholder: const Text('분'),
            isExpanded: true,
            items: const [
              ComboBoxItem(value: 0, child: Text('00분')),
              ComboBoxItem(value: 15, child: Text('15분')),
              ComboBoxItem(value: 30, child: Text('30분')),
              ComboBoxItem(value: 45, child: Text('45분')),
            ],
            onChanged: (m) {
              if (m == null) return;
              final base = value ?? DateTime.now();
              onPick(DateTime(
                  base.year, base.month, base.day, value?.hour ?? 10, m));
            },
          ),
        ),
      ],
    );
  }

  /// 캠페인 홍보 이미지를 여러 장 고른다.
  Future<void> _pickCampaignImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path != null) _selectedImages.add(File(file.path!));
      }
    });
  }

  /// 캠페인 홍보 PDF 를 고른다.
  Future<void> _pickCampaignPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _selectedPdf = File(path);
      _selectedPdfName = result!.files.single.name;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 처리 중 재진입(중복 등록) 방지
    if (_isLoading) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('입력 오류'),
                content: const Text('제목을 입력해주세요.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }
    if (widget.kind.hasPeriod &&
        _startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('입력 오류'),
                content: const Text('종료일이 시작일보다 빠릅니다.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }
    if (widget.kind.hasPeriod &&
        _endDate != null &&
        _endDate!.hour == 0 &&
        _endDate!.minute == 0) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('입력 오류'),
                content: const Text('종료일의 마감 시각을 선택해주세요.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      final data = <String, dynamic>{
        'title': title,
        'content': content,
        'authorId': user?.uid ?? '',
        'authorName': user?.email?.split('@').first ?? '관리자',
      };

      if (widget.kind.hasPeriod) {
        data['startDate'] =
            _startDate == null ? null : Timestamp.fromDate(_startDate!);
        data['endDate'] =
            _endDate == null ? null : Timestamp.fromDate(_endDate!);
      }
      if (widget.kind.hasAttachments) {
        final docPrefix = 'council_campaign_${DateTime.now().millisecondsSinceEpoch}';

        // 새 이미지 업로드
        final imageUrls = List<String>.from(_existingImageUrls);
        for (int i = 0; i < _selectedImages.length; i++) {
          final fileName = '${docPrefix}_img_$i.jpg';
          imageUrls.add(
              await _storage.uploadNoticeImage(_selectedImages[i], fileName));
        }
        data['imageUrls'] = imageUrls;

        // PDF 처리
        String? pdfUrl = _existingPdfUrl;
        String? pdfFileName = _existingPdfFileName;
        if (_selectedPdf != null && _selectedPdfName != null) {
          pdfUrl = await _storage.uploadNoticePdf(
              _selectedPdf!, '${docPrefix}_$_selectedPdfName');
          pdfFileName = _selectedPdfName;
        }
        data['pdfUrl'] = pdfUrl;
        data['pdfFileName'] = pdfFileName;
      }

      final col =
          FirebaseFirestore.instance.collection(widget.kind.collection);
      if (widget.editing != null) {
        await col.doc(widget.editing!.id).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      }

      if (!mounted) return;
      Navigator.pop(context);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: Text(widget.editing != null ? '수정 완료' : '등록 완료'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('저장 실패'),
                content: Text('$e'),
                severity: InfoBarSeverity.error,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  /// 캠페인 홍보물 첨부 섹션 (이미지 여러 장 + PDF 1개)
  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Button(
              onPressed: _isLoading ? null : _pickCampaignImages,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.photo2, size: 14),
                  SizedBox(width: 6),
                  Text('이미지 추가'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Button(
              onPressed: _isLoading ? null : _pickCampaignPdf,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.pdf, size: 14),
                  SizedBox(width: 6),
                  Text('PDF 추가'),
                ],
              ),
            ),
          ],
        ),
        if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._existingImageUrls.asMap().entries.map((entry) =>
                  _buildAttachmentThumb(
                    image: NetworkImage(entry.value),
                    onRemove: () => setState(
                        () => _existingImageUrls.removeAt(entry.key)),
                  )),
              ..._selectedImages.asMap().entries.map((entry) =>
                  _buildAttachmentThumb(
                    image: FileImage(entry.value),
                    onRemove: () =>
                        setState(() => _selectedImages.removeAt(entry.key)),
                  )),
            ],
          ),
        ],
        if (_existingPdfUrl != null && _selectedPdf == null) ...[
          const SizedBox(height: 10),
          _buildAttachmentPdfRow(
            _existingPdfFileName?.isNotEmpty == true
                ? _existingPdfFileName!
                : 'PDF 첨부됨',
            onRemove: () => setState(() {
              _existingPdfUrl = null;
              _existingPdfFileName = null;
            }),
          ),
        ],
        if (_selectedPdf != null) ...[
          const SizedBox(height: 10),
          _buildAttachmentPdfRow(
            _selectedPdfName ?? 'PDF',
            onRemove: () => setState(() {
              _selectedPdf = null;
              _selectedPdfName = null;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentThumb(
      {required ImageProvider image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[60], width: 1),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(3),
              decoration:
                  BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child:
                  const Icon(FluentIcons.clear, size: 10, color: Colors.white),
            ),
            onPressed: _isLoading ? null : onRemove,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPdfRow(String fileName,
      {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[60], width: 1),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.pdf, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(FluentIcons.clear, size: 11),
            onPressed: _isLoading ? null : onRemove,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 620),
      title: Text(
          '사생회 ${kind.label} ${widget.editing != null ? '수정' : '작성'}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            InfoLabel(
              label: '제목',
              child: TextBox(
                controller: _titleCtrl,
                placeholder: '제목을 입력하세요',
              ),
            ),
            const SizedBox(height: 14),
            if (kind.hasPeriod) ...[
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: '시작일',
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DatePicker(
                              selected: _startDate,
                              onChanged: (d) => setState(() {
                                final t = _startDate;
                                _startDate = DateTime(d.year, d.month, d.day,
                                    t?.hour ?? 10, t?.minute ?? 0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: _buildTimeCombo(
                              _startDate,
                              (dt) => setState(() => _startDate = dt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: '종료일',
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DatePicker(
                              selected: _endDate,
                              onChanged: (d) => setState(() {
                                final t = _endDate;
                                // 마감 시각은 직접 선택한 값만 쓴다. 날짜만 바뀐
                                // 경우 기존에 고른 시간이 있으면 유지하고, 없으면
                                // 00:00으로 두어 아래 시간 선택에서 직접 고르게 한다.
                                _endDate = DateTime(
                                    d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: _buildTimeCombo(
                              _endDate,
                              (dt) => setState(() => _endDate = dt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (kind.hasAttachments) ...[
              InfoLabel(
                label: '첨부 파일',
                child: _buildAttachmentsSection(),
              ),
              const SizedBox(height: 14),
            ],
            InfoLabel(
              label: '내용',
              child: TextBox(
                controller: _contentCtrl,
                placeholder: '내용을 입력하세요',
                maxLines: 10,
                minLines: 6,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : Text(widget.editing != null ? '수정' : '등록'),
        ),
      ],
    );
  }
}

