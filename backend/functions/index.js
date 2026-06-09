const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const admin = require('firebase-admin');
const functions = require('firebase-functions');

admin.initializeApp();
const db = admin.firestore();
const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

const cfg = {
  baseUrl: process.env.SELCOM_BASE_URL || '',
  apiKey: process.env.SELCOM_API_KEY || '',
  apiSecret: process.env.SELCOM_API_SECRET || '',
  vendor: process.env.SELCOM_VENDOR || '',
  functionsBaseUrl: process.env.FUNDIHUB_FUNCTIONS_BASE_URL || '',
  redirectUrl: process.env.FUNDIHUB_PAYMENT_REDIRECT_URL || '',
  cancelUrl: process.env.FUNDIHUB_PAYMENT_CANCEL_URL || '',
  webhookToken: process.env.SELCOM_WEBHOOK_TOKEN || '',
};

function requireConfig() {
  const missing = Object.entries(cfg)
    .filter(([k, v]) => ['baseUrl', 'apiKey', 'apiSecret', 'vendor', 'functionsBaseUrl'].includes(k) && !v)
    .map(([k]) => k);
  if (missing.length) {
    throw new Error(`Missing Selcom backend env: ${missing.join(', ')}`);
  }
}

function tzTimestamp() {
  const date = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  // ISO-like timestamp. Selcom may require +03:00; confirm with issued credentials/docs.
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}T${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(date.getUTCSeconds())}+00:00`;
}

function b64(value) {
  return Buffer.from(String(value), 'utf8').toString('base64');
}

function signPayload(payload, signedFields, timestamp) {
  const signing = [`timestamp=${timestamp}`]
    .concat(signedFields.map((field) => `${field}=${payload[field] ?? ''}`))
    .join('&');
  return crypto.createHmac('sha256', cfg.apiSecret).update(signing).digest('base64');
}

function authHeaders(payload, signedFields) {
  const timestamp = tzTimestamp();
  return {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    Authorization: `SELCOM ${b64(cfg.apiKey)}`,
    'Digest-Method': 'HS256',
    Timestamp: timestamp,
    'Signed-Fields': signedFields.join(','),
    Digest: signPayload(payload, signedFields, timestamp),
  };
}

function normalizePhone(raw) {
  const digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('255')) return digits;
  if (digits.startsWith('0')) return `255${digits.substring(1)}`;
  if (digits.length === 9) return `255${digits}`;
  return digits;
}

function paymentTypeTitle(type) {
  switch (type) {
    case 'job_fee': return 'FundiHub Job Completion Fee';
    case 'subscription': return 'FundiHub Premium Subscription';
    case 'promotion': return 'FundiHub Profile Boost';
    default: return 'FundiHub Payment';
  }
}

async function applySuccessfulPayment(paymentId, providerPayload = {}) {
  const ref = db.collection('payments').doc(paymentId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('Payment document not found');
    const payment = snap.data();
    if (payment.status === 'confirmed') return;

    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.update(ref, {
      status: 'confirmed',
      providerStatus: providerPayload.payment_status || providerPayload.result || 'confirmed',
      providerTransactionId: providerPayload.transid || providerPayload.transaction_id || payment.providerTransactionId || null,
      callbackReference: providerPayload.reference || payment.callbackReference || null,
      rawCallback: providerPayload,
      confirmedAt: now,
      updatedAt: now,
    });

    const fundiId = payment.fundiId;
    if (!fundiId) return;

    const walletRef = db.collection('wallets').doc(fundiId);
    const userRef = db.collection('users').doc(fundiId);

    if (payment.paymentType === 'job_fee') {
      tx.set(walletRef, {
        lockedReason: 'none',
        feeStatus: 'paid',
        pendingJobFee: 0,
        totalFeesPaid: admin.firestore.FieldValue.increment(Number(payment.amount || 0)),
        updatedAt: now,
      }, { merge: true });
    }

    if (payment.paymentType === 'subscription') {
      const subRef = db.collection('subscriptions').doc();
      const start = admin.firestore.Timestamp.now();
      const end = admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000);
      tx.set(subRef, {
        subscriptionId: subRef.id,
        fundiId,
        fundiName: payment.fundiName || '',
        paymentId,
        startDate: start,
        endDate: end,
        isActive: true,
        amountPaid: payment.amount || 0,
        createdAt: now,
      });
      tx.set(walletRef, {
        subscriptionStatus: 'premium',
        lockedReason: 'none',
        updatedAt: now,
      }, { merge: true });
      tx.set(userRef, { plan: 'premium', updatedAt: now }, { merge: true });
    }

    if (payment.paymentType === 'promotion') {
      const durationDays = Number(payment.durationDays || 7);
      const prRef = db.collection('promotions').doc();
      tx.set(prRef, {
        promotionId: prRef.id,
        fundiId,
        paymentId,
        startDate: admin.firestore.Timestamp.now(),
        endDate: admin.firestore.Timestamp.fromMillis(Date.now() + durationDays * 24 * 60 * 60 * 1000),
        durationDays,
        isActive: true,
        createdAt: now,
      });
      tx.set(walletRef, { promotionStatus: 'active', updatedAt: now }, { merge: true });
      tx.set(userRef, { promotionStatus: 'active', updatedAt: now }, { merge: true });
    }
  });
}

async function applyFailedPayment(paymentId, providerPayload = {}) {
  await db.collection('payments').doc(paymentId).set({
    status: 'rejected',
    providerStatus: providerPayload.payment_status || providerPayload.result || 'failed',
    rejectionReason: providerPayload.message || 'Selcom payment failed or was cancelled.',
    rawCallback: providerPayload,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

app.get('/health', (req, res) => res.json({ ok: true, service: 'fundihub-selcom' }));

app.post('/payments/selcom/checkout', async (req, res) => {
  try {
    requireConfig();
    const body = req.body || {};
    const paymentId = String(body.paymentId || '');
    const orderId = String(body.orderId || `FH-${Date.now()}`);
    const amount = Number(body.amount || 0);
    const type = String(body.paymentType || 'payment');
    const customer = body.customer || {};

    if (!paymentId || !amount || amount < 1) {
      return res.status(400).json({ message: 'paymentId and positive amount are required.' });
    }

    const phone = normalizePhone(customer.phone);
    const names = String(customer.name || 'FundiHub User').trim().split(/\s+/);
    const firstName = names[0] || 'FundiHub';
    const lastName = names.slice(1).join(' ') || 'User';
    const webhookUrl = `${cfg.functionsBaseUrl.replace(/\/+$/, '')}/payments/selcom/webhook?paymentId=${encodeURIComponent(paymentId)}&token=${encodeURIComponent(cfg.webhookToken)}`;

    const payload = {
      vendor: cfg.vendor,
      order_id: orderId,
      buyer_email: customer.email || 'customer@fundihub.app',
      buyer_name: customer.name || 'FundiHub User',
      buyer_userid: customer.id || '',
      buyer_phone: phone,
      amount,
      currency: 'TZS',
      payment_methods: 'ALL',
      redirect_url: b64(cfg.redirectUrl || cfg.functionsBaseUrl),
      cancel_url: b64(cfg.cancelUrl || cfg.functionsBaseUrl),
      webhook: b64(webhookUrl),
      no_of_items: 1,
      buyer_remarks: paymentTypeTitle(type),
      merchant_remarks: `FundiHub ${type} ${paymentId}`,
      'billing.firstname': firstName,
      'billing.lastname': lastName,
      'billing.address_1': 'FundiHub',
      'billing.address_2': 'Tanzania',
      'billing.city': 'Dar es Salaam',
      'billing.state_or_region': 'Dar es Salaam',
      'billing.postcode_or_pobox': '00000',
      'billing.country': 'TZ',
      'billing.phone': phone,
    };

    const signedFields = [
      'vendor', 'order_id', 'buyer_email', 'buyer_name', 'buyer_userid', 'buyer_phone',
      'amount', 'currency', 'payment_methods', 'redirect_url', 'cancel_url', 'webhook',
      'no_of_items', 'buyer_remarks', 'merchant_remarks',
      'billing.firstname', 'billing.lastname', 'billing.address_1', 'billing.address_2',
      'billing.city', 'billing.state_or_region', 'billing.postcode_or_pobox', 'billing.country', 'billing.phone',
    ];

    await db.collection('payments').doc(paymentId).set({
      paymentId,
      provider: 'selcom',
      providerOrderId: orderId,
      referenceNumber: orderId,
      status: 'pending',
      providerStatus: 'checkout_requested',
      amount,
      paymentType: type,
      durationDays: body.durationDays || null,
      relatedBookingId: body.relatedBookingId || null,
      fundiId: customer.id || null,
      fundiName: customer.name || '',
      fundiPhone: phone,
      customerPhone: phone,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const url = `${cfg.baseUrl.replace(/\/+$/, '')}/v1/checkout/create-order`;
    const selcomResponse = await axios.post(url, payload, {
      headers: authHeaders(payload, signedFields),
      timeout: 30000,
    });

    const data = selcomResponse.data || {};
    const arr = Array.isArray(data.data) ? data.data : [];
    const first = arr[0] || {};
    let checkoutUrl = first.payment_gateway_url || first.gateway_url || first.checkout_url || data.payment_gateway_url || '';
    try {
      if (checkoutUrl && !String(checkoutUrl).startsWith('http')) {
        checkoutUrl = Buffer.from(String(checkoutUrl), 'base64').toString('utf8');
      }
    } catch (_) {}

    await db.collection('payments').doc(paymentId).set({
      providerStatus: data.result || data.payment_status || 'pending',
      providerReference: data.reference || null,
      checkoutUrl,
      rawProviderResponse: data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    res.json({
      paymentId,
      orderId,
      checkoutUrl,
      status: data.result || 'pending',
      message: data.message || 'Selcom checkout created.',
      raw: data,
    });
  } catch (err) {
    console.error('checkout error', err.response?.data || err.message || err);
    res.status(500).json({ message: err.response?.data?.message || err.message || 'Selcom checkout failed.' });
  }
});

app.post('/payments/selcom/webhook', async (req, res) => {
  try {
    const token = String(req.query.token || '');
    if (cfg.webhookToken && token !== cfg.webhookToken) {
      return res.status(401).json({ message: 'Invalid webhook token' });
    }
    const paymentId = String(req.query.paymentId || req.body.paymentId || '');
    const orderId = req.body.order_id || req.body.orderId || '';
    let id = paymentId;
    if (!id && orderId) {
      const q = await db.collection('payments').where('providerOrderId', '==', orderId).limit(1).get();
      if (!q.empty) id = q.docs[0].id;
    }
    if (!id) return res.status(400).json({ message: 'paymentId/order_id missing' });

    const status = String(req.body.payment_status || req.body.result || '').toUpperCase();
    const code = String(req.body.resultcode || req.body.resulcode || '');
    const success = status === 'COMPLETED' || status === 'SUCCESS' || code === '000';
    const pending = status === 'PENDING' || status === 'INPROGRESS' || code === '111' || code === '927';

    if (success) await applySuccessfulPayment(id, req.body);
    else if (pending) {
      await db.collection('payments').doc(id).set({
        providerStatus: req.body.payment_status || req.body.result || 'pending',
        rawCallback: req.body,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else await applyFailedPayment(id, req.body);

    res.json({ ok: true });
  } catch (err) {
    console.error('webhook error', err.message || err);
    res.status(500).json({ message: err.message || 'Webhook failed' });
  }
});

exports.api = functions.https.onRequest(app);
