# Financial Tracker Implementation Plan

**Date Created:** 2025-11-09
**Status:** Planning Phase
**Current Phase:** Phase 1 - Investment Tracking MVP

---

## Executive Summary

This document outlines the implementation plan for adding advanced financial tracking features to SpendPal, transforming it from a Splitwise-style expense tracker into a comprehensive personal finance management app.

The spec provided was for a full-featured portfolio tracker with smart suggestions. This plan extracts the core requirements, simplifies overly complex features, and maps them to a 3-phase implementation that builds on SpendPal's existing infrastructure.

---

## What Already EXISTS in SpendPal (Can Be Reused)

### Models
- **MoneyTrackerAccount** (`lib/models/money_tracker_model.dart`) - Bank & credit card accounts ✓
- **MoneyTransaction** - Transaction tracking (credit/debit) ✓
- **SalaryRecord** - Monthly salary tracking ✓
- **ExpenseModel** (`lib/models/expense_model.dart`) - Personal expense tracking ✓

### Screens
- **MoneyTrackerScreen** (`lib/screens/money_tracker/money_tracker_screen.dart`) - Dashboard showing salary, expenses, bank balance, credit cards ✓
- **PersonalExpensesScreen** (`lib/screens/personal/personal_screen.dart`) - Expense tracking with categories ✓
- **AnalyticsScreen** (`lib/screens/analytics/analytics_screen.dart`) - Pie charts, trends, category breakdown ✓

### Services
- **AnalyticsService** (`lib/services/analytics_service.dart`) - Category breakdown, monthly totals ✓
- **Bill Upload Service** (`lib/services/bill_upload_service.dart`) - File upload infrastructure ✓
- **SMS Parser Services** - Transaction detection from SMS ✓

### Infrastructure
- Firebase/Firestore integration ✓
- Firebase Functions (for bill parsing at `functions/`) ✓
- Chart widgets (pie, line charts) ✓
- 13+ expense categories with colors/icons ✓

---

## What's NEW from the Spec (Needs Building)

### 1. Investment Portfolio Tracking
- Asset types: MUTUAL_FUNDS, EQUITY/ETF, FD/RD, GOLD
- Holdings with quantity, average price, current price
- Transaction types: BUY, SELL, SIP, DIVIDEND, FEE

### 2. Valuation & Returns
- Daily portfolio snapshots
- XIRR calculation for returns
- Net worth tracking over time
- P/L tracking per holding

### 3. Schedules & Reminders
- SIP schedules (monthly recurring investments)
- EMI schedules (already have credit cards, extend this)
- Due date tracking and notifications

### 4. Smart Insights (Rules Engine)
- **SIP_MISSED**: Due on Dth, not posted by D+3
- **REBALANCE_DRIFT**: Asset allocation vs target bands
- **CONCENTRATION_RISK**: Top 3 holdings >40% of equity
- **HIGH_EXPENSE_RATIO**: Regular vs direct fund plans (Phase 2)
- **FUND_OVERLAP**: Defer - requires AMFI data (Phase 3+)
- **GOAL_SHORTFALL**: Defer - add goals feature first (Phase 3+)

### 5. Automations (Firebase Functions)
- Daily price refresh (07:00 IST)
- Daily valuation snapshots
- Daily insights computation
- Weekly digest (in-app notifications)

### 6. Import Features
- CAS import (mutual fund consolidated statement)
- CSV import for bulk transactions
- Email parsing: Defer to Phase 2+

---

## What's OVERLY COMPLEX (Simplified)

### From Original Spec → Our Simplified Approach

| Original Spec | Simplified Implementation |
|--------------|---------------------------|
| Price Adapters with multiple backends | Manual price entry first, add API later |
| Mailer Adapters for email digest | In-app notifications instead |
| All 7 rules on Day 1 | Start with 3 core rules |
| Fund overlap matrix | Defer (requires external data) |
| Property tracking | Defer (low priority) |
| Crypto tracking | Optional toggle, defer complexity |
| Email parsing webhook | Defer to Phase 2+ |
| Complex XIRR Newton method | Use existing Dart package |
| Pubsub scheduling | Firebase Cloud Scheduler or cron |

---

## Three-Phase Implementation Plan

### Phase 1: Investment Tracking MVP (2-3 weeks)

**Goal**: Users can track MF/Equity holdings, see total portfolio value, calculate XIRR

#### Data Models

**File: `lib/models/investment_asset.dart`**
```dart
class InvestmentAsset {
  final String assetId;
  final String userId;
  final String assetType; // 'mutual_fund', 'equity', 'etf', 'fd', 'gold'
  final String name;
  final String? symbol; // For stocks: 'RELIANCE', 'TCS'
  final String? schemeCode; // For MF: AMFI scheme code
  final String currency; // 'INR'
  final List<String> tags;
  final String? goalId; // Link to goal (future feature)
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**File: `lib/models/investment_holding.dart`**
```dart
class InvestmentHolding {
  final String holdingId;
  final String userId;
  final String assetId;
  final double quantity; // Number of units/shares
  final double avgPrice; // Average purchase price
  final double? currentPrice; // Latest market price
  final double currentValue; // quantity * currentPrice
  final double investedAmount; // quantity * avgPrice
  final double unrealizedPL; // currentValue - investedAmount
  final double unrealizedPLPercent;
  final DateTime lastUpdatedAt;
}
```

**File: `lib/models/investment_transaction.dart`**
```dart
class InvestmentTransaction {
  final String txnId;
  final String userId;
  final String assetId;
  final String? holdingId;
  final String type; // 'BUY', 'SELL', 'SIP', 'DIVIDEND', 'FEE'
  final DateTime date;
  final double? quantity; // For BUY/SELL/SIP
  final double? price; // Price per unit
  final double amount; // Total transaction amount
  final double fees; // Brokerage/transaction charges
  final String? notes;
  final String source; // 'MANUAL', 'CSV', 'CAS', 'EMAIL'
  final DateTime createdAt;
}
```

**File: `lib/models/portfolio_valuation.dart`**
```dart
class PortfolioValuation {
  final String valuationId; // YYYYMMDD format
  final String userId;
  final DateTime date;
  final Map<String, double> totals; // { netWorth, equity, mf, fd, gold, cash, debt }
  final Map<String, double> assetBreakdown; // Map<assetId, value>
  final double totalInvested;
  final double totalCurrent;
  final double totalPL;
  final double totalPLPercent;
}
```

#### Firestore Collections

```
/users/{uid}/investments/{assetId}
  - assetType, name, symbol, schemeCode, currency, tags, goalId
  - createdAt, updatedAt

/users/{uid}/holdings/{holdingId}
  - assetId, quantity, avgPrice, currentPrice, currentValue
  - investedAmount, unrealizedPL, unrealizedPLPercent
  - lastUpdatedAt

/users/{uid}/investmentTransactions/{txnId}
  - assetId, holdingId, type, date, quantity, price, amount, fees
  - notes, source, createdAt

/users/{uid}/valuations/{YYYYMMDD}
  - date, totals, assetBreakdown, totalInvested, totalCurrent
  - totalPL, totalPLPercent
```

#### Services

**File: `lib/services/xirr_service.dart`**
```dart
class XirrService {
  // Calculate XIRR using existing package or Newton-Raphson method
  // Cashflows: negative for purchases, positive for redemptions/dividends
  static Future<double> calculateXirr(List<Cashflow> cashflows, {double guess = 0.1});

  // Get cashflows for a specific asset
  static Future<List<Cashflow>> getAssetCashflows(String userId, String assetId);

  // Get cashflows for entire portfolio
  static Future<List<Cashflow>> getPortfolioCashflows(String userId);
}

class Cashflow {
  final DateTime date;
  final double amount; // Negative for investments, positive for returns
}
```

**File: `lib/services/valuation_service.dart`**
```dart
class ValuationService {
  // Compute current portfolio valuation
  static Future<PortfolioValuation> computeDailyValuation(String userId);

  // Update current prices for all holdings
  static Future<void> updateHoldingPrices(String userId, Map<String, double> prices);

  // Get historical valuations
  static Stream<List<PortfolioValuation>> getValuationHistory(
    String userId,
    DateTime startDate,
    DateTime endDate
  );
}
```

**File: `lib/services/portfolio_service.dart`**
```dart
class PortfolioService {
  // Get asset allocation breakdown
  static Future<Map<String, double>> getAssetAllocation(String userId);

  // Get total returns
  static Future<double> getTotalReturns(String userId);

  // Get holdings for a specific asset type
  static Stream<List<InvestmentHolding>> getHoldingsByType(
    String userId,
    String assetType
  );

  // Process a transaction (BUY/SELL/SIP) and update holdings
  static Future<void> processTransaction(InvestmentTransaction txn);
}
```

**File: `lib/services/investment_transaction_service.dart`**
```dart
class InvestmentTransactionService {
  // Create a new investment transaction
  static Future<void> createTransaction(InvestmentTransaction txn);

  // Update holding after transaction
  static Future<void> _updateHolding(InvestmentTransaction txn);

  // Calculate new average price for BUY transactions
  static double _calculateNewAvgPrice(
    double currentQty,
    double currentAvg,
    double newQty,
    double newPrice
  );
}
```

#### Screens

**File: `lib/screens/investments/investments_screen.dart`**
```dart
class InvestmentsScreen extends StatefulWidget {
  // Tab-based layout with:
  // - All Investments tab (summary)
  // - Mutual Funds tab
  // - Stocks/ETFs tab
  // - FD/RD tab
  // - Gold tab

  // Summary cards at top:
  // - Total Portfolio Value (large number)
  // - Today's P/L (with color indicator)
  // - Total Returns (XIRR %)
  // - Invested Amount

  // FAB: Add Investment Transaction
}
```

**File: `lib/screens/investments/asset_detail_screen.dart`**
```dart
class AssetDetailScreen extends StatelessWidget {
  // Shows details for a specific investment
  // - Asset name, type, current value
  // - Holdings summary (quantity, avg price, current price)
  // - P/L chart (line chart over time)
  // - Transaction history (list of BUY/SELL/SIP/DIV)
  // - Actions: Add Transaction, Update Price
}
```

**File: `lib/screens/investments/add_investment_transaction_screen.dart`**
```dart
class AddInvestmentTransactionScreen extends StatefulWidget {
  // Form to add investment transaction
  // - Select Asset (dropdown or search)
  // - Transaction Type (BUY/SELL/SIP/DIVIDEND/FEE)
  // - Date picker
  // - Quantity (for BUY/SELL/SIP)
  // - Price per unit
  // - Auto-calculate total amount
  // - Fees/charges
  // - Notes
  // - Save button (validates and creates transaction)
}
```

**File: `lib/screens/investments/update_price_screen.dart`**
```dart
class UpdatePriceScreen extends StatefulWidget {
  // Manual price entry for holdings
  // - List of all holdings without today's price
  // - Quick entry: symbol/name → current price
  // - Bulk update button
  // - Last updated timestamp
}
```

#### Widgets

**File: `lib/widgets/investment_card.dart`**
```dart
class InvestmentCard extends StatelessWidget {
  // Reusable card for displaying investment summary
  // - Asset name and icon
  // - Current value (large)
  // - P/L amount and percentage (color-coded)
  // - Quantity and avg price (small text)
  // - Tap to open AssetDetailScreen
}
```

**File: `lib/widgets/portfolio_pie_chart.dart`**
```dart
class PortfolioPieChart extends StatelessWidget {
  // Pie chart showing asset allocation
  // - Segments: Equity, MF, FD, Gold, Cash
  // - Colors: Use existing theme colors
  // - Legend with percentages
  // - Center: Total value
}
```

**File: `lib/widgets/net_worth_chart.dart`**
```dart
class NetWorthChart extends StatelessWidget {
  // Line chart showing net worth over time
  // - X-axis: Dates
  // - Y-axis: Portfolio value
  // - Data points from valuations collection
  // - Smooth curve
}
```

#### Phase 1 Deliverables

- [x] 4 new models (InvestmentAsset, Holding, Transaction, Valuation)
- [ ] InvestmentsScreen with tabs (All, MF, Equity, FD, Gold)
- [ ] AssetDetailScreen with holdings and transaction history
- [ ] AddInvestmentTransactionScreen form
- [ ] UpdatePriceScreen for manual price entry
- [ ] XirrService with XIRR calculation
- [ ] ValuationService for portfolio valuation
- [ ] PortfolioService for asset allocation
- [ ] InvestmentTransactionService for transaction processing
- [ ] 3 reusable widgets (InvestmentCard, PortfolioPieChart, NetWorthChart)
- [ ] Firestore security rules for new collections
- [ ] Integration with HomeScreen (add "Investments" card)

#### Phase 1 Acceptance Tests

1. Add a mutual fund with 3 SIP transactions → See current value, P/L, XIRR
2. Add a stock with 2 BUY transactions → See quantity, avg price, current value
3. View investments by asset class (MF, Equity, FD, Gold)
4. Update current price manually → See P/L update
5. Daily valuation snapshot created with correct totals
6. Portfolio pie chart shows correct allocation percentages
7. Net worth chart displays historical valuations

---

### Phase 2: Schedules & Insights (1-2 weeks)

**Goal**: Track SIP schedules, get smart reminders for missed SIPs and portfolio imbalances

#### Data Models

**File: `lib/models/investment_schedule.dart`**
```dart
class InvestmentSchedule {
  final String scheduleId;
  final String userId;
  final String relatedId; // assetId for SIP
  final String type; // 'SIP', 'EMI'
  final double amount;
  final String cadence; // 'MONTHLY' (support weekly/yearly later)
  final int dueDay; // 1-31
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastExecutedDate;
  final bool isActive;
}
```

**File: `lib/models/insight.dart`**
```dart
class Insight {
  final String insightId;
  final String userId;
  final DateTime date;
  final String title;
  final String message;
  final String severity; // 'info', 'warn', 'critical'
  final String ruleId;
  final String status; // 'NEW', 'ACK', 'MUTED'
  final DateTime? cooldownUntil;
  final Map<String, dynamic>? metadata; // Rule-specific data
}
```

**File: `lib/models/allocation_target.dart`**
```dart
class AllocationTarget {
  final String userId;
  final double equityPct; // Default 60%
  final double debtPct; // Default 30%
  final double goldPct; // Default 5%
  final double cashPct; // Default 5%
  final double bandPct; // Tolerance band, default 5%
}
```

#### Firestore Collections

```
/users/{uid}/schedules/{scheduleId}
  - relatedId, type, amount, cadence, dueDay
  - startDate, endDate, lastExecutedDate, isActive

/users/{uid}/insights/{insightId}
  - date, title, message, severity, ruleId
  - status, cooldownUntil, metadata

/users/{uid}/targets/allocation
  - equityPct, debtPct, goldPct, cashPct, bandPct
```

#### Services

**File: `lib/services/schedule_service.dart`**
```dart
class ScheduleService {
  // Get schedules due in next N days
  static Stream<List<InvestmentSchedule>> getUpcomingDues(String userId, {int days = 7});

  // Mark schedule as executed for a date
  static Future<void> markExecuted(String scheduleId, DateTime date);

  // Check for missed SIPs and return insights
  static Future<List<Insight>> checkMissedSips(String userId);

  // Create/update schedule
  static Future<void> saveSchedule(InvestmentSchedule schedule);
}
```

**File: `lib/services/insights_service.dart`**
```dart
class InsightsService {
  // Run all rules and generate insights
  static Future<List<Insight>> runRules(String userId);

  // Dismiss an insight
  static Future<void> dismissInsight(String insightId);

  // Snooze an insight for N days
  static Future<void> snoozeInsight(String insightId, int days);

  // Get active insights for user
  static Stream<List<Insight>> getActiveInsights(String userId);
}
```

**File: `lib/services/rules/sip_missed_rule.dart`**
```dart
class SipMissedRule {
  static const String RULE_ID = 'sip-missed';
  static const int COOLDOWN_DAYS = 10;
  static const int GRACE_DAYS = 3;

  static Future<List<Insight>> evaluate(String userId, DateTime now) {
    // For each SIP schedule with dueDay < today - GRACE_DAYS
    // Check if any transaction of type SIP exists within ±GRACE_DAYS
    // If not, create INFO insight
  }
}
```

**File: `lib/services/rules/concentration_risk_rule.dart`**
```dart
class ConcentrationRiskRule {
  static const String RULE_ID = 'concentration-risk';
  static const int COOLDOWN_DAYS = 30;
  static const double THRESHOLD_PCT = 40.0;

  static Future<List<Insight>> evaluate(String userId, DateTime now) {
    // Get all equity holdings
    // Sort by currentValue descending
    // Sum top 3 holdings
    // If (top3Sum / totalEquityValue) > THRESHOLD_PCT, create WARN insight
  }
}
```

**File: `lib/services/rules/rebalance_drift_rule.dart`**
```dart
class RebalanceDriftRule {
  static const String RULE_ID = 'rebalance-drift';
  static const int COOLDOWN_DAYS = 30;

  static Future<List<Insight>> evaluate(String userId, DateTime now) {
    // Get allocation target
    // Get current allocation from latest valuation
    // For each asset class (equity, debt, gold, cash):
    //   If current% > target% + band% OR current% < target% - band%
    //     Calculate recommended rebalance amount
    //     Create WARN insight
  }
}
```

#### Screens

**File: `lib/screens/schedules/schedules_screen.dart`**
```dart
class SchedulesScreen extends StatefulWidget {
  // List of SIP/EMI schedules
  // Grouped by status:
  // - Due Today (red chip)
  // - Missed (orange chip)
  // - Upcoming 7 days (green chip)
  // - Future (grey chip)

  // Each schedule card shows:
  // - Asset name
  // - Amount, due day
  // - Mark as executed button (if due)
  // - Edit/Delete actions

  // FAB: Add Schedule
}
```

**File: `lib/screens/insights/insights_screen.dart`**
```dart
class InsightsScreen extends StatelessWidget {
  // List of insights ordered by severity (critical → warn → info)
  // Each insight card:
  // - Icon based on severity
  // - Title and message
  // - "Why am I seeing this?" expansion
  // - Actions: Dismiss, Snooze (30d)

  // Empty state: "No insights - your portfolio looks good!"
}
```

#### Phase 2 Deliverables

- [ ] 3 new models (InvestmentSchedule, Insight, AllocationTarget)
- [ ] SchedulesScreen with schedule management
- [ ] InsightsScreen with insight cards
- [ ] ScheduleService for schedule tracking
- [ ] InsightsService for insight management
- [ ] 3 rule implementations (SIP_MISSED, CONCENTRATION_RISK, REBALANCE_DRIFT)
- [ ] Cooldown logic in insights service
- [ ] Integration with HomeScreen (show top 3 insights)

#### Phase 2 Acceptance Tests

1. Create SIP schedule for 5th of month
2. On 8th (5+3), see "SIP Missed" insight if no SIP transaction
3. If Equity >70% and target 60±5%, see "Rebalance" insight with suggested amount
4. If top 3 equity holdings >40% of total equity, see "Concentration Risk" insight
5. Dismiss insight → status changes to ACK, not shown in active list
6. Snooze insight for 30 days → cooldownUntil set, not shown for 30 days
7. Same rule doesn't fire again within cooldown period

---

### Phase 3: Automation & Import (1 week)

**Goal**: Daily automated valuation/insights, CSV bulk import

#### Firebase Functions

**File: `functions/src/jobs/dailyValuation.ts`**
```typescript
export const dailyValuationJob = functions
  .pubsub
  .schedule('0 7 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    // For each user with investments:
    //   1. Fetch latest prices (manual for now, API later)
    //   2. Compute portfolio valuation
    //   3. Write to /users/{uid}/valuations/{YYYYMMDD}
    //   4. Update holdings with current prices
  });
```

**File: `functions/src/jobs/dailyInsights.ts`**
```typescript
export const dailyInsightsJob = functions
  .pubsub
  .schedule('0 7 30 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    // For each user with investments:
    //   1. Run all insight rules
    //   2. Check cooldowns
    //   3. Write new insights (status: NEW)
    //   4. Skip if same rule in cooldown
  });
```

**File: `functions/src/http/csvImport.ts`**
```typescript
export const csvImportFunction = functions
  .https
  .onCall(async (data, context) => {
    // Validate user authentication
    // Parse CSV data (array of rows)
    // Validate each transaction row
    // Bulk create investmentTransactions
    // Process each transaction to update holdings
    // Return summary: { imported: 10, skipped: 2, errors: [] }
  });
```

**File: `functions/src/http/casImport.ts`** (STUB)
```typescript
export const casImportFunction = functions
  .https
  .onCall(async (data, context) => {
    // TODO: Implement CAS PDF parsing
    // For now, return stub response
    // Accept base64 PDF
    // Parse PDF to extract MF transactions
    // Normalize to InvestmentTransaction format
    // Return summary
  });
```

#### Screens

**File: `lib/screens/import/csv_import_screen.dart`**
```dart
class CsvImportScreen extends StatefulWidget {
  // File picker for CSV
  // Preview first 5 rows
  // Column mapping UI (if headers don't match expected)
  // Import button
  // Progress indicator
  // Summary screen after import (imported, skipped, errors)
}
```

**Sample CSV Template**
```csv
date,type,asset_name,asset_type,quantity,price,amount,fees,notes
2024-01-05,BUY,Axis Bluechip,mutual_fund,100,45.50,4550,0,Monthly SIP
2024-02-05,SIP,Axis Bluechip,mutual_fund,100,46.20,4620,0,Monthly SIP
2024-03-15,BUY,RELIANCE,equity,10,2850,28500,50,Buy 10 shares
```

#### Phase 3 Deliverables

- [ ] 2 Cloud Functions (dailyValuation, dailyInsights)
- [ ] csvImportFunction with parsing logic
- [ ] casImportFunction (stub implementation)
- [ ] CsvImportScreen with file picker and preview
- [ ] CSV template and documentation
- [ ] Scheduler config (Firebase Cloud Scheduler)
- [ ] Error handling and logging

#### Phase 3 Acceptance Tests

1. Upload CSV with 10 transactions → All imported correctly, holdings updated
2. Upload CSV with invalid rows → Errors reported, valid rows imported
3. Daily valuation job runs at 07:00 IST → Creates valuation snapshot for all users
4. Daily insights job runs at 07:30 IST → Generates new insights (respecting cooldowns)
5. CAS import function returns stub message (TODO for Phase 4)

---

## Phase 4+: Advanced Features (Future Roadmap)

### Automated Price Fetching
- Integrate NSE/BSE API for equity prices
- Integrate AMFI API for mutual fund NAVs
- Caching and rate limiting
- Fallback to manual entry if API fails

### Fund Overlap Detection
- Fetch fund portfolio holdings from AMFI
- Calculate overlap percentage matrix
- Generate HIGH_OVERLAP insight when >70% overlap detected

### Goal Tracking
- Goal model (retirement, education, house, car)
- Target amount and date
- Link investments to goals
- Projection and shortfall calculation
- GOAL_SHORTFALL insight

### Email Parsing
- Webhook to receive parsed emails
- Contract notes (equity trades)
- SIP confirmations
- Dividend credits
- Auto-create transactions from emails

### Weekly Digest
- In-app notification with:
  - Top 3 insights
  - Upcoming 7-day dues (SIP/EMI)
  - Net worth 30-day sparkline
  - Weekly P/L summary
- Optional email digest via SendGrid/Mailgun

### Multi-Currency Support
- Support USD, EUR, GBP holdings
- Currency conversion service
- Multi-currency portfolio valuation

### Property Tracking
- Property asset type
- Purchase price, current valuation (manual)
- EMI/installment schedules
- PROPERTY_MILESTONE_DUE insight

### Crypto Tracking (Optional)
- BTC, ETH, other crypto assets
- Integration with crypto price APIs
- High volatility warnings

### Advanced Analytics
- Year-over-year comparisons
- Month-over-month growth rates
- Dividend yield tracking
- Sector allocation analysis
- Benchmark comparison (Nifty 50, Sensex)

---

## Technical Architecture

### Data Flow

```
User Action (Add Transaction)
  ↓
InvestmentTransactionService.createTransaction()
  ↓
Update Firestore: /investmentTransactions/{txnId}
  ↓
InvestmentTransactionService._updateHolding()
  ↓
Recalculate: avgPrice, quantity, unrealizedPL
  ↓
Update Firestore: /holdings/{holdingId}
  ↓
UI updates via StreamBuilder
```

### Daily Automation Flow

```
07:00 IST - dailyValuationJob (Cloud Function)
  ↓
For each user:
  1. Fetch latest prices (manual or API)
  2. ValuationService.computeDailyValuation()
  3. Write: /valuations/{YYYYMMDD}
  4. Update: /holdings/{holdingId}.currentPrice
  ↓
07:30 IST - dailyInsightsJob (Cloud Function)
  ↓
For each user:
  1. InsightsService.runRules()
  2. Check cooldowns
  3. Write: /insights/{insightId} (status: NEW)
  ↓
User opens app → StreamBuilder shows new insights
```

### Security Rules

**File: `firestore.rules`** (extend existing)
```
match /users/{userId}/investments/{assetId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/holdings/{holdingId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/investmentTransactions/{txnId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/valuations/{valuationId} {
  allow read: if request.auth.uid == userId;
  allow write: if false; // Only Cloud Functions can write
}

match /users/{userId}/schedules/{scheduleId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/insights/{insightId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/targets/allocation {
  allow read, write: if request.auth.uid == userId;
}
```

---

## Dependencies

### New Dart Packages
```yaml
dependencies:
  # Existing packages...

  # XIRR calculation
  # Option 1: Use existing package
  # xirr: ^1.0.0

  # Option 2: Implement custom (simpler)
  # No additional dependency needed

  # CSV parsing (for imports)
  csv: ^5.0.0

  # File picker (for CSV/CAS import)
  file_picker: ^6.0.0

  # Charts (if not already present)
  fl_chart: ^0.65.0
```

### Firebase Functions Packages
```json
{
  "dependencies": {
    "firebase-admin": "^11.0.0",
    "firebase-functions": "^4.0.0",
    "csv-parser": "^3.0.0",
    "pdf-parse": "^1.1.1"
  }
}
```

---

## Migration Strategy

### Extending Existing Features

1. **MoneyTrackerScreen**
   - Add "Investments" summary card
   - Show total portfolio value
   - Link to InvestmentsScreen

2. **AnalyticsService**
   - Add `getInvestmentReturns()` method
   - Add `getAssetAllocation()` method
   - Reuse chart widgets

3. **HomeScreen**
   - Add "Top Insights" widget (max 3)
   - Show upcoming SIP dues
   - Link to InsightsScreen

### Database Migration
- No migration needed (new collections)
- Existing collections unchanged
- Firestore security rules additive

---

## Testing Strategy

### Unit Tests
- XirrService.calculateXirr() with sample cashflows
- InvestmentTransactionService._calculateNewAvgPrice()
- Each rule's evaluate() method
- Schedule due date calculation

### Integration Tests
- Add transaction → Holding updates correctly
- BUY transaction increases quantity, updates avgPrice
- SELL transaction decreases quantity, realizes P/L
- Daily valuation captures correct totals
- Insights respect cooldown periods

### E2E Tests
- Complete user flow: Add asset → Add transactions → View portfolio
- CSV import flow: Upload file → Preview → Import → Verify transactions
- Schedule flow: Create SIP → Miss due date → See insight → Mark executed

---

## Performance Considerations

### Optimizations
- **Indexes**: Create Firestore composite indexes for common queries
  - `/investments` where `userId == X` order by `createdAt desc`
  - `/investmentTransactions` where `userId == X` and `assetId == Y` order by `date desc`
  - `/insights` where `userId == X` and `status == 'NEW'` order by `severity`

- **Caching**: Cache latest valuation in memory (reduce Firestore reads)
- **Batch Writes**: Use batch writes for bulk transaction imports
- **Pagination**: Paginate transaction history (load 20 at a time)

### Scalability
- Cloud Functions: Auto-scales with user count
- Firestore: Scales horizontally
- Daily jobs: Process users in batches (100 at a time) to avoid timeouts

---

## Compliance & Disclaimers

### User-Facing Disclaimer
Display in app (InsightsScreen footer):

> "Insights are for educational and monitoring purposes only and do not constitute investment advice. Portfolio values are approximations based on manually entered prices. Always verify with official sources before making investment decisions."

### Data Privacy
- All investment data is user-specific (uid-scoped)
- No sharing of portfolio data with other users
- User can export/delete their investment data
- Comply with local data protection regulations

---

## Timeline Estimate

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1 | 2-3 weeks | Investment tracking MVP with manual price entry |
| Phase 2 | 1-2 weeks | Schedules and 3 core insights rules |
| Phase 3 | 1 week | Automation and CSV import |
| **Total** | **4-6 weeks** | **Fully functional investment tracker** |

Additional phases (API integration, advanced features) can be prioritized based on user feedback.

---

## Success Metrics

### Phase 1 Success Criteria
- 80% of users add at least one investment
- Average 3+ transactions per user per month
- Portfolio valuation accuracy within 5% of actual
- XIRR calculation matches Excel/calculator

### Phase 2 Success Criteria
- 60% of users create at least one SIP schedule
- Average 2+ insights generated per user per month
- <10% insight dismissal rate (indicates relevance)
- Users act on insights (rebalance, mark SIP executed)

### Phase 3 Success Criteria
- 40% of users try CSV import
- <5% error rate in CSV imports
- Daily jobs complete in <5 minutes per 1000 users
- Zero data loss incidents

---

## Support & Documentation

### User Documentation
- "How to add your first investment" tutorial
- "Understanding XIRR returns" explainer
- "Setting up SIP schedules" guide
- CSV import template and instructions
- Insights explanation ("Why am I seeing this?")

### Developer Documentation
- Data model ERD
- API reference for services
- Cloud Functions deployment guide
- Testing guide
- Troubleshooting common issues

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| XIRR calculation errors | High | Use well-tested package; add unit tests with known values |
| Manual price entry fatigue | Medium | Add API integration in Phase 4; provide bulk update UI |
| Cloud Function timeout | Medium | Batch user processing; optimize queries; add monitoring |
| Insight noise (too many) | Low | Tune cooldowns; allow users to mute specific rules |
| CSV import data quality | Medium | Strict validation; clear error messages; template with examples |

---

## Next Steps

1. **Review & Approve Plan** → Get stakeholder sign-off on phased approach
2. **Set Up Development Environment** → Create feature branch, set up local Firebase emulator
3. **Start Phase 1 Implementation** → Begin with data models
4. **Iterate Based on Feedback** → Adjust priorities after Phase 1 user testing

---

## Appendix: Original Spec vs. Simplified

### Features Deferred or Simplified

| Original Feature | Status | Reason |
|------------------|--------|--------|
| Fund overlap matrix | Deferred to Phase 4+ | Requires external AMFI portfolio data |
| Property tracking | Deferred to Phase 4+ | Low priority, complex valuation |
| Email parsing webhook | Deferred to Phase 4+ | Complex integration, low initial value |
| Multi-currency support | Deferred to Phase 4+ | Indian users primarily use INR |
| Crypto tracking | Optional toggle in Phase 4+ | High volatility, regulatory uncertainty |
| Goal tracking with projections | Deferred to Phase 4+ | Requires solid foundation first |
| Weekly email digest | Simplified to in-app | Email infrastructure complexity |
| Complex price adapter system | Simplified to manual entry | API integration can come later |
| All 7 insight rules | Reduced to 3 in Phase 2 | Focus on highest value rules first |

### Features Fully Implemented

| Feature | Phase | Notes |
|---------|-------|-------|
| Investment portfolio tracking | 1 | MF, Equity, FD, Gold assets |
| XIRR calculation | 1 | Using Dart package or custom implementation |
| Daily valuation snapshots | 3 | Automated via Cloud Functions |
| SIP schedules | 2 | Monthly cadence with due date tracking |
| 3 core insights | 2 | SIP_MISSED, CONCENTRATION_RISK, REBALANCE_DRIFT |
| CSV bulk import | 3 | For transaction history |
| Asset allocation breakdown | 1 | Pie chart and percentages |

---

**Document Version:** 1.0
**Last Updated:** 2025-11-09
**Status:** Planning Complete → Ready for Phase 1 Implementation
