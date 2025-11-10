# Set Admin Role in Firestore

The "insufficient permissions" error occurs because Firestore rules check for `role: 'admin'` in the database, but your user document doesn't have this field set yet.

## Quick Fix - Firebase Console (Easiest)

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: **bong-bazar-3659f**
3. Click **Firestore Database** in the left menu
4. Find the **users** collection
5. Find the document with your email: **mail2adiexp@gmail.com**
6. Click on that document
7. Add/Edit the field:
   - Field: `role`
   - Type: `string`
   - Value: `admin`
8. Click **Update**

## Alternative - Using Flutter App Console

Run this in your browser's JavaScript console while logged in:

```javascript
// Get current user ID
const userId = firebase.auth().currentUser.uid;

// Set admin role
firebase.firestore().collection('users').doc(userId).update({
  role: 'admin'
}).then(() => {
  console.log('✅ Admin role set successfully!');
  alert('Admin role set! Please refresh the page.');
}).catch((error) => {
  console.error('❌ Error:', error);
});
```

## Verify Admin Status

After setting the role:

1. **Restart your Flutter app** (hot reload won't work)
2. Look for this log in the console:
   ```
   👑 Admin resolved | claim=false role=true email=true => isAdmin=true
   ```
3. The `role=true` confirms Firestore role is detected

## Why This Happens

- **App-side check**: Uses email allowlist `{'mail2adiexp@gmail.com'}` ✅
- **Firestore rules**: Check `users/{uid}.role == 'admin'` ❌ (not set yet)

Both need to be true for write operations to work in Firestore.

## Current Firestore Rule

```javascript
match /service_categories/{categoryId} {
  allow read: if true;
  allow write: if isAdmin();  // Checks: users/{uid}.role == 'admin'
}
```

The `isAdmin()` function checks the Firestore `users` collection, not the local app state.
