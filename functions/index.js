"use strict";

/**
 * FundiHub Firebase Cloud Functions — Final Audit Edition
 *
 * DOUBLE-COUNT FIX:
 *   The previous version had CF incrementing jobsDone as a "backup"
 *   whenever the booking doc transitioned to 'completed' and jobsDoneCounted
 *   flipped to true.  But booking_service.dart ALSO increments it atomically
 *   in a Dart transaction.  Both paths ran → +2 instead of +1.
 *
 *   FIX: CF no longer increments jobsDone at all.
 *   booking_service.dart clientConfirmCompletion() is the SOLE place that
 *   increments jobsDone.  It is protected by the jobsDoneCounted flag so it
 *   can never run twice even if triggered multiple times.
 *
 * NOTIFICATION DEDUPLICATION:
 *   notify() checks if the stable-ID doc already exists before writing.
 *   booking_service.dart writes with the same stable ID pattern so CF finds
 *   the existing doc and skips → no duplicate notifications.
 *
 * CHAT OPEN STATUSES:
 *   awaiting_confirmation and completion_disputed are now in the open set
 *   so chat is not accidentally locked during those phases.
 */

const functions = require("firebase-functions");
const admin     = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const fv = admin.firestore.FieldValue;

const BOOKING_EXPIRY_H = parseInt(process.env.BOOKING_EXPIRY_HOURS || "48", 10);

// ─────────────────────────────────────────────────────────────────────────────
// STABLE-ID notification writer
// Pattern: {userId}_{type}_{safeRelatedId}
// Checks existence first → skips if booking_service.dart already wrote it.
// ─────────────────────────────────────────────────────────────────────────────
async function notify(userId, title, body, type, relatedId, senderId) {
  if (!userId || !title) return;
  try {
    const safeId   = (relatedId || "none").replace(/[^a-zA-Z0-9_-]/g,"_").substring(0,100);
    const safeType = (type || "notif").replace(/[^a-zA-Z0-9_]/g,"_");
    const notifId  = `${userId}_${safeType}_${safeId}`;
    const ref      = db.collection("notifications").doc(notifId);

    const existing = await ref.get();
    if (existing.exists) {
      console.log(`[notify] Skipping dup: ${notifId}`);
      return;
    }

    const t        = (type||"").toLowerCase();
    const isBook   = t.includes("booking")||t.includes("job")||t.includes("agreement")||
                     t.includes("completion")||t.includes("dispute")||t.includes("payment")||
                     t.includes("review")||t.includes("expired")||t.includes("started")||
                     t.includes("accepted")||t.includes("rejected")||t.includes("cancelled");
    const isChat   = t.includes("chat")||t.includes("message");

    await ref.set({
      notificationId: notifId, notifId,
      userId,  receiverId: userId,
      senderId: senderId||null,
      title, body, message: body, type,
      relatedId: relatedId||null,
      ...(relatedId && isBook ? {bookingId: relatedId} : {}),
      ...(relatedId && isChat ? {chatId:    relatedId} : {}),
      isRead: false, read: false,
      createdAt: fv.serverTimestamp(),
      updatedAt: fv.serverTimestamp(),
    });
    console.log(`[notify] ${notifId}: "${title}"`);
  } catch(err) {
    console.error(`[notify] FAIL ${type}→${userId}:`, err.message);
  }
}

async function sendPush(userId, title, body, data) {
  try {
    const snap  = await db.collection("users").doc(userId).get();
    const token = (snap.data()||{}).fcmToken;
    if (!token) return;
    await admin.messaging().send({
      token, notification: {title, body},
      data: data||{},
      android: {priority:"high", notification:{sound:"default",channelId:"fundihub_default"}},
    });
  } catch(err) {
    console.warn(`[push] Failed ${userId}:`, err.message);
  }
}

async function notifyAndPush(userId, title, body, type, relatedId, senderId) {
  await Promise.all([
    notify(userId, title, body, type, relatedId, senderId),
    sendPush(userId, title, body, {
      type: type||"", relatedId: relatedId||"",
      bookingId: relatedId||"",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    }),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: role claims
// ─────────────────────────────────────────────────────────────────────────────
exports.setUserRoleClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated","Must be logged in.");
  const uid  = data.uid || context.auth.uid;
  const role = data.role || "client";
  if (!["client","fundi"].includes(role))
    throw new functions.https.HttpsError("invalid-argument","Role must be client or fundi.");
  if (uid !== context.auth.uid && (context.auth.token||{}).role !== "admin")
    throw new functions.https.HttpsError("permission-denied","Cannot set role for another user.");
  await admin.auth().setCustomUserClaims(uid, {role});
  return {success:true, uid, role};
});

exports.setAdminRoleClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated","Must be logged in.");
  if ((context.auth.token||{}).role !== "admin")
    throw new functions.https.HttpsError("permission-denied","Only admins can grant admin.");
  const uid = data.uid;
  if (!uid) throw new functions.https.HttpsError("invalid-argument","Missing uid.");
  await admin.auth().setCustomUserClaims(uid, {role:"admin"});
  await db.collection("users").doc(uid).set(
    {role:"admin", updatedAt: fv.serverTimestamp()}, {merge:true});
  return {success:true, uid};
});

// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER: onBookingWrite — notification BACKUP
// booking_service.dart writes first with same stable IDs → CF skips duplicates.
// ─────────────────────────────────────────────────────────────────────────────
exports.onBookingWrite = functions.firestore
  .document("bookings/{bookingId}")
  .onWrite(async (change, context) => {
    const bookingId = context.params.bookingId;
    const before    = change.before.exists ? change.before.data() : null;
    const after     = change.after.exists  ? change.after.data()  : null;
    if (!after) return null;

    const norm = s => (s||"").trim().toLowerCase()
      .replace("in progress",          "in_progress")
      .replace("awaitingconfirmation",  "awaiting_confirmation")
      .replace("awaiting confirmation", "awaiting_confirmation")
      .replace("completiondisputed",    "completion_disputed")
      .replace("agreementconfirmed",    "agreement_confirmed");

    const sBefore  = norm(before ? before.status : "");
    const sAfter   = norm(after.status);
    const clientId = after.clientId  || "";
    const fundiId  = after.fundiId   || "";
    const cName    = after.clientName || "Client";
    const fName    = after.fundiName  || "Fundi";

    console.log(`[onBookingWrite] ${bookingId}: "${sBefore}" → "${sAfter}"`);

    // New booking
    if (!before && sAfter === "pending") {
      await notifyAndPush(fundiId, "New Booking Request 📋",
        `${cName} sent you a new booking request.`,
        "booking_request", bookingId, clientId);
      return null;
    }

    // Agreement flag change only (status unchanged)
    if (sBefore === sAfter) {
      const cAB = before ? !!before.clientAgreed : false;
      const fAB = before ? !!before.fundiAgreed  : false;
      if (!cAB && !!after.clientAgreed && !after.fundiAgreed)
        await notifyAndPush(fundiId, "Agreement Pending",
          `${cName} confirmed the agreement.`, "agreement_pending", bookingId, clientId);
      if (!fAB && !!after.fundiAgreed && !after.clientAgreed)
        await notifyAndPush(clientId, "Agreement Pending",
          `${fName} confirmed the agreement.`, "agreement_pending", bookingId, fundiId);
      return null;
    }

    switch (sAfter) {
      case "accepted":
        await notifyAndPush(clientId, "Booking Accepted ✅",
          `${fName} accepted your booking. You can now call, WhatsApp, and chat!`,
          "booking_accepted", bookingId, fundiId);
        break;

      case "rejected":
        await notifyAndPush(clientId, "Booking Rejected",
          `${fName} rejected your booking.`,
          "booking_rejected", bookingId, fundiId);
        break;

      case "cancelled": {
        const by      = after.cancelledBy||"";
        const byCl    = by === clientId || by.toLowerCase() === "client";
        const actor   = byCl ? cName  : fName;
        const recv    = byCl ? fundiId : clientId;
        const sndr    = byCl ? clientId: fundiId;
        await notifyAndPush(recv, "Booking Cancelled",
          `${actor} cancelled the booking.`, "booking_cancelled", bookingId, sndr);
        break;
      }

      case "agreement_confirmed":
        await Promise.all([
          notifyAndPush(clientId, "Agreement Confirmed ✅",
            "Both parties confirmed. Contact is unlocked.",
            "agreement_confirmed", bookingId, fundiId),
          notifyAndPush(fundiId, "Agreement Confirmed ✅",
            "Both parties confirmed. Contact is unlocked.",
            "agreement_confirmed", bookingId, clientId),
        ]);
        break;

      case "in_progress":
        await notifyAndPush(clientId, "Job Started 🔧",
          `${fName} has started the job.`, "job_started", bookingId, fundiId);
        break;

      case "awaiting_confirmation":
        await notifyAndPush(clientId, "Job Done — Please Confirm ✅",
          `${fName} marked the job as done. Tap to confirm or report a problem.`,
          "completion_requested", bookingId, fundiId);
        break;

      case "completion_disputed":
        await notifyAndPush(fundiId, "Completion Disputed ⚠️",
          `${cName} reported a problem with the job completion.`,
          "completion_disputed", bookingId, clientId);
        break;

      case "completed":
        // IMPORTANT: Do NOT increment jobsDone here.
        // booking_service.dart clientConfirmCompletion() is the sole incrementer.
        // It uses jobsDoneCounted flag to guarantee exactly-once semantics.
        await notifyAndPush(fundiId, "Job Completed ✅",
          `${cName} confirmed the job is complete. Great work!`,
          "job_completed", bookingId, clientId);
        break;

      case "expired":
        await Promise.all([
          notifyAndPush(clientId, "Booking Expired",
            "Your booking request has expired.", "booking_expired", bookingId, null),
          notifyAndPush(fundiId,  "Booking Expired",
            "A pending booking has expired.",   "booking_expired", bookingId, null),
        ]);
        break;
    }
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// DISABLED: onBookingAcceptWallet (growth phase — no fees)
// ─────────────────────────────────────────────────────────────────────────────
exports.onBookingAcceptWallet = functions.firestore
  .document("bookings/{bookingId}")
  .onWrite(async () => null);

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: auto-expire pending bookings
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledBookingExpiry = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - BOOKING_EXPIRY_H * 60*60*1000));
    const snap = await db.collection("bookings")
      .where("status","==","pending").where("createdAt","<",cutoff).limit(100).get();
    if (snap.empty) return null;
    const batch = db.batch(), ts = fv.serverTimestamp();
    snap.docs.forEach(doc => batch.update(doc.ref,
      {status:"expired", expiredAt:ts, updatedAt:ts}));
    await batch.commit();
    console.log(`Expired ${snap.docs.length} bookings`);
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: subscription + promotion expiry (records only, no access gates)
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledSubscriptionExpiry = functions.pubsub
  .schedule("every 24 hours").timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const now  = admin.firestore.Timestamp.now();
    const snap = await db.collection("subscriptions")
      .where("isActive","==",true).where("endDate","<",now).limit(100).get();
    if (snap.empty) return null;
    const ts = fv.serverTimestamp();
    await Promise.allSettled(snap.docs.map(async doc => {
      const {fundiId} = doc.data(); if (!fundiId) return;
      await doc.ref.update({isActive:false, updatedAt:ts});
      // Growth phase: do NOT downgrade plan or restrict access
    }));
    return null;
  });

exports.scheduledPromotionExpiry = functions.pubsub
  .schedule("every 6 hours").timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const now  = admin.firestore.Timestamp.now();
    const snap = await db.collection("promotions")
      .where("isActive","==",true).where("endDate","<",now).limit(100).get();
    if (snap.empty) return null;
    const ts = fv.serverTimestamp();
    await Promise.allSettled(snap.docs.map(async doc => {
      const {fundiId} = doc.data(); if (!fundiId) return;
      const batch = db.batch();
      batch.update(doc.ref, {isActive:false, status:"expired", updatedAt:ts});
      batch.set(db.collection("users").doc(fundiId),
        {boostActive:false, promotionStatus:"inactive", updatedAt:ts}, {merge:true});
      await batch.commit();
    }));
    return null;
  });
