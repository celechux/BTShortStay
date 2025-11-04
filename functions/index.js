const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Get Paystack secret key from Firebase config
const PAYSTACK_SECRET_KEY =
  functions.config().paystack?.secret_key || functions.config().paystack?.secret;

const runtimeOpts = {
  timeoutSeconds: 60,
  memory: "512MB",
};

/**
 * Calculate and create commission record
 */
async function calculateCommission(reservationId, paymentAmount) {
  try {
    console.log(`=== CALCULATING COMMISSION FOR RESERVATION: ${reservationId} ===`);

    // Prevent duplicate commissions
    const existingCommission = await admin
      .firestore()
      .collection("commissions")
      .where("reservationId", "==", reservationId)
      .limit(1)
      .get();

    if (!existingCommission.empty) {
      console.log(`Commission already exists for reservation: ${reservationId}`);
      return { success: true, message: "Commission already calculated" };
    }

    // Get reservation details
    const reservationDoc = await admin
      .firestore()
      .collection("reservations")
      .doc(reservationId)
      .get();

    if (!reservationDoc.exists) {
      throw new Error(`Reservation not found: ${reservationId}`);
    }

    const reservationData = reservationDoc.data();

    // Commission: 5% platform fee
    const commissionRate = 0.05;
    const bookingAmount = paymentAmount / 100; // Convert kobo → naira
    const commissionAmount = bookingAmount * commissionRate;
    const hostPayout = bookingAmount - commissionAmount;

    const commissionRef = admin.firestore().collection("commissions").doc();
    await commissionRef.set({
      commissionId: commissionRef.id,
      reservationId,
      apartmentId: reservationData.apartmentId || "",
      hostUid: reservationData.hostUID || reservationData.authUID || "",
      guestUid: reservationData.guestUid || "",
      paymentReference: reservationData.paymentReference || "",
      bookingAmount,
      commissionRate,
      commissionAmount: Math.round(commissionAmount * 100) / 100,
      hostPayout: Math.round(hostPayout * 100) / 100,
      status: "calculated",
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paidToHostAt: null,
      apartmentTitle: reservationData.apartmentTitle || "",
      checkInDate: reservationData.checkIn || null,
      checkOutDate: reservationData.checkOut || null,
      numberOfNights: reservationData.numberOfNights || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ Commission created:", {
      commissionId: commissionRef.id,
      commissionAmount,
      hostPayout,
    });

    return {
      success: true,
      commissionId: commissionRef.id,
      commissionAmount,
      hostPayout,
    };
  } catch (error) {
    console.error("❌ Commission calculation error:", error);
    return {
      success: false,
      error: error.message,
      message: "Commission calculation failed but payment was successful",
    };
  }
}

/**
 * 1️⃣ Initialize Paystack Payment
 */
exports.initializePayment = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    try {
      console.log("=== INITIALIZE PAYMENT FUNCTION ENTRY ===");
      const { email, amount, reference } = data || {};

      if (!email || typeof email !== "string" || !email.includes("@")) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `A valid email is required. Received: ${email}`
        );
      }
      if (amount === undefined || amount === null) {
        throw new functions.https.HttpsError("invalid-argument", "Amount is required.");
      }

      let koboAmount =
        typeof amount === "string" ? parseInt(amount, 10) : Math.round(amount);
      if (isNaN(koboAmount) || koboAmount < 100) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `Amount must be integer >= 100 kobo (₦1). Got: ${koboAmount}`
        );
      }

      if (!PAYSTACK_SECRET_KEY) {
        console.log("⚠️ No Paystack key found — running in EMULATOR MODE");
        return {
          status: true,
          message: "Authorization URL created (EMULATOR MODE)",
          data: {
            authorization_url: "https://checkout.paystack.com/mock-url",
            access_code: "mock_access_code",
            reference: reference || `mock_ref_${Date.now()}`,
          },
        };
      }

      const payload = {
        email: email.trim().toLowerCase(),
        amount: koboAmount,
      };
      if (reference && reference.trim()) payload.reference = reference.trim();

      const response = await axios.post(
        "https://api.paystack.co/transaction/initialize",
        payload,
        {
          headers: {
            Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
            "Content-Type": "application/json",
          },
          timeout: 15000,
        }
      );

      if (!response.data) {
        throw new functions.https.HttpsError("internal", "Empty response from Paystack");
      }

      return response.data;
    } catch (error) {
      console.error("❌ InitializePayment error:", error.response?.data || error.message);
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError(
        "internal",
        error.response?.data?.message || error.message || "Payment initialization failed"
      );
    }
  });

/**
 * 2️⃣ Verify Payment + Update Firestore + Commission
 */
exports.verifyPayment = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    try {
      console.log("=== VERIFY PAYMENT FUNCTION ENTRY ===");
      const { reservationId, reference } = data || {};

      if (!reference || !reservationId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Reference and reservationId are required"
        );
      }

      if (!PAYSTACK_SECRET_KEY) {
        console.log("⚠️ Emulator mode: Verifying mock payment");
        await admin.firestore().collection("reservations").doc(reservationId).update({
          status: "confirmed",
          paymentStatus: "completed",
          paymentTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        const commissionResult = await calculateCommission(reservationId, 100000);
        return {
          status: true,
          message: "Verification succeeded (EMULATOR MODE)",
          data: { status: "success", reference, amount: 100000 },
          commission: commissionResult,
        };
      }

      const response = await axios.get(
        `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
        {
          headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
          timeout: 10000,
        }
      );

      if (!response.data) {
        throw new functions.https.HttpsError("internal", "No data from Paystack verification");
      }

      const paystackData = response.data.data || {};
      const paystackStatus = (paystackData.status || "").toLowerCase();
      const paymentIsSuccessful = ["success", "successful"].includes(paystackStatus);

      if (paymentIsSuccessful) {
        await admin.firestore().collection("reservations").doc(reservationId).update({
          status: "confirmed",
          paymentStatus: "completed",
          paymentTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        await admin.firestore().collection("payments").doc(reference).set({
          reference,
          reservationId,
          amount: paystackData.amount || 0,
          status: paystackData.status || "",
          channel: paystackData.channel || "",
          currency: paystackData.currency || "",
          paidAt: paystackData.paid_at || "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          customer: paystackData.customer || {},
          authorization: paystackData.authorization || {},
          raw: paystackData,
        });

        const commissionResult = await calculateCommission(
          reservationId,
          paystackData.amount || 0
        );

        return {
          status: true,
          message:
            "Payment verified, reservation confirmed, and commission calculated",
          data: paystackData,
          commission: commissionResult,
        };
      } else {
        await admin.firestore().collection("reservations").doc(reservationId).update({
          paymentStatus: "pending",
        });
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Payment verification failed or incomplete (status: ${paystackStatus})`
        );
      }
    } catch (error) {
      console.error("❌ Verification error:", error.response?.data || error.message);
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError(
        "internal",
        error.response?.data?.message || error.message || "Verification failed"
      );
    }
  });

/**
 * 3️⃣ Create Paystack Recipient (for Host payouts)
 */
exports.createPaystackRecipient = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    // 🔓 AUTH CHECKS TEMPORARILY DISABLED
    // if (!context.auth) {
    //   throw new functions.https.HttpsError(
    //     "unauthenticated",
    //     "You must be logged in."
    //   );
    // }

    const hostId = data.hostId; // or context.auth.uid when auth is restored

    // if (hostId !== context.auth.uid) {
    //   throw new functions.https.HttpsError(
    //     "permission-denied",
    //     "You can only create a recipient for your own account"
    //   );
    // }

    const hostRef = admin.firestore().collection("hosts").doc(hostId);
    const hostSnap = await hostRef.get();

    if (!hostSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Host not found");
    }

    const host = hostSnap.data();
    const bankDetails = host.bankDetails || {};

    if (bankDetails.paystackRecipientCode) {
      console.log(`✅ Recipient already exists: ${bankDetails.paystackRecipientCode}`);
      return { 
        success: true, 
        recipient_code: bankDetails.paystackRecipientCode,
        message: "Recipient already exists"
      };
    }

    if (
      !bankDetails.bankName ||
      !bankDetails.accountNumber ||
      !bankDetails.accountName
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Missing bank details (bankName, accountNumber, accountName required)"
      );
    }

    if (!PAYSTACK_SECRET_KEY) {
      console.log("⚠️ Emulator mode — returning mock recipient");
      const mockRecipientCode = `MOCK_RCP_${Date.now()}`;
      await hostRef.update({
        "bankDetails.paystackRecipientCode": mockRecipientCode,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { 
        success: true, 
        recipient_code: mockRecipientCode,
        message: "Mock recipient created (emulator mode)"
      };
    }

    try {
      console.log(`🔄 Creating Paystack recipient for host: ${hostId}`);

      const banksResp = await axios.get("https://api.paystack.co/bank", {
        headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
        timeout: 10000,
      });

      const bank = banksResp.data.data.find((b) =>
        b.name.toLowerCase().includes(bankDetails.bankName.toLowerCase())
      );

      if (!bank) {
        throw new Error(`Bank not found in Paystack list: ${bankDetails.bankName}`);
      }

      console.log(`✅ Bank found: ${bank.name} (${bank.code})`);

      const payload = {
        type: "nuban",
        name: bankDetails.accountName,
        account_number: bankDetails.accountNumber,
        bank_code: bank.code,
        currency: "NGN",
      };

      const response = await axios.post(
        "https://api.paystack.co/transferrecipient",
        payload,
        {
          headers: { 
            Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
            "Content-Type": "application/json"
          },
          timeout: 15000,
        }
      );

      const recipientCode = response.data.data.recipient_code;

      await hostRef.update({
        "bankDetails.paystackRecipientCode": recipientCode,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Paystack recipient created successfully: ${recipientCode}`);
      
      return { 
        success: true, 
        recipient_code: recipientCode,
        message: "Recipient created successfully"
      };

    } catch (err) {
      console.error("❌ Paystack recipient creation failed:", {
        error: err.response?.data || err.message,
        hostId,
        bankDetails: {
          bankName: bankDetails.bankName,
          accountNumber: bankDetails.accountNumber,
          accountName: bankDetails.accountName,
        }
      });

      throw new functions.https.HttpsError(
        "internal",
        err.response?.data?.message || err.message || "Paystack recipient creation failed"
      );
    }
  });

/**
 * 4️⃣ Transfer Payout to Host
 */
exports.transferPayoutToHost = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "You must be logged in"
        );
      }

      const { commissionId } = data;

      if (!commissionId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "commissionId is required"
        );
      }

      console.log(`=== PROCESSING PAYOUT FOR COMMISSION: ${commissionId} ===`);

      const commissionRef = admin.firestore().collection("commissions").doc(commissionId);
      const commissionDoc = await commissionRef.get();

      if (!commissionDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Commission record not found");
      }

      const commission = commissionDoc.data();

      if (commission.status === "paid") {
        console.log(`⚠️ Commission already paid: ${commissionId}`);
        return {
          success: true,
          message: "Payout already processed",
          transfer_code: commission.transferCode || null,
          amount: commission.hostPayout,
        };
      }

      const hostDoc = await admin
        .firestore()
        .collection("hosts")
        .doc(commission.hostUid)
        .get();

      if (!hostDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Host not found");
      }

      const hostData = hostDoc.data();
      const recipientCode = hostData.bankDetails?.paystackRecipientCode;

      if (!recipientCode) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Host does not have a Paystack recipient code. Please ensure host has completed bank setup."
        );
      }

      if (!PAYSTACK_SECRET_KEY) {
        console.log("⚠️ Emulator mode — processing mock transfer");
        const mockTransferCode = `MOCK_TRF_${Date.now()}`;
        
        await commissionRef.update({
          status: "paid",
          paidToHostAt: admin.firestore.FieldValue.serverTimestamp(),
          transferCode: mockTransferCode,
          transferReference: `payout_${commissionId}_${Date.now()}`,
          transferStatus: "success",
        });

        console.log(`✅ Mock payout completed: ${commission.hostPayout}`);
        
        return {
          success: true,
          message: "Mock transfer completed (emulator mode)",
          transfer_code: mockTransferCode,
          amount: commission.hostPayout,
          hostName: hostData.fullName || "Unknown",
        };
      }

      const amountInKobo = Math.round(commission.hostPayout * 100);
      const transferReference = `payout_${commissionId}_${Date.now()}`;

      const payload = {
        source: "balance",
        amount: amountInKobo,
        recipient: recipientCode,
        reason: `Booking payout for ${commission.apartmentTitle || 'reservation'} (${commission.reservationId})`,
        reference: transferReference,
      };

      console.log(`🔄 Initiating Paystack transfer:`, {
        amount: commission.hostPayout,
        recipient: recipientCode,
        reference: transferReference,
      });

      const response = await axios.post(
        "https://api.paystack.co/transfer",
        payload,
        {
          headers: {
            Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
            "Content-Type": "application/json",
          },
          timeout: 15000,
        }
      );

      const transferData = response.data.data;

      await commissionRef.update({
        status: "paid",
        paidToHostAt: admin.firestore.FieldValue.serverTimestamp(),
        transferCode: transferData.transfer_code,
        transferReference: transferReference,
        transferStatus: transferData.status,
        transferAmount: transferData.amount / 100,
      });

      console.log(`✅ Payout transferred successfully:`, {
        hostUid: commission.hostUid,
        amount: commission.hostPayout,
        transfer_code: transferData.transfer_code,
        status: transferData.status,
      });

      return {
        success: true,
        message: "Payout transferred successfully",
        transfer_code: transferData.transfer_code,
        amount: commission.hostPayout,
        status: transferData.status,
        hostName: hostData.fullName || "Unknown",
      };

    } catch (err) {
      console.error("❌ Payout transfer failed:", {
        error: err.response?.data || err.message,
        commissionId: data.commissionId,
      });

      throw new functions.https.HttpsError(
        "internal",
        err.response?.data?.message || err.message || "Payout transfer failed. Please try again."
      );
    }
  });

// ✉️ Send verification code using your domain SMTP


// ✉️ Send verification code using Brevo SMTP
const transporter = nodemailer.createTransport({
  host: "smtp-relay.brevo.com",
  port: 587,
  secure: false,
  auth: {
    user: functions.config().brevo.user, // your Brevo login email
    pass: functions.config().brevo.key,  // your Brevo SMTP key
  },
});

exports.sendVerificationCodeEmail = functions
  .runWith({ timeoutSeconds: 60, memory: "512MB" })
  .https.onCall(async (data, context) => {
    const { email, code } = data;

    if (!email || !code) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and verification code are required."
      );
    }

    const mailOptions = {
      from: '"BT ShortStay" <noreply@btshortstay.com>',
      to: email,
      subject: "Your BT ShortStay Verification Code",
      html: `
        <div style="font-family: Arial, sans-serif; color: #333;">
          <h2>Verify Your Email</h2>
          <p>Hello,</p>
          <p>Your BT ShortStay verification code is:</p>
          <h1 style="color:#007bff;">${code}</h1>
          <p>This code will expire in 10 minutes.</p>
          <p>Thanks,<br><strong>BT ShortStay Team</strong></p>
        </div>
      `,
      text: `Your BT ShortStay verification code is ${code}. It expires in 10 minutes.`,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Verification email sent successfully to: ${email}`);
      return { success: true, message: "Verification email sent" };
    } catch (error) {
      console.error("❌ Error sending verification email:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to send verification email: ${error.message}`
      );
    }
  });
