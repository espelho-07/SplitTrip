## Summary of Changes

Provide a clear and concise description of what this PR accomplishes and why it is needed.

## Related Issues

Fixes #(issue number)

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 🔨 Refactor (code improvement with zero behavioral changes)
- [ ] ⚡ Performance optimization
- [ ] 📚 Documentation update
- [ ] 🧪 Tests / CI update

## Verification & Testing Evidence

Please provide the exact terminal commands and outputs demonstrating that this change was verified empirically:

- [ ] `flutter analyze` passes with 0 issues:
  ```text
  (paste output here)
  ```
- [ ] `flutter test` passes with 0 failures:
  ```text
  (paste output here)
  ```
- [ ] `npm test --prefix server` passes with 0 failures (if backend modified):
  ```text
  (paste output here)
  ```
- [ ] Android build succeeds (`flutter build apk --debug`):
  ```text
  (paste output here)
  ```

## UI Changes (if applicable)

| Before | After |
| :---: | :---: |
| *(Image/GIF)* | *(Image/GIF)* |

## Checklist

- [ ] I have read the [CONTRIBUTING](CONTRIBUTING.md) guide.
- [ ] My code adheres to the clean architecture and coding standards of Kith.
- [ ] Currency values are strictly represented in integer paise (`amountInPaise`), never floating-point.
- [ ] I have added automated unit/integration tests for my changes.
- [ ] No secrets, API keys, or private tokens are committed.
