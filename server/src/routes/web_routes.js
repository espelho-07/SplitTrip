const express = require('express');
const authService = require('../services/auth_service');

const router = express.Router();

const privacyHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy & Data Safety — Kith</title>
  <style>
    :root {
      --bg: #0F172A;
      --card-bg: #1E293B;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --primary: #10B981;
      --border: rgba(255, 255, 255, 0.1);
      --danger: #EF4444;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      margin: 0;
      padding: 24px 16px;
    }
    .container {
      max-width: 760px;
      margin: 0 auto;
    }
    .header {
      padding: 32px 24px;
      background: var(--card-bg);
      border-radius: 16px;
      border: 1px solid var(--border);
      margin-bottom: 24px;
    }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      background: rgba(16, 185, 129, 0.15);
      color: var(--primary);
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 12px;
    }
    h1 {
      margin: 0 0 8px 0;
      font-size: 28px;
      font-weight: 800;
    }
    .subtitle {
      color: var(--text-muted);
      font-size: 14px;
    }
    .section {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 24px;
      margin-bottom: 16px;
    }
    h2 {
      font-size: 18px;
      font-weight: 700;
      margin-top: 0;
      margin-bottom: 12px;
      color: var(--primary);
    }
    ul {
      margin: 0;
      padding-left: 20px;
      color: #E2E8F0;
    }
    li {
      margin-bottom: 8px;
    }
    .footer-links {
      text-align: center;
      margin-top: 32px;
      padding-top: 20px;
      border-top: 1px solid var(--border);
    }
    a {
      color: var(--primary);
      text-decoration: none;
      font-weight: 600;
    }
    a:hover {
      text-decoration: underline;
    }
    .btn-delete {
      display: inline-block;
      padding: 10px 20px;
      background: rgba(239, 68, 68, 0.15);
      color: var(--danger);
      border: 1px solid rgba(239, 68, 68, 0.3);
      border-radius: 8px;
      font-weight: 700;
      font-size: 14px;
      margin-top: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">Official Policy</span>
      <h1>Privacy Policy & Data Safety</h1>
      <div class="subtitle">Kith by Nirniq Technologies · Effective Date: August 2026</div>
    </div>

    <div class="section">
      <h2>1. Overview & Data Minimization</h2>
      <p>Kith is designed from the ground up with a privacy-first, zero-tracker architecture. We collect only the minimum data required to calculate mathematical expense splits and synchronize ledgers across your authorized devices.</p>
    </div>

    <div class="section">
      <h2>2. Information We Collect</h2>
      <ul>
        <li><strong>Account Identifiers:</strong> Google account email address, display name, and avatar URL when signing in via Google OAuth.</li>
        <li><strong>Guest Identity:</strong> Cryptographic Recovery Key and anonymous user identifier for guest sessions.</li>
        <li><strong>User-Entered Financial Records:</strong> Expense amounts, titles, split ratios, trip categories, and participant names that you manually record.</li>
      </ul>
    </div>

    <div class="section">
      <h2>3. Data We Do NOT Collect</h2>
      <ul>
        <li><strong>No Banking Logins:</strong> Kith never asks for or handles bank credentials, UPI PINs, or credit card numbers.</li>
        <li><strong>No Location Tracking:</strong> We do not track or store your GPS location.</li>
        <li><strong>No Background Audio:</strong> The microphone is only accessed on-demand during explicit speech capture.</li>
        <li><strong>No Advertising Trackers:</strong> Zero advertising SDKs, data brokers, or third-party ad networks.</li>
      </ul>
    </div>

    <div class="section">
      <h2>4. Non-Banking Financial Services Disclaimer</h2>
      <p>Kith is strictly an informational expense tracking and mathematical split utility. Kith is NOT a bank, NBFC, lender, money transmitter, or payment processor. Marking an expense as "Paid" or "Settled" is an offline manual declaration between friends and does not execute real-world fund transfers.</p>
    </div>

    <div class="section">
      <h2>5. Permanent Account & Data Deletion</h2>
      <p>You have the absolute right to delete your account, expenses, and cloud backups at any time:</p>
      <ul>
        <li><strong>In-App Deletion:</strong> Profile → Danger Zone → Delete Account & Cloud Data.</li>
        <li><strong>Web Data Deletion Portal:</strong> If you uninstalled the app or wish to request data purging from the web, visit our <a href="/delete-account">Web Data Deletion Portal</a>.</li>
      </ul>
      <p><a href="/delete-account" class="btn-delete">Request Account & Data Deletion</a></p>
    </div>

    <div class="section">
      <h2>6. Contact & Developer Details</h2>
      <p>Developer: <strong>Nirniq Technologies</strong><br>
      Product: Kith Expense & Trip Ledger<br>
      Email: <a href="mailto:support@kith.app">support@kith.app</a> / <a href="mailto:contact@nirniq.dev">contact@nirniq.dev</a><br>
      Website: <a href="https://kith.app">https://kith.app</a></p>
    </div>

    <div class="footer-links">
      <a href="/delete-account">Account Deletion Portal</a> · <a href="mailto:support@kith.app">Contact Support</a>
    </div>
  </div>
</body>
</html>`;

const deleteAccountHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account & Data Deletion Portal — Kith</title>
  <style>
    :root {
      --bg: #0F172A;
      --card-bg: #1E293B;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --primary: #10B981;
      --border: rgba(255, 255, 255, 0.1);
      --danger: #EF4444;
      --danger-hover: #DC2626;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      margin: 0;
      padding: 32px 16px;
    }
    .container {
      max-width: 580px;
      margin: 0 auto;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 32px;
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
    }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      background: rgba(239, 68, 68, 0.15);
      color: var(--danger);
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 12px;
    }
    h1 {
      margin: 0 0 8px 0;
      font-size: 24px;
      font-weight: 800;
    }
    .desc {
      color: var(--text-muted);
      font-size: 14px;
      margin-bottom: 24px;
    }
    .form-group {
      margin-bottom: 20px;
      text-align: left;
    }
    label {
      display: block;
      font-size: 13px;
      font-weight: 700;
      margin-bottom: 8px;
      color: #E2E8F0;
    }
    input[type="text"] {
      width: 100%;
      box-sizing: border-box;
      padding: 14px 16px;
      background: rgba(15, 23, 42, 0.8);
      border: 1px solid var(--border);
      border-radius: 10px;
      color: #FFF;
      font-size: 15px;
      outline: none;
      transition: border-color 0.2s;
    }
    input[type="text"]:focus {
      border-color: var(--primary);
    }
    .btn-submit {
      width: 100%;
      padding: 14px;
      background: var(--danger);
      color: #FFF;
      border: none;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
      transition: background 0.2s;
    }
    .btn-submit:hover {
      background: var(--danger-hover);
    }
    .alert {
      padding: 14px;
      border-radius: 10px;
      margin-top: 20px;
      font-size: 14px;
      display: none;
    }
    .alert-success {
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: var(--primary);
    }
    .alert-error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.3);
      color: var(--danger);
    }
    .warning-box {
      background: rgba(239, 68, 68, 0.08);
      border: 1px solid rgba(239, 68, 68, 0.2);
      border-radius: 10px;
      padding: 16px;
      margin-bottom: 24px;
      font-size: 13px;
      color: #FECACA;
    }
    .footer-links {
      text-align: center;
      margin-top: 24px;
      font-size: 13px;
    }
    a {
      color: var(--primary);
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <span class="badge">Google Play Data Safety Portal</span>
      <h1>Delete Account & Cloud Data</h1>
      <p class="desc">In accordance with Google Play User Data Policy, you may permanently purge your account, expenses, trip memberships, and all cloud backups.</p>

      <div class="warning-box">
        <strong>⚠️ Permanent Action:</strong> Deletion is immediate and irreversible. All personal records, debts, budgets, and cloud synchronization sessions associated with your identifier will be completely removed from our servers.
      </div>

      <form id="deleteForm">
        <div class="form-group">
          <label for="identifier">Your Registered Email Address or Recovery Key:</label>
          <input type="text" id="identifier" name="identifier" placeholder="e.g. user@gmail.com or KITH-XXXX-XXXX" required />
        </div>

        <button type="submit" class="btn-submit" id="submitBtn">Permanently Delete Everything</button>
      </form>

      <div id="alertBox" class="alert"></div>
    </div>

    <div class="footer-links">
      <a href="/privacy">Read Privacy Policy</a> · <a href="mailto:support@kith.app">Contact Developer</a>
    </div>
  </div>

  <script>
    const form = document.getElementById('deleteForm');
    const alertBox = document.getElementById('alertBox');
    const submitBtn = document.getElementById('submitBtn');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const identifier = document.getElementById('identifier').value.trim();
      if (!identifier) return;

      if (!confirm('Are you absolutely sure you want to permanently delete your account and all associated cloud data? This cannot be undone.')) {
        return;
      }

      submitBtn.disabled = true;
      submitBtn.textContent = 'Processing Permanent Deletion...';
      alertBox.style.display = 'none';

      try {
        const response = await fetch('/api/auth/web-delete-request', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ identifier }),
        });
        const data = await response.json();

        if (response.ok && data.data && data.data.success) {
          alertBox.className = 'alert alert-success';
          alertBox.textContent = data.data.message || 'Account and all associated personal data have been permanently deleted.';
          alertBox.style.display = 'block';
          form.reset();
        } else {
          alertBox.className = 'alert alert-error';
          alertBox.textContent = (data.error && data.error.message) || 'Failed to process deletion request. Please contact support@kith.app.';
          alertBox.style.display = 'block';
        }
      } catch (err) {
        alertBox.className = 'alert alert-error';
        alertBox.textContent = 'Network error. Please try again or email support@kith.app.';
        alertBox.style.display = 'block';
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Permanently Delete Everything';
      }
    });
  </script>
</body>
</html>`;

router.get('/privacy', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(privacyHtml);
});

router.get('/privacy-policy', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(privacyHtml);
});

router.get('/delete-account', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(deleteAccountHtml);
});

router.get('/data-deletion', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(deleteAccountHtml);
});

router.post('/delete-account', (req, res) => {
  try {
    const { identifier } = req.body || {};
    const result = authService.deleteAccountByEmailOrKey(identifier);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(deleteAccountHtml.replace('id="alertBox" class="alert"', 'id="alertBox" class="alert alert-success" style="display:block;"').replace('</div>', `${result.message}</div>`));
  } catch (e) {
    res.status(400).send(e.message);
  }
});

module.exports = router;
