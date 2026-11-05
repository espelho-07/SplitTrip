/// Feature flags controlling Nirniq identity platform rollout.
///
/// ALL flags default to false in Phase 1.
/// These are NEVER read by existing authentication code paths.
/// Existing guest and Recovery Key flows are unaffected.
///
/// Usage: gated by AppConfig.enableNirniqIdentity
class NirniqFeatureFlags {
  const NirniqFeatureFlags._();

  /// Master switch for the Nirniq identity platform.
  /// When false, all Nirniq code paths are bypassed entirely.
  static const bool enableNirniqIdentity = false;

  /// Whether to show the "Continue with Nirniq" button in onboarding.
  /// Requires [enableNirniqIdentity] = true AND Gate 2+3 approved.
  static const bool showNirniqSignInButton = false;

  /// Whether to allow existing guests to link their account to Nirniq.
  /// Requires [enableNirniqIdentity] = true AND active Supabase project.
  static const bool enableGuestToNirniqLinking = false;

  /// Whether new installs use the Nirniq-first auth flow.
  /// Requires all gates 1-3 approved.
  static const bool enableNirniqFirstInstall = false;

  /// Whether to persist legacy mapping records locally.
  /// Phase 1: false (mapping is modeled but not persisted).
  static const bool enableLocalMappingPersistence = false;
}
