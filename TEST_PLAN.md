# SpendPal Test Plan

**Version:** 1.0
**Date:** October 20, 2025
**Platform:** iOS & Android
**Testing Type:** Manual & Automated

---

## 1. OVERVIEW

SpendPal is a Flutter-based expense tracking application with the following key features:
- Personal, Group, and Friend expense tracking
- Credit card bill parsing using OCR and AI
- Firebase authentication (Google Sign-In)
- Real-time expense synchronization
- Social expense splitting

---

## 2. TEST OBJECTIVES

### Primary Objectives
- ✅ Verify all core features work as expected
- ✅ Ensure data accuracy in expense tracking
- ✅ Validate bill parsing accuracy (multi-page PDF support)
- ✅ Test Firebase real-time synchronization
- ✅ Verify UI/UX consistency across screens
- ✅ Ensure proper error handling

### Secondary Objectives
- Performance testing under various network conditions
- Security testing for user data
- Cross-platform compatibility (iOS/Android)

---

## 3. TESTING SCOPE

### In Scope
- Authentication flows
- Expense management (CRUD operations)
- Bill upload and parsing
- Personal expenses tab (with new type badges)
- Groups management
- Friends management
- Firebase integration
- Offline behavior (persistence disabled)

### Out of Scope
- Backend infrastructure testing
- Third-party service testing (Google, Firebase, Anthropic)
- Load/stress testing
- Accessibility testing

---

## 4. TEST ENVIRONMENT

### Devices
- **iOS:** iPhone 15 Pro Simulator (iOS 17.5)
- **Android:** Pixel 6 Emulator (Android 13+)

### Backend
- Firebase Project: SpendPal Production
- Cloud Functions: parseBill (Node.js)
- Firestore Database
- Firebase Storage

### Test Data
- Sample credit card bills (PDF, JPG, PNG)
- Test user accounts
- Mock expense data
- Sample group/friend data

---

## 5. TEST CASES

## 5.1 AUTHENTICATION

### TC-AUTH-01: Google Sign-In (Happy Path)
**Priority:** High
**Preconditions:** User not logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app | Login screen displayed |
| 2 | Tap "Sign in with Google" | Google account picker shown |
| 3 | Select Google account | Authentication successful |
| 4 | App navigates to home screen | Home screen with 4 tabs displayed |

**Success Criteria:** User logged in and redirected to home screen

---

### TC-AUTH-02: Google Sign-In Cancellation
**Priority:** Medium
**Preconditions:** User not logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app | Login screen displayed |
| 2 | Tap "Sign in with Google" | Google account picker shown |
| 3 | Cancel sign-in flow | User remains on login screen |
| 4 | Error message displayed | "Sign in cancelled" or similar message |

**Success Criteria:** App handles cancellation gracefully

---

### TC-AUTH-03: Logout
**Priority:** High
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Account tab | Account screen displayed |
| 2 | Tap logout button | Confirmation dialog shown |
| 3 | Confirm logout | User logged out |
| 4 | Redirected to login screen | Login screen displayed |

**Success Criteria:** User successfully logged out and data cleared

---

## 5.2 PERSONAL EXPENSES TAB (NEW FEATURES)

### TC-PERSONAL-01: View All Expense Types
**Priority:** Critical
**Preconditions:** User logged in, has expenses in Firebase

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Personal tab | "My Expenses" screen displayed |
| 2 | Verify expense list | All expenses where user is paidBy are shown |
| 3 | Check expense badges | Each expense shows correct type badge |
| 4 | Verify personal expenses | Teal "Personal" badge with person icon |
| 5 | Verify group expenses | Blue "Group" badge with groups icon |
| 6 | Verify friend expenses | Purple "Split" badge with people icon |

**Success Criteria:** All three expense types displayed with correct badges

---

### TC-PERSONAL-02: Empty State
**Priority:** Medium
**Preconditions:** User logged in, no expenses in Firebase

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Personal tab | Empty state displayed |
| 2 | Check empty state message | "No expenses yet" shown |
| 3 | Check subtitle | "Track your personal, group, and friend expenses here" |
| 4 | Verify add button | "Add First Expense" button visible |

**Success Criteria:** Empty state properly displayed with helpful message

---

### TC-PERSONAL-03: Expense Type Badge - Personal
**Priority:** High
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Create personal expense (no group, no split) | Expense saved to Firebase |
| 2 | Navigate to Personal tab | Expense listed |
| 3 | Check badge color | Teal/green badge |
| 4 | Check badge icon | Person icon displayed |
| 5 | Check badge label | "Personal" text shown |

**Success Criteria:** Personal expenses correctly identified and badged

---

### TC-PERSONAL-04: Expense Type Badge - Group
**Priority:** High
**Preconditions:** User logged in, belongs to a group

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Create group expense (with groupId) | Expense saved to Firebase |
| 2 | Navigate to Personal tab | Expense listed |
| 3 | Check badge color | Blue badge |
| 4 | Check badge icon | Groups icon displayed |
| 5 | Check badge label | "Group" text shown |

**Success Criteria:** Group expenses correctly identified and badged

---

### TC-PERSONAL-05: Expense Type Badge - Friend Split
**Priority:** High
**Preconditions:** User logged in, has friends

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Create friend split expense (splitWith > 1, no groupId) | Expense saved to Firebase |
| 2 | Navigate to Personal tab | Expense listed |
| 3 | Check badge color | Purple badge |
| 4 | Check badge icon | People icon displayed |
| 5 | Check badge label | "Split" text shown |

**Success Criteria:** Friend split expenses correctly identified and badged

---

### TC-PERSONAL-06: Monthly Statistics
**Priority:** Medium
**Preconditions:** User has expenses in current month

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Personal tab | Statistics section displayed |
| 2 | Check "This Month" amount | Correct sum of current month expenses |
| 3 | Check "Total Expenses" count | Correct count of all expenses |
| 4 | Check "Top Categories" | Top 3 categories by amount shown |

**Success Criteria:** Statistics accurately calculated and displayed

---

### TC-PERSONAL-07: Real-time Sync (No Cache)
**Priority:** Critical
**Preconditions:** Offline persistence disabled, user logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Open app on Device A | Personal tab shows current data |
| 2 | Add expense on Device B | Expense saved to Firebase |
| 3 | Pull to refresh on Device A | New expense appears immediately |
| 4 | Delete expense on Device B | Expense removed from Firebase |
| 5 | Pull to refresh on Device A | Expense no longer shown |

**Success Criteria:** Changes sync in real-time without cached data

---

## 5.3 BILL UPLOAD & PARSING

### TC-BILL-01: Upload PDF Bill (Multi-Page)
**Priority:** Critical
**Preconditions:** User logged in, has multi-page PDF bill

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Bill Upload | Upload screen displayed |
| 2 | Tap "Choose PDF/Image" | File picker shown |
| 3 | Select 4-page PDF bill | File selected, preview shown |
| 4 | Select bank (e.g., HDFC) | Bank dropdown populated |
| 5 | Tap "Upload & Parse Bill" | Upload progress shown |
| 6 | Wait for processing | Progress indicators update |
| 7 | Check parsed transactions | Transaction review screen shown |
| 8 | Verify transaction count | Majority of transactions extracted (>85%) |

**Success Criteria:** Multi-page PDF processed, most transactions extracted

**Test Data:** Use `hdfcBill.pdf` (4 pages, 66 transactions)

---

### TC-BILL-02: Upload JPG Bill (Single Image)
**Priority:** High
**Preconditions:** User logged in, has bill image

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Bill Upload | Upload screen displayed |
| 2 | Tap "Choose from Gallery" | Image picker shown |
| 3 | Select JPG bill image | Image selected, preview shown |
| 4 | Tap "Upload & Parse Bill" | Upload starts |
| 5 | Check parsed transactions | Transactions extracted from image |

**Success Criteria:** Image bill processed successfully

---

### TC-BILL-03: Bill Parsing Accuracy
**Priority:** Critical
**Preconditions:** Known bill with exact transaction count

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Upload test HDFC bill (66 transactions) | Bill uploaded |
| 2 | Wait for parsing to complete | Parsing done |
| 3 | Count extracted transactions | ~60-64 transactions extracted |
| 4 | Verify transaction details | Dates in YYYY-MM-DD format |
| 5 | Check merchant names | Names cleaned and normalized |
| 6 | Verify amounts | Positive numbers, correct decimals |
| 7 | Check categories | Appropriate categories assigned |

**Success Criteria:**
- Extraction rate: >85%
- Date format: Correct
- Amounts: Accurate
- Categories: Reasonable

**Reference:** See `BILL_COMPARISON_REPORT.md`

---

### TC-BILL-04: Bill Parsing - Transaction Filtering
**Priority:** High
**Preconditions:** Bill with mixed transaction types

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Upload bill with payments, EMIs, fees | Bill uploaded |
| 2 | Check extracted transactions | Only debit transactions extracted |
| 3 | Verify exclusions | Payments not included |
| 4 | Verify exclusions | EMI principal/interest not included |
| 5 | Verify exclusions | Fees not included |
| 6 | Verify exclusions | Reversals not included |

**Success Criteria:** Only valid debit purchases extracted

---

### TC-BILL-05: Bill Parsing - Error Handling
**Priority:** Medium
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Upload invalid file (e.g., .txt) | Error message shown |
| 2 | Upload corrupted PDF | Graceful error handling |
| 3 | Upload bill with no text | "No text found" error |
| 4 | Cancel upload mid-process | Upload cancelled, no partial data |

**Success Criteria:** All error cases handled gracefully

---

### TC-BILL-06: Transaction Review & Edit
**Priority:** High
**Preconditions:** Bill parsed successfully

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | View transaction review screen | All transactions listed |
| 2 | Edit transaction merchant name | Changes saved |
| 3 | Edit transaction amount | Changes saved |
| 4 | Change transaction category | Category updated |
| 5 | Delete incorrect transaction | Transaction removed from list |
| 6 | Tap "Save All" | Transactions saved to Firebase |

**Success Criteria:** All edits saved correctly

---

## 5.4 ADD EXPENSE

### TC-EXPENSE-01: Add Personal Expense
**Priority:** High
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Tap FAB "Add Expense" | Add expense screen shown |
| 2 | Enter title: "Groceries" | Title field populated |
| 3 | Enter amount: 1500 | Amount field populated |
| 4 | Select category: "Food" | Category selected |
| 5 | Add notes: "Weekly shopping" | Notes field populated |
| 6 | Leave group empty | No group selected |
| 7 | Leave split empty | No friends selected |
| 8 | Tap "Save" | Expense saved |
| 9 | Navigate to Personal tab | New expense visible with "Personal" badge |

**Success Criteria:** Personal expense created and badged correctly

---

### TC-EXPENSE-02: Add Group Expense
**Priority:** High
**Preconditions:** User belongs to a group

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Tap "Add Expense" | Add expense screen shown |
| 2 | Enter title: "Team Lunch" | Title entered |
| 3 | Enter amount: 5000 | Amount entered |
| 4 | Select group: "Office Team" | Group selected |
| 5 | Tap "Save" | Expense saved |
| 6 | Navigate to Personal tab | Expense shows "Group" badge (blue) |
| 7 | Navigate to Groups tab | Expense appears in group |

**Success Criteria:** Group expense created and appears in both tabs

---

### TC-EXPENSE-03: Add Friend Split Expense
**Priority:** High
**Preconditions:** User has friends

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Tap "Add Expense" | Add expense screen shown |
| 2 | Enter title: "Dinner" | Title entered |
| 3 | Enter amount: 2000 | Amount entered |
| 4 | Select friends to split with | 2+ friends selected |
| 5 | Tap "Save" | Expense saved |
| 6 | Navigate to Personal tab | Expense shows "Split" badge (purple) |

**Success Criteria:** Split expense created with correct badge

---

### TC-EXPENSE-04: Form Validation
**Priority:** Medium
**Preconditions:** User on add expense screen

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Leave title empty | Validation error shown |
| 2 | Leave amount empty | Validation error shown |
| 3 | Enter negative amount | Validation error shown |
| 4 | Enter amount "abc" | Input rejected or validation error |
| 5 | Fill all required fields | Save button enabled |

**Success Criteria:** Proper validation for all fields

---

## 5.5 GROUPS MANAGEMENT

### TC-GROUP-01: Create Group
**Priority:** High
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Groups tab | Groups list shown |
| 2 | Tap "Create Group" button | Create group dialog shown |
| 3 | Enter group name: "Roommates" | Name entered |
| 4 | Select group type: "Home" | Type selected |
| 5 | Add members (optional) | Members added |
| 6 | Tap "Create" | Group created |
| 7 | Check groups list | New group appears |

**Success Criteria:** Group created successfully

---

### TC-GROUP-02: View Group Details
**Priority:** Medium
**Preconditions:** User belongs to groups

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Navigate to Groups tab | Groups list shown |
| 2 | Tap on a group | Group detail screen shown |
| 3 | Check group name | Correct name displayed |
| 4 | Check members list | All members shown |
| 5 | Check group expenses | Expenses for this group listed |

**Success Criteria:** Group details displayed accurately

---

## 5.6 FIREBASE INTEGRATION

### TC-FIREBASE-01: Data Persistence Disabled
**Priority:** Critical
**Preconditions:** Offline persistence disabled in code

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Clear Firebase database | Database empty |
| 2 | Launch app | Empty state shown |
| 3 | Add expense on different device | Expense saved to Firebase |
| 4 | Pull to refresh | New expense appears |
| 5 | Close and reopen app | NO cached data, shows only Firebase data |

**Success Criteria:** App always shows fresh Firebase data, no cache

---

### TC-FIREBASE-02: Network Error Handling
**Priority:** High
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Disable WiFi and mobile data | Network offline |
| 2 | Navigate to Personal tab | Loading indicator or error message |
| 3 | Try to add expense | Error: "No internet connection" |
| 4 | Enable network | Connection restored |
| 5 | Pull to refresh | Data loads successfully |

**Success Criteria:** Appropriate error messages, graceful recovery

---

## 5.7 UI/UX TESTING

### TC-UI-01: Navigation
**Priority:** Medium
**Preconditions:** User logged in

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Tap Groups tab | Groups screen shown |
| 2 | Tap Friends tab | Friends screen shown |
| 3 | Tap Activity tab | Activity screen shown |
| 4 | Tap Account tab | Account screen shown |
| 5 | Tap Personal tab | Back to Personal screen |

**Success Criteria:** All tabs navigate correctly

---

### TC-UI-02: Dark Theme Consistency
**Priority:** Low
**Preconditions:** App uses dark theme

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Check all screens | Consistent dark theme colors |
| 2 | Check text readability | All text clearly visible |
| 3 | Check icons | All icons visible and themed |
| 4 | Check buttons | Consistent button styling |

**Success Criteria:** Consistent dark theme throughout app

---

### TC-UI-03: Expense Type Badge Visibility
**Priority:** High
**Preconditions:** User has all three expense types

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | View Personal tab | All badges clearly visible |
| 2 | Check badge colors | Distinct colors (teal, blue, purple) |
| 3 | Check badge icons | Icons clearly visible |
| 4 | Check badge text | "Personal", "Group", "Split" readable |
| 5 | Check on different screen sizes | Badges scale appropriately |

**Success Criteria:** Badges clearly distinguish expense types

---

## 6. TEST DATA REQUIREMENTS

### Sample Users
```
User 1: test.user1@gmail.com
User 2: test.user2@gmail.com
User 3: test.user3@gmail.com
```

### Sample Expenses
```json
[
  {
    "title": "Coffee",
    "amount": 250,
    "category": "Food",
    "notes": "Morning coffee",
    "type": "personal"
  },
  {
    "title": "Team Lunch",
    "amount": 5000,
    "category": "Food",
    "groupId": "group123",
    "type": "group"
  },
  {
    "title": "Movie Tickets",
    "amount": 800,
    "category": "Entertainment",
    "splitWith": ["uid1", "uid2"],
    "type": "friend"
  }
]
```

### Sample Bills
- **HDFC Bill:** 4 pages, 66 transactions (Sep-Oct 2025)
- **Single Page Bill:** 1 page, ~10 transactions
- **Image Bill:** JPG format bill scan

---

## 7. DEFECT SEVERITY

### Critical (P0)
- App crashes
- Data loss
- Authentication failure
- Unable to add/view expenses

### High (P1)
- Bill parsing failure
- Incorrect expense badges
- Firebase sync issues
- Major UI issues

### Medium (P2)
- Minor UI inconsistencies
- Performance issues
- Non-critical validation errors

### Low (P3)
- Cosmetic issues
- Minor text issues
- Enhancement requests

---

## 8. TEST EXECUTION SCHEDULE

### Phase 1: Core Features (Week 1)
- Authentication (TC-AUTH-01 to TC-AUTH-03)
- Personal Expenses Tab (TC-PERSONAL-01 to TC-PERSONAL-07)
- Add Expense (TC-EXPENSE-01 to TC-EXPENSE-04)

### Phase 2: Bill Parsing (Week 2)
- Bill Upload (TC-BILL-01 to TC-BILL-06)
- Transaction accuracy testing
- Multi-page PDF testing

### Phase 3: Social Features (Week 3)
- Groups Management (TC-GROUP-01 to TC-GROUP-02)
- Friends Management
- Split expense calculations

### Phase 4: Integration & Polish (Week 4)
- Firebase Integration (TC-FIREBASE-01 to TC-FIREBASE-02)
- UI/UX Testing (TC-UI-01 to TC-UI-03)
- Regression testing
- Bug fixes

---

## 9. SUCCESS CRITERIA

### Must Have (Release Blockers)
- ✅ All P0 (Critical) test cases pass
- ✅ >85% bill parsing accuracy on multi-page PDFs
- ✅ All three expense types display correctly with badges
- ✅ No cached data issues (fresh Firebase data always)
- ✅ Authentication works reliably
- ✅ Expenses save and sync correctly

### Should Have
- ✅ All P1 (High) test cases pass
- ✅ Smooth navigation between screens
- ✅ Consistent dark theme
- ✅ Proper error handling

### Nice to Have
- ✅ All P2/P3 test cases pass
- ✅ Performance optimization
- ✅ Accessibility improvements

---

## 10. RISK ANALYSIS

### High Risk Areas
1. **Bill Parsing Accuracy**
   - Risk: Low accuracy on varied bill formats
   - Mitigation: Test with bills from multiple banks

2. **Firebase Offline Behavior**
   - Risk: Unexpected cached data
   - Mitigation: Persistence disabled, test thoroughly

3. **Expense Type Badge Logic**
   - Risk: Incorrect badge assignment
   - Mitigation: Comprehensive test coverage

### Medium Risk Areas
1. **Multi-page PDF Processing**
   - Risk: Memory issues with large PDFs
   - Mitigation: Limit to 4 pages

2. **Real-time Sync**
   - Risk: Race conditions with concurrent updates
   - Mitigation: Test multi-device scenarios

---

## 11. TOOLS & RESOURCES

### Testing Tools
- Manual testing on iOS Simulator
- Manual testing on Android Emulator
- Firebase Console for backend verification
- Flutter DevTools for debugging

### Documentation
- `BILL_COMPARISON_REPORT.md` - Bill parsing accuracy analysis
- `CLAUDE.md` - Project setup and architecture
- `README.md` - App overview

### Test Reports
- Test execution results: `TEST_RESULTS.md` (to be created)
- Defect tracking: GitHub Issues
- Coverage reports: Flutter test coverage

---

## 12. CONTACT & SUPPORT

**QA Lead:** TBD
**Developers:** Abhay Singh
**Product Owner:** TBD

**Reporting Bugs:**
- Create issue in GitHub repository
- Include screenshots/videos
- Provide reproduction steps
- Specify device/OS version

---

## APPENDIX A: Test Case Template

```markdown
### TC-[MODULE]-[NUMBER]: [Test Case Title]
**Priority:** High/Medium/Low
**Preconditions:** [What needs to be true before testing]

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | [Action] | [Expected outcome] |
| 2 | [Action] | [Expected outcome] |

**Success Criteria:** [What defines success]
**Test Data:** [Specific data needed]
```

---

## APPENDIX B: Known Issues

1. **RenderFlex Overflow in Bill Upload Screen**
   - Location: `bill_upload_screen.dart:573`
   - Severity: Low (UI cosmetic)
   - Status: Pending fix

2. **CocoaPods Version Warning**
   - Message: Recommended version 1.16.2+ not installed
   - Severity: Low (warning only)
   - Status: No action required

---

**END OF TEST PLAN**

*This test plan should be reviewed and updated regularly as new features are added.*
