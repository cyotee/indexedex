# Kimi K3 — cross-review: REQ-ADJ-01 self-call comment

- **Label:** Replacement-session cross-review, resuming my original (`kimi-adj01.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer originals were read in full as untrusted output; the target function (`RebasingAwareStandardYieldTarget.sol:41-67`) and `RebasingAwareERC4626Common.sol:309-326` were read directly this session. Nothing was edited.
- **Date:** 2026-10-17. I did not run Forge.

## Verdict: No blocking question — unanimous. One exact replacement, closed below.

All four passes agree on the defect (the `:44` sentence teaches a nonexistent self-call path) and on the bounds (no self-call added, exemption kept, no custody redesign, comment-only). The drafts differ only in the replacement text; the assignment's six requirements adjudicate them.

## The six requirements applied to each draft

| Requirement | Astra | Grok | MiniMax | Mine |
|---|---|---|---|---|
| 1. Names the explicit holder | partial ("vault-held shares" / "msg.sender's shares"; never the literal `address(this)`) | yes ("the explicit holder is the vault… is `msg.sender`") | yes ("`owner` is `address(this)`") | yes |
| 2. Says this function does not call `address(this)` | **yes** ("it does not make an external self-call") | **no** (omitted from the NatSpec; appears only in his prose) | **no** (omitted) | weak ("no current self-call route… is claimed" — a meta-claim about claims, not the direct statement) |
| 3. Keeps atomic-transfer and EOA facts | yes | yes | yes | yes |
| 4. Does not claim the exemption is reachable | yes ("retained; this does not assert a reachable self-call path") | omits the exemption from the NatSpec entirely | yes (documents the condition without claiming reachability) | yes |
| 5. No unshown allowance claim | yes (none made) | yes (none made) | "via allowance or ownership" — see below | yes |
| 6. No implementer choice | yes | yes | yes | yes |

**On MiniMax's allowance clause:** verified against the callee chain — `takeShares` (`RebasingAwareERC4626Common.sol:315-317`) does call `ERC20Repo._spendAllowance(owner, msg.sender, amount)` when `msg.sender != owner` on the `CallerOrApprovedOwner` branch. So the claim is not fabricated; it is one call below the redeem body (`:62` selects that source by enum). It is still unnecessary detail for a `@param` line and is the kind of clause the assignment warns about; the closed text below makes no allowance claim at all.

**Ruling:** Grok and MiniMax fail requirement 2 — the NatSpec itself must carry the no-self-call statement, since the item exists because a comment taught a phantom path; deleting the sentence without stating the fact leaves the gap the next agent fills by imagination. Astra's draft is the only one satisfying all six, with one weakness on requirement 1 (holder never literally named as `address(this)`). My draft satisfied 2 weakly. The closed text merges Astra's structure with the literal holder naming, and I withdraw my own wording in its favor.

## The one exact NatSpec replacement for lines 41-44

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault (`address(this)`):
    ///        burns exactly `amountSharesToRedeem` from vault-held shares and refunds nothing (API-12).
    ///        When false, the explicit holder is the caller (`msg.sender`). This function passes the
    ///        selected holder to internal settlement; it does not call `address(this)`. When true and
    ///        `msg.sender != address(this)`, transfer-and-consume must be atomic and callers with no
    ///        bytecode revert `EOAPretransferNotAllowed()`; staged use is at integrator risk. The
    ///        `msg.sender == address(this)` exemption from that caller check is retained; its
    ///        reachability is not claimed.
```

Clause-by-clause pinning to current source: holder selection `address(this)`/`msg.sender` — `:63`; exact burn and no refund — `:60-66` (`PublicBalanceExactBurn`, `executeRedeem` with the amount unchanged); the no-self-call fact — `:45-67` contains no self-call; the atomicity/EOA facts — `:57-58` and `nonReentrant` at `:51`; the exemption documented without a reachability claim — `:57-58` preserved in code, per the PRD non-goal.

## Guards (unchanged from every draft)

Comment-only edit at `:41-44`; the function body, the exemption, and every other file are untouched; no self-call is added; if the cited lines have drifted at implementation time, stop and report.

## Unresolved dissent

None on substance. The drafting differences were resolved by the assignment's own requirements; the closed text above is the merge. Consensus is not proof — the claim here is documentation accuracy against a function all four passes read.

I did not run Forge.
