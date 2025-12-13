# Gmail API Setup Guide for SpendPal

This guide will walk you through setting up Gmail API access for SpendPal's email transaction import feature (like CRED).

## Overview

SpendPal uses Gmail API to:
- Read bank transaction emails
- Parse credit card statements
- Import investment transaction emails
- **All processing happens on-device** (more private than CRED)

## Step 1: Google Cloud Console Setup

### 1.1 Access Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your existing Firebase project (the one linked to SpendPal)
   - Project ID should match what's in `android/app/google-services.json`

### 1.2 Enable Gmail API
1. In the sidebar, navigate to **APIs & Services** → **Library**
2. Search for "Gmail API"
3. Click on **Gmail API**
4. Click **ENABLE**

### 1.3 Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **External** user type (unless you have G Suite/Workspace)
3. Click **CREATE**

#### Fill in Application Information:
- **App name**: SpendPal
- **User support email**: Your email
- **App logo**: Upload SpendPal icon (optional)
- **Application home page**: Your app website or Firebase hosting URL
- **Application privacy policy link**: Your privacy policy URL
- **Application terms of service link**: Your terms URL (optional)
- **Authorized domains**:
  - `firebaseapp.com`
  - Your custom domain (if any)
- **Developer contact information**: Your email

Click **SAVE AND CONTINUE**

#### 1.4 Configure Scopes
Click **ADD OR REMOVE SCOPES**

Add these scopes:
```
https://www.googleapis.com/auth/gmail.readonly
https://www.googleapis.com/auth/gmail.labels
https://www.googleapis.com/auth/userinfo.email
```

**Scope Justification** (you may need to provide this):
- `gmail.readonly`: To read emails from banks and credit card companies for transaction parsing
- `gmail.labels`: To organize imported transactions with labels
- `userinfo.email`: To identify the user

Click **UPDATE** then **SAVE AND CONTINUE**

#### 1.5 Add Test Users
During development, add test email addresses:
1. Click **ADD USERS**
2. Add your Gmail address (and team members)
3. Click **SAVE AND CONTINUE**

#### 1.6 Review and Finish
Review all settings and click **BACK TO DASHBOARD**

## Step 2: Create OAuth 2.0 Credentials

### 2.1 For Android

1. Go to **APIs & Services** → **Credentials**
2. Click **CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
3. Select **Application type**: **Android**
4. Fill in:
   - **Name**: SpendPal Android
   - **Package name**: `com.blrtechpub.spendpal`
     (from `android/app/build.gradle.kts`)

#### Get SHA-1 Certificate Fingerprint:

**For Debug Build:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**For Release Build:**
```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-alias
```

Copy the **SHA-1** fingerprint and paste it in the form.

5. Click **CREATE**
6. Download the JSON file (optional, not needed for app)

### 2.2 For iOS

1. Click **CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
2. Select **Application type**: **iOS**
3. Fill in:
   - **Name**: SpendPal iOS
   - **Bundle ID**: Get from `ios/Runner.xcodeproj/project.pbxproj`
     (look for `PRODUCT_BUNDLE_IDENTIFIER`)

4. Click **CREATE**
5. Note down the **Client ID** (you'll need this for iOS configuration)

### 2.3 For Web (Optional - for future web support)

1. Click **CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
2. Select **Application type**: **Web application**
3. Fill in:
   - **Name**: SpendPal Web
   - **Authorized JavaScript origins**:
     - `http://localhost:5000` (for development)
     - Your Firebase Hosting URL
   - **Authorized redirect URIs**:
     - `http://localhost:5000/__/auth/handler`
     - `https://YOUR_PROJECT.firebaseapp.com/__/auth/handler`

4. Click **CREATE**

## Step 3: Update Android Configuration

### 3.1 Update google-services.json
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** → **General**
4. Scroll to **Your apps**
5. Click the download icon next to **google-services.json**
6. Replace `android/app/google-services.json` with the new file

### 3.2 Update build.gradle (if needed)
The OAuth credentials are automatically linked via:
- Package name in `android/app/build.gradle.kts`
- SHA-1 fingerprint registered in Google Cloud Console
- google-services.json file

No additional configuration needed!

## Step 4: Update iOS Configuration (if supporting iOS)

### 4.1 Update Info.plist
Add the following to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your iOS Client ID (reversed) -->
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
    </array>
  </dict>
</array>
```

### 4.2 Download GoogleService-Info.plist
1. Firebase Console → Project Settings → Your apps
2. Click iOS app
3. Download `GoogleService-Info.plist`
4. Replace `ios/Runner/GoogleService-Info.plist`

## Step 5: Testing Gmail Access

### 5.1 Test Authentication Flow

1. Build and run the app:
```bash
flutter run
```

2. Navigate to **Personal** tab → **Auto-Import**
3. Tap **Email Transactions** card
4. Tap the **"Connect Gmail"** button (when implemented)
5. You should see Google Sign-In screen
6. Sign in with a test user account
7. **IMPORTANT**: You'll see a scary warning: "Google hasn't verified this app"
   - This is normal for apps in testing mode
   - Click **Advanced** → **Go to SpendPal (unsafe)**
   - This warning will disappear once you verify your app (see Step 6)

8. Grant permissions:
   - ✓ View your email messages
   - ✓ Manage your labels

### 5.2 Verify Access
After granting permissions:
- App should show "Gmail connected"
- You should be able to sync emails manually
- Transactions should appear in the review queue

## Step 6: Publishing (Verification)

### For Production Release:

#### 6.1 Verify Your Domain
1. Google Cloud Console → OAuth consent screen
2. Add and verify your domain using Google Search Console

#### 6.2 Complete App Verification
Google requires verification for sensitive scopes like Gmail:

1. Prepare documentation:
   - **App description**: Explain SpendPal's expense tracking features
   - **Scope justification**: Why you need Gmail access (transaction parsing)
   - **Video demo**: Show the app requesting and using Gmail access
   - **Privacy policy**: Must be publicly accessible
   - **Homepage URL**: Where users can learn about your app

2. Submit for verification:
   - Go to OAuth consent screen
   - Click **PUBLISH APP**
   - Click **PREPARE FOR VERIFICATION**
   - Upload required documents

3. Wait for Google's review (can take 3-7 days)

#### 6.3 What Changes After Verification?
- ✓ Warning screen removed for all users
- ✓ No test user limit
- ✓ Production-ready

## Step 7: Privacy & Security Best Practices

### 7.1 Inform Users
Add a clear explanation in-app:
```
SpendPal reads emails from:
✓ Banks (HDFC, ICICI, SBI, etc.)
✓ Credit card companies
✓ Investment platforms (Zerodha, Groww, etc.)

SpendPal NEVER reads:
✗ Personal emails
✗ Work emails
✗ Social media notifications

All email processing happens on YOUR device.
Emails are never sent to SpendPal servers.
```

### 7.2 Allow Easy Disconnection
Provide a button in Settings:
- "Disconnect Gmail" button
- Shows when access was granted
- Revokes all tokens when clicked

### 7.3 Minimal Scope Request
SpendPal only requests `gmail.readonly` (read-only):
- ✓ Cannot send emails
- ✓ Cannot delete emails
- ✓ Cannot modify emails
- ✓ More secure than CRED's full access

## Troubleshooting

### Error: "Access blocked: This app's request is invalid"
**Solution**: Make sure:
- OAuth consent screen is configured
- App is in "Testing" mode with your email as a test user
- OR app is published

### Error: "The Android package name and signing certificate do not match"
**Solution**:
- Verify package name in `android/app/build.gradle.kts` matches Google Cloud Console
- Verify SHA-1 fingerprint is correct
- Regenerate and download new `google-services.json`

### Error: "invalid_client"
**Solution**:
- Download latest `google-services.json` from Firebase Console
- Clean and rebuild app: `flutter clean && flutter pub get && flutter run`

### Silent Sign-In Fails
**Solution**:
- User needs to grant permissions at least once
- After first sign-in, silent sign-in will work
- Check if Gmail scopes are included in GoogleSignIn initialization

### Emails Not Showing Up
**Solution**:
- Verify Gmail API is enabled
- Check query syntax (sender domains must match exactly)
- Test with a known transaction email first
- Check Firebase Crashlytics for errors

## Support

For more help:
- [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [OAuth 2.0 for Mobile Apps](https://developers.google.com/identity/protocols/oauth2/native-app)

## Security Notes

### Do NOT commit these files:
- `android/app/google-services.json` (add to .gitignore if containing sensitive data)
- `ios/Runner/GoogleService-Info.plist`
- Release keystores
- OAuth client secrets

### Do commit:
- This setup guide
- Privacy policy
- Terms of service

---

**Last Updated**: January 2025
**SpendPal Version**: 1.0.0+12
