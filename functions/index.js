// functions/index.js
//
// FUNCTIONS:
//  1. markAbsentAtCutoff     → scheduled 12:01 PM Mon–Fri
//  2. markAbsentHalfDay      → scheduled 2:01 PM Mon–Fri
//  3. onBarrierCreated       → Firestore trigger on barriers/{barrierId}
//     Sends FCM push notifications to recipient + CC list via
//     Firebase Admin SDK (HTTP v1 API) — works for all app states
//     (foreground, background, and fully closed).

const { setGlobalOptions }    = require("firebase-functions");
const { onSchedule }          = require("firebase-functions/v2/scheduler");
const { onDocumentCreated }   = require("firebase-functions/v2/firestore");
const logger                  = require("firebase-functions/logger");
const admin                   = require("firebase-admin");

admin.initializeApp();
const db        = admin.firestore();
const messaging = admin.messaging();

setGlobalOptions({ maxInstances: 1 });

// ─────────────────────────────────────────────────────────────────────────────
// RUN 1 — 12:01 PM  Mon–Fri
// Marks employees absent who have not checked in by checkInCutoff (12:00).
// Skips firstHalf-leave employees — they still have until halfDayCutoff (2 PM).
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentAtCutoff = onSchedule(
  {
    schedule:     "1 12 * * 1-5",
    timeZone:     "Asia/Karachi",
    maxInstances: 1,
  },
  async (_event) => {
    logger.info("[markAbsentAtCutoff] Starting noon absent run.");
    await _runMarkAbsent({ skipFirstHalfLeave: true });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// RUN 2 — 2:01 PM  Mon–Fri
// Marks firstHalf-leave employees absent if they still haven't checked in
// after halfDayCutoff. Also catches anyone missed by the noon run.
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentHalfDay = onSchedule(
  {
    schedule:     "1 14 * * 1-5",
    timeZone:     "Asia/Karachi",
    maxInstances: 1,
  },
  async (_event) => {
    logger.info("[markAbsentHalfDay] Starting half-day absent run.");
    await _runMarkAbsent({ skipFirstHalfLeave: false });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// BARRIER NOTIFICATION — triggers when a new barrier doc is created
// ─────────────────────────────────────────────────────────────────────────────
exports.onBarrierCreated = onDocumentCreated(
  "barriers/{barrierId}",
  async (event) => {
    const barrier = event.data.data();
    const barrierId = event.params.barrierId;

    logger.info(`[onBarrierCreated] New barrier: ${barrierId}`);

    const {
      employeeName  = "An employee",
      recipientId   = null,
      ccIds         = [],
      description   = "",
    } = barrier;

    if (!recipientId) {
      logger.warn("[onBarrierCreated] No recipientId on barrier doc — skipping.");
      return;
    }

    const shortDesc = description.length > 80
      ? description.substring(0, 80) + "…"
      : description;

    const recipientSnap = await db.collection("users").doc(recipientId).get();
    const recipientToken = recipientSnap.exists
      ? (recipientSnap.data().fcmToken ?? null)
      : null;

    const ccTokens = [];
    if (Array.isArray(ccIds) && ccIds.length > 0) {
      const ccSnaps = await Promise.all(
        ccIds.map((uid) => db.collection("users").doc(uid).get())
      );
      for (const snap of ccSnaps) {
        if (snap.exists) {
          const token = snap.data().fcmToken ?? null;
          if (token) ccTokens.push(token);
        }
      }
    }

    const sendResults = [];

    if (recipientToken) {
      try {
        const result = await messaging.send({
          token: recipientToken,
          notification: {
            title: "⚠ Barrier Report",
            body:  `${employeeName} reported a barrier: ${shortDesc}`,
          },
          data: {
            type:         "barrier_report",
            barrierId,
            reporterId:   barrier.employeeId   ?? "",
            reporterName: employeeName,
            description,
            timestamp:    new Date().toISOString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "barrier_reports",
              sound:     "default",
              priority:  "high",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: "⚠ Barrier Report",
                  body:  `${employeeName} reported a barrier: ${shortDesc}`,
                },
                sound: "default",
              },
            },
            headers: { "apns-priority": "10" },
          },
        });
        logger.info(`[onBarrierCreated] Recipient notified. FCM message ID: ${result}`);
        sendResults.push({ uid: recipientId, status: "sent", messageId: result });
      } catch (e) {
        logger.error(`[onBarrierCreated] Failed to notify recipient ${recipientId}: ${e.message}`);
        sendResults.push({ uid: recipientId, status: "failed", error: e.message });

        if (
          e.code === "messaging/registration-token-not-registered" ||
          e.code === "messaging/invalid-registration-token"
        ) {
          await db.collection("users").doc(recipientId).update({ fcmToken: null });
          logger.info(`[onBarrierCreated] Cleared stale token for ${recipientId}`);
        }
      }
    } else {
      logger.warn(`[onBarrierCreated] Recipient ${recipientId} has no FCM token.`);
    }

    for (let i = 0; i < ccTokens.length; i++) {
      const token = ccTokens[i];
      const uid   = ccIds[i];
      try {
        const result = await messaging.send({
          token,
          data: {
            type:         "barrier_report_cc",
            barrierId,
            reporterId:   barrier.employeeId ?? "",
            reporterName: employeeName,
            description,
            timestamp:    new Date().toISOString(),
          },
          android: { priority: "high" },
          apns: {
            headers: { "apns-priority": "5" },
          },
        });
        logger.info(`[onBarrierCreated] CC ${uid} notified. FCM message ID: ${result}`);
        sendResults.push({ uid, status: "sent", messageId: result });
      } catch (e) {
        logger.error(`[onBarrierCreated] Failed to notify CC ${uid}: ${e.message}`);
        sendResults.push({ uid, status: "failed", error: e.message });

        if (
          e.code === "messaging/registration-token-not-registered" ||
          e.code === "messaging/invalid-registration-token"
        ) {
          await db.collection("users").doc(uid).update({ fcmToken: null });
          logger.info(`[onBarrierCreated] Cleared stale token for ${uid}`);
        }
      }
    }

    await event.data.ref.update({
      notificationsSent: sendResults,
      notifiedAt:        admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `[onBarrierCreated] Done. ` +
      `${sendResults.filter((r) => r.status === "sent").length} sent, ` +
      `${sendResults.filter((r) => r.status === "failed").length} failed.`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Core absent logic — called by both scheduled functions
// ─────────────────────────────────────────────────────────────────────────────
async function _runMarkAbsent({ skipFirstHalfLeave }) {

  let checkInCutoff = 12;
  let halfDayCutoff = 14;
  let halfDayMark   = 13;
  let workStartHour = 9;
  let workEndHour   = 18;
  let timezone      = "Asia/Karachi";

  try {
    const settingsSnap = await db
      .collection("office_settings")
      .doc("timings")
      .get();

    if (settingsSnap.exists) {
      const data = settingsSnap.data();
      if (data.checkInCutoff != null) checkInCutoff = data.checkInCutoff;
      if (data.halfDayCutoff != null) halfDayCutoff = data.halfDayCutoff;
      if (data.halfDayMark   != null) halfDayMark   = data.halfDayMark;
      if (data.workStartHour != null) workStartHour = data.workStartHour;
      if (data.workEndHour   != null) workEndHour   = data.workEndHour;
      if (data.timezone      != null) timezone      = data.timezone;

      logger.info(
        `[markAbsent] Settings — start:${workStartHour} cutoff:${checkInCutoff} ` +
        `halfMark:${halfDayMark} halfCutoff:${halfDayCutoff} end:${workEndHour} tz:${timezone}`
      );
    } else {
      logger.warn("[markAbsent] office_settings/timings not found — using defaults.");
    }
  } catch (e) {
    logger.warn(`[markAbsent] Failed to read settings (${e.message}) — using defaults.`);
  }

  const now = new Date();

  // ── FIX 1: Derive todayStr and todayStart fully in the configured timezone ──
  // Previously: new Date(dayKey + "T00:00:00") used the server's local timezone
  // (UTC on Cloud Functions), which could be a different date than Pakistan time.
  const todayStr = now.toLocaleDateString("en-CA", { timeZone: timezone }); // "YYYY-MM-DD"
  const dayKey   = todayStr;

  // Build midnight in Pakistan time correctly via Intl parts
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year:     "numeric",
    month:    "2-digit",
    day:      "2-digit",
  }).formatToParts(now);
  const pYear  = Number(parts.find(p => p.type === "year").value);
  const pMonth = Number(parts.find(p => p.type === "month").value);
  const pDay   = Number(parts.find(p => p.type === "day").value);

  // Midnight PKT expressed as a UTC Date
  // PKT = UTC+5, so midnight PKT = previous day 19:00 UTC
  const todayStart = new Date(Date.UTC(pYear, pMonth - 1, pDay, 0, 0, 0) - (5 * 60 * 60 * 1000));

  const currentHour = parseInt(
    now.toLocaleTimeString("en-GB", { timeZone: timezone, hour: "2-digit", hour12: false }),
    10
  );

  logger.info(`[markAbsent] Date: ${dayKey}, Hour: ${currentHour}:00 (${timezone})`);

  if (currentHour >= workEndHour) {
    logger.info(`[markAbsent] Hour ${currentHour} at/after work end ${workEndHour}. Stopping.`);
    return;
  }

  const holidaySnap = await db.collection("public_holidays").doc(dayKey).get();
  if (holidaySnap.exists) {
    logger.info(`[markAbsent] Public holiday: ${holidaySnap.data().name} — skipping.`);
    return;
  }

  const usersSnap = await db
    .collection("users")
    .where("isActive", "==", true)
    .where("role",     "==", "employee")
    .get();

  if (usersSnap.empty) {
    logger.info("[markAbsent] No active employees found.");
    return;
  }

  logger.info(`[markAbsent] Processing ${usersSnap.size} employees...`);

  const month = String(pMonth).padStart(2, "0");

  const BATCH_SIZE = 400;
  let   batch      = db.batch();
  let   batchCount = 0;
  let   processed  = 0;

  for (const userDoc of usersSnap.docs) {
    const userId    = userDoc.id;
    const archiveId = `${userId}_${pYear}_${month}`;

    // ── FIX 2: Check attendance_live using dayKey string, not Date comparison ──
    // Previously relied on isSameDay(liveDate, todayStart) which could mismatch
    // due to timezone offset on todayStart. Now we store/read the date string
    // directly from the live doc's "dateString" field (YYYY-MM-DD in PKT).
    // Falls back to the old Timestamp-based check for backward compatibility.
    const liveSnap = await db.collection("attendance_live").doc(userId).get();
    const liveData = liveSnap.exists ? liveSnap.data() : null;

    let checkedIn = false;
    if (liveData) {
      if (liveData.dateString) {
        // ── Preferred: compare string directly (no timezone ambiguity) ──
        checkedIn = liveData.dateString === dayKey;
      } else if (liveData.date) {
        // ── Fallback: old Timestamp field ──
        const liveDate = liveData.date.toDate();
        checkedIn = isSameDayInTZ(liveDate, now, timezone);
      }
    }

    // ── FIX 3: Employee never opened the app → liveData is null → checkedIn
    // remains false. This is intentional — they haven't checked in, so we
    // fall through to the absent-marking logic below. No extra guard needed.
    // The original code already handled this correctly in terms of flow, but
    // the timezone bug on todayStart could cause the archive check below to
    // look up the wrong document ID, silently skipping the employee.
    // With todayStart now correct, the archiveId and dayKey are consistent. ──

    const archiveSnap = await db.collection("attendance_archive").doc(archiveId).get();
    if (archiveSnap.exists) {
      const days = archiveSnap.data()?.days ?? {};
      if (days[dayKey]) {
        logger.debug(
          `[markAbsent] ${userId} — archive already exists (${days[dayKey].status}), skipping.`
        );
        continue;
      }
    }

    const leaveSnap = await db
      .collection("leaves")
      .where("userId",    "==", userId)
      .where("status",    "==", "approved")
      .where("startDate", "<=", admin.firestore.Timestamp.fromDate(todayStart))
      .where("endDate",   ">=", admin.firestore.Timestamp.fromDate(todayStart))
      .limit(1)
      .get();

    const leaveDoc       = leaveSnap.empty ? null : leaveSnap.docs[0];
    const leaveRequestId = leaveDoc?.id ?? null;
    const leaveDuration  = leaveDoc?.data()?.duration ?? null;

    let status = null;

    if (leaveDuration === "fullDay") {
      status = "onLeave";

    } else if (leaveDuration === "firstHalf") {
      if (skipFirstHalfLeave) {
        logger.debug(
          `[markAbsent] ${userId} — firstHalf leave, deferring to halfDay run.`
        );
        continue;
      }
      if (currentHour < halfDayCutoff) {
        logger.debug(
          `[markAbsent] ${userId} — firstHalf leave, hour ${currentHour} < halfDayCutoff ${halfDayCutoff}. Skipping.`
        );
        continue;
      }
      if (checkedIn) {
        logger.debug(`[markAbsent] ${userId} — firstHalf leave, checked in. Skipping.`);
        continue;
      }
      status = "absent";

    } else if (leaveDuration === "secondHalf") {
      if (checkedIn) {
        logger.debug(`[markAbsent] ${userId} — secondHalf leave, checked in. Skipping.`);
        continue;
      }
      status = "absent";

    } else {
      // No leave — regular employee
      if (checkedIn) {
        logger.debug(`[markAbsent] ${userId} — checked in normally. Skipping.`);
        continue;
      }
      if (currentHour < checkInCutoff) {
        logger.debug(
          `[markAbsent] ${userId} — hour ${currentHour} < cutoff ${checkInCutoff}. Skipping.`
        );
        continue;
      }
      // ── FIX 3 confirmed: liveData === null lands here with checkedIn = false
      // and currentHour >= checkInCutoff, so status = "absent" is correctly set.
      status = "absent";
    }

    if (status === null) continue;

    logger.info(
      `[markAbsent] ${userId} — marking as "${status}" ` +
      `(leaveDuration: ${leaveDuration ?? "none"}, hadLiveDoc: ${liveData !== null})`
    );

    const archiveRef = db.collection("attendance_archive").doc(archiveId);
    const record = {
      userId,
      date:              admin.firestore.Timestamp.fromDate(todayStart),
      status,
      checkInCutoff,
      halfDayCutoff,
      halfDayMark,
      workStartHour,
      workEndHour,
      breaks:            [],
      totalWorkSeconds:  0,
      totalBreakSeconds: 0,
      ...(leaveDuration  && { leaveType: leaveDuration }),
      ...(leaveRequestId && { leaveRequestId }),
    };

    batch.set(
      archiveRef,
      {
        userId,
        year:  pYear,
        month: pMonth,
        days:  { [dayKey]: record },
      },
      { merge: true }
    );

    batchCount++;
    processed++;

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      logger.info(`[markAbsent] Batch of ${batchCount} committed.`);
      batch      = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    logger.info(`[markAbsent] Final batch of ${batchCount} committed.`);
  }

  logger.info(`[markAbsent] Done. Marked ${processed} employee(s).`);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * @deprecated  Use dateString comparison instead.
 * Kept only as a fallback for old attendance_live docs that still
 * store a Timestamp rather than a dateString field.
 */
function isSameDayInTZ(dateA, dateB, timezone) {
  const strA = dateA.toLocaleDateString("en-CA", { timeZone: timezone });
  const strB = dateB.toLocaleDateString("en-CA", { timeZone: timezone });
  return strA === strB;
}