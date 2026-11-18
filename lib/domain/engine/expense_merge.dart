import '../models/expense.dart';

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
/// and without letting an older server row replace a newer unsynced local edit.
ExpenseMergeOutcome mergeAuthoritativeExpenses({
  required List<Expense> localExpenses,
  required List<Expense> serverExpenses,
  required Set<String> pendingDeletedIds,
  required Map<String, Expense> pendingUpserts,
  required Set<String> tombstonedIds,
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
    if (pending != null && !pending.updatedAt.isBefore(server.updatedAt)) {
      merged[server.id] = pending;
      continue;
    }

    final local = localById[server.id];
    if (pending == null &&
        local != null &&
        !local.isDeleted &&
        local.updatedAt.isAfter(server.updatedAt)) {
      merged[server.id] = local;
      localNewerIds.add(server.id);
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
