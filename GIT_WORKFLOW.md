# SplitTrip (KITH) Git & GitHub Version Control Workflow

This document establishes the official version control policies, branching models, commit conventions, and disaster recovery procedures for the SplitTrip codebase.

---

## 1. Branching Strategy

We follow a structured Git branching model to maintain production stability while enabling parallel feature development and hotfixing:

```
[main] (Production releases & tags only)
  ▲
  │ (Release / Fast-Forward PR)
[develop] (Active development & integration)
  ▲
  ├── feature/<feature-name>  (e.g., feature/split-receipt-scan)
  ├── bugfix/<bug-description> (e.g., bugfix/multi-payer-calc)
  └── hotfix/<critical-fix>   (Direct branch off main for production hotfixes)
```

### Branch Responsibilities
- **`main`**: The single source of truth for stable, audited, and production-ready code. Commits on `main` must pass all test suites and static analysis. Every milestone on `main` is tagged with a semantic version (e.g., `v2.0.25`).
- **`develop`**: The primary branch for daily development and integration. New features and non-urgent bug fixes branch off and merge back into `develop`.
- **`feature/*`**: Dedicated branches for new features. Branch off `develop`, merge back into `develop` via Pull Request or fast-forward merge after passing tests.
- **`bugfix/*`**: Dedicated branches for bug remediation. Branch off `develop`, merge back into `develop`.
- **`hotfix/*`**: Emergency fixes for critical issues in production. Branch directly off `main`, test rigorously, merge into both `main` and `develop`.

---

## 2. Daily Development Workflow

### Step 1: Sync with Remote Before Starting Work
Always ensure your base branch is up-to-date:
```bash
git checkout develop
git pull origin develop
```

### Step 2: Create a Feature or Bugfix Branch
Use lowercase descriptive branch names with hyphens:
```bash
# For a new feature:
git checkout -b feature/upi-deep-link

# For a bug fix:
git checkout -b bugfix/balance-rounding
```

### Step 3: Verify Locally Before Committing
Before staging or committing any code, run local verification:
```bash
# 1. Run Flutter static analysis (must be 0 issues)
flutter analyze

# 2. Run Flutter test suite
flutter test

# 3. Run backend Node test suite
cd server
npm test
cd ..
```

### Step 4: Staging & Committing Changes
Follow the **Conventional Commits** specification:
```
<type>(<scope>): <short imperative description>

[optional body explaining why the change was made]
```

**Allowed Types:**
- `feat`: A new user-facing feature
- `fix`: A bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or correcting tests
- `chore`: Build tasks, package updates, git configuration
- `docs`: Documentation updates only

**Examples:**
```bash
# Stage only verified files:
git add lib/presentation/viewmodels/add_expense_viewmodel.dart

# Commit with a clear conventional message:
git commit -m "fix(expense): preserve multi-payer allocations on total amount change"
```

### Step 5: Safe Pushing to GitHub
Never force-push (`--force`) to shared branches (`main` or `develop`).
```bash
# Push your feature branch to the remote repository:
git push -u origin feature/upi-deep-link
```

---

## 3. Merging & Release Management

### Merging Feature Branches into `develop`
When a feature is verified:
```bash
git checkout develop
git pull origin develop
git merge --no-ff feature/upi-deep-link
git push origin develop
```

### Releasing to `main` with Semantic Versioning
When a milestone on `develop` is ready for release:
1. Ensure `pubspec.yaml` and `CHANGELOG.md` have been updated with the new version (e.g., `2.0.26`).
2. Merge `develop` into `main`:
   ```bash
   git checkout main
   git pull origin main
   git merge --ff-only develop
   ```
3. Create an annotated Git tag:
   ```bash
   git tag -a v2.0.26 -m "Release v2.0.26: Multi-payer sync and offline merge hardening"
   ```
4. Push both the branch and the new tag to GitHub:
   ```bash
   git push origin main
   git push origin v2.0.26
   ```

---

## 4. Disaster Recovery & Rollback Procedures

### Scenario A: Discard Uncommitted Changes in Working Tree
To discard uncommitted changes in a specific file:
```bash
git restore path/to/file.dart
```
To discard all uncommitted modifications in the entire working directory:
```bash
git restore .
```

### Scenario B: Unstage Files Without Losing Work
If you ran `git add` by mistake but want to keep your modifications in the working tree:
```bash
git restore --staged path/to/file.dart
```

### Scenario C: Restore a Specific File from a Previous Commit
To restore an individual file from a past commit without affecting other files:
```bash
git checkout <commit-hash> -- path/to/file.dart
```

### Scenario D: Revert a Published Commit Safely
If a bad commit was already pushed to GitHub, **never force-push or rebase**. Instead, create a reverse commit:
```bash
git revert <commit-hash>
git push origin <branch-name>
```

### Scenario E: Temporary Local Stashing
To quickly save uncommitted work and switch branches without committing:
```bash
# Save to stash:
git stash save "WIP: offline balance adjustments"

# Switch branches, do work, and return:
git checkout develop

# Restore stashed changes:
git stash pop
```

---

## 5. Security & Secret Hygiene

### Zero Secrets Policy
The repository `.gitignore` strictly excludes credentials, private keys, and environment files:
- `*.env`, `.env.*` (excluding `.env.example`)
- `google-services.json`, `GoogleService-Info.plist`
- `*.jks`, `*.keystore`, `key.properties`
- `service-account*.json`
- `supabase/.temp/`

### If a Secret Is Accidentally Staged:
1. **Do NOT commit.**
2. Unstage the secret immediately:
   ```bash
   git restore --staged <secret-file>
   ```
3. Add the file pattern to `.gitignore`.
4. If a secret was ever pushed to GitHub, assume it is compromised: **rotate the credential immediately in Supabase/Google Cloud/Firebase**.
