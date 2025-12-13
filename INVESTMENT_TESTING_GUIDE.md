# Investment Tracking Feature - Testing Guide

## Overview
This guide provides comprehensive test scenarios for the investment tracking feature in SpendPal.

## Prerequisites
- Firebase project configured
- User authenticated in the app
- Firestore security rules deployed

## Test Flow Navigation
Home → Money Tracker → Investments Card → Investments Screen

---

## Test Scenario 1: Create New Asset & Add BUY Transaction

### Steps:
1. Navigate to Investments screen (should show empty state)
2. Tap the floating action button "Add"
3. Select "Add Transaction" from bottom sheet
4. **Step 1 - Select Asset:**
   - Toggle "Create New Asset" ON
   - Select asset type: "Mutual Fund"
   - Enter asset name: "HDFC Equity Fund"
   - Enter scheme code: "123456" (optional)
   - Tap "Continue"
5. **Step 2 - Transaction Type:**
   - Select "Buy"
   - Tap "Continue"
6. **Step 3 - Details:**
   - Select date (today or past date)
   - Enter quantity: 10
   - Enter price per unit: 50
   - Enter fees: 5 (optional)
   - Add notes: "First investment" (optional)
   - Tap "Submit"

### Expected Results:
- ✅ Success snackbar appears
- ✅ Returns to Investments screen
- ✅ Portfolio summary card shows:
  - Invested: ₹505 (10 × 50 + 5 fees)
  - Current: ₹500 (10 × 50, no price update yet)
  - P/L: -₹5 (due to fees)
- ✅ Asset card appears in "All" and "Mutual Funds" tabs
- ✅ Asset card shows name, invested amount, current value, P/L

### Firestore Verification:
```
/users/{userId}/investmentAssets/{assetId}
  - assetType: "mutual_fund"
  - name: "HDFC Equity Fund"
  - schemeCode: "123456"

/users/{userId}/investmentHoldings/{holdingId}
  - assetId: {assetId}
  - quantity: 10
  - avgPrice: 50.5 (includes fees)
  - currentPrice: null

/users/{userId}/investmentTransactions/{txnId}
  - type: "BUY"
  - quantity: 10
  - price: 50
  - fees: 5
```

---

## Test Scenario 2: Update Current Price

### Steps:
1. From Investments screen, tap "Update Price" from floating action button menu
2. Select the asset created in Scenario 1
3. Enter new price: 55
4. Tap "Update Price"

### Expected Results:
- ✅ Success snackbar appears
- ✅ Returns to Investments screen (or refreshes if using navigation)
- ✅ Portfolio summary updates:
  - Invested: ₹505
  - Current: ₹550 (10 × 55)
  - P/L: +₹45
  - P/L %: +8.91%
- ✅ Asset card shows positive P/L in green

### Firestore Verification:
```
/users/{userId}/investmentHoldings/{holdingId}
  - currentPrice: 55
  - currentValue: 550
  - unrealizedPL: 45
```

---

## Test Scenario 3: Add SIP Transaction to Existing Asset

### Steps:
1. Tap floating action button "Add"
2. Select "Add Transaction"
3. **Step 1:** Keep "Create New Asset" OFF, select existing asset
4. **Step 2:** Select "SIP"
5. **Step 3:**
   - Enter quantity: 5
   - Enter price: 52
   - Enter fees: 2
   - Tap "Submit"

### Expected Results:
- ✅ Portfolio summary updates:
  - Invested: ₹772 (505 + 260 + 2 + 5)
  - Current: ₹825 (15 × 55)
  - P/L: +₹53
- ✅ Holding quantity increases to 15
- ✅ Average price recalculates to 51.47

### Calculation Verification:
```
Old: 10 units @ 50.5 avg = 505
New: 5 units @ 52 = 260 + 2 fees = 262
Combined: 15 units @ ((10×50.5 + 5×52.4) / 15) = 51.47
```

---

## Test Scenario 4: View Asset Details

### Steps:
1. Tap on any asset card in the portfolio list
2. Verify Asset Detail Screen displays

### Expected Results:
- ✅ Asset info card shows name, type, symbol/scheme code
- ✅ Holdings summary card shows:
  - Quantity: 15
  - Avg Price: ₹51.47
  - Current Price: ₹55
  - Invested: ₹772
  - Current Value: ₹825
  - Unrealized P/L: +₹53 (green badge)
  - P/L %: +6.87%
- ✅ Performance metrics card shows XIRR (if enough data)
- ✅ Transaction history shows 2 transactions (BUY, SIP) chronologically
- ✅ Each transaction shows:
  - Type icon (colored)
  - Date formatted (dd MMM yyyy)
  - Quantity and price details
  - Fees if applicable
  - Notes if provided

---

## Test Scenario 5: Add DIVIDEND Transaction

### Steps:
1. From Asset Detail screen, tap floating action button
2. Select date
3. Enter amount: 50
4. Add notes: "Quarterly dividend"
5. Tap "Submit"

### Expected Results:
- ✅ Transaction appears in history
- ✅ Current holding quantity unchanged (15 units)
- ✅ Dividend marked with income icon (green)
- ✅ XIRR calculation updates (positive cashflow)

---

## Test Scenario 6: Add SELL Transaction

### Steps:
1. Add transaction from any entry point
2. Select existing asset
3. Select transaction type: "Sell"
4. Enter quantity: 5 (less than holding)
5. Enter price: 58
6. Enter fees: 3
7. Submit

### Expected Results:
- ✅ Holding quantity reduces to 10
- ✅ Realized P/L calculated: (5 × 58) - (5 × 51.47) - 3 = 29.65
- ✅ Average price remains 51.47 (only applies to acquisitions)
- ✅ Current value updates: 10 × 55 = 550
- ✅ Transaction history shows SELL with red icon

---

## Test Scenario 7: Test Multiple Asset Types

### Steps:
Create one asset of each type:
1. **Stock (equity):**
   - Type: Equity
   - Name: "Reliance Industries"
   - Symbol: "RELIANCE"
   - Buy: 2 units @ 2400

2. **ETF:**
   - Type: ETF
   - Name: "Nifty 50 ETF"
   - Symbol: "NIFTYBEES"
   - Buy: 50 units @ 200

3. **Fixed Deposit:**
   - Type: FD
   - Name: "HDFC Bank FD"
   - Buy: 1 unit @ 100000
   - (Note: Use unit = 1, price = full FD amount)

4. **Gold:**
   - Type: Gold
   - Name: "Gold ETF"
   - Buy: 10 grams @ 5500

### Expected Results:
- ✅ "All" tab shows all 5 assets (including MF from earlier)
- ✅ Each specialized tab shows only relevant assets:
  - Mutual Funds: 1 asset
  - Equity: 1 asset
  - ETF: 2 assets (Nifty 50 + Gold ETF if applicable)
  - FD/RD: 1 asset
  - Gold: 1 asset
- ✅ Portfolio summary aggregates all investments
- ✅ Each asset has appropriate icon

---

## Test Scenario 8: Test Tab Filtering

### Steps:
1. Navigate through each tab (All, Mutual Funds, Equity, ETF, FD/RD, Gold)
2. Verify filtering works correctly

### Expected Results:
- ✅ Each tab shows only assets of that type
- ✅ Empty tabs show "No investments yet" message
- ✅ Tab counts match actual assets
- ✅ Pull-to-refresh works on all tabs

---

## Test Scenario 9: Test Empty States

### Steps:
1. Navigate to Investments screen with no data
2. Check each tab

### Expected Results:
- ✅ Portfolio summary shows all zeros
- ✅ Each tab shows empty state with icon and message
- ✅ Message: "No investments yet"
- ✅ Subtitle: "Tap + to add your first investment"

---

## Test Scenario 10: Test Price Update Screen

### Steps:
1. Open UpdatePriceScreen via menu or floating button
2. Test with asset that has no current price
3. Test with asset that has existing price

### Expected Results:
- ✅ Dropdown lists all assets
- ✅ When asset selected:
  - If current price exists: Shows "Current Price" card in blue
  - If no current price: Doesn't show current price card
- ✅ Info card explains what price update does
- ✅ Validation: Must be > 0
- ✅ Success updates holding and portfolio

---

## Test Scenario 11: Test XIRR Calculation

### Steps:
1. Create asset with multiple transactions over different dates:
   - Day 1: BUY 10 @ 100 (₹1000)
   - Day 30: SIP 5 @ 105 (₹525)
   - Day 60: BUY 10 @ 98 (₹980)
   - Day 90: DIVIDEND ₹50
   - Current date: Price updated to 110

2. View Asset Detail screen

### Expected Results:
- ✅ XIRR displays in Performance Metrics card
- ✅ XIRR formula considers:
  - Negative cashflows: BUY/SIP transactions
  - Positive cashflows: SELL/DIVIDEND transactions
  - Final cashflow: Current value at today's date
- ✅ XIRR should be annualized percentage return
- ✅ If insufficient data, shows "Insufficient data for XIRR"

---

## Test Scenario 12: Test Navigation Flow

### Complete Navigation Test:
1. Home → Money Tracker → Tap Investments card
2. Investments Screen → Tap Add button → Select Add Transaction
3. Complete transaction → Returns to Investments Screen
4. Tap asset card → Asset Detail Screen
5. Tap menu → Update Price → UpdatePriceScreen
6. Update price → Returns to Asset Detail
7. Pull to refresh → Data updates
8. Back navigation works at each step

### Expected Results:
- ✅ All navigations work smoothly
- ✅ Back button returns to previous screen
- ✅ Data persists across navigations
- ✅ Refresh updates all calculated values

---

## Test Scenario 13: Test Error Handling

### Steps to Test:
1. **Validation Errors:**
   - Try submitting empty required fields
   - Try entering negative numbers
   - Try entering invalid dates (future dates)

2. **Network Errors:**
   - Disable network
   - Try adding transaction
   - Re-enable network

3. **Permission Errors:**
   - Test with unauthenticated user (if applicable)

### Expected Results:
- ✅ Validation errors show inline with red text
- ✅ Network errors show red snackbar with error message
- ✅ No crashes on errors
- ✅ Loading states show during operations
- ✅ Retry functionality works

---

## Test Scenario 14: Test Pull-to-Refresh

### Steps:
1. On Investments Screen, pull down to refresh
2. On Asset Detail Screen, pull down to refresh

### Expected Results:
- ✅ Loading indicator appears
- ✅ Data reloads from Firestore
- ✅ Portfolio calculations update
- ✅ All values reflect latest data

---

## Test Scenario 15: Test Security Rules

### Steps:
1. Create investment data for User A
2. Try to access from User B's account

### Expected Results:
- ✅ User B cannot see User A's investments
- ✅ User B cannot modify User A's investments
- ✅ Security rules enforce user isolation
- ✅ Each user sees only their own data

### Firestore Rules to Verify:
```javascript
match /users/{userId}/investmentAssets/{assetId} {
  allow read, write: if request.auth.uid == userId;
}
// Same for holdings, transactions, valuations
```

---

## Test Scenario 16: Test Edge Cases

### Test Cases:
1. **Zero Fees:** Add transaction with 0 fees
2. **Very Large Numbers:** Add transaction with 1,000,000 units
3. **Decimal Precision:** Add 0.0001 units @ 123456.78
4. **Same-Day Transactions:** Add multiple transactions on same date
5. **Sell More Than Holdings:** Try to sell 100 units when holding 10
6. **Negative Price:** Try to enter negative price
7. **Special Characters:** Enter asset name with emojis/symbols

### Expected Results:
- ✅ Zero fees accepted
- ✅ Large numbers handled correctly
- ✅ Decimal places preserved (up to limits)
- ✅ Multiple same-day transactions work
- ✅ Over-selling prevented by business logic
- ✅ Negative price rejected by validation
- ✅ Special characters handled gracefully

---

## Performance Testing

### Test Load Performance:
1. Create 50 assets
2. Add 10 transactions per asset (500 total)
3. Navigate through screens

### Expected Results:
- ✅ List rendering smooth with pagination/lazy loading
- ✅ No lag when scrolling
- ✅ Calculations complete within 2 seconds
- ✅ No memory leaks
- ✅ App remains responsive

---

## Regression Testing Checklist

### Existing Features Still Work:
- ✅ Expense tracking unaffected
- ✅ Group features work
- ✅ Friend requests work
- ✅ Bill parsing works
- ✅ SMS auto-expense works (Android)
- ✅ Money Tracker shows all cards correctly
- ✅ Settlements work
- ✅ Bug reporting works

---

## Deployment Checklist

### Before Production:
- ✅ All test scenarios pass
- ✅ Firestore security rules deployed
- ✅ No console errors
- ✅ No linting warnings
- ✅ XIRR calculations verified with known data
- ✅ UI tested on multiple screen sizes
- ✅ Dark mode tested (if applicable)
- ✅ iOS and Android tested
- ✅ Network error handling tested
- ✅ Offline behavior acceptable
- ✅ Performance acceptable with realistic data

---

## Known Limitations

1. **Price Updates:** Manual only, no auto-fetch from market APIs
2. **XIRR:** Requires at least 2 transactions for calculation
3. **Decimal Precision:** Limited to 4 decimal places for quantity
4. **Asset Types:** Fixed set, no custom types
5. **Portfolio Valuations:** Generated on-demand, not daily snapshots (ValuationService available but not triggered)

---

## Troubleshooting

### If portfolio summary shows incorrect values:
1. Check Firestore data for consistency
2. Verify current prices are set for holdings
3. Check transaction fees are included in calculations
4. Verify security rules allow reads

### If XIRR shows N/A:
1. Ensure multiple transactions exist
2. Check transactions have valid dates
3. Verify current price is set
4. Check XirrService.calculateXirr logic

### If transactions don't appear:
1. Check Firestore write succeeded
2. Verify userId matches current user
3. Check security rules allow writes
4. Verify transaction service returned success

---

## Success Criteria

### Feature is production-ready when:
- ✅ All 16 test scenarios pass
- ✅ No critical bugs found
- ✅ Performance acceptable
- ✅ Security rules enforced
- ✅ User can complete full investment flow without guidance
- ✅ All edge cases handled gracefully
- ✅ Error messages are clear and actionable

---

## Quick Test (Smoke Test)

**5-minute verification:**
1. ✅ Navigate to Investments screen
2. ✅ Add new asset with BUY transaction
3. ✅ Update current price
4. ✅ View asset details
5. ✅ Add SIP transaction
6. ✅ Verify portfolio summary calculations correct
7. ✅ Test pull-to-refresh
8. ✅ Navigate back to home

If all pass, feature is likely working correctly.

---

## Feedback & Issues

If you encounter any issues during testing:
1. Note the exact steps to reproduce
2. Check Firestore console for data
3. Check Flutter console for errors
4. Use the in-app bug reporting feature
5. Document expected vs actual behavior

---

**End of Testing Guide**
