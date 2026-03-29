# harding-corral

Corral is a SQL-first data mapper and table gateway library for Harding. It keeps raw SQL as a first-class tool while making common persistence operations concise.

## Current Features

- table objects via `Corral table:on:`
- parameterized `query:with:` and `execute:with:`
- row-to-object mapping using class metadata
- `insert:`, `update:`, `upsert:`, `delete:` and `deleteId:`
- `sql{...}` templates with `$value` and `$(expression)` interpolation
- SQLite-backed in-memory tests

## Installation

```bash
./harding lib install corral
nimble harding
```

Or manually clone it into Harding's external library directory:

```bash
cd /path/to/harding/external
git clone https://github.com/gokr/harding-corral.git corral
nimble discover
nimble harding
```

## Example

```smalltalk
Harding load: "lib/corral/Bootstrap.hrd".

Player := Object derive: #(id, name, score).
Player class>>corralTableName [ ^ "players" ].

conn := Corral on: (SqliteConnection open: ":memory:").
players := Corral table: Player on: conn.

conn execute: sql{
  CREATE TABLE players (
    id INTEGER PRIMARY KEY,
    name TEXT,
    score INTEGER
  )
}.

players execute: sql{
  INSERT INTO players (id, name, score)
  VALUES ($(1), $("Ada"), $(1200))
}.

((players byId: 1) slotAt: #name) println.
```

## Testing

The library ships with SQLite in-memory tests under `tests/`. From a Harding checkout with Corral installed under `external/corral`:

```bash
nim c -r -d:harding_corral -d:harding_sqlite external/corral/tests/test_corral.nim
```

## Status

Corral is still early and currently focuses on the SQL-first mapper layer. Schema tooling, safe identifier helpers, and block-recorded predicate queries can be added next.
