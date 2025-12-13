/**
 * Check for bug reports in Firestore
 * Run from functions directory: node scripts/check-bugs.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
admin.initializeApp({
  projectId: 'spendpal-app-blrtechpub',
});

const db = admin.firestore();

async function checkBugReports() {
  console.log('╔════════════════════════════════════════╗');
  console.log('║  Bug Reports Checker                  ║');
  console.log('╚════════════════════════════════════════╝');
  console.log('');

  try {
    console.log('Querying Firestore bugReports collection...\n');

    // Get all bug reports
    const snapshot = await db.collection('bugReports').get();

    if (snapshot.empty) {
      console.log('📭 No bug reports found in Firestore.\n');
      console.log('This means:');
      console.log('  • No users have submitted bug reports yet');
      console.log('  • OR the bug reporting feature hasn\'t been tested\n');
      return;
    }

    console.log(`📊 Found ${snapshot.size} bug report(s):\n`);
    console.log('─'.repeat(80));

    let pendingCount = 0;
    let syncedCount = 0;

    snapshot.forEach((doc, index) => {
      const data = doc.data();
      const status = data.status || 'unknown';

      if (status === 'pending') pendingCount++;
      if (status === 'synced') syncedCount++;

      console.log(`\n[${index + 1}] Bug Report ID: ${doc.id}`);
      console.log(`    Status: ${getStatusIcon(status)} ${status.toUpperCase()}`);
      console.log(`    Title: ${data.title || 'No title'}`);
      console.log(`    Priority: ${getPriorityIcon(data.priority)} ${data.priority || 'Unknown'}`);
      console.log(`    Platform: ${getPlatformIcon(data.platform)} ${data.platform || 'Unknown'}`);
      console.log(`    Reported By: ${data.reportedByName || 'Unknown'} (${data.reportedByEmail || 'No email'})`);
      console.log(`    Created: ${formatDate(data.createdAt)}`);

      if (data.description) {
        const desc = data.description.length > 100
          ? data.description.substring(0, 100) + '...'
          : data.description;
        console.log(`    Description: ${desc}`);
      }

      if (data.stepsToReproduce) {
        console.log(`    Has Steps to Reproduce: Yes`);
      }

      if (data.githubIssueNumber) {
        console.log(`    GitHub Issue: #${data.githubIssueNumber}`);
      }

      if (data.syncedAt) {
        console.log(`    Synced: ${formatDate(data.syncedAt)}`);
      }

      console.log('─'.repeat(80));
    });

    // Summary
    console.log('\n📈 Summary:');
    console.log(`   Total Reports: ${snapshot.size}`);
    console.log(`   ⏳ Pending (need sync): ${pendingCount}`);
    console.log(`   ✅ Synced to GitHub: ${syncedCount}`);

    if (pendingCount > 0) {
      console.log('\n💡 Next Steps:');
      console.log('   Run the sync script to create GitHub issues:');
      console.log('   → node scripts/sync-bugs-to-github.js');
      console.log('   OR use: /sync-bugs (in Claude Code)');
    }

    console.log('');

  } catch (error) {
    console.error('❌ Error querying Firestore:', error.message);
    console.error('\nDetails:', error);
    process.exit(1);
  }
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

function formatDate(timestamp) {
  if (!timestamp) return 'Unknown';

  try {
    // Handle Firestore Timestamp
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
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

// Run the checker
checkBugReports()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error('Unexpected error:', error);
    process.exit(1);
  });
