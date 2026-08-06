const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Stripe = require("stripe");

admin.initializeApp();

// ===================== SECRETS (rotate — exposed in chat) =====================
const STRIPE_SECRET_KEY =
  "sk_test_51U0IbORvUfS6DiJXDvALnck8x7k0dC0Ivfr4Y8dUFnLYeOrs764zksEQoXYvdpkf4JCsmS7AJkeKo4K0hofCQjBH00n89CoEM7";
const STRIPE_WEBHOOK_SECRET = "whsec_RAC1FIB7pNBgoLag0qpMsahQW8qgrphU";
const FIVESIM_TOKEN =
  "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4MTY5NTMzOTgsImlhdCI6MTc4NTQxNzM5OCwicmF5IjoiOTVmOWNmNWJjYzQ3OTU3OTQyYjE3YzY4YWQxY2Q5YjAiLCJzdWIiOjQzODQwNzR9.feZlZ1SmsoZAmepLceSz76czXBZu57AjlEhE7XK0H5fR-4xt4muwz19d8VYW730DsP0u-y_AwcC4fr9gE0GQldCIiMmtCwD8neD1rahqSgWdFx0cVfA8p_CzIZnawEJ2zuEK9VS9JVEP0-JsonvqpB2h42PXFKNHUG52Ytdx1BWU6nnThuO6sGqhg0ddrKNKxFUBnqVKyKICWS-dZ1WVwGioRi1kVS6xSKGHoO7dJZKh3Zunypy6TbqDx_2eGQOL0KVAJ53RSn1OvhcA-YePI9X68HlP0Cv9Ac4YI8oVRSQV7PizDGMnQIdxqbKcQz_qZaPPEhHFWFuNbQFjEXAL_A";

const APP_URL = "https://app.globeline.online";
// const APP_URL = "https://verifyglobally.web.app";

const MARKUP = 1.5;

const POPULAR_SERVICES = new Set([
  "whatsapp",
  "telegram",
  "google",
  "facebook",
  "instagram",
  "twitter",
  "discord",
  "tiktok",
  "microsoft",
  "amazon",
  "apple",
]);

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});

async function fivesimGet(path) {
  const response = await fetch(`https://5sim.net${path}`, {
    method: "GET",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${FIVESIM_TOKEN}`,
    },
  });
  const text = await response.text();
  let data = null;
  try {
    data = JSON.parse(text);
  } catch (_) {
    data = null;
  }
  return { ok: response.ok, status: response.status, text, data };
}

exports.createCheckoutSession = onCall(
  { region: "us-central1", cors: true },
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
        success_url: `${APP_URL}/?payment=success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${APP_URL}/?payment=cancel`,
      });

      return { url: session.url, sessionId: session.id };
    } catch (err) {
      console.error("createCheckoutSession error:", err);
      throw new HttpsError("internal", err.message || "Unknown error");
    }
  }
);

exports.confirmTopUp = onCall(
  { region: "us-central1", cors: true },
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

exports.stripeWebhook = onRequest(
  { region: "us-central1", cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const sig = req.headers["stripe-signature"];
    const rawBody = req.rawBody;
    if (!rawBody) {
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
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

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
                const current = doc.exists
                  ? Number(doc.data().balance || 0)
                  : 0;
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

exports.buyNumber = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const uid = request.auth.uid;
      const country = String(request.data.country || "").toLowerCase();
      const product = String(request.data.product || "").toLowerCase();
      const operator = String(request.data.operator || "any");
      const price = Number(request.data.price);

      if (!country || !product) {
        throw new HttpsError("invalid-argument", "Country and product required");
      }
      if (!(price > 0)) {
        throw new HttpsError("invalid-argument", "Invalid price");
      }

      const userRef = admin.firestore().collection("users").doc(uid);

      await admin.firestore().runTransaction(async (tx) => {
        const doc = await tx.get(userRef);
        if (!doc.exists) {
          throw new HttpsError("failed-precondition", "User wallet not found");
        }
        const balance = Number(doc.data().balance || 0);
        if (balance < price) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient balance. Need $${price.toFixed(2)}`
          );
        }
        tx.update(userRef, { balance: balance - price });
      });

      const buyUrl = `https://5sim.net/v1/user/buy/activation/${country}/${operator}/${product}`;
      const response = await fetch(buyUrl, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${FIVESIM_TOKEN}`,
          Accept: "application/json",
        },
      });

      const text = await response.text();
      let data;
      try {
        data = JSON.parse(text);
      } catch (_) {
        data = null;
      }

      if (!response.ok || !data || !data.phone) {
        await admin.firestore().runTransaction(async (tx) => {
          const doc = await tx.get(userRef);
          const balance = Number(doc.data().balance || 0);
          tx.update(userRef, { balance: balance + price });
        });
        console.error("5SIM buy failed:", text);
        throw new HttpsError(
          "internal",
          "Failed to buy number. Balance refunded."
        );
      }

      await admin.firestore().collection("orders").add({
        uid,
        country,
        product,
        operator,
        price,
        phone: data.phone,
        activationId: data.id || null,
        status: data.status || "PENDING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        provider: "5sim",
        raw: data,
      });

      return {
        success: true,
        phone: data.phone,
        activationId: data.id || null,
        status: data.status || "PENDING",
        price,
      };
    } catch (err) {
      console.error("buyNumber error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Buy failed");
    }
  }
);

exports.getCountries = onCall(
  { region: "us-central1", cors: true },
  async () => {
    try {
      const { ok, text, data } = await fivesimGet("/v1/guest/countries");
      if (!ok || !data || typeof data !== "object") {
        console.error("5SIM countries error:", text);
        throw new HttpsError("internal", "Failed to load countries");
      }

      const countries = Object.entries(data).map(([code, info]) => {
        let name =
          (info && (info.text_en || info.name)) ||
          code.charAt(0).toUpperCase() + code.slice(1);
        if (String(code).toLowerCase() === "england") name = "UK";
        return {
          code: String(code).toLowerCase(),
          name: String(name),
          flag: "🌍",
        };
      });

      countries.sort((a, b) => a.name.localeCompare(b.name));
      return { countries };
    } catch (err) {
      console.error("getCountries error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Failed to load countries");
    }
  }
);

exports.getProducts = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    try {
      const country = String(request.data.country || "").toLowerCase().trim();
      if (!country) {
        throw new HttpsError("invalid-argument", "country is required");
      }

      const productsRes = await fivesimGet(
        `/v1/guest/products/${encodeURIComponent(country)}/any`
      );
      if (!productsRes.ok || !productsRes.data) {
        console.error("5SIM products error:", productsRes.text);
        throw new HttpsError("internal", "Failed to load products");
      }

      const pricesRes = await fivesimGet(
        `/v1/guest/prices?country=${encodeURIComponent(country)}`
      );

      let pricesData = {};
      if (pricesRes.ok && pricesRes.data && typeof pricesRes.data === "object") {
        if (pricesRes.data[country]) {
          pricesData = pricesRes.data[country];
        } else {
          pricesData = pricesRes.data;
        }
      }

      const services = [];
      for (const [serviceName, info] of Object.entries(productsRes.data)) {
        if (!info || typeof info !== "object") continue;
        const category = String(
          info.Category || info.category || ""
        ).toLowerCase();
        const qty = Number(info.Qty ?? info.qty ?? 0);
        if (category !== "activation" || qty <= 0) continue;

        let bestCost = Number(info.Price ?? info.price ?? 0.25);
        let bestOperator = "any";
        let bestRate = 0;

        if (
          pricesData[serviceName] &&
          typeof pricesData[serviceName] === "object"
        ) {
          for (const [operatorName, operatorInfo] of Object.entries(
            pricesData[serviceName]
          )) {
            if (!operatorInfo || typeof operatorInfo !== "object") continue;
            const cost = Number(operatorInfo.cost ?? 999);
            const count = Number(operatorInfo.count ?? 0);
            const rate = Number(operatorInfo.rate ?? 0);
            if (count <= 0) continue;
            if (rate > bestRate) {
              bestRate = rate;
              bestCost = cost;
              bestOperator = operatorName;
            } else if (rate === bestRate && cost < bestCost) {
              bestCost = cost;
              bestOperator = operatorName;
            }
          }
        }

        if (!(bestCost > 0)) continue;

        services.push({
          name: String(serviceName).toLowerCase(),
          cost: bestCost,
          price: Number((bestCost * MARKUP).toFixed(2)),
          qty,
          operator: bestOperator,
          rate: bestRate,
          isPopular: POPULAR_SERVICES.has(String(serviceName).toLowerCase()),
        });
      }

      services.sort((a, b) => {
        if (a.isPopular !== b.isPopular) return a.isPopular ? -1 : 1;
        return a.name.localeCompare(b.name);
      });

      return { products: services };
    } catch (err) {
      console.error("getProducts error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Failed to load products");
    }
  }
);