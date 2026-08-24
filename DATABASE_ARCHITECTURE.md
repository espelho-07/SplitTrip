# Kith PostgreSQL Database Architecture (Supabase Staging & Production)

This document details the production-grade PostgreSQL architecture for Kith, replacing file-based JSON storage with a transactional relational database.

---

## 1. High-Level Architecture

```
Flutter Mobile App (Android / iOS)
       │ (HTTPS / WSS REST & WebSocket)
       ▼
Node.js API Server (Render / Express)
       │ (Encrypted Pool Connection via DATABASE_URL)
       ▼
PostgreSQL Relational Database (Supabase Managed Instance)
```

> **Security Invariant**: Flutter NEVER connects directly to Supabase/PostgreSQL and NEVER receives database passwords or service-role keys. The Node.js backend remains the trusted authentication, authorization, and financial validation boundary.

---

## 2. Core Relational Schema

### A. `users` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Stable user ID (`usr_...`) |
| `display_name` | `VARCHAR(255)` | `NOT NULL` | User's full display name |
| `avatar_url` | `TEXT` | `NULL` | Optional avatar profile picture URL |
| `recovery_key_hash` | `VARCHAR(64)` | `NOT NULL, INDEX` | SHA-256 hash of recovery key (`KITH-XXXX-XXXX`) |
| `is_guest` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Guest identity indicator |
| `email` | `VARCHAR(255)` | `NULL` | Future verified email |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Registration timestamp |
| `last_active_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Last API activity |

---

### B. `sessions` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | UUID session identifier |
| `token` | `VARCHAR(255)` | `NOT NULL UNIQUE, INDEX` | Bearer session token (`kith_sess_...`) |
| `user_id` | `VARCHAR(64)` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | Associated user |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Session issue timestamp |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL, INDEX` | Expiration timestamp (1 year rolling) |

---

### C. `trips` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Stable trip ID (`trip_...`) |
| `name` | `VARCHAR(255)` | `NOT NULL` | Trip name |
| `description` | `TEXT` | `NULL` | Optional description |
| `emoji` | `VARCHAR(32)` | `DEFAULT '✈️'` | Trip avatar emoji |
| `cover_gradient_index`| `INT` | `DEFAULT 0` | Cover banner theme gradient index |
| `currency_code` | `VARCHAR(3)` | `NOT NULL DEFAULT 'INR'` | ISO currency code (INR, USD, EUR, GBP) |
| `creator_id` | `VARCHAR(64)` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | Trip creator |
| `invite_code` | `VARCHAR(12)` | `NOT NULL UNIQUE, INDEX` | 6-character alphanumeric join code |
| `lifecycle_state` | `VARCHAR(32)` | `NOT NULL DEFAULT 'active'` | `active`, `completed`, `settling`, `settled` |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Last modified timestamp |

---

### D. `trip_members` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Membership ID (`mbr_...`) |
| `trip_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trips(id) ON DELETE CASCADE` | Associated trip |
| `user_id` | `VARCHAR(64)` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` | User membership |
| `display_name` | `VARCHAR(255)` | `NOT NULL` | Name within trip |
| `avatar_url` | `TEXT` | `NULL` | Avatar URL |
| `role` | `VARCHAR(32)` | `NOT NULL DEFAULT 'member'` | `creator`, `admin`, `member` |
| `joined_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Join timestamp |

*Composite Invariant*: `UNIQUE(trip_id, user_id)` prevents accidental duplicate memberships.

---

### E. `expenses` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Expense ID (`exp_...`) |
| `trip_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trips(id) ON DELETE CASCADE` | Associated trip |
| `title` | `VARCHAR(255)` | `NOT NULL` | Expense description |
| `amount_in_paise` | `BIGINT` | `NOT NULL CHECK (amount_in_paise > 0)` | Integer smallest currency units |
| `category` | `VARCHAR(64)` | `NOT NULL DEFAULT 'general'` | Expense category |
| `paid_by_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE`| Payer member |
| `split_type` | `VARCHAR(32)` | `NOT NULL DEFAULT 'equal'` | `equal`, `shares`, `percentage`, `custom` |
| `voice_transcript`| `TEXT` | `NULL` | Original voice transcription |
| `receipt_url` | `TEXT` | `NULL` | Attached receipt document/image |
| `is_deleted` | `BOOLEAN` | `NOT NULL DEFAULT FALSE` | Soft delete flag |
| `deleted_at` | `TIMESTAMPTZ` | `NULL` | Soft delete timestamp |
| `created_by_id` | `VARCHAR(64)` | `NOT NULL` | Creator user ID |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Update timestamp |

---

### F. `expense_splits` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Split ID (`split_...`) |
| `expense_id` | `VARCHAR(64)` | `NOT NULL REFERENCES expenses(id) ON DELETE CASCADE`| Associated expense |
| `member_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE`| Participant member |
| `amount_in_paise` | `BIGINT` | `NOT NULL CHECK (amount_in_paise >= 0)` | Exact individual share in paise |
| `shares` | `INT` | `NULL` | Share units for share-based splits |
| `percentage` | `INT` | `NULL` | Percentage basis |

*Composite Invariant*: `UNIQUE(expense_id, member_id)` guarantees one split per member per expense.

---

### G. `settlements` Table
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Settlement ID (`stl_...`) |
| `trip_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trips(id) ON DELETE CASCADE` | Associated trip |
| `from_member_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE`| Debtor member |
| `to_member_id` | `VARCHAR(64)` | `NOT NULL REFERENCES trip_members(id) ON DELETE CASCADE`| Creditor member |
| `amount_in_paise` | `BIGINT` | `NOT NULL CHECK (amount_in_paise > 0)` | Settle amount in paise |
| `payment_reference`| `TEXT` | `NULL` | Payment reference or note |
| `note` | `TEXT` | `NULL` | Settle note |
| `is_settled` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Completion flag |
| `recorded_by_id` | `VARCHAR(64)` | `NOT NULL` | Recording user ID |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Record timestamp |
| `settled_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT NOW()` | Settlement timestamp |

---

## 3. Financial Integrity & Zero-Sum Guarantees
1. **Integer Money Representation**: All monetary values are strictly stored as `BIGINT` representing the currency's smallest atomic unit (e.g. `paise` for INR, `cents` for USD/EUR, `pence` for GBP). Floating point database types (`FLOAT`, `REAL`, `DOUBLE PRECISION`) are prohibited.
2. **Atomic Multi-Entity Transactions**: Expense creation and split recording occur inside single atomic database transactions (`BEGIN ... COMMIT`).
3. **Conservation Invariant**: $\sum(\text{expense\_splits.amount\_in\_paise}) \equiv \text{expenses.amount\_in\_paise}$.

---

## 4. Migration & Deployment Instructions

### Local Development:
```bash
# Run schema migrations
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/kith" node scripts/migrate_json_to_pg.js
```

### Staging on Supabase / Render:
1. In Supabase Dashboard, obtain the PostgreSQL Connection String (`URI`).
2. Add `DATABASE_URL` to Render Staging Environment Variables.
3. The server runs migrations automatically upon startup or deployment script execution.
