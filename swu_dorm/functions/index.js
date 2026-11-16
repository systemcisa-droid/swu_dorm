/**
 * SWU 기숙사 통합관리 시스템 - 푸시 알림 발송
 *
 * 앱은 FCM 수신 준비가 되어 있으나(토큰 저장·채널 생성), 발송 주체가 없어
 * 기기 알림이 뜨지 않았다. FCM 발송은 서버 키가 필요해 앱에서 직접 할 수 없으므로
 * 이 함수가 발송을 담당한다.
 *
 * 1) onNotificationRequest : notification_requests 문서 생성 시 발송
 *    (공지사항·메시지·수리신고 상태변경 등 기존 코드가 이미 쌓고 있음)
 * 2) onFloorChatMessage    : 층장단톡방 메시지 생성 시 상대방에게 발송
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// 서울 리전 고정 (지연 시간 감소)
setGlobalOptions({ region: "asia-northeast3", maxInstances: 10 });

/** FCM 토큰은 500개씩 나눠 보내야 한다. */
const FCM_BATCH = 500;

/**
 * 토큰 목록으로 푸시를 보내고, 만료된 토큰은 Firestore에서 제거한다.
 * @param {Array<{token: string, uid: string}>} targets
 */
async function sendToTokens(targets, title, body, data) {
  if (!targets.length) {
    console.log("발송 대상 없음");
    return { success: 0, failure: 0 };
  }

  // 문자열만 허용되므로 모든 값을 문자열로 변환한다.
  const stringData = {};
  Object.entries(data || {}).forEach(([k, v]) => {
    if (v !== null && v !== undefined) stringData[k] = String(v);
  });

  let success = 0;
  let failure = 0;
  const staleTokens = [];

  for (let i = 0; i < targets.length; i += FCM_BATCH) {
    const chunk = targets.slice(i, i + FCM_BATCH);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk.map((t) => t.token),
      notification: { title, body },
      data: stringData,
      android: {
        priority: "high",
        notification: {
          channelId: "swu_dormi_channel",
          sound: "default",
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });

    success += res.successCount;
    failure += res.failureCount;

    res.responses.forEach((r, idx) => {
      if (r.success) return;
      const code = r.error && r.error.code;
      // 더 이상 유효하지 않은 토큰은 정리 대상
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token" ||
        code === "messaging/invalid-argument"
      ) {
        staleTokens.push({ uid: chunk[idx].uid, collectionName: chunk[idx].collectionName });
      } else {
        console.error("발송 실패:", code);
      }
    });
  }

  // 만료 토큰 제거 (다음 로그인 시 새 토큰이 저장된다)
  if (staleTokens.length) {
    const batch = db.batch();
    staleTokens.forEach(({ uid, collectionName }) => {
      batch.update(db.collection(collectionName || "student").doc(uid), {
        fcmToken: admin.firestore.FieldValue.delete(),
      });
    });
    await batch.commit();
    console.log(`만료 토큰 ${staleTokens.length}건 정리`);
  }

  console.log(`발송 결과: 성공 ${success} / 실패 ${failure}`);
  return { success, failure };
}

/**
 * student/admin 문서들에서 fcmToken 을 수집한다.
 * collectionName은 만료 토큰 정리 시 어느 컬렉션의 문서를 지울지 알기 위해 필요하다
 * (student 문서와 admin 문서는 분리되어 있다).
 */
function collectTokens(docs, collectionName) {
  const targets = [];
  docs.forEach((doc) => {
    const d = doc.data();
    if (!d) return;
    const token = d.fcmToken;
    if (typeof token === "string" && token.trim()) {
      targets.push({ token: token.trim(), uid: doc.id, collectionName });
    }
  });
  return targets;
}

/** settings/current_term 문서에서 현재(라이브) 학기 id를 읽는다. */
async function getCurrentTermId() {
  const doc = await db.collection("settings").doc("current_term").get();
  const termId = doc.exists && doc.data() ? doc.data().termId : null;
  return termId && String(termId).trim() ? String(termId).trim() : "default";
}

/** 현재 학기의 student_enrollment 컬렉션(학생 방/호실/건물 배정) 참조. */
function studentEnrollmentCollection(termId) {
  return db.collection("terms").doc(termId).collection("student_enrollment");
}

/**
 * 알림 종류별 수신 거부 여부.
 * 학생앱이 users/{uid}.notificationSettings 에 저장한다.
 * 값이 없으면 수신으로 간주한다.
 */
function isEnabled(userData, type) {
  const settings = (userData && userData.notificationSettings) || {};

  // 전체 알림을 끈 경우 어떤 알림도 보내지 않는다.
  if (settings.all_notifications === false) return false;

  // 학생앱 NotificationPrefs.keyByType 과 동일하게 유지할 것.
  const keyByType = {
    notice: "notice_notifications",
    check_in_out: "check_in_out_notifications",
    message: "admin_message_notifications",
    board_comment: "board_comment_notifications",
    floor_chat: "message_notifications", // 층장단톡방
  };
  const key = keyByType[type];
  if (!key) return true;

  const v = settings[key];
  if (v === undefined || v === null) return true; // 설정이 없으면 수신
  return v === true;
}

// ──────────────────────────────────────────────────────────
// 1) notification_requests → 푸시 발송
// ──────────────────────────────────────────────────────────
exports.onNotificationRequest = onDocumentCreated(
  "terms/{termId}/notification_requests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const req = snap.data() || {};

    const title = req.title || "알림";
    const body = req.body || "";
    const type = req.type || "";
    const target = req.target || "";

    try {
      let targets = [];

      if (target === "users" || Array.isArray(req.userIds)) {
        // 지정한 여러 사용자 (메시지 전송 등) — student/admin 둘 다에서 찾는다.
        const uids = Array.isArray(req.userIds) ? req.userIds : [];
        const studentDocs = [];
        const adminDocs = [];
        // Firestore documentId whereIn 은 30개 제한 → 나눠 조회
        for (let i = 0; i < uids.length; i += 30) {
          const chunk = uids.slice(i, i + 30);
          const [studentSnap, adminSnap] = await Promise.all([
            db
              .collection("student")
              .where(admin.firestore.FieldPath.documentId(), "in", chunk)
              .get(),
            db
              .collection("admin")
              .where(admin.firestore.FieldPath.documentId(), "in", chunk)
              .get(),
          ]);
          studentSnap.docs.forEach((d) => {
            const data = d.data();
            if (data && isEnabled(data, type)) studentDocs.push(d);
          });
          adminSnap.docs.forEach((d) => {
            const data = d.data();
            if (data && isEnabled(data, type)) adminDocs.push(d);
          });
        }
        targets = [
          ...collectTokens(studentDocs, "student"),
          ...collectTokens(adminDocs, "admin"),
        ];
      } else if (target === "user") {
        // 특정 사용자 1명 — student에 없으면 admin에서 찾는다.
        const uid = req.userId;
        if (!uid) {
          await snap.ref.update({ status: "failed", error: "userId 없음" });
          return;
        }
        let userDoc = await db.collection("student").doc(uid).get();
        let collectionName = "student";
        if (!userDoc.exists) {
          userDoc = await db.collection("admin").doc(uid).get();
          collectionName = "admin";
        }
        const data = userDoc.data();
        if (userDoc.exists && data && isEnabled(data, type)) {
          targets = collectTokens([userDoc], collectionName);
        }
      } else {
        // 전체 학생 (target: 'all_students') — student 컬렉션 자체가 학생 전용이다.
        const snapshot = await db.collection("student").get();
        const allowed = snapshot.docs.filter((d) => {
          const data = d.data();
          if (!data) return false;
          return isEnabled(data, type);
        });
        targets = collectTokens(allowed, "student");
      }

      const result = await sendToTokens(targets, title, body, {
        ...(req.data || {}),
        type,
      });

      await snap.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: result.success,
        failureCount: result.failure,
      });
    } catch (e) {
      console.error("알림 발송 오류:", e);
      await snap.ref.update({
        status: "failed",
        error: String(e).slice(0, 500),
      });
    }
  }
);

// ──────────────────────────────────────────────────────────
// 2) 층장단톡방 메시지 → 상대방에게 푸시
//    terms/{termId}/floor_chats/{roomId}/messages/{messageId}
//    roomId 예: '샬롬하우스_A동_202호'
// ──────────────────────────────────────────────────────────
exports.onFloorChatMessage = onDocumentCreated(
  "terms/{termId}/floor_chats/{roomId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const msg = snap.data() || {};

    const senderId = msg.senderId || "";
    const senderName = msg.senderName || "";
    const roomId = event.params.roomId;
    const eventTermId = event.params.termId;

    // 첨부만 보낸 경우 본문이 비어 있다.
    let body = (msg.text || "").trim();
    if (!body) {
      body = msg.mediaType === "video" ? "[영상]" : "[사진]";
    }
    if (body.length > 60) body = `${body.slice(0, 60)}...`;

    try {
      // 경로 파라미터(roomId)는 한글이 깨져 전달되는 경우가 있어
      // 방 문서에 저장된 roomId 필드를 우선 사용한다.
      let resolvedRoomId = roomId;
      try {
        const roomDoc = await db
          .collection("terms")
          .doc(eventTermId)
          .collection("floor_chats")
          .doc(roomId)
          .get();
        const stored =
          roomDoc.exists && roomDoc.data() ? roomDoc.data().roomId : null;
        if (typeof stored === "string" && stored.includes("_")) {
          resolvedRoomId = stored;
        }
      } catch (e) {
        console.error("방 문서 조회 실패:", e);
      }

      // roomId 에서 건물/동/호실 복원 → 해당 호실 학생 + 담당 층장에게 발송
      // 형식: '샬롬하우스_A동_320호' (3파트) / '바롬인성교육관_1001-A호' (2파트, 동 없음)
      const parts = resolvedRoomId.split("_");
      if (parts.length < 2) {
        console.log("roomId 형식 불일치:", roomId);
        return;
      }
      let dormBuilding = parts[0];
      const isBarom = dormBuilding.startsWith("바롬인성교육관");
      let wing = null;
      let roomNumber;
      if (isBarom) {
        // '1001-A호' → '1001-A' (바롬 호실은 접미사까지 포함)
        roomNumber = parts[1].replace(/호$/, "").trim();
        if (!roomNumber) {
          console.log("호실 번호 추출 실패:", parts[1]);
          return;
        }
      } else {
        if (parts.length < 3) {
          console.log("roomId 형식 불일치:", roomId);
          return;
        }
        wing = parts[1];
        // '320호' → '320' (한글 '호'가 정규식으로 안 잘리는 경우가 있어 숫자만 추출)
        const roomDigits = parts[2].match(/\d+/);
        if (!roomDigits) {
          console.log("호실 번호 추출 실패:", parts[2]);
          return;
        }
        roomNumber = roomDigits[0];
      }

      // 방 ID의 한글이 손상돼 전달되는 경우가 있으므로,
      // 발신자(student 또는 admin 문서)의 건물/호실을 신뢰할 수 있는 값으로 사용한다.
      // 학생의 건물/호실/동은 이제 student 문서가 아니라 이 메시지가 속한 학기의
      // terms/{termId}/student_enrollment 문서에 있다. 트리거 경로의 termId를 그대로 쓴다.
      const termId = eventTermId;
      if (senderId) {
        try {
          const studentDoc = await db.collection("student").doc(senderId).get();
          if (studentDoc.exists) {
            const enrollDoc = await studentEnrollmentCollection(termId)
              .doc(senderId)
              .get();
            const e = enrollDoc.exists ? enrollDoc.data() : null;
            const sDorm = (e && e.dormBuilding || "").trim();
            const sRoom = (e && e.roomNumber || "").trim();
            if (sDorm && sRoom && sRoom !== "000") {
              // 학생이 보낸 경우: 본인 거주 건물/호실이 곧 채팅방
              dormBuilding = sDorm;
              roomNumber = sRoom;
              const sWing = (e.building || "").trim();
              if (sWing && !dormBuilding.startsWith("바롬인성교육관")) wing = sWing;
            }
          } else {
            const adminDoc = await db.collection("admin").doc(senderId).get();
            const s = adminDoc.exists ? adminDoc.data() : null;
            if (s && s.role === "admin_m") {
              // 층장이 보낸 경우: 본인 거주지는 무관하므로 담당 구역에서 건물만 가져온다.
              // (호실은 방 ID에서 뽑은 값을 그대로 쓴다). assignedFloor는 admin 문서
              // 자신의 필드로, 학기 구분 없이 그대로 유지된다.
              const af = (s.assignedFloor || "").trim();
              const mWing = af.match(/^(.+?)\s+([AB]동)\s+\d+층$/);
              const mBarom = af.match(/^(바롬인성교육관\S*)\s+\d+층$/);
              if (mWing) {
                dormBuilding = mWing[1];
                wing = mWing[2];
              } else if (mBarom) {
                dormBuilding = mBarom[1];
                wing = null;
              }
            }
          }
        } catch (e) {
          console.error("발신자 조회 실패:", e);
        }
      }

      // 해당 호실 학생 (현재 학기 enrollment에서 먼저 uid를 찾고, student에서 신원을 합친다)
      const enrolledSnap = await studentEnrollmentCollection(termId)
        .where("dormBuilding", "==", dormBuilding)
        .where("roomNumber", "==", roomNumber)
        .get();
      const roomUids = enrolledSnap.docs.map((d) => d.id);
      const studentsSnap = { docs: [] };
      for (let i = 0; i < roomUids.length; i += 30) {
        const chunk = roomUids.slice(i, i + 30);
        if (!chunk.length) continue;
        const snap = await db
          .collection("student")
          .where(admin.firestore.FieldPath.documentId(), "in", chunk)
          .get();
        studentsSnap.docs.push(...snap.docs);
      }

      // 담당 층장 (assignedFloor 가 '샬롬하우스 A동 2층' / '바롬인성교육관 10층' 형태)
      // 동은 저장값('미배정' 가능)보다 호실 번호로 계산한 값을 신뢰한다.
      // 바롬은 '1001-A' 형식이라 접미사를 떼고 층 계산.
      const n = parseInt(isBarom ? roomNumber.split("-")[0] : roomNumber, 10);
      let computedWing = null;
      if (dormBuilding.startsWith("국제생활관")) {
        if ((n >= 101 && n <= 132) || (n >= 201 && n <= 229)) computedWing = "A동";
        else if ((n >= 233 && n <= 260) || (n >= 301 && n <= 329)) computedWing = "B동";
      } else if (dormBuilding.startsWith("샬롬하우스")) {
        const last = n % 100;
        if (last >= 1 && last <= 20) computedWing = "A동";
        else if (last >= 21 && last <= 35) computedWing = "B동";
      }
      if (computedWing) wing = computedWing;

      const floorNum = Math.floor(n / 100);
      const assignedFloor = isBarom
        ? `${dormBuilding} ${floorNum}층`
        : `${dormBuilding} ${wing} ${floorNum}층`;
      const captainsSnap = await db
        .collection("admin")
        .where("role", "==", "admin_m")
        .where("assignedFloor", "==", assignedFloor)
        .get();

      console.log(
        `roomId=${roomId} 건물=${dormBuilding} 동=${wing} 호실=${roomNumber} ` +
          `담당구역=${assignedFloor} 학생=${studentsSnap.size} 층장=${captainsSnap.size} ` +
          `발신자=${senderId}`
      );

      // 보낸 사람 제외 + 수신 설정 확인
      const recipients = [...studentsSnap.docs, ...captainsSnap.docs].filter(
        (d) => {
          if (d.id === senderId) return false;
          const data = d.data();
          if (!data) return false;
          return isEnabled(data, "floor_chat");
        }
      );

      // 중복 제거 (학생이자 층장인 경우는 없지만 방어적으로)
      const seen = new Set();
      const unique = recipients.filter((d) => {
        if (seen.has(d.id)) return false;
        seen.add(d.id);
        return true;
      });

      const targets = collectTokens(unique);
      await sendToTokens(targets, `층장단톡방 · ${senderName}`, body, {
        type: "floor_chat",
        roomId,
      });
    } catch (e) {
      console.error("단톡방 알림 발송 오류:", e);
    }
  }
);

// ──────────────────────────────────────────────────────────
// 3) 이메일 가입 전, 동일 이메일의 구글 가입 여부 확인
//
// 클라이언트 SDK의 fetchSignInMethodsForEmail은 Firebase 프로젝트의
// "이메일 열거 보호"가 켜져 있으면 항상 빈 배열을 반환해 신뢰할 수 없다.
// Admin SDK(auth().getUserByEmail)는 이 보호의 영향을 받지 않으므로
// 서버(Cloud Functions)에서만 정확히 판별할 수 있다.
// ──────────────────────────────────────────────────────────
exports.checkEmailSignInMethods = onCall(async (request) => {
  const email = (request.data && request.data.email || "").trim();
  if (!email) {
    throw new HttpsError("invalid-argument", "이메일이 필요합니다.");
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    const providers = (userRecord.providerData || []).map((p) => p.providerId);
    return { exists: true, providers };
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      return { exists: false, providers: [] };
    }
    console.error("이메일 가입 수단 조회 오류:", e);
    throw new HttpsError("internal", "가입 정보를 확인하지 못했습니다.");
  }
});

