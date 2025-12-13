# Android App Signing & Firebase Configuration Guide

## Overview

This document explains how Android app signing works with Google Play Store and how it affects Firebase services like Google Sign-In.

## What is SHA-1 Fingerprint?

A **SHA-1 fingerprint** is a unique identifier (like a fingerprint) derived from the certificate used to sign your Android app. It proves the app's authenticity and origin.

When you build an Android app, it must be **digitally signed** with a certificate. The SHA-1 fingerprint is calculated from that certificate.

## Why We Have Two Different SHA-1 Certificates

When using Google Play Store's **Play App Signing**, your app uses **two different certificates**:

### 1. Upload Key (Your Local Keystore)

**Location**: `/Users/abhaysingh/keystores/spendpal-upload-keystore.jks`

**SHA-1**: `B2:2E:84:62:5B:BF:6E:6D:30:D4:3A:C2:46:49:BF:91:47:08:3F:20`

**Used For**:
- Building the app locally on your development machine
- Installing via USB debugging (`flutter install`)
- Uploading .aab files to Play Console
- Internal testing and development

**Who Controls It**: You (the developer)

**How to Extract SHA-1**:
```bash
keytool -list -v -keystore /Users/abhaysingh/keystores/spendpal-upload-keystore.jks \
  -alias upload \
  -storepass SpendPal2025!Secure | grep -A 1 "SHA1:"
```

---

### 2. App Signing Key (Google's Certificate)

**Managed By**: Google Play Store

**SHA-1**: `16:73:71:3C:0F:9A:5E:97:94:CA:1A:45:3C:44:F5:E4:8C:44:D2:A5`

**Used For**:
- Apps downloaded from Google Play Store
- Production releases to end users
- All public distribution

**Who Controls It**: Google (stored securely in their infrastructure)

**How to Find SHA-1**:
1. Go to Play Console → Release → Setup → App integrity
2. Look for "App signing key certificate" section
3. Copy the SHA-1 fingerprint

---

## How Play App Signing Works

```
┌─────────────────┐
│  Developer      │
│  Builds App     │
│  Signs with     │
│  Upload Key     │
└────────┬────────┘
         │
         │ Upload .aab
         ▼
┌─────────────────┐
│  Play Console   │
│  1. Removes     │
│     upload sig  │
│  2. Re-signs    │
│     with app    │
│     signing key │
└────────┬────────┘
         │
         │ Distribution
         ▼
┌─────────────────┐
│  End Users      │
│  Download app   │
│  signed by      │
│  Google's key   │
└─────────────────┘
```

### Why Does Google Re-sign?

**Security Benefits**:
- If you lose your upload keystore, Google can still update the app
- Google keeps the "real" production signing key secure in their infrastructure
- You can reset your upload key if it's compromised
- Google manages certificate rotation

---

## Impact on Firebase & Google Sign-In

### How Firebase Uses SHA-1

When your app attempts to use Firebase services (like Google Sign-In):

1. **App requests authentication**
2. **Google checks the app's signature**
   - If installed via USB: Sees upload key SHA-1 (`B2:2E:84:...`)
   - If installed via Play Store: Sees app signing key SHA-1 (`16:73:71:...`)
3. **Google queries Firebase**: "Is this SHA-1 registered for package `com.blrtechpub.spendpal`?"
4. **Authentication decision**:
   - If SHA-1 is registered → Authentication proceeds ✅
   - If SHA-1 is NOT registered → Authentication fails ("Sign-in cancelled") ❌

### Why Sign-In Fails Without Both SHA-1s

| Installation Method | Certificate Used | SHA-1 | Must Be Registered In Firebase |
|-------------------|------------------|-------|-------------------------------|
| **USB Install** (`flutter install`) | Upload Key | `B2:2E:84:...` | ✅ Yes |
| **Play Store Download** | App Signing Key | `16:73:71:...` | ✅ Yes |

**Problem Scenario**:
- Only upload key SHA-1 registered in Firebase
- USB install → Works ✅ (your SHA-1 registered)
- Play Store install → Fails ❌ (Google's SHA-1 not registered)
- Users see "Sign-in cancelled or failed"

**Solution**: Register **BOTH** SHA-1 fingerprints in Firebase

---

## Firebase Configuration Steps

### Step 1: Add Both SHA-1s to Firebase Console

1. Go to **Firebase Console**: https://console.firebase.google.com/
2. Select project: **spendpal-app-blrtechpub**
3. **Settings** (gear icon) → **Project settings**
4. Scroll to **Your apps** → Find Android app: `com.blrtechpub.spendpal`
5. You should see both SHA-1 fingerprints added:
   - Upload key: `B2:2E:84:62:5B:BF:6E:6D:30:D4:3A:C2:46:49:BF:91:47:08:3F:20`
   - App signing key: `16:73:71:3C:0F:9A:5E:97:94:CA:1A:45:3C:44:F5:E4:8C:44:D2:A5`

### Step 2: Create OAuth Clients in Google Cloud Console

For Google Sign-In to work, you need **TWO** OAuth clients (one for each certificate):

1. Go to **Google Cloud Console**: https://console.cloud.google.com/
2. Select project: **spendpal-app-blrtechpub**
3. **APIs & Services** → **Credentials**

**Create OAuth Client for Upload Key**:
- **+ CREATE CREDENTIALS** → **OAuth client ID** → **Android**
- Name: `SpendPal Upload Key`
- Package name: `com.blrtechpub.spendpal`
- SHA-1: `B2:2E:84:62:5B:BF:6E:6D:30:D4:3A:C2:46:49:BF:91:47:08:3F:20`

**Create OAuth Client for App Signing Key**:
- **+ CREATE CREDENTIALS** → **OAuth client ID** → **Android**
- Name: `SpendPal Play Store`
- Package name: `com.blrtechpub.spendpal`
- SHA-1: `16:73:71:3C:0F:9A:5E:97:94:CA:1A:45:3C:44:F5:E4:8C:44:D2:A5`

### Step 3: Download Updated google-services.json

1. Back in **Firebase Console** → **Project settings**
2. Find your Android app
3. Click **Download google-services.json**
4. Replace `android/app/google-services.json` in your project
5. Rebuild the app

---

## Keystore Details

### Upload Keystore Information

**File**: `/Users/abhaysingh/keystores/spendpal-upload-keystore.jks`

**Credentials** (stored in `android/key.properties`):
```properties
storePassword=SpendPal2025!Secure
keyPassword=SpendPal2025!Secure
keyAlias=upload
storeFile=/Users/abhaysingh/keystores/spendpal-upload-keystore.jks
```

**Package Name**: `com.blrtechpub.spendpal`

**IMPORTANT**: Keep this keystore file and passwords secure! Back them up safely.

---

## Troubleshooting

### Google Sign-In Works Locally But Not on Play Store

**Symptom**:
- USB install: Sign-in works ✅
- Play Store install: Shows "Sign-in cancelled" ❌

**Cause**: App signing key SHA-1 not registered in Firebase

**Solution**:
1. Get app signing SHA-1 from Play Console → App integrity
2. Add to Firebase Console → Project settings → Add fingerprint
3. Create OAuth client in Google Cloud Console with the app signing SHA-1
4. Download updated google-services.json
5. Rebuild and upload new version to Play Store

### How to Verify SHA-1 Configuration

**Check Firebase Console**:
- Should see 2 SHA-1 fingerprints under your Android app

**Check Google Cloud Console**:
- APIs & Services → Credentials
- Should see 2 Android OAuth clients for `com.blrtechpub.spendpal`

**Check google-services.json**:
- Should contain `oauth_client` entries with both SHA-1 hashes
- File located at: `android/app/google-services.json`

### Logs Show "Sign-in cancelled" Immediately

If logs show:
```
🔵 Step 3: Calling authenticate()...
ℹ️ User cancelled Google Sign-In
```

But you didn't actually cancel, it means:
- The SHA-1 for the installed app is not registered in Firebase
- Check which SHA-1 the app is using (upload vs app signing)
- Ensure that SHA-1 is added to Firebase Console

---

## Build Variants

| Build Type | Keystore | SHA-1 | When to Use |
|-----------|----------|-------|-------------|
| **Debug** | Android debug key | Different SHA-1 | Development only |
| **Release (USB)** | Upload keystore | `B2:2E:84:...` | Local testing |
| **Release (Play Store)** | App signing key | `16:73:71:...` | Production |

**Note**: Debug builds use a different certificate automatically generated by Android SDK. You typically don't add debug SHA-1 to production Firebase projects.

---

## Summary Checklist

When setting up Google Sign-In for Play Store:

- [ ] Upload keystore SHA-1 added to Firebase Console
- [ ] App signing key SHA-1 added to Firebase Console
- [ ] Upload keystore OAuth client created in Google Cloud Console
- [ ] App signing key OAuth client created in Google Cloud Console
- [ ] Updated google-services.json downloaded and placed in `android/app/`
- [ ] App rebuilt with new google-services.json
- [ ] Tested USB install (should work)
- [ ] Uploaded to Play Store and tested download (should work)

---

## Important Files

| File | Purpose | Location |
|------|---------|----------|
| Upload Keystore | Your signing certificate | `/Users/abhaysingh/keystores/spendpal-upload-keystore.jks` |
| Key Properties | Keystore credentials | `android/key.properties` |
| Firebase Config | OAuth clients & API keys | `android/app/google-services.json` |
| Build Config | App ID & signing config | `android/app/build.gradle.kts` |

---

## References

- [Play App Signing Documentation](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android/start-integrating)
- [Authenticating Your Client](https://developers.google.com/android/guides/client-auth)
