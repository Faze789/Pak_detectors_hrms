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
  // maxInstances stays at 1 globally because the `CpuAllocPerProjectRegion`
  // quota is 20 vCPU. With ~16 functions and cpu:1, raising maxInstances
  // multiplies the regional draw past the cap and breaks the next deploy.
  // If a specific function needs concurrency (e.g. onTaskNotificationCreated
  // under bursty load), override it per-function — or request a regional
  // CPU quota increase in Cloud Console → IAM → Quotas first.
  // maxInstances: 1,

  // 512MiB is generous on Blaze (~10 GB-seconds/month per function — the
  // Blaze free tier covers 400,000 GB-s) and gives ~380MiB of working
  // memory above the firebase-admin SDK baseline. At 256MiB we had
  // ~125MiB of working memory which was tight for any batched write or
  // larger Firestore snapshot. At 128MiB (older config) the container
  // OOMed on cold start — confirmed in May 2026 logs.
  // memory: "512MiB",

  // cpu stays at 1. Bumping to 2 would double our regional draw
  // (16 functions × 2 vCPU = 32 vCPU > 20 vCPU quota). I/O is the
  // bottleneck for these functions anyway, not compute.
  // cpu: 1,
});

// ─────────────────────────────────────────────────────────────────────────────
// HR ALERT PIPELINE
//
// `logHrAlert(...)` writes a doc into `hr_alerts` describing a notification
// failure (FCM send error, missing recipient token, cron crash, etc.). A
// trigger `onHrAlertCreated` further down fans the alert out as a push
// notification to every HR user, including the human-readable reason so
// HR can act on it (re-add a missing token, ping the on-call engineer, etc.)
// without needing to open Cloud Logs.
//
// We log alerts in a try/catch — if `hr_alerts` itself errors, we just
// surface to Cloud Logs and move on; otherwise we'd risk crashing the
// caller in their own error-handling path.
// ─────────────────────────────────────────────────────────────────────────────
async function logHrAlert({ type, summary, details, relatedTo }) {
  try {
    const payload = {
      type: String(type || 'unknown'),
      summary: String(summary || 'A notification could not be delivered.'),
      details:
        typeof details === 'string'
          ? details
          : details
            ? JSON.stringify(details)
            : '',
      relatedTo: relatedTo || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection('hr_alerts').add(payload);
  } catch (e) {
    // Don't crash the caller — surface to Cloud Logs only.
    logger.error(`[logHrAlert] Failed to record HR alert: ${e.message}`);
  }
}

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
    // Inherits memory/cpu/maxInstances from setGlobalOptions.
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

        const stale =
          e.code === "messaging/registration-token-not-registered" ||
          e.code === "messaging/invalid-registration-token";
        if (stale) {
          await db.collection("users").doc(recipientId).update({ fcmToken: null });
          logger.info(`[onBarrierCreated] Cleared stale token for ${recipientId}`);
          // SPAM SUPPRESSION: routine token rotation, no HR alert.
        } else {
          await logHrAlert({
            type: 'fcm_send_failed',
            summary: `Barrier alert to ${recipientId} failed.`,
            details:
              `FCM error code: ${e.code || '(none)'}\n` +
              `FCM error message: ${e.message}\n` +
              `Barrier ID: ${barrierId}\n` +
              `Reporter: ${employeeName}\n` +
              `Action taken: none.`,
            relatedTo: { barrierId, recipientId, role: 'recipient' },
          });
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

        const stale =
          e.code === "messaging/registration-token-not-registered" ||
          e.code === "messaging/invalid-registration-token";
        if (stale) {
          await db.collection("users").doc(uid).update({ fcmToken: null });
          logger.info(`[onBarrierCreated] Cleared stale token for ${uid}`);
          // SPAM SUPPRESSION: routine token rotation, no HR alert.
        } else {
          await logHrAlert({
            type: 'fcm_send_failed',
            summary: `Barrier CC alert to ${uid} failed.`,
            details:
              `FCM error code: ${e.code || '(none)'}\n` +
              `FCM error message: ${e.message}\n` +
              `Barrier ID: ${barrierId}\n` +
              `Reporter: ${employeeName}\n` +
              `Action taken: none.`,
            relatedTo: { barrierId, ccUid: uid, role: 'cc' },
          });
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
    // Inherits memory/cpu/maxInstances from setGlobalOptions.
    concurrency: 1,
  },
  async (event) => {
    const notif = event.data.data();
    const notifId = event.params.notifId;

    logger.info(`[onTaskNotificationCreated] New task notification: ${notifId}`);

    const leadEmpId = (notif.lead_id ?? "").toLowerCase();
    if (!leadEmpId) {
      logger.warn("[onTaskNotificationCreated] No lead_id — skipping.");
      // Skip HR alert for self-referential alerts (avoid loops).
      if ((notif.type ?? "") !== 'hr_alert') {
        await logHrAlert({
          type: 'missing_lead_id',
          summary: 'A task notification had no recipient (`lead_id`).',
          details:
            `task_notifications/${notifId} was written with no lead_id ` +
            `field. The trigger has no recipient to push to. Likely cause: ` +
            `a writer in client/cron code forgot to set lead_id.`,
          relatedTo: { notifId, notifType: notif.type ?? null },
        });
      }
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
      // SPAM SUPPRESSION:
      //   • `no_fcm_token` (user exists, no token saved) is a routine
      //     client-side issue — recipient simply hasn't logged in lately
      //     or hasn't granted notification permission. Logging this to
      //     hr_alerts spammed HR every time a cron tried to notify a
      //     logged-out employee. We now only surface to Cloud Logs.
      //   • `recipient_not_found` (no user record at all for this emp_id)
      //     IS still a real data-integrity issue — usually points at a
      //     bad writer or a deleted-but-still-referenced user — so we
      //     keep alerting for that path.
      if (!leadUid && (notif.type ?? "") !== 'hr_alert') {
        await logHrAlert({
          type: 'recipient_not_found',
          summary: `Couldn't notify ${notif.lead_id} — no matching user record.`,
          details:
            `No user document in the users collection has an emp_id ` +
            `matching "${notif.lead_id}". Either the lead_id is wrong ` +
            `on the writer side, or the user was deleted.`,
          relatedTo: {
            notifId,
            leadEmpId: notif.lead_id,
            notifTitle: notif.title ?? null,
          },
        });
      }
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
            // Must match the AndroidNotificationChannel id created on the
            // client in lib/main.dart (`_taskChannel`). On Android 8+ a
            // notification whose channelId is not registered on the device
            // is silently dropped — which is why all check-in / check-out /
            // task reminders disappeared before this fix.
            channelId: "task_notifications",
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
      const stale =
        e.code === "messaging/registration-token-not-registered" ||
        e.code === "messaging/invalid-registration-token";
      if (stale) {
        await db.collection("users").doc(leadUid).update({ fcmToken: null });
        logger.info(`[onTaskNotificationCreated] Cleared stale token for ${leadUid}`);
        // SPAM SUPPRESSION: stale tokens are a normal outcome of a
        // device being signed out / reinstalled. We've already cleared
        // it so the recipient will re-register on next app open. No
        // value in pushing an HR alert for routine token rotation.
        return;
      }
      // Genuine FCM send failure (network, quota, etc.) — surface to HR.
      if ((notif.type ?? "") !== 'hr_alert') {
        await logHrAlert({
          type: 'fcm_send_failed',
          summary: `Failed to deliver a notification to ${notif.lead_id}.`,
          details:
            `FCM error code: ${e.code || '(none)'}\n` +
            `FCM error message: ${e.message}\n` +
            `Notification title: ${notif.title ?? '(no title)'}\n` +
            `Action taken: none — the notification could not be delivered.`,
          relatedTo: {
            notifId,
            leadEmpId: notif.lead_id,
            leadUid,
            notifTitle: notif.title ?? null,
          },
        });
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

// ─────────────────────────────────────────────────────────────────────────────
// onHrAlertCreated — runs on every new doc in `hr_alerts`. Fans the alert
// out to every HR user as both an in-app `task_notifications` entry AND a
// direct FCM push. Title is "⚠ Notification issue", body is the alert's
// `summary`, the data payload carries `details` so the in-app screen can
// show the full reason.
//
// To prevent loops: in-app fan-out goes through `task_notifications` with
// type='hr_alert'. The `onTaskNotificationCreated` trigger SKIPS logging
// another HR alert when it sees `type==='hr_alert'`, so a failed
// alert-delivery never re-triggers another alert.
// ─────────────────────────────────────────────────────────────────────────────
exports.onHrAlertCreated = onDocumentCreated(
  {
    document: "hr_alerts/{alertId}",
    concurrency: 1,
  },
  async (event) => {
    const alert = event.data.data();
    const alertId = event.params.alertId;
    const summary = alert.summary || 'A notification could not be delivered.';
    const details = alert.details || '';
    const alertType = alert.type || 'unknown';

    logger.info(`[onHrAlertCreated] ${alertId} (${alertType}) → fanning to HR`);

    const hrSnap = await db.collection('users')
      .where('role', '==', 'hr')
      .get();

    if (hrSnap.empty) {
      logger.warn(`[onHrAlertCreated] No HR users to notify for alert ${alertId}.`);
      return;
    }

    let pushed = 0;
    let skippedNoToken = 0;
    let failed = 0;
    for (const doc of hrSnap.docs) {
      const u = doc.data();
      const hrEmpId = (u.emp_id || '').toString();
      const token = u.fcmToken;

      // Always enqueue an in-app notification so HR has it on the
      // notifications screen even if FCM push is missing.
      if (hrEmpId) {
        try {
          await db.collection('task_notifications').add({
            lead_id: hrEmpId,
            title: '⚠ Notification issue',
            body: summary,
            type: 'hr_alert',
            alertId,
            alertType,
            details: details.substring(0, 800),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          });
        } catch (e) {
          // Non-fatal — we still try FCM below.
          logger.warn(
            `[onHrAlertCreated] Failed to enqueue in-app for HR ${doc.id}: ${e.message}`,
          );
        }
      }

      if (!token) {
        skippedNoToken++;
        continue;
      }
      try {
        await messaging.send({
          token,
          notification: {
            title: '⚠ System alert',
            body: summary,
          },
          data: {
            type: 'hr_alert',
            alertId,
            alertType,
            // FCM data payload cap is 4 KB total — keep details short.
            details: details.substring(0, 1000),
          },
          android: {
            priority: 'high',
            notification: {
              // Dedicated channel for genuine system-failure alerts.
              // MUST match the Android channel created on the client in
              // lib/main.dart (_hrSystemAlertChannel). Routine FCM-token
              // hygiene NO LONGER routes through this trigger — only
              // unhandled errors / data integrity issues do — so HR
              // shouldn't see noise here.
              channelId: 'hr_system_alerts',
              // `hr_alert` is the custom sound the client channel
              // registers; if that asset is absent on the device, the
              // OS falls back to the channel's default sound.
              sound: 'hr_alert',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                alert: { title: '⚠ System alert', body: summary },
                sound: 'hr_alert.caf',
              },
            },
            headers: { 'apns-priority': '10' },
          },
        });
        pushed++;
      } catch (e) {
        failed++;
        const stale =
          e.code === 'messaging/registration-token-not-registered' ||
          e.code === 'messaging/invalid-registration-token';
        if (stale) {
          await db.collection('users').doc(doc.id).update({ fcmToken: null });
        }
        // IMPORTANT: do NOT call logHrAlert here — would loop.
        logger.warn(
          `[onHrAlertCreated] FCM send to HR ${doc.id} failed: ${e.code || ''} ${e.message}`,
        );
      }
    }
    logger.info(
      `[onHrAlertCreated] ${alertId} — pushed ${pushed} HR, ` +
      `skipped ${skippedNoToken} (no token), ${failed} failed.`
    );
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// onWorkHourOverrideCreated — fires when HR adds a custom-hours override
// for an employee. Writes a `task_notifications` doc so the affected
// employee gets both:
//   • a push notification (via the existing onTaskNotificationCreated
//     trigger that reads task_notifications),
//   • a persistent row in their in-app notifications history (since
//     task_notifications IS that collection).
//
// We don't fire a HR alert on failure here — a missing emp_id is a data
// hygiene issue HR can spot from the Schedules screen itself. We DO log
// it to Cloud Logs.
// ─────────────────────────────────────────────────────────────────────────────
exports.onWorkHourOverrideCreated = onDocumentCreated(
  {
    document: "work_hour_overrides/{overrideId}",
    concurrency: 1,
  },
  async (event) => {
    const o = event.data.data();
    const overrideId = event.params.overrideId;
    const userId = (o.userId || "").toString();
    if (!userId) {
      logger.warn(
        `[onWorkHourOverrideCreated] ${overrideId} has no userId — skipping.`,
      );
      return;
    }

    // Resolve recipient's emp_id (task_notifications routes by emp_id).
    let empId = "";
    let employeeName = "";
    try {
      const userSnap = await db.collection("users").doc(userId).get();
      if (userSnap.exists) {
        const u = userSnap.data();
        empId = (u.emp_id || "").toString();
        employeeName = (u.name || "").toString();
      }
    } catch (e) {
      logger.warn(
        `[onWorkHourOverrideCreated] users/${userId} lookup failed: ${e.message}`,
      );
    }
    if (!empId) {
      logger.warn(
        `[onWorkHourOverrideCreated] No emp_id on users/${userId} — skipping.`,
      );
      return;
    }

    // Build human-readable date + time labels.
    const startDate = o.startDate?.toDate?.();
    const endDate = o.endDate?.toDate?.();
    const fmt = (d, full) =>
      new Intl.DateTimeFormat("en-US", {
        timeZone: "Asia/Karachi",
        day: "numeric",
        month: "short",
        ...(full && { year: "numeric" }),
      }).format(d);
    let dateLabel = "";
    if (startDate && endDate) {
      const sameDay =
        startDate.toISOString().slice(0, 10) ===
        endDate.toISOString().slice(0, 10);
      dateLabel = sameDay
        ? fmt(startDate, true)
        : `${fmt(startDate, false)} → ${fmt(endDate, true)}`;
    }

    const fmtTime = (h, m) => {
      const hh = h ?? 0;
      const mm = m ?? 0;
      const period = hh >= 12 ? "PM" : "AM";
      const hour = hh === 0 ? 12 : hh > 12 ? hh - 12 : hh;
      return `${hour}:${String(mm).padStart(2, "0")} ${period}`;
    };
    const startTimeLabel = fmtTime(o.workStartHour, o.workStartMinute);
    const endTimeLabel = fmtTime(o.workEndHour, o.workEndMinute);

    const reason = (o.reason || "").toString().trim();
    const reasonSuffix = reason ? ` Reason: ${reason}.` : "";
    const body =
      `Your work hours for ${dateLabel || "the assigned dates"} are now ` +
      `${startTimeLabel} – ${endTimeLabel}.${reasonSuffix}`;

    await db.collection("task_notifications").add({
      lead_id: empId,
      title: "📅 Custom schedule set",
      body,
      // type=schedule_override is what the in-app notifications screen can
      // use to render a custom icon / deep-link to the Schedules detail.
      type: "schedule_override",
      overrideId,
      // Surfacing the raw shift data lets the client render a chip without
      // re-fetching the override doc.
      startDateKey: o.startDateKey ?? null,
      endDateKey: o.endDateKey ?? null,
      workStartHour: o.workStartHour ?? null,
      workStartMinute: o.workStartMinute ?? null,
      workEndHour: o.workEndHour ?? null,
      workEndMinute: o.workEndMinute ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

    logger.info(
      `[onWorkHourOverrideCreated] ${overrideId} → notified ${empId} ` +
      `(${employeeName || "(no name)"}): ${dateLabel} ${startTimeLabel}-${endTimeLabel}`,
    );
  },
);

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
// markAbsentAtSixPM — 6:30 PM Mon–Fri, Asia/Karachi (the post-shift cutoff)
//
// Spec: any employee who has neither checked in NOR checked out by 6:30 PM
// on a weekday is marked absent in `attendance_archive`. Weekends, public
// holidays, and days covered by an approved leave are skipped.
//
// Notes:
//   • Writes go to `attendance_archive/{userId}_{year}_{MM}` under the
//     `days.{YYYY-MM-DD}` key, matching the shape produced by
//     `AttendanceService.archiveAttendance` so the HR Monthly screen and
//     payroll see a normal absent day.
//   • The function streams users + batches writes to stay inside the 128 MiB
//     memory budget and lean CPU allocation — same pattern as
//     `checkInReminders` / `checkOutReminders` / `cleanStaleLiveRecords`.
// ─────────────────────────────────────────────────────────────────────────────
exports.markAbsentAtSixPM = onSchedule(
  {
    schedule: "30 18 * * 1-5",
    timeZone: "Asia/Karachi",
    // Inherits memory/cpu/maxInstances from setGlobalOptions
    // (256MiB / cpu:1 / maxInstances:1 — see comment there).
    concurrency: 1,
  },
  async (_event) => {
    const now = new Date();
    const dateKey = now.toLocaleDateString("en-CA", { timeZone: "Asia/Karachi" });
    const year = parseInt(dateKey.slice(0, 4), 10);
    const month = parseInt(dateKey.slice(5, 7), 10);
    const monthPad = dateKey.slice(5, 7);

    logger.info(`[markAbsentAtSixPM] Running for ${dateKey}`);

    // 1) Skip the entire run if today is a public holiday.
    const holidayDoc = await db.collection("public_holidays").doc(dateKey).get();
    if (holidayDoc.exists) {
      logger.info(`[markAbsentAtSixPM] ${dateKey} is a public holiday — skipping.`);
      return;
    }

    // 2) Pre-fetch approved leaves covering today. We query BOTH
    //    request_for_leave (the active flow, field=`uid`) AND legacy
    //    `leaves` (field=`userId`) so this cron honours any leave
    //    regardless of which approval path created it.
    //
    //    Result is a Map<uid, durationStr> so the per-user branch below
    //    can choose between `onLeave` (full day) and `firstHalfLeave` /
    //    `secondHalfLeave` (half day) when writing the archive row.
    const todayMidnight = new Date(`${dateKey}T00:00:00+05:00`); // Asia/Karachi
    const leaveByUid = new Map();
    const recordLeave = (uid, durationRaw, start, end) => {
      if (!uid || !start || !end) return;
      if (!(start <= todayMidnight && end >= todayMidnight)) return;
      const duration = (durationRaw || 'fullDay').toString();
      // Latest wins; the new flow doc beats the legacy one.
      leaveByUid.set(uid, duration);
    };
    try {
      const reqSnap = await db.collection("request_for_leave")
        .where("status", "==", "approved")
        .where("startDate", "<=", admin.firestore.Timestamp.fromDate(todayMidnight))
        .get();
      for (const ld of reqSnap.docs) {
        const d = ld.data();
        recordLeave(
          d.uid,
          d.duration,
          d.startDate?.toDate?.(),
          d.endDate?.toDate?.(),
        );
      }
    } catch (e) {
      logger.warn(`[markAbsentAtSixPM] request_for_leave prefetch failed: ${e.message}`);
    }
    try {
      const legacySnap = await db.collection("leaves")
        .where("status", "==", "approved")
        .where("startDate", "<=", admin.firestore.Timestamp.fromDate(todayMidnight))
        .get();
      for (const ld of legacySnap.docs) {
        const d = ld.data();
        recordLeave(
          d.userId,
          d.duration,
          d.startDate?.toDate?.(),
          d.endDate?.toDate?.(),
        );
      }
    } catch (e) {
      logger.warn(`[markAbsentAtSixPM] legacy leaves prefetch failed: ${e.message}`);
    }

    // 3) Stream users one at a time; batch the absent writes.
    const BATCH_SIZE = 100;
    let writeBatch = db.batch();
    let pending = 0;
    let marked = 0;
    let markedOnLeave = 0;
    let skippedAlreadyIn = 0;

    const flush = async () => {
      if (pending > 0) {
        await writeBatch.commit();
        writeBatch = db.batch();
        pending = 0;
      }
    };

    const statusForDuration = (duration) => {
      switch ((duration || 'fullDay').toString()) {
        case 'firstHalf':
          return 'firstHalfLeave';
        case 'secondHalf':
          return 'secondHalfLeave';
        default:
          return 'onLeave';
      }
    };

    for await (const userDoc of db.collection("users").stream()) {
      const u = userDoc.data();
      const role = (u.role || "").toString().toLowerCase();
      // Only employees + leads are tracked for attendance.
      if (role === "hr" || role === "admin") continue;
      if (u.disabled === true) continue;
      const userId = userDoc.id;

      // Has the user already checked in OR out today? If so, the live
      // doc / archive entry from that flow is authoritative — skip.
      const liveSnap = await db.collection("attendance_live").doc(userId).get();
      if (liveSnap.exists) {
        const live = liveSnap.data();
        if (live.dateString === dateKey &&
          (live.checkInTime || live.checkOutTime)) {
          skippedAlreadyIn++;
          continue;
        }
      }

      // Is the user on approved leave today? Write a leave row to the
      // archive instead of absent. Half-day leaves still get a row so
      // the HR Monthly view can see them (deduction policy treats any
      // *.isAnyLeave status as paid — zero deduction).
      const archiveRef = db.collection("attendance_archive")
        .doc(`${userId}_${year}_${monthPad}`);
      if (leaveByUid.has(userId)) {
        const status = statusForDuration(leaveByUid.get(userId));
        const leaveDay = {
          userId,
          date: admin.firestore.Timestamp.fromDate(todayMidnight),
          dateString: dateKey,
          status,
          leaveType: leaveByUid.get(userId),
          checkInTime: null,
          checkOutTime: null,
          breaks: [],
          totalWorkSeconds: 0,
          totalBreakSeconds: 0,
          autoMarkedAt: now.toISOString(),
          autoMarkedBy: "markAbsentAtSixPM",
        };
        writeBatch.set(
          archiveRef,
          { userId, year, month, days: { [dateKey]: leaveDay } },
          { merge: true }
        );
        pending++;
        markedOnLeave++;
        if (pending >= BATCH_SIZE) await flush();
        continue;
      }

      // No leave, no check-in/out → mark absent.
      const absentDay = {
        userId,
        date: admin.firestore.Timestamp.fromDate(todayMidnight),
        dateString: dateKey,
        status: "absent",
        checkInTime: null,
        checkOutTime: null,
        breaks: [],
        totalWorkSeconds: 0,
        totalBreakSeconds: 0,
        autoMarkedAt: now.toISOString(),
        autoMarkedBy: "markAbsentAtSixPM",
      };
      writeBatch.set(
        archiveRef,
        { userId, year, month, days: { [dateKey]: absentDay } },
        { merge: true }
      );
      pending++;
      marked++;
      if (pending >= BATCH_SIZE) await flush();
    }
    await flush();
    logger.info(
      `[markAbsentAtSixPM] ${dateKey} — marked ${marked} absent, ` +
      `${markedOnLeave} on leave, skipped ${skippedAlreadyIn} (already in/out).`
    );
  }
);

exports.cleanStaleLiveRecords = onSchedule(
  {
    schedule: "59 23 * * *",
    timeZone: "Asia/Karachi",
    // Inherits memory/cpu/maxInstances from setGlobalOptions.
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
// Per-employee reminder window. The cron fires every 15 min from 5 AM to
// 11:45 PM. For each employee, we compute their personal reminder window
// based on (a) the work_hour_overrides covering today, falling back to
// (b) the default 9:00 AM start. Window is [workStart − 10 min, workStart
// + 60 min] — same shape the legacy 8:50–10:00 spec produced, just slid
// to the employee's actual start time.
//
// Examples:
//   • Default 9:00 AM start → reminders [08:50, 10:00]
//   • Override 11:30 AM start → reminders [11:20, 12:30]
//   • Override 14:00 PM start → reminders [13:50, 15:00]
//
// Each reminder is written to `task_notifications`, which the existing
// `onTaskNotificationCreated` trigger turns into FCM push + in-app local
// notification (no double-wiring required).
// ─────────────────────────────────────────────────────────────────────────────

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

// Defaults applied when no work_hour_overrides doc covers today for an employee.
const _DEFAULT_WORK_START_MINUTES = 9 * 60;  // 09:00
const _DEFAULT_WORK_END_MINUTES = 18 * 60;   // 18:00

// Pre-fetch work-hour overrides covering [todayKey], indexed by userId.
// Latest createdAt wins when an employee has overlapping overrides.
// Returns Map<uid, { startMinutes, endMinutes }>.
async function _fetchOverridesForToday(todayKey) {
  const overrides = new Map();
  try {
    const snap = await db.collection('work_hour_overrides')
      .where('startDateKey', '<=', todayKey)
      .get();
    for (const d of snap.docs) {
      const o = d.data();
      if ((o.endDateKey || '').toString() < todayKey) continue;
      const uid = (o.userId || '').toString();
      if (!uid) continue;
      const sh = Number(o.workStartHour ?? 9);
      const sm = Number(o.workStartMinute ?? 0);
      const eh = Number(o.workEndHour ?? 18);
      const em = Number(o.workEndMinute ?? 0);
      const createdAtMs = o.createdAt?.toDate?.()?.getTime() || 0;
      const existing = overrides.get(uid);
      if (existing && existing.createdAtMs >= createdAtMs) continue;
      overrides.set(uid, {
        startMinutes: sh * 60 + sm,
        endMinutes: eh * 60 + em,
        createdAtMs,
      });
    }
  } catch (e) {
    logger.warn(`[overrides] prefetch failed: ${e.message}`);
  }
  return overrides;
}

// Pre-fetch userIds on FULL-DAY approved leave today (uses request_for_leave
// which uses field `uid`, with a legacy-collection fallback). Half-day
// leaves are not skipped — those employees still need a check-in nudge.
async function _fetchFullDayLeaveUidsForToday(todayKey) {
  const onLeave = new Set();
  const midnight = new Date(`${todayKey}T00:00:00+05:00`);
  const consider = (uid, durationRaw, start, end) => {
    if (!uid || !start || !end) return;
    if (!(start <= midnight && end >= midnight)) return;
    const duration = (durationRaw || 'fullDay').toString();
    if (duration === 'firstHalf' || duration === 'secondHalf') return;
    onLeave.add(uid);
  };
  try {
    const reqSnap = await db.collection('request_for_leave')
      .where('status', '==', 'approved')
      .where('startDate', '<=', admin.firestore.Timestamp.fromDate(midnight))
      .get();
    for (const d of reqSnap.docs) {
      const data = d.data();
      consider(data.uid, data.duration, data.startDate?.toDate?.(), data.endDate?.toDate?.());
    }
  } catch (e) {
    logger.warn(`[leaves] request_for_leave prefetch failed: ${e.message}`);
  }
  try {
    const legSnap = await db.collection('leaves')
      .where('status', '==', 'approved')
      .where('startDate', '<=', admin.firestore.Timestamp.fromDate(midnight))
      .get();
    for (const d of legSnap.docs) {
      const data = d.data();
      consider(data.userId, data.duration, data.startDate?.toDate?.(), data.endDate?.toDate?.());
    }
  } catch (e) {
    logger.warn(`[leaves] legacy prefetch failed: ${e.message}`);
  }
  return onLeave;
}

exports.checkInReminders = onSchedule(
  {
    // Fire every 15 min, all 24 hours, Mon–Fri. The cron itself stays
    // agnostic to what hours HR sets — per-user filtering inside the
    // handler decides whose personal window covers "now" and nudges
    // only those users. This handles every shift HR might assign
    // (early-morning, night, swing, etc.) without ever missing a
    // window edge.
    //
    // Cost (Blaze): 96 fires/day × ~52 Firestore reads/fire across all
    // employees ≈ 5K reads/day per cron — comfortably inside the daily
    // 50K free-read allowance.
    schedule: '*/15 * * * 1-5',
    timeZone: 'Asia/Karachi',
    // Inherits memory/cpu/maxInstances from setGlobalOptions.
    concurrency: 1,
  },
  async () => {
    const { hour, minute } = _karachiHourMinute();
    const nowMinutes = hour * 60 + minute;
    const todayKey = _todayKeyKarachi();
    logger.info(
      `[checkInReminders] Running for ${todayKey} at ` +
      `${hour}:${String(minute).padStart(2, '0')}`,
    );

    const overrides = await _fetchOverridesForToday(todayKey);
    const onLeave = await _fetchFullDayLeaveUidsForToday(todayKey);

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

    for await (const userDoc of db.collection('users').stream()) {
      const u = userDoc.data();
      const role = (u.role || '').toString().toLowerCase();
      const empId = (u.emp_id || '').toString();
      if (!empId) continue;
      if (role === 'hr' || role === 'admin') continue;
      if (u.disabled === true) continue;
      const userId = userDoc.id;

      if (onLeave.has(userId)) continue; // full-day leave → no nudge

      // Per-employee reminder window. With no override active for today,
      // this resolves to [08:50, 10:00] — the default company spec.
      const ov = overrides.get(userId);
      const startMinutes = ov ? ov.startMinutes : _DEFAULT_WORK_START_MINUTES;
      const windowLo = startMinutes - 10;
      const windowHi = startMinutes + 60;
      if (nowMinutes < windowLo || nowMinutes > windowHi) continue;

      // Already checked in today → skip.
      const liveDoc = await db.collection('attendance_live').doc(userId).get();
      if (liveDoc.exists) {
        const live = liveDoc.data();
        if ((live.dateString || '') === todayKey && live.checkInTime) continue;
      }

      // Body uses the employee's PERSONAL start time so the message is
      // accurate ("It's 9:30 — check in for today" makes no sense to
      // someone on a 2 PM shift).
      const startH = Math.floor(startMinutes / 60);
      const startM = startMinutes % 60;
      const body =
        `Please check in. Your shift starts at ` +
        `${startH}:${String(startM).padStart(2, '0')}.`;

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
// Per-employee reminder window. The cron fires every 5 min from 4 PM to
// 11:55 PM. For each employee, we compute their personal reminder window
// as [workEnd + 5 min, workEnd + 30 min] — same shape the legacy 18:05–
// 18:30 spec produced, just slid to the employee's actual end time.
//
// Examples:
//   • Default 6:00 PM end → reminders [18:05, 18:30]
//   • Override 8:00 PM end → reminders [20:05, 20:30]
//   • Override 10:00 PM end → reminders [22:05, 22:30]
//
// The final tick (workEnd + 30 min) coincides with the client-side hard
// checkout cutoff (override-aware via AttendanceService.isPastDailyCutoffFor),
// so the last reminder is also the "Check-out closes now" warning.
// ─────────────────────────────────────────────────────────────────────────────

exports.checkOutReminders = onSchedule(
  {
    // Fire every 5 min, all 24 hours, Mon–Fri. Same rationale as
    // checkInReminders — per-user filtering decides who's inside their
    // own checkout window. This is the right shape for any HR-assigned
    // shift, including night shifts ending past midnight.
    schedule: '*/5 * * * 1-5',
    timeZone: 'Asia/Karachi',
    // Inherits memory/cpu/maxInstances from setGlobalOptions.
    concurrency: 1,
  },
  async () => {
    const { hour, minute } = _karachiHourMinute();
    const nowMinutes = hour * 60 + minute;
    const todayKey = _todayKeyKarachi();
    logger.info(
      `[checkOutReminders] Running for ${todayKey} at ` +
      `${hour}:${String(minute).padStart(2, '0')}`,
    );

    const overrides = await _fetchOverridesForToday(todayKey);

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

    for await (const userDoc of db.collection('users').stream()) {
      const u = userDoc.data();
      const role = (u.role || '').toString().toLowerCase();
      const empId = (u.emp_id || '').toString();
      if (!empId) continue;
      if (role === 'hr' || role === 'admin') continue;
      if (u.disabled === true) continue;
      const userId = userDoc.id;

      // Per-employee reminder window. With no override active for today,
      // this resolves to [18:05, 18:30] — the default company spec.
      const ov = overrides.get(userId);
      const endMinutes = ov ? ov.endMinutes : _DEFAULT_WORK_END_MINUTES;
      const windowLo = endMinutes + 5;
      const windowHi = endMinutes + 30;
      if (nowMinutes < windowLo || nowMinutes > windowHi) continue;

      // Must be checked in but not yet checked out.
      const liveDoc = await db.collection('attendance_live').doc(userId).get();
      if (!liveDoc.exists) continue;
      const live = liveDoc.data();
      if ((live.dateString || '') !== todayKey) continue;
      if (!live.checkInTime) continue;     // never checked in → no checkout nag
      if (live.checkOutTime) continue;     // already checked out → done

      const isFinal = (nowMinutes >= windowHi - 1);
      const endH = Math.floor(endMinutes / 60);
      const endM = endMinutes % 60;
      const cutoffH = Math.floor((endMinutes + 30) / 60);
      const cutoffM = (endMinutes + 30) % 60;
      const cutoffLabel =
        `${cutoffH}:${String(cutoffM).padStart(2, '0')}`;

      const title = isFinal
        ? '🚪 Final Check-out Reminder'
        : '🕕 Check-out Reminder';
      const body = isFinal
        ? `Last reminder — please check out now. After ${cutoffLabel} ` +
          `the check-out button will be disabled.`
        : `Your shift ended at ${endH}:${String(endM).padStart(2, '0')} ` +
          `— please check out for the day.`;

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
