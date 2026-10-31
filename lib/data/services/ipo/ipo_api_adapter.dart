import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/config/supabase_config.dart';
import 'ipo_dtos.dart';

/// Custom exception thrown when the external IPO API (e.g. IPO Guru) has not been configured yet.
class IpoApiNotConfiguredException implements Exception {
  final String message;
  const IpoApiNotConfiguredException([this.message = 'IPO Market API is not configured.']);

  @override
  String toString() => message;
}

/// Abstract contract for IPO Market API Adapters.
/// Encapsulates all network endpoints, query parameters, authentication headers,
/// and external DTO parsing away from domain entities and repositories.
abstract class IpoApiAdapter {
  /// Fetches latest active, upcoming, and closed IPO market listings.
  Future<List<IpoDto>> fetchIpos();

  /// Fetches single IPO details by symbol or ID.
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol);

  /// Fetches unofficial GMP history data points if supplied by data provider.
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol);

  /// Indicates if this adapter has valid credentials / configuration.
  bool get isConfigured;

  /// Readable source attribution (e.g. "IPO Guru API", "Official BSE/NSE Feed", etc.)
  String get sourceAttribution;
}

/// Official Adapter for upcoming "IPO Guru API".
/// Ready for drop-in credentials and documentation once provided.
/// When unconfigured, maintains strict data integrity: never fabricates sample IPOs.
class IpoGuruApiAdapter implements IpoApiAdapter {
  final http.Client _client;
  final String? apiKey;
  final String? baseUrl;

  IpoGuruApiAdapter({
    http.Client? client,
    this.apiKey,
    this.baseUrl,
  }) : _client = client ?? http.Client();

  @override
  bool get isConfigured {
    final key = apiKey;
    final url = baseUrl;
    return key != null && key.trim().isNotEmpty && url != null && url.trim().isNotEmpty;
  }

  @override
  String get sourceAttribution => 'IPO Guru Market API';

  @override
  Future<List<IpoDto>> fetchIpos() async {
    if (!isConfigured) {
      throw const IpoApiNotConfiguredException(
        'IPO Guru API credentials and endpoint have not been configured yet.',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/ipos');
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'x-api-key': apiKey!,
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List)
            ? decoded
            : (decoded is Map && decoded['data'] is List)
                ? decoded['data'] as List
                : <dynamic>[];
        return list
            .whereType<Map<String, dynamic>>()
            .map((json) => IpoDto.fromJson(json))
            .toList();
      } else {
        throw Exception('IPO Guru API returned HTTP status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[IpoGuruApiAdapter] fetch error: $e');
      rethrow;
    }
  }

  @override
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse('$baseUrl/ipos/$idOrSymbol');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return IpoDto.fromJson(decoded);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol) async {
    if (!isConfigured) return const [];
    try {
      final uri = Uri.parse('$baseUrl/ipos/$idOrSymbol/gmp-history');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((json) => IpoGmpHistoryDto.fromJson(json))
              .toList();
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Fallback Market Adapter querying Kith backend proxy & public feeds.
class FallbackMarketApiAdapter implements IpoApiAdapter {
  final http.Client _client;

  FallbackMarketApiAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool get isConfigured => true;

  @override
  String get sourceAttribution => 'NSE/BSE Public Aggregation Feed';

  @override
  Future<List<IpoDto>> fetchIpos() async {
    // 1. Try Dedicated Kith IPO API Service
    if (AppConfig.ipoApiBaseUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('${AppConfig.ipoApiBaseUrl}/v1/ipos?limit=100');
        final response = await _client.get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (AppConfig.ipoApiKey.isNotEmpty) 'x-api-key': AppConfig.ipoApiKey,
          },
        ).timeout(const Duration(seconds: 5));

        final list = _parseList(response);
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[FallbackMarketApiAdapter] Kith IPO API notice: $e');
      }
    }

    // 2. Try SplitTrip Cloud Backend Proxy
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/ipos');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      final list = _parseList(response);
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[FallbackMarketApiAdapter] Backend proxy notice: $e');
    }

    // 3. Try Public Aggregation Endpoint
    try {
      final uri = Uri.parse('https://finapi.upvaly.com/api/ipo');
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Kith-Mobile/1.0',
        },
      ).timeout(const Duration(seconds: 6));

      final list = _parseList(response);
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[FallbackMarketApiAdapter] Public feed notice: $e');
    }

    // 4. Try Supabase Edge Function
    if (SupabaseConfig.isConfigured) {
      try {
        final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/ipo-data');
        final response = await _client.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          },
        ).timeout(const Duration(seconds: 5));

        final list = _parseList(response);
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[FallbackMarketApiAdapter] Edge function notice: $e');
      }
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
    return const [];
  }

  List<IpoDto> _parseList(http.Response response) {
    if (response.statusCode != 200) return const [];
    try {
      final decoded = jsonDecode(response.body);
      final rawList = (decoded is List)
          ? decoded
          : (decoded is Map && decoded['data'] is List)
              ? decoded['data'] as List
              : (decoded is Map && decoded['ipos'] is List)
                  ? decoded['ipos'] as List
                  : <dynamic>[];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => IpoDto.fromJson(j))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Composite Adapter prioritizing IPO Guru API and falling back seamlessly.
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
  String get sourceAttribution => guruAdapter.isConfigured
      ? guruAdapter.sourceAttribution
      : fallbackAdapter.sourceAttribution;

  @override
  Future<List<IpoDto>> fetchIpos() async {
    if (guruAdapter.isConfigured) {
      try {
        final guruResults = await guruAdapter.fetchIpos();
        if (guruResults.isNotEmpty) return guruResults;
      } catch (e) {
        debugPrint('[CompositeIpoApiAdapter] Guru API error, using fallback: $e');
      }
    }
    return fallbackAdapter.fetchIpos();
  }

  @override
  Future<IpoDto?> fetchIpoDetails(String idOrSymbol) async {
    if (guruAdapter.isConfigured) {
      try {
        final res = await guruAdapter.fetchIpoDetails(idOrSymbol);
        if (res != null) return res;
      } catch (_) {}
    }
    return fallbackAdapter.fetchIpoDetails(idOrSymbol);
  }

  @override
  Future<List<IpoGmpHistoryDto>> fetchGmpHistory(String idOrSymbol) async {
    if (guruAdapter.isConfigured) {
      try {
        final res = await guruAdapter.fetchGmpHistory(idOrSymbol);
        if (res.isNotEmpty) return res;
      } catch (_) {}
    }
    return fallbackAdapter.fetchGmpHistory(idOrSymbol);
  }
}
