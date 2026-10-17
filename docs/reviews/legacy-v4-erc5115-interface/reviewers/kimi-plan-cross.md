# Kimi K3 — plan cross-review: legacy V4 ERC-5115

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax's draft is a labeled replacement (`ses_ebdf718feffemWQNf7wuTpapqX`), not continuity of `ses_ec41255ceffeVhrySLQe8hwwMC`. My plan draft is `kimi-plan.md` in this directory. The three peer drafts were read in full as untrusted model output. The controlling PRD (`../REMEDIATION_PRD.md`) and the named interface file were re-read in my own pass. Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Assigned ruling: the plan can be written with no implementer choice — agree

All four drafts converge on the same executable shape, and the PRD itself closed the previously contested points (the deposit flag carries no new caller gate, `:59`; no facet split; no parallel class; the declaration sites). The shared closed set, identical in substance across Astra, Grok, MiniMax (with the corrections below), and my draft:

- Nine Pendle identities removed; the non-payable five-argument `deposit` added; `redeem` and the six reads retained with identical selectors; both `type(IStandardizedYield).interfaceId` declaration sites (`UniswapV4StandardExchangeDFPkg.sol:162`, `UniswapV4StandardExchangeOutMultiQueryFacet.sol:20`) replaced in place; the IN facet array becomes exactly `exchangeIn` + ERC-5115 `deposit` + `redeem`; the OUT multi-query array becomes exactly `previewExchangeOutOneToMany` + the six ERC-5115 reads; owners do not move.
- The existing yield target is edited in place; the validation order, the REQ-V4-02 disable checks, the holder rules, the events, and the `_settleNamedHolder` shape are preserved.
- `depositFromInternalBalance` forwards literally as the SE `pretransferred` argument; no `LocalCreditLib.requirePretransferCaller` is added on the token path (the PRD's dissent records my and Astra's withdrawn alternative).
- Shared SY files, the vendored Pendle interface, and every other family are untouched.

## Corrections to MiniMax's draft (compile-breaking, so not stylistic)

I verified both against the shared sources:

1. **MiniMax step 1 keeps the query target's inheritance while deleting `assetInfo` and narrowing the validity overrides to "internal"** (`minimax-plan.md:40,47,51`). That cannot compile: `NativeStandardYieldDiscoveryTarget.sol:16` declares `assetInfo` as an unimplemented `virtual`, so a concrete target that stops implementing it while still inheriting the base fails to compile; and a `public view override` cannot be narrowed to `internal` over a public virtual. The detach variant — stop inheriting the shared preview/discovery targets and implement the six reads directly — is not a preference but the compilable shape (Astra step 2, Grok step 3, my step 3). **Sentence the plan must use:** "The query target stops inheriting the shared Pendle preview/discovery targets and implements the six ERC-5115 reads directly; the inherited virtuals cannot be kept, because the shared base leaves `assetInfo` unimplemented and the validity overrides cannot narrow visibility."
2. **MiniMax step 3 declares the yield target `is …, IERC5115_StandardizedYield, …`** (`:117-120`). The interface has eight functions; the money target supplies two; the concrete `UniswapV4StandardExchangeInFacet` would then have to implement the six query functions or fail to compile. Astra anticipated this exactly (`astra-plan.md:47`). **Sentence the plan must use:** "The money target declares functions whose signatures match the interface without inheriting `IERC5115_StandardizedYield`; the proxy's composition — typed selector arrays, package registration, and proxy-level ERC-165 — is what establishes the interface, per the PRD."

## The deposit's exact call form: adopt Astra's over Grok's

Grok's true-flag branch (`grok-plan.md:36`) calls the custody helper directly and then mints. Astra's form (`astra-plan.md:63`) forwards the flag through the existing internal `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)`. Astra's is the faithful read of the PRD's "call the existing token transfer helper with `pretransferred` true" (`:59`) because it preserves the existing route's structure — lock, funding, issuance, reserve sync, TWAP, and the current `block.timestamp` deadline convention (`NativeStandardYieldTarget.sol:56`) — rather than reconstructing custody-plus-mint by hand. Adopted into the closed set.

## Notes adopted from peers without change

- Astra's dedicated `UniswapV4StandardExchange_ERC5115.t.sol` (surface enumeration, both deposit modes including the code-less positive control for the owner-selected absence of a new gate, the nonpayable-ABI negative, event-field equality) is the closed test addition; the PRD's acceptance criteria (`:76-81`) require a true-flag witness the existing suites do not contain. Grok's retarget-only set is the minimum; the coordinator should pick Astra's superset — it is the only draft that covers PRD `:79` behaviorally.
- MiniMax's pre-flight hygiene (toolchain record, cache preservation) is fine except **pre-flight 0.4** (`:20`: "`git status` must show only the files this plan lists … If unrelated modifications exist, stop and report"). That contradicts this repository's shared-tree rule — unrelated working-tree changes are recorded and preserved, not a stop condition. Replace with: "Record the pre-existing working-tree changes and preserve them; do not reset them."

## Unresolved dissent

None that survives the compile checks above: the two MiniMax deviations are objectively unbuildable as written, not alternative architectures. The deposit-flag dissent from the previous round is settled by the PRD (`:93`) and no pass reopens it. Consensus is not proof, but the disagreements here were resolved by reading the shared bases, not by counting votes.

I did not run Forge.
