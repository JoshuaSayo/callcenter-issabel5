# Domain docs

How engineering skills consume this repository's domain documentation.

## Before exploring

Read these when they exist:

- `CONTEXT.md` at the repository root.
- ADRs under `docs/adr/` that affect the area being changed.

If either location is absent, proceed silently. Do not create placeholder domain files merely to satisfy the layout. Domain documentation should be added when terminology or architectural decisions are actually resolved.

## File structure

This is a single-context repository:

```text
/
|-- CONTEXT.md
|-- docs/
|   `-- adr/
`-- src/
```

The repository currently uses legacy top-level and module directories rather than a required `src/` tree. The diagram describes where future domain documentation belongs; it does not require restructuring the application.

## Use the glossary vocabulary

When output names a domain concept in code, tests, issues, documentation, or review findings, use the term defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids.

If the required concept is missing, reconsider whether the term belongs to the project. If it represents a real domain gap, record it for later domain modeling rather than silently inventing competing language.

## Flag ADR conflicts

If proposed work conflicts with an existing ADR, identify the conflict explicitly instead of silently overriding the decision.
