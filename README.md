# harding-corral

Corral is a SQL-first data mapper and table gateway library for Harding. It keeps raw SQL as a first-class tool while making common persistence operations concise.

## Current Features

- table objects via `Corral table:on:` and `Corral table:on:prefix:`
- parameterized `query:with:` and `execute:with:`
- row-to-object mapping using class metadata
- `insert:`, `update:`, `upsert:`, `delete:` and `deleteId:`
- `sql{...}` templates with `$value` and `$(expression)` interpolation
- configurable fallback table prefixes for class-name-based table naming
- SQLite-backed in-memory tests

## Design

- `CORRAL_RFC.md` contains the technical design and roadmap
- `CORRAL.md` contains the higher-level principles and inspiration

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

Player>>id [ ^ id ].
Player>>id: anId [ id := anId. ^ self ].
Player>>name [ ^ name ].
Player>>name: aName [ name := aName. ^ self ].
Player>>score [ ^ score ].
Player>>score: aScore [ score := aScore. ^ self ].

Player class>>id: anId name: aName score: aScore [
  ^ self new
    id: anId;
    name: aName;
    score: aScore;
    yourself
].

conn := Corral on: (SqliteConnection open: ":memory:") prefix: "app".
players := Corral table: Player on: conn.

conn execute: sql{
  CREATE TABLE appPlayer (
    id INTEGER PRIMARY KEY,
    name TEXT,
    score INTEGER
  )
}.

ada := Player id: 1 name: "Ada" score: 1200.
players insert: ada.

found := players byId: 1.
found name println.

topPlayers := players query: sql{
  SELECT *
  FROM appPlayer
  WHERE score >= $(1000 + 200)
} as: Player.

(topPlayers first) name println.
```

## Testing

The library ships with SQLite in-memory tests under `tests/`. From a Harding checkout with Corral installed under `external/corral`:

```bash
nim c -r -d:harding_corral -d:harding_sqlite external/corral/tests/test_corral.nim
```

## Status

Corral is still early and currently focuses on the SQL-first mapper layer. Schema tooling, safe identifier helpers, and block-recorded predicate queries can be added next.
