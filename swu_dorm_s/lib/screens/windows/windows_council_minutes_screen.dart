import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:swu_dormi_admin/services/storage_service.dart';

/// 사생회 회의록 관리 화면. 식단표 관리 화면과 동일하게 연도/월을 고르고
/// 주차(1~5번째주)별로 PDF 한 장씩 등록하는 슬롯 구조를 쓴다.
class WindowsCouncilMinutesScreen extends StatefulWidget {
  const WindowsCouncilMinutesScreen({super.key});

  @override
  State<WindowsCouncilMinutesScreen> createState() =>
      _WindowsCouncilMinutesScreenState();
}

class _WindowsCouncilMinutesScreenState
    extends State<WindowsCouncilMinutesScreen> {
  final _storageService = StorageService();
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int? _selectedWeekNumber;

  // 현재 월의 회의록 맵 (weekNumber -> 문서)
  Map<int, _MinuteDoc> _minutesByWeek = {};

  Stream<QuerySnapshot> _stream() {
    return FirebaseFirestore.instance
        .collection('council_minutes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // 왼쪽: 연도/월 선택 + 주차 슬롯 목록
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: FluentTheme.of(context).micaBackgroundColor,
                border: Border(
                  right: BorderSide(
                    color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).cardColor,
                      border: Border(
                        bottom: BorderSide(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '회의록 관리',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: ComboBox<int>(
                                value: _selectedYear,
                                items: List.generate(5, (index) {
                                  final year = DateTime.now().year - 2 + index;
                                  return ComboBoxItem(value: year, child: Text('$year년'));
                                }),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedYear = value;
                                      _selectedWeekNumber = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: ComboBox<int>(
                                value: _selectedMonth,
                                items: List.generate(12, (index) {
                                  final month = index + 1;
                                  return ComboBoxItem(value: month, child: Text('$month월'));
                                }),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedMonth = value;
                                      _selectedWeekNumber = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _stream(),
                      builder: (context, snapshot) {
                        _minutesByWeek = {};
                        if (snapshot.hasData) {
                          for (final doc in snapshot.data!.docs) {
                            final minute = _MinuteDoc.fromDoc(doc);
                            if (minute.year == _selectedYear && minute.month == _selectedMonth) {
                              _minutesByWeek[minute.weekNumber] = minute;
                            }
                          }
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            final weekNumber = index + 1;
                            final minute = _minutesByWeek[weekNumber];
                            final isRegistered = minute != null;
                            final isSelected = _selectedWeekNumber == weekNumber;

                            return Card(
                              backgroundColor: isSelected
                                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                                  : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onPressed: () => setState(() => _selectedWeekNumber = weekNumber),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isRegistered
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isRegistered ? FluentIcons.completed : FluentIcons.document,
                                    color: isRegistered ? Colors.green : Colors.grey[100],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $weekNumber번째주',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  isRegistered ? '등록됨' : '미등록',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRegistered ? Colors.green : Colors.grey[100],
                                  ),
                                ),
                                trailing: isRegistered
                                    ? Icon(FluentIcons.pdf, size: 16, color: Colors.red)
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
            ),
          ),
          // 오른쪽: 상세 정보 / 등록
          Expanded(
            flex: 3,
            child: _selectedWeekNumber == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.library, size: 64, color: Colors.grey[60]),
                        const SizedBox(height: 16),
                        const Text('주차를 선택해주세요', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  )
                : _buildDetailPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    final minute = _minutesByWeek[_selectedWeekNumber];
    final slotName =
        '$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $_selectedWeekNumber번째주 회의록';

    if (minute == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slotName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('아직 회의록이 등록되지 않았습니다.',
                style: TextStyle(fontSize: 14, color: Colors.grey[100])),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(FluentIcons.cloud_upload, size: 64, color: Colors.grey[60]),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _uploadPdf,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 16),
                        SizedBox(width: 8),
                        Text('PDF 파일 등록'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slotName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('등록일: ${_dateFormat.format(minute.createdAt)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[100])),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 20),
                onPressed: () => _deleteMinute(minute),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.pdf, size: 20, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    minute.pdfFileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: SfPdfViewer.network(minute.pdfUrl, key: ValueKey(minute.pdfUrl)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final selectedFile = File(result.files.single.path!);
    final selectedFileName = result.files.single.name;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) => const ContentDialog(
        title: Text('업로드 중'),
        content: SizedBox(height: 100, child: Center(child: ProgressRing())),
      ),
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfUrl =
          await _storageService.uploadNoticePdf(selectedFile, '${timestamp}_$selectedFileName');

      await FirebaseFirestore.instance.collection('council_minutes').add({
        'year': _selectedYear,
        'month': _selectedMonth,
        'weekNumber': _selectedWeekNumber,
        'pdfUrl': pdfUrl,
        'pdfFileName': selectedFileName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (successContext) => ContentDialog(
          title: const Text('완료'),
          content: const Text('회의록이 등록되었습니다.'),
          actions: [
            FilledButton(child: const Text('확인'), onPressed: () => Navigator.pop(successContext)),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (errorContext) => ContentDialog(
          title: const Text('오류'),
          content: Text('회의록 등록 중 오류가 발생했습니다:\n$e'),
          actions: [
            FilledButton(child: const Text('확인'), onPressed: () => Navigator.pop(errorContext)),
          ],
        ),
      );
    }
  }

  void _deleteMinute(_MinuteDoc minute) {
    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('회의록 삭제'),
        content: Text('「${minute.slotDisplayName}」을(를) 삭제하시겠습니까?'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance
                    .collection('council_minutes')
                    .doc(minute.id)
                    .delete();
                if (!mounted) return;
                setState(() => _selectedWeekNumber = null);
              } catch (e) {
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (errorContext) => ContentDialog(
                    title: const Text('오류'),
                    content: Text('회의록 삭제 중 오류가 발생했습니다:\n$e'),
                    actions: [
                      FilledButton(
                          child: const Text('확인'), onPressed: () => Navigator.pop(errorContext)),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MinuteDoc {
  final String id;
  final int year;
  final int month;
  final int weekNumber;
  final String pdfUrl;
  final String pdfFileName;
  final DateTime createdAt;

  _MinuteDoc({
    required this.id,
    required this.year,
    required this.month,
    required this.weekNumber,
    required this.pdfUrl,
    required this.pdfFileName,
    required this.createdAt,
  });

  String get slotDisplayName => '$year.${month.toString().padLeft(2, '0')} $weekNumber번째주 회의록';

  factory _MinuteDoc.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _MinuteDoc(
      id: doc.id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (data['month'] as num?)?.toInt() ?? DateTime.now().month,
      weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 1,
      pdfUrl: (data['pdfUrl'] ?? '').toString(),
      pdfFileName: (data['pdfFileName'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
