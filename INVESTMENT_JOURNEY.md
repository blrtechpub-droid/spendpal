# Investment Tracking - User Journey

## Overview

SpendPal's investment tracker lets users manage their entire investment portfolio across 9 asset types, 24+ broker platforms, and integrates with the Money Tracker for a complete net worth picture. Transactions can be added manually or auto-imported from SMS.

---

## Entry Points

Users discover the investment feature from two places:

1. **Money Tracker Screen** → InvestmentsCard (teal gradient card showing portfolio value and P/L)
2. **Direct navigation** → `/investments` route

```
Money Tracker Screen
├── Net Worth Card ← includes investment total
├── Bank Balance Card
├── Wallets Card
├── Credit Card Card
├── Investments Card ← TAP HERE
│   ├── Current Value (large font)
│   ├── P/L amount & percentage
│   └── [Expanded] Top 3 holdings + "View All"
├── Debts Card
└── Budget Summary Card
```

For first-time users, the card shows "No investments yet" with a prompt to add their first investment.

---

## Screen Flow

```
                    ┌──────────────────────┐
                    │   Money Tracker       │
                    │   (InvestmentsCard)   │
                    └──────────┬───────────┘
                               │ tap
                               ▼
                    ┌──────────────────────┐
                    │  InvestmentsScreen    │
                    │  /investments         │
                    │                      │
                    │  Portfolio Summary    │
                    │  7 Tabs: All | MF |  │
                    │  Equity | ETF | FD/RD│
                    │  | PPF/EPF/NPS | Gold│
                    │                      │
                    │  [+] Add Options:    │
                    │  ├── Add New Asset   │
                    │  ├── Add Transaction │
                    │  └── Update Price    │
                    └──┬────┬────┬────┬────┘
                       │    │    │    │
          ┌────────────┘    │    │    └──────────────┐
          ▼                 │    ▼                   ▼
┌─────────────────┐  │  ┌──────────────────┐  ┌──────────────┐
│  AddAssetScreen  │  │  │ UpdatePriceScreen│  │ AssetDetail  │
│  /add_asset      │  │  │ /update_price    │  │ Screen       │
│                  │  │  │                  │  │              │
│  Asset type      │  │  │  Select asset    │  │  Asset info  │
│  Name/Symbol     │  │  │  Enter price     │  │  Holdings    │
│  Platform        │  │  │  Save            │  │  P/L & XIRR  │
│  FD/Gold fields  │  │  │                  │  │  Txn history │
└─────────────────┘  │  └──────────────────┘  │              │
                     ▼                         │  Actions:    │
          ┌───────────────────────┐            │  + Add Txn   │
          │ AddInvestmentTxnScreen│            │  ✏ Edit Asset│
          │ /add_investment_txn   │            │  📈 Update $ │
          │                       │            │  🗑 Delete   │
          │  Select asset         │            └──────────────┘
          │  Transaction type:    │
          │  BUY|SELL|SIP|DIV|FEE │
          │  Date, Qty, Price     │
          │  Fees, Notes          │
          └───────────────────────┘


SMS Auto-Import (separate flow):

  SMS Arrives (broker/AMC)
          │
          ▼
  InvestmentSmsParserService
  (40+ regex patterns)
          │
          ▼
  investmentSmsQueue (Firestore)
  status: pending
          │
          ▼
  ┌──────────────────────────┐
  │ InvestmentSmsReviewScreen│
  │ /investment_sms_review   │
  │                          │
  │  Parsed SMS cards        │
  │  [Approve] [Reject]      │
  │                          │
  │  On approve:             │
  │  → Find/create asset     │
  │  → Create transaction    │
  │  → Update holding        │
  └──────────────────────────┘
```

---

## Supported Asset Types

| Type | Code | Fields | Example |
|------|------|--------|---------|
| Equity (Stock) | `equity` | Name, Symbol, Platform | RELIANCE on Zerodha |
| Mutual Fund | `mutual_fund` | Name, Scheme Code, Platform | Axis Bluechip on Groww |
| ETF | `etf` | Name, Symbol, Platform | NIFTYBEES on Upstox |
| Fixed Deposit | `fd` | Bank, Account #, Interest %, Tenure, Maturity | SBI FD 7.1% |
| Recurring Deposit | `rd` | Bank, Account #, Interest %, Tenure, Maturity | HDFC RD |
| PPF | `ppf` | Bank, Account # | SBI PPF |
| EPF | `epf` | Account # | EPFO |
| NPS | `nps` | Account # | NPS (NSDL) |
| Gold | `gold` | Form (physical/digital/ETF), Weight, Purity | 10g 24K Physical |

---

## Transaction Types

| Type | Effect on Holding | Cash Flow | Use Case |
|------|-------------------|-----------|----------|
| **BUY** | +qty, recalculates avgPrice | Outflow (-) | Purchase shares/units |
| **SELL** | -qty, avgPrice unchanged | Inflow (+) | Sell shares/units |
| **SIP** | +qty, recalculates avgPrice | Outflow (-) | Systematic Investment Plan |
| **DIVIDEND** | No change | Inflow (+) | Income received |
| **FEE** | No change | Outflow (-) | Brokerage/charges |

### Weighted Average Price Calculation (BUY/SIP)

```
newAvgPrice = (existingQty x existingAvg + newQty x newPrice) / (existingQty + newQty)
```

Example:
- Existing: 100 units @ 50 avg = 5,000 invested
- New BUY: 50 units @ 60
- New avg: (100 x 50 + 50 x 60) / (100 + 50) = 8,000 / 150 = 53.33

### SELL Validation

- Checks available quantity before allowing sell
- Average price stays the same (cost basis preserved)
- Holding deleted if quantity drops below 0.001

---

## Data Models

### Three-Layer Architecture

```
InvestmentAsset (What you own)
    │
    ├── InvestmentHolding (Current position - qty, avgPrice, currentPrice)
    │       │
    │       ├── currentValue = qty x currentPrice
    │       ├── investedAmount = qty x avgPrice
    │       ├── unrealizedPL = currentValue - investedAmount
    │       └── unrealizedPLPercent = (PL / invested) x 100
    │
    └── InvestmentTransaction[] (History of BUY/SELL/SIP/DIV/FEE)
            │
            └── xirrCashflow (for return calculation)
                ├── BUY/SIP/FEE → negative (money out)
                └── SELL/DIVIDEND → positive (money in)
```

### Firestore Structure

```
users/{userId}/
├── investmentAssets/{assetId}
│   ├── assetType, name, symbol, schemeCode
│   ├── platform, trackerId
│   ├── bankName, accountNumber, interestRate  (FD/RD)
│   ├── goldForm, weightGrams, purity          (Gold)
│   └── currency, tags, createdAt, updatedAt
│
├── investmentHoldings/{holdingId}
│   ├── assetId, quantity, avgPrice
│   ├── currentPrice, lastUpdatedAt
│   └── (computed: currentValue, investedAmount, PL)
│
├── investmentTransactions/{txnId}
│   ├── assetId, holdingId, type
│   ├── date, quantity, price, amount, fees
│   ├── source (MANUAL/CSV/CAS/EMAIL/SMS_AUTO)
│   └── notes, createdAt
│
└── investmentSmsQueue/{queueId}
    ├── parsedData (fundName, units, nav, amount, type)
    ├── rawSms, sender, receivedAt
    └── status (pending/imported/rejected)
```

---

## Services

### InvestmentTransactionService
Core CRUD for assets and transactions.

| Method | Purpose |
|--------|---------|
| `createAsset()` | Register a new investment instrument |
| `addBuyTransaction()` | Record purchase, update holding with weighted avg |
| `addSellTransaction()` | Record sale, reduce holding quantity |
| `addSipTransaction()` | Record SIP (same logic as BUY) |
| `addDividendTransaction()` | Record dividend income |
| `addFeeTransaction()` | Record brokerage/charges |
| `updateCurrentPrice()` | Update market price for P/L calculation |
| `deleteTransaction()` | Delete and recalculate holding from scratch |

### PortfolioService
Portfolio-level analytics and aggregation.

| Method | Purpose |
|--------|---------|
| `getPortfolioSummary()` | Total invested, current value, P/L, item list |
| `getPortfolioByAssetType()` | Group holdings by asset type with subtotals |
| `getAssetPerformance()` | Per-asset XIRR, transaction history, returns |
| `getTopPerformers()` | Best performing holdings |
| `getWorstPerformers()` | Worst performing holdings |
| `getPortfolioStats()` | Win rate, avg return, winners/losers count |
| `searchAssets()` | Fuzzy search across user's assets |
| `streamPortfolioSummary()` | Real-time portfolio updates |

### ValuationService
Daily snapshots and historical tracking.

| Method | Purpose |
|--------|---------|
| `calculateCurrentValuation()` | Aggregate all holdings by type |
| `createTodayValuation()` | Save daily portfolio snapshot |
| `getValuationsInRange()` | Historical portfolio values |
| `calculatePerformanceMetrics()` | Growth %, volatility, peak/trough |
| `getAssetAllocation()` | % distribution by asset type |

### InvestmentSmsParserService
Auto-detect and parse investment SMS.

| Method | Purpose |
|--------|---------|
| `parseInvestmentSms()` | Extract data from SMS text using 40+ regex patterns |
| `saveInvestmentSms()` | Save to pending queue for user review |
| `importToInvestmentTransaction()` | Convert approved SMS to actual transaction |
| `getPendingInvestmentSms()` | Stream of items awaiting review |

---

## SMS Auto-Import

### Supported Platforms (SMS Keywords)

**Discount Brokers:** Zerodha, Groww, Upstox, Angel One, 5Paisa
**Traditional Brokers:** ICICI Direct, HDFC Securities, Kotak Securities
**MF Platforms:** Kuvera, Paytm Money, MFU Online
**Gold:** SafeGold, MMTC-PAMP
**Government:** NPS (NSDL), PPF (SBI), EPF (EPFO)

### Detected SMS Patterns

| Pattern | Example SMS |
|---------|-------------|
| MF Purchase | "purchased 10.5 units of Axis Bluechip Fund at NAV Rs.45.23" |
| SIP | "Your SIP investment of Rs.5000 in Fund Name is successful" |
| MF Redemption | "redeemed 10.5 units of Fund Name" |
| Dividend | "Dividend of Rs.125.50 credited for Fund Name" |
| Stock Buy | "bought 5 shares of RELIANCE at Rs.2450" |
| Stock Sell | "sold 5 shares of RELIANCE at Rs.2450" |
| PPF Deposit | "Rs.10000 deposited in PPF account" |
| EPF Contribution | "EPF contribution of Rs.5000 credited" |
| NAV Update | "NAV of Fund Name as on 10-Nov-2025: Rs.45.23" |

### Import Flow

```
1. SMS arrives → SmsListenerService detects investment keywords
2. InvestmentSmsParserService.parseInvestmentSms() extracts data
3. Saved to investmentSmsQueue with status: "pending"
4. User opens InvestmentSmsReviewScreen
5. Reviews parsed data alongside raw SMS
6. On APPROVE:
   a. Find existing asset by schemeCode → symbol → fuzzy name
   b. Create new asset if not found
   c. Create transaction (BUY/SELL/SIP/DIVIDEND)
   d. Update holding (quantity + weighted avg price)
   e. Mark queue item as "imported"
7. On REJECT: Mark as "rejected", no data created
```

---

## Money Tracker Integration

The investment portfolio feeds into the Money Tracker's net worth calculation:

```
Net Worth = Total Assets - Total Liabilities

Total Assets:
  ├── Bank Savings (from moneyAccounts)
  ├── Digital Wallets (from moneyAccounts)
  ├── Investments ← PortfolioService.getPortfolioSummary()['totalCurrent']
  └── Other Assets

Total Liabilities:
  ├── Credit Card Balance
  └── Loans
```

The InvestmentsCard in Money Tracker shows:
- **Collapsed**: Current value + P/L with color-coded gradient
- **Expanded**: Top 3 holdings + "View All" and "Manage Investments" buttons

---

## Portfolio Analytics

### Available Metrics

| Metric | Description |
|--------|-------------|
| Total Invested | Sum of (qty x avgPrice) across all holdings |
| Current Value | Sum of (qty x currentPrice) across all holdings |
| Total P/L | Current Value - Total Invested |
| Total P/L % | (Total P/L / Total Invested) x 100 |
| XIRR | Extended IRR considering actual transaction dates |
| Win Rate | % of holdings with positive P/L |
| Asset Allocation | % distribution across asset types |

### Portfolio Valuation (Daily Snapshots)

The `ValuationService` creates daily snapshots (`PortfolioValuation`) containing:
- Total portfolio value by asset type
- Per-asset breakdown
- Overall P/L metrics
- Used for historical performance charts

---

## File Reference

### Screens
| File | Route | Purpose |
|------|-------|---------|
| `lib/screens/investments/investments_screen.dart` | `/investments` | Portfolio dashboard with 7 tabs |
| `lib/screens/investments/add_asset_screen.dart` | `/add_asset` | Create/edit investment asset |
| `lib/screens/investments/add_investment_transaction_screen.dart` | `/add_investment_transaction` | Record BUY/SELL/SIP/DIV/FEE |
| `lib/screens/investments/update_price_screen.dart` | `/update_price` | Update current market price |
| `lib/screens/investments/asset_detail_screen.dart` | Push navigation | Asset details, holdings, XIRR, history |
| `lib/screens/investment/investment_sms_review_screen.dart` | `/investment_sms_review` | Review & approve parsed SMS |
| `lib/screens/money_tracker/money_tracker_screen.dart` | (tab) | InvestmentsCard at lines 2278-2568 |

### Models
| File | Purpose |
|------|---------|
| `lib/models/investment_asset.dart` | Master asset record (9 types) |
| `lib/models/investment_holding.dart` | Current position with P/L getters |
| `lib/models/investment_transaction.dart` | Transaction history with XIRR cashflow |
| `lib/models/portfolio_valuation.dart` | Daily portfolio snapshot |

### Services
| File | Purpose |
|------|---------|
| `lib/services/investment_transaction_service.dart` | Asset CRUD, transaction management, holding updates |
| `lib/services/portfolio_service.dart` | Portfolio summary, analytics, search, streaming |
| `lib/services/valuation_service.dart` | Daily snapshots, historical data, allocation |
| `lib/services/investment_sms_parser_service.dart` | SMS detection, parsing, queue management |

### Config
| File | Purpose |
|------|---------|
| `lib/config/investment_platform_registry.dart` | 24+ broker/platform definitions with SMS keywords |

---

## Known Issues

| Issue | Location | Impact |
|-------|----------|--------|
| Double FutureBuilder in InvestmentsCard | `money_tracker_screen.dart:2316,2437` | Redundant API calls |
| Missing error handling in InvestmentsCard | `money_tracker_screen.dart:2316` | Silent failures |
| No real-time updates (Future not Stream) | InvestmentsCard | Manual refresh needed |
| SELL quantity validation off-by-one | `investment_transaction_service.dart:127` | Can't fully liquidate |
| No concurrency control | Transaction service | Race condition on simultaneous trades |
| Debug print() in production | Multiple services | Console noise |
| No unit tests | All investment logic | Untested calculations |
