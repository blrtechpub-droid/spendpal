# Smart Email Parsing - Testing Guide

## Overview

This guide will help you test the smart email parsing features that were just implemented. The system allows you to upload email screenshots to automatically generate parsing patterns using Vision API and Gemini AI.

## Prerequisites

Before testing, ensure:

1. **Cloud Functions Deployed**:
   ```bash
   cd functions
   firebase deploy --only functions:parseEmailScreenshot
   ```

2. **Firestore Rules Deployed**:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Gemini API Key Configured**:
   ```bash
   firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"
   ```
   Get your key from: https://aistudio.google.com/app/apikey

4. **App Installed**: Latest APK installed on your phone (already done!)

## Testing Methods

### Method 1: Direct Testing via Firestore Console (Easiest for Now)

Since the UI navigation buttons aren't added yet, you can test the backend directly:

#### Step 1: Upload a Test Email Screenshot

1. Take a screenshot of a bank transaction email on your phone
2. Save it to your photo gallery

#### Step 2: Test the Cloud Function Directly

You can test the Cloud Function using Firebase Console:

1. Go to Firebase Console → Functions
2. Find `parseEmailScreenshot` function
3. Click "Test function"
4. Use this test payload:
   ```json
   {
     "imageBase64": "<base64_encoded_image>",
     "userId": "<your_firebase_user_id>"
   }
   ```

#### Step 3: Verify Pattern Created in Firestore

1. Go to Firebase Console → Firestore Database
2. Navigate to: `users/{your_uid}/customEmailPatterns`
3. You should see a new pattern document with:
   - `bankDomain` (e.g., "hdfcbank.com")
   - `bankName` (e.g., "HDFC Bank")
   - `patterns` (amount, merchant, date regex patterns)
   - `gmailFilter` (keywords for Gmail filtering)
   - `confidence` (0-1 score)
   - `active` (false by default)

#### Step 4: Activate the Pattern

1. In Firestore, click on the pattern document
2. Find the `active` field
3. Change it from `false` to `true`

#### Step 5: Test Email Parsing

The pattern will now be used automatically when parsing emails from that bank!

---

### Method 2: Testing via App UI (After Navigation Added)

I'll add navigation buttons to make testing easier. Here's how you'll test once those are added:

#### Feature 1: Upload Email Screenshot

**Location**: Email Transactions Screen → AppBar → Camera Icon

**Steps**:
1. Open SpendPal app
2. Go to "Auto Import" tab (bottom navigation)
3. Tap "Email" in the tab bar
4. Tap the camera icon in the top right (will be added)
5. Choose "Camera" or "Gallery"
6. Select/take a photo of a bank transaction email
7. Tap "Upload & Analyze"

**Expected Result**:
- Progress indicator shows "Uploading screenshot and analyzing..."
- After 3-5 seconds, you see:
  - Bank name (e.g., "HDFC Bank")
  - Bank domain (e.g., "hdfcbank.com")
  - Confidence score (e.g., "75%")
  - Keywords as chips (e.g., "debit", "transaction", "account")
  - Success message: "Pattern generated successfully"

**What to Check**:
- Does it correctly identify the bank?
- Are the keywords relevant?
- Is the confidence score reasonable (>50%)?

#### Feature 2: Pattern Management

**Location**: Email Transactions Screen → AppBar → Settings Icon

**Steps**:
1. From Email Transactions screen
2. Tap the settings/manage icon in the top right (will be added)
3. You'll see all your custom patterns

**Expected Result**:
- List of all patterns you've created
- Each pattern shows:
  - Bank name and domain
  - Confidence score (color-coded: green >70%, orange >50%, red <50%)
  - Priority level
  - Usage statistics (used count, success count, failure count)
  - Keywords as chips
  - Toggle switch (active/inactive)

**What to Check**:
- Can you toggle patterns on/off?
- Do the statistics update after using the pattern?
- Can you delete patterns?
- Can you view pattern details?

---

## Test Scenarios

### Scenario 1: Upload HDFC Bank Email Screenshot

**Prepare**:
1. Find an HDFC Bank transaction email in your Gmail
2. Take a screenshot

**Test**:
1. Upload the screenshot
2. Verify pattern generated with:
   - Bank: "HDFC Bank"
   - Domain: "hdfcbank.com"
   - Keywords: "debited", "HDFC", "account", etc.

**Verify in Firestore**:
```
users/{uid}/customEmailPatterns/{pattern_id}:
  bankName: "HDFC Bank"
  bankDomain: "hdfcbank.com"
  patterns:
    amount:
      regex: "Rs\\.?\\s*([0-9,]+\\.?[0-9]*)"
      captureGroup: 1
      type: "debit"
    merchant:
      regex: "at\\s+([A-Z\\s]+)"
      captureGroup: 1
  gmailFilter:
    from: "hdfcbank.com"
    keywords: ["debited", "transaction", "account"]
  confidence: 0.7
  active: false
```

### Scenario 2: Activate Pattern and Parse Email

**Steps**:
1. Activate the HDFC pattern (set `active: true`)
2. Go to Email Transactions screen
3. Tap "Sync Emails"
4. Wait for emails to be fetched
5. Check if HDFC Bank emails are parsed correctly

**Expected**:
- HDFC emails should appear in the pending list
- Amount, merchant, and date should be extracted
- The pattern's `usageCount` and `successCount` should increment

### Scenario 3: Multiple Banks

**Test**:
1. Upload screenshots from 3 different banks:
   - HDFC Bank
   - ICICI Bank
   - SBI
2. Verify each creates a separate pattern
3. Activate all patterns
4. Sync emails
5. Check that emails from each bank are parsed correctly

---

## Debugging

### Check Cloud Function Logs

```bash
firebase functions:log --only parseEmailScreenshot -n 20
```

Look for:
- ✅ "Vision API extracted text"
- ✅ "Gemini generated pattern"
- ✅ "Pattern saved to Firestore"
- ❌ Any error messages

### Check Firestore Data

Verify the pattern structure matches the schema:
```javascript
{
  bankDomain: string,
  bankName: string,
  patterns: {
    amount: { regex, captureGroup, type },
    merchant: { regex, captureGroup },
    date: { regex, format }
  },
  gmailFilter: {
    from: string,
    keywords: string[]
  },
  confidence: number (0-1),
  active: boolean,
  priority: number (10 for user patterns),
  usageCount: number,
  successCount: number,
  failureCount: number,
  createdAt: timestamp
}
```

### Common Issues

**Issue 1: "Vision API error"**
- Solution: Ensure Cloud Vision API is enabled in Google Cloud Console
- Already should be enabled from SMS implementation

**Issue 2: "Gemini API error"**
- Solution: Check Gemini API key is configured:
  ```bash
  firebase functions:config:get gemini.key
  ```

**Issue 3: Pattern not used during parsing**
- Solution: Ensure `active: true` in Firestore
- Clear pattern cache by toggling the pattern off and on

**Issue 4: Low confidence score**
- This is normal for first-time patterns
- Confidence improves as the pattern is used successfully
- Formula: `(successCount / totalCount) * usageWeight * verifiedBonus`

---

## Performance Testing

### Test 1: Upload Speed
- Expected: 3-5 seconds for image upload + analysis
- Factors: Image size, network speed, AI processing

### Test 2: Pattern Cache
- First load: Fetches from Firestore
- Subsequent loads (within 1 hour): Uses cached patterns
- Verify: Check debug logs for "Using cached patterns"

### Test 3: Email Parsing Speed
- With patterns: Should parse 10-20 emails/second
- Fallback (no pattern): Uses hardcoded parsing

---

## Next Steps

### After UI Navigation is Added

I'll add two buttons to the Email Transactions Screen AppBar:

1. **Camera Icon** → Upload Email Screenshot Screen
2. **Settings Icon** → Pattern Management Screen

Then you can test the full UI flow!

### Future Enhancements

1. **Manual Correction Flow**: Mark unparsed emails and generate patterns from them
2. **Pattern Sharing**: Share successful patterns to global collection
3. **Pattern Merger**: Automatically merge similar patterns
4. **Multi-language Support**: Handle emails in Hindi and regional languages

---

## Quick Test Checklist

- [ ] Gemini API key configured
- [ ] Cloud Functions deployed
- [ ] Firestore rules deployed
- [ ] App installed on phone
- [ ] Test email screenshot uploaded
- [ ] Pattern created in Firestore
- [ ] Pattern activated (active: true)
- [ ] Email parsing tested
- [ ] Statistics updated correctly
- [ ] Pattern management works
- [ ] Multiple banks tested

---

**Ready to test!** Start with Method 1 (Firestore Console) to verify the backend works, then we'll add the UI buttons for easier testing.
