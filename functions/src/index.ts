import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import {ImageAnnotatorClient} from '@google-cloud/vision';
import Anthropic from '@anthropic-ai/sdk';
import * as https from 'https';

admin.initializeApp();

interface Transaction {
  id: string;
  date: string;
  merchant: string;
  amount: number;
  category: string;
}

interface ReceiptItem {
  itemName: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  category: string | null;
  unit: string | null;
}

interface ParseBillRequest {
  fileUrl: string;
  bankName?: string;
  month?: string;
  year?: string;
}

/**
 * Cloud Function to parse credit card bills
 * Extracts transactions using Google Cloud Vision OCR + Claude AI
 */
export const parseBill = functions
    .runWith({
      timeoutSeconds: 300,
      memory: '1GB',
    })
    .https.onCall(async (data: ParseBillRequest, context) => {
      // 1. Authentication check
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be authenticated to parse bills'
        );
      }

      const {fileUrl, bankName, month, year} = data;
      const userId = context.auth.uid;

      console.log(`Parsing bill for user: ${userId}, bank: ${bankName}`);

      try {
        // 2. Extract text from bill using Google Cloud Vision
        console.log('Extracting text from bill...', {fileUrl});
        let extractedText: string;

        try {
          extractedText = await extractTextFromBill(fileUrl);
        } catch (visionError: any) {
          console.error('Vision API error:', visionError);
          throw new Error(`Vision API failed: ${visionError.message}`);
        }

        if (!extractedText || extractedText.trim().length < 50) {
          console.error('Text extraction failed:', {
            hasText: !!extractedText,
            length: extractedText?.length || 0,
          });
          throw new Error('No text found in bill or text too short');
        }

        console.log(`Extracted ${extractedText.length} characters`);

        // 3. Try rule-based parsing for known banks
        let transactions: Transaction[] = [];
        let parsedBy = 'rule';

        if (bankName) {
          console.log(`Attempting rule-based parsing for ${bankName}...`);
          transactions = parseKnownBank(extractedText, bankName);
        }

        // 4. Fallback to Claude AI if rule-based fails
        let regexPattern: GeneratedRegexPattern | null = null;
        if (transactions.length === 0) {
          console.log('Rule-based parsing failed. Using Claude AI...');
          const result = await parseWithClaude(extractedText, bankName);
          transactions = result.transactions;
          regexPattern = result.regexPattern;
          parsedBy = 'llm';
        }

        console.log(`Successfully parsed ${transactions.length} transactions`);

        // 5. Return structured response
        return {
          status: 'success',
          parsedBy,
          transactions,
          metadata: {
            bankName: bankName || 'Unknown',
            month: month || '',
            year: year || '',
          },
          regexPattern: regexPattern && regexPattern.confidence >= 70 ? regexPattern : null,
        };
      } catch (error: any) {
        console.error('Bill parsing error:', error);
        throw new functions.https.HttpsError(
            'internal',
            `Failed to parse bill: ${error.message}`
        );
      }
    });

/**
 * Download file from URL as Buffer
 */
async function downloadFileAsBuffer(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      const chunks: Buffer[] = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => resolve(Buffer.concat(chunks)));
      response.on('error', reject);
    });
  });
}

/**
 * Extract text from image/PDF using Google Cloud Vision
 * Supports both single images and multi-page PDFs
 */
async function extractTextFromBill(fileUrl: string): Promise<string> {
  const visionClient = new ImageAnnotatorClient();

  try {
    // Check if the file is a PDF based on URL extension
    const isPdf = fileUrl.toLowerCase().includes('.pdf');

    if (isPdf) {
      console.log('Detected PDF file, downloading and processing with base64 encoding');

      // Download PDF file as buffer
      const pdfBuffer = await downloadFileAsBuffer(fileUrl);
      console.log(`Downloaded PDF: ${pdfBuffer.length} bytes`);

      // Convert to base64
      const base64Pdf = pdfBuffer.toString('base64');

      // Use annotateFile for multi-page PDF
      const request: any = {
        requests: [
          {
            inputConfig: {
              content: base64Pdf,
              mimeType: 'application/pdf',
            },
            features: [{type: 'DOCUMENT_TEXT_DETECTION' as const}],
            // Process pages 1-4 (most bills are 4 pages or less)
            pages: [1, 2, 3, 4],
          },
        ],
      };

      console.log('Calling Vision API for PDF text extraction...');
      const [result]: any = await visionClient.batchAnnotateFiles(request);

      // Combine text from all pages
      let fullText = '';
      if (result.responses && result.responses.length > 0) {
        for (const response of result.responses) {
          if (response.responses) {
            for (const pageResponse of response.responses) {
              if (pageResponse.fullTextAnnotation) {
                fullText += pageResponse.fullTextAnnotation.text + '\n\n';
              }
            }
          }
        }
      }

      if (!fullText || fullText.trim().length === 0) {
        throw new Error('No text extracted from PDF');
      }

      console.log(`Extracted ${fullText.length} characters from ${result.responses[0].responses?.length || 0} pages`);
      return fullText;
    } else {
      // For images (JPG, PNG), use simple text detection
      console.log('Detected image file, using standard text detection');
      const [result] = await visionClient.textDetection(fileUrl);
      const detections = result.textAnnotations;

      if (!detections || detections.length === 0) {
        throw new Error('No text detected in image');
      }

      // First annotation contains full text
      return detections[0].description || '';
    }
  } catch (error: any) {
    console.error('Vision API error:', error);
    throw new Error(`OCR failed: ${error.message}`);
  }
}

/**
 * Parse bill using Claude AI with regex pattern generation
 */
async function parseWithClaude(
    text: string,
    bankName?: string
): Promise<{transactions: Transaction[]; regexPattern: GeneratedRegexPattern | null}> {
  const apiKey = functions.config().anthropic?.key;

  if (!apiKey) {
    console.error('Anthropic API key not configured');
    throw new Error('Claude API not configured. Set with: firebase functions:config:set anthropic.key="YOUR_KEY"');
  }

  console.log('Calling Claude API for bill parsing + regex generation...');

  const anthropic = new Anthropic({apiKey});

  try {
    const message = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 6144, // Increased for regex pattern
      messages: [
        {
          role: 'user',
          content: `You are a financial data extraction expert with regex pattern generation skills.

TASK 1: Extract ALL transactions from this Indian credit card bill
TASK 2: Generate a reusable regex pattern to parse similar bills from ${bankName || 'this bank'}

BILL TEXT:
${text.substring(0, 15000)}

Return JSON with this EXACT structure:
{
  "transactions": [
    {"date": "2025-01-10", "merchant": "Amazon", "amount": 1520.50, "category": "Shopping"},
    {"date": "2025-01-12", "merchant": "Swiggy", "amount": 450.00, "category": "Food"}
  ],
  "regexPattern": {
    "pattern": string,
    "description": string,
    "extractionMap": {
      "date": number,
      "merchant": number,
      "amount": number
    },
    "confidence": number,
    "categoryHint": null
  }
}

TRANSACTION EXTRACTION:
1. Extract ONLY actual purchase transactions (debits)
2. Skip: totals, balances, offers, rewards, interest, fees
3. Normalize merchant names (remove city, branch codes)
4. Infer category: Food, Travel, Shopping, Entertainment, Utilities, Healthcare, Education, Personal Care, Other
5. Use ISO date format (YYYY-MM-DD)

REGEX PATTERN GENERATION:
1. Analyze the transaction table structure in the bill
2. Create a regex to match transaction rows
3. Use capture groups for: date, merchant, amount
4. Pattern should work for future bills from ${bankName || 'this bank'}
5. extractionMap: field name → capture group number (1-indexed)
6. confidence: 0-100 (how likely this pattern works for future bills)
   - 90-100: Very standardized format
   - 70-89: Somewhat standardized
   - <70: Too variable (set pattern to null)
7. Only generate pattern if confidence >= 70%

Return ONLY valid JSON, no markdown.`,
        },
      ],
    });

    // Extract JSON from response
    const content = message.content[0];
    if (content.type === 'text') {
      const jsonMatch = content.text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const response = JSON.parse(jsonMatch[0]);

        // Parse transactions
        const transactions: Transaction[] = (response.transactions || []).map((t: any, index: number) => ({
          id: `${Date.now()}_${index}`,
          date: t.date || '2025-01-01',
          merchant: t.merchant || 'Unknown',
          amount: parseFloat(t.amount) || 0,
          category: t.category || 'Other',
        }));

        // Parse regex pattern
        const regexPattern: GeneratedRegexPattern | null = response.regexPattern || null;

        if (regexPattern && regexPattern.confidence >= 70) {
          console.log(`✅ Generated bill regex pattern (confidence: ${regexPattern.confidence}%)`);
        }

        return {transactions, regexPattern};
      }
    }

    throw new Error('Invalid response format from Claude');
  } catch (error: any) {
    console.error('Claude API error details:', {
      message: error.message,
      status: error.status,
      type: error.type,
      error: JSON.stringify(error, null, 2),
    });

    if (error.status === 404) {
      throw new Error(`Model not available. Check API key access to claude-3-haiku-20240307`);
    } else if (error.status === 401) {
      throw new Error(`Invalid Anthropic API key`);
    } else if (error.status === 429) {
      throw new Error(`Rate limit exceeded. Try again later`);
    }

    throw new Error(`LLM parsing failed: ${error.message}`);
  }
}

/**
 * Rule-based parsing for known banks
 */
function parseKnownBank(text: string, bankName: string): Transaction[] {
  const bank = bankName.toLowerCase();

  if (bank.includes('hdfc')) {
    return parseHDFC(text);
  } else if (bank.includes('icici')) {
    return parseICICI(text);
  } else if (bank.includes('sbi')) {
    return parseSBI(text);
  } else if (bank.includes('axis')) {
    return parseAxis(text);
  }

  return [];
}

/**
 * HDFC Bank statement parser
 */
function parseHDFC(text: string): Transaction[] {
  const transactions: Transaction[] = [];
  const lines = text.split('\n');

  // HDFC format: DD/MM/YYYY Description Amount
  // Example: 10/01/2025 AMAZON INDIA 1,520.50
  const pattern = /(\d{2}\/\d{2}\/\d{4})\s+(.+?)\s+(?:Rs\.?|₹)?\s*([\d,]+\.?\d*)/i;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const match = line.match(pattern);

    if (match) {
      const [, date, merchant, amountStr] = match;
      const amount = parseFloat(amountStr.replace(/,/g, ''));

      // Skip invalid entries
      if (amount <= 0) continue;
      if (merchant.toLowerCase().includes('total')) continue;
      if (merchant.toLowerCase().includes('balance')) continue;
      if (merchant.toLowerCase().includes('payment')) continue;

      transactions.push({
        id: `${Date.now()}_${i}`,
        date: formatDate(date, 'DD/MM/YYYY'),
        merchant: cleanMerchantName(merchant),
        amount,
        category: inferCategory(merchant),
      });
    }
  }

  return transactions;
}

/**
 * ICICI Bank statement parser
 */
function parseICICI(text: string): Transaction[] {
  const transactions: Transaction[] = [];
  const lines = text.split('\n');

  // ICICI format: DD-MM-YYYY Description Amount
  const pattern = /(\d{2}-\d{2}-\d{4})\s+(.+?)\s+(?:Rs\.?|₹)?\s*([\d,]+\.?\d*)/i;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const match = line.match(pattern);

    if (match) {
      const [, date, merchant, amountStr] = match;
      const amount = parseFloat(amountStr.replace(/,/g, ''));

      if (amount > 0 && !isExcludedTransaction(merchant)) {
        transactions.push({
          id: `${Date.now()}_${i}`,
          date: formatDate(date, 'DD-MM-YYYY'),
          merchant: cleanMerchantName(merchant),
          amount,
          category: inferCategory(merchant),
        });
      }
    }
  }

  return transactions;
}

/**
 * SBI Bank statement parser
 */
function parseSBI(text: string): Transaction[] {
  const transactions: Transaction[] = [];
  const lines = text.split('\n');

  // SBI format varies, try common patterns
  const pattern = /(\d{2}[\/\-]\d{2}[\/\-]\d{2,4})\s+(.+?)\s+(?:Rs\.?|₹)?\s*([\d,]+\.?\d*)/i;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const match = line.match(pattern);

    if (match) {
      const [, date, merchant, amountStr] = match;
      const amount = parseFloat(amountStr.replace(/,/g, ''));

      if (amount > 0 && !isExcludedTransaction(merchant)) {
        transactions.push({
          id: `${Date.now()}_${i}`,
          date: formatDate(date, 'DD/MM/YY'),
          merchant: cleanMerchantName(merchant),
          amount,
          category: inferCategory(merchant),
        });
      }
    }
  }

  return transactions;
}

/**
 * Axis Bank statement parser
 */
function parseAxis(text: string): Transaction[] {
  // Similar to HDFC format
  return parseHDFC(text);
}

/**
 * Helper: Format date to YYYY-MM-DD
 */
function formatDate(dateStr: string, format: string): string {
  try {
    let day: string; let month: string; let year: string;

    if (format === 'DD/MM/YYYY' || format === 'DD/MM/YY') {
      [day, month, year] = dateStr.split(/[\/\-]/);
    } else if (format === 'DD-MM-YYYY' || format === 'DD-MM-YY') {
      [day, month, year] = dateStr.split(/[\/\-]/);
    } else {
      return dateStr;
    }

    // Handle 2-digit year
    if (year.length === 2) {
      year = parseInt(year) > 50 ? `19${year}` : `20${year}`;
    }

    return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
  } catch {
    return '2025-01-01'; // Fallback date
  }
}

/**
 * Helper: Clean merchant name
 */
function cleanMerchantName(merchant: string): string {
  return merchant
      .replace(/\s+/g, ' ')
      .replace(/[A-Z]{2,}\s[A-Z]{2,}/g, '') // Remove location codes
      .replace(/\*+/g, '')
      .trim();
}

/**
 * Helper: Check if transaction should be excluded
 */
function isExcludedTransaction(merchant: string): boolean {
  const m = merchant.toLowerCase();
  const excludeKeywords = [
    'total',
    'balance',
    'payment',
    'credit limit',
    'minimum',
    'interest',
    'fee',
    'charge',
    'reward',
  ];

  return excludeKeywords.some((keyword) => m.includes(keyword));
}

/**
 * Helper: Infer category from merchant name
 */
function inferCategory(merchant: string): string {
  const m = merchant.toLowerCase();

  // Food & Dining
  if (m.match(/swiggy|zomato|restaurant|cafe|food|domino|pizza|burger|mcdonald|kfc|subway/)) {
    return 'Food';
  }

  // Travel & Transportation
  if (m.match(/uber|ola|rapido|irctc|makemytrip|goibibo|flight|hotel|petrol|diesel/)) {
    return 'Travel';
  }

  // Shopping & E-commerce
  if (m.match(/amazon|flipkart|myntra|ajio|nykaa|shopping|mall|store|retail/)) {
    return 'Shopping';
  }

  // Entertainment & Subscriptions
  if (m.match(/netflix|prime|hotstar|disney|spotify|bookmyshow|cinema|movie|pvr|inox/)) {
    return 'Entertainment';
  }

  // Utilities & Bills
  if (m.match(/electricity|water|gas|internet|broadband|mobile|recharge|phone|bill/)) {
    return 'Utilities';
  }

  // Healthcare
  if (m.match(/hospital|clinic|pharmacy|doctor|medical|medicine|apollo|fortis/)) {
    return 'Healthcare';
  }

  // Education
  if (m.match(/school|college|university|course|udemy|coursera|education|tuition/)) {
    return 'Education';
  }

  // Personal Care
  if (m.match(/salon|spa|gym|fitness|yoga|grooming/)) {
    return 'Personal Care';
  }

  return 'Other';
}

// ============================================================================
// BUG REPORTING - AUTOMATIC GITHUB SYNC
// ============================================================================

interface BugReport {
  title: string;
  description: string;
  stepsToReproduce?: string;
  priority: 'Low' | 'Medium' | 'High' | 'Critical';
  platform: 'Android' | 'iOS' | 'Web' | 'All';
  status: 'pending' | 'synced' | 'closed';
  reportedBy: string;
  reportedByName: string;
  reportedByEmail: string;
  createdAt: admin.firestore.Timestamp;
  githubIssueNumber?: number;
  syncedAt?: admin.firestore.Timestamp;
}

/**
 * Cloud Function: Automatically sync bug reports to GitHub Issues
 *
 * Triggers when a new document is created in the bugReports collection
 * Creates a GitHub issue and updates the Firestore document with the issue number
 */
export const syncBugToGitHub = functions.firestore
    .document('bugReports/{reportId}')
    .onCreate(async (snap, context) => {
      const bugData = snap.data() as BugReport;
      const reportId = context.params.reportId;

      console.log(`New bug report created: ${reportId}`);
      console.log('Bug details:', {
        title: bugData.title,
        priority: bugData.priority,
        platform: bugData.platform,
        reportedBy: bugData.reportedByEmail,
      });

      try {
        // 1. Get GitHub token from Firebase config
        const githubToken = functions.config().github?.token;

        if (!githubToken) {
          console.error('GitHub token not configured!');
          console.error('Set it with: firebase functions:config:set github.token="YOUR_GITHUB_PAT"');
          throw new Error('GitHub token not configured');
        }

        // 2. Format the issue body
        const issueBody = formatGitHubIssueBody(bugData);

        // 3. Determine labels based on priority and platform
        const labels = getLabelsForBug(bugData);

        // 4. Create GitHub issue using REST API directly
        console.log('Creating GitHub issue...');

        const issue = await createGitHubIssue({
          token: githubToken,
          owner: 'blrtechpub-droid',
          repo: 'spendpal',
          title: `[BUG] [${bugData.platform}] ${bugData.title}`,
          body: issueBody,
          labels: labels,
        });

        console.log(`GitHub issue created: #${issue.number}`);
        console.log(`Issue URL: ${issue.html_url}`);

        // 5. Update Firestore document with GitHub issue number
        await snap.ref.update({
          status: 'synced',
          githubIssueNumber: issue.number,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Updated Firestore document ${reportId} with issue #${issue.number}`);

        return {
          success: true,
          issueNumber: issue.number,
          issueUrl: issue.html_url,
        };
      } catch (error: any) {
        console.error('Error syncing bug to GitHub:', error);

        // Log detailed error information
        if (error.status) {
          console.error('GitHub API Error:', {
            status: error.status,
            message: error.message,
            documentation: error.documentation_url,
          });
        }

        // Don't update Firestore on error - leave status as 'pending'
        // This allows manual retry or debugging

        throw new functions.https.HttpsError(
            'internal',
            `Failed to create GitHub issue: ${error.message}`
        );
      }
    });

/**
 * Format bug report data into GitHub issue body
 */
function formatGitHubIssueBody(bug: BugReport): string {
  const createdDate = bug.createdAt.toDate().toLocaleString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    timeZoneName: 'short',
  });

  let body = `## Description\n\n${bug.description}\n\n`;

  if (bug.stepsToReproduce && bug.stepsToReproduce.trim()) {
    body += `## Steps to Reproduce\n\n${bug.stepsToReproduce}\n\n`;
  } else {
    body += `## Steps to Reproduce\n\n_Not provided_\n\n`;
  }

  body += `## Platform\n\n${bug.platform}\n\n`;
  body += `## Priority\n\n${bug.priority}\n\n`;

  body += `## Reported By\n\n`;
  body += `- **Name:** ${bug.reportedByName}\n`;
  body += `- **Email:** ${bug.reportedByEmail}\n`;
  body += `- **Date:** ${createdDate}\n\n`;

  body += `---\n`;
  body += `*This issue was automatically created from an in-app bug report*\n`;

  return body;
}

/**
 * Get appropriate GitHub labels for bug report
 */
function getLabelsForBug(bug: BugReport): string[] {
  const labels: string[] = ['bug', 'from-app'];

  // Add priority label
  const priorityLabel = `priority:${bug.priority.toLowerCase()}`;
  labels.push(priorityLabel);

  // Add platform label
  const platform = bug.platform.toLowerCase();
  if (platform !== 'all') {
    labels.push(platform);
  } else {
    // If 'All' platforms, add all platform labels
    labels.push('android', 'ios', 'web');
  }

  return labels;
}

/**
 * Create GitHub issue using REST API directly
 */
async function createGitHubIssue(options: {
  token: string;
  owner: string;
  repo: string;
  title: string;
  body: string;
  labels: string[];
}): Promise<{number: number; html_url: string}> {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      title: options.title,
      body: options.body,
      labels: options.labels,
    });

    const requestOptions = {
      hostname: 'api.github.com',
      port: 443,
      path: `/repos/${options.owner}/${options.repo}/issues`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
        'Authorization': `Bearer ${options.token}`,
        'User-Agent': 'SpendPal-Bug-Reporter',
        'Accept': 'application/vnd.github.v3+json',
      },
    };

    const req = https.request(requestOptions, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 201) {
          const issue = JSON.parse(responseData);
          resolve({
            number: issue.number,
            html_url: issue.html_url,
          });
        } else {
          reject(new Error(
              `GitHub API error: ${res.statusCode} - ${responseData}`
          ));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

// ============================================================================
// RECEIPT PARSING WITH OCR + AI + SELF-LEARNING
// ============================================================================

interface ParseReceiptRequest {
  fileUrl: string;
  merchant?: string;
}

/**
 * Cloud Function to parse grocery/retail receipts with item-level extraction
 * Extracts individual items, prices, quantities using Google Cloud Vision OCR + Claude AI
 * Generates regex patterns for future receipts from same merchant (self-learning)
 */
export const parseReceipt = functions
    .runWith({
      timeoutSeconds: 180,
      memory: '1GB',
    })
    .https.onCall(async (data: ParseReceiptRequest, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be authenticated to parse receipts'
        );
      }

      const {fileUrl, merchant} = data;
      const userId = context.auth.uid;

      console.log(`Parsing receipt for user: ${userId}, merchant: ${merchant}`);

      try {
        // 1. Extract text using OCR
        console.log('Extracting text from receipt...');
        const extractedText = await extractTextFromBill(fileUrl);

        if (!extractedText || extractedText.trim().length < 30) {
          throw new Error('No text found in receipt or text too short');
        }

        console.log(`Extracted ${extractedText.length} characters from receipt`);

        // 2. Parse receipt with AI
        console.log('Parsing receipt with Claude AI...');
        const result = await parseReceiptWithClaude(extractedText, merchant);

        console.log(`Successfully parsed receipt: ${result.items.length} items`);

        // 3. Return structured response
        return {
          status: 'success',
          parsedBy: 'ai',
          receipt: {
            merchant: result.merchant,
            date: result.date,
            totalAmount: result.totalAmount,
            taxAmount: result.taxAmount,
            discountAmount: result.discountAmount,
            receiptNumber: result.receiptNumber,
            paymentMethod: result.paymentMethod,
          },
          items: result.items,
          regexPattern: result.regexPattern && result.regexPattern.confidence >= 70 ?
            result.regexPattern : null,
        };
      } catch (error: any) {
        console.error('Receipt parsing error:', error);
        throw new functions.https.HttpsError(
            'internal',
            `Failed to parse receipt: ${error.message}`
        );
      }
    });

/**
 * Parse receipt with Claude AI (item-level extraction)
 */
async function parseReceiptWithClaude(
    text: string,
    merchant?: string
): Promise<{
  merchant: string;
  date: string;
  totalAmount: number;
  taxAmount: number | null;
  discountAmount: number | null;
  receiptNumber: string | null;
  paymentMethod: string | null;
  items: ReceiptItem[];
  regexPattern: GeneratedRegexPattern | null;
}> {
  const apiKey = functions.config().anthropic?.key;

  if (!apiKey) {
    throw new Error('Claude API not configured');
  }

  console.log('Calling Claude API for receipt parsing + regex generation...');

  const anthropic = new Anthropic({apiKey});

  try {
    const message = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 8192,
      messages: [
        {
          role: 'user',
          content: `You are a receipt parsing expert with regex pattern generation skills.

TASK 1: Extract ALL items and metadata from this receipt
TASK 2: Generate a reusable regex pattern to parse similar receipts from ${merchant || 'this merchant'}

RECEIPT TEXT:
${text.substring(0, 20000)}

Return JSON with this EXACT structure:
{
  "receipt": {
    "merchant": string,
    "date": string (YYYY-MM-DD),
    "totalAmount": number,
    "taxAmount": number | null,
    "discountAmount": number | null,
    "receiptNumber": string | null,
    "paymentMethod": string | null
  },
  "items": [
    {
      "itemName": string,
      "quantity": number,
      "unitPrice": number,
      "totalPrice": number,
      "category": string | null,
      "unit": string | null
    }
  ],
  "regexPattern": {
    "pattern": string,
    "description": string,
    "extractionMap": {
      "itemName": number,
      "quantity": number,
      "unitPrice": number,
      "totalPrice": number
    },
    "confidence": number,
    "categoryHint": null
  }
}

ITEM EXTRACTION:
1. Extract EVERY item purchased (not totals, subtotals, tax)
2. itemName: Normalize product names
3. quantity: Number of units (default 1 if not shown)
4. unitPrice: Price per unit
5. totalPrice: Total for this item (quantity × unitPrice)
6. category: Auto-infer from item name (Groceries, Food, Household, Personal Care, Other)
7. unit: kg, ltr, pcs, box, etc. (null if not applicable)

METADATA EXTRACTION:
1. merchant: Store name from receipt header
2. date: Purchase date in YYYY-MM-DD
3. totalAmount: Grand total paid
4. taxAmount: Tax/GST amount if shown
5. discountAmount: Total discounts if any
6. receiptNumber: Receipt/bill number if present
7. paymentMethod: Cash, Card, UPI, etc. (null if not shown)

REGEX PATTERN GENERATION:
1. Analyze the item list structure in the receipt
2. Create a regex to match item rows (with quantity, price)
3. Use capture groups for: itemName, quantity, unitPrice, totalPrice
4. Pattern should work for future receipts from ${merchant || 'this merchant'}
5. extractionMap: field name → capture group number
6. confidence: 0-100
   - 90-100: Very standardized receipt format
   - 70-89: Somewhat standardized
   - <70: Too variable (set pattern to null)
7. Only generate pattern if confidence >= 70%

Return ONLY valid JSON, no markdown.`,
        },
      ],
    });

    const content = message.content[0];
    if (content.type === 'text') {
      const jsonMatch = content.text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const response = JSON.parse(jsonMatch[0]);

        const receiptData = response.receipt;
        const items: ReceiptItem[] = response.items || [];
        const regexPattern: GeneratedRegexPattern | null = response.regexPattern || null;

        if (regexPattern && regexPattern.confidence >= 70) {
          console.log(`✅ Generated receipt regex pattern (confidence: ${regexPattern.confidence}%)`);
        }

        return {
          merchant: receiptData.merchant || merchant || 'Unknown',
          date: receiptData.date || new Date().toISOString().split('T')[0],
          totalAmount: parseFloat(receiptData.totalAmount) || 0,
          taxAmount: receiptData.taxAmount ? parseFloat(receiptData.taxAmount) : null,
          discountAmount: receiptData.discountAmount ? parseFloat(receiptData.discountAmount) : null,
          receiptNumber: receiptData.receiptNumber || null,
          paymentMethod: receiptData.paymentMethod || null,
          items,
          regexPattern,
        };
      }
    }

    throw new Error('Invalid response format from Claude');
  } catch (error: any) {
    console.error('Claude API error:', error);
    throw new Error(`Receipt parsing failed: ${error.message}`);
  }
}

// ============================================================================
// SMS EXPENSE PARSING WITH AI (CLAUDE OR GEMINI)
// ============================================================================

interface SmsExpenseData {
  amount: number;
  merchant: string;
  category: 'Food' | 'Shopping' | 'Travel' | 'Entertainment' | 'Groceries' | 'Utilities' | 'Healthcare' | 'Other';
  transactionId: string | null;
  accountInfo: string | null;
  date: string; // ISO date string
  isDebit: boolean;
}

interface GeneratedRegexPattern {
  pattern: string;
  description: string;
  extractionMap: {[key: string]: number}; // field name -> capture group number
  confidence: number; // 0-100
  categoryHint: string | null;
}

interface ParseSmsRequest {
  smsText: string;
  sender: string;
  date: string;
}

// AI Provider Selection
// Change this to switch between AI providers: 'claude' or 'gemini'
// Can also be set via Firebase config: firebase functions:config:set ai.provider="gemini"
const AI_PROVIDER = functions.config().ai?.provider || 'claude';

/**
 * Cloud Function: Parse SMS transaction using AI (Claude or Gemini)
 *
 * AI Provider: Configurable via AI_PROVIDER constant or Firebase config
 * - Claude 3.5 Haiku: ~₹0.13/SMS (high accuracy, proven)
 * - Gemini 2.0 Flash: ~₹0.011/SMS (cheapest, fast)
 *
 * To switch providers:
 * 1. Via code: Change AI_PROVIDER constant above
 * 2. Via Firebase config: firebase functions:config:set ai.provider="gemini"
 * 3. Redeploy: firebase deploy --only functions:parseSmsWithAI
 *
 * Usage:
 *   const callable = FirebaseFunctions.instance.httpsCallable('parseSmsWithAI');
 *   final result = await callable.call({'smsText': '...', 'sender': 'HDFCBK', 'date': '2025-11-02'});
 */
/**
 * Cloud Function: Parse email screenshot to extract email patterns
 * Uses Vision API + Gemini to analyze transaction email screenshots
 * Generates Gmail filter queries and regex parsing patterns
 */
interface ParseEmailScreenshotRequest {
  imageBase64: string;
  userId: string;
}

interface EmailPatternResponse {
  bankDomain: string;
  bankName: string;
  patterns: {
    amount: {
      regex: string;
      captureGroup: number;
      type: 'debit' | 'credit' | 'upi';
    };
    merchant?: {
      regex: string;
      captureGroup: number;
    };
    date?: {
      regex: string;
      format: string;
    };
  };
  gmailFilter: {
    from: string;
    keywords: string[];
  };
  confidence: number;
}

export const parseEmailScreenshot = functions
    .runWith({
      timeoutSeconds: 120,
      memory: '512MB',
    })
    .https.onCall(async (data: ParseEmailScreenshotRequest, context) => {
      // 1. Authentication check
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be authenticated to parse email screenshots'
        );
      }

      const {imageBase64, userId} = data;

      if (context.auth.uid !== userId) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'User ID mismatch'
        );
      }

      console.log(`Parsing email screenshot for user: ${userId}`);

      try {
        // 1.5. Check cache first (based on image hash)
        const crypto = require('crypto');
        const imageHash = crypto.createHash('sha256').update(imageBase64).digest('hex');
        const cacheKey = `email_screenshot_cache_${imageHash}`;

        // Check if we've already processed this exact image
        const cacheRef = admin.firestore().collection('cache').doc(cacheKey);
        const cacheDoc = await cacheRef.get();

        if (cacheDoc.exists) {
          const cachedData = cacheDoc.data();
          console.log('✅ Cache HIT! Returning cached result');
          console.log('Cached pattern:', JSON.stringify(cachedData?.pattern));

          if (!cachedData?.pattern) {
            console.error('❌ Cache has no pattern data! Clearing cache and reprocessing...');
            await cacheRef.delete();
            // Continue to process the image
          } else {
            // Check if pattern already exists in user's collection
            const existingPatterns = await admin.firestore()
                .collection('users').doc(userId)
                .collection('customEmailPatterns')
                .where('bankDomain', '==', cachedData.pattern.bankDomain)
                .limit(1)
                .get();

            if (existingPatterns.empty) {
              // Save cached pattern to Firestore if it doesn't exist
              console.log('Saving cached pattern to Firestore...');
              await admin.firestore()
                  .collection('users').doc(userId)
                  .collection('customEmailPatterns')
                  .add({
                    ...cachedData.pattern,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    source: 'vision_api',
                    active: false, // User must review and activate
                    verified: false,
                    priority: 10,
                    usageCount: 0,
                    successCount: 0,
                    failureCount: 0,
                    tags: ['user-generated', 'vision-api', 'from-cache'],
                  });
              console.log('✅ Cached pattern saved to Firestore');
            } else {
              console.log('Pattern already exists in Firestore, skipping save');
            }

            return {
              success: true,
              pattern: cachedData.pattern,
              message: 'Email pattern retrieved from cache (testing mode). Please review and activate.',
              cached: true,
            };
          }
        }

        console.log('Cache MISS. Processing image...');

        // 2. Extract text from screenshot using Vision API
        console.log('Extracting text from email screenshot...');
        const extractedText = await extractTextFromEmailScreenshot(imageBase64);

        if (!extractedText || extractedText.trim().length < 30) {
          throw new Error('No text found in screenshot or text too short');
        }

        console.log(`Extracted ${extractedText.length} characters from screenshot`);

        // 3. Use Claude to analyze and generate patterns
        console.log('Analyzing email with Claude AI...');
        const emailPattern = await generateEmailPatternWithClaude(extractedText);

        console.log(`Successfully generated pattern for ${emailPattern.bankName}`);

        // 4. Save to user's custom patterns collection
        await admin.firestore()
            .collection('users').doc(userId)
            .collection('customEmailPatterns')
            .add({
              ...emailPattern,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              source: 'vision_api',
              active: false, // User must review and activate
              verified: false,
              priority: 10,
              usageCount: 0,
              successCount: 0,
              failureCount: 0,
              tags: ['user-generated', 'vision-api'],
            });

        console.log('✅ Email pattern saved to Firestore');

        // 5. Save to cache for faster testing (24 hour TTL)
        await cacheRef.set({
          pattern: emailPattern,
          extractedText,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        });
        console.log('✅ Result cached for future requests');

        return {
          success: true,
          pattern: emailPattern,
          message: 'Email pattern generated successfully. Please review and activate.',
        };
      } catch (error: any) {
        console.error('Email screenshot parsing error:', error);

        throw new functions.https.HttpsError(
            'internal',
            `Failed to parse email screenshot: ${error.message}`
        );
      }
    });

/**
 * Extract text from email screenshot using Vision API
 */
async function extractTextFromEmailScreenshot(imageBase64: string): Promise<string> {
  const visionClient = new ImageAnnotatorClient();

  try {
    const [result] = await visionClient.textDetection({
      image: {content: imageBase64},
    });

    const detections = result.textAnnotations;

    if (!detections || detections.length === 0) {
      throw new Error('No text detected in email screenshot');
    }

    // First annotation contains full text
    const fullText = detections[0].description || '';
    return fullText;
  } catch (error: any) {
    console.error('Vision API error:', error);
    throw new Error(`OCR failed: ${error.message}`);
  }
}

/**
 * Generate email parsing pattern using Claude AI
 */
async function generateEmailPatternWithClaude(emailText: string): Promise<EmailPatternResponse> {
  const anthropicKey = functions.config().anthropic?.key;

  if (!anthropicKey) {
    console.error('Anthropic API key not configured!');
    throw new Error('Claude API not configured. Set with: firebase functions:config:set anthropic.key="YOUR_KEY"');
  }

  const anthropic = new Anthropic({apiKey: anthropicKey});

  const prompt = `You are an expert at analyzing bank transaction emails and creating parsing patterns.

TASK: Analyze this email and generate a structured parsing pattern.

EMAIL TEXT:
${emailText.substring(0, 10000)}

Return JSON with this EXACT structure:
{
  "bankDomain": string (e.g., "hdfcbank.com"),
  "bankName": string (e.g., "HDFC Bank"),
  "patterns": {
    "amount": {
      "regex": string (regex pattern to extract transaction amount),
      "captureGroup": number (which group has the amount),
      "type": "debit" | "credit" | "upi"
    },
    "merchant": {
      "regex": string (regex to extract merchant name),
      "captureGroup": number
    },
    "date": {
      "regex": string (regex to extract transaction date),
      "format": string (e.g., "DD-MM-YYYY")
    }
  },
  "gmailFilter": {
    "from": string (sender domain for Gmail filter),
    "keywords": string[] (keywords to identify transaction emails)
  },
  "confidence": number (0-100, how reliable is this pattern)
}

EXTRACTION RULES:
1. bankDomain: Extract sender email domain (e.g., "alerts@hdfcbank.com" → "hdfcbank.com")
2. bankName: Identify the bank name from the email
3. amount regex: Pattern to extract amount with Rs/₹ symbols
   - Should handle: "Rs 1,234.56", "INR 500", "₹ 1234"
   - Use capture groups to get the numeric value
4. merchant regex: Pattern to extract merchant/vendor name
   - Common patterns: "at MERCHANT", "to MERCHANT", "merchant: MERCHANT"
5. date regex: Pattern to extract transaction date
   - Common formats: DD-MM-YYYY, DD/MM/YYYY, DD-MM-YY
6. Gmail filter: Create a search query to find similar emails
   - from: Sender domain
   - keywords: Transaction indicators like "debited", "credited", "spent", "received"
7. confidence: Rate 0-100 based on:
   - 90-100: Very clear, standardized format
   - 70-89: Good structure, some variations
   - 50-69: Moderate confidence
   - <50: Too ambiguous

IMPORTANT:
- Use proper regex escaping (\\. for dots, \\s for spaces)
- captureGroup is 1-indexed (1 = first capture group)
- Make patterns flexible enough for variations
- Return ONLY valid JSON`;

  console.log('Calling Claude API for email pattern extraction...');

  const message = await anthropic.messages.create({
    model: 'claude-3-haiku-20240307',
    max_tokens: 2048,
    messages: [{
      role: 'user',
      content: prompt,
    }],
  });

  console.log('Claude response received');

  // Extract JSON from response
  const content = message.content[0];
  if (content.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }

  // Try to extract JSON from the response - look for properly balanced braces
  let jsonText = content.text.trim();

  // If response starts with explanation text, try to find JSON
  const firstBraceIndex = jsonText.indexOf('{');
  if (firstBraceIndex === -1) {
    console.error('No JSON found in Claude response:', content.text.substring(0, 500));
    throw new Error('Failed to extract JSON from Claude response');
  }

  // Find matching closing brace
  let braceCount = 0;
  let jsonEndIndex = -1;
  for (let i = firstBraceIndex; i < jsonText.length; i++) {
    if (jsonText[i] === '{') braceCount++;
    if (jsonText[i] === '}') {
      braceCount--;
      if (braceCount === 0) {
        jsonEndIndex = i + 1;
        break;
      }
    }
  }

  if (jsonEndIndex === -1) {
    console.error('Unbalanced braces in Claude response:', content.text.substring(0, 500));
    throw new Error('Malformed JSON in Claude response');
  }

  const jsonString = jsonText.substring(firstBraceIndex, jsonEndIndex);
  console.log('Extracted JSON substring (first 200 chars):', jsonString.substring(0, 200));

  const pattern: EmailPatternResponse = JSON.parse(jsonString);

  // Validate response
  if (!pattern.bankDomain || !pattern.patterns || !pattern.gmailFilter) {
    throw new Error('Invalid pattern generated by Claude');
  }

  return pattern;
}

export const parseSmsWithAI = functions
    .runWith({
      timeoutSeconds: 30,
      memory: '256MB',
    })
    .https.onCall(async (data: ParseSmsRequest, context) => {
      // 1. Authentication check
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be authenticated to parse SMS'
        );
      }

      const {smsText, sender, date} = data;
      const userId = context.auth.uid;

      console.log(`Parsing SMS for user: ${userId}, sender: ${sender}, provider: ${AI_PROVIDER}`);

      // 2. Validate input
      if (!smsText || smsText.trim().length < 10) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'SMS text is too short or empty'
        );
      }

      try {
        let parsedData: SmsExpenseData;
        let aiModel: string;
        let regexPattern: GeneratedRegexPattern | null = null;

        // 3. Route to appropriate AI provider
        if (AI_PROVIDER === 'gemini') {
          const result = await parseSmsWithGemini(smsText, sender, date);
          parsedData = result.data;
          aiModel = result.model;
          regexPattern = result.regexPattern;
        } else {
          // Default to Claude
          const result = await parseSmsWithClaude(smsText, sender, date);
          parsedData = result.data;
          aiModel = result.model;
          regexPattern = result.regexPattern;
        }

        // 4. Validate parsed data
        if (!parsedData.amount || parsedData.amount <= 0) {
          throw new Error('Invalid amount extracted');
        }

        if (!parsedData.merchant || parsedData.merchant.trim().length === 0) {
          throw new Error('No merchant name extracted');
        }

        // 5. Return success response with regex pattern
        console.log(`Successfully parsed SMS: ${parsedData.merchant} - ₹${parsedData.amount}`);
        if (regexPattern && regexPattern.confidence >= 60) {
          console.log(`🎓 Generated reusable regex pattern (confidence: ${regexPattern.confidence}%)`);
        }

        return {
          success: true,
          data: {
            amount: parsedData.amount,
            merchant: parsedData.merchant.trim(),
            category: parsedData.category || 'Other',
            transactionId: parsedData.transactionId || null,
            accountInfo: parsedData.accountInfo || null,
            date: parsedData.date || date,
            isDebit: parsedData.isDebit !== false, // Default to true (expense)
          },
          metadata: {
            sender: sender,
            parsedBy: AI_PROVIDER,
            model: aiModel,
          },
          regexPattern: regexPattern && regexPattern.confidence >= 60 ? regexPattern : null,
        };
      } catch (error: any) {
        console.error(`Error parsing SMS with ${AI_PROVIDER}:`, error);

        // Log detailed error for debugging
        if (error.message) {
          console.error('Error message:', error.message);
        }
        if (error.status) {
          console.error('Error status:', error.status);
        }

        throw new functions.https.HttpsError(
            'internal',
            `Failed to parse SMS: ${error.message}`
        );
      }
    });

/**
 * Parse multiple SMS messages in bulk (10x faster!)
 *
 * Processes 10-20 SMS in a single AI call instead of individual calls
 * HUGE speed improvement: 2-3s total vs 40-60s sequential
 */
export const parseBulkSmsWithAI = functions
    .runWith({
      timeoutSeconds: 180, // Extended timeout for email processing (emails are much longer than SMS)
      memory: '1GB', // Increased memory for processing large email batches
    })
    .https.onCall(async (data: {smsMessages: any[]}, context) => {
      // 1. Authentication check
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be authenticated to parse SMS'
        );
      }

      const {smsMessages} = data;
      const userId = context.auth.uid;

      console.log(`🚀 Bulk parsing ${smsMessages.length} SMS for user: ${userId}`);

      // 2. Validate input
      if (!smsMessages || !Array.isArray(smsMessages) || smsMessages.length === 0) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'smsMessages must be a non-empty array'
        );
      }

      if (smsMessages.length > 20) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Cannot process more than 20 SMS at once'
        );
      }

      try {
        let results: any[];

        // 3. Route to appropriate AI provider
        if (AI_PROVIDER === 'gemini') {
          results = await parseBulkSmsWithGemini(smsMessages);
        } else {
          results = await parseBulkSmsWithClaude(smsMessages);
        }

        console.log(`✅ Bulk parsing complete: ${results.length}/${smsMessages.length} processed`);

        return {
          success: true,
          results: results,
          metadata: {
            totalProcessed: results.length,
            provider: AI_PROVIDER,
          },
        };
      } catch (error: any) {
        console.error(`Error in bulk SMS parsing with ${AI_PROVIDER}:`, error);

        throw new functions.https.HttpsError(
            'internal',
            `Failed to parse SMS batch: ${error.message}`
        );
      }
    });

/**
 * Parse SMS using Claude AI and generate regex pattern
 */
async function parseSmsWithClaude(
    smsText: string,
    sender: string,
    date: string
): Promise<{data: SmsExpenseData; model: string; regexPattern: GeneratedRegexPattern | null}> {
  // Get Claude API key from Firebase config
  const apiKey = functions.config().anthropic?.key;

  if (!apiKey) {
    console.error('Claude API key not configured!');
    console.error('Set it with: firebase functions:config:set anthropic.key="YOUR_ANTHROPIC_API_KEY"');
    throw new Error('Claude API not configured');
  }

  // Initialize Claude AI
  const anthropic = new Anthropic({apiKey});

  // Create prompt (now includes regex pattern generation)
  const prompt = createPromptWithRegex(smsText, sender, date);

  console.log('Calling Claude API for SMS parsing + regex generation...');
  const message = await anthropic.messages.create({
    model: 'claude-3-5-haiku-20241022',
    max_tokens: 2048, // Increased for regex pattern
    temperature: 0.1,
    messages: [{role: 'user', content: prompt}],
  });

  // Parse response
  const content = message.content[0];
  if (content.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }

  console.log('Claude response received:', content.text.substring(0, 200));

  // Extract JSON (Claude sometimes wraps it in markdown)
  const jsonMatch = content.text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    console.error('No JSON found in Claude response:', content.text);
    throw new Error('AI returned invalid format');
  }

  const response = JSON.parse(jsonMatch[0]);

  // Separate transaction data from regex pattern
  const parsedData: SmsExpenseData = {
    amount: response.transaction.amount,
    merchant: response.transaction.merchant,
    category: response.transaction.category,
    transactionId: response.transaction.transactionId,
    accountInfo: response.transaction.accountInfo,
    date: response.transaction.date,
    isDebit: response.transaction.isDebit,
  };

  const regexPattern: GeneratedRegexPattern | null = response.regexPattern || null;

  if (regexPattern) {
    console.log(`✅ Generated regex pattern with ${regexPattern.confidence}% confidence`);
  }

  return {
    data: parsedData,
    model: 'claude-3-5-haiku-20241022',
    regexPattern: regexPattern,
  };
}

/**
 * Parse SMS using Gemini AI and generate regex pattern
 */
async function parseSmsWithGemini(
    smsText: string,
    sender: string,
    date: string
): Promise<{data: SmsExpenseData; model: string; regexPattern: GeneratedRegexPattern | null}> {
  const geminiKey = functions.config().gemini?.key;

  if (!geminiKey) {
    console.error('Gemini API key not configured!');
    console.error('Set it with: firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"');
    throw new Error('Gemini API not configured. Install @google/generative-ai and configure API key.');
  }

  // Import Gemini SDK dynamically to avoid errors when not used
  const {GoogleGenerativeAI} = await import('@google/generative-ai');

  const genAI = new GoogleGenerativeAI(geminiKey);
  // COST OPTIMIZATION: Using gemini-1.5-flash instead of gemini-2.0-flash-exp
  // Savings: 75% cheaper (₹0.075 vs ₹0.30 per 1M tokens)
  // Still maintains 95%+ accuracy for SMS parsing
  const model = genAI.getGenerativeModel({
    model: 'gemini-1.5-flash',
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.1,
    },
  });

  // Use enhanced prompt with regex generation
  const prompt = createPromptWithRegex(smsText, sender, date);

  console.log('Calling Gemini API for SMS parsing + regex generation...');
  const result = await model.generateContent(prompt);
  const response = result.response;
  const text = response.text();

  console.log('Gemini response received:', text.substring(0, 200));

  const jsonResponse = JSON.parse(text);

  // Separate transaction data from regex pattern
  const parsedData: SmsExpenseData = {
    amount: jsonResponse.transaction.amount,
    merchant: jsonResponse.transaction.merchant,
    category: jsonResponse.transaction.category,
    transactionId: jsonResponse.transaction.transactionId,
    accountInfo: jsonResponse.transaction.accountInfo,
    date: jsonResponse.transaction.date,
    isDebit: jsonResponse.transaction.isDebit,
  };

  const regexPattern: GeneratedRegexPattern | null = jsonResponse.regexPattern || null;

  if (regexPattern) {
    console.log(`✅ Generated regex pattern with ${regexPattern.confidence}% confidence`);
  }

  return {
    data: parsedData,
    model: 'gemini-1.5-flash', // Updated to cheaper model
    regexPattern: regexPattern,
  };
}

/**
 * Create enhanced prompt that includes regex pattern generation
 * This enables self-learning: AI generates a pattern that can parse similar SMS in the future
 */
function createPromptWithRegex(smsText: string, sender: string, date: string): string {
  return `You are a financial data extraction expert with regex pattern generation skills.

TASK 1: Extract transaction details from this bank SMS
TASK 2: Generate a reusable regex pattern for similar SMS from this sender

SMS Text: "${smsText}"
SMS Sender: "${sender}"
SMS Date: "${date}"

Return JSON with this EXACT structure:
{
  "transaction": {
    "amount": number,
    "merchant": string,
    "category": string,
    "transactionId": string | null,
    "accountInfo": string | null,
    "date": string,
    "isDebit": boolean
  },
  "regexPattern": {
    "pattern": string,
    "description": string,
    "extractionMap": {
      "amount": number,
      "merchant": number,
      "transactionId": number,
      "accountInfo": number
    },
    "confidence": number,
    "categoryHint": string | null
  }
}

TRANSACTION EXTRACTION RULES:
1. amount: Positive number (remove ₹, Rs, commas)
2. merchant: Normalized name (remove city, branch codes)
3. category: One of: Food, Shopping, Travel, Entertainment, Groceries, Utilities, Healthcare, Other
4. transactionId: Transaction/reference ID if present
5. accountInfo: Last 4 digits of card/account (like XX1234)
6. date: YYYY-MM-DD format
7. isDebit: true if spent, false if received

REGEX PATTERN GENERATION RULES:
1. pattern: Create a regex that matches THIS specific SMS format from ${sender}
2. Use capture groups () for: amount, merchant, transactionId, accountInfo
3. Make pattern flexible but specific to ${sender}'s format
4. Handle variations in amounts, merchant names, dates
5. extractionMap: Map field names to capture group numbers (1-indexed)
6. confidence: 0-100 (how confident the pattern will work for future SMS from ${sender})
   - 90-100: Very standardized format, high confidence
   - 70-89: Somewhat standardized, good confidence
   - 50-69: Variable format, moderate confidence
   - <50: Too variable, low confidence (set pattern to null if <60)
7. description: Brief explanation of what the pattern matches
8. categoryHint: Suggested category if pattern implies specific type (e.g., "Travel" for flight bookings)

EXAMPLE for "Spent Rs.500 at AMAZON on XX1234. Ref: TXN123456":
{
  "transaction": {
    "amount": 500,
    "merchant": "Amazon",
    "category": "Shopping",
    "transactionId": "TXN123456",
    "accountInfo": "XX1234",
    "date": "${date}",
    "isDebit": true
  },
  "regexPattern": {
    "pattern": "Spent Rs\\\\.([0-9,]+(?:\\\\.[0-9]{2})?) at ([A-Z0-9\\\\s]+) on (XX[0-9]{4})\\\\. Ref: ([A-Z0-9]+)",
    "description": "Matches debit transactions with amount, merchant, account info, and reference number",
    "extractionMap": {
      "amount": 1,
      "merchant": 2,
      "accountInfo": 3,
      "transactionId": 4
    },
    "confidence": 95,
    "categoryHint": null
  }
}

IMPORTANT:
- If SMS format is too variable or unstructured, set regexPattern to null
- Only generate pattern if confidence >= 60%
- Escape special regex characters properly
- Test mentally: will this pattern match similar future SMS from ${sender}?
- Return ONLY valid JSON, no markdown or extra text`;
}

/**
 * Parse multiple SMS with Gemini in bulk (10x faster!)
 */
async function parseBulkSmsWithGemini(smsMessages: any[]): Promise<any[]> {
  const geminiKey = functions.config().gemini?.key;

  if (!geminiKey) {
    throw new Error('Gemini API not configured');
  }

  const {GoogleGenerativeAI} = await import('@google/generative-ai');

  const genAI = new GoogleGenerativeAI(geminiKey);
  const model = genAI.getGenerativeModel({
    model: 'gemini-1.5-flash',
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.1,
    },
  });

  // Create bulk prompt
  const bulkPrompt = createBulkPrompt(smsMessages);

  console.log(`📡 Calling Gemini API for bulk parsing of ${smsMessages.length} SMS...`);
  const result = await model.generateContent(bulkPrompt);
  const response = result.response;
  const text = response.text();

  console.log('Gemini bulk response received');

  const jsonResponse = JSON.parse(text);

  // Map results back to original SMS with index
  const results = jsonResponse.results.map((item: any, idx: number) => {
    const originalSms = smsMessages[idx];

    if (!item.transaction || !item.transaction.amount) {
      return {
        index: originalSms.index,
        success: false,
        error: 'Failed to extract transaction data',
      };
    }

    return {
      index: originalSms.index,
      success: true,
      data: {
        amount: item.transaction.amount,
        merchant: item.transaction.merchant,
        category: item.transaction.category || 'Other',
        transactionId: item.transaction.transactionId || null,
        accountInfo: item.transaction.accountInfo || null,
        date: item.transaction.date || originalSms.date,
        isDebit: item.transaction.isDebit !== false,
      },
      regexPattern: item.regexPattern && item.regexPattern.confidence >= 60 ? item.regexPattern : null,
    };
  });

  return results;
}

/**
 * Parse multiple SMS with Claude in bulk (10x faster!)
 */
async function parseBulkSmsWithClaude(smsMessages: any[]): Promise<any[]> {
  const apiKey = functions.config().anthropic?.key;

  if (!apiKey) {
    throw new Error('Claude API not configured');
  }

  const anthropic = new Anthropic({apiKey});

  // Create bulk prompt
  const bulkPrompt = createBulkPrompt(smsMessages);

  console.log(`📡 Calling Claude API for bulk parsing of ${smsMessages.length} SMS...`);
  const message = await anthropic.messages.create({
    model: 'claude-3-5-haiku-20241022',
    max_tokens: 8192, // Larger for bulk processing
    temperature: 0.1,
    messages: [{role: 'user', content: bulkPrompt}],
  });

  const content = message.content[0];
  if (content.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }

  console.log('Claude bulk response received');

  // Extract JSON
  const jsonMatch = content.text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('AI returned invalid format');
  }

  const jsonResponse = JSON.parse(jsonMatch[0]);

  // Map results back to original SMS with index
  const results = jsonResponse.results.map((item: any, idx: number) => {
    const originalSms = smsMessages[idx];

    if (!item.transaction || !item.transaction.amount) {
      return {
        index: originalSms.index,
        success: false,
        error: 'Failed to extract transaction data',
      };
    }

    return {
      index: originalSms.index,
      success: true,
      data: {
        amount: item.transaction.amount,
        merchant: item.transaction.merchant,
        category: item.transaction.category || 'Other',
        transactionId: item.transaction.transactionId || null,
        accountInfo: item.transaction.accountInfo || null,
        date: item.transaction.date || originalSms.date,
        isDebit: item.transaction.isDebit !== false,
      },
      regexPattern: item.regexPattern && item.regexPattern.confidence >= 60 ? item.regexPattern : null,
    };
  });

  return results;
}

/**
 * Create bulk prompt for processing multiple SMS at once
 */
function createBulkPrompt(smsMessages: any[]): string {
  const smsListJson = smsMessages.map((msg, idx) => ({
    index: msg.index,
    smsText: msg.smsText,
    sender: msg.sender,
    date: msg.date,
  }));

  return `You are a financial data extraction expert processing multiple bank SMS messages in bulk.

TASK: Extract transaction details AND generate regex patterns for each SMS below.

SMS MESSAGES:
${JSON.stringify(smsListJson, null, 2)}

Return JSON array with this EXACT structure:
{
  "results": [
    {
      "transaction": {
        "amount": number,
        "merchant": string,
        "category": string,
        "transactionId": string | null,
        "accountInfo": string | null,
        "date": string,
        "isDebit": boolean
      },
      "regexPattern": {
        "pattern": string,
        "description": string,
        "extractionMap": {
          "amount": number,
          "merchant": number,
          "transactionId": number,
          "accountInfo": number
        },
        "confidence": number,
        "categoryHint": string | null
      }
    }
  ]
}

TRANSACTION EXTRACTION RULES:
1. amount: Positive number (remove ₹, Rs, commas)
2. merchant: Normalized name (remove city, branch codes)
3. category: One of: Food, Shopping, Travel, Entertainment, Groceries, Utilities, Healthcare, Other
4. transactionId: Transaction/reference ID if present
5. accountInfo: Last 4 digits of card/account (like XX1234)
6. date: YYYY-MM-DD format
7. isDebit: true if spent, false if received

REGEX PATTERN GENERATION RULES:
1. Create pattern specific to each sender's format
2. Use capture groups () for: amount, merchant, transactionId, accountInfo
3. extractionMap: Map field names to capture group numbers (1-indexed)
4. confidence: 0-100 (set to null if <60)
5. Escape special regex characters properly

IMPORTANT:
- Process ALL ${smsMessages.length} SMS messages
- Return results in SAME ORDER as input
- If SMS is not a transaction, set transaction.amount to 0 and isDebit to false
- Only generate regex pattern if confidence >= 60%
- Return ONLY valid JSON, no markdown or extra text`;
}
