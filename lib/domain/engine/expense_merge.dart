import '../enums/expense_category.dart';
import '../enums/split_type.dart';
import '../models/expense.dart';
import '../models/expense_split.dart';

/// Engine responsible for deterministic 3-way and field-level merging of concurrent expense edits.
class ExpenseMergeEngine {
  /// Merges non-conflicting field edits across concurrent versions of an expense.
  ///
  /// When [base] is provided, a true 3-way merge is performed:
  /// - If only [local] changed a field relative to [base], [local]'s change is preserved.
  /// - If only [remote] changed a field relative to [base], [remote]'s change is preserved.
  /// - If both changed the field to identical values, that value is preserved.
  /// - If both changed the field to conflicting values, the conflict is resolved
  ///   using Last-Write-Wins (preferring the newer [updatedAt]).
  ///
  /// When [base] is null, a field-level reconciliation between [local] and [remote]
  /// is performed, combining distinct non-default/newer attributes.
  static Expense merge3Way({
    required Expense local,
    required Expense remote,
    Expense? base,
  }) {
    // 1. Tombstone / Deletion Invariant: Deletion strictly takes precedence
    if (local.isDeleted || remote.isDeleted || (base != null && base.isDeleted)) {
      final newer = local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
      return newer.copyWith(isDeleted: true);
    }

    // If identical, return local directly
    if (_areExpensesIdentical(local, remote)) {
      return local;
    }

    final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);
    bool hasCombinedEdits = false;

    // 2. Field: Title
    String title;
    if (base != null) {
      final localChanged = local.title != base.title;
      final remoteChanged = remote.title != base.title;
      if (localChanged && !remoteChanged) {
        title = local.title;
      } else if (remoteChanged && !localChanged) {
        title = remote.title;
        hasCombinedEdits = true;
      } else if (localChanged && remoteChanged) {
        if (local.title == remote.title) {
          title = local.title;
        } else if (local.title.trim().isEmpty) {
          title = remote.title;
        } else if (remote.title.trim().isEmpty) {
          title = local.title;
        } else {
          title = isLocalNewer ? local.title : remote.title;
        }
      } else {
        title = base.title;
      }
    } else {
      if (local.title == remote.title) {
        title = local.title;
      } else if (local.title.trim().isEmpty) {
        title = remote.title;
      } else if (remote.title.trim().isEmpty) {
        title = local.title;
      } else {
        title = isLocalNewer ? local.title : remote.title;
      }
    }

    // 3. Field: Category
    ExpenseCategory category;
    if (base != null) {
      final localChanged = local.category != base.category;
      final remoteChanged = remote.category != base.category;
      if (localChanged && !remoteChanged) {
        category = local.category;
      } else if (remoteChanged && !localChanged) {
        category = remote.category;
        hasCombinedEdits = true;
      } else if (localChanged && remoteChanged) {
        if (local.category == remote.category) {
          category = local.category;
        } else {
          category = isLocalNewer ? local.category : remote.category;
        }
      } else {
        category = base.category;
      }
    } else {
      if (local.category == remote.category) {
        category = local.category;
      } else if (local.category == ExpenseCategory.general &&
          remote.category != ExpenseCategory.general) {
        category = remote.category;
        hasCombinedEdits = true;
      } else if (remote.category == ExpenseCategory.general &&
          local.category != ExpenseCategory.general) {
        category = local.category;
      } else {
        category = isLocalNewer ? local.category : remote.category;
      }
    }

    // 4. Field: Location
    String? location;
    if (base != null) {
      final localChanged = local.location != base.location;
      final remoteChanged = remote.location != base.location;
      if (localChanged && !remoteChanged) {
        location = local.location;
      } else if (remoteChanged && !localChanged) {
        location = remote.location;
        hasCombinedEdits = true;
      } else if (localChanged && remoteChanged) {
        location = isLocalNewer ? local.location : remote.location;
      } else {
        location = base.location;
      }
    } else {
      if (local.location == remote.location) {
        location = local.location;
      } else if (local.location == null || local.location!.isEmpty) {
        location = remote.location;
        if (remote.location != null && remote.location!.isNotEmpty) {
          hasCombinedEdits = true;
        }
      } else if (remote.location == null || remote.location!.isEmpty) {
        location = local.location;
      } else {
        location = isLocalNewer ? local.location : remote.location;
      }
    }

    // 5. Field: Receipt URL
    String? receiptUrl;
    if (base != null) {
      final localChanged = local.receiptUrl != base.receiptUrl;
      final remoteChanged = remote.receiptUrl != base.receiptUrl;
      if (localChanged && !remoteChanged) {
        receiptUrl = local.receiptUrl;
      } else if (remoteChanged && !localChanged) {
        receiptUrl = remote.receiptUrl;
        hasCombinedEdits = true;
      } else if (localChanged && remoteChanged) {
        receiptUrl = isLocalNewer ? local.receiptUrl : remote.receiptUrl;
      } else {
        receiptUrl = base.receiptUrl;
      }
    } else {
      if (local.receiptUrl == remote.receiptUrl) {
        receiptUrl = local.receiptUrl;
      } else if (local.receiptUrl == null || local.receiptUrl!.isEmpty) {
        receiptUrl = remote.receiptUrl;
        if (remote.receiptUrl != null && remote.receiptUrl!.isNotEmpty) {
          hasCombinedEdits = true;
        }
      } else if (remote.receiptUrl == null || remote.receiptUrl!.isEmpty) {
        receiptUrl = local.receiptUrl;
      } else {
        receiptUrl = isLocalNewer ? local.receiptUrl : remote.receiptUrl;
      }
    }

    // 6. Field: Voice Transcript
    String? voiceTranscript;
    if (base != null) {
      final localChanged = local.voiceTranscript != base.voiceTranscript;
      final remoteChanged = remote.voiceTranscript != base.voiceTranscript;
      if (localChanged && !remoteChanged) {
        voiceTranscript = local.voiceTranscript;
      } else if (remoteChanged && !localChanged) {
        voiceTranscript = remote.voiceTranscript;
        hasCombinedEdits = true;
      } else {
        voiceTranscript = isLocalNewer
            ? local.voiceTranscript
            : remote.voiceTranscript;
      }
    } else {
      if (local.voiceTranscript == remote.voiceTranscript) {
        voiceTranscript = local.voiceTranscript;
      } else if (local.voiceTranscript == null ||
          local.voiceTranscript!.isEmpty) {
        voiceTranscript = remote.voiceTranscript;
        if (remote.voiceTranscript != null) hasCombinedEdits = true;
      } else if (remote.voiceTranscript == null ||
          remote.voiceTranscript!.isEmpty) {
        voiceTranscript = local.voiceTranscript;
      } else {
        voiceTranscript = isLocalNewer
            ? local.voiceTranscript
            : remote.voiceTranscript;
      }
    }

    // 7. Financial Bundle (amountInPaise, paidById, paidByMap, splitType, splits)
    // Financial fields must remain mathematically coupled to satisfy zero-sum split equality.
    final int amountInPaise;
    final String paidById;
    final Map<String, int>? paidByMap;
    final SplitType splitType;
    final List<ExpenseSplit> splits;

    if (base != null) {
      final localFinChanged = _isFinancialGroupChanged(local, base);
      final remoteFinChanged = _isFinancialGroupChanged(remote, base);

      if (localFinChanged && !remoteFinChanged) {
        amountInPaise = local.amountInPaise;
        paidById = local.paidById;
        paidByMap = local.paidByMap;
        splitType = local.splitType;
        splits = local.splits;
      } else if (remoteFinChanged && !localFinChanged) {
        amountInPaise = remote.amountInPaise;
        paidById = remote.paidById;
        paidByMap = remote.paidByMap;
        splitType = remote.splitType;
        splits = remote.splits;
        hasCombinedEdits = true;
      } else if (localFinChanged && remoteFinChanged) {
        // Both sides concurrently edited financial math: resolve by newer timestamp
        final finWinner = isLocalNewer ? local : remote;
        amountInPaise = finWinner.amountInPaise;
        paidById = finWinner.paidById;
        paidByMap = finWinner.paidByMap;
        splitType = finWinner.splitType;
        splits = finWinner.splits;
      } else {
        amountInPaise = base.amountInPaise;
        paidById = base.paidById;
        paidByMap = base.paidByMap;
        splitType = base.splitType;
        splits = base.splits;
      }
    } else {
      if (!_isFinancialGroupChanged(local, remote)) {
        amountInPaise = local.amountInPaise;
        paidById = local.paidById;
        paidByMap = local.paidByMap;
        splitType = local.splitType;
        splits = local.splits;
      } else {
        final finWinner = isLocalNewer ? local : remote;
        amountInPaise = finWinner.amountInPaise;
        paidById = finWinner.paidById;
        paidByMap = finWinner.paidByMap;
        splitType = finWinner.splitType;
        splits = finWinner.splits;
      }
    }

    // 8. Timestamps
    final DateTime effectiveUpdatedAt;
    final latestUpdate = isLocalNewer ? local.updatedAt : remote.updatedAt;
    if (hasCombinedEdits) {
      // Advance by 1 millisecond so the synthesized 3-way merge outcome
      // is authoritative and newer than both source edits.
      effectiveUpdatedAt = latestUpdate.add(const Duration(milliseconds: 1));
    } else {
      effectiveUpdatedAt = latestUpdate;
    }

    final effectiveCreatedAt = local.createdAt.isBefore(remote.createdAt)
        ? local.createdAt
        : remote.createdAt;

    return Expense(
      id: local.id,
      tripId: local.tripId,
      title: title,
      amountInPaise: amountInPaise,
      category: category,
      paidById: paidById,
      paidByMap: paidByMap,
      splits: splits,
      splitType: splitType,
      location: location,
      receiptUrl: receiptUrl,
      voiceTranscript: voiceTranscript,
      createdAt: effectiveCreatedAt,
      updatedAt: effectiveUpdatedAt,
      isDeleted: false,
    );
  }

  static bool _isFinancialGroupChanged(Expense a, Expense b) {
    if (a.amountInPaise != b.amountInPaise) return true;
    if (a.paidById != b.paidById) return true;
    if (a.splitType != b.splitType) return true;
    if (!_splitsEqual(a.splits, b.splits)) return true;
    if (!_mapsEqual(a.paidByMap, b.paidByMap)) return true;
    return false;
  }

  static bool _splitsEqual(List<ExpenseSplit> a, List<ExpenseSplit> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].memberId != b[i].memberId ||
          a[i].amountInPaise != b[i].amountInPaise ||
          a[i].percentage != b[i].percentage ||
          a[i].shares != b[i].shares) {
        return false;
      }
    }
    return true;
  }

  static bool _mapsEqual(Map<String, int>? a, Map<String, int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _areExpensesIdentical(Expense a, Expense b) {
    return a.id == b.id &&
        a.title == b.title &&
        a.amountInPaise == b.amountInPaise &&
        a.category == b.category &&
        a.paidById == b.paidById &&
        a.splitType == b.splitType &&
        a.location == b.location &&
        a.receiptUrl == b.receiptUrl &&
        a.voiceTranscript == b.voiceTranscript &&
        a.isDeleted == b.isDeleted &&
        _splitsEqual(a.splits, b.splits) &&
        _mapsEqual(a.paidByMap, b.paidByMap);
  }
}

/// Result of merging a local expense list with a successful server snapshot.
class ExpenseMergeOutcome {
  final List<Expense> expenses;

  /// Local expenses the server no longer returns and that are not pending upload.
  final Set<String> remoteDeletedIds;

  /// Local expenses newer than the server copy, with no pending mutation yet.
  final Set<String> localNewerIds;

  const ExpenseMergeOutcome({
    required this.expenses,
    required this.remoteDeletedIds,
    required this.localNewerIds,
  });
}

/// Merges expenses without letting an omitted server row resurrect a delete,
/// while performing field-level 3-way merge on concurrent edits.
ExpenseMergeOutcome mergeAuthoritativeExpenses({
  required List<Expense> localExpenses,
  required List<Expense> serverExpenses,
  required Set<String> pendingDeletedIds,
  required Map<String, Expense> pendingUpserts,
  required Set<String> tombstonedIds,
  Map<String, Expense>? pendingBaseExpenses,
}) {
  final localById = <String, Expense>{
    for (final expense in localExpenses) expense.id: expense,
  };
  final serverIds = serverExpenses.map((expense) => expense.id).toSet();
  final merged = <String, Expense>{};
  final remoteDeletedIds = <String>{};
  final localNewerIds = <String>{};

  bool isBlocked(String id) =>
      pendingDeletedIds.contains(id) || tombstonedIds.contains(id);

  for (final server in serverExpenses) {
    if (server.isDeleted || isBlocked(server.id)) {
      remoteDeletedIds.add(server.id);
      continue;
    }

    final pending = pendingUpserts[server.id];
    final local = localById[server.id];

    if (pending != null) {
      // Determine the true base ancestor for 3-way merge.
      // 1. Prefer explicit baseExpense recorded when the mutation was enqueued.
      // 2. If absent and local snapshot differs from pending, local is the pre-mutation base.
      // 3. Otherwise, if local is just the optimistic cache identical to pending, base is null.
      Expense? base = pendingBaseExpenses?[server.id];
      if (base == null && local != null) {
        final isLocalOptimisticCopyOfPending =
            local.updatedAt == pending.updatedAt &&
            local.amountInPaise == pending.amountInPaise &&
            local.title == pending.title;
        if (!isLocalOptimisticCopyOfPending) {
          base = local;
        }
      }

      // 3-way merge between local pending edit, incoming server version, and base snapshot
      final mergedExpense = ExpenseMergeEngine.merge3Way(
        local: pending,
        remote: server,
        base: base,
      );
      merged[server.id] = mergedExpense;
      if (mergedExpense.updatedAt.isAfter(server.updatedAt)) {
        localNewerIds.add(server.id);
      }
      continue;
    }

    if (local != null && !local.isDeleted) {
      // 3-way field-level reconciliation between local version and server version
      final mergedExpense = ExpenseMergeEngine.merge3Way(
        local: local,
        remote: server,
      );
      merged[server.id] = mergedExpense;
      if (mergedExpense.updatedAt.isAfter(server.updatedAt)) {
        localNewerIds.add(server.id);
      }
      continue;
    }

    merged[server.id] = server;
  }

  for (final local in localExpenses) {
    if (local.isDeleted || isBlocked(local.id)) {
      remoteDeletedIds.add(local.id);
      continue;
    }
    if (merged.containsKey(local.id)) continue;

    final pending = pendingUpserts[local.id];
    if (pending != null) {
      merged[local.id] = pending;
      continue;
    }

    // In an offline-first mesh architecture, an unacknowledged local or P2P expense
    // omitted from the server snapshot must NEVER be silently deleted.
    // Preserve it locally and schedule it to be synced/uploaded to the server.
    if (!serverIds.contains(local.id)) {
      merged[local.id] = local;
      localNewerIds.add(local.id);
    }
  }

  final expenses = merged.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return ExpenseMergeOutcome(
    expenses: expenses,
    remoteDeletedIds: remoteDeletedIds,
    localNewerIds: localNewerIds,
  );
}
