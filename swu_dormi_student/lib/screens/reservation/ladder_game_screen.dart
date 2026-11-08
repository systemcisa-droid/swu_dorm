import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/ladder_strings.dart';

/// 사다리타기. 서버 저장 없이 그 자리에서 무작위로 뽑는 가벼운 유틸리티라
/// Firestore를 쓰지 않는다.
const int _kMinParticipants = 2;
const int _kMaxParticipants = 10;
const int _kInitialRungLevels = 10;
// 리셋을 누를 때마다 사다리 가로줄 단수가 하나씩 늘어나는데, 너무 빽빽해지지 않도록 상한을 둔다.
const int _kMaxRungLevels = 30;

// 처음 화면을 열었을 때 바로 체험해볼 수 있도록 넣어두는 기본값.
const List<String> _kDefaultNames = ['슈리', '윈디', '유시', '슈니'];
const List<String> _kDefaultResults = ['패스', '패스', '패스', '꽝'];

const List<Color> _kPathPalette = [
  Colors.deepOrange,
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.pink,
  Colors.brown,
  Colors.cyan,
  Colors.amber,
  Colors.indigo,
  Colors.teal,
];

class LadderGameScreen extends StatefulWidget {
  const LadderGameScreen({super.key});

  @override
  State<LadderGameScreen> createState() => _LadderGameScreenState();
}

class _LadderGameScreenState extends State<LadderGameScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _resultCtrls = [];

  bool _started = false;
  int _rowCount = _kInitialRungLevels;
  List<List<bool>> _rungs = [];
  // start participant index -> logical path points (dx=column, dy=row), both in logical units.
  List<List<Offset>> _allPaths = [];
  final Map<int, Color> _pathColors = {};
  // 참가자별로 경로를 따라 내려가는 애니메이션 진행도(0~1)를 관리한다.
  final Map<int, AnimationController> _controllers = {};
  final Map<int, double> _progress = {};
  // 애니메이션이 끝까지 도달한(=결과가 실제로 공개된) 참가자.
  final Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _kDefaultNames.length; i++) {
      _nameCtrls.add(TextEditingController(text: _kDefaultNames[i]));
      _resultCtrls.add(TextEditingController(text: _kDefaultResults[i]));
    }
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _resultCtrls) {
      c.dispose();
    }
    _disposeAnimations();
    super.dispose();
  }

  void _disposeAnimations() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _progress.clear();
    _completed.clear();
  }

  void _addRow() {
    if (_nameCtrls.length >= _kMaxParticipants) {
      final s = LadderStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.maxParticipantsReached)));
      return;
    }
    setState(() {
      _nameCtrls.add(TextEditingController());
      _resultCtrls.add(TextEditingController());
    });
  }

  void _removeRow(int index) {
    if (_nameCtrls.length <= _kMinParticipants) return;
    setState(() {
      _nameCtrls.removeAt(index).dispose();
      _resultCtrls.removeAt(index).dispose();
    });
  }

  void _startLadder() {
    final s = LadderStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final names = _nameCtrls.map((c) => c.text.trim()).toList();
    final results = _resultCtrls.map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty) || results.any((r) => r.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.emptyNameError)));
      return;
    }

    _rowCount = _kInitialRungLevels;
    _generateLadder();
    setState(() => _started = true);
  }

  /// "리셋" 버튼: 이름 입력 화면으로 돌아가지 않고, 같은 참가자/결과로 사다리만
  /// 새로 섞어서 다시 그린다. 누를 때마다 가로줄 단수를 하나씩 늘려 매번 조금씩
  /// 더 복잡한 사다리가 되게 한다.
  void _resetLadder() {
    if (_rowCount < _kMaxRungLevels) _rowCount += 1;
    _generateLadder();
  }

  /// 현재 _rowCount 기준으로 가로줄을 무작위로 새로 배치하고, 참가자별 경로를 다시 계산한다.
  void _generateLadder() {
    final n = _nameCtrls.length;
    final rand = Random();
    final rungs = List.generate(_rowCount, (_) => List<bool>.filled(n - 1, false));
    for (int r = 0; r < _rowCount; r++) {
      int col = 0;
      while (col < n - 1) {
        if (rand.nextDouble() < 0.45) {
          rungs[r][col] = true;
          col += 2; // 같은 줄에서 인접한 가로줄끼리 겹치지 않게 한 칸 건너뛴다.
        } else {
          col += 1;
        }
      }
    }

    final paths = <List<Offset>>[];
    for (int start = 0; start < n; start++) {
      paths.add(_tracePath(start, rungs, n));
    }

    _disposeAnimations();
    setState(() {
      _rungs = rungs;
      _allPaths = paths;
      _pathColors.clear();
    });
  }

  /// 참가자 [start]의 경로를 (열, 행) 논리 좌표의 꺾은선으로 계산한다.
  List<Offset> _tracePath(int start, List<List<bool>> rungs, int n) {
    final points = <Offset>[Offset(start.toDouble(), 0)];
    double col = start.toDouble();
    for (int r = 0; r < _rowCount; r++) {
      final y = (r + 1).toDouble();
      final ci = col.round();
      if (ci > 0 && rungs[r][ci - 1]) {
        points.add(Offset(col, y));
        col = (ci - 1).toDouble();
        points.add(Offset(col, y));
      } else if (ci < n - 1 && rungs[r][ci]) {
        points.add(Offset(col, y));
        col = (ci + 1).toDouble();
        points.add(Offset(col, y));
      } else {
        points.add(Offset(col, y));
      }
    }
    points.add(Offset(col, (_rowCount + 1).toDouble()));
    return points;
  }

  /// 참가자 [index]의 경로를 위에서부터 한 칸씩 내려가는 애니메이션으로 공개한다.
  void _revealOne(int index) {
    if (_controllers.containsKey(index)) return;
    _pathColors[index] = _kPathPalette[index % _kPathPalette.length];
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 220 * _rowCount),
    );
    controller.addListener(() {
      setState(() => _progress[index] = controller.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _completed.add(index));
      }
    });
    setState(() {
      _controllers[index] = controller;
      _progress[index] = 0;
    });
    controller.forward();
  }

  /// 남은 참가자를 전부 동시에 공개한다 ("일괄 결과 보기" 버튼). 이름을 하나씩 눌러
  /// 직접 공개하는 것은 _buildLabelRow의 onTap(_revealOne)으로 이미 가능하다.
  void _revealAll() {
    for (int i = 0; i < _allPaths.length; i++) {
      if (_controllers.containsKey(i)) continue;
      _revealOne(i);
    }
  }

  bool get _allRevealed => _controllers.length >= _allPaths.length && _allPaths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = LadderStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: SafeArea(
        child: _started ? _buildLadderView(s) : _buildEditView(s),
      ),
    );
  }

  Widget _buildEditView(LadderStrings s) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _nameCtrls.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrls[i],
                        decoration: InputDecoration(
                          labelText: '${s.participantLabel} ${i + 1}',
                          hintText: s.nameHint(i),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _resultCtrls[i],
                        decoration: InputDecoration(
                          labelText: s.resultLabel,
                          hintText: s.resultHint(i),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      color: Colors.red,
                      onPressed: _nameCtrls.length > _kMinParticipants ? () => _removeRow(i) : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.addRow),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startLadder,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(s.startButton),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLadderView(LadderStrings s) {
    final n = _nameCtrls.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(s.tapToRevealHint,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              ),
              TextButton(onPressed: _resetLadder, child: Text(s.resetButton)),
            ],
          ),
        ),
        _buildLabelRow(n, (i) => _nameCtrls[i].text, onTap: _revealOne, isTop: true),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _LadderPainter(
                    n: n,
                    rowCount: _rowCount,
                    rungs: _rungs,
                    animatedPaths: {
                      for (final i in _controllers.keys) i: _allPaths[i],
                    },
                    progress: _progress,
                    pathColors: _pathColors,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildLabelRow(n, (i) => _resultCtrls[i].text, isTop: false),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _allRevealed ? null : _revealAll,
              child: Text(s.revealAllButton),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelRow(int n, String Function(int) textOf, {void Function(int)? onTap, required bool isTop}) {
    // 참가자(위)는 눌러서 결과를 확인하고, 결과(아래)는 해당 참가자의 선이 다 내려와야(=완료) 같은 색으로 강조한다.
    int? revealedForResultIndex(int resultIndex) {
      for (final i in _completed) {
        if (_allPaths[i].last.dx.round() == resultIndex) return i;
      }
      return null;
    }

    return Row(
      children: [
        for (int i = 0; i < n; i++)
          Expanded(
            child: GestureDetector(
              onTap: onTap != null ? () => onTap(i) : null,
              child: Builder(builder: (context) {
                final revealedBy = isTop ? (_controllers.containsKey(i) ? i : null) : revealedForResultIndex(i);
                final color = revealedBy != null ? _pathColors[revealedBy] : null;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: color?.withValues(alpha: 0.12) ?? Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color ?? Colors.grey.shade300),
                  ),
                  child: Text(
                    textOf(i),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.black87,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _LadderPainter extends CustomPainter {
  final int n;
  final int rowCount;
  final List<List<bool>> rungs;
  /// 현재 애니메이션 중이거나 완료된 참가자의 전체 경로.
  final Map<int, List<Offset>> animatedPaths;
  /// 참가자별 진행도(0~1). 1이면 끝까지 그려진 상태.
  final Map<int, double> progress;
  final Map<int, Color> pathColors;

  _LadderPainter({
    required this.n,
    required this.rowCount,
    required this.rungs,
    required this.animatedPaths,
    required this.progress,
    required this.pathColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (n < 2 || rungs.isEmpty) return;
    final colWidth = size.width / n;
    final rowHeight = size.height / (rowCount + 1);
    double px(double col) => (col + 0.5) * colWidth;
    double py(double row) => row * rowHeight;

    final basePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    for (int c = 0; c < n; c++) {
      canvas.drawLine(
        Offset(px(c.toDouble()), 0),
        Offset(px(c.toDouble()), size.height),
        basePaint,
      );
    }
    for (int r = 0; r < rowCount; r++) {
      for (int c = 0; c < n - 1; c++) {
        if (rungs[r][c]) {
          canvas.drawLine(
            Offset(px(c.toDouble()), py((r + 1).toDouble())),
            Offset(px((c + 1).toDouble()), py((r + 1).toDouble())),
            basePaint,
          );
        }
      }
    }

    for (final entry in animatedPaths.entries) {
      final pts = entry.value;
      final totalSegments = pts.length - 1;
      if (totalSegments <= 0) continue;
      final t = (progress[entry.key] ?? 0.0).clamp(0.0, 1.0);
      final color = pathColors[entry.key] ?? Colors.deepOrange;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final exactPos = t * totalSegments;
      final fullCount = exactPos.floor().clamp(0, totalSegments);
      final frac = exactPos - fullCount;

      for (int i = 0; i < fullCount; i++) {
        canvas.drawLine(
          Offset(px(pts[i].dx), py(pts[i].dy)),
          Offset(px(pts[i + 1].dx), py(pts[i + 1].dy)),
          paint,
        );
      }
      if (fullCount < totalSegments && frac > 0) {
        final a = pts[fullCount];
        final b = pts[fullCount + 1];
        final mid = Offset(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac);
        canvas.drawLine(
          Offset(px(a.dx), py(a.dy)),
          Offset(px(mid.dx), py(mid.dy)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LadderPainter oldDelegate) {
    return true;
  }
}
