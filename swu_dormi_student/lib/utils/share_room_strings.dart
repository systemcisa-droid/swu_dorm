import 'package:flutter/material.dart';

// 소모임 화면에서 사용하는 다국어 문자열
class ShareRoomStrings {
  final bool isEnglish;
  const ShareRoomStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('소모임', 'Meetup');
  String get todayOnlyNotice => _t('소모임은 당일만 유지되고 자정에 초기화됩니다', 'Meetups reset at midnight — same-day only');
  String get emptySlot => _t('비어있는 소모임입니다', 'This meetup is empty');
  String get createButton => _t('소모임 만들기', 'Create a meetup');
  String get cancelButton => _t('취소하기', 'Cancel');
  String get authorLabel => _t('작성자', 'Host');
  String get maxParticipantsLabel => _t('최대 인원', 'Max participants');
  String get noLimit => _t('제한 없음', 'No limit');
  String get meetingTimeLabel => _t('모이는 시간', 'Meeting time');
  String get locationLabel => _t('장소', 'Location');
  String get openChatHint => _t('탭하면 채팅방이 열립니다', 'Tap to open chat');
  String get loginRequired =>
      _t('로그인 정보를 불러오지 못했습니다. 앱을 다시 실행하거나 재로그인해주세요.',
          'Could not load your login info. Please restart the app or sign in again.');

  // 작성 다이얼로그
  String get createDialogTitle => _t('소모임 만들기', 'Create a Meetup');
  String get topicLabel => _t('주제', 'Topic');
  String get topicHint => _t('예: 보드게임 같이 하실 분', 'e.g. Board games, anyone?');
  String get contentLabel => _t('내용', 'Description');
  String get contentHint => _t('소모임에 대한 설명을 적어주세요', 'Describe your meetup');
  String get maxParticipantsHint => _t('선택 입력', 'Optional');
  String get meetingTimeHint => _t('예: 오늘 저녁 7시', 'e.g. Today at 7 PM');
  String get locationHint => _t('예: 1층 라운지', 'e.g. 1st floor lounge');
  String get submitButton => _t('등록하기', 'Post');
  String get topicRequired => _t('주제를 입력해주세요', 'Please enter a topic');

  String get cancelConfirmTitle => _t('소모임 취소', 'Cancel Meetup');
  String get cancelConfirmContent => _t('소모임을 취소하시겠습니까?', 'Are you sure you want to cancel this meetup?');
  String get keep => _t('아니요', 'No');
  String get confirm => _t('취소하기', 'Yes, Cancel');
  String get createSuccess => _t('소모임이 등록되었습니다', 'Meetup created');
  String get cancelSuccess => _t('소모임이 취소되었습니다', 'Meetup cancelled');
  String get slotUnavailable => _t('이미 다른 학생이 소모임을 만들었습니다', 'Another student already created a meetup here');
  String errorLabel(Object e) => _t('오류: $e', 'Error: $e');

  // 소모임 채팅
  String get messageHint => _t('메시지를 입력하세요...', 'Write a message...');
  String get noMessagesYet => _t('아직 메시지가 없습니다. 첫 메시지를 보내보세요!', 'No messages yet. Send the first one!');
  String get sendFailed => _t('메시지 전송에 실패했습니다', 'Failed to send message');
  String sendError(Object e) => _t('전송 오류: $e', 'Send error: $e');
  String get messageCopied => _t('메시지가 복사되었습니다', 'Message copied');

  /// 메시지 길게 누르기 메뉴
  String get menuCopy => _t('복사', 'Copy');
  String get menuSelectCopy => _t('선택 복사', 'Select text');
  String get menuEdit => _t('수정', 'Edit');
  String get menuDelete => _t('삭제', 'Delete');
  String get deleteMessageTitle => _t('메시지 삭제', 'Delete message');
  String get deleteMessageConfirm => _t('이 메시지를 삭제하시겠습니까?', 'Delete this message?');
  String deleteError(Object e) => _t('삭제 오류: $e', 'Delete error: $e');
  String get cancel => _t('취소', 'Cancel');
  String get save => _t('저장', 'Save');
  String get close => _t('닫기', 'Close');
  String get editMessageTitle => _t('메시지 수정', 'Edit message');
  String editError(Object e) => _t('수정 오류: $e', 'Edit error: $e');
  String get editedLabel => _t('(수정됨)', '(edited)');

  /// 첨부(사진/영상)
  String get attachTooltip => _t('사진/영상 첨부', 'Attach photo/video');
  String get pickImage => _t('사진 선택', 'Choose photo');
  String get pickVideo => _t('영상 선택', 'Choose video');
  String get pickVideoHint => _t('최대 1분 · 업로드 시 압축됩니다', 'Up to 1 min · compressed on upload');
  String get compressingVideo => _t('영상 압축 중...', 'Compressing video...');
  String get uploadingVideo => _t('영상 업로드 중...', 'Uploading video...');
  String get uploadingImage => _t('사진 업로드 중...', 'Uploading photo...');
  String get fileTooLarge =>
      _t('파일이 너무 큽니다. 더 짧은 영상을 선택해주세요', 'File is too large. Please choose a shorter video.');

  /// 날짜 구분선 형식
  String get dateFormat => _t('yyyy년 MM월 dd일 (E)', 'MMM d, yyyy (E)');
  String get dateLocale => _t('ko', 'en');

  /// 답장(스와이프)
  String replyingTo(String name) => _t('$name님에게 답장', 'Replying to $name');
  String get replyMediaImage => _t('[사진]', '[Photo]');
  String get replyMediaVideo => _t('[영상]', '[Video]');

  // 작성 다이얼로그 - 빠른 주제 템플릿
  String get quickTemplatesLabel => _t('빠른 주제 선택', 'Quick topic ideas');
  String get quickTemplatesHint =>
      _t('탭하면 주제에 자동으로 입력됩니다', 'Tap one to fill in the topic');
  String get quickTemplatesExamplesLabel => _t('예시 문구', 'Example phrases');

  List<ShareRoomTemplateCategory> get templateCategories => [
        ShareRoomTemplateCategory(
          label: _t('식사·카페', 'Food & Cafe'),
          icon: Icons.restaurant_outlined,
          topics: [
            _t('지금 샬롬식당 같이 먹을 사람!', "Anyone up for dining hall food?"),
            _t('배민/요기요 배달비 아낄 분 (치킨/피자/마라탕)',
                'Split delivery fees with me (chicken/pizza/mala tang)'),
            _t('야식으로 컵라면이나 편의점 같이 가실 분',
                'Late-night cup noodles or a convenience store run?'),
            _t('지금 누리관(컴포즈, 공차, 퀴즈노스 등) 가는데 같이 하실 분',
                'I am going to Nuri Hall (Compose, Gong Cha, Quiznos, etc.) right now; anyone want to join??'),
          ],
        ),
        ShareRoomTemplateCategory(
          label: _t('이동·교통', 'Transport'),
          icon: Icons.directions_car_outlined,
          topics: [
            _t('학교에서 화랑대나 태릉역로 택시 타고 같이 가실분 (00시 출발)',
                'Anyone who wants to take a taxi from school to Hwarangdae or Taereung Station (leaving at __)'),
            _t('화랑대나 태릉역에서 학교로 택시 타고 같이 들어 오실분 (00시 출발)',
                'Looking for someone to take a taxi to the school with from Hwarangdae or Taereung Station(leaving at __)'),
            _t('같이 강남(명동, 한강, 홍대, 공항) 같이 가실분',
                'Looking for someone to go to Gangnam (Myeongdong, Hangang, Hongdae, Airport) together?'),
            _t('같이 부산(광주, 강화도, 강원도) 같이 가실분',
                'Looking for someone to go to Busan (Gwangju, Ganghwa Island, Gangwon-do) together'),
          ],
        ),
        ShareRoomTemplateCategory(
          label: _t('문화·여가', 'Leisure'),
          icon: Icons.movie_outlined,
          topics: [
            _t('같이 보드게임 하실분?',
                "Anyone want to play board games together?"),
            _t('교내 산책이나 러닝 하실분?', 'Anyone want to go for a walk or run on campus?'),
            _t('영화 보기, 같이 사진찍기, 노래방 가기, ', 'Watching a movie, taking photos together, going to noraebang'),
            _t('모바일 게임(롤토체스, 브롤스타즈 등) 스쿼드/듀오 하실 분',
                'Looking for a squad/duo for mobile games (TFT, Brawl Stars, etc.)'),
          ],
        ),
        ShareRoomTemplateCategory(
          label: _t('생활 정보', 'Life Tips'),
          icon: Icons.lightbulb_outline,
          topics: [
            _t('중간고사/기말고사 밤샘 공부 스터디메이트 (도서관 독서실 자리 공유)',
                'Midterm/final all-nighter study buddy (sharing library seats)'),
            _t('안 쓰는 멀티탭/옷걸이/책 나눔합니다',
                'Giving away a spare power strip/hangers/books'),
          ],
        ),
      ];
}

class ShareRoomTemplateCategory {
  final String label;
  final IconData icon;
  final List<String> topics;
  const ShareRoomTemplateCategory({
    required this.label,
    required this.icon,
    required this.topics,
  });
}
