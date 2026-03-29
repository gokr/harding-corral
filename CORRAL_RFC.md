# Corral RFC

## Goal

Add a Harding-native database library named Corral with these properties:

1. plain Harding objects can be mapped to rows and back
2. table objects provide explicit persistence APIs such as `users insert: user`
3. handwritten SQL stays first-class through `sql{...}` templates
4. the common query cases can be expressed tersely with block/proxy predicates
5. SQLite and MySQL share one public model while keeping room for dialect differences

## Non-Goals

Corral is not trying to be:

- a full ORM with lazy loading or hidden unit-of-work behavior
- a replacement for handwritten SQL
- a giant SQL DSL in the style of Hibernate criteria APIs
- a compile-time Nim macro system like Debby

## Why a Harding-Native Design

Harding models are runtime classes, not Nim compile-time types.

That means Debby's public macro surface is not directly reusable even though many of its architectural ideas are still valuable. Corral should therefore borrow from Debby at the mapper and schema layers while using Harding-native syntax and runtime metadata.

## Public Shape

### Main Entry Points

Recommended public classes and objects for the first implementation:

- `Corral` - top-level entry point and convenience factory
- `CorralConnection` - common connection protocol wrapper
- `CorralTable` - table gateway bound to one Harding model class
- `Sql` - SQL helper class for template and identifier operations
- `CorralSchema` - schema inspection and diffing helpers
- `CorralCodec` - optional codec protocol/helper namespace

### Table Gateway API

Recommended API:

```smalltalk
users := Corral table: User on: conn.

users byId: 1.
users all.
users where: [:u | u email = "ada@example.com"].
users firstWhere: [:u | u email = "ada@example.com"].

users insert: user.
users update: user.
users upsert: user.
users delete: user.

users query: sql{SELECT * FROM users WHERE email = $email}.
users query: sql{SELECT id, email FROM users WHERE created_at > $cutoff} as: UserSummary.
users execute: sql{UPDATE users SET last_seen_at = $ts WHERE id = $id}.
```

### Model Defaults

Corral should work with ordinary Harding classes by convention.

Default conventions:

- the model is a plain Harding object
- slot names map to snake_case column names
- no automatic pluralization is performed
- `id` is treated as the primary key by default
- an `id` slot of type `int` is treated as auto-generated unless overridden
- structured values can use a JSON codec fallback when no primitive mapping exists

### Metadata Overrides

The first version should support class-side metadata methods rather than a large builder DSL.

Recommended shape:

```smalltalk
User := Object derivePublic: #(id email displayName createdAt profile)

User class>>corralTableName [ ^ "users" ]

User class>>corralColumns [
  ^ #{
    #id -> #{
      #type -> #integer.
      #primaryKey -> true.
      #auto -> true
    }.
    #email -> #{
      #type -> #text.
      #nullable -> false
    }.
    #displayName -> #{
      #column -> "display_name".
      #type -> #text
    }.
    #createdAt -> #{
      #column -> "created_at".
      #type -> #timestamp
    }.
    #profile -> #{
      #codec -> #json
    }
  }
]
```

The metadata protocol should stay simple and data-shaped so it is easy to inspect and cache.

## `sql{...}` Templates

### Why

Using ordered `?` placeholders is hard to read and easy to get wrong. Harding already has prefix literals, so SQL templates should be expressed in a form that keeps SQL readable while still compiling to prepared statements and bound values.

### Syntax

Recommended syntax:

```smalltalk
sql{SELECT * FROM users WHERE email = $email}
sql{SELECT * FROM users WHERE created_at > $(Clock now subtractDays: 7)}
```

Interpolation rules:

- `$name` inserts a bound value from a variable or identifier expression
- `$(...)` inserts a bound value from an arbitrary Harding expression
- interpolation never produces raw SQL text for normal values

Dynamic identifiers require an explicit wrapper:

```smalltalk
sql{
  SELECT $(Sql ident: #email)
  FROM $(Sql ident: (users tableName))
}
```

### Safety Rules

These rules are recommended as hard guarantees:

- `$name` and `$(...)` always mean bound values unless the resulting object is a special SQL fragment wrapper
- plain strings are never treated as identifier fragments
- raw identifier insertion must use an explicit object such as `SqlIdentifier`

### Parser Strategy

The parser should gain a dedicated `sql{...}` path similar to the current special handling for `json{...}`.

Recommended implementation:

1. keep generic prefix literal support for simple `Prefix{...}` cases
2. add a special parser path for the normalized prefix `Sql`
3. scan the content as raw SQL text with interpolation markers, not as ordinary Harding expressions
4. produce a dedicated AST node such as `SqlTemplateNode`

Why a dedicated AST node instead of a raw string:

- the template needs to preserve static SQL segments separately from embedded Harding expressions
- both interpreter and Granite can lower the same node cleanly
- later validation can attach source locations and interpolation metadata directly to the node

Recommended shape:

```nim
type
  SqlTemplatePartKind = enum
    stpkText,
    stpkExpr

  SqlTemplatePart = object
    kind: SqlTemplatePartKind
    text: string
    expr: Node

  SqlTemplateNode = ref object of Node
    parts: seq[SqlTemplatePart]
```

### Runtime Lowering

At execution time, a `SqlTemplateNode` should become a `CorralSqlTemplate` value containing:

- dialect-neutral text segments
- evaluated argument values
- source metadata for debugging and error reporting

Then the dialect layer produces:

- final SQL text with backend placeholders
- ordered bound argument list

Example:

```smalltalk
sql{SELECT * FROM users WHERE email = $email AND created_at > $cutoff}
```

Could lower to:

- SQLite: `SELECT * FROM users WHERE email = ? AND created_at > ?`
- MySQL: `SELECT * FROM users WHERE email = ? AND created_at > ?`

with argument list `#(email cutoff)`.

## Block Query DSL

### Recommended Surface

Corral should support a deliberately small query block surface for the 80 percent case.

```smalltalk
users where: [:u | u email = "ada@example.com"].

users where: [:u |
  (u email = "ada@example.com") & (u createdAt > cutoff)
].

users firstWhere: [:u | (u email like: "%example.com") | (u email isNil not)].
```

Recommended operators and messages for the first version:

- `=`
- `~=`
- `>`
- `>=`
- `<`
- `<=`
- `like:`
- `in:`
- `isNil`
- `not`
- `&`
- `|`

### Implementation Strategy

Use proxy recording, not AST introspection.

Recommended runtime objects:

- `CorralQueryRowProxy`
- `CorralQueryField`
- `CorralPredicate`

Flow:

1. `users where:` creates a row proxy for the table schema
2. the block is executed with that proxy as its argument
3. unary messages like `u email` are intercepted by `doesNotUnderstand:` on the proxy and become `CorralQueryField` objects
4. comparison messages on `CorralQueryField` create predicate nodes
5. `&` and `|` on predicate nodes build predicate trees

This is intentionally narrow and avoids a full symbolic execution engine.

### Why `&` and `|`

The predicate layer should use `&` and `|` instead of `and:` and `or:`.

Reasons:

- `and:` and `or:` are short-circuit boolean messages in the regular language model
- query predicates are symbolic expressions, not booleans
- `&` and `|` communicate composition more clearly in this context

## Mapper and Codecs

### Mapping Strategy

Corral should map rows to Harding objects through cached runtime metadata.

Recommended layers:

- `CorralModelSpec` - Harding-visible metadata and conventions
- `CorralModelPlan` - Nim-only compiled mapping plan
- `CorralRowMapper` - row-to-object and object-to-row operations

Compiled plan fields should include:

- slot index
- slot name
- column name
- column type kind
- nullable flag
- primary key flag
- auto-generated flag
- codec kind or codec object reference

### Codec Strategy

Corral should borrow Debby's codec-hook idea, but adapt it to runtime classes.

Recommended built-in codec kinds:

- integer
- float
- text
- boolean
- timestamp
- json
- bytes
- nilable wrapper behavior where needed

Recommended extension points:

- symbolic built-ins like `#json` and `#timestamp`
- optional codec objects for custom domain values

Suggested codec protocol:

```smalltalk
MoneyCodec>>dumpSqlValue: aValue
MoneyCodec>>parseSqlValue: aString
```

The Nim layer may also cache direct native codec handlers for built-in cases.

## Schema and Validation

### Schema API

Corral should support explicit schema helpers on `CorralTable` and `CorralSchema`.

Recommended messages:

- `createTableSql`
- `checkSchema`
- `diffSchema`
- `createTable`
- `applyMissingColumns`

Automatic mutation should remain opt-in.

### Validation Layers

Validation should happen in layers:

1. template validity
   - interpolation markers parse correctly
   - identifier wrappers are explicit
2. model validation
   - requested output columns can be mapped to the requested Harding class
3. schema validation
   - known tables and columns exist in the model metadata or schema registry
4. database validation
   - optional live checks against the actual backend during schema operations or dedicated verify commands

The parser should not contact the database.

## Connection and Dialect Architecture

### Common Protocol

Corral should sit above the current SQLite and MySQL libraries and expose a common protocol.

Recommended common messages:

- `query:with:`
- `query:with:as:`
- `execute:with:`
- `transactionDo:`
- `prepare:`
- `close`

### Dialect Layer

Recommended internal dialect objects:

- `CorralDialect`
- `CorralSqliteDialect`
- `CorralMysqlDialect`

Dialect responsibilities:

- placeholder rendering
- identifier quoting
- built-in SQL type names
- auto-increment SQL generation
- timestamp encoding conventions
- schema inspection queries

### Existing Adapter Reuse

Corral should reuse the current database adapters as the transport layer where practical, but the public Corral API should not be tied to their current string-only shape.

The likely path is:

1. extend the Nim side with prepared execution and richer row metadata
2. wrap those capabilities in a common Corral connection object
3. keep the old `query:` and `execute:` entry points as compatibility surfaces on the underlying DB libraries

## Package and File Layout

Recommended initial layout:

```text
lib/corral/
  Bootstrap.hrd
  Corral.hrd
  Sql.hrd
  Table.hrd
  Schema.hrd
  Codec.hrd

src/corral/
  corral.nim
  connection.nim
  dialect.nim
  sqlite_adapter.nim
  mysql_adapter.nim
  sql_template.nim
  mapper.nim
  schema.nim
  query_proxy.nim
  codecs.nim
```

Core parser/runtime changes would still land under `src/harding/` because `sql{...}` needs language support.

## Existing Harding Touchpoints

The implementation should be built around these current realities:

- Harding already supports prefix literals, including a special parser path for `json{...}`
- current SQLite and MySQL support is exposed through thin `query:` and `execute:` APIs
- Harding already supports reflection over slots
- DNU-style proxy recording is possible for unary field access

This means Corral can be native to the language without needing a separate code generator for the initial version.

## Phased Implementation Plan

### Phase 0: Shared DB Core

- add parameterized query execution under a common API
- normalize row metadata and result access
- add transaction helpers
- add prepared statement support and statement caching

### Phase 1: `sql{...}`

- add parser support for SQL templates
- add `SqlTemplateNode`
- add interpreter lowering and execution
- add explicit identifier wrapper support

### Phase 2: Mapper

- build runtime model specs and compiled plans
- add row-to-object and object-to-row mapping
- add built-in codecs and JSON fallback

### Phase 3: Table Gateways

- add `Corral table:on:`
- add CRUD messages and object mapping integration
- add `query:as:` and `execute:` convenience methods

### Phase 4: Block Queries

- add row proxy and field objects
- implement predicate recording with `&` and `|`
- support `where:` and `firstWhere:`

### Phase 5: Schema Layer

- add schema generation, diffing, and checking
- add optional validation of `sql{...}` against known metadata

### Phase 6: Granite Support

- lower `SqlTemplateNode` in Granite
- ensure generated code uses the same template and binding semantics as the interpreter

## Future Extensions

Good later additions:

- named reusable SQL files with verification
- join helpers and projection helpers
- preload helpers for common parent-child cases
- optional CLI schema verify command

## Recommended First Milestone

The first milestone should be intentionally narrow and useful:

1. `query:with:` and `execute:with:`
2. `sql{...}` templates with value interpolation
3. object mapping for direct SQL query results
4. `CorralTable` with `byId:`, `insert:`, `update:`, `delete:`, and `query:as:`

That gives immediate value before the block DSL or schema diff features are finished.
