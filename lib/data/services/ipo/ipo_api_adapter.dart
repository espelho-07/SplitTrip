import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import 'ipo_dtos.dart';

/// Custom exception thrown when the IPO Market API has not been configured.
class IpoApiNotConfiguredException implements Exception {
  final String message;
  const IpoApiNotConfiguredException([this.message = 'IPO Market API is not configured.']);

  @override
  String toString() => message;
}

/// Abstract contract for IPO Market API Adapters.
abstract class IpoApiAdapter {
  Future<List<IpoDto>> fetchIpos();
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol);
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol);
  bool get isConfigured;
  String get sourceAttribution;
}

/// Official Adapter for IPO Guru Developer API v2 data.
/// Serves centrally ingested and cached records directly from PostgreSQL (KITH-STAGING).
/// ZERO direct outbound calls are made from the client to external APIs.
class IpoGuruApiAdapter implements IpoApiAdapter {
  final SupabaseClient? client;

  IpoGuruApiAdapter({this.client, String? apiKey, String? baseUrl});

  SupabaseClient? get _supabase =>
      client ?? (SupabaseConfig.isConfigured ? Supabase.instance.client : null);

  @override
  bool get isConfigured => client != null || SupabaseConfig.isConfigured;

  @override
  String get sourceAttribution => 'Data: IPO Guru';

  @override
  Future<List<IpoDto>> fetchIpos() async {
    if (!isConfigured) {
      throw const IpoApiNotConfiguredException('IPO Guru Market API is not configured.');
    }
    final sClient = _supabase;
    if (sClient == null) return const [];

    try {
      final response = await sClient
          .from('ipo_master')
          .select('*, ipo_gmp_cache(*)')
          .order('open_date', ascending: false);

      if (response.isNotEmpty) {
        return response
            .whereType<Map<String, dynamic>>()
            .map((json) => IpoDto.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('[IpoGuruApiAdapter] Database cache read notice: $e');
    }
    return const [];
  }

  @override
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol) async {
    final all = await fetchIpos();
    return all.where((i) => i.id == idOrSymbol || i.symbol == idOrSymbol).firstOrNull;
  }

  @override
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol) async {
    // Free tier does not include historical GMP
    return const [];
  }
}

/// Fallback adapter reading from local/database cache
class FallbackMarketApiAdapter extends IpoGuruApiAdapter {
  FallbackMarketApiAdapter({super.client});

  @override
  String get sourceAttribution => 'KITH PostgreSQL Staging Cache';
}

/// Composite Adapter providing unified cached access
class CompositeIpoApiAdapter implements IpoApiAdapter {
  final IpoGuruApiAdapter guruAdapter;
  final FallbackMarketApiAdapter fallbackAdapter;

  CompositeIpoApiAdapter({
    required this.guruAdapter,
    required this.fallbackAdapter,
  });

  @override
  bool get isConfigured => guruAdapter.isConfigured || fallbackAdapter.isConfigured;

  @override
  String get sourceAttribution => guruAdapter.sourceAttribution;

  @override
  Future<List<IpoDto>> fetchIpos() async {
    final list = await guruAdapter.fetchIpos();
    if (list.isNotEmpty) return list;
    return fallbackAdapter.fetchIpos();
  }

  @override
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol) async {
    final item = await guruAdapter.fetchIpoDetails(idOrSymbol);
    if (item != null) return item;
    return fallbackAdapter.fetchIpoDetails(idOrSymbol);
  }

  @override
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol) async {
    return const [];
  }
}
