# .mli Guidelines

## Rule

Every public module must have an `.mli`.

## Constructor visibility

Hide constructors by default. Expose only what is needed for API stability and adapter integration.

## Documentation

Each public module includes:

- module-level purpose comment
- short docs for key values
- notes for unsupported/deferred behavior when relevant
