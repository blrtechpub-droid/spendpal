#!/usr/bin/env node

/**
 * Simple bug report checker using Firebase REST API
 * No authentication required - uses public Firestore REST API
 *
 * Usage: node tool/check-bugs-simple.js
 */

const https = require('https');

const PROJECT_ID = 'spendpal-app-blrtechpub';
const COLLECTION = 'bugReports';

/**
 * Fetch bug reports from Firestore using REST API
 */
async function fetchBugReports() {
  return new Promise((resolve, reject) => {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}`;

    https.get(url, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const result = JSON.parse(data);

          // Check if we got an error (like permission denied)
          if (result.error) {
            reject(new Error(result.error.message || 'API Error'));
            return;
          }

          resolve(result);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Convert Firestore document to readable format
 */
function parseFirestoreDoc(doc) {
  const fields = doc.fields || {};
  const data = {};

  // Extract field values from Firestore format
  for (const [key, value] of Object.entries(fields)) {
    if (value.stringValue !== undefined) {
      data[key] = value.stringValue;
    } else if (value.integerValue !== undefined) {
      data[key] = parseInt(value.integerValue);
    } else if (value.timestampValue !== undefined) {
      data[key] = new Date(value.timestampValue);
    } else if (value.nullValue !== undefined) {
      data[key] = null;
    }
  }

  // Extract document ID from name
  const nameParts = doc.name.split('/');
  data.id = nameParts[nameParts.length - 1];

  return data;
}

function getStatusIcon(status) {
  const icons = {
    'pending': '⏳',
    'synced': '✅',
    'closed': '❌',
  };
  return icons[status] || '❓';
}

function getPriorityIcon(priority) {
  const icons = {
    'Critical': '🔴',
    'High': '🟠',
    'Medium': '🟡',
    'Low': '🟢',
  };
  return icons[priority] || '⚪';
}

function getPlatformIcon(platform) {
  const icons = {
    'Android': '🤖',
    'iOS': '🍎',
    'Web': '🌐',
    'All': '📱',
  };
  return icons[platform] || '❓';
}

function formatDate(date) {
  if (!date) return 'Unknown';

  try {
    return date.toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return 'Invalid date';
  }
}

/**
 * Main function
 */
async function main() {
  console.log('╔════════════════════════════════════════╗');
  console.log('║  Bug Reports Checker (REST API)       ║');
  console.log('╚════════════════════════════════════════╝');
  console.log('');
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Collection: ${COLLECTION}\n`);

  try {
    console.log('Fetching bug reports from Firestore...\n');

    const result = await fetchBugReports();

    // Check if no documents found
    if (!result.documents || result.documents.length === 0) {
      console.log('📭 No bug reports found in Firestore.\n');
      console.log('This means:');
      console.log('  • No users have submitted bug reports yet');
      console.log('  • OR the bug reporting feature hasn\'t been tested');
      console.log('  • OR Firestore security rules are blocking read access\n');
      console.log('💡 To test the bug reporting feature:');
      console.log('  1. Open the app on a device/emulator');
      console.log('  2. Go to Account → Report a Bug');
      console.log('  3. Fill out and submit a test bug report');
      console.log('  4. Run this script again\n');
      return;
    }

    const bugs = result.documents.map(parseFirestoreDoc);

    console.log(`📊 Found ${bugs.length} bug report(s):\n`);
    console.log('─'.repeat(80));

    let pendingCount = 0;
    let syncedCount = 0;

    bugs.forEach((bug, index) => {
      const status = bug.status || 'unknown';

      if (status === 'pending') pendingCount++;
      if (status === 'synced') syncedCount++;

      console.log(`\n[${index + 1}] Bug Report ID: ${bug.id}`);
      console.log(`    Status: ${getStatusIcon(status)} ${status.toUpperCase()}`);
      console.log(`    Title: ${bug.title || 'No title'}`);
      console.log(`    Priority: ${getPriorityIcon(bug.priority)} ${bug.priority || 'Unknown'}`);
      console.log(`    Platform: ${getPlatformIcon(bug.platform)} ${bug.platform || 'Unknown'}`);
      console.log(`    Reported By: ${bug.reportedByName || 'Unknown'} (${bug.reportedByEmail || 'No email'})`);
      console.log(`    Created: ${formatDate(bug.createdAt)}`);

      if (bug.description) {
        const desc = bug.description.length > 100
          ? bug.description.substring(0, 100) + '...'
          : bug.description;
        console.log(`    Description: ${desc}`);
      }

      if (bug.stepsToReproduce) {
        console.log(`    Has Steps to Reproduce: Yes`);
      }

      if (bug.githubIssueNumber) {
        console.log(`    GitHub Issue: #${bug.githubIssueNumber}`);
      }

      if (bug.syncedAt) {
        console.log(`    Synced: ${formatDate(bug.syncedAt)}`);
      }

      console.log('─'.repeat(80));
    });

    // Summary
    console.log('\n📈 Summary:');
    console.log(`   Total Reports: ${bugs.length}`);
    console.log(`   ⏳ Pending (need sync): ${pendingCount}`);
    console.log(`   ✅ Synced to GitHub: ${syncedCount}`);

    if (pendingCount > 0) {
      console.log('\n💡 Next Steps:');
      console.log('   These bug reports need to be synced to GitHub.');
      console.log('   Options:');
      console.log('   1. Implement automatic sync with Cloud Function');
      console.log('   2. Create manual sync script');
      console.log('   3. Use /sync-bugs command (in Claude Code)');
    } else if (bugs.length > 0) {
      console.log('\n✅ All bug reports are synced to GitHub!');
    }

    console.log('');

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('');

    if (error.message.includes('Missing or insufficient permissions')) {
      console.error('⚠️  Firestore Security Rules Issue:');
      console.error('   The bugReports collection is protected by security rules.');
      console.error('   This script cannot access it without authentication.\n');
      console.error('📋 Alternative Options:');
      console.error('   1. Check Firebase Console manually:');
      console.error('      → https://console.firebase.google.com/project/spendpal-app-blrtechpub/firestore');
      console.error('   2. Run with authentication:');
      console.error('      → gcloud auth application-default login');
      console.error('      → cd functions && node scripts/check-bugs.js');
      console.error('   3. Test the app directly:');
      console.error('      → Open app → Account → Report a Bug\n');
    } else {
      console.error('Details:', error);
    }

    process.exit(1);
  }
}

// Run
main().catch(console.error);
