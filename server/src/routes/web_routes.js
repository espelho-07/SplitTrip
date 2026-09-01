const express = require('express');
const authService = require('../services/auth_service');

const router = express.Router();

const indexHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kith — Split & Trip Expense Tracker</title>
  <style>
    :root {
      --bg: #0F172A;
      --card-bg: #1E293B;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --primary: #10B981;
      --indigo: #6366F1;
      --border: rgba(255, 255, 255, 0.1);
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
      max-width: 800px;
      margin: 0 auto;
      text-align: center;
    }
    .badge {
      display: inline-block;
      padding: 6px 16px;
      background: rgba(16, 185, 129, 0.15);
      color: var(--primary);
      border-radius: 24px;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.5px;
      margin-bottom: 20px;
    }
    h1 {
      font-size: 42px;
      font-weight: 900;
      margin: 0 0 12px 0;
      letter-spacing: -0.5px;
    }
    .hero-sub {
      color: var(--text-muted);
      font-size: 18px;
      max-width: 580px;
      margin: 0 auto 32px auto;
    }
    .card-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
      text-align: left;
      margin-bottom: 40px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
    }
    .card h3 {
      margin: 0 0 8px 0;
      font-size: 17px;
      color: var(--primary);
    }
    .card p {
      margin: 0;
      font-size: 14px;
      color: #CBD5E1;
    }
    .legal-links {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
      margin-top: 32px;
    }
    .legal-links h3 {
      margin: 0 0 8px 0;
      font-size: 18px;
    }
    .legal-links a {
      color: var(--primary);
      text-decoration: none;
      font-weight: 600;
      margin: 0 12px;
    }
    .legal-links a:hover {
      text-decoration: underline;
    }
    .developer-info {
      margin-top: 32px;
      font-size: 14px;
      color: var(--text-muted);
    }
    .developer-info a {
      color: #94A3B8;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">Official Application Homepage</div>
    <h1>Kith</h1>
    <p class="hero-sub">Split &amp; Trip Expense Tracker — A deterministic group financial ledger, personal finance manager, and debt graph simplifier.</p>

    <div class="card-grid">
      <div class="card">
        <h3>⚡ Realtime Ledger</h3>
        <p>Sync group expenses instantly across devices with automated debt simplification algorithms.</p>
      </div>
      <div class="card">
        <h3>🔒 Local-First Vault</h3>
        <p>Complete offline functionality secured with local AES encryption and master recovery keys.</p>
      </div>
      <div class="card">
        <h3>✨ Smart P2P Split</h3>
        <p>Zero floating-point inaccuracies or penny leaks with Paise-perfect integer arithmetic.</p>
      </div>
    </div>

    <div class="legal-links">
      <h3>Policy &amp; Legal Compliance</h3>
      <p style="color: var(--text-muted); font-size: 14px; margin-bottom: 16px;">Review our verified terms, privacy protections, and user data rights:</p>
      <a href="/privacy">Privacy Policy</a> · 
      <a href="/terms">Terms of Service</a> · 
      <a href="/delete-account">Account &amp; Data Deletion Portal</a>
    </div>

    <div class="developer-info">
      Developer: <strong>Darpan Parmar</strong> · Contact: <a href="mailto:hello.nirniq@gmail.com">hello.nirniq@gmail.com</a> · Website: <a href="https://darpanparmar.me" target="_blank">darpanparmar.me</a>
    </div>
  </div>
</body>
</html>`;

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
      <p>Developer: <strong>Darpan Parmar</strong><br>
      Product: Kith Expense & Trip Ledger<br>
      Email: <a href="mailto:hello.nirniq@gmail.com">hello.nirniq@gmail.com</a><br>
      Website: <a href="https://darpanparmar.me" target="_blank">https://darpanparmar.me</a></p>
    </div>

    <div class="footer-links">
      <a href="/delete-account">Account Deletion Portal</a> · <a href="mailto:hello.nirniq@gmail.com">Contact Support</a>
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
      <a href="/privacy">Read Privacy Policy</a> · <a href="mailto:hello.nirniq@gmail.com">Contact Developer</a>
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
          alertBox.textContent = (data.error && data.error.message) || 'Failed to process deletion request. Please contact hello.nirniq@gmail.com.';
          alertBox.style.display = 'block';
        }
      } catch (err) {
        alertBox.className = 'alert alert-error';
        alertBox.textContent = 'Network error. Please try again or email hello.nirniq@gmail.com.';
        alertBox.style.display = 'block';
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Permanently Delete Everything';
      }
    });
  </script>
</body>
</html>`;

const termsHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Terms of Service — Kith</title>
  <style>
    :root {
      --bg: #0F172A;
      --card-bg: #1E293B;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --primary: #10B981;
      --border: rgba(255, 255, 255, 0.1);
      --indigo: #6366F1;
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
      background: rgba(99, 102, 241, 0.15);
      color: var(--indigo);
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
      color: var(--text);
    }
    p, ul {
      color: #CBD5E1;
      font-size: 14.5px;
      margin: 0 0 12px 0;
    }
    ul {
      padding-left: 20px;
    }
    li {
      margin-bottom: 6px;
    }
    a {
      color: var(--primary);
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
    .footer-links {
      text-align: center;
      margin-top: 32px;
      font-size: 13px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">Legal Agreement</div>
      <h1>Terms of Service</h1>
      <div class="subtitle">Effective Date: August 31, 2026 · App: Kith Expense &amp; Trip Ledger</div>
    </div>

    <div class="section">
      <h2>1. Acceptance of Terms</h2>
      <p>By downloading, accessing, or using <strong>Kith</strong> (&quot;the Application&quot;, &quot;Service&quot;), provided by <strong>Darpan Parmar</strong> (&quot;Developer&quot;, &quot;we&quot;, &quot;us&quot;), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Application.</p>
    </div>

    <div class="section">
      <h2>2. Description of Service &amp; Financial Disclaimer</h2>
      <p>Kith is a local-first group travel expense tracker, personal finance manager, and debt simplification calculation tool. Please note:</p>
      <ul>
        <li><strong>Calculation Utility Only:</strong> Kith is not a bank, payment gateway, custodian, or financial institution. Kith calculates mathematical debt balances and transaction splits between friends and groups.</li>
        <li><strong>No Direct Fund Holding:</strong> Kith does not hold, transmit, custody, or manage monetary funds or bank accounts.</li>
        <li><strong>Peer-to-Peer Payments:</strong> Any financial settlements initiated via UPI or external payment links occur entirely outside Kith via third-party payment applications chosen by the users.</li>
      </ul>
    </div>

    <div class="section">
      <h2>3. User Accounts &amp; Data Responsibility</h2>
      <ul>
        <li><strong>Guest Mode:</strong> You may use Kith anonymously as a Guest without providing personal identification. Guest records are secured locally on your device with a cryptographically generated Recovery Key. You are solely responsible for saving your Recovery Key.</li>
        <li><strong>Google Sign-In:</strong> You may link your Google Account to back up and synchronize your trips and budgets across devices.</li>
        <li><strong>User Content:</strong> You retain ownership of all expense names, trip titles, categories, and receipts you enter into the Application. You agree not to upload abusive, unlawful, or infringing content.</li>
      </ul>
    </div>

    <div class="section">
      <h2>4. Intellectual Property</h2>
      <p>The Kith software, algorithms (including the debt simplification engine), visual designs, logos, and documentation are the intellectual property of Darpan Parmar. You are granted a personal, revocable, non-exclusive, non-transferable license to use the app for personal, non-commercial expense tracking.</p>
    </div>

    <div class="section">
      <h2>5. Termination &amp; Data Deletion</h2>
      <p>You may terminate your relationship with Kith at any time by uninstalling the application and/or purging your data:</p>
      <ul>
        <li><strong>In-App Deletion:</strong> Profile &rarr; Delete Account &amp; Cloud Data permanently deletes your profile, expenses, and cloud backups.</li>
        <li><strong>Web Data Deletion Portal:</strong> If you uninstalled the app, you may request permanent data deletion via our <a href="/delete-account">Web Data Deletion Portal</a>.</li>
      </ul>
    </div>

    <div class="section">
      <h2>6. Limitation of Liability</h2>
      <p>To the maximum extent permitted by applicable law, Kith is provided on an &quot;AS IS&quot; and &quot;AS AVAILABLE&quot; basis without warranties of any kind. The developer shall not be liable for indirect, incidental, special, consequential, or punitive damages arising from the use or inability to use the Service.</p>
    </div>

    <div class="section">
      <h2>7. Contact Information</h2>
      <p>Developer: <strong>Darpan Parmar</strong><br>
      Email: <a href="mailto:hello.nirniq@gmail.com">hello.nirniq@gmail.com</a><br>
      Website: <a href="https://darpanparmar.me" target="_blank">https://darpanparmar.me</a></p>
    </div>

    <div class="footer-links">
      <a href="/privacy">Privacy Policy</a> · <a href="/delete-account">Data Deletion Portal</a> · <a href="mailto:hello.nirniq@gmail.com">Contact Developer</a>
    </div>
  </div>
</body>
</html>`;

router.get('/', (req, res) => {
  const accept = req.headers.accept || '';
  if (accept.includes('text/html') && !accept.includes('application/json')) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(indexHtml);
  }
  return res.status(200).json({ status: 'ok', service: 'kith-backend', version: '1.0.0' });
});

router.get('/privacy', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(privacyHtml);
});

router.get('/privacy-policy', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(privacyHtml);
});

router.get('/terms', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(termsHtml);
});

router.get('/terms-of-service', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(termsHtml);
});

router.get('/tos', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(termsHtml);
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
