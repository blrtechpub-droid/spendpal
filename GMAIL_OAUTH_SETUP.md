# Gmail OAuth Setup Documentation

This document provides step-by-step instructions for configuring Gmail API OAuth consent screen for SpendPal.

## Prerequisites

- Google Cloud Console access
- Firebase project linked to SpendPal
- Project ID: spendpal-app-blrtechpub

## Overview

SpendPal uses Gmail API to:
- Read bank transaction emails (HDFC, ICICI, SBI, Axis, Kotak, etc.)
- Parse credit card statements
- Import investment transaction emails (Zerodha, Groww, etc.)
- All processing happens **on-device** (privacy-first approach)

## Step 1: Enable Gmail API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select project: **spendpal-app-blrtechpub**
3. Navigate to **APIs & Services** → **Library**
4. Search for "Gmail API"
5. Click **Gmail API**
6. Click **ENABLE**

**Status**: ✅ Completed

---

## Step 2: Configure OAuth Consent Screen

### Access OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Or navigate to: **Google Auth Platform** → **OAuth consent screen**

### User Type Selection

- Select: **External** (for public app distribution)
- Click **CREATE**

**Status**: ✅ Already configured (automatically redirects to overview)

---

## Step 3: Configure Branding

Navigate to **Branding** section in the left sidebar.

### App Information

| Field | Value |
|-------|-------|
| **App name** | SpendPal |
| **User support email** | blrtechpub@gmail.com |
| **App logo** | Optional (can upload later) |
| **App domain** | firebaseapp.com |
| **Developer contact** | blrtechpub@gmail.com |

### Instructions

1. Click **Branding** in left sidebar
2. Change "project-525963188971" to "SpendPal"
3. Verify user support email: blrtechpub@gmail.com
4. Scroll down and click **SAVE** (if available)

**Status**: ⚠️ In Progress - Update app name to "SpendPal"

---

## Step 4: Configure Data Access (Gmail Scopes)

Navigate to **Data access** section in the left sidebar.

### Required Gmail Scopes

SpendPal requires two Gmail API scopes:

| Scope | Type | Purpose |
|-------|------|---------|
| `https://www.googleapis.com/auth/gmail.readonly` | Restricted | Read-only access to emails |
| `https://www.googleapis.com/auth/gmail.labels` | Non-sensitive | Manage email labels |

**Status**: ✅ Scopes already added

### Scope Justification (Required for Restricted Scopes)

#### What features will you use?
- Select: **Email** or **Read emails**

#### How will the scopes be used?

```
SpendPal uses Gmail API to automatically extract expenses from credit card statements and bank transaction emails (similar to CRED app). The app reads:

1. Credit card monthly statements (PDF and email) from HDFC, ICICI, SBI, Axis, Kotak, Amex, Citi, Standard Chartered
2. Individual transaction alert emails from banks
3. Investment transaction notifications from Zerodha, Groww, Angel Broking, Upstox

The app parses these emails/PDFs to automatically extract:
- Transaction amounts and dates
- Merchant names
- Categories
- Payment methods

All email processing happens on the user's device - emails are never uploaded to our servers, making it more private than CRED. We use gmail.readonly for read-only access (cannot send/delete/modify emails) and gmail.labels to organize imported transactions with labels like "SpendPal-Imported".
```

#### Action Required

1. Go to **Data access** section
2. Scroll down to "What features will you use?" dropdown
3. Select appropriate feature (Email/Read emails)
4. Scroll to "How will the scopes be used?" text field
5. Paste the justification text above
6. Click **SAVE**

**Status**: ⚠️ Pending - Add scope justification

---

## Step 5: Add Test Users

Navigate to **Audience** section in the left sidebar.

### Why Test Users?

During development (Testing mode):
- App shows "unverified app" warning to regular users
- Test users can bypass this warning
- Up to 100 test users allowed

### Add Test Users

1. Click **Audience** in left sidebar
2. Click **ADD USERS** button
3. Add Gmail addresses (one per line):
   - blrtechpub@gmail.com
   - (Add your personal Gmail)
   - (Add team members' Gmail)
4. Click **SAVE**

**Status**: ⚠️ Pending

---

## Step 6: Create OAuth 2.0 Credentials for Android

### Navigate to Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **CREATE CREDENTIALS** → **OAuth 2.0 Client ID**

### Android Configuration

| Field | Value |
|-------|-------|
| **Application type** | Android |
| **Name** | SpendPal Android |
| **Package name** | com.blrtechpub.spendpal |
| **SHA-1 fingerprint** | Get from keystore (see below) |

### Get SHA-1 Fingerprint

**For Release Build** (Production):
```bash
keytool -list -v \
  -keystore android/app/spendpal-release-keystore.jks \
  -alias spendpal
```

**For Debug Build** (Development):
```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android
```

Copy the **SHA-1** fingerprint from the output.

### Create Credential

1. Paste SHA-1 fingerprint
2. Click **CREATE**
3. Download JSON file (optional - not needed in app)

**Status**: ⚠️ Pending

---

## Step 7: Update google-services.json

After creating OAuth credentials, download the latest configuration:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **spendpal-app-blrtechpub** project
3. Go to **Project Settings** → **General**
4. Scroll to **Your apps** → Android app
5. Click download icon for `google-services.json`
6. Replace `android/app/google-services.json` with the new file

**Status**: ⚠️ Pending - After OAuth credential creation

---

## Step 8: Testing Gmail Access

### Test on Device

1. Build and install release APK:
   ```bash
   flutter build apk --release
   adb -s RZCX10CLGPJ install -r build/app/outputs/flutter-apk/app-release.apk
   ```

2. Open SpendPal on device
3. Navigate to **Personal** tab → **Auto-Import**
4. Tap **Email Transactions** card
5. Tap **Connect Gmail** button

### Expected Flow

1. Google Sign-In screen appears
2. User signs in with test account
3. **Warning screen**: "Google hasn't verified this app"
   - This is normal for Testing mode
   - Click **Advanced** → **Go to SpendPal (unsafe)**
4. Grant permissions:
   - ✓ View your email messages
   - ✓ Manage your labels
5. App shows "Gmail connected" status

### Troubleshooting

**Error: "Access blocked: This app's request is invalid"**
- Ensure app is in Testing mode
- Ensure your email is added as a test user

**Error: "invalid_client"**
- Download latest `google-services.json`
- Verify SHA-1 fingerprint is correct
- Clean rebuild: `flutter clean && flutter pub get && flutter run`

**Error: "The Android package name and signing certificate do not match"**
- Verify package name: `com.blrtechpub.spendpal`
- Verify SHA-1 fingerprint matches the keystore you're using to sign the APK

**Status**: ⚠️ Pending - After all configuration complete

---

## Step 9: Publishing (App Verification)

**Note**: Only required for production release. Testing mode is sufficient for beta testing.

### When to Verify

- Before publishing to Play Store (production release)
- When you want to remove the "unverified app" warning
- When you exceed 100 test users

### Verification Requirements

1. **Domain verification**
   - Verify your domain using Google Search Console
   - Add domain to authorized domains

2. **App documentation**
   - App description and features
   - Scope justification (already done in Step 4)
   - Video demo showing Gmail access flow
   - Privacy policy (publicly accessible URL)
   - Homepage URL

3. **Submit for verification**
   - Go to OAuth consent screen
   - Click **PUBLISH APP**
   - Click **PREPARE FOR VERIFICATION**
   - Upload required documents
   - Wait 3-7 days for Google's review

### After Verification

- ✓ Warning screen removed for all users
- ✓ No test user limit
- ✓ Production-ready

**Status**: ⏸️ Not required yet (Testing mode sufficient)

---

## Current Status Summary

| Step | Task | Status |
|------|------|--------|
| 1 | Enable Gmail API | ✅ Complete |
| 2 | OAuth Consent Screen (External) | ✅ Complete |
| 3 | Update Branding (App name) | ⚠️ In Progress |
| 4 | Add Gmail Scopes | ✅ Complete |
| 4b | Add Scope Justification | ⚠️ Pending |
| 5 | Add Test Users | ⚠️ Pending |
| 6 | Create Android OAuth Credentials | ⚠️ Pending |
| 7 | Update google-services.json | ⚠️ Pending |
| 8 | Test Gmail Access | ⚠️ Pending |
| 9 | App Verification (Production) | ⏸️ Future |

---

## Next Steps

1. ✅ **Complete Branding**: Change app name to "SpendPal"
2. ⚠️ **Add Scope Justification**: Fill in the two required fields in Data access
3. ⚠️ **Add Test Users**: Add your Gmail address to Audience section
4. ⚠️ **Create OAuth Credentials**: Generate Android OAuth client with SHA-1
5. ⚠️ **Update google-services.json**: Download and replace configuration file
6. ⚠️ **Test**: Try connecting Gmail from the app

---

## Security & Privacy Notes

### What SpendPal Can Do
- ✓ Read emails (read-only access)
- ✓ Search for specific emails from banks
- ✓ Create/manage labels for organization

### What SpendPal CANNOT Do
- ✗ Send emails
- ✗ Delete emails
- ✗ Modify email content
- ✗ Access emails outside bank/financial categories
- ✗ Upload emails to servers (all processing is on-device)

### Privacy Guarantee

All email processing happens on the user's device. Emails are:
- **Never sent to SpendPal servers**
- **Never stored in cloud databases**
- **Only parsed locally for transaction data**
- **Filtered by sender** (only bank/financial institution emails)

This makes SpendPal **more private than CRED**, which processes emails on their servers.

---

## References

- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
- [OAuth 2.0 for Mobile Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Firestore Security Rules](./firestore.rules)
- [Gmail Service Implementation](./lib/services/gmail_service.dart)

---

**Last Updated**: November 6, 2025
**Document Version**: 1.0
**Author**: SpendPal Development Team
