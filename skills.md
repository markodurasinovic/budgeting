# Agentic Development Cheatsheet

A one-page daily guide for using agents effectively.

## Core rule
**Use agents for speed. Use your judgment for correctness.**

Never merge code you do not understand.

---

## The default workflow

### 1. Classify the task
Is it a:
- bug
- feature
- refactor
- investigation
- review
- migration

Ask:
- what does done look like?
- what can break?
- what is the smallest safe change?

### 2. Ask for understanding before code
Prompt:
> Help me understand where this behavior lives. Identify likely files, entry points, data flow, tests, and risks. Keep it concise and call out uncertainty.

### 3. Ask for a small plan
Prompt:
> Propose a minimal implementation plan. Include files to change, tests to add, risks, and open questions.

### 4. Make the agent work in steps
Good:
- implement step 1 only
- generate tests only
- review this diff only
- compare 2 approaches

Bad:
- refactor this whole subsystem
- implement everything end to end in one go

### 5. Review hard
Check:
- does it solve the actual problem?
- did it change unrelated code?
- is it consistent with the repo?
- is it too clever?
- what assumptions did it make?
- what tests are missing?

### 6. Validate
Run the narrowest useful checks:
- unit tests
- integration tests if relevant
- lint/typecheck
- manual verification for UX/API behavior

### 7. Use the agent one more time
Prompt:
> Review this final diff skeptically. What are the remaining risks, missing tests, and likely reviewer concerns?

---

## Best uses of agents

### High ROI
- understanding unfamiliar code
- finding where behavior is implemented
- generating first drafts
- generating tests
- debugging hypotheses
- summarizing diffs/PRs
- identifying edge cases
- drafting docs

### Human-led
- architecture decisions
- security-sensitive work
- production-risk decisions
- data migrations with blast radius
- final merge judgment

---

## Prompt templates

### Understand code
> I need to work on [problem]. Explain the current flow, key files, entry points, data transformations, and likely change points. Keep it concise and note uncertainties.

### Plan
> Given this requirement and these files, propose a minimal implementation plan. Include tests, risks, and open questions.

### Minimal patch
> Implement the smallest safe change to achieve [goal]. Do not refactor unrelated code. Preserve public interfaces unless required.

### Tests
> Generate targeted tests for this change. Match existing test style. Focus on regressions, boundaries, and invalid inputs.

### Review
> Review this diff critically. Focus on correctness, edge cases, hidden assumptions, backwards compatibility, and missing tests.

### PR summary
> Summarize this change for a PR. Include problem, approach, files changed, validation, and remaining risks.

---

## Review checklist for agent-generated code

### Correctness
- handles happy path?
- handles failure/edge cases?
- actually matches requirement?

### Consistency
- follows local patterns?
- naming/style matches?
- appropriate abstraction level?

### Risk
- silent behavior changes?
- security/privacy issues?
- performance regressions?
- migration/data risks?

### Tests
- behavior-changing code covered?
- edge cases covered?
- tests prove behavior, not implementation details?

### Scope
- unrelated files changed?
- too much code generated?
- can patch be smaller?

---

## Common anti-patterns
- asking for code before understanding the area
- accepting large patches
- trusting passing tests too much
- keeping clever code you cannot explain
- asking for “best practice” without repo context
- using agents without validation

---

## Daily habit loop
1. Ask for understanding
2. Ask for a plan
3. Implement in small steps
4. Review hard
5. Validate
6. Ask for final risk review
7. Save prompts that worked

---

## Personal policy
- I will not merge code I do not understand.
- I will prefer small, reviewable agent tasks.
- I will validate every generated change.
- I will use agents for leverage, not authority.
