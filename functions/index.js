const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Stripe = require("stripe");

admin.initializeApp();

// ⚠️ Replace with your real TEST keys
const STRIPE_SECRET_KEY = "sk_test_51U0IbORvUfS6DiJXDvALnck8x7k0dC0Ivfr4Y8dUFnLYeOrs764zksEQoXYvdpkf4JCsmS7AJkeKo4K0hofCQjBH00n89CoEM7";
const STRIPE_WEBHOOK_SECRET = "whsec_RAC1FIB7pNBgoLag0qpMsahQW8qgrphU";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});

/**
 * Create Stripe Checkout Session
 */
exports.createCheckoutSession = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const amount = Number(request.data.amount);
      const allowed = [5, 10, 20, 50];

      if (!allowed.includes(amount)) {
        throw new HttpsError("invalid-argument", "Invalid top-up amount");
      }

      const uid = request.auth.uid;
      const email = request.auth.token.email || undefined;

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: ["card"],
        customer_email: email,
        line_items: [
          {
            price_data: {
              currency: "usd",
              product_data: {
                name: "VerifyGlobally Wallet Top-up",
                description: `Add $${amount} to wallet`,
              },
              unit_amount: Math.round(amount * 100),
            },
            quantity: 1,
          },
        ],
        metadata: {
          uid,
          amount: String(amount),
          type: "wallet_topup",
        },
        success_url: "http://localhost:8080/?payment=success&session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "http://localhost:8080/?payment=cancel",
      });

      return {
        url: session.url,
        sessionId: session.id,
      };
    } catch (err) {
      console.error("createCheckoutSession error:", err);
      throw new HttpsError("internal", err.message || "Unknown error");
    }
  }
);

/**
 * Backup method:
 * App can confirm payment by session ID after returning from Stripe
 */
exports.confirmTopUp = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const sessionId = request.data.sessionId;
      if (!sessionId) {
        throw new HttpsError("invalid-argument", "Missing sessionId");
      }

      const session = await stripe.checkout.sessions.retrieve(sessionId);

      if (session.payment_status !== "paid") {
        throw new HttpsError("failed-precondition", "Payment not completed");
      }

      const metadata = session.metadata || {};
      const uid = metadata.uid;
      const amount = parseFloat(metadata.amount || "0");

      if (!uid || uid !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Invalid user for this payment");
      }

      if (!(amount > 0)) {
        throw new HttpsError("invalid-argument", "Invalid amount");
      }

      // Prevent double-credit
      const paymentsRef = admin.firestore().collection("payments");
      const existing = await paymentsRef
        .where("sessionId", "==", sessionId)
        .limit(1)
        .get();

      if (!existing.empty) {
        return { success: true, message: "Already credited", amount };
      }

      const userRef = admin.firestore().collection("users").doc(uid);

      await admin.firestore().runTransaction(async (tx) => {
        const doc = await tx.get(userRef);
        const current = doc.exists ? Number(doc.data().balance || 0) : 0;

        tx.set(
          userRef,
          {
            balance: current + amount,
            lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      await paymentsRef.add({
        uid,
        amount,
        provider: "stripe",
        sessionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, amount };
    } catch (err) {
      console.error("confirmTopUp error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Unknown error");
    }
  }
);

/**
 * Stripe webhook
 * Uses req.rawBody (do NOT use Express JSON parser here)
 */
exports.stripeWebhook = onRequest(
  {
    region: "us-central1",
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const sig = req.headers["stripe-signature"];
    const rawBody = req.rawBody;

    if (!rawBody) {
      console.error("rawBody missing. typeof body =", typeof req.body);
      res.status(400).send("Raw body unavailable");
      return;
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error("Webhook signature error:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    console.log("Stripe event type:", event.type);

    try {
      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        const metadata = session.metadata || {};

        if (metadata.type === "wallet_topup") {
          const uid = metadata.uid;
          const amount = parseFloat(metadata.amount || "0");

          if (uid && amount > 0) {
            const paymentsRef = admin.firestore().collection("payments");
            const existing = await paymentsRef
              .where("sessionId", "==", session.id)
              .limit(1)
              .get();

            if (existing.empty) {
              const userRef = admin.firestore().collection("users").doc(uid);

              await admin.firestore().runTransaction(async (tx) => {
                const doc = await tx.get(userRef);
                const current = doc.exists ? Number(doc.data().balance || 0) : 0;

                tx.set(
                  userRef,
                  {
                    balance: current + amount,
                    lastTopUp: admin.firestore.FieldValue.serverTimestamp(),
                  },
                  { merge: true }
                );
              });

              await paymentsRef.add({
                uid,
                amount,
                provider: "stripe",
                sessionId: session.id,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              console.log(`Credited $${amount} to user ${uid}`);
            }
          }
        }
      }

      res.json({ received: true });
    } catch (err) {
      console.error("Webhook processing error:", err);
      res.status(500).send("Webhook processing failed");
    }
  }
);