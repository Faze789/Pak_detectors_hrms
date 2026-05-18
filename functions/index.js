// functions/index.js
//
// FUNCTIONS:
//  1. markAbsentAtCutoff            → scheduled 12:01 PM Mon–Fri
//  2. markAbsentHalfDay             → scheduled 2:01 PM Mon–Fri
//  3. onBarrierCreated              → Firestore trigger on barriers/{barrierId}
//  4. onTaskNotificationCreated     → Firestore trigger on task_notifications/{notifId}
//     Sends FCM push to the lead when their task is modified.
//  5. sendDailyTaskReminders        → scheduled 9:00 AM Mon–Fri
//     Sends countdown reminders to lead + members for pending tasks.

const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

setGlobalOptions({

  maxInstances: 1,
  memory: "128MiB", // Lower memory (default is usually higher)
  cpu: 1      // Use a fraction of a CPU instead of a full one

});

// ─────────────────────────────────────────────────────────────────────────────
// RUN 1 — 12:01 PM  Mon–Fri
// Marks employees absent who have not checked in by checkInCutoff (12:00).
// Skips firstHalf-leave employees — they still have until halfDayCutoff (2 PM).
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentAtCutoff = onSchedule(
  {
    schedule: "1 15 * * 1-5",
    timeZone: "Asia/Karachi",
    maxInstances: 1,
  },
  async (_event) => {
    logger.info("[markAbsentAtCutoff] Starting noon absent run.");
    await _runMarkAbsent({ skipFirstHalfLeave: true });
  }
);



// ─── Helper: get FCM token by emp_id ────────────────────────────────────────
async function getTokenByEmpId(empId) {
  const snap = await db.collection('users')
    .where('emp_id', '==', empId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].data().fcmToken || null;
}

// ─── Helper: get FCM token by Firebase Auth UID ──────────────────────────────
async function getTokenByUid(uid) {
  const doc = await db.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

// ─── Helper: send FCM message ────────────────────────────────────────────────
async function sendFcm(token, title, body, data = {}) {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,                          // all values must be strings
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'hrms_default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
    console.log(`✅ FCM sent to token: ${token.slice(0, 20)}...`);
  } catch (err) {
    console.error(`❌ FCM error for token ${token.slice(0, 20)}:`, err.message);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TRIGGER 1: New leave request → notify each lead (or HR)
// ────────────────────────────────────────────────────────────────────────────
// --- Leave Request Created (Member -> Lead) ---
exports.onLeaveRequestCreated = onDocumentCreated(
  "request_for_leave/{requestId}",
  async (event) => {
    const data = event.data.data();
    const requestId = event.params.requestId;
    const recipients = data.leadsNotified || [];
    const name = data.name || 'An employee';
    const days = data.totalDays || 1;

    for (const empId of recipients) {
      // Add to the notification queue - Trigger 4 handles the FCM
      await db.collection("task_notifications").add({
        lead_id: empId,
        title: '📋 New Leave Request',
        body: `${name} has requested ${days} day${days > 1 ? 's' : ''} of leave`,
        type: 'leave_request',
        taskId: requestId, // Use taskId field for the reference
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

// --- Leave Request Updated (Lead -> Member) ---
exports.onLeaveRequestUpdated = onDocumentUpdated( // Or use onDocumentUpdated
  "request_for_leave/{requestId}",
  async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();

    if (before.status === after.status) return;
    if (!['approved', 'declined'].includes(after.status)) return;

    // Notify the member (after.uid)
    // We lookup the emp_id because your onTaskNotificationCreated uses lead_id (empId)
    const userSnap = await db.collection("users").doc(after.uid).get();
    const memberEmpId = userSnap.data()?.emp_id;

    if (memberEmpId) {
      await db.collection("task_notifications").add({
        lead_id: memberEmpId,
        title: after.status === 'approved' ? '✅ Leave Approved' : '❌ Leave Declined',
        body: after.status === 'approved'
          ? 'Your leave request is approved.'
          : `Declined: ${after.rejectionReason || 'No reason provided.'}`,
        type: 'leave_response',
        taskId: event.params.requestId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// RUN 2 — 2:01 PM  Mon–Fri
// Marks firstHalf-leave employees absent if they still haven't checked in
// after halfDayCutoff. Also catches anyone missed by the noon run.
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentHalfDay = onSchedule(
  {
    schedule: "1 14 * * 1-5",
    timeZone: "Asia/Karachi",
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
  {
    document: "barriers/{barrierId}",
    memory: "128MiB",
    cpu: "gcf_gen1",     // ≈ 0.083 vCPU @ 128MiB — opts out of setGlobalOptions cpu:1
    maxInstances: 1,
    concurrency: 1,
  },
  async (event) => {
    const barrier = event.data.data();
    const barrierId = event.params.barrierId;

    logger.info(`[onBarrierCreated] New barrier: ${barrierId}`);

    const {
      employeeName = "An employee",
      recipientId = null,
      ccIds = [],
      description = "",
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
            body: `${employeeName} reported a barrier: ${shortDesc}`,
          },
          data: {
            type: "barrier_report",
            barrierId,
            reporterId: barrier.employeeId ?? "",
            reporterName: employeeName,
            description,
            timestamp: new Date().toISOString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "barrier_reports",
              sound: "default",
              priority: "high",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: "⚠ Barrier Report",
                  body: `${employeeName} reported a barrier: ${shortDesc}`,
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
      const uid = ccIds[i];
      try {
        const result = await messaging.send({
          token,
          data: {
            type: "barrier_report_cc",
            barrierId,
            reporterId: barrier.employeeId ?? "",
            reporterName: employeeName,
            description,
            timestamp: new Date().toISOString(),
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
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `[onBarrierCreated] Done. ` +
      `${sendResults.filter((r) => r.status === "sent").length} sent, ` +
      `${sendResults.filter((r) => r.status === "failed").length} failed.`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// TASK NOTIFICATION — triggers when a task_notifications doc is created
// Sends FCM push to the lead when their task is modified.
// ─────────────────────────────────────────────────────────────────────────────
exports.onTaskNotificationCreated = onDocumentCreated(
  {
    document: "task_notifications/{notifId}",
    memory: "128MiB",
    cpu: "gcf_gen1",
    maxInstances: 1,
    concurrency: 1,
  },
  async (event) => {
    const notif = event.data.data();
    const notifId = event.params.notifId;

    logger.info(`[onTaskNotificationCreated] New task notification: ${notifId}`);

    const leadEmpId = (notif.lead_id ?? "").toLowerCase();
    if (!leadEmpId) {
      logger.warn("[onTaskNotificationCreated] No lead_id — skipping.");
      return;
    }

    // Find the lead's user doc by emp_id (case-insensitive)
    const usersSnap = await db.collection("users").get();
    let leadToken = null;
    let leadUid = null;
    for (const doc of usersSnap.docs) {
      const data = doc.data();
      if ((data.emp_id ?? "").toLowerCase() === leadEmpId) {
        leadToken = data.fcmToken ?? null;
        leadUid = doc.id;
        break;
      }
    }

    if (!leadToken) {
      logger.warn(`[onTaskNotificationCreated] No FCM token for lead ${notif.lead_id}.`);
      return;
    }

    const title = notif.title ?? "Task Updated";
    const body = notif.body ?? "One of your tasks was modified.";

    try {
      const result = await messaging.send({
        token: leadToken,
        notification: { title, body },
        data: {
          type: "task_modified",
          taskId: notif.taskId ?? "",
          modifiedBy: notif.modifiedBy ?? "",
          timestamp: new Date().toISOString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "task_updates",
            sound: "default",
            priority: "high",
          },
        },
        apns: {
          payload: {
            aps: { alert: { title, body }, sound: "default" },
          },
          headers: { "apns-priority": "10" },
        },
      });
      logger.info(`[onTaskNotificationCreated] Lead ${leadUid} notified. FCM ID: ${result}`);
    } catch (e) {
      logger.error(`[onTaskNotificationCreated] Failed: ${e.message}`);
      if (
        e.code === "messaging/registration-token-not-registered" ||
        e.code === "messaging/invalid-registration-token"
      ) {
        await db.collection("users").doc(leadUid).update({ fcmToken: null });
        logger.info(`[onTaskNotificationCreated] Cleared stale token for ${leadUid}`);
      }
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// DAILY TASK REMINDERS — 9:00 AM Mon–Fri
// Sends countdown notifications to lead + members for pending tasks.

// ─────────────────────────────────────────────────────────────────────────────

// 0    9    *    *    1-5
// │    │    │    │    │
// │    │    │    │    └── Monday to Friday
// │    │    │    └────── Every month
// │    │    └────────── Every day of month
// │    └────────────── 9 AM
// └────────────────── Minute 0

// Final Meaning

// 👉 Runs at 9:00 AM, Monday to Friday, every week
exports.sendDailyTaskReminders = onSchedule(
  {
    schedule: "0 9 * * 1-5",
    timeZone: "Asia/Karachi",
    maxInstances: 1,
  },
  async (_event) => {
    logger.info("[sendDailyTaskReminders] Starting daily reminder run.");

    const tasksSnap = await db.collection("tasks")
      .where("status", "==", "pending")
      .get();

    if (tasksSnap.empty) {
      logger.info("[sendDailyTaskReminders] No pending tasks found.");
      return;
    }

    logger.info(`[sendDailyTaskReminders] Found ${tasksSnap.size} pending task(s).`);

    const now = new Date();
    let notifCount = 0;

    for (const taskDoc of tasksSnap.docs) {
      const task = taskDoc.data();
      const taskId = taskDoc.id;
      const deadline = task.deadline;

      if (!deadline) continue;

      const deadlineDate = deadline.toDate();
      const diffMs = deadlineDate.getTime() - now.getTime();
      const remainingDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      const title = task.title || "Untitled Task";
      let reminderText;
      if (remainingDays > 0) {
        reminderText = `"${title}" — ${remainingDays} day${remainingDays === 1 ? "" : "s"} remaining`;
      } else if (remainingDays === 0) {
        reminderText = `"${title}" is due today!`;
      } else {
        reminderText = `"${title}" is overdue by ${-remainingDays} day${remainingDays === -1 ? "" : "s"}`;
      }

      // Collect all recipient emp_ids: lead + members
      const recipientEmpIds = new Set();

      const leadId = (task.lead_id || "").trim();
      if (leadId) recipientEmpIds.add(leadId);

      const members = task.members || {};
      for (const key of Object.keys(members)) {
        const m = members[key];
        if (m && m.emp_id) {
          recipientEmpIds.add(m.emp_id);
        }
      }

      // Create a task_notification doc for each recipient
      for (const empId of recipientEmpIds) {
        await db.collection("task_notifications").add({
          lead_id: empId,
          taskId: taskId,
          title: "Task Reminder",
          body: reminderText,
          type: "daily_reminder",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        notifCount++;
      }
    }

    logger.info(`[sendDailyTaskReminders] Done. Created ${notifCount} reminder notification(s).`);
  }
);

// (Legacy 8:50/9:00/9:20/9:40/10:00 check-in reminders and the 5:50 PM
// check-out reminder were removed — superseded by `checkInReminders` and
// `checkOutReminders` further down. Removing the duplicates also drops their
// per-service CPU allocation, which is required to stay within the regional
// `CpuAllocPerProjectRegion` quota on the free tier.)

// ─────────────────────────────────────────────────────────────────────────────
// markAbsentAtSixPM — 6:01 PM Mon–Fri, Asia/Karachi
// Final cutoff: anyone who hasn't checked in by 6 PM is marked absent.
// (In addition to the existing noon/2 PM cutoffs.)
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentAtSixPM = onSchedule(
  {
    schedule: "1 18 * * 1-5",
    timeZone: "Asia/Karachi",
    maxInstances: 1,
  },
  async (_event) => {
    const dateKey = new Date().toLocaleDateString("en-CA", {
      timeZone: "Asia/Karachi",
    });

    const usersSnap = await db.collection("users")
      .where("role", "in", ["employee", "project lead"])
      .get();

    let count = 0;
    for (const userDoc of usersSnap.docs) {
      const liveRef = db.collection("attendance_live").doc(userDoc.id);
      const live = (await liveRef.get()).data();

      // Already checked in today → skip
      if (live && live.dateString === dateKey && live.checkInTime) continue;

      // Already marked absent for today → skip
      if (live && live.dateString === dateKey && live.status === "absent") continue;

      await liveRef.set(
        {
          userId: userDoc.id,
          dateString: dateKey,
          status: "absent",
          checkInTime: null,
          checkOutTime: null,
        },
        { merge: true }
      );
      count++;
    }
    logger.info(`[markAbsentAtSixPM] Marked ${count} employees absent.`);
  }
);

exports.cleanStaleLiveRecords = onSchedule(
  {
    schedule: "59 23 * * *",
    timeZone: "Asia/Karachi",
    memory: "128MiB",
    cpu: "gcf_gen1",     // ≈ 0.083 vCPU @ 128MiB — opts out of setGlobalOptions cpu:1
    maxInstances: 1,
    concurrency: 1,
  },
  async () => {
    const todayKey = new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Karachi" });

    // Stream the live collection one doc at a time so we don't materialize
    // every employee's live record in memory at once. Archive + delete are
    // grouped into batches of BATCH_SIZE (each batch counts each (archive
    // set + live delete) pair as 2 writes, so we keep BATCH_SIZE * 2 ≤ 500).
    const BATCH_SIZE = 200;
    let writeBatch = db.batch();
    let pending = 0;
    let cleaned = 0;

    const flush = async () => {
      if (pending > 0) {
        await writeBatch.commit();
        writeBatch = db.batch();
        pending = 0;
      }
    };

    const autoClosedAt = new Date().toISOString();

    for await (const doc of db.collection("attendance_live").stream()) {
      const data = doc.data();
      if (data.dateString !== todayKey) continue;
      if (data.checkOutTime != null) continue;

      const userId = doc.id;
      const archiveRef = db.collection("attendance_archive").doc(
        `${userId}_${todayKey.slice(0, 4)}_${todayKey.slice(5, 7)}`
      );
      writeBatch.set(
        archiveRef,
        { userId, days: { [todayKey]: { ...data, autoClosedAt } } },
        { merge: true }
      );
      writeBatch.delete(doc.ref);
      pending += 2;
      cleaned++;
      if (pending >= BATCH_SIZE * 2) await flush();
    }
    await flush();
    logger.info(`[cleanStaleLiveRecords] Archived & cleared ${cleaned} stale live record(s).`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// adminSetEmployeePassword — HR-only callable to set/reset an employee's
// Firebase Auth password by uid. Also stores the plaintext password on the
// users/{uid} doc so HR can view it later (per workplace policy).
//
// Caller must be signed in AND have role == 'hr' in their users/{callerUid} doc.
// Returns { success: true } on success, throws HttpsError otherwise.
// ─────────────────────────────────────────────────────────────────────────────
exports.adminSetEmployeePassword = onCall(async (request) => {
  // 1. Verify caller is signed in
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  // 2. Verify caller is HR
  const callerDoc = await db.collection("users").doc(callerUid).get();
  const callerRole = (callerDoc.data()?.role || "").toLowerCase();
  if (callerRole !== "hr") {
    throw new HttpsError(
      "permission-denied",
      "Only HR can reset employee passwords."
    );
  }

  // 3. Validate input
  const { uid, newPassword } = request.data || {};
  if (!uid || typeof uid !== "string") {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (!newPassword || typeof newPassword !== "string") {
    throw new HttpsError("invalid-argument", "newPassword is required.");
  }
  if (newPassword.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  try {
    // 4. Update Firebase Auth password
    await admin.auth().updateUser(uid, { password: newPassword });

    // 5. Store plaintext on Firestore doc so HR can view it later
    await db.collection("users").doc(uid).update({
      lastSetPassword: newPassword,
      passwordSetAt: admin.firestore.FieldValue.serverTimestamp(),
      passwordSetByUid: callerUid,
    });

    // 6. Notify the employee in-app
    const targetDoc = await db.collection("users").doc(uid).get();
    const empId = (targetDoc.data()?.emp_id || "").toString();
    if (empId) {
      await db.collection("task_notifications").add({
        lead_id: empId,
        title: "Password Reset by HR",
        body: "Your account password was reset. Contact HR for the new password.",
        type: "task",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
    }

    logger.info(
      `[adminSetEmployeePassword] HR ${callerUid} reset password for ${uid}`
    );
    return { success: true };
  } catch (err) {
    logger.error(`[adminSetEmployeePassword] Failed: ${err.message}`);
    if (err.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No Firebase Auth user with that uid.");
    }
    throw new HttpsError("internal", err.message || "Unknown error");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Core absent logic — called by both scheduled functions
// ─────────────────────────────────────────────────────────────────────────────
async function _runMarkAbsent({ skipFirstHalfLeave }) {

  let checkInCutoff = 15;
  let halfDayCutoff = 14;
  let halfDayMark = 13;
  let workStartHour = 9;
  let workEndHour = 18;
  let timezone = "Asia/Karachi";

  try {
    const settingsSnap = await db
      .collection("office_settings")
      .doc("timings")
      .get();

    if (settingsSnap.exists) {
      const data = settingsSnap.data();
      if (data.checkInCutoff != null) checkInCutoff = data.checkInCutoff;
      if (data.halfDayCutoff != null) halfDayCutoff = data.halfDayCutoff;
      if (data.halfDayMark != null) halfDayMark = data.halfDayMark;
      if (data.workStartHour != null) workStartHour = data.workStartHour;
      if (data.workEndHour != null) workEndHour = data.workEndHour;
      if (data.timezone != null) timezone = data.timezone;

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
  const dayKey = todayStr;

  // Build midnight in Pakistan time correctly via Intl parts
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const pYear = Number(parts.find(p => p.type === "year").value);
  const pMonth = Number(parts.find(p => p.type === "month").value);
  const pDay = Number(parts.find(p => p.type === "day").value);

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
    .where("role", "==", "employee")
    .get();

  if (usersSnap.empty) {
    logger.info("[markAbsent] No active employees found.");
    return;
  }

  logger.info(`[markAbsent] Processing ${usersSnap.size} employees...`);

  const month = String(pMonth).padStart(2, "0");

  const BATCH_SIZE = 400;
  let batch = db.batch();
  let batchCount = 0;
  let processed = 0;

  for (const userDoc of usersSnap.docs) {
    const userId = userDoc.id;
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
      .where("userId", "==", userId)
      .where("status", "==", "approved")
      .where("startDate", "<=", admin.firestore.Timestamp.fromDate(todayStart))
      .where("endDate", ">=", admin.firestore.Timestamp.fromDate(todayStart))
      .limit(1)
      .get();

    const leaveDoc = leaveSnap.empty ? null : leaveSnap.docs[0];
    const leaveRequestId = leaveDoc?.id ?? null;
    const leaveDuration = leaveDoc?.data()?.duration ?? null;

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
      date: admin.firestore.Timestamp.fromDate(todayStart),
      status,
      checkInCutoff,
      halfDayCutoff,
      halfDayMark,
      workStartHour,
      workEndHour,
      breaks: [],
      totalWorkSeconds: 0,
      totalBreakSeconds: 0,
      ...(leaveDuration && { leaveType: leaveDuration }),
      ...(leaveRequestId && { leaveRequestId }),
    };

    batch.set(
      archiveRef,
      {
        userId,
        year: pYear,
        month: pMonth,
        days: { [dayKey]: record },
      },
      { merge: true }
    );

    batchCount++;
    processed++;

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      logger.info(`[markAbsent] Batch of ${batchCount} committed.`);
      batch = db.batch();
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

// ─────────────────────────────────────────────────────────────────────────────
// CHECK-IN REMINDERS  — Mon–Fri Asia/Karachi
//
// Spec: every 15 minutes from 8:50 AM until 11:00 AM, nudge employees who
// haven't checked in yet today.
//
// The cron pattern `0,5,20,35,50 8,9,10,11 * * 1-5` fires at slightly more
// times than the spec wants (it includes 8:00/8:05/8:20/8:35, 11:05/etc.) —
// we filter those out inside via the `VALID_CHECKIN_REMINDERS` map. Keeping
// one Cloud Function with internal filtering is cheaper than registering a
// handful of separate functions for each individual cron line.
//
// Each reminder is written to `task_notifications`, which the existing
// `onTaskNotificationCreated` trigger turns into FCM push + in-app local
// notification (no double-wiring required).
// ─────────────────────────────────────────────────────────────────────────────

const VALID_CHECKIN_REMINDERS = {
  8: [50],
  9: [5, 20, 35, 50],
  10: [5, 20, 35, 50],
  11: [0],
};

function _karachiHourMinute() {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Karachi',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const h = parseInt(parts.find(p => p.type === 'hour').value, 10);
  const m = parseInt(parts.find(p => p.type === 'minute').value, 10);
  return { hour: h, minute: m };
}

function _todayKeyKarachi() {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Karachi' });
}

exports.checkInReminders = onSchedule(
  {
    schedule: '0,5,20,35,50 8,9,10,11 * * 1-5',
    timeZone: 'Asia/Karachi',
    memory: '128MiB',
    cpu: 'gcf_gen1',   // ≈ 0.083 vCPU — opts out of setGlobalOptions cpu:1
    maxInstances: 1,
    concurrency: 1,
  },
  async () => {
    const { hour, minute } = _karachiHourMinute();
    const validMinutes = VALID_CHECKIN_REMINDERS[hour] || [];
    if (!validMinutes.includes(minute)) {
      logger.info(
        `[checkInReminders] ${hour}:${String(minute).padStart(2, '0')} ` +
        `not in spec — skipping.`,
      );
      return;
    }

    const todayKey = _todayKeyKarachi();
    logger.info(`[checkInReminders] Running for ${todayKey} at ${hour}:${minute}`);

    // Memory-budget note: we stay under the 128 MiB function limit by
    // streaming the `users` collection one doc at a time (never holding the
    // full snapshot in RAM) and flushing notification writes in batches of
    // BATCH_SIZE instead of awaiting one .add() per user.
    const BATCH_SIZE = 100;
    let queued = 0;
    let writeBatch = db.batch();
    let pending = 0;

    const flush = async () => {
      if (pending > 0) {
        await writeBatch.commit();
        writeBatch = db.batch();
        pending = 0;
      }
    };

    const body = `It's ${hour}:${String(minute).padStart(2, '0')} — please check in for today.`;

    for await (const userDoc of db.collection('users').stream()) {
      const u = userDoc.data();
      const role = (u.role || '').toString().toLowerCase();
      const empId = (u.emp_id || '').toString();
      if (!empId) continue;
      if (role === 'hr') continue;          // HR doesn't need this nudge
      if (u.disabled === true) continue;

      const liveDoc = await db.collection('attendance_live').doc(userDoc.id).get();
      if (liveDoc.exists) {
        const live = liveDoc.data();
        // Already checked in today → skip.
        if ((live.dateString || '') === todayKey && live.checkInTime) continue;
      }

      const notifRef = db.collection('task_notifications').doc();
      writeBatch.set(notifRef, {
        lead_id: empId,
        title: '⏰ Check-in Reminder',
        body,
        type: 'attendance',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
      pending++;
      queued++;
      if (pending >= BATCH_SIZE) await flush();
    }
    await flush();
    logger.info(`[checkInReminders] Queued ${queued} reminder(s).`);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// CHECK-OUT REMINDERS  — Mon–Fri Asia/Karachi
//
// Spec: every 5 minutes from 6:05 PM to 6:30 PM, nudge employees who are
// checked in but haven't checked out yet. The 6:30 PM tick is also the
// hard cutoff — the client-side check-out button is disabled after this
// time (see lib/views/employee_views/attendance_screen.dart).
// ─────────────────────────────────────────────────────────────────────────────

exports.checkOutReminders = onSchedule(
  {
    schedule: '5,10,15,20,25,30 18 * * 1-5',
    timeZone: 'Asia/Karachi',
    memory: '128MiB',
    cpu: 'gcf_gen1',
    maxInstances: 1,
    concurrency: 1,
  },
  async () => {
    const { hour, minute } = _karachiHourMinute();
    const todayKey = _todayKeyKarachi();
    logger.info(`[checkOutReminders] Running for ${todayKey} at ${hour}:${minute}`);

    // See checkInReminders for the memory-budget rationale: stream users +
    // batch writes to stay inside the 128 MiB function limit.
    const BATCH_SIZE = 100;
    const isFinal = (minute === 30);
    const title = isFinal ? '🚪 Final Check-out Reminder' : '🕕 Check-out Reminder';
    const body = isFinal
      ? 'Last reminder — please check out now. After 6:30 PM the check-out button will be disabled.'
      : `It's ${hour}:${String(minute).padStart(2, '0')} — please check out for the day.`;

    let queued = 0;
    let writeBatch = db.batch();
    let pending = 0;

    const flush = async () => {
      if (pending > 0) {
        await writeBatch.commit();
        writeBatch = db.batch();
        pending = 0;
      }
    };

    for await (const userDoc of db.collection('users').stream()) {
      const u = userDoc.data();
      const role = (u.role || '').toString().toLowerCase();
      const empId = (u.emp_id || '').toString();
      if (!empId) continue;
      if (role === 'hr') continue;
      if (u.disabled === true) continue;

      const liveDoc = await db.collection('attendance_live').doc(userDoc.id).get();
      if (!liveDoc.exists) continue;
      const live = liveDoc.data();
      if ((live.dateString || '') !== todayKey) continue;
      if (!live.checkInTime) continue;      // never checked in → no checkout
      if (live.checkOutTime) continue;      // already checked out → done

      const notifRef = db.collection('task_notifications').doc();
      writeBatch.set(notifRef, {
        lead_id: empId,
        title,
        body,
        type: 'attendance',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
      pending++;
      queued++;
      if (pending >= BATCH_SIZE) await flush();
    }
    await flush();
    logger.info(`[checkOutReminders] Queued ${queued} reminder(s).`);
  },
);
