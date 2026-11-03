import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/ipo/ipo.dart';
import '../../domain/models/ipo/ipo_application.dart';

abstract class IpoDataProvider {
  Future<List<Ipo>> fetchIpos();
  Future<bool> registerApplicationMonitoring(IpoApplication app);
  Future<IpoApplication?> checkApplicationAllotment(String applicationId);
  Future<List<IpoApplication>> syncUserAllotments(String userId);
}

/// Centralized PostgreSQL Cache Data Provider for KITH IPO Management.
///
/// ZERO Direct External Calls:
/// Never makes outbound requests to IPO Guru, FinAPI, or external market scrapers.
/// Reads directly from PostgreSQL `ipo_master` and `ipo_gmp_cache` in KITH-STAGING.
class SupabaseIpoDataProvider implements IpoDataProvider {
  final SupabaseClient? client;

  SupabaseIpoDataProvider({this.client});

  SupabaseClient? get _supabase {
    if (client != null) return client;
    if (SupabaseConfig.isConfigured) {
      return Supabase.instance.client;
    }
    return null;
  }

  @override
  Future<List<Ipo>> fetchIpos() async {
    final sClient = _supabase;
    if (sClient == null) {
      debugPrint('[SupabaseIpoDataProvider] Supabase is not configured. Returning empty IPO list.');
      return const [];
    }

    try {
      final response = await sClient
          .from('ipo_master')
          .select('*, ipo_gmp_cache(*)')
          .order('open_date', ascending: false);

      if (response.isNotEmpty) {
        final items = <Ipo>[];
        for (final row in response) {
          try {
            items.add(Ipo.fromJson(row));
          } catch (e) {
            debugPrint('[SupabaseIpoDataProvider] Error parsing row into Ipo: $e');
          }
        }
        return items;
      }
    } catch (e) {
      debugPrint('[SupabaseIpoDataProvider] Database fetch notice: $e');
    }
    return const [];
  }

  @override
  Future<bool> registerApplicationMonitoring(IpoApplication app) async {
    final sClient = _supabase;
    if (sClient == null) return false;

    try {
      await sClient.from('ipo_applications').upsert({
        'id': app.id,
        'ipo_id': app.ipoId,
        'ipo_name': app.ipoName,
        'user_id': app.userId,
        'application_account_id': app.applicationAccountId,
        'account_display_name': app.accountDisplayName,
        'account_masked_pan': app.accountMaskedPan,
        'application_number': app.applicationNumber,
        'registrar': app.registrar,
        'application_date': app.applicationDate.toIso8601String(),
        'lots_applied': app.lotsApplied,
        'lot_size': app.lotSize,
        'bid_price_in_rupees': app.bidPriceInRupees,
        'bid_price_type': app.bidPriceType,
        'application_amount_in_paise': app.applicationAmountInPaise,
        'actual_submitted_amount_in_paise': app.actualSubmittedAmountInPaise,
        'mandate_amount_in_paise': app.mandateAmountInPaise,
        'upi_mandate_status': app.upiMandateStatus,
        'status': app.status.name,
        'allotted_lots': app.allottedLots,
        'allotted_shares': app.allottedShares,
        'actual_invested_amount_in_paise': app.actualInvestedAmountInPaise,
        'released_amount_in_paise': app.releasedAmountInPaise,
        'refund_initiated_amount_in_paise': app.refundInitiatedAmountInPaise,
        'notes': app.notes,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseIpoDataProvider] Register application error: $e');
      return false;
    }
  }

  @override
  Future<IpoApplication?> checkApplicationAllotment(String applicationId) async {
    final sClient = _supabase;
    if (sClient == null) return null;

    try {
      final response = await sClient
          .from('ipo_applications')
          .select()
          .eq('id', applicationId)
          .maybeSingle();

      if (response != null) {
        return IpoApplication.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SupabaseIpoDataProvider] Check allotment error: $e');
    }
    return null;
  }

  @override
  Future<List<IpoApplication>> syncUserAllotments(String userId) async {
    final sClient = _supabase;
    if (sClient == null) return const [];

    try {
      final response = await sClient
          .from('ipo_applications')
          .select()
          .eq('user_id', userId)
          .order('application_date', ascending: false);

      if (response.isNotEmpty) {
        return response.map((m) => IpoApplication.fromJson(m)).toList();
      }
    } catch (e) {
      debugPrint('[SupabaseIpoDataProvider] Sync user allotments error: $e');
    }
    return const [];
  }
}

/// Backward-compatible alias for existing service locators
class LiveIpoDataProvider extends SupabaseIpoDataProvider {
  LiveIpoDataProvider({super.client});
}
