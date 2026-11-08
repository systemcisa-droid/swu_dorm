/// 사생회 화면 문구 (한/영)
class StudentCouncilStrings {
  final bool isEnglish;
  const StudentCouncilStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('사생회', 'Resident Council');

  // 탭
  String get tabNotices => _t('공지', 'Notices');
  String get tabCampaigns => _t('캠페인', 'Campaigns');
  String get tabElections => _t('선거', 'Elections');
  String get tabMinutes => _t('회의록', 'Minutes');

  // 공통
  String get loadError => _t('불러오는 중 오류가 발생했습니다', 'Failed to load');
  String get noticesEmpty =>
      _t('등록된 사생회 공지가 없습니다', 'No resident council notices yet');
  String get campaignsEmpty =>
      _t('진행 중인 캠페인이 없습니다', 'No campaigns in progress');
  String get electionsEmpty => _t('진행 중인 선거가 없습니다', 'No elections in progress');
  String get minutesEmpty => _t('등록된 회의록이 없습니다', 'No meeting minutes yet');
  String get registeredLabel => _t('등록됨', 'Registered');
  String get unregisteredLabel => _t('미등록', 'Not registered');

  // 캠페인 상태
  String get statusOngoing => _t('진행중', 'Ongoing');
  String get statusUpcoming => _t('예정', 'Upcoming');
  String get statusClosed => _t('종료', 'Closed');

  // 선거
  String get electionPeriod => _t('투표 기간', 'Voting period');
  String get electionCandidates => _t('후보', 'Candidates');

  // 선거 상세
  String get electionDetailTitle => _t('선거 공고', 'Election Notice');
  String get electionNoContent =>
      _t('등록된 공고 내용이 없습니다.', 'No notice content registered.');

  // 투표
  String get voteSelectCandidate => _t('후보를 선택하세요', 'Select a candidate');
  String get voteButton => _t('투표하기', 'Vote');
  String get voteConfirmTitle => _t('투표 확인', 'Confirm Vote');
  String voteConfirmBody(String candidate) => _t(
      '「$candidate」 후보에게 투표하시겠습니까?\n\n투표 후에는 변경하거나 취소할 수 없습니다.',
      'Vote for "$candidate"?\n\nYour vote cannot be changed or canceled.');
  String get voteConfirm => _t('투표', 'Vote');
  String get voteCancel => _t('취소', 'Cancel');
  String get voteDone => _t('투표가 완료되었습니다.', 'Your vote has been submitted.');
  String get voteAlreadyDone =>
      _t('이미 투표하셨습니다.', 'You have already voted.');
  String get voteStartsInLabel => _t('투표 시작까지', 'Voting starts in');
  String get voteClosed => _t('투표가 종료되었습니다.', 'Voting has closed.');
  String get voteFailed =>
      _t('투표 처리에 실패했습니다. 다시 시도해주세요.', 'Failed to submit your vote. Please try again.');
  String get voteSecretNotice => _t(
      '비밀투표입니다. 누구를 선택했는지는 기록되지 않으며, 투표 여부만 확인됩니다.',
      'This is a secret ballot. Your choice is not recorded with your identity — only that you voted.');
  String get voteNoCandidates =>
      _t('등록된 후보가 없습니다.', 'No candidates registered.');

  // 후보 소개
  String get candidateIntro => _t('소개', 'Profile');
  String get candidateIntroTitle => _t('후보 소개', 'Candidate Profile');
  String get candidateNoIntro =>
      _t('등록된 소개가 없습니다.', 'No profile registered.');
  String get candidateWatchVideo =>
      _t('연설·공약 영상 보기', 'Watch speech & pledges');
  String get candidateNoVideo =>
      _t('등록된 영상이 없습니다.', 'No video registered.');
  String get linkOpenFailed =>
      _t('링크를 열 수 없습니다.', 'Could not open the link.');

  // 선거 포스터
  String get electionPoster => _t('선거 포스터', 'Election Poster');
  String get electionPosterOpen => _t('선거 포스터 보기', 'View election poster');

  // 캠페인 상세
  String get campaignDetailTitle => _t('캠페인', 'Campaign');
  String get likeLabel => _t('좋아요', 'Like');
  String get likeFailed => _t(
      '좋아요를 처리하지 못했습니다. 잠시 후 다시 시도해주세요.',
      'Could not update your like. Please try again.');

  // 캠페인 댓글
  String get loginRequired => _t('로그인이 필요합니다', 'Login required');
  String commentsCount(int n) => _t('댓글 $n개', '$n Comments');
  String get commentsLoadError => _t('댓글을 불러올 수 없습니다', 'Unable to load comments');
  String get noCommentsYet => _t('첫 댓글을 작성해보세요!', 'Be the first to comment!');
  String get commentHint => _t('댓글을 입력하세요...', 'Write a comment...');
  String get commentPosted => _t('댓글이 등록되었습니다', 'Comment posted');
  String commentPostError(Object e) =>
      _t('댓글 등록 중 오류가 발생했습니다: $e', 'An error occurred while posting the comment: $e');
  String get deleteCommentTitle => _t('댓글 삭제', 'Delete Comment');
  String get deleteCommentConfirm =>
      _t('댓글을 삭제하시겠습니까?', 'Are you sure you want to delete this comment?');
  String get commentDeleted => _t('댓글이 삭제되었습니다', 'Comment deleted');
  String commentDeleteError(Object e) =>
      _t('댓글 삭제 중 오류가 발생했습니다: $e', 'An error occurred while deleting the comment: $e');
  String get cancel => _t('취소', 'Cancel');
  String get delete => _t('삭제', 'Delete');

  // 댓글 신고·차단 (게시판과 동일한 정책)
  String get reportMenu => _t('신고하기', 'Report');
  String get blockUser => _t('사용자 차단', 'Block User');
  String get unblockUser => _t('차단 해제', 'Unblock');
  String get reportDialogTitle => _t('신고하기', 'Report');
  String get reportCommentPrompt =>
      _t('이 댓글을 신고하는 이유를 선택해주세요.', 'Please select a reason for reporting this comment.');
  static const _reportReasonsKo = ['비방·욕설', '허위 사실 유포', '음란·불건전 내용', '개인정보 침해', '기타'];
  static const _reportReasonsEn = [
    'Abuse / profanity',
    'Spreading false information',
    'Obscene / inappropriate content',
    'Privacy violation',
    'Other',
  ];
  List<String> get reportReasons => isEnglish ? _reportReasonsEn : _reportReasonsKo;
  String get reportDetailHint => _t('신고 내용을 입력해주세요', 'Please describe the issue');
  String get report => _t('신고', 'Report');
  String get reportSubmitted =>
      _t('신고가 접수되었습니다. 검토 후 조치하겠습니다.', 'Your report has been submitted. We will review it and take action.');
  String reportSubmitError(Object e) =>
      _t('신고 접수 중 오류가 발생했습니다: $e', 'An error occurred while submitting the report: $e');
  String get blockTitle => _t('사용자 차단', 'Block User');
  String get unblockTitle => _t('차단 해제', 'Unblock User');
  String get unblockConfirm => _t('이 사용자의 차단을 해제하시겠습니까?', 'Are you sure you want to unblock this user?');
  String get blockConfirm => _t(
      '이 사용자를 차단하면 해당 사용자의 글과 댓글이 보이지 않습니다.\n차단하시겠습니까?',
      "If you block this user, their posts and comments will no longer be visible.\nDo you want to block them?");
  String get unblockAction => _t('해제', 'Unblock');
  String get blockAction => _t('차단', 'Block');
  String get unblockedMessage => _t('차단이 해제되었습니다.', 'User has been unblocked.');
  String get blockedMessage =>
      _t('차단되었습니다. 해당 사용자의 글이 더 이상 보이지 않습니다.', "User has been blocked. Their posts will no longer be visible.");

  // 공지 상세
  String get noticeDetailTitle => _t('사생회 공지', 'Council Notice');
  String get noticeOpenPdf => _t('첨부 PDF 보기', 'View attached PDF');

  // 회의록 상세
  String get minuteDetailTitle => _t('회의록', 'Meeting Minutes');

  // 투표율
  String get electionTurnout => _t('투표율', 'Turnout');

  // 투표 완료 후 안내 (결과 공표·이의 접수)
  String get voteResultNotice => _t(
      '규정에 따라 투표 공식 종료하고 3시간 후 선거 결과를 공표(공지사항)할 예정입니다. '
      '선거 과정 전반에 대해 이의가 있는 각 후보 측은 결과 발표 전까지 정해진 양식에 따라 '
      '선거관리위원회로 이의를 접수해 주시기 바랍니다.',
      'The election results will be announced (in Notices) three hours after voting '
      'officially closes, in accordance with the regulations. Any candidate with an '
      'objection regarding the election process must submit it to the Election '
      'Management Committee using the designated form before the results are announced.');
}
