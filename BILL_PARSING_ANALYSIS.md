# Credit Card Bill Parsing Analysis

## Test Date: 2025-10-20

---

## 1. EXTRACTED TRANSACTIONS (From App)

### Total Extracted: ___ transactions

**Please fill in the transactions that were extracted by the app:**

| # | Date | Merchant | Amount | Category |
|---|------|----------|--------|----------|
| 1 |      |          |        |          |
| 2 |      |          |        |          |
| 3 |      |          |        |          |
| 4 |      |          |        |          |
| 5 |      |          |        |          |

*(Add more rows as needed)*

---

## 2. ACTUAL TRANSACTIONS (From Bill)

### Total in Bill: ___ transactions

**Please manually enter ALL transactions from the credit card bill:**

| # | Date | Merchant | Amount | Type | Notes |
|---|------|----------|--------|------|-------|
| 1 |      |          |        | Debit/Credit | |
| 2 |      |          |        | Debit/Credit | |
| 3 |      |          |        | Debit/Credit | |
| 4 |      |          |        | Debit/Credit | |
| 5 |      |          |        | Debit/Credit | |

*(Add more rows as needed)*

---

## 3. COMPARISON ANALYSIS

### Missing Transactions
**Transactions in bill but NOT extracted:**

1.
2.
3.

### Incorrect Extractions
**Transactions extracted incorrectly:**

| Merchant (Actual) | Merchant (Extracted) | Amount (Actual) | Amount (Extracted) | Issue |
|-------------------|----------------------|-----------------|-------------------|--------|
|                   |                      |                 |                   |        |

### Correct Extractions
**Number of correctly extracted transactions:** ___

**Accuracy Rate:** ___% (Correct / Total)

---

## 4. PATTERNS IDENTIFIED

### What was extracted correctly?
- [ ] Large amounts (> ₹1000)
- [ ] Well-known merchants (Swiggy, Amazon, etc.)
- [ ] Recent transactions
- [ ] Clear date formats
- Other:

### What was missed?
- [ ] Small amounts (< ₹100)
- [ ] Similar consecutive transactions
- [ ] Merchant names with special characters
- [ ] Transactions near headers/footers
- [ ] Multi-line merchant names
- Other:

### Date Format Issues
- Bill date format: ___________
- Expected format: YYYY-MM-DD
- Conversion issues: Yes / No

---

## 5. BILL CHARACTERISTICS

- **Bank:** ___________
- **Bill Month/Year:** ___________
- **Total Transactions in Bill:** ___
- **Bill Size:** ___ pages
- **File Format:** PDF / JPG / PNG
- **File Size:** ___ MB
- **OCR Quality:** Good / Fair / Poor

---

## 6. PARSING METHOD USED

- [ ] Rule-based (bank-specific)
- [ ] Claude AI (LLM)
- [ ] Google Vision OCR only

**Which bank rule was attempted?** ___________

---

## 7. RECOMMENDATIONS FOR IMPROVEMENT

### High Priority Fixes:
1.
2.
3.

### Medium Priority:
1.
2.

### Low Priority / Edge Cases:
1.
2.

---

## 8. EXAMPLE TRANSACTION PATTERNS

### Well-Extracted Example:
```
Date: 2025-01-15
Merchant: AMAZON INDIA
Amount: 1,250.00
Status: ✅ Correctly extracted
```

### Missed Example:
```
Date: 2025-01-12
Merchant: LOCAL GROCERY STORE
Amount: 150.50
Status: ❌ Not extracted
Reason: [merchant name format, amount too small, etc.]
```

---

## 9. TECHNICAL DETAILS

### Vision API Performance
- **Text extraction successful:** Yes / No
- **Characters extracted:** ___
- **Text quality:** Good / Fair / Poor

### Claude AI Performance
- **Model used:** claude-3-haiku-20240307
- **Response time:** ___ seconds
- **Parsing strategy:** Worked / Failed

### Rule-Based Parser
- **Attempted:** Yes / No
- **Result:** Success / Failed / Partial

---

## 10. ACTION ITEMS

### Code Changes Needed:
- [ ] Update regex patterns in `parseHDFC()` function
- [ ] Improve merchant name cleaning logic
- [ ] Add better amount extraction
- [ ] Handle multi-line transactions
- [ ] Improve date parsing for edge cases
- [ ] Add support for new bank format

### Prompt Improvements (for Claude AI):
- [ ] Add examples of missed transaction types
- [ ] Clarify extraction rules
- [ ] Add negative examples (what to skip)
- [ ] Improve category inference

### Testing:
- [ ] Test with more bills from same bank
- [ ] Test with different banks
- [ ] Test with different file formats
- [ ] Validate edge cases

---

## Notes

Please add any additional observations or issues here:

