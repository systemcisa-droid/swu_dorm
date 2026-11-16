// 사다리타기 화면에서 사용하는 다국어 문자열
class LadderStrings {
  final bool isEnglish;
  const LadderStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('사다리타기', 'Ladder Game');
  String get hubSubtitle =>
      _t('참가자와 결과를 입력하고 무작위로 사다리를 탑니다', 'Enter names and outcomes, then draw a random ladder');

  String get participantLabel => _t('참가자', 'Participant');
  String get resultLabel => _t('결과', 'Outcome');
  String nameHint(int index) => _t('참가자 ${index + 1}', 'Participant ${index + 1}');
  String resultHint(int index) => _t('결과 ${index + 1}', 'Outcome ${index + 1}');
  String get addRow => _t('참가자 추가', 'Add participant');
  String get maxParticipantsReached => _t('참가자는 최대 10명까지 가능합니다', 'Up to 10 participants allowed');
  String get minParticipantsError => _t('참가자는 최소 2명 이상이어야 합니다', 'At least 2 participants are required');
  String get emptyNameError =>
      _t('참가자와 결과 이름을 모두 입력해주세요', 'Please fill in every participant and outcome name');
  String get startButton => _t('사다리 타기 시작', 'Start the ladder');
  // 같은 참가자/결과로 사다리만 새로 섞어서 다시 그린다 (이름 수정 화면으로 돌아가지 않음).
  String get resetButton => _t('리셋', 'Reset');
  String get revealAllButton => _t('일괄 결과 보기', 'Reveal all at once');
  String get tapToRevealHint =>
      _t('참가자 이름을 눌러 결과를 확인하세요', 'Tap a participant to reveal their outcome');
  String resultArrow(String name, String result) => _t('$name → $result', '$name → $result');
}
