import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/models/ipo/ipo.dart';
import '../local_storage_service.dart';
import 'ipo_api_adapter.dart';
import 'ipo_data_mapper.dart';
import 'ipo_dtos.dart';

/// Service coordinating IPO market discovery, API adapter calls, and local cache hydration.
class IpoService {
  final IpoApiAdapter apiAdapter;
  final LocalStorageService storage;

  IpoService({
    required this.apiAdapter,
    required this.storage,
  });

  bool get isConfigured => apiAdapter.isConfigured;

  String get sourceAttribution => apiAdapter.sourceAttribution;

  DateTime? get lastUpdated => storage.getIposLastUpdated();

  /// Fetches real-time market IPOs through the adapter and maps them to clean domain entities.
  Future<List<Ipo>> fetchIpoCatalog({bool forceRefresh = false}) async {
    final cached = storage.getSavedIpos();
    final lastUpdated = storage.getIposLastUpdated();
    final isStale = lastUpdated == null || DateTime.now().difference(lastUpdated) > const Duration(minutes: 15);

    if (!forceRefresh && cached.isNotEmpty && !isStale) {
      return cached.map((j) => Ipo.fromJson(j)).toList();
    }

    try {
      final dtos = await apiAdapter.fetchIpos();
      if (dtos.isNotEmpty) {
        final domainList = dtos.map((d) => IpoDataMapper.mapDtoToDomain(d)).toList();
        await storage.saveIpos(domainList.map((i) => i.toJson()).toList());
        await storage.setIposLastUpdated(DateTime.now());
        return domainList;
      }
    } catch (e) {
      debugPrint('[IpoService] API fetch notice: $e');
      if (cached.isNotEmpty) {
        return cached.map((j) => Ipo.fromJson(j)).toList();
      }
      rethrow;
    }

    return cached.map((j) => Ipo.fromJson(j)).toList();
  }

  /// Fetches single IPO details by symbol or ID.
  Future<Ipo?> getIpoDetails(String idOrSymbol) async {
    try {
      final dto = await apiAdapter.fetchIpoDetails(idOrSymbol);
      if (dto != null) {
        return IpoDataMapper.mapDtoToDomain(dto);
      }
    } catch (_) {}

    final cached = storage.getSavedIpos();
    final match = cached.where((j) => j['id'] == idOrSymbol || j['symbol'] == idOrSymbol).firstOrNull;
    if (match != null) {
      return Ipo.fromJson(match);
    }
    return null;
  }

  /// Fetches speculative GMP history if available from configured provider.
  Future<List<IpoGmpHistoryDto>> getGmpHistory(String idOrSymbol) async {
    try {
      return await apiAdapter.fetchGmpHistory(idOrSymbol);
    } catch (_) {
      return const [];
    }
  }
}
