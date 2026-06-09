/**
 * FundiHub Cloud Functions — safe Cloudinary deletion
 *
 * TWO FUNCTIONS:
 *
 * 1. onReelSoftDeleted  (Firestore trigger)
 *    Fires whenever a reel document is updated.
 *    When isDeleted flips false → true, deletes the Cloudinary video using
 *    the storagePath / publicId stored on the document.
 *    Writes back: cloudinaryDeleted, cloudinaryDeletedAt, cloudinaryDeleteError.
 *
 * 2. hardDeleteReel  (HTTPS callable)
 *    Admin-only.  Permanently deletes:
 *      - Cloudinary video (via API secret — server side only)
 *      - Firestore reel document
 *      - Firestore comments sub-collection
 *    Returns { success, cloudinaryOk, cloudinaryError }.
 *
 * ── SETUP ────────────────────────────────────────────────────────────────────
 * Store Cloudinary credentials as Firebase Functions environment config
 * (never commit these to source control):
 *
 *   firebase functions:config:set \
 *     cloudinary.cloud_name="YOUR_CLOUD_NAME" \
 *     cloudinary.api_key="YOUR_API_KEY" \
 *     cloudinary.api_secret="YOUR_API_SECRET"
 *
 * Deploy:
 *   cd functions
 *   npm install
 *   firebase deploy --only functions
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
// node-fetch v2 uses CommonJS — compatible with Node 18 functions
import fetch from "node-fetch";

admin.initializeApp();
const db = admin.firestore();

// ── Read Cloudinary credentials from environment config ───────────────────────
// These are NEVER sent to the Flutter client.
const CLOUD_NAME  = (): string => functions.config().cloudinary?.cloud_name  ?? "";
const API_KEY     = (): string => functions.config().cloudinary?.api_key     ?? "";
const API_SECRET  = (): string => functions.config().cloudinary?.api_secret  ?? "";

// ── Helper: delete one Cloudinary resource ───────────────────────────────────
async function destroyCloudinaryAsset(
  publicId: string,
  resourceType = "video"
): Promise<{ ok: boolean; error?: string }> {
  const cloudName = CLOUD_NAME();
  const apiKey    = API_KEY();
  const apiSecret = API_SECRET();

  if (!publicId) {
    return { ok: false, error: "publicId is empty — nothing to delete" };
  }
  if (!cloudName || !apiKey || !apiSecret) {
    return {
      ok:    false,
      error: "Cloudinary env config missing — run firebase functions:config:set",
    };
  }

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = crypto
    .createHash("sha1")
    .update(`public_id=${publicId}&timestamp=${timestamp}${apiSecret}`)
    .digest("hex");

  const body = new URLSearchParams({
    public_id: publicId,
    timestamp,
    api_key:   apiKey,
    signature,
  });

  const url = `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/destroy`;

  try {
    const res  = await fetch(url, { method: "POST", body });
    const data = (await res.json()) as Record<string, unknown>;
    // "ok" = deleted; "not found" = already gone — both are success states
    if (data.result === "ok" || data.result === "not found") {
      return { ok: true };
    }
    return { ok: false, error: `Cloudinary result: ${JSON.stringify(data)}` };
  } catch (err) {
    return { ok: false, error: `fetch error: ${String(err)}` };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Firestore trigger — auto-delete Cloudinary on soft-delete
// ─────────────────────────────────────────────────────────────────────────────
export const onReelSoftDeleted = functions.firestore
  .document("reels/{reelId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only act when isDeleted transitions false → true
    if (before.isDeleted === true || after.isDeleted !== true) return null;

    const reelId   = context.params.reelId;
    // storagePath stores the Cloudinary publicId (see reel_model.dart)
    const publicId = String(after.storagePath ?? after.publicId ?? "");

    functions.logger.info(
      `[onReelSoftDeleted] reelId=${reelId}  publicId=${publicId}`
    );

    const { ok, error } = await destroyCloudinaryAsset(publicId);

    // Write deletion status back so admin can audit
    await change.after.ref.update({
      cloudinaryDeleted:   ok,
      cloudinaryDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(error && { cloudinaryDeleteError: error }),
    });

    functions.logger.info(
      `[onReelSoftDeleted] ${ok ? "✓ deleted" : "✗ failed"}  reelId=${reelId}  error=${error ?? ""}`
    );
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: HTTPS callable — admin permanent hard-delete
// Deletes: Cloudinary video + Firestore doc + comments sub-collection
// ─────────────────────────────────────────────────────────────────────────────
export const hardDeleteReel = functions.https.onCall(
  async (data: { reelId: string }, context) => {
    // ── Must be signed in ─────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    // ── Must be admin ─────────────────────────────────────────────────────
    const callerSnap = await db
      .collection("users")
      .doc(context.auth.uid)
      .get();
    if (callerSnap.data()?.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can permanently delete reels."
      );
    }

    const { reelId } = data;
    if (!reelId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "reelId is required."
      );
    }

    const reelRef  = db.collection("reels").doc(reelId);
    const reelSnap = await reelRef.get();

    // Reel already gone — treat as success
    if (!reelSnap.exists) {
      return { success: true, cloudinaryOk: true, cloudinaryError: "" };
    }

    const reelData = reelSnap.data()!;
    const publicId = String(reelData.storagePath ?? reelData.publicId ?? "");

    // ── Delete Cloudinary asset ───────────────────────────────────────────
    let cloudinaryOk    = true;
    let cloudinaryError = "";
    if (publicId) {
      const result = await destroyCloudinaryAsset(publicId);
      cloudinaryOk    = result.ok;
      cloudinaryError = result.error ?? "";
    }

    // ── Delete Firestore sub-collections in batches ───────────────────────
    const commentsSnap = await reelRef
      .collection("comments")
      .limit(500)
      .get();

    const batch = db.batch();
    commentsSnap.docs.forEach((d) => batch.delete(d.ref));
    // Delete the reel document itself
    batch.delete(reelRef);
    await batch.commit();

    functions.logger.info(
      `[hardDeleteReel] done  reelId=${reelId}  cloudinaryOk=${cloudinaryOk}`
    );

    return { success: true, cloudinaryOk, cloudinaryError };
  }
);
