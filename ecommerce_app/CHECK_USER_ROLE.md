# Firebase User Role Check

## Steps to check your user's role:

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Go to **Firestore Database**
4. Click on **Data** tab
5. Open **users** collection
6. Find your user document (by email or UID)
7. Check if there's a **role** field

## If role field is missing or null:

### Option 1: Manually add role
1. Click on your user document
2. Click **+ Add field**
3. Field name: `role`
4. Field value: `seller` (or whatever your role should be)
5. Save

### Option 2: Login with admin email
- Use email: `mail2adiexp@gmail.com`
- This email has admin access without needing role field

## Current Issue:
The rules are checking for `role` field but your user might not have it set.
