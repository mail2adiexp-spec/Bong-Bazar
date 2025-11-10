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

  const {userId, email} = data;

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

  const {userId, newRole} = data;

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
      await admin.auth().setCustomUserClaims(userId, {admin: true});
    } else {
      await admin.auth().setCustomUserClaims(userId, {admin: false});
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
