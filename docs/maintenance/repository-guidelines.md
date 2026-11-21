# Open-Source Maintenance & Repository Guidelines

## 1. Branch Management

Kith adheres to a structured Git flow:

- **`main`:** The production-ready stable branch. Direct commits to `main` are restricted. All changes arrive via thoroughly reviewed and verified pull requests.
- **`develop`:** The primary integration branch for ongoing development. Features and bug fixes branch off and merge back into `develop`.
- **`feature/*`:** Individual feature branches focused on a single vertical slice.
- **`fix/*`:** Targeted bug fix branches.

---

## 2. Secrets & Credential Protection

- **Zero-Secrets Policy:** Never commit secrets, Google Service Account keys, Firebase API keys, signing keystores, or private environment files to the repository.
- Use `android/key.properties.TEMPLATE` and `google-services.json.TEMPLATE` as reference models. Actual secrets must be loaded via local environment variables or GitHub Actions Secrets.
- Pre-commit hygiene: Always inspect `git status` and `git diff` before committing to ensure no unintended temporary files are staged.

---

## 3. Dependency Management

- Automated weekly pull requests for `pub` and `npm` packages are managed by Dependabot (`.github/dependabot.yml`).
- Review dependency bumps carefully for breaking changes before merging.
- Run `flutter analyze` and `flutter test` on all automated dependency upgrade PRs.

---

## 4. Issue & Pull Request Triage

1. **New Issues:** Triage issues within 48 hours. Apply relevant labels (`bug`, `enhancement`, `needs-repro`).
2. **Pull Requests:** Ensure PR template checklists are completed and verification evidence (CLI outputs) is attached before approving and merging.
