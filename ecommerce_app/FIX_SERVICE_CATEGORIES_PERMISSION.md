# Fix Service Categories Permission Error

## Problem
Getting error: `[cloud_firestore/permission-denied] Missing or insufficient permissions` when adding service categories.

## Solution - Update Firestore Rules Manually

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select project: **bong-bazar-3659f**
3. Click **Firestore Database** in left menu
4. Click **Rules** tab at the top

### Step 2: Update the Rules

Find these two function definitions at the top of your rules and replace them:

**OLD CODE:**
```javascript
function isAdmin() {
  return request.auth != null && 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

function isSellerOrAdmin() {
  return request.auth != null && 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'seller'];
}
```

**NEW CODE:**
```javascript
function isAdmin() {
  return request.auth != null && (
         // Check email allowlist first
         request.auth.token.email == 'mail2adiexp@gmail.com' ||
         // Or check Firestore role
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
  );
}

function isSellerOrAdmin() {
  return request.auth != null && (
         // Check email allowlist first
         request.auth.token.email == 'mail2adiexp@gmail.com' ||
         // Or check Firestore role
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'seller']
  );
}
```

### Step 3: Publish the Rules
1. Click **Publish** button
2. Confirm the changes

### Step 4: Test
1. **Restart your Flutter app** (hot reload won't work, press 'R' or stop and run again)
2. Try adding a service category again
3. It should work now!

## What This Does

The updated rules allow admin access in two ways:
1. **Email allowlist**: `mail2adiexp@gmail.com` gets instant admin access
2. **Database role**: Users with `role: 'admin'` in Firestore also get access

This way you don't need to set up the database role first - your email is automatically recognized.

## Verify It's Working

After publishing rules, look for this in the console:
```
✅ Service category added successfully
```

Instead of:
```
❌ Error: [cloud_firestore/permission-denied]
```
