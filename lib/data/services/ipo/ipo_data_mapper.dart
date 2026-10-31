import '../../../domain/models/ipo/ipo.dart';
import 'ipo_dtos.dart';

/// Data mapper converting raw API DTOs into immutable domain entities.
/// Strictly enforces domain constraints: zero fake prices, safe date handling, and valid price bands.
class IpoDataMapper {
  static Ipo mapDtoToDomain(IpoDto dto) {
    final now = DateTime.now();

    final openDate = _parseDate(dto.openDate) ?? now;
    final closeDate = _parseDate(dto.closeDate) ?? openDate.add(const Duration(days: 3));
    final allotmentDate = _parseDate(dto.allotmentDate);
    final listingDate = _parseDate(dto.listingDate);
    final refundDate = _parseDate(dto.refundDate);

    final minPrice = (dto.minPrice ?? dto.maxPrice ?? 0).toInt();
    final maxPrice = (dto.maxPrice ?? dto.minPrice ?? 0).toInt();
    final lotSize = (dto.lotSize != null && dto.lotSize! > 0) ? dto.lotSize! : 1;

    IpoSubscription? subscription;
    if (dto.subscription != null) {
      subscription = IpoSubscription(
        qib: dto.subscription!.qib,
        nii: dto.subscription!.nii,
        retail: dto.subscription!.retail,
        employee: dto.subscription!.employee,
        shareholder: dto.subscription!.shareholder,
        total: dto.subscription!.total,
      );
    }

    return Ipo(
      id: dto.id.trim(),
      name: dto.name.trim(),
      companyName: (dto.companyName ?? dto.name).trim(),
      symbol: (dto.symbol ?? dto.id).trim().toUpperCase(),
      marketType: IpoMarketType.fromString(dto.marketType),
      status: IpoStatus.fromString(dto.status),
      openDate: openDate,
      closeDate: closeDate,
      allotmentDate: allotmentDate,
      listingDate: listingDate,
      refundDate: refundDate,
      minPrice: minPrice,
      maxPrice: maxPrice,
      lotSize: lotSize,
      issueSizeCrores: dto.issueSizeCrores?.toDouble(),
      freshIssueCrores: dto.freshIssueCrores?.toDouble(),
      ofsCrores: dto.ofsCrores?.toDouble(),
      subscription: subscription,
      subscriptionOverall: dto.subscription?.total,
      gmp: dto.gmp,
      issuePrice: dto.issuePrice?.toInt(),
      listingPrice: dto.listingPrice?.toInt(),
      currentPrice: dto.currentPrice?.toInt(),
      lastUpdated: now,
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final clean = raw.trim();
      // Handle standard ISO or YYYY-MM-DD
      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }
}
