class FacilityReportStrings {
  final bool isEnglish;
  const FacilityReportStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('수리 보수 신청', 'Repair Request');
  String get tabSubmit => _t('수리 신청하기', 'Submit Request');
  String get tabHistory => _t('신청 내역', 'Request History');

  static const Map<String, String> _categoryEn = {
    '가구/도어': 'Furniture/Door',
    '수도설비': 'Plumbing',
    '전기': 'Electrical',
    '공동구역(헬스장, 기도실 등)': 'Common Area (Gym, Prayer Room)',
    '기타': 'Other',
  };
  String category(String ko) => isEnglish ? (_categoryEn[ko] ?? ko) : ko;

  static const Map<String, String> _statusEn = {
    '접수 대기': 'Pending',
    '처리 중': 'In Progress',
    '처리 완료': 'Completed',
    '자체 처리': 'Self-Resolved',
  };
  String status(String ko) => isEnglish ? (_statusEn[ko] ?? ko) : ko;

  String get maxAttachNotice => _t('최대 5개까지만 첨부할 수 있습니다', 'You can attach up to 5 files');
  String get cannotSelectFile => _t('파일을 선택할 수 없습니다', 'Unable to select file');
  String get takePhoto => _t('카메라로 사진 촬영', 'Take a Photo');
  String get recordVideo => _t('카메라로 영상 촬영', 'Record a Video');
  String get chooseImageFromGallery => _t('갤러리에서 사진 선택', 'Choose Photo from Gallery');
  String get chooseVideoFromGallery => _t('갤러리에서 영상 선택', 'Choose Video from Gallery');

  String get formNotReady => _t('폼이 초기화되지 않았습니다. 다시 시도해주세요.', 'The form has not been initialized. Please try again.');
  String get loginRequired => _t('로그인이 필요합니다', 'Login required');

  String get residenceInfoMissingBanner =>
      _t('기숙사 건물, 호실, 자리번호가 등록되어 있지 않습니다.\n프로필은 기숙사 입사일 자동 업데이트됩니다.',
          'Your dormitory building, room, and seat number are not registered.\nyour profile will be automatically updated on the day you move into the dormitory.');

  String get processing => _t('처리 중...', 'Processing...');
  String compressingVideo(int cur, int total) => _t('영상 압축 중... ($cur/$total)', 'Compressing video... ($cur/$total)');
  String optimizingImage(int cur, int total) => _t('이미지 최적화 중... ($cur/$total)', 'Optimizing image... ($cur/$total)');
  String uploading(int cur, int total) => _t('업로드 중... ($cur/$total)', 'Uploading... ($cur/$total)');
  String get uploadFailedSubmitWithoutFile =>
      _t('파일 업로드에 실패했습니다. 파일 없이 신고를 접수합니다.', 'File upload failed. The request will be submitted without files.');
  String get submitSuccess => _t('수리 보수 신청이 접수되었습니다', 'Your repair request has been submitted');
  String get submitError => _t('수리 보수 신청 접수 중 오류가 발생했습니다. 다시 시도해주세요.', 'An error occurred while submitting the request. Please try again.');

  String get residentInfo => _t('사생 정보', 'Resident Information');
  String get name => _t('이름', 'Name');
  String get noInfo => _t('정보 없음', 'No information');
  String get dormBuilding => _t('기숙사', 'Dormitory');
  String get area => _t('구역', 'Area');
  String get room => _t('호실', 'Room');
  String get seatNumber => _t('자리번호', 'Seat Number');

  String get photoVideoAttachOptional => _t('사진 및 영상 첨부 (필수)', 'Attach Photos/Videos (Required)');
  String get photoVideoRequired => _t('사진 또는 영상을 1개 이상 첨부해주세요', 'Please attach at least one photo or video');
  String get addPhotoVideo => _t('사진 및 영상 추가', 'Add Photos/Videos');
  String get requestType => _t('신청 유형', 'Request Type');
  String get detailDescription => _t('상세 설명', 'Detailed Description');
  String get detailDescriptionHint => _t('ex) 옷장 2번째 서랍 안닫혀요.', 'e.g. The second drawer of the closet won\'t close.');
  String get detailDescriptionRequired => _t('상세 설명을 입력해주세요', 'Please enter a detailed description');
  String get submit => _t('신청 접수', 'Submit');

  String get guideText => _t(
        '''●접수: 당일 13:00 이전 추천/ 24시간 신청가능
●작업: 유관부서 일정에 따라 변동 가능
▶시설보수신청 이후 유관부서에 전달

순차진행, 유관부서 상황에 따라 작업일정 변동 가능
누수, 파손등 긴급 시설보수 필요에 따라 작업순서 변동 가능
※ 학생이 방에 없을 경우, 행정실인턴이 동행하여 마스터키로 문을 열고 수리함''',
        '''● Submission: Recommended before 1:00 PM same day / requests accepted 24 hours a day
● Work: Schedule may vary depending on the relevant department
▶ Requests are forwarded to the relevant department after submission

Requests are processed in order; the work schedule may change depending on the department's situation
The work order may change for urgent repairs such as leaks or damage
※ If the student is not in the room, an administrative office intern will accompany staff and open the door with a master key for the repair''',
      );

  // ── 신청 내역 ──
  String get historyLoginRequired => _t('로그인이 필요합니다', 'Login required');
  String get historyLoadError => _t('신청 내역을 불러오는 중 오류가 발생했습니다', 'An error occurred while loading the request history');
  String get noHistory => _t('신청 내역이 없습니다', 'There is no request history');
  String get adminNote => _t('관리자 메모', 'Admin Note');
  String moreCount(int n) => _t('+$n개 더', '+$n more');

  String get requestTypeLabel => _t('신청 유형', 'Request Type');
  String get requestDateTime => _t('신청 일시', 'Requested At');
  String get completedDateTime => _t('완료 일시', 'Completed At');
  String get attachedFiles => _t('첨부 파일', 'Attached Files');
  String get imageLoadError => _t('이미지를 불러올 수 없습니다', 'Unable to load image');

  String get cancel => _t('취소', 'Cancel');

  // ── 자체 처리 ──
  String get selfResolveButton => _t('자체 처리', 'Self-Resolved');
  String get selfResolveTitle => _t('자체 처리 확인', 'Confirm Self-Resolution');
  String get selfResolveConfirm => _t(
      '직접 수리하거나 처리하셨나요?\n처리 완료로 표시되며, 더 이상 수정/삭제할 수 없습니다.',
      'Did you fix or resolve this yourself?\nIt will be marked as completed and can no longer be edited or deleted.');
  String get selfResolveNoteHint => _t('처리 내용 (선택)', 'What you did (optional)');
  String get selfResolveConfirmButton => _t('처리 완료', 'Mark Completed');
  String get selfResolveSuccess => _t('자체 처리로 등록되었습니다', 'Marked as self-resolved');
  String selfResolveError(Object e) => _t('처리 등록 오류: $e', 'Error marking as resolved: $e');
}
