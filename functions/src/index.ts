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
        if (transactions.length === 0) {
          console.log('Rule-based parsing failed. Using Claude AI...');
          transactions = await parseWithClaude(extractedText);
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
 * Parse bill using Claude AI
 */
async function parseWithClaude(text: string): Promise<Transaction[]> {
  const apiKey = functions.config().anthropic?.key;

  if (!apiKey) {
    console.error('Anthropic API key not configured');
    throw new Error('Claude API not configured. Set with: firebase functions:config:set anthropic.key="YOUR_KEY"');
  }

  console.log('Calling Claude API with model: claude-3-haiku-20240307');

  const anthropic = new Anthropic({apiKey});

  try {
    const message = await anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 4096,
      messages: [
        {
          role: 'user',
          content: `You are a financial data extraction expert. Extract ALL transactions from this Indian credit card bill.

BILL TEXT:
${text.substring(0, 15000)}

INSTRUCTIONS:
1. Extract ONLY actual purchase transactions (debits)
2. Skip: totals, balances, offers, rewards, interest charges, fees
3. Normalize merchant names (remove city, branch codes)
4. Infer category from merchant name
5. Use ISO date format (YYYY-MM-DD)
6. Ensure amounts are positive numbers

Return ONLY a valid JSON array with this structure:
[
  {"date": "2025-01-10", "merchant": "Amazon", "amount": 1520.50, "category": "Shopping"},
  {"date": "2025-01-12", "merchant": "Swiggy", "amount": 450.00, "category": "Food"}
]

Categories to use: Food, Travel, Shopping, Entertainment, Utilities, Healthcare, Education, Personal Care, Other

IMPORTANT: Return ONLY the JSON array, no additional text.`,
        },
      ],
    });

    // Extract JSON from response
    const content = message.content[0];
    if (content.type === 'text') {
      // Extract JSON array from response
      const jsonMatch = content.text.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);

        // Add unique IDs
        return parsed.map((t: any, index: number) => ({
          id: `${Date.now()}_${index}`,
          date: t.date || '2025-01-01',
          merchant: t.merchant || 'Unknown',
          amount: parseFloat(t.amount) || 0,
          category: t.category || 'Other',
        }));
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

    // Provide more helpful error messages
    if (error.status === 404) {
      throw new Error(`Model not available. Please check your Anthropic API key has access to claude-3-haiku-20240307`);
    } else if (error.status === 401) {
      throw new Error(`Invalid Anthropic API key`);
    } else if (error.status === 429) {
      throw new Error(`Rate limit exceeded. Please try again later`);
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
