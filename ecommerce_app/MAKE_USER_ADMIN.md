# Make mail2adiexp@gmail.com an Admin User

## Method 1: Using Firebase Console (Easiest - No Code)

### Step-by-Step:

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select Project**: bong-bazar-3659f
3. **Navigate to**: Firestore Database
4. **Find the users collection**
5. **Search for document** with email = `mail2adiexp@gmail.com`
6. **Edit the document** and add/update field:
   - Field name: `role`
   - Field value: `admin`
   - Type: string
7. **Save** the document

### Then update Firestore Rules:

Go to Firestore Database → Rules and make sure you have this helper function:

```javascript
function isAdmin() {
  return request.auth != null && 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

---

## Method 2: Using Firebase Admin SDK (Advanced)

### Prerequisites:
1. Download Service Account Key from Firebase Console:
   - Settings (gear icon) → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `serviceAccountKey.json` in your project root

### Install Firebase Admin:
```bash
npm install firebase-admin
```

### Run the script:
```bash
node set_admin.js
```

The script will set custom claim `admin: true` for mail2adiexp@gmail.com

---

## Method 3: Using Firebase CLI (Recommended if you have functions)

### Create a Cloud Function:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.setAdmin = functions.https.onCall(async (data, context) => {
  // Only allow if caller is already admin
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can set admin claims');
  }
  
  const email = data.email;
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  
  return { message: `Success! ${email} is now an admin` };
});
```

---

## Method 4: Manual Firestore Update (Quick & Easy)

### Using Firestore in Firebase Console:

1. Open Firestore Database
2. Go to `users` collection
3. Find user with email: `mail2adiexp@gmail.com`
4. Click on the document
5. Add/Edit field:
   ```
   role: "admin"
   ```
6. Save

**After updating, the user needs to:**
- Sign out of the app
- Sign in again
- Admin access will be active

---

## Verification

After making the change, check if it works:

1. Sign in as `mail2adiexp@gmail.com`
2. Go to Account screen
3. You should see "Admin Panel" button
4. Click it to access admin features

If you see the Admin Panel with all 4 tabs (Products, Categories, Services, Featured), you're all set! ✅

---

## Recommended Approach

**Use Method 1** (Firestore Console) - it's the quickest and doesn't require any coding or setup. Just:
1. Open Firestore
2. Find the user document
3. Set `role: "admin"`
4. User signs out and back in
5. Done!
