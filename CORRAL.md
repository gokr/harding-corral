# Corral

Corral is the working name for Harding's planned database and query library.

The name comes from The Mysterious Island. A corral is practical, deliberate, and orderly. That is the tone we want for persistence in Harding: a place where data is kept, shaped, and moved with intention, not a magical object world that hides SQL and surprises the user.

## Sources of Inspiration

Corral is not trying to invent database access from scratch. It borrows ideas from several systems that each get part of the story right.

- Debby for code-first models, plain object mapping, codec hooks, and schema checking
- Jet for strong SQL ergonomics and good result mapping without pretending SQL does not exist
- sqlc for the idea that handwritten SQL is worth validating instead of replacing
- Bob for layered adoption and keeping raw SQL available at every level
- GemStone for the Smalltalk idea that a block can be executed against a recording proxy to build a query
- classic Smalltalk table gateway and data mapper styles for explicit persistence APIs such as `users insert: user`

## Core Principles

### SQL First

Corral is SQL-friendly, not SQL-avoidant.

- handwritten SQL remains a first-class path
- joins, aggregates, CTEs, vendor features, and reporting queries should stay easy to express directly
- the abstraction layer should remove boilerplate, not hide the language of the database

### Mapper, Not Full ORM

Corral should be a data mapper with table objects, not a Hibernate-style ORM.

- domain objects stay plain Harding objects
- table objects and repositories perform database I/O
- there is no lazy loading, unit-of-work magic, transparent session state, or hidden query execution

### Code First, With Escape Hatches

Corral should default to code-first metadata.

- class slots map to columns by default
- table and column names can be overridden explicitly
- complex fields can use codecs or JSON-backed storage
- raw SQL is always available when the abstraction stops being helpful

### Safe by Default

Corral should make the safe path the obvious path.

- `sql{...}` interpolation means bound values, not string splicing
- identifiers require an explicit escape hatch such as `Sql ident:`
- prepared statements and bound parameters are the default execution model
- schema validation should be available without requiring live production mutation

### Lean for the 80 Percent Case

The common queries should be concise.

- table objects should support `byId:`, `insert:`, `update:`, `delete:`, `where:`, and `firstWhere:`
- simple query blocks should read naturally in Harding
- more complex queries should drop to SQL instead of forcing a giant query DSL

### Dialect Aware, Not Fake Portable

Corral should share one public model while respecting backend differences.

- common behavior should work across SQLite and MySQL
- dialect-specific SQL should still be possible where needed
- the abstraction layer should not pretend every backend is identical

## Big Ideas

### `sql{...}` Templates

Corral should add a prefix SQL literal similar in spirit to `json{...}`:

```smalltalk
users query: sql{
  SELECT id, email
  FROM users
  WHERE created_at > $someTimestamp
}
```

And for richer Harding expressions:

```smalltalk
users query: sql{
  SELECT *
  FROM users
  WHERE created_at > $(Clock now subtractDays: 7)
}
```

Rules:

- `$name` and `$(...)` are bound values only
- identifiers are never interpolated implicitly
- identifiers require an explicit wrapper such as `Sql ident:`
- the final query sent to the database should be a prepared statement plus bound arguments

### Table Objects

The central object should be a table gateway:

```smalltalk
users := Corral table: User on: conn.

users insert: user.
users update: user.
users delete: user.
users byId: 1.
users where: [:u | (u email = "ada@example.com") & (u createdAt > cutoff)].
```

This style keeps persistence explicit and local.

### Block Queries for Simple Predicates

For the common case, Corral should let a block run against a recording proxy.

```smalltalk
users where: [:u | u email = "ada@example.com"].

users where: [:u |
  (u email = "ada@example.com") | (u email = "grace@example.com")
].
```

The recommended boolean composition operators for query predicates are `&` and `|`.

### Runtime Mapping and Codecs

Corral should map rows to ordinary Harding objects using runtime class metadata.

- default mapping uses slot names and simple type conventions
- custom codecs handle dates, booleans, structured values, and domain-specific representations
- complex fields can fall back to JSON storage when appropriate

### Explicit Schema Work

Corral should help with schema evolution, but not hide it.

- generate `createTableSql`
- compare class metadata to the database with `checkSchema` and `diffSchema`
- keep migration application explicit by default

## What Corral Is Not

Corral is not aiming to be:

- a full ORM with hidden lifecycle behavior
- a replacement for handwritten SQL
- an all-purpose SQL AST builder that models every clause before the first release
- a fake portability layer that ignores backend differences

## Initial Direction

The first useful version of Corral should deliver:

1. parameterized execution shared across SQLite and MySQL
2. `sql{...}` templates with safe value interpolation
3. row-to-object mapping and codec hooks
4. table objects with explicit CRUD messages
5. simple block-based `where:` queries using proxy recording
6. schema metadata and schema diff/check support

## Relationship to Harding

Corral should feel native to Harding rather than imported from another ecosystem.

- it should use prefix literals naturally
- it should lean on Smalltalk-style message sends and blocks
- it should fit Harding's runtime object model and reflection facilities
- it should remain understandable to users who already know SQL and Smalltalk

Corral should be practical, inspectable, and unsurprising.
