# Quick Fix: Add Featured Sections to Firestore

## Go to Firebase Console

1. Open: https://console.firebase.google.com
2. Select project: **bong-bazar-3659f**
3. Go to: **Firestore Database**
4. Find or create collection: **`featured_sections`**

## Add Three Documents

### Document 1: HOTS DEALS
Click "Add Document" and enter:
```
Document ID: (auto-generate)

Fields:
title: "HOTS DEALS" (string)
categoryName: "Hot Deals" (string)
displayOrder: 1 (number)
isActive: true (boolean)
```

### Document 2: Daily Needs
Click "Add Document" and enter:
```
Document ID: (auto-generate)

Fields:
title: "Daily Needs" (string)
categoryName: "Daily Needs" (string)
displayOrder: 2 (number)
isActive: true (boolean)
```

### Document 3: Customer Choices
Click "Add Document" and enter:
```
Document ID: (auto-generate)

Fields:
title: "Customer Choices" (string)
categoryName: "Customer Choice" (string)
displayOrder: 3 (number)
isActive: true (boolean)
```

## After Adding

1. Hot reload your app (press 'r' in terminal)
2. Go to home screen
3. You should now see:
   - HOTS DEALS banner
   - Daily Needs carousel (if products exist in that category)
   - Customer Choices carousel (if products exist in that category)

## Note

The carousels will only show if you have products in those categories. Make sure you have:
- Products with category = "Daily Needs"
- Products with category = "Customer Choice"
- Products with category = "Hot Deals"
