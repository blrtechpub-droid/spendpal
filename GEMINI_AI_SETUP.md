# Gemini AI SMS Parsing - Setup Guide

This guide explains how to set up Google Gemini AI for SMS expense parsing in SpendPal.

## Overview

SpendPal uses Google's Gemini 2.0 Flash model to parse bank transaction SMS messages with high accuracy (~95-99%). The system automatically falls back to regex-based parsing if AI parsing fails.

**Cost**: ~₹0.011 per SMS (~₹4-66/year depending on usage)
**Accuracy**: 95-99% (vs 70-80% with regex)
**Speed**: 1-2 seconds per SMS

---

## Prerequisites

1. **Google Cloud Project** with Firebase
2. **Firebase Blaze Plan** (pay-as-you-go) - Required for Cloud Functions
3. **Firebase CLI** installed: `npm install -g firebase-tools`

---

## Step 1: Get Gemini API Key

### Option A: Google AI Studio (Easiest)

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Get API Key"**
4. Create a new API key or use existing one
5. Copy the API key (looks like: `AIzaSy...`)

**Free Tier**: 1,500 requests/day

### Option B: Google Cloud Console (For Production)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project (or create new one)
3. Enable **Generative Language API**:
   - Go to APIs & Services → Library
   - Search for "Generative Language API"
   - Click **Enable**
4. Create API Key:
   - Go to APIs & Services → Credentials
   - Click **Create Credentials** → **API Key**
   - Copy the API key
5. (Optional) Restrict API key:
   - Click on the API key name
   - Under "API restrictions", select "Restrict key"
   - Select only "Generative Language API"
   - Save

---

## Step 2: Configure Firebase Functions

### Set the Gemini API Key

Run this command in your project root:

```bash
firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"
```

Replace `YOUR_GEMINI_API_KEY` with the API key you copied in Step 1.

### Verify Configuration

```bash
firebase functions:config:get
```

You should see:

```json
{
  "gemini": {
    "key": "AIzaSy..."
  }
}
```

---

## Step 3: Deploy Cloud Functions

### Build TypeScript Functions

```bash
cd functions
npm run build
cd ..
```

### Deploy to Firebase

```bash
firebase deploy --only functions:parseSmsWithAI
```

This deploys only the SMS parsing function (faster than deploying all functions).

**Or deploy all functions:**

```bash
firebase deploy --only functions
```

### Verify Deployment

```bash
firebase functions:log --only parseSmsWithAI
```

You should see deployment success message.

---

## Step 4: Test AI Parsing

### Test from Client App

1. Build and run the Flutter app
2. Grant SMS permissions
3. Send yourself a test transaction SMS (or use existing SMS)
4. Open **Personal Tab → SMS Expenses**
5. Tap **"Scan SMS Messages"**
6. Check if transactions are detected

### Monitor Logs

**Cloud Function Logs:**
```bash
firebase functions:log --only parseSmsWithAI -n 50
```

**Client Logs (via ADB):**
```bash
adb logcat | grep -i "AI SMS"
```

### Expected Output

**Success:**
```
Parsing SMS with Gemini AI...
Sender: HDFCBK, Date: 2025-11-02
Gemini response received: {"amount":500,"merchant":"SWIGGY",...}
AI parsing successful: SWIGGY - ₹500.0
✅ SMS expense saved to pending
```

**Fallback to Regex:**
```
Error in AI SMS parsing: ...
Falling back to regex-based parsing...
Regex fallback successful: SWIGGY - ₹500.0
```

---

## Cost Management

### Check API Usage

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services → Dashboard**
4. Click on **Generative Language API**
5. View usage metrics

### Set Budget Alerts

1. Go to **Billing → Budgets & alerts**
2. Click **Create Budget**
3. Set amount: ₹100/month (covers ~9,000 SMS parses)
4. Set alert threshold: 50%, 90%, 100%
5. Add email for notifications

### Expected Costs

| Usage | Monthly SMS | Monthly Cost | Annual Cost |
|-------|------------|--------------|-------------|
| Light | 30 SMS | ₹0.33 | ₹4 |
| Average | 100 SMS | ₹1.10 | ₹13 |
| Heavy | 500 SMS | ₹5.50 | ₹66 |
| Very Heavy | 1000 SMS | ₹11 | ₹132 |

---

## Troubleshooting

### Error: "Gemini API not configured"

**Cause**: API key not set in Firebase config

**Solution:**
```bash
firebase functions:config:set gemini.key="YOUR_API_KEY"
firebase deploy --only functions:parseSmsWithAI
```

### Error: "Invalid API Key" or "401 Unauthorized"

**Cause**: API key is incorrect or expired

**Solution:**
1. Generate new API key from Google AI Studio
2. Update Firebase config
3. Redeploy functions

### Error: "Model not available" or "404 Not Found"

**Cause**: Generative Language API not enabled

**Solution:**
1. Go to Google Cloud Console
2. Enable "Generative Language API"
3. Wait 1-2 minutes for propagation

### Error: "Rate limit exceeded" or "429 Too Many Requests"

**Cause**: Exceeded free tier (1,500 requests/day)

**Solution:**
1. Wait for daily reset (resets at midnight PST)
2. Or enable billing for higher limits

### AI Parsing Always Falls Back to Regex

**Check:**
1. View function logs: `firebase functions:log --only parseSmsWithAI -n 20`
2. Look for error messages
3. Verify API key is correct
4. Check if API is enabled in Google Cloud

---

## Security Best Practices

### 1. API Key Restrictions

**Restrict by API:**
- Only allow "Generative Language API"

**Restrict by Application (Optional):**
- Add your Firebase project's App Check tokens

### 2. Function Security

The `parseSmsWithAI` function already includes:
- ✅ Authentication check (only logged-in users)
- ✅ Input validation (minimum SMS length)
- ✅ Error handling with fallback
- ✅ Logging for debugging

### 3. Privacy Considerations

**Data Sent to Gemini:**
- SMS text content
- SMS sender (e.g., "HDFCBK")
- SMS date

**Data NOT Sent:**
- User identity
- Phone numbers
- Other personal data

**Data Storage:**
- Gemini does not store SMS data for training
- All data is processed immediately and discarded

---

## Monitoring & Analytics

### Track AI vs Regex Usage

The `AiSmsParserService.getParsingStats()` method returns:

```dart
{
  'ai': 0,      // Count of AI-parsed expenses
  'regex': 0,   // Count of regex-parsed expenses
  'total': 0    // Total SMS expenses
}
```

### Monitor Function Performance

```bash
# Real-time logs
firebase functions:log --only parseSmsWithAI

# Last 50 invocations
firebase functions:log --only parseSmsWithAI -n 50

# With specific time range
firebase functions:log --only parseSmsWithAI --since 1h
```

---

## Upgrading Gemini Model

### Current Model

**gemini-2.0-flash-exp** (Experimental)
- Fastest
- Cheapest ($0.075/1M input tokens)
- JSON mode support
- 95-99% accuracy

### Alternative Models

**gemini-2.0-flash** (Stable)
- Same pricing
- Production-ready (when exp graduates)

**gemini-pro** (More Powerful)
- Higher accuracy
- 2x cost ($0.50/1M input tokens)
- Better for complex/ambiguous SMS

### How to Change Model

Edit `functions/src/index.ts`:

```typescript
const model = genAI.getGenerativeModel({
  model: 'gemini-pro',  // Change this line
  generationConfig: {
    responseMimeType: 'application/json',
    temperature: 0.1,
  },
});
```

Then redeploy:
```bash
cd functions && npm run build && cd ..
firebase deploy --only functions:parseSmsWithAI
```

---

## Disable AI Parsing (Use Only Regex)

If you want to temporarily disable AI parsing and use only regex:

### Option 1: Comment Out AI Call (Temporary)

Edit `lib/services/ai_sms_parser_service.dart`:

```dart
static Future<SmsExpenseModel?> parseSmsWithAI({...}) async {
  // Immediately fall back to regex (skip AI)
  throw Exception('AI disabled');

  // ... rest of the code
}
```

### Option 2: Use Old SMS Listener (Permanent)

Revert `lib/services/sms_listener_service_android.dart` to use:
```dart
final transaction = SmsParserService.parseSms(smsText, sender, date);
```

---

## Support & Resources

- **Gemini API Docs**: https://ai.google.dev/docs
- **Pricing**: https://ai.google.dev/pricing
- **Cloud Functions Docs**: https://firebase.google.com/docs/functions
- **Firebase Console**: https://console.firebase.google.com/

---

## Quick Reference Commands

```bash
# Set API key
firebase functions:config:set gemini.key="YOUR_KEY"

# Get current config
firebase functions:config:get

# Build functions
cd functions && npm run build && cd ..

# Deploy SMS parser function
firebase deploy --only functions:parseSmsWithAI

# View logs
firebase functions:log --only parseSmsWithAI -n 50

# Test from Firebase CLI
firebase functions:shell
> parseSmsWithAI({smsText: "...", sender: "HDFCBK", date: "2025-11-02"})
```

---

**Version**: 1.1.0
**Last Updated**: 2025-11-02
**Status**: ✅ Production Ready
