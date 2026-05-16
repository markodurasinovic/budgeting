# budgeting

A small terminal budgeting application written in Rust, backed by PostgreSQL.

## Goals

This project aims to stay small, understandable, and practical:

- Rust + Cargo
- terminal/TUI-style interaction
- PostgreSQL as the persistent source of truth
- code that is readable to someone learning Rust

Unlike the earlier version, this app now uses the Rust `postgres` crate directly for database access. That makes the persistence layer substantially cleaner than shelling out to `psql`.

---

## High-level architecture

The application is split into six modules:

- `src/main.rs`
- `src/app.rs`
- `src/db.rs`
- `src/models.rs`
- `src/storage.rs`
- `src/tui.rs`

### `main.rs`

Process bootstrap:

1. load database configuration from environment variables
2. connect to PostgreSQL
3. ensure the schema exists
4. create `App`
5. enter the main interaction loop

### `app.rs`

The orchestration layer.

Responsibilities:

- render the home screen
- dispatch menu commands
- implement add/edit/delete/report/import/reload flows
- maintain the in-memory snapshot used by the UI
- keep the snapshot and database in sync

This is where most user-facing behavior lives.

### `db.rs`

The persistence boundary.

Responsibilities:

- build the Postgres connection config
- connect using `postgres::Client`
- create the schema if needed
- load entries from SQL rows
- insert/update/delete entries
- import CSV rows inside a transaction

This module is intentionally the only part of the app that knows SQL.

### `models.rs`

Domain types and parsing helpers.

Responsibilities:

- `Entry`
- `SimpleDate`
- date parsing and validation
- money parsing and formatting
- string truncation helpers for the TUI

This module has no terminal logic and no database logic.

### `storage.rs`

CSV import support.

Responsibilities:

- parse app-format CSV
- parse the legacy sample format
- turn CSV rows into `Entry` values for import
- expose a tiny CSV parser for local use

The database is the system of record. CSV is only an import mechanism.

### `tui.rs`

Terminal I/O helpers.

Responsibilities:

- clear the terminal
- read prompts
- enforce required prompts
- pause between screens
- render the command prompt

This keeps `app.rs` from being cluttered with repetitive `stdin/stdout` plumbing.

---

## Runtime model

The app uses a **database-backed snapshot model**.

### Startup

At startup:

1. `main` constructs `DatabaseConfig`
2. `Database::connect` opens a Postgres client
3. `Database::ensure_schema` creates the table if necessary
4. `App::load` reads all entries into memory

### Reads

The UI renders from an in-memory `Vec<Entry>`.

That keeps the interaction logic simple:

- list views do not need a DB roundtrip
- reports can be computed in memory
- edit/delete selection is easy to implement

### Writes

Mutations are write-through:

- **Add**: insert into Postgres, receive generated id, push into memory
- **Edit**: update Postgres, then update the in-memory entry
- **Delete**: delete from Postgres, then remove from memory

### Reload

`[Y]Sync` discards the local snapshot and reloads from the database.

This is the mechanism for observing out-of-band database changes.

---

## Why the `postgres` crate is the right choice here

This app previously used `psql` subprocesses because of a strict no-third-party-crate constraint.

Once a Postgres crate became allowed, switching was the obvious move.

### Benefits of the crate-based approach

- parameterized queries instead of manual SQL string interpolation
- typed row access
- no subprocess spawning overhead
- transaction support for CSV import
- cleaner error handling
- cleaner architecture overall

This is materially safer and easier to maintain than the `psql`-shelling approach.

---

## Database schema

The app auto-creates this table:

```sql
CREATE TABLE IF NOT EXISTS entries (
    id BIGSERIAL PRIMARY KEY,
    entry_date DATE NOT NULL,
    item TEXT NOT NULL,
    category TEXT NOT NULL,
    amount_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Notes

- `id` is the stable row identity used for edit/delete
- `entry_date` is the logical date of the transaction
- `amount_cents` is an integer by design to avoid decimal precision bugs
- `updated_at` is updated explicitly by the application on row edits

---

## Configuration

Connection settings are read from environment variables.

The app prefers `BUDGETING_*` variables and falls back to standard `PG*` variables where relevant.

| Variable | Fallback | Default |
|---|---|---|
| `BUDGETING_PGHOST` | `PGHOST` | `localhost` |
| `BUDGETING_PGPORT` | `PGPORT` | `5432` |
| `BUDGETING_PGDATABASE` | `PGDATABASE` | `budgeting` |
| `BUDGETING_PGUSER` | `PGUSER`, then `USER` | current shell user or `postgres` |
| `BUDGETING_PGPASSWORD` | `PGPASSWORD` | unset |

Example:

```bash
export BUDGETING_PGHOST=localhost
export BUDGETING_PGPORT=5432
export BUDGETING_PGDATABASE=budgeting
export BUDGETING_PGUSER=markodurasinovic
export BUDGETING_PGPASSWORD=postgres
```

---

## Building and running

### Build

```bash
cd ~/dev/budgeting
cargo build
```

### Run

```bash
cargo run
```

---

## Command model

Main menu:

- `[A]dd`
- `[E]dit`
- `[D]elete`
- `[L]ist`
- `[R]eport`
- `[I]mport`
- `[Y]Sync`
- `[Q]uit`

The UI is line-based because the standard library does not expose a portable raw-terminal API. The commands are still intentionally short so the interaction feels lightweight.

### Add

Prompts for:

- item
- category
- amount
- date

Date entry supports partial forms:

- blank -> today
- `DD` -> current month/year
- `DD/MM` -> current year
- `DD/MM/YYYY` -> exact date

### Edit

Rows are edited by stable database id, not by display index.

That choice is important because the in-memory vector is re-sorted frequently. Display order can change; primary keys do not.

### Delete

Deletes by stable database id and requires confirmation.

### Report

Generates a month-scoped report showing:

- entry count
- month total
- totals by category
- every row in the selected month

### Import

Imports CSV rows into Postgres.

Supported formats:

1. app format
   - `Date,Item,Category,Amount`
2. legacy format
   - `Date,Item,Price,...`

Legacy import behavior is generic:

- first three columns are interpreted as transaction fields
- dates are read as `MM/DD/YYYY`
- category is set to `Uncategorized`

No item-name-specific categorization logic is hardcoded.

### Sync

Reloads the in-memory snapshot from the database.

---

## Domain model details

### Entry

`Entry` is the central domain type:

- `id: i64`
- `date: SimpleDate`
- `item: String`
- `category: String`
- `amount_cents: i64`

### Money

Amounts are stored as integer cents.

Examples:

- `12` -> `1200`
- `12.5` -> `1250`
- `12.50` -> `1250`
- `-7.25` -> `-725`

Why this matters:

- no floating point rounding surprises
- simple integer aggregation
- straightforward rendering back to a human format

### Dates

The app uses a custom `SimpleDate` type instead of a date crate.

That type handles:

- partial input parsing
- validation
- leap years
- `DD/MM/YYYY` display for humans
- `YYYY-MM-DD` rendering for SQL parameters

---

## Query strategy

### Loading entries

`db.rs` runs a normal SQL query:

```sql
SELECT id, entry_date::text, item, category, amount_cents
FROM entries
ORDER BY entry_date, item, category, id;
```

Rows are then mapped into `Entry` values.

### Inserts

Adds use a parameterized statement with `RETURNING id`:

```sql
INSERT INTO entries (entry_date, item, category, amount_cents)
VALUES ($1::date, $2, $3, $4)
RETURNING id;
```

### Updates

Edits use a parameterized `UPDATE`:

```sql
UPDATE entries
SET entry_date = $1::date,
    item = $2,
    category = $3,
    amount_cents = $4,
    updated_at = NOW()
WHERE id = $5;
```

### Deletes

Deletes are a simple keyed delete:

```sql
DELETE FROM entries WHERE id = $1;
```

### Import transaction

CSV import is wrapped in a database transaction.

That means a failed import row aborts the entire import rather than leaving the DB partially updated.

For a local utility, that is a much saner failure mode than partial success.

---

## CSV import pipeline

Import flow:

1. user chooses `[I]mport`
2. app reads the file path
3. `storage.rs` parses the CSV into `Entry` values with `id = 0`
4. `db.rs` inserts them inside a transaction
5. app reloads the DB snapshot

The import parser supports both the app's own format and the legacy sample spreadsheet layout.

---

## Sorting and reporting semantics

The snapshot is sorted by:

1. date
2. item
3. category
4. id

Recent-entry views reverse that order to show the newest rows first.

Reports are currently computed in memory from the loaded snapshot rather than pushed into SQL.

That is a conscious simplicity trade-off:

- the likely dataset is small
- the logic is easy to read
- the UI already depends on the snapshot

If the dataset grows, monthly aggregation should move into SQL.

---

## Error handling philosophy

This is a small interactive application, so the error handling model is intentionally simple:

- most functions return `Result<T, String>`
- database and parsing errors are converted into human-readable messages
- startup failures abort early
- interactive flow errors bubble up to the top-level runner

This keeps the code approachable and easy to trace.

In a larger system, a structured error hierarchy would likely be warranted.

---

## Current limitations

1. **Line-based terminal interaction**
   - no raw-mode key handling
   - standard-library limitation unless a TUI/input crate is introduced

2. **In-memory reporting**
   - category totals are computed client-side
   - acceptable for small datasets, not ideal for large ones

3. **No duplicate detection on import**
   - importing the same file twice duplicates rows

4. **No migration framework**
   - schema management is a startup `CREATE TABLE IF NOT EXISTS`

5. **No tests yet**
   - parsers and flows would benefit from focused tests

---

## Recommended next steps

If continuing to evolve this project, the most valuable next improvements would be:

1. move monthly/category aggregation into SQL
2. add duplicate detection or import idempotency
3. add search and filtering by item/category/date range
4. add tests for date parsing, money parsing, and CSV parsing
5. introduce a real terminal UI crate if you want richer interaction
6. add schema migrations once the data model becomes less stable

---

## Example workflow

Run the app:

```bash
cargo run
```

Import your old CSV:

```text
[I]mport
CSV path: /Users/markodurasinovic/dev/accounting - April 2026.csv
```

Then:

- `[L]ist` to inspect imported rows
- `[E]dit` to assign better categories
- `[R]eport` to inspect a month
- `[Y]Sync` if the DB changes outside the app

---

## Summary

This is a deliberately small PostgreSQL-backed budgeting app:

- Rust terminal application
- direct Postgres integration through the `postgres` crate
- simple module structure
- CSV retained as an import path only
- readable code and explicit control flow

It is not aiming to be a full finance platform. It is a compact, maintainable personal budgeting tool with a real relational backend and a codebase that is easy to reason about.
