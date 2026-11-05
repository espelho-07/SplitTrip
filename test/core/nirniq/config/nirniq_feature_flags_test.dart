import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/config/app_config.dart';
import 'package:kith_app/core/nirniq/config/nirniq_feature_flags.dart';

void main() {
  group('NirniqFeatureFlags & AppConfig Gate 5 Safeguards', () {
    test('ALL NirniqFeatureFlags default to false in Phase 1', () {
      expect(
        NirniqFeatureFlags.enableNirniqIdentity,
        isFalse,
        reason: 'enableNirniqIdentity MUST be false in Phase 1 (Gate 5 constraint)',
      );
      expect(
        NirniqFeatureFlags.showNirniqSignInButton,
        isFalse,
        reason: 'showNirniqSignInButton MUST be false until Gate 2 & 3 approval',
      );
      expect(
        NirniqFeatureFlags.enableGuestToNirniqLinking,
        isFalse,
        reason: 'enableGuestToNirniqLinking MUST be false until active Supabase project',
      );
      expect(
        NirniqFeatureFlags.enableNirniqFirstInstall,
        isFalse,
        reason: 'enableNirniqFirstInstall MUST be false until all Gates 1-3 approved',
      );
      expect(
        NirniqFeatureFlags.enableLocalMappingPersistence,
        isFalse,
        reason: 'enableLocalMappingPersistence MUST be false (modeling only, no persistence)',
      );
    });

    test('AppConfig.enableNirniqIdentity is explicitly false', () {
      expect(
        AppConfig.enableNirniqIdentity,
        isFalse,
        reason: 'AppConfig master flag for Nirniq identity must be false in Phase 1',
      );
    });
  });
}
