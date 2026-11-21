# Security Policy

## Supported Versions

Security updates and critical patches are actively provided for the following releases of Kith:

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| 2.0.x   | :white_check_mark: | Active production release |
| < 2.0.0 | :x:                | Deprecated |

---

## Reporting a Vulnerability

The Kith team takes financial security and cryptographic privacy seriously. Because Kith handles financial expense distributions, peer-to-peer offline ledgers, and UPI identifiers, we treat security vulnerabilities with high urgency.

### How to Report

If you discover a security vulnerability, please **DO NOT** create a public GitHub issue.

Instead, report it privately via:
1. **GitHub Security Advisory:** Open a draft security advisory at [https://github.com/espelho-07/SplitTrip/security/advisories/new](https://github.com/espelho-07/SplitTrip/security/advisories/new).
2. **Direct Security Contact:** Email our core maintainers at `security@nirniq.com` with:
   - Vulnerability title and affected component (`lib/`, `android/`, `server/`).
   - Detailed step-by-step reproduction instructions or Proof-of-Concept (PoC).
   - Expected vs observed security impact (e.g. IDOR, outbox tampering, authorization bypass).
   - Any suggested mitigations or patches.

### Our Commitment

- **Acknowledgment:** We will acknowledge receipt of your report within 48 hours.
- **Triage & Assessment:** We will provide an initial assessment and severity rating within 5 business days.
- **Coordination & Fix:** We will work on a secure fix and release a patched build before public disclosure.
- **Responsible Disclosure:** We request that you give us a 90-day disclosure window before sharing details publicly.
