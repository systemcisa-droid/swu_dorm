import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/share_room_strings.dart';
import '../message/chat_media.dart';
import '../message/chat_upload.dart';
import '../message/swipe_to_reply.dart';

/// 나눔방 글에 딸린 채팅방. 그 나눔방 글(share_rooms/{roomId}) 아래 messages
/// 서브컬렉션에 메시지를 쌓는다. 나눔방이 취소/초기화되면 채팅도 함께 사라진다.
/// 층장단톡방과 동일한 수준으로 사진/영상 첨부, 답장, 이모티콘 반응, 수정/삭제를 지원한다.
class ShareRoomChatScreen extends StatefulWidget {
  final String roomId;
  final String roomLabel;
  final String topic;

  const ShareRoomChatScreen({
    super.key,
    required this.roomId,
    required this.roomLabel,
    required this.topic,
  });

  @override
  State<ShareRoomChatScreen> createState() => _ShareRoomChatScreenState();
}

class _ShareRoomChatScreenState extends State<ShareRoomChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sendingNotifier = ValueNotifier<bool>(false);
  /// 첨부 업로드 진행 상태 (압축/업로드 중 입력창에 표시)
  final _uploadingNotifier = ValueNotifier<String?>(null);
  int _prevDocCount = 0;

  /// 답장 대상으로 지정된 메시지 (스와이프로 선택)
  final ValueNotifier<Map<String, dynamic>?> _replyTargetNotifier =
      ValueNotifier(null);

  ShareRoomStrings get _s =>
      ShareRoomStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);

  CollectionReference<Map<String, dynamic>> get _messagesRef => _firestore
      .collection('share_rooms')
      .doc(widget.roomId)
      .collection('messages');

  @override
  void dispose() {
    ChatUpload.cancelCompression();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sendingNotifier.dispose();
    _uploadingNotifier.dispose();
    _replyTargetNotifier.dispose();
    super.dispose();
  }

  /// 첨부(사진/영상) 선택 → 압축 → 업로드 → 메시지 전송
  Future<void> _sendMedia(dynamic user, {required ImageSource source, required bool isVideo}) async {
    if (_uploadingNotifier.value != null) return;
    final s = _s;

    try {
      final picked = isVideo
          ? await ChatUpload.pickVideo(source)
          : await ChatUpload.pickImage(source);
      if (picked == null) return;

      File file = picked;
      if (isVideo) {
        _uploadingNotifier.value = s.compressingVideo;
        file = await ChatUpload.compressVideo(picked);
      }

      if (await file.length() > ChatUpload.maxUploadBytes) {
        _uploadingNotifier.value = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.fileTooLarge)));
        }
        return;
      }

      _uploadingNotifier.value = isVideo ? s.uploadingVideo : s.uploadingImage;
      final url = await ChatUpload.upload(
        file: file,
        roomId: widget.roomId,
        isVideo: isVideo,
        collection: 'share_rooms',
      );

      final replyTo = _replyTargetNotifier.value;

      await _messagesRef.add({
        'text': '',
        'mediaUrl': url,
        'mediaType': isVideo ? 'video' : 'image',
        'senderId': user.uid,
        'senderName': user.nickname ?? user.name,
        'createdAt': FieldValue.serverTimestamp(),
        if (replyTo != null) 'replyTo': replyTo,
      });

      _clearReplyTarget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.sendError(e))));
      }
    } finally {
      _uploadingNotifier.value = null;
    }
  }

  void _showAttachSheet(dynamic user) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: Text(_s.pickImage),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(user, source: ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.teal),
              title: Text(_s.pickVideo),
              subtitle: Text(_s.pickVideoHint, style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(user, source: ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyMessageText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_s.messageCopied), duration: const Duration(seconds: 1)),
    );
  }

  static const _kReactionEmojis = ['❤️', '👍', '✅', '😂', '😮', '😢'];

  /// 카카오톡처럼 메시지를 길게 누르면 그 자리에 이모티콘 반응·복사·수정·삭제 메뉴를 띄운다.
  /// 답장은 메뉴가 아니라 메시지를 좌측으로 스와이프해서 보낸다.
  Future<void> _showMessageMenu(
    Offset globalPosition,
    String text, {
    VoidCallback? onDelete,
    ValueChanged<String>? onReact,
    VoidCallback? onEdit,
  }) async {
    HapticFeedback.selectionClick();
    final s = _s;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: Colors.white,
      items: [
        if (onReact != null)
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _kReactionEmojis
                    .map((emoji) => GestureDetector(
                          onTap: () => Navigator.of(context).pop('react:$emoji'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        if (text.isNotEmpty) PopupMenuItem(value: 'copy', child: Text(s.menuCopy)),
        if (text.isNotEmpty) PopupMenuItem(value: 'select_copy', child: Text(s.menuSelectCopy)),
        if (onEdit != null) PopupMenuItem(value: 'edit', child: Text(s.menuEdit)),
        if (onDelete != null)
          PopupMenuItem(value: 'delete', child: Text(s.menuDelete, style: const TextStyle(color: Colors.red))),
      ],
    );
    if (selected == null) return;
    if (selected.startsWith('react:')) {
      onReact?.call(selected.substring(6));
      return;
    }
    switch (selected) {
      case 'copy':
        _copyMessageText(text);
        break;
      case 'select_copy':
        _showSelectableText(text);
        break;
      case 'edit':
        onEdit?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }

  void _showSelectableText(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_s.close)),
        ],
      ),
    );
  }

  Future<void> _editMessage(DocumentReference<Object?> ref, String currentText) async {
    final s = _s;
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.editMessageTitle),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(s.save)),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == currentText) return;
    try {
      await ref.update({'text': newText, 'edited': true, 'editedAt': Timestamp.now()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.editError(e))));
      }
    }
  }

  Widget _buildReactionsRow(Map<String, dynamic> reactions, ValueChanged<String>? onReact) {
    final myUid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    final counts = <String, int>{};
    for (final v in reactions.values) {
      final emoji = v as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        final mine = myUid != null && reactions[myUid] == entry.key;
        return GestureDetector(
          onTap: onReact == null ? null : () => onReact(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: mine ? Colors.teal.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mine ? Colors.teal.shade300 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 12)),
                if (entry.value > 1) ...[
                  const SizedBox(width: 3),
                  Text('${entry.value}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 같은 이모티콘을 다시 누르면 반응을 취소하고, 다른 이모티콘을 누르면 교체한다(1인당 1개).
  Future<void> _toggleReaction(DocumentReference<Object?> ref, String emoji) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();
    try {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      final current = (data?['reactions'] as Map?)?[user.uid] as String?;
      await ref.update({'reactions.${user.uid}': current == emoji ? FieldValue.delete() : emoji});
    } catch (_) {}
  }

  Future<void> _confirmDeleteMessage(DocumentReference<Object?> ref) async {
    final s = _s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteMessageTitle),
        content: Text(s.deleteMessageConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.menuDelete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deleteError(e))));
      }
    }
  }

  Future<void> _send(dynamic user) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sendingNotifier.value) return;

    _sendingNotifier.value = true;
    final s = _s;
    try {
      final replyTo = _replyTargetNotifier.value;
      await _messagesRef.add({
        'text': text,
        'senderId': user.uid,
        'senderName': user.nickname ?? user.name,
        'createdAt': FieldValue.serverTimestamp(),
        if (replyTo != null) 'replyTo': replyTo,
      });
      _msgCtrl.clear();
      _clearReplyTarget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.sendError(e))));
      }
    } finally {
      _sendingNotifier.value = false;
    }
  }

  /// 메시지를 좌측으로 스와이프하면 답장 대상으로 지정한다.
  void _setReplyTarget(Map<String, dynamic> data) {
    HapticFeedback.selectionClick();
    _replyTargetNotifier.value = {
      'senderName': data['senderName'] as String? ?? '',
      'text': data['text'] as String? ?? '',
      'mediaType': data['mediaType'] as String?,
    };
  }

  void _clearReplyTarget() => _replyTargetNotifier.value = null;

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final myUid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.roomLabel, style: const TextStyle(fontSize: 15)),
            Text(widget.topic,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(s, myUid)),
          if (user != null) _buildInputBar(s, user),
        ],
      ),
    );
  }

  Widget _buildMessageList(ShareRoomStrings s, String? myUid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.noMessagesYet, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ),
          );
        }

        // 새 메시지가 오면 맨 아래(reverse 기준 offset 0)로 이동한다.
        if (docs.length > _prevDocCount) {
          final isFirstLoad = _prevDocCount == 0;
          _prevDocCount = docs.length;
          if (!isFirstLoad) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollCtrl.hasClients) return;
              _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
            });
          }
        }

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, reverseIndex) {
            final index = docs.length - 1 - reverseIndex;
            final data = docs[index].data();
            final isMine = data['senderId'] == myUid;
            final senderName = data['senderName'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final mediaUrl = data['mediaUrl'] as String?;
            final mediaType = data['mediaType'] as String?;
            final replyTo = data['replyTo'] as Map<String, dynamic>?;
            final reactions = (data['reactions'] as Map?)?.cast<String, dynamic>();
            final edited = data['edited'] == true;
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

            String? dateDivider;
            if (index == 0 && ts != null) {
              dateDivider = DateFormat(s.dateFormat, s.dateLocale).format(ts.toDate());
            } else if (index > 0 && ts != null) {
              final prevTs = docs[index - 1].data()['createdAt'] as Timestamp?;
              if (prevTs != null) {
                final prev = prevTs.toDate();
                final curr = ts.toDate();
                if (prev.day != curr.day || prev.month != curr.month || prev.year != curr.year) {
                  dateDivider = DateFormat(s.dateFormat, s.dateLocale).format(curr);
                }
              }
            }

            final senderId = data['senderId'] as String?;
            final prevData = index > 0 ? docs[index - 1].data() : null;
            bool sameMinute(Timestamp? a, Timestamp? b) {
              if (a == null || b == null) return false;
              final x = a.toDate();
              final y = b.toDate();
              return x.year == y.year && x.month == y.month && x.day == y.day && x.hour == y.hour && x.minute == y.minute;
            }

            final isFirstOfGroup = dateDivider != null ||
                prevData == null ||
                (prevData['senderId'] as String?) != senderId ||
                !sameMinute(prevData['createdAt'] as Timestamp?, ts);

            final nextData = index < docs.length - 1 ? docs[index + 1].data() : null;
            final isLastOfGroup = nextData == null ||
                (nextData['senderId'] as String?) != senderId ||
                !sameMinute(nextData['createdAt'] as Timestamp?, ts);

            return Column(
              children: [
                if (dateDivider != null) _buildDateDivider(dateDivider),
                _buildBubble(
                  s,
                  isMine: isMine,
                  senderName: senderName,
                  text: text,
                  time: isLastOfGroup ? time : '',
                  isFirstOfGroup: isFirstOfGroup,
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                  replyTo: replyTo,
                  reactions: reactions,
                  edited: edited,
                  onSwipeReply: () => _setReplyTarget(data),
                  onDelete: isMine ? () => _confirmDeleteMessage(docs[index].reference) : null,
                  onReact: (emoji) => _toggleReaction(docs[index].reference, emoji),
                  onEdit: isMine && text.isNotEmpty ? () => _editMessage(docs[index].reference, text) : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildBubble(
    ShareRoomStrings s, {
    required bool isMine,
    required String senderName,
    required String text,
    required String time,
    bool isFirstOfGroup = true,
    String? mediaUrl,
    String? mediaType,
    Map<String, dynamic>? replyTo,
    Map<String, dynamic>? reactions,
    bool edited = false,
    VoidCallback? onSwipeReply,
    VoidCallback? onDelete,
    ValueChanged<String>? onReact,
    VoidCallback? onEdit,
  }) {
    final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
    final bubbleColor = isMine ? Colors.teal.shade500 : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;

    return SwipeToReply(
      onReply: onSwipeReply,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2, top: isFirstOfGroup ? 8 : 0),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine && isFirstOfGroup)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(senderName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMine) ...[
                      Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(width: 6),
                    ],
                    Column(
                      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                          child: hasMedia
                              ? ChatMediaBubble(
                                  url: mediaUrl,
                                  isVideo: mediaType == 'video',
                                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                                )
                              : GestureDetector(
                                  onLongPressStart: (details) => _showMessageMenu(
                                    details.globalPosition,
                                    text,
                                    onDelete: onDelete,
                                    onReact: onReact,
                                    onEdit: onEdit,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: bubbleColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                                        bottomRight: Radius.circular(isMine ? 4 : 16),
                                      ),
                                      border: isMine ? null : Border.all(color: Colors.grey.shade200),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (replyTo != null) ...[
                                          _buildReplyQuote(s, replyTo, isMine),
                                          const SizedBox(height: 6),
                                        ],
                                        Text.rich(
                                          TextSpan(
                                            text: text,
                                            style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
                                            children: edited
                                                ? [
                                                    TextSpan(
                                                      text: ' ${s.editedLabel}',
                                                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.65)),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        if (reactions != null && reactions.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 3), child: _buildReactionsRow(reactions, onReact)),
                      ],
                    ),
                    if (!isMine) ...[
                      const SizedBox(width: 6),
                      Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyQuote(ShareRoomStrings s, Map<String, dynamic> replyTo, bool isMine) {
    final name = replyTo['senderName'] as String? ?? '';
    final mediaType = replyTo['mediaType'] as String?;
    final rawText = replyTo['text'] as String? ?? '';
    final preview = mediaType == 'video'
        ? s.replyMediaVideo
        : mediaType == 'image'
            ? s.replyMediaImage
            : rawText;
    final barColor = isMine ? Colors.white70 : Colors.teal.shade400;
    final bgColor = isMine ? Colors.white.withValues(alpha: 0.15) : Colors.teal.shade50;
    final textColor = isMine ? Colors.white : Colors.grey.shade700;
    final nameColor = isMine ? Colors.white : Colors.teal.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: nameColor)),
          const SizedBox(height: 2),
          Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildInputBar(ShareRoomStrings s, dynamic user) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _replyTargetNotifier,
            builder: (_, replyTo, __) {
              if (replyTo == null) return const SizedBox.shrink();
              final name = replyTo['senderName'] as String? ?? '';
              final mediaType = replyTo['mediaType'] as String?;
              final rawText = replyTo['text'] as String? ?? '';
              final preview = mediaType == 'video'
                  ? s.replyMediaVideo
                  : mediaType == 'image'
                      ? s.replyMediaImage
                      : rawText;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  children: [
                    Container(width: 3, height: 32, color: Colors.teal.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.replyingTo(name), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                          const SizedBox(height: 2),
                          Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _clearReplyTarget,
                      icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _uploadingNotifier,
            builder: (_, uploading, __) {
              if (uploading == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.teal.shade50,
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal.shade600)),
                    const SizedBox(width: 10),
                    Text(uploading, style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                  ],
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: _uploadingNotifier,
                  builder: (_, uploading, __) => IconButton(
                    onPressed: uploading != null ? null : () => _showAttachSheet(user),
                    icon: Icon(Icons.add_circle_outline, color: uploading != null ? Colors.grey.shade300 : Colors.teal.shade600),
                    tooltip: s.attachTooltip,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: s.messageHint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(user),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: _sendingNotifier,
                  builder: (_, sending, __) => IconButton(
                    onPressed: sending ? null : () => _send(user),
                    icon: sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
