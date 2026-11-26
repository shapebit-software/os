---
name: documentation
description: Plan, create, restructure, review, and maintain ShapeBit project documentation, including architecture, ADRs, roadmaps, and verified project-state updates. Use for documentation work across ShapeBit repositories; do not use for implementation-only changes.
---

# Documentation

Make ShapeBit documentation accurate, coherent, actionable, and maintainable.
Preserve the distinction between decisions, proposals, plans, and observed
behavior.

## Establish the documentation context

Before changing content:

1. Read the applicable repository instructions.
2. Inspect the worktree and identify repository or submodule boundaries.
3. Find the documentation entry points, indexes, templates, build commands, and
   link-checking tools provided by the repository.
4. Identify the canonical source for each relevant fact. Do not edit generated
   sites, copied output, or mirrors when an editable source exists.
5. Read the relevant decisions, current design, plans, component documentation,
   and implementation evidence before reconciling them.

Investigate uncertainty that can be resolved from the repository. Ask the user
when the remaining ambiguity requires a product or architecture choice; do not
guess and present the guess as current truth.

## Classify every material claim

Keep these categories visibly distinct, using the repository's own terminology
when it defines an equivalent model:

- **Verified behavior**: supported by current code, configuration, tests, build
  artifacts, or runtime evidence appropriate to the claim.
- **Accepted decision**: explicitly approved and binding, even when it is not
  implemented yet.
- **Proposed design**: a candidate that still requires review or validation.
- **Planned work**: intended work with a clear completion or evidence condition.
- **Unknown**: not established by the available sources.

Documentation, scaffolding, syntax checks, and plans are not runtime evidence.
Never silently promote proposed work to accepted, planned work to completed, or
documented behavior to verified behavior.

## Route the work by purpose

### Plan the next work

- Start from the current verified state, accepted constraints, open proposals,
  and explicitly recorded gaps.
- Define outcomes, dependencies, boundaries, and acceptance evidence rather
  than only listing activities.
- Use explicit completed and outstanding markers when the canonical tracker
  supports them.
- Update the canonical tracker instead of creating a parallel roadmap or
  temporary continuation document.
- A documentation-only request does not authorize implementation changes.

### Develop or change architecture

- Establish which document or decision owns each affected concern before
  editing summaries.
- Describe system boundaries, invariants, interfaces, alternatives,
  consequences, risks, and re-evaluation conditions at the level needed for
  the decision.
- Route durable choices through the repository's decision process. New
  decisions start as proposed unless the user explicitly accepts them.
- When the repository uses ADRs, do not rewrite an accepted decision in place
  to reverse it; add a superseding ADR and update the decision index and
  summaries.
- Keep living design documents aligned with authoritative decisions without
  allowing a summary to override them.

### Record current project state

- Verify state against the owning repository and the kind of evidence required
  by the claim.
- State what was observed, where it was observed, and what remains unverified.
- Treat dates, versions, dependency behavior, and external facts as potentially
  stale and verify them when they matter.
- Do not infer end-to-end success from the existence of individual components
  or from a narrower passing check.

### Maintain and restructure documentation

- Remove duplication by retaining one canonical explanation and linking to it
  from summaries and entry points.
- Resolve contradictions in favor of authoritative, current evidence. If two
  authoritative sources conflict, surface the conflict rather than choosing
  silently.
- Preserve useful history in decision records; remove stale navigation,
  duplicated plans, and obsolete references when their replacement is clear.
- Keep implementation and UX details close to their owning component. Keep
  cross-system architecture, security invariants, and ownership boundaries in
  the system-level documentation.
- Use terminology, naming, status labels, and link style consistently across
  all touched documents.

### Prepare published documentation

- Edit the canonical source, not a generated publication tree.
- Preserve stable public links when practical; update navigation and incoming
  repository links when paths must change.
- Keep internal planning, unresolved security details, and operational secrets
  out of public documentation unless publication is explicitly intended and
  appropriate.

## Make coherent changes

- Respect the requested scope. Update related indexes, summaries, navigation,
  and ownership maps only when the primary change makes them stale.
- Prefer direct, precise prose. Keep repository content in the language and
  style required by its instructions.
- Record confirmed decisions only. When presenting alternatives, make the
  recommendation and tradeoffs clear without treating the recommendation as an
  accepted decision.
- Keep repository boundaries visible. Review and report changes in a parent
  repository and its submodules independently.

## Validate

Use the validation supplied by the repository. At minimum, when applicable:

1. Review the complete diff in every affected repository.
2. Run `git diff --check`.
3. Check local Markdown links and navigation.
4. Run the documented site or documentation build when publication behavior
   changed.
5. Reconcile decision indexes, statuses, backlinks, and supersession links.
6. Confirm that completed markers and verified claims have matching evidence.

Report the documentation outcome, the evidence checked, validation results,
remaining unknowns, and any decisions that still require explicit confirmation.
