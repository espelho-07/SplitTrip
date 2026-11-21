# User Activity Error Handling Matrix

**Project:** SplitTrip (KITH)  
**Standard:** Actionable, Contextual, Non-Generic Error Architecture  
**Status:** Complete & Verified  

---

## Complete Error Handling Matrix

| Activity | Failure Condition | Error Category | User Title & Message | Saved Locally? | Reached Server? | Retry Safety | Recovery Action |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **Authentication: Login** | Invalid credentials / recovery key | `ValidationError` | **"Check your recovery key"**<br>The 16-character recovery key was not recognized. Please re-enter. | No | Yes | Safe | Re-type the 16-character recovery key. |
| **Authentication: Login** | Offline during login | `NetworkError` | **"You're offline"**<br>An internet connection is required to sign in with Google or verify your recovery key. | No | No | Safe | Connect to Wi-Fi/data and tap Retry. |
| **Authentication: Registration** | Device registration timeout | `NetworkError` | **"Connection timed out"**<br>We couldn't set up your guest account. Please check your connection. | Yes (Local Guest) | No | Safe | Tap Retry to sync account credentials. |
| **Authentication: Logout** | Network drop during token revocation | `SynchronizationError` | **"Signed out locally"**<br>You are signed out on this device. Cloud token revocation will complete automatically. | Yes | Unknown | Safe | None required; local credentials wiped. |
| **Authentication: Password/Key Reset** | Server unavailable | `ServerError` | **"Server temporarily unavailable"**<br>Could not issue a replacement key right now. Please try again. | No | No | Safe | Wait a few minutes and retry. |
| **Authentication: Session Expiration** | Token expired (401) | `AuthenticationError` | **"Session expired"**<br>Please sign in again or use your recovery key to continue syncing trips. | Yes (Cache Kept) | Yes | Unsafe (Until Sign In) | Sign in with Google or enter recovery key. |
| **Trip: Create Trip** | Offline during trip creation | `SynchronizationError` | **"Trip created on device"**<br>Your trip is ready! It will sync and generate a shareable invite code once online. | **Yes** | No | Safe | No action needed; auto-syncs when online. |
| **Trip: Create Trip** | Missing trip name | `ValidationError` | **"Enter a trip name"**<br>Please give your trip a name before continuing. | No | No | Safe | Enter a name and tap Create Trip. |
| **Trip: Join Trip** | Offline during join attempt | `NetworkError` | **"You're offline"**<br>An internet connection is required to verify and join this trip. Connect and try again. | No | No | Safe | Connect to internet and tap Retry Join. |
| **Trip: Join Trip** | Invalid / Nonexistent code (404) | `ValidationError` | **"Trip not found"**<br>No trip found matching this invite code. Check the code with your host. | No | Yes | Unsafe | Verify the 6-character code with the trip creator. |
| **Trip: Join Trip** | Already a member (409) | `ConflictError` | **"Already joined"**<br>You are already a participant in this trip. Opening trip dashboard... | Yes | Yes | Unsafe | None; app automatically opens trip view. |
| **Trip: Accept Invitation** | Expired claim token | `ValidationError` | **"Invitation expired"**<br>This invitation is no longer active. Request a new link from the host. | No | Yes | Unsafe | Ask trip host to re-send invite. |
| **Trip: Reject Invitation** | Offline during rejection | `SynchronizationError` | **"Invitation declined"**<br>Declined on this device. Sync will update the host when online. | Yes | No | Safe | Auto-syncs when connection returns. |
| **Trip: Leave Trip** | Outstanding balance owed | `ValidationError` | **"Settle balances before leaving"**<br>You have unsettled expenses in this trip. Settle up with members to leave. | No | No | Unsafe | Pay outstanding settlement debts first. |
| **Trip: Leave Trip** | Host cannot leave active trip | `AuthorizationError` | **"Assign new host"**<br>As trip creator, please transfer host permissions before leaving. | No | No | Unsafe | Assign another member as host. |
| **Trip: Delete Trip** | Non-creator delete attempt (403) | `AuthorizationError` | **"Access unavailable"**<br>Only the trip creator can delete this trip. | No | Yes | Unsafe | Contact trip creator to request deletion. |
| **Trip: Edit Trip** | Concurrent name edit conflict | `ConflictError` | **"Update conflict detected"**<br>Another member updated trip details. We have refreshed with the latest information. | Yes | Yes | Unsafe | Review latest details and re-apply edit. |
| **Trip: Complete Trip** | Unsynced participants offline | `SynchronizationError` | **"Participants pending sync"**<br>Some members have un-synced expenses. Wait for them to sync or force complete. | Yes | Yes | Safe (Force Override) | Wait for members to reconnect or tap Force Complete. |
| **Trip: Complete Trip** | Stale trip revision | `ConflictError` | **"Trip updated"**<br>New expenses were recorded while finalizing. Review latest balances. | Yes | Yes | Safe | Review updated balance summary and retry. |
| **Participant: Add Participant** | Duplicate participant name | `ValidationError` | **"Member name already exists"**<br>A member with this name is already in the trip. Use a nickname. | No | No | Safe | Enter a unique name or surname. |
| **Participant: Remove Participant** | Member has recorded expenses | `ValidationError` | **"Member has expenses"**<br>Cannot remove a member with recorded expenses or active debts. | No | No | Unsafe | Reassign or delete member's expenses first. |
| **Participant: Change Details** | Offline during rename | `SynchronizationError` | **"Member updated on device"**<br>Name changed locally; will sync to the group automatically. | **Yes** | No | Safe | No action needed; auto-syncs. |
| **Participant: Assign Roles** | Non-admin role assignment | `AuthorizationError` | **"Admin permission required"**<br>Only trip admins can change participant roles. | No | Yes | Unsafe | Request host to elevate your role. |
| **Expense: Add Expense** | Offline during expense add | `SynchronizationError` | **"Expense saved on device"**<br>Your expense was saved locally. It will sync automatically when back online. | **Yes** | No | Safe | Continue using app; auto-syncs when online. |
| **Expense: Add Expense** | Split sum mismatch | `ValidationError` | **"Split total mismatch"**<br>Total participant shares do not equal the total expense amount. | No | No | Safe | Adjust split sliders/amounts to match total. |
| **Expense: Add Expense** | Multi-payer sum mismatch | `ValidationError` | **"Payer total mismatch"**<br>Amounts contributed by payers do not equal total expense amount. | No | No | Safe | Re-distribute payer contributions to equal total. |
| **Expense: Edit Expense** | Concurrent edit by another user | `ConflictError` | **"Expense was modified"**<br>Another member edited this expense. Latest changes loaded. | Yes | Yes | Unsafe | Review latest values and re-edit if desired. |
| **Expense: Delete Expense** | Offline during deletion | `SynchronizationError` | **"Expense deleted locally"**<br>Expense removed from your view. Cloud deletion queued. | **Yes** | No | Safe | Auto-syncs deletion tombstone when online. |
| **Expense: Split Expense** | Non-positive percentage/share | `ValidationError` | **"Invalid split value"**<br>Percentage and share values must be greater than zero. | No | No | Safe | Enter positive numbers for all members. |
| **Expense: Change Payer** | Selected payer not a member | `ValidationError` | **"Select a valid payer"**<br>The chosen member is no longer in this trip. | No | No | Safe | Choose an active member from the roster. |
| **Expense: Upload Receipt** | Image exceeds size limit / timeout | `StorageError` | **"Receipt upload paused"**<br>Could not upload image right now. Expense saved without image. | **Yes (Expense Saved)** | No | Safe | Re-attach receipt when connection improves. |
| **Settlement: Record Payment** | Network drops mid-payment submit | `UnknownOutcomeError` | **"Checking payment status"**<br>Interrupted while recording payment. Checking server to avoid duplicates. | **Yes** | Unknown | Safe | Tap Check Status to verify receipt. |
| **Settlement: Confirm Payment** | Non-recipient confirm attempt | `AuthorizationError` | **"Confirmation restricted"**<br>Only the payment recipient can confirm receipt of funds. | No | Yes | Unsafe | Recipient must log in to confirm payment. |
| **Settlement: Edit Settlement** | Settlement already confirmed | `ValidationError` | **"Settlement already confirmed"**<br>Confirmed payments cannot be edited. | Yes | Yes | Unsafe | Record an adjustment payment instead. |
| **Settlement: Delete Settlement** | Payment already reconciled | `ConflictError` | **"Payment finalized"**<br>This settlement has already been reconciled into trip totals. | Yes | Yes | Unsafe | Dispute transaction with payment receiver. |
| **Sync: Initial Sync** | Server unreachable | `NetworkError` | **"Syncing paused"**<br>Could not connect to sync service. Operating in offline mode. | **Yes** | No | Safe | Tap Retry or continue offline. |
| **Sync: Background Sync** | Token invalid during periodic sync | `AuthenticationError` | **"Session needs refresh"**<br>Background sync paused. Tap to refresh credentials. | **Yes** | Yes | Safe | Tap banner to sign in or refresh session. |
| **Sync: Manual Sync** | Outbox queue drain timeout | `SynchronizationError` | **"Sync in progress"**<br>Your changes are safely queued. Retrying background sync. | **Yes** | Partial | Safe | Allow sync engine to backoff and retry. |
| **Sync: Conflict Resolution** | Multiple devices edit same field | `ConflictError` | **"Resolve update conflict"**<br>Simultaneous changes detected on this expense. Choose version. | **Yes** | Yes | Safe | Choose local or remote version in dialog. |
| **Sync: Offline Recovery** | App terminated during sync | `SynchronizationError` | **"Resuming sync"**<br>Recovered pending changes from device storage. Resuming sync. | **Yes** | No | Safe | Automatic; no user action needed. |
