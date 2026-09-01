import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/models/ipo/ipo.dart';

abstract class IpoDataProvider {
  Future<List<Ipo>> fetchIpos();
}

/// Fetches real-time Indian IPO market data via Kith's secure backend proxy & Supabase Edge Functions.
///
/// Security & Quota:
/// - Connects to Kith Backend (`/api/ipos`) with automatic fallback to Supabase Edge Function (`/ipo-data`).
/// - The mobile app never receives or manages external provider API keys.
/// - Zero hardcoded or mock IPOs in production. Returns empty list if backend is unreachable.
class LiveIpoDataProvider implements IpoDataProvider {
  final http.Client _client;

  LiveIpoDataProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<Ipo>> fetchIpos() async {
    // 1. Try Primary Kith Cloud Backend proxy
    try {
      final backendUri = Uri.parse('${AppConfig.baseUrl}/ipos');
      final response = await _client.get(
        backendUri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      final items = _parseResponse(response);
      if (items.isNotEmpty) {
        return items;
      }
    } catch (e) {
      debugPrint('[LiveIpoDataProvider] Backend proxy fetch notice: $e');
    }

    // 2. Try Supabase Edge Function proxy as seamless high-availability fallback
    if (SupabaseConfig.isConfigured) {
      try {
        final edgeUri = Uri.parse('${SupabaseConfig.url}/functions/v1/ipo-data');
        final response = await _client.get(
          edgeUri,
          headers: {
            'Accept': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          },
        ).timeout(const Duration(seconds: 6));

        final items = _parseResponse(response);
        if (items.isNotEmpty) {
          return items;
        }
      } catch (e) {
        debugPrint('[LiveIpoDataProvider] Supabase Edge Function fetch notice: $e');
      }
    }

    // Zero fake data: return empty list on provider failure.
    return const [];
  }

  List<Ipo> _parseResponse(http.Response response) {
    if (response.statusCode != 200) return const [];
    try {
      final decoded = jsonDecode(response.body);
      List? rawList;
      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          rawList = decoded['data'] as List;
        } else if (decoded['ipos'] is List) {
          rawList = decoded['ipos'] as List;
        } else if (decoded['result'] is List) {
          rawList = decoded['result'] as List;
        }
      }

      if (rawList != null && rawList.isNotEmpty) {
        final items = <Ipo>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            try {
              items.add(Ipo.fromJson(item));
            } catch (e) {
              debugPrint('[LiveIpoDataProvider] JSON item parse notice: $e');
            }
          }
        }
        return items;
      }
    } catch (_) {}
    return const [];
  }
}


