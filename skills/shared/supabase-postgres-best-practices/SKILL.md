---
name: supabase-postgres-best-practices
description: "Postgres best practices maintained by Supabase, for Postgres running anywhere. Load this skill BEFORE writing or changing anything that lives in a Postgres database: creating or altering tables and columns (including choosing column types), schema design, migrations and declarative schema files, RLS policies and the tests that verify them, indexes, triggers, database functions, queues and scheduled jobs (pg_cron, pgmq), vector/semantic search (pgvector), and restoring dumps (pg_restore) or importing data. Also load it when diagnosing slow queries, high CPU, timeouts, EXPLAIN plans, connection exhaustion, locking, bloat, or rows visible to the wrong user or tenant. This is not just a performance guide — schema, migration, security, and SQL authoring tasks need these rules too, even for a one-column change or a single query."
license: MIT
metadata:
  author: supabase
  version: "1.1.1"
  organization: Supabase
  date: January 2026
  abstract: Comprehensive Postgres performance optimization guide for developers using Supabase and Postgres. Contains performance rules across 8 categories, prioritized by impact from critical (query performance, connection management) to incremental (advanced features). Each rule includes detailed explanations, incorrect vs. correct SQL examples, query plan analysis, and specific performance metrics to guide automated optimization and code generation.
---

# Supabase Postgres Best Practices

Comprehensive performance optimization guide for Postgres, maintained by Supabase. Contains rules across 8 categories, prioritized by impact to guide automated query optimization and schema design.

## When to Apply

Reference these guidelines when:
- Writing SQL queries or designing schemas
- Implementing indexes or query optimization
- Reviewing database performance issues
- Configuring connection pooling or scaling
- Optimizing for Postgres-specific features
- Working with Row-Level Security (RLS)

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
|----------|----------|--------|--------|
| 1 | Query Performance | CRITICAL | `query-` |
| 2 | Connection Management | CRITICAL | `conn-` |
| 3 | Security & RLS | CRITICAL | `security-` |
| 4 | Schema Design | HIGH | `schema-` |
| 5 | Concurrency & Locking | MEDIUM-HIGH | `lock-` |
| 6 | Data Access Patterns | MEDIUM | `data-` |
| 7 | Monitoring & Diagnostics | LOW-MEDIUM | `monitor-` |
| 8 | Advanced Features | LOW | `advanced-` |

## How to Use

Read individual rule files for detailed explanations and SQL examples.

**Query Performance (critical):** [query-missing-indexes.md](references/query-missing-indexes.md), [query-partial-indexes.md](references/query-partial-indexes.md), [query-composite-indexes.md](references/query-composite-indexes.md), [query-covering-indexes.md](references/query-covering-indexes.md), [query-index-types.md](references/query-index-types.md)

**Connection Management (critical):** [conn-pooling.md](references/conn-pooling.md), [conn-limits.md](references/conn-limits.md), [conn-idle-timeout.md](references/conn-idle-timeout.md), [conn-prepared-statements.md](references/conn-prepared-statements.md)

**Security & RLS (critical):** [security-rls-basics.md](references/security-rls-basics.md), [security-rls-performance.md](references/security-rls-performance.md), [security-privileges.md](references/security-privileges.md)

**Schema Design (high):** [schema-primary-keys.md](references/schema-primary-keys.md), [schema-data-types.md](references/schema-data-types.md), [schema-constraints.md](references/schema-constraints.md), [schema-foreign-key-indexes.md](references/schema-foreign-key-indexes.md), [schema-partitioning.md](references/schema-partitioning.md), [schema-lowercase-identifiers.md](references/schema-lowercase-identifiers.md)

**Concurrency & Locking (medium-high):** [lock-short-transactions.md](references/lock-short-transactions.md), [lock-advisory.md](references/lock-advisory.md), [lock-deadlock-prevention.md](references/lock-deadlock-prevention.md), [lock-skip-locked.md](references/lock-skip-locked.md)

**Data Access Patterns (medium):** [data-n-plus-one.md](references/data-n-plus-one.md), [data-batch-inserts.md](references/data-batch-inserts.md), [data-pagination.md](references/data-pagination.md), [data-upsert.md](references/data-upsert.md)

**Monitoring & Diagnostics (low-medium):** [monitor-explain-analyze.md](references/monitor-explain-analyze.md), [monitor-pg-stat-statements.md](references/monitor-pg-stat-statements.md), [monitor-vacuum-analyze.md](references/monitor-vacuum-analyze.md)

**Advanced Features (low):** [advanced-full-text-search.md](references/advanced-full-text-search.md), [advanced-jsonb-indexing.md](references/advanced-jsonb-indexing.md)

Category definitions live in [_sections.md](references/_sections.md); maintaining the rules follows [_contributing.md](references/_contributing.md) and [_template.md](references/_template.md).

Each rule file contains:
- Brief explanation of why it matters
- Incorrect SQL example with explanation
- Correct SQL example with explanation
- Optional EXPLAIN output or metrics
- Additional context and references
- Supabase-specific notes (when applicable)

## References

- https://www.postgresql.org/docs/current/
- https://supabase.com/docs
- https://wiki.postgresql.org/wiki/Performance_Optimization
- https://supabase.com/docs/guides/database/overview
- https://supabase.com/docs/guides/auth/row-level-security
