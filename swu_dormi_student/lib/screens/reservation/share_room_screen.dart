import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/share_room_strings.dart';
import 'share_room_chat_screen.dart';

// 나눔방은 물리적인 방이 아니라, 하루 단위로 초기화되는 4개의 가상 슬롯이다.
// 먼저 글을 올린 학생이 주제/내용을 정하고, 다른 학생은 보기만 한다.
const List<String> _kShareRoomSlots = ['A', 'B', 'C', 'D'];

class ShareRoomScreen extends StatefulWidget {
  const ShareRoomScreen({super.key});

  @override
  State<ShareRoomScreen> createState() => _ShareRoomScreenState();
}

class _ShareRoomScreenState extends State<ShareRoomScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  bool _isLoading = true;
  String? _error;
  // slot -> 오늘의 나눔방 글 (없으면 그 슬롯은 비어있음)
  Map<String, Map<String, dynamic>> _roomsBySlot = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _today => _dateFormat.format(DateTime.now());

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snap = await _firestore
          .collection('share_rooms')
          .where('date', isEqualTo: _today)
          .get();

      final bySlot = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        data['_id'] = doc.id;
        final slot = data['slot'] as String? ?? '';
        if (slot.isNotEmpty) bySlot[slot] = data;
      }

      if (!mounted) return;
      setState(() {
        _roomsBySlot = bySlot;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _createRoom(String slot) async {
    final s = ShareRoomStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);

    // 다이얼로그를 여는 데는 로그인 정보가 필요 없으므로, 네트워크 조회를 먼저 기다리게
    // 하지 않고 바로 연다 (예전엔 여기서 로그인 정보를 기다리다 네트워크가 느리면
    // 버튼을 눌러도 한참을 아무 반응 없이 멈춰있는 것처럼 보였다).
    final result = await showDialog<_CreateRoomForm>(
      context: context,
      builder: (ctx) => _CreateRoomDialog(slot: slot, s: s),
    );
    if (result == null) return;
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    var user = authProvider.currentUser;
    if (user == null) {
      // 글을 실제로 등록하는 이 시점에만 로그인 정보가 필요하다. 네트워크가 느려도
      // 무한정 기다리지 않도록 시간 제한을 둔다.
      try {
        await authProvider.refreshUserData().timeout(const Duration(seconds: 8));
      } catch (_) {
        // 시간 초과/오류는 아래 user == null 분기에서 함께 안내한다.
      }
      if (!mounted) return;
      user = authProvider.currentUser;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // 제출 직전 재확인: 동시성으로 인한 중복 생성 방지
      final recheckSnap = await _firestore
          .collection('share_rooms')
          .where('date', isEqualTo: _today)
          .where('slot', isEqualTo: slot)
          .get();
      if (recheckSnap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.slotUnavailable), backgroundColor: Colors.red),
        );
        await _load();
        return;
      }

      await _firestore.collection('share_rooms').add({
        'slot': slot,
        'date': _today,
        'topic': result.topic,
        'content': result.content,
        'maxParticipants': result.maxParticipants,
        'meetingTime': result.meetingTime,
        'location': result.location,
        'userId': user.uid,
        'userName': user.nickname ?? user.name,
        'roomNumber': user.roomNumber,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.createSuccess), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errorLabel(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelRoom(Map<String, dynamic> room) async {
    final s = ShareRoomStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.cancelConfirmTitle),
        content: Text(s.cancelConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.keep)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestore.collection('share_rooms').doc(room['_id'] as String).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cancelSuccess), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errorLabel(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ShareRoomStrings(Provider.of<LocaleProvider>(context).isEnglish);
    final authProvider = Provider.of<AuthProvider>(context);
    final myUid = authProvider.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.errorLabel(_error!)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.teal.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.todayOnlyNotice,
                                style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final slot in _kShareRoomSlots) ...[
                        _buildSlotCard(slot, _roomsBySlot[slot], myUid, s),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildSlotCard(
    String slot,
    Map<String, dynamic>? room,
    String? myUid,
    ShareRoomStrings s,
  ) {
    final label = '소모임 $slot';
    if (room == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(s.emptySlot, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _createRoom(slot),
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.createButton),
              ),
            ),
          ],
        ),
      );
    }

    final topic = room['topic'] as String? ?? '';
    final content = room['content'] as String? ?? '';
    final authorName = room['userName'] as String? ?? '';
    final maxParticipants = (room['maxParticipants'] as num?)?.toInt();
    final meetingTime = room['meetingTime'] as String? ?? '';
    final location = room['location'] as String? ?? '';
    final isMine = room['userId'] == myUid;
    final roomId = room['_id'] as String;

    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareRoomChatScreen(roomId: roomId, roomLabel: label, topic: topic),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade700)),
                  const Spacer(),
                  if (isMine)
                    TextButton(
                      onPressed: () => _cancelRoom(room),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                      child: Text(s.cancelButton, style: const TextStyle(fontSize: 12.5)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(content, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4)),
              ],
              const SizedBox(height: 10),
              _infoRow(Icons.person_outline, s.authorLabel, authorName),
              if (meetingTime.isNotEmpty) _infoRow(Icons.schedule, s.meetingTimeLabel, meetingTime),
              if (location.isNotEmpty) _infoRow(Icons.place_outlined, s.locationLabel, location),
              _infoRow(
                Icons.groups_outlined,
                s.maxParticipantsLabel,
                maxParticipants != null ? '$maxParticipants' : s.noLimit,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 14, color: Colors.teal.shade700),
                  const SizedBox(width: 4),
                  Text(
                    s.openChatHint,
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _CreateRoomForm {
  final String topic;
  final String content;
  final int? maxParticipants;
  final String meetingTime;
  final String location;

  const _CreateRoomForm({
    required this.topic,
    required this.content,
    required this.maxParticipants,
    required this.meetingTime,
    required this.location,
  });
}

class _CreateRoomDialog extends StatefulWidget {
  final String slot;
  final ShareRoomStrings s;
  const _CreateRoomDialog({required this.slot, required this.s});

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _topicCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _meetingTimeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  int _selectedCategoryIndex = 0;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _contentCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _meetingTimeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final s = widget.s;
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.topicRequired), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.pop(
      context,
      _CreateRoomForm(
        topic: topic,
        content: _contentCtrl.text.trim(),
        maxParticipants: int.tryParse(_maxParticipantsCtrl.text.trim()),
        meetingTime: _meetingTimeCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text('${s.createDialogTitle} (소모임 ${widget.slot})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplatePicker(s),
            const SizedBox(height: 14),
            TextField(
              controller: _topicCtrl,
              decoration: InputDecoration(labelText: s.topicLabel, hintText: s.topicHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              decoration: InputDecoration(labelText: s.contentLabel, hintText: s.contentHint),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meetingTimeCtrl,
              decoration: InputDecoration(labelText: s.meetingTimeLabel, hintText: s.meetingTimeHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(labelText: s.locationLabel, hintText: s.locationHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxParticipantsCtrl,
              decoration: InputDecoration(labelText: s.maxParticipantsLabel, hintText: s.maxParticipantsHint),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancelButton)),
        ElevatedButton(onPressed: _submit, child: Text(s.submitButton)),
      ],
    );
  }

  Widget _buildTemplatePicker(ShareRoomStrings s) {
    final categories = s.templateCategories;
    final selected = categories[_selectedCategoryIndex];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.quickTemplatesLabel,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
          const SizedBox(height: 2),
          Text(s.quickTemplatesHint, style: TextStyle(fontSize: 11, color: Colors.teal.shade700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < categories.length; i++)
                ChoiceChip(
                  label: Text(categories[i].label),
                  avatar: Icon(
                    categories[i].icon,
                    size: 15,
                    color: i == _selectedCategoryIndex ? Colors.white : Colors.teal.shade700,
                  ),
                  selected: i == _selectedCategoryIndex,
                  onSelected: (_) => setState(() => _selectedCategoryIndex = i),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.white,
                  selectedColor: Colors.teal.shade600,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: i == _selectedCategoryIndex ? Colors.white : Colors.teal.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: i == _selectedCategoryIndex ? Colors.teal.shade600 : Colors.teal.shade300,
                    width: 1.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.teal.shade200),
          const SizedBox(height: 8),
          Text(s.quickTemplatesExamplesLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final topic in selected.topics)
                ActionChip(
                  label: Text(topic, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _topicCtrl.text = topic),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.teal.shade200),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
