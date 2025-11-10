# Featured Sections Management - Setup Guide

## Overview
The app now supports dynamic management of featured sections (HOTS DEALS, Daily Needs, Customer Choices) through the Admin Panel, connected to Firebase Firestore.

## What Changed

### New Files Created:
1. **`lib/models/featured_section_model.dart`** - Model for featured sections
2. **`lib/providers/featured_section_provider.dart`** - Provider for CRUD operations

### Modified Files:
1. **`lib/main.dart`** - Added FeaturedSectionProvider to the app
2. **`lib/screens/admin_panel_screen.dart`** - Added "Featured" tab with full CRUD UI
3. **`lib/screens/home_screen.dart`** - Now fetches sections dynamically from Firestore

## Firestore Collection Structure

Collection: `featured_sections`

Document fields:
- `id` (string) - Auto-generated document ID
- `title` (string) - Display title (e.g., "HOTS DEALS", "Daily Needs")
- `categoryName` (string) - Product category to filter (e.g., "Hot Deals", "Daily Needs")
- `displayOrder` (number) - Order of appearance (1, 2, 3...)
- `isActive` (boolean) - Whether to show this section
- `bannerColor1` (string, optional) - Gradient color 1 (for future use)
- `bannerColor2` (string, optional) - Gradient color 2 (for future use)
- `iconName` (string, optional) - Icon identifier (for future use)

## How to Add Initial Sections

### Option 1: Using Admin Panel (Recommended)
1. Run the app and sign in as an admin
2. Go to Admin Panel → Featured tab
3. Click "Add Section" and fill in:
   - **HOTS DEALS**: Title="HOTS DEALS", Category="Hot Deals", Order=1
   - **Daily Needs**: Title="Daily Needs", Category="Daily Needs", Order=2
   - **Customer Choices**: Title="Customer Choices", Category="Customer Choice", Order=3

### Option 2: Manually in Firebase Console
1. Go to Firebase Console → Firestore Database
2. Create collection `featured_sections`
3. Add three documents with the following data:

**Document 1 (HOTS DEALS):**
```json
{
  "title": "HOTS DEALS",
  "categoryName": "Hot Deals",
  "displayOrder": 1,
  "isActive": true
}
```

**Document 2 (Daily Needs):**
```json
{
  "title": "Daily Needs",
  "categoryName": "Daily Needs",
  "displayOrder": 2,
  "isActive": true
}
```

**Document 3 (Customer Choices):**
```json
{
  "title": "Customer Choices",
  "categoryName": "Customer Choice",
  "displayOrder": 3,
  "isActive": true
}
```

## Firestore Security Rules

Add these rules to allow admin-only writes:

```javascript
match /featured_sections/{sectionId} {
  // Anyone can read
  allow read: if true;
  
  // Only admins can write
  allow write: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}
```

## Admin Panel Features

In the Admin Panel → Featured tab, you can:
- ✅ View all featured sections with their order and status
- ✅ Add new featured sections
- ✅ Edit existing sections (title, category, display order)
- ✅ Toggle active/inactive status with a switch
- ✅ Delete sections
- ✅ See read-only mode if not admin

## Home Screen Behavior

The home screen now:
- Shows the HOTS DEALS banner (if a section with title "HOTS DEALS" is active)
- Displays horizontal carousels for other active sections (Daily Needs, Customer Choices, etc.)
- Sections appear in order based on `displayOrder` field
- Only shows sections where `isActive` is true
- Automatically hides sections with no products

## Testing

1. **Add sections via Admin Panel**
2. **Go to Home screen** - You should see:
   - Category grid (9 categories)
   - HOTS DEALS banner
   - Daily Needs carousel (if products exist in that category)
   - Customer Choices carousel (if products exist in that category)
3. **Toggle a section inactive** - It should disappear from home screen
4. **Change display order** - Sections should reorder accordingly

## Notes

- The HOTS DEALS section is special - it appears as a gradient banner, not a carousel
- Other sections appear as horizontal scrolling carousels
- If a section's category has no products, it won't show on the home screen
- Admin-only access ensures only authorized users can modify featured sections
