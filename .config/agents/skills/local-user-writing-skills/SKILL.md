---
name: local-user-writing-skills
description: How to write a SKILL.md. Use when asked to create, extract or edit a skill, or to capture what was learned in a session as a reusable instruction.
---

# Writing skills

A skill is the delta between what a capable model does by default and what I actually want. Nothing else belongs in it.

## Include

- Preferences a model cannot infer: formats, conventions, tools to use, things never to do.
- Corrections I have made, restated as the rule they imply.
- Non-obvious technical traps — a failure whose cause is hard to find, worth the lines it takes to describe. Say what breaks and how to avoid it.
- Places where the obvious approach is wrong, and what to do instead.

## Leave out

- **Anything a smart model already does well.** Do not explain how to approach the work: which subagents to spawn, how to sequence phases, how to divide or parallelise the job, how to research before writing. Assume competence and say nothing.
- **The story of the session that produced the skill.** No "in this project", no "the book we wrote", no explanation of why a past decision was made. A reader with no knowledge of that session must lose nothing.
- **Anything that varies per task** — lengths, counts, structures, the number of chapters or sections or diagrams. If the right answer is "as many as needed", the rule does not belong here.
- **Anything another skill already says.** Refer to it by name instead, and add only what it is missing.
- General good practice, background explanation, and motivation. If a line would survive being deleted without changing behaviour, delete it.

## Form

- Declarative and imperative. `Don't add sidebars.` `Link every code reference to a pinned commit.` Not `it turned out that…`, not `I chose to…`.
- Short. A skill that fits on one screen gets followed; a long one gets skimmed. Twenty good lines beat two hundred.
- Group rules under plain headings so a specific rule can be found without reading the whole file.
- Do not guess the header. The file format and the frontmatter fields are specified at <https://agentskills.io/specification>; read it if anything beyond `name` and `description` is needed.
- Of those fields, only `name` and `description` are normally worth setting. Spend the effort on the `description`: it is all that is loaded until the skill activates, so it must name the trigger phrases and situations, not just the subject.
- Follow the `local-user-writing-md` skill for markdown: one line per paragraph and per list item, no hard wrapping.
- Nested and supporting files are fine for reference material — a long table, a template, a script — but `SKILL.md` itself stays the short rulebook.

## When extracting a skill from work just done

Go through what happened and keep only two categories: what I corrected, and what cost real time to discover. Everything else felt significant while doing it and is noise in a rulebook. Expect the result to be much shorter than the session felt.
