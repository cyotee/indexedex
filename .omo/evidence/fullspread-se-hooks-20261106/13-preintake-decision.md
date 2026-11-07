# Pre-intake ownership interpretation

## Superseded by the user's clarification

The user clarified that initialization supplies every required leg, with
either SE shares or pairToken for each SE-backed leg, not both components.
The user also confirmed that ongoing single-leg deposits were supported
and asked to resume the task after the implementation regression was
explained.

The prohibition below was the agent's overly broad interpretation, not an
owner lock. It must not disable a properly paid conversion/swap stage that
prepares a caller-funded basket for an ongoing single-leg join. Restore
those routes, preserve their public APIs, and evaluate proportional LP
issuance against the book after completed paid swaps and before crediting
the remaining contribution. Conversion costs and refunds remain attributed
to the caller; no incumbent assets are given away as missing contributions.

Initialization may acquire SE shares from the caller's pairToken inside the
route before applying the actual five-percent share-redemption seed rule.
The user's clarification supersedes the earlier shares-only input restriction.
Earlier rejection-based single-input and pair-bootstrap test expectations
are historical evidence, not the current acceptance contract.

The DETF funding-model question and its timeout no longer gate this repair.
The task is to restore the previously supported ongoing behavior under the
clarified accounting, not introduce a new complete-basket DETF public API.

## Historical interpretation

Date: 2026-11-07. The clarification question timed out. The user instructed
continuation to completion using best judgment and not to ask that question
again this turn. This is the parent's implementation interpretation of the
existing PRD, not an owner-approved amendment or approval of post-trade
ownership.

Follow FS-HOOK-07 literally:

- Snapshot every incumbent native component and actual LP supply before
  crediting this join's input.
- Assemble each caller's contribution from their supplied pair tokens,
  SE shares, actual conversion outputs and refunds.
- Do not trade against incumbent hook inventory to manufacture missing
  caller components before taking a replacement snapshot.
- A positive gross mint must satisfy every positive component of the
  original book. Where supplied assets cannot assemble that basket, fail
  atomically rather than subsidize missing components.
- Keep valid multi-input, flexible share-funded and share-only genesis
  routes. Zero-component topologies must not be blanket-disabled.
- Preserve actual swap and exit curves/fees; this interpretation concerns
  join ownership, not a new trading restriction.

Tests introduced during this execution that assumed paid incumbent swaps
and post-trade snapshots are not acceptance authority. They must enforce
the original-book invariant and full rollback for impossible baskets.
Original required FullSpread swap positives and independent valid
multi-input joins remain positive tests.

The parent owns weighted, Balancer and shared behavior changes. Separate
source-only tracks own CP single, dual, Orbital and Curve. All compilation
and execution remains serialized under the parent. Existing task-16/gas
receipts remain historical evidence; affected behavior will be revalidated
after these changes.
