---
name: local-user-writing-a-book
description: House rules for writing a technical book. Use when asked to write a book.
---

# Writing a book about a system

## Shape

- One HTML page per chapter, each standalone and readable on its own. Pages get opened individually, not browsed as a set.
- No sidebar and no navigation chrome. A contents page, plus prev/next links at the foot of each chapter, is all the navigation there is.
- Self-contained: no network fetches, no CDN, no companion files a viewer might not resolve. Scripting may be disabled, and the page must still read and link correctly.

## Referencing code

- Every reference to code carries a link to the source in a remote registry: every code listing, and every place the prose names a specific file.
- Cite the file and a line range, and link the exact pinned commit - never a branch. State the pinned commits on the cover page.
- Verify every cited path exists at the pinned upstream commit rather than in the working tree.

## Diagrams

Follow the `local-user-mermaid-diagrams` skill.
