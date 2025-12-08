const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Delete user account completely (Auth + Firestore)
 * Only admins can call this function
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // Check if caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  // Check if caller is admin
  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  const callerRole = callerDoc.data()?.role;
  const isAdmin =
    callerRole === "admin" ||
    callerRole === "administrator" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can delete user accounts",
    );
  }

  const { userId, email } = data;

  if (!userId || !email) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId and email are required",
    );
  }

  try {
    const batch = admin.firestore().batch();

    // 1. Delete Firestore user document
    const userRef = admin.firestore().collection("users").doc(userId);
    batch.delete(userRef);

    // 2. Delete partner requests
    const partnerRequestsSnapshot = await admin
      .firestore()
      .collection("partner_requests")
      .where("email", "==", email)
      .get();

    partnerRequestsSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // 3. Delete from pending_sellers if exists
    const pendingSellerRef = admin
      .firestore()
      .collection("pending_sellers")
      .doc(email);
    batch.delete(pendingSellerRef);

    // 4. Commit Firestore deletions
    await batch.commit();

    // 5. Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    return {
      success: true,
      message: `User ${email} deleted successfully from Auth and Firestore`,
    };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to delete user: ${error.message}`,
    );
  }
});

/**
 * Update user role
 * Only admins can call this function
 */
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  // Check if caller is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  // Check if caller is admin
  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  const callerRole = callerDoc.data()?.role;
  const isAdmin =
    callerRole === "admin" ||
    callerRole === "administrator" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can update user roles",
    );
  }

  const { userId, newRole } = data;

  if (!userId || !newRole) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId and newRole are required",
    );
  }

  try {
    // Update Firestore
    await admin.firestore().collection("users").doc(userId).update({
      role: newRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Optionally set custom claims for admin role
    if (newRole === "admin" || newRole === "administrator") {
      await admin.auth().setCustomUserClaims(userId, { admin: true });
    } else {
      await admin.auth().setCustomUserClaims(userId, { admin: false });
    }

    return {
      success: true,
      message: `User role updated to ${newRole}`,
    };
  } catch (error) {
    console.error("Error updating role:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to update role: ${error.message}`,
    );
  }
});

exports.approvePartnerRequest = functions.https.onCall(async (data, context) => {
  // 1. Check if caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to approve partner requests.",
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  const callerRole = callerDoc.data()?.role;
  const isAdmin =
    callerRole === "admin" ||
    callerRole === "administrator" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can approve partner requests.",
    );
  }

  // 2. Validate input
  const { requestId } = data;
  if (!requestId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a 'requestId'.",
    );
  }

  const requestRef = admin.firestore().collection("partner_requests").doc(requestId);

  try {
    const requestDoc = await requestRef.get();

    // 3. Check if the request exists and is pending
    if (!requestDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Partner request not found.");
    }

    const requestData = requestDoc.data();
    if (requestData.status !== "pending") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Request has status '${requestData.status}' and cannot be approved.`,
      );
    }

    const { email, password, name, phone, role, businessName, address, servicePincode } = requestData;

    const lowerCaseRole = role.toLowerCase();

    // 4. Create new user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      disabled: false,
    });

    // 5. Create new user document in Firestore
    const newUserRef = admin.firestore().collection("users").doc(userRecord.uid);
    const userData = {
      uid: userRecord.uid,
      name: name,
      email: email,
      phone: phone,
      role: lowerCaseRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      businessName: businessName || null,
      address: address || null,
      servicePincode: servicePincode || null,
      // Add other fields as necessary
    };

    // Set custom claims if the role is admin
    if (lowerCaseRole === 'admin' || lowerCaseRole === 'administrator') {
      await admin.auth().setCustomUserClaims(userRecord.uid, { admin: true });
    }

    await newUserRef.set(userData);

    // 6. Update the request status to 'approved'
    await requestRef.update({
      status: "approved",
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: context.auth.uid,
    });

    return {
      success: true,
      message: `Successfully approved request and created user for ${email}.`,
      userId: userRecord.uid,
    };
  } catch (error) {
    console.error("Error approving partner request:", error);
    // Check if the error is a Firebase Auth error (e.g., email-already-exists)
    if (error.code && error.code.startsWith('auth/')) {
      throw new functions.https.HttpsError("already-exists", error.message);
    }
    throw new functions.https.HttpsError("internal", "An internal error occurred while approving the request.");
  }
});

/**
 * Create a new Core Staff account
 * Only admins can call this function
 */
exports.createStaffAccount = functions.https.onCall(async (data, context) => {
  // 1. Check if caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to create staff accounts.",
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  const callerRole = callerDoc.data()?.role;
  const isAdmin =
    callerRole === "admin" ||
    callerRole === "administrator" ||
    context.auth.token.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can create staff accounts.",
    );
  }

  // 2. Validate input
  const { email, password, name, phone, position, bio } = data;
  if (!email || !password || !name) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email, password, and name are required.",
    );
  }

  try {
    // 3. Create new user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
      disabled: false,
    });

    // 4. Create new user document in Firestore
    const newUserRef = admin.firestore().collection("users").doc(userRecord.uid);
    const userData = {
      uid: userRecord.uid,
      name: name,
      email: email,
      phone: phone || "",
      position: position || "",
      bio: bio || "",
      role: "core_staff",
      permissions: {
        can_view_dashboard: true, // Default permission
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await newUserRef.set(userData);

    return {
      success: true,
      message: `Successfully created staff account for ${email}.`,
      userId: userRecord.uid,
    };
  } catch (error) {
    console.error("Error creating staff account:", error);
    if (error.code && error.code.startsWith('auth/')) {
      throw new functions.https.HttpsError("already-exists", error.message);
    }
    throw new functions.https.HttpsError("internal", "An internal error occurred while creating the account.");
  }
});