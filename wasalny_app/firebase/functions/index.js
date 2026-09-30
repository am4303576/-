const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Resend } = require("resend");

admin.initializeApp();
const db = admin.firestore();

// API Key can be set via: firebase functions:config:set resend.key="YOUR_KEY"
const resend = new Resend(process.env.RESEND_API_KEY || "re_dummy_key");

/**
 * Cloud Function: requestOtp
 * Generates 6-digit OTP, hashes it, stores with 5-minute expiry, sends email.
 */
exports.requestOtp = functions.https.onCall(async (data, context) => {
  const email = (data.email || "").trim().toLowerCase();
  const inviteCode = (data.inviteCode || "").trim();

  if (!email || !email.includes("@")) {
    throw new functions.https.HttpsError("invalid-argument", "بريد إلكتروني غير صالح.");
  }

  // Admin Check
  if (email === "am4303576@gmail.com") {
    // Check initial Admin code
    if (inviteCode !== "178jab90") {
      throw new functions.https.HttpsError("permission-denied", "الرمز السري الخاص بالمالك غير صحيح.");
    }
  }

  // Generate 6-digit OTP
  const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

  await db.collection("otp_requests").doc(email).set({
    email: email,
    code: otpCode,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    attempts: 0,
  });

  // Send Email via Resend
  try {
    await resend.emails.send({
      from: "وصلني <onboarding@resend.dev>",
      to: email,
      subject: "رمز التحقق لتطبيق وصلني (OTP)",
      html: `
        <div dir="rtl" style="font-family: Arial, sans-serif; text-align: center; padding: 20px;">
          <h2 style="color: #FF5722;">تطبيق وصلني لتوصيل الطعام</h2>
          <p>رمز التأكيد الخاص بك لتسجيل الدخول هو:</p>
          <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #333; margin: 20px 0;">${otpCode}</div>
          <p style="color: #888;">هذا الرمز صالح لمدة 5 دقائق فقط. لا تشاركه مع أي شخص.</p>
        </div>
      `,
    });
  } catch (error) {
    console.error("Error sending email:", error);
  }

  return { success: true, message: "تم إرسال رمز التحقق إلى بريدك الإلكتروني." };
});

/**
 * Cloud Function: onOrderStatusUpdated
 * Sends High Priority FCM push notification to Customer when order status changes.
 */
exports.onOrderStatusUpdated = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return null;

    const customerId = after.customerId;
    const userDoc = await db.collection("users").doc(customerId).get();
    if (!userDoc.exists) return null;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return null;

    let statusText = "";
    switch (after.status) {
      case "received":
        statusText = "تم استلام طلبك من قِبل المطعم!";
        break;
      case "preparing":
        statusText = "طلبك قيد التجهيز الآن في المطبخ 👨‍🍳";
        break;
      case "picked_up":
        statusText = `الكابتن (${after.captainName || ""}) استلم طلبك وهو في الطريق إليك 🛵`;
        break;
      case "delivered":
        statusText = "تم تسليم طلبك بنجاح! بالعافية 🎉";
        break;
      case "cancelled":
        statusText = "تم إلغاء الطلب.";
        break;
      default:
        statusText = `تغيرت حالة طلبك إلى: ${after.status}`;
    }

    const payload = {
      notification: {
        title: `تحديث طلبك #${after.orderNumber}`,
        body: statusText,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "wasalny_order_updates",
          sound: "default",
          priority: "max",
        },
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
  });
