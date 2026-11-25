---
name: kiro-specs
description: Transform product ideas, requirements, and bug reports into structured implementation-ready specifications with requirements, design, and tasks. Use when creating feature specs, user stories with acceptance criteria, technical design documents, bugfix analysis, or breaking work into executable implementation tasks.
---

# Specification-Driven Development

Transform product ideas, requirements, and bug reports into structured, implementation-ready specifications that enable clear collaboration between product and engineering teams.

## When to Use

Use this skill when the user asks to:
- Create a spec, requirements doc, technical design, or implementation plan
- Break a feature idea into user stories with acceptance criteria
- Analyze a bug (current vs. expected behavior)
- Decompose approved work into executable tasks

Do not use for direct implementation without a spec — complete Phase 1 before Phase 2, and Phase 2 before Phase 3.

## Spec Location

Write each spec to `.kiro/specs/<kebab-case-feature-name>/` with:

- `requirements.md` (features) or `bugfix.md` (bugs) — Phase 1
- `design.md` — Phase 2
- `tasks.md` — Phase 3

Create the directory if it does not exist. Never mix two features in one spec directory.

## How to Run

1. Determine spec type (feature vs. bugfix) and spec name. Confirm both with the user if ambiguous.
2. Execute Phase 1, then STOP and get explicit user approval before starting Phase 2.
3. Execute Phase 2, then STOP and get explicit user approval before starting Phase 3.
4. Execute Phase 3. When implementing tasks, update task checkboxes in `tasks.md` (`- [ ]` → `- [x]`) as work proceeds.
5. If requirements or design decisions change mid-implementation, update the spec files first (living documentation).

## Capabilities

- **Break down requirements** into clear user stories with well-defined acceptance criteria.
- **Analyze bugs** by documenting current behavior, expected behavior, and behavior that must remain unchanged.
- **Create technical design documents** covering system architecture, component interactions, data flow, sequence diagrams, error handling, and testing strategy.
- **Decompose designs into implementation tasks** that are discrete, actionable, and independently trackable.
- **Track implementation progress** across individual tasks and maintain task status as development proceeds.
- **Bridge product and engineering** by translating business requirements into technically actionable specifications while keeping the original product intent intact.

## Core Structure

Every specification produces three key files that form the foundation of the implementation:

### `requirements.md` / `bugfix.md`

Defines **what needs to be built or fixed**.

- Feature specifications contain user stories and acceptance criteria.
- Bugfix specifications contain:
  - Current behavior
  - Expected behavior
  - Unchanged behavior
  - Root-cause analysis where applicable

### `design.md`

Defines **how the solution should be built**.

Includes:

- System architecture
- Component design
- Data flow
- Sequence diagrams
- API and integration considerations
- Error handling
- Testing strategy
- Technical constraints and implementation considerations

### `tasks.md`

Defines **how the implementation will be executed**.

Includes:

- Discrete implementation tasks
- Clear task outcomes
- Dependencies between tasks
- Task status and progress tracking
- Tasks that can be executed individually or as a complete implementation plan

## Three-Phase Workflow

All specifications follow a structured three-phase workflow:

### Phase 1 — Requirements / Bug Analysis

Translate the initial idea, requirement, or bug report into a precise definition of the problem.

**For features:**

- Identify users and use cases.
- Create user stories in the form: `As a <role>, I want <goal>, so that <benefit>.`
- Define acceptance criteria in verifiable EARS style, e.g.:
  ```
  - WHEN <condition> THEN the system SHALL <expected result>
  ```
- Identify functional and non-functional requirements.

**For bugs:**

- Document current behavior.
- Define expected behavior.
- Identify behavior that must remain unchanged.
- Analyze the likely cause when sufficient information is available.

### Phase 2 — Design

Translate the requirements into a technical implementation approach.

- Research the existing codebase first (relevant files, patterns, integrations) and ground the design in what actually exists. Do not invent APIs or components that already have an established pattern.
- Define system architecture.
- Identify components and their responsibilities.
- Describe data flows and interactions.
- Create sequence diagrams where useful.
- Define APIs, database changes, and integrations.
- Specify error handling and edge cases.
- Define the testing strategy.

### Phase 3 — Tasks

Convert the approved design into an executable implementation plan.

- Break the solution into discrete tasks.
- Give each task a clear outcome.
- Write each task as a checkbox (`- [ ] Task description`) and reference its requirement, e.g. `_Requirements: 1.2, 2.1_`.
- Establish task dependencies where necessary.
- Keep tasks small enough to implement and review independently.
- Track task status as implementation progresses.
- Support executing tasks individually or the complete plan sequentially.

## Guiding Principles

- **Requirements before implementation** — clarify what should be built before deciding how to build it.
- **Design before tasks** — implementation tasks should be derived from an agreed technical design.
- **Traceability** — every implementation task should be traceable back to a requirement or design decision.
- **Small, executable tasks** — avoid vague tasks such as "implement the feature"; define concrete outcomes.
- **Explicit acceptance criteria** — requirements should be objectively verifiable.
- **Product-engineering alignment** — preserve business intent while making technical implications explicit.
- **Incremental progress** — implementation status should remain visible throughout development.
- **Living documentation** — update specifications when significant requirements or design decisions change.
