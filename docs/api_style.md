# API Style

## Opaque types

Core HTTP structures use opaque types in `.mli` files to preserve refactor safety.

## Naming

- Nouns for values (`Request`, `Response`, `Headers`)
- Verbs for actions (`with_header`, `redirect`, `router`)
- Small stable top-level API under `Thunder`

## Top-level philosophy

Top-level `Thunder` re-exports common modules and offers convenience constructors without hiding lower-level modules.
