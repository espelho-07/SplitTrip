# Synchronization Architecture & Offline-First Review
**Project:** SplitTrip (KITH)  
**Scope:** Multi-Device, High-Concurrency Offline & Cloud Synchronization  
**Author:** Principal Distributed Systems Engineer & Staff Flutter Architect  
**Date:** 2026-11-19  

---

## 1. Real-World Operating Assumptions

The synchronization engine is engineered to perform reliably under the most demanding real-world travel conditions:
- **Group Scale**: 10 to 50 active participants per trip.
- **Heterogeneous Connectivity**: A mix of high-speed Wi-Fi, flaky 3G/4G, intermittent hotel captive portals, and complete offline environments (remote mountains, flights, tunnels).
- **Asynchronous Partitions**: Some members remain offline for multiple days while other members actively record expenses.
- **Concurrent Actions**: Multiple members create, edit, or split expenses simultaneously.
- **Unreliable Hardware**: Sudden app termination, device reboots, out-of-memory kills, and battery-saver background task throttling.

---

## 2. Synchronization State Machine & Lifecycle

Every mutation moves through a formal deterministic state machine:

```
                  ┌───────────────────────┐
                  │    1. Local Action    │
                  └──────────┬────────────┘
                             │ Atomic SQLite WAL write
                             ▼
                  ┌───────────────────────┐
                  │  2. 'localPending'    │◄─── Persisted in mutation_outbox
                  └──────────┬────────────┘
                             │
            ┌────────────────┴────────────────┐
            │ Online                          │ Offline
            ▼                                 ▼
┌───────────────────────┐         ┌───────────────────────┐
│     3. 'syncing'      │         │     4. 'p2pShared'    │ (Exchanged via BLE
│  (HTTP / WebSocket)   │         │  (Nearby Mesh)        │  mesh broadcast)
└───────────┬───────────┘         └───────────┬───────────┘
            │                                 │
     ┌──────┴──────┐                          │ Later reconnects
     │ Success     │ Failure / Timeout        │ to internet
     ▼             ▼                          │
┌─────────┐   ┌───────────────────────┐       │
│ 'synced'│   │ 5. Backoff & Retry    │◄──────┘
│ (Acked) │   │ (jittered backoff)    │
└─────────┘   └───────────┬───────────┘
                          │ HTTP 409 (Revision Mismatch)
                          ▼
              ┌───────────────────────┐
              │ 6. 'conflictReview'   │
              │ (Manual / Auto-Merge) │
              └───────────────────────┘
```

---

## 3. The 10 Offline-First Guarantees

1. **Local-First Authoritative Persistence**: Every write commits to SQLite WAL before any network packet is dispatched.
2. **Crash-Proof Outbox Pattern**: Mutations reside in SQLite `mutation_outbox` across device reboots and app terminations.
3. **Monotonic Event Sequencing**: The cloud database orders all changes via `kith_sync_events.seq (BIGSERIAL)`, preventing clock drift errors.
4. **Non-Destructive Delta Sync**: Incoming server sync merges records rather than performing table wipes.
5. **Deterministic Tombstones**: Deletions propagate via `expense_tombstones` with timestamps, preventing resurrected items from overwriting deletions.
6. **Exponential Backoff with Full Jitter**:
   $$\text{delay} = \min(60\text{s}, 2^{\text{retryCount}} \times 1.5\text{s}) \times (0.8 + 0.4 \times \text{random}())$$
7. **Idempotent Operations**: Client assigns UUID v4 and SHA-256 idempotency key; server replay returns HTTP 200 without creating duplicates.
8. **Dual-Transport Synchronization**: Seamless handover between cloud (HTTPS/WebSocket) and local peer-to-peer (BLE / Wi-Fi Direct).
9. **Late Offline Reopening**: If an offline member submits an expense after trip completion, the trip state automatically switches to `completed_with_pending_changes` rather than dropping the data.
10. **State-Observable Pipeline**: All operations return strongly typed `OperationResult<T>` with distinct sync states (`pending`, `syncing`, `synced`, `failed`, `conflict`).

---

## 4. Root Causes of Historical Data Loss & Duplication

### Historical Defect A: Blind SQLite Table Wipes
- **Mechanism**: `LocalDatabaseService.saveExpenses()` previously executed:
  ```sql
  DELETE FROM expenses WHERE trip_id = ?;
  ```
- **Catastrophic Failure**: When an incoming sync response was partial or delayed, all locally-created offline expenses waiting in `mutation_outbox` were instantly deleted from disk.
- **Architectural Fix**: Replaced with an ID-scoped non-destructive merge:
  ```sql
  DELETE FROM expenses 
  WHERE trip_id = ? 
    AND id NOT IN ('server_id_1', 'server_id_2') 
    AND id NOT IN (SELECT json_extract(payload, '$.id') FROM mutation_outbox WHERE trip_id = ?);
  ```

### Historical Defect B: Stale Tombstone Deletion Gap
- **Mechanism**: Deleting an expense inserted a tombstone record into `expense_tombstones` but left the active row in `expenses` until server sync completed.
- **Catastrophic Failure**: If the app restarted while offline, the local database reloaded the expense as if it were still active.
- **Architectural Fix**: Executed immediate atomic row deletion (`DELETE FROM expenses WHERE id = ?;`) inside the exact same SQLite transaction as the tombstone insertion.

### Historical Defect C: Multi-Tap Duplication
- **Mechanism**: Slow cellular networks delayed the HTTP POST response. Users repeatedly tapped "Save Expense".
- **Catastrophic Failure**: Multiple POST requests generated multiple expenses with identical titles and amounts.
- **Architectural Fix**: Immediate button throttling / debouncing in the UI combined with client-side UUID v4 generation.

---

## 5. Peer-to-Peer (P2P) Mesh Synchronization

For situations where group members are traveling in remote areas without internet access, SplitTrip incorporates Nearby Connections:

### P2P Protocol:
1. **Discovery**: Devices advertise using service ID `com.nirniq.kith.p2p` and trip ID hash.
2. **Handshake**: Authenticate peer identity using the shared trip invite secret.
3. **Payload Exchange**:
   - Each peer transmits their vector clock: `{ deviceId: latestSeq }`.
   - The recipient identifies mutations present in its local database but missing on the peer.
   - Delta payloads are dispatched over high-speed Wi-Fi Direct or Bluetooth channels.
4. **Local Reconcile**:
   - The recipient verifies payloads against `expense_tombstones`.
   - Missing expenses are inserted into local SQLite.
   - P2P-received expenses are flagged `syncState = 'p2pShared'`.
5. **Cloud Catch-Up**: When any group member subsequently connects to cellular data or Wi-Fi, their client pushes all `p2pShared` mutations to the cloud, synchronizing the entire group.

---

## 6. Conflict Resolution Strategy

When two members edit the same expense concurrently:
1. **Attribute-Level Non-Overlapping Merge**:
   - If User A modifies the split breakdown and User B modifies the category or receipt URL, the engine merges both changes automatically.
2. **Overlapping Edit Conflict (HTTP 409)**:
   - If both users edit the expense amount or title concurrently:
   - The backend rejects the second edit with `HTTP 409 Conflict` and returns the current server revision.
   - The client marks the mutation as `SyncStateStatus.conflict` and prompts the user:
     *"This expense was modified by Alice 5 minutes ago. Keep your changes or accept Alice's version?"*
   - No data is silently overwritten or discarded.
