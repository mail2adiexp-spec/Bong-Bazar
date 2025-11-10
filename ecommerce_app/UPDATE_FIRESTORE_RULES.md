# Quick Fix: Update Firestore Rules Manually

Since firebase.json doesn't have firestore configured, please update the rules manually:

## Steps:

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project**: bong-bazar-3659f
3. **Navigate to**: Firestore Database → Rules tab
4. **Replace the entire rules** with the content below
5. **Click "Publish"**

---

## Complete Firestore Rules (Copy and Paste):

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check user role
    function isAdmin() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function isSellerOrAdmin() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'seller'];
    }
    
    // Users collection - users can read/write their own data, admins can read all
    match /users/{userId} {
      allow read: if request.auth != null && 
                    (request.auth.uid == userId || isAdmin());
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && 
                      (request.auth.uid == userId || isAdmin());
      allow delete: if isAdmin();
    }
    
    // Products collection - everyone can read, sellers/admins can write
    match /products/{productId} {
      allow read: if true;
      allow create: if isSellerOrAdmin() && 
                      request.resource.data.keys().hasAll(['name', 'price', 'imageUrl', 'description']) &&
                      request.resource.data.price is number &&
                      request.resource.data.price >= 0;
      allow update: if isSellerOrAdmin();
      allow delete: if isSellerOrAdmin();
    }
    
    // Orders collection - users can read their own orders, admins can read all
    match /orders/{orderId} {
      allow read: if request.auth != null && 
                    (resource.data.userId == request.auth.uid || isAdmin());
      allow create: if request.auth != null;
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }
    
    // Categories collection - everyone can read, authenticated users can write (for testing)
    // TODO: Restrict to admins only in production
    match /categories/{categoryId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Cart collection - users can manage their own cart
    match /carts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Reviews collection - authenticated users can create, authors can update/delete
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                              (resource.data.userId == request.auth.uid || isAdmin());
    }
    
    // Service Categories collection - everyone can read, admins can write
    match /service_categories/{categoryId} {
      allow read: if true;
      allow write: if isAdmin();
    }
    
    // Featured Sections collection - everyone can read, admins can write
    match /featured_sections/{sectionId} {
      allow read: if true;
      allow write: if isAdmin();
    }
  }
}
```

---

## What This Fixes:

The new rules add:
- ✅ `featured_sections` collection with read access for everyone
- ✅ Write access only for admins
- ✅ `service_categories` rules (was missing)

After publishing these rules, restart your app and the permission error will be gone!
