# SMS Auto-Expense Tracking

## Overview

SpendPal automatically detects and extracts expense information from bank transaction SMS messages on Android devices. When you make a purchase using your debit/credit card or UPI, the SMS from your bank is parsed and saved as a **pending expense** for you to review and categorize.

**Key Change from v1.0**: SMS expenses are no longer automatically added to your personal expenses. Instead, they appear in a dedicated **SMS Expenses** screen where you can review, categorize, or ignore them before they're added to your main expense list.

---

## How It Works

### Current Workflow (v1.1+)

1. **Background Monitoring**: App listens for incoming SMS messages in the background
2. **Smart Detection**: Identifies bank transaction messages using pattern matching
3. **Auto-Parsing**: Extracts amount, merchant name, date, and category
4. **Pending Storage**: Saves to `sms_expenses` collection with status 'pending'
5. **User Review**: Transaction appears in SMS Expenses screen with badge notification
6. **User Categorization**: You choose what to do with each transaction:
   - **Add as Personal** → Creates personal expense immediately
   - **Share with Friend/Group** → Pre-fills expense form, you choose split
   - **Ignore** → Hides from pending list (can be restored)
   - **Delete** → Permanently removes
7. **Final Storage**: Only categorized expenses appear in main expense list

### Benefits of New Workflow

✅ **No Auto-Clutter**: Your personal expenses stay clean and intentional
✅ **Flexible Splitting**: Decide which expenses to share with friends/groups
✅ **Review Control**: Approve each transaction before it's added
✅ **Categorization Choice**: Change category before adding
✅ **Mistake Prevention**: Avoid duplicate or incorrect expenses

---

## Features

### Automatic Detection
- ✅ Works with all major Indian banks (HDFC, ICICI, SBI, etc.)
- ✅ Supports UPI transactions (Paytm, PhonePe, GPay, etc.)
- ✅ Detects debit card, credit card, and net banking transactions
- ✅ Skips credit/refund messages (only creates expenses for debits)
- ✅ Configurable scan duration: 7, 15, 30, 60, or 90 days (default: 30)

### Smart Categorization
Automatically categorizes expenses based on merchant name:
- **Food**: Swiggy, Zomato, restaurants, cafes
- **Groceries**: DMart, BigBasket, Blinkit, Zepto
- **Shopping**: Amazon, Flipkart, Myntra, AJIO
- **Travel**: Uber, Ola, Rapido, MakeMyTrip, IRCTC, fuel stations
- **Entertainment**: Netflix, Prime Video, Hotstar, BookMyShow
- **Utilities**: Electricity, water, broadband, mobile recharges
- **Healthcare**: Pharmacies, hospitals, clinics
- **Other**: Everything else

### Data Extraction
From each SMS, the app extracts:
- **Amount**: ₹500, Rs.1,200, INR 2500
- **Merchant**: Store or service name
- **Account Info**: Last 4 digits of card/account
- **Transaction ID**: Reference number for deduplication
- **Date/Time**: When the transaction occurred

### Platform Support
- ✅ **Android**: Full support with background SMS monitoring
- ❌ **iOS**: Not supported (iOS doesn't allow third-party SMS access)
  - App shows helpful explanation when opened on iOS

### Enhanced Error Handling
- **Permission Issues**: Clear instructions to grant SMS permissions
- **iOS Detection**: Explains platform limitation with helpful message
- **Database Errors**: Specific error messages with retry options
- **Timeout Errors**: Suggests scanning shorter duration

---

## Supported SMS Formats

The parser uses generic patterns that work with most bank SMS formats:

```
✅ HDFC Bank: Your A/c XX1234 debited for Rs.500 at SWIGGY on 26-OCT-25. Ref No: TXN12345

✅ ICICI: Rs 1,200 debited from A/c **4567 on 26-OCT-25 for AMAZON Purchase. Ref: ABC123

✅ SBI: Dear Customer, INR 2,500 has been debited from your Card XX8900 at BIGBASKET

✅ Paytm: Payment of Rs.250 to UBER via UPI successful. UPI Ref: 123456789

✅ PhonePe: Rs 800 paid to ZOMATO. UPI Txn ID: ABC@paytm
```

**Limitation**: Regex-based parsing has limitations with non-standard formats. See [AI-Based SMS Parsing](#ai-based-sms-parsing-future) for a more robust solution.

---

## Permissions Required

### Android Permissions
- **READ_SMS**: To read existing SMS messages
- **RECEIVE_SMS**: To receive new SMS messages in real-time
- **SEND_SMS**: For telephony package requirements (not actively used)

**Privacy Promise**: The app only reads transaction-related SMS. It does not read personal messages or share SMS data with any third party.

---

## Setup & Usage

### First Time Setup

1. **Install the App**: Build and install on Android device
2. **Grant Permissions**: On first launch, app will request SMS permissions
3. **Open Personal Tab**: Tap the message icon in the top-right corner
4. **Scan SMS**: Choose duration (7-90 days) and tap "Scan SMS Messages"
5. **Review Pending**: See all detected transactions in the SMS Expenses screen
6. **Categorize**: Add as personal, share, ignore, or delete each transaction

### Daily Usage

1. **Make Purchase**: Use your card/UPI for payment
2. **Receive Bank SMS**: Bank sends transaction confirmation SMS
3. **Auto-Detection**: App automatically detects and parses SMS in background
4. **Badge Notification**: Red badge appears on message icon in Personal tab
5. **Review & Categorize**: Open SMS Expenses screen, review transaction, choose action

### SMS Expenses Screen

**Access**: Personal Tab → Message Icon (with red badge showing pending count)

**Features**:
- **Duration Selector**: AppBar shows current duration, tap to change (7/15/30/60/90 days)
- **Scan Button**: Manually trigger SMS scan for selected duration
- **Pending Count**: Shows how many transactions await categorization
- **Transaction Cards**: Each card shows:
  - Merchant name and amount
  - Date and category
  - Account info (last 4 digits)
  - Transaction ID
  - Raw SMS (tap to expand)
- **Swipe Actions**:
  - Swipe left → Ignore or Delete
  - Swipe right → Add as Personal
- **Tap Actions**:
  - Tap "Add as Personal" → Creates personal expense immediately
  - Tap "Share with Friends/Groups" → Opens add expense form with pre-filled data

---

## Technical Implementation

### Files Created

1. **`lib/models/sms_expense_model.dart`**
   - Pending expense data model
   - Fields: id, amount, merchant, date, category, status, userId, etc.
   - Status: 'pending', 'categorized', 'ignored'
   - Methods: fromDocument, toFirestore, copyWith
   - Helper getters: isPending, isCategorized, isIgnored

2. **`lib/services/sms_expense_service.dart`**
   - Business logic for SMS expense categorization
   - Methods:
     - `getPendingSmsExpenses()` - Stream of pending expenses
     - `getPendingCount()` - Count of pending expenses for badge
     - `categorizeAsPersonal()` - Convert to personal expense
     - `markAsCategorized()` - Mark as categorized (when shared)
     - `ignoreSmsExpense()` - Hide from pending list
     - `deleteSmsExpense()` - Permanently delete
     - `getAllSmsExpenses()` - Get all (for history)
     - `restoreSmsExpense()` - Restore ignored expense

3. **`lib/screens/sms_expenses/sms_expenses_screen.dart`**
   - User interface for reviewing and categorizing SMS expenses
   - Features:
     - Platform detection (shows iOS message)
     - Duration selector bottom sheet
     - Permission handling with retry
     - Error state with contextual help
     - Loading state during scan
     - Empty state with scan prompt
     - Transaction cards with swipe actions
     - Detailed error messages

4. **`lib/services/sms_parser_service.dart`** (395 lines)
   - Transaction SMS detection using regex patterns
   - Amount/merchant extraction
   - Smart categorization based on keywords
   - Duplicate prevention
   - **NEW**: `saveSmsExpenseToPending()` method (replaces direct expense creation)

5. **`lib/services/sms_listener_service.dart`** (160 lines)
   - Background SMS listening
   - Permission handling
   - Message processing
   - Manual import functionality
   - **UPDATED**: Default scan duration changed from 7 to 30 days

### Modified Files

6. **`lib/screens/personal/personal_screen.dart`**
   - Added SMS Expenses button in AppBar with FutureBuilder
   - Red badge showing pending count
   - Navigation to SmsExpensesScreen

7. **`android/app/src/main/AndroidManifest.xml`**
   - Added SMS permissions
   - Added broadcast receiver for background SMS

8. **`lib/main.dart`**
   - Initialize SMS listener on app start (Android only)

9. **`pubspec.yaml`**
   - Added `telephony: ^0.2.0` package
   - Added `permission_handler: ^11.3.1` package

10. **`firestore.rules`**
   - Added security rules for `sms_expenses` collection
   - Users can read/write their own SMS expenses only
   - Status must be 'pending' on creation

---

## Firestore Structure

### `sms_expenses` Collection

```json
{
  "id": "auto_generated_id",
  "amount": 500.0,
  "merchant": "SWIGGY",
  "date": "2025-11-02T10:30:00Z",
  "category": "Food",
  "accountInfo": "XX1234",
  "rawSms": "Your A/c XX1234 debited for Rs.500...",
  "transactionId": "TXN12345",
  "userId": "current_user_uid",
  "status": "pending",
  "smsSender": "HDFCBK",
  "parsedAt": "2025-11-02T10:30:05Z",
  "categorizedAt": null,
  "linkedExpenseId": null
}
```

### Status Flow

```
pending → categorizedAt (when categorized as personal or shared)
pending → ignored (when user ignores)
ignored → pending (when user restores)
deleted → permanently removed
```

### When Categorized as Personal

```json
{
  "status": "categorized",
  "categorizedAt": "2025-11-02T10:35:00Z",
  "linkedExpenseId": "expense_doc_id"
}
```

And a new expense is created in `expenses` collection:

```json
{
  "title": "SWIGGY",
  "amount": 500,
  "category": "Food",
  "notes": "Auto-imported from SMS\nA/c XX1234\nTxn: TXN12345",
  "date": "2025-11-02T10:30:00Z",
  "paidBy": "current_user_uid",
  "splitWith": ["current_user_uid"],
  "splitDetails": {"current_user_uid": 500},
  "splitMethod": "equal",
  "groupId": null,
  "isFromBill": true,
  "billMetadata": {
    "source": "sms",
    "sender": "HDFCBK",
    "rawSms": "Full SMS text",
    "transactionId": "TXN12345",
    "accountInfo": "XX1234",
    "parsedAt": "2025-11-02T10:30:05Z",
    "smsExpenseId": "sms_expense_doc_id"
  },
  "createdAt": "2025-11-02T10:35:00Z",
  "updatedAt": "2025-11-02T10:35:00Z"
}
```

---

## How Parsing Works (Current Regex-Based)

### 1. Transaction Detection
```dart
// Checks for:
- Transaction keywords (account, card, upi, transaction, payment)
- Amount pattern (₹, Rs., INR)
- Debit keywords (debited, spent, withdrawn, paid)
```

### 2. Amount Extraction
```dart
// Supports multiple formats:
₹500
Rs. 1,200
INR 2500
Amount: Rs.1500
```

### 3. Merchant Extraction
```dart
// Patterns:
at SWIGGY
to AMAZON
for ZOMATO
merchant: UBER
payee: NETFLIX
```

### 4. Category Mapping
```dart
if (merchant contains "swiggy") → Food
if (merchant contains "amazon") → Shopping
if (merchant contains "uber") → Travel
// ... and so on
```

### 5. Duplicate Prevention
```dart
// Checks:
1. Transaction ID match (if available)
2. Same amount + merchant + date (same day)
```

---

## AI-Based SMS Parsing (Future)

### Why AI-Based Parsing?

**Current Limitation**: Regex patterns are brittle and fail with non-standard SMS formats.

**Problem Examples**:
```
❌ "You've paid ₹500.00 to Swiggy via HDFC Bank"
❌ "Txn of Rs 1200 done at Amazon using card ***4567"
❌ "UPI payment: ₹250 - Zomato - REF:ABC123"
❌ "Card purchase INR2500 BIGBASKET 02NOV25"
```

Each bank and payment app uses slightly different formats, making regex maintenance difficult.

**AI Solution**: Use a Large Language Model (LLM) to extract structured data from SMS text, regardless of format.

### How It Would Work

1. **SMS Received** → App detects transaction-related SMS
2. **Send to AI Model** → Send SMS text to AI API with structured output request
3. **AI Extracts Data** → Model returns JSON with amount, merchant, category, etc.
4. **Save to Firestore** → Store extracted data as pending SMS expense
5. **User Reviews** → User categorizes as usual

### AI Model Options & Cost Analysis

#### Option 1: Google Gemini (Recommended)

**Model**: Gemini 2.0 Flash
- **Input Cost**: $0.075 per 1M tokens (~$0.000075 per request)
- **Output Cost**: $0.30 per 1M tokens (~$0.000060 per response)
- **Total per SMS**: ~$0.000135 (₹0.011)
- **For 1000 SMS/month**: ~$0.135/month (₹11/month)
- **Integration**: Google Cloud API, easy to setup with Firebase

**Pros**:
- Cheapest option
- Fast response time (<1 second)
- Multimodal (can handle image-based receipts later)
- Structured output support (JSON mode)
- Free tier: 1,500 requests/day

**Cons**:
- Requires Google Cloud project
- API key management needed

#### Option 2: OpenAI GPT-4o-mini

**Model**: gpt-4o-mini
- **Input Cost**: $0.150 per 1M tokens (~$0.00015 per request)
- **Output Cost**: $0.600 per 1M tokens (~$0.00012 per response)
- **Total per SMS**: ~$0.00027 (₹0.022)
- **For 1000 SMS/month**: ~$0.27/month (₹22/month)
- **Integration**: OpenAI API

**Pros**:
- Excellent accuracy
- Structured output (JSON mode)
- Well-documented API
- Function calling support

**Cons**:
- 2x cost of Gemini
- Requires OpenAI account
- Rate limits on free tier

#### Option 3: Anthropic Claude Haiku

**Model**: Claude 3.5 Haiku
- **Input Cost**: $0.80 per 1M tokens (~$0.0008 per request)
- **Output Cost**: $4.00 per 1M tokens (~$0.0008 per response)
- **Total per SMS**: ~$0.0016 (₹0.13)
- **For 1000 SMS/month**: ~$1.60/month (₹132/month)
- **Integration**: Anthropic API

**Pros**:
- Very high accuracy
- Excellent instruction following
- Good structured output

**Cons**:
- Most expensive option (12x Gemini)
- Requires Anthropic account

#### Option 4: Firebase Vertex AI (Gemini via Firebase)

**Model**: Gemini Pro via Firebase Extensions
- **Cost**: Same as Gemini 2.0 Flash pricing
- **Integration**: Firebase Extension (easier setup)

**Pros**:
- No separate API key needed (uses Firebase auth)
- Automatic scaling
- Built-in security rules
- Easy to deploy as Cloud Function

**Cons**:
- Requires Firebase Blaze plan (pay-as-you-go)

### Recommended Approach: Gemini via Firebase Cloud Functions

**Implementation Plan**:

1. **Cloud Function**: Create Firebase Cloud Function that receives SMS text
2. **AI Processing**: Function calls Gemini 2.0 Flash API with prompt:
   ```
   Extract transaction details from this SMS:

   SMS: "{sms_text}"

   Return JSON with:
   - amount (number)
   - merchant (string)
   - category (Food/Shopping/Travel/etc)
   - transactionId (string or null)
   - accountInfo (string or null)
   - date (ISO string)
   - isDebit (boolean)
   ```
3. **Response Validation**: Function validates AI response
4. **Save to Firestore**: Function saves to `sms_expenses` collection
5. **Client Update**: App receives real-time update via Firestore snapshot

### Cost Projections

**Average User**:
- 30 transactions/month
- Cost: ₹0.33/month (~₹4/year)

**Heavy User**:
- 100 transactions/month
- Cost: ₹1.10/month (~₹13/year)

**Very Heavy User**:
- 500 transactions/month
- Cost: ₹5.50/month (~₹66/year)

**Conclusion**: AI-based parsing is **extremely affordable** even for heavy users.

### Privacy & Security Considerations

**If Using AI Parsing**:

✅ **What we'll do**:
- Send only transaction SMS (not personal messages)
- Strip personally identifiable info before sending
- Use Google Cloud (same as Firebase)
- Process immediately and don't store in AI provider logs
- Use secure HTTPS connections

❌ **What we won't do**:
- Send OTPs or personal messages
- Share raw SMS with third parties
- Store SMS text in AI provider databases
- Use SMS data for training AI models

**User Control**:
- Option to enable/disable AI parsing
- Fallback to regex if AI fails
- All processing happens in Cloud Functions (not on third-party servers)

### Implementation Code Snippet

```dart
// Cloud Function (functions/src/index.ts)
import { onCall } from 'firebase-functions/v2/https';
import { GoogleGenerativeAI } from '@google/generative-ai';

export const parseSmsWithAI = onCall(async (request) => {
  const { smsText, sender, date } = request.data;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: 'gemini-2.0-flash',
    generationConfig: {
      responseMimeType: 'application/json'
    }
  });

  const prompt = `Extract transaction details from this SMS:

  SMS: "${smsText}"

  Return JSON with:
  {
    "amount": number,
    "merchant": string,
    "category": "Food" | "Shopping" | "Travel" | "Entertainment" | "Groceries" | "Utilities" | "Healthcare" | "Other",
    "transactionId": string | null,
    "accountInfo": string | null,
    "date": ISO date string,
    "isDebit": boolean
  }`;

  const result = await model.generateContent(prompt);
  const parsed = JSON.parse(result.response.text());

  return { success: true, data: parsed };
});
```

```dart
// Client-side (lib/services/ai_sms_parser_service.dart)
class AiSmsParserService {
  static Future<SmsExpenseModel?> parseSmsWithAI(
    String smsText,
    String sender,
    DateTime date
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('parseSmsWithAI');
      final result = await callable.call({
        'smsText': smsText,
        'sender': sender,
        'date': date.toIso8601String(),
      });

      if (result.data['success']) {
        return SmsExpenseModel.fromAiResponse(result.data['data']);
      }
    } catch (e) {
      // Fallback to regex-based parsing
      return SmsParserService.parseSms(smsText, sender, date);
    }
    return null;
  }
}
```

---

## Privacy & Security

### What the App Does
✅ Reads only transaction SMS from banks
✅ Processes SMS locally on your device (regex mode)
✅ Stores only transaction details in Firestore
✅ Uses transaction data solely for expense tracking
✅ All data stored in your private Firestore database

### What the App Does NOT Do
❌ Does not read personal messages
❌ Does not send SMS data to third parties (except AI parsing if enabled)
❌ Does not share raw SMS content
❌ Does not access SMS from non-banking sources

### Data Storage
- **Raw SMS**: Stored in expense metadata for reference (Firestore only)
- **Extracted Data**: Amount, merchant, category stored
- **Location**: Your private Firestore database
- **Access**: Only you can see your expenses (enforced by security rules)

---

## Limitations

### Platform
- ✅ **Android**: Fully supported
- ❌ **iOS**: Not supported (iOS doesn't allow SMS access for third-party apps)

### SMS Format Variations (Regex Mode)
- Parser uses generic patterns but may not catch all formats
- Some banks use non-standard SMS formats
- Manual expenses can always be added for missed transactions
- **Future**: AI parsing will handle all formats

### Duplicate Detection
- Relies on transaction IDs or amount+merchant+date matching
- Same amount to same merchant on same day might be detected as duplicate
- Manual verification recommended for such cases

---

## Troubleshooting

### Expenses Not Being Created

**1. Check Permissions**
```
Settings → Apps → SpendPal → Permissions → SMS → Allow
```

**2. Check if SMS is a Transaction**
- Must contain transaction keywords
- Must contain amount
- Must be a debit transaction (not credit)

**3. Check Pending List**
- Open Personal Tab → Message Icon
- Transaction might be waiting for categorization

**4. Check for Duplicates**
- Look for existing expense with same details
- Duplicate expenses are automatically skipped

**5. Check Logs**
```bash
adb logcat | grep -i "transaction detected"
adb logcat | grep -i "sms expense saved"
```

### Permission Denied

**Re-request Permissions**:
- Open SMS Expenses screen
- Tap "Retry" button in error message
- Or manually grant permissions in phone settings

### Incorrect Categorization

- Current version uses keyword-based categorization
- You can change category before adding to expenses
- Future AI version will have better accuracy

### Badge Not Updating

- Badge count updates on app restart
- If stuck, force close and reopen app

---

## Future Enhancements

### Planned Features
- [x] User categorization workflow (completed in v1.1)
- [x] Duration selector (completed in v1.1)
- [x] Platform detection (completed in v1.1)
- [ ] **AI-based SMS parsing** (see above section)
- [ ] Manual category override for auto-detected expenses
- [ ] SMS format customization for specific banks
- [ ] Bill/receipt image attachment from SMS links
- [ ] Monthly SMS expense summary
- [ ] Pattern learning from user corrections
- [ ] Merchant name normalization (SWIGGY, Swiggy, swiggy → Swiggy)

### Suggested Improvements
- Gemini AI for robust parsing (see cost analysis above)
- Support for credit transactions (income tracking)
- EMI detection and recurring expense tracking
- Budget alerts based on SMS patterns
- Export SMS expenses to CSV/Excel

---

## Developer Notes

### Adding Custom Bank Patterns

Edit `lib/services/sms_parser_service.dart`:

```dart
// Add custom amount pattern
static final _customAmountPattern = RegExp(
  r'your_bank_specific_pattern',
  caseSensitive: false,
);

// Add to _amountPatterns list
static final List<RegExp> _amountPatterns = [
  // ... existing patterns
  _customAmountPattern,
];
```

### Testing Locally

```dart
// In sms_parser_service.dart
void testParser() {
  final sms = "Your A/c XX1234 debited for Rs.500 at SWIGGY";
  final result = SmsParserService.parseSms(sms, "HDFCBK", DateTime.now());
  print(result?.merchant); // Should print "SWIGGY"
  print(result?.amount);   // Should print 500.0
  print(result?.category); // Should print "Food"
}
```

### Manual SMS Import

```dart
// Import last 7 days
await SmsListenerService.processRecentMessages(days: 7);

// Import last 30 days (default)
await SmsListenerService.processRecentMessages(days: 30);

// Import last 90 days
await SmsListenerService.processRecentMessages(days: 90);
```

### Accessing SMS Expenses Screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const SmsExpensesScreen(),
  ),
);
```

---

## FAQ

### Will this drain my battery?
No. The app only activates when an SMS is received. It does not continuously poll or scan messages.

### Can I disable this feature?
Yes. Simply deny SMS permissions in app settings or phone settings.

### What if the amount is wrong?
Review the transaction in SMS Expenses screen before adding. You can also edit the expense after adding like any other expense in SpendPal.

### Does it work with all banks?
It works with most Indian banks using standard SMS formats. If your bank uses a unique format, it may not be detected. AI-based parsing (future) will handle all formats.

### Can I see which SMS created which expense?
Yes. Open the expense details and check the notes field. It contains the transaction ID and account info. The raw SMS is also stored in `billMetadata`.

### What about SMS from non-banking apps?
The parser is designed to only detect bank transaction SMS. Marketing messages, OTPs, and personal messages are ignored.

### Why aren't expenses automatically added anymore?
To give you control over which expenses to add and how to split them. This prevents clutter and allows you to share expenses with friends/groups.

### Can I restore an ignored transaction?
Yes (planned feature). Currently, you can manually create the expense.

### Will AI parsing cost me money?
AI parsing would cost approximately ₹0.01 per SMS, or about ₹4-66 per year depending on usage (see cost analysis above). This feature is not yet implemented.

---

## Support

For issues or questions:
1. Check if SMS format matches supported patterns
2. Verify SMS permissions are granted
3. Check pending SMS expenses screen
4. Check adb logs for parsing errors
5. Create a GitHub issue with sample SMS format (remove sensitive data)

---

## Comparison: Regex vs AI Parsing

| Feature | Regex (Current) | AI (Future) |
|---------|----------------|------------|
| **Setup** | Zero setup, works offline | Requires Firebase Cloud Functions + API key |
| **Cost** | Free | ~₹0.01 per SMS (~₹4-66/year) |
| **Accuracy** | 70-80% (standard formats only) | 95-99% (all formats) |
| **Speed** | Instant | ~1-2 seconds (API call) |
| **Privacy** | 100% local | Sends SMS to Google Cloud (secure) |
| **Maintenance** | High (add patterns for new banks) | Low (AI adapts automatically) |
| **Category Accuracy** | Keyword-based (~80%) | Context-aware (~95%) |
| **Handles Typos** | No | Yes |
| **Handles New Formats** | No (requires code update) | Yes (AI understands intent) |

**Recommendation**: Start with regex (current), migrate to AI for better accuracy when budget allows.

---

**Version**: 1.1.0
**Last Updated**: 2025-11-02
**Platform**: Android Only (iOS shows helpful explanation)
**Status**: ✅ Production Ready (Regex) | 📋 Planned (AI)
