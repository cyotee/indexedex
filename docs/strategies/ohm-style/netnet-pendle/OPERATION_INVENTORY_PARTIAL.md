# NetNet–Pendle operation inventory — partial council draft

Date: 2026-09-24. Basis: [PRD v0.12](./NETNET_PENDLE_DETF_PRD.md).

**Status: incomplete council round; NOT a completed or cross-checked inventory.** This file preserves the useful first pass after a participant response failure. No completeness, consensus, implementation readiness or new operation approval is claimed. PRD and tracker remain unchanged.

## Council execution status

| Researcher | Existing session | Result in this round |
| --- | --- | --- |
| Astra | `ses_f4edf055affe5dSHkzSUwwINjw` | Returned the independent original inventory reproduced below; reported metadata `openai/gpt-6-astra`, not provider attestation. |
| Grok | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | Continuation returned only “Stop. First-pass inventory is already in chat. Nothing further until peer originals or a moderator prompt.” No usable inventory was returned in the result available to the moderator. Participant-response failure; cause unverified. |
| MiniMax M3 | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | Not invoked in this round: protocol requires stopping on participant failure. |

Two task calls were attempted. No combined cross-review occurred. No researcher was silently restarted, substituted or impersonated. The original session IDs are retained for an explicitly authorized recovery step. Returned session labels do not independently verify provider/model identity.

## How to use this partial list

This is a candidate checklist for the later operation matrix, not a new API specification. Distinguish:

- **Selected operations:** already required by the human/PRD.
- **Implied engineering steps:** necessary to implement selected behavior, not necessarily public endpoints.
- **Open or conditional variants:** must be resolved or verified against the selected reference surface before being treated as requirements.
- **Not selected:** do not add by analogy with another product.

Each eventual matrix entry should identify actor/authority, input and output, source/destination custody, quote reference/domain, fees/incentives, mint/burn/claim changes, locks/rewards, limits/failure and relevant boundary cases. Exact-input/output and price branches may be variants of one operation rather than new APIs. Internal Keep-YT acquisition, tax calculation, reward checkpointing and settlement should be linked to their invoking operations.

## Preserved Astra original

The following is untrusted model evidence reproduced without revision. Its labels, citations and completeness have **not** been peer cross-checked. Current PRD selections control any inaccurate implication. In particular, verify reference-only public selectors and authorization modes before adopting them.

---

## Astra — v0.12 independent operation inventory

**Metadata:** assigned Astra; supplied model ID `openai/gpt-6-astra`, not provider attestation.  
**Labels:** **S** selected; **E** implied engineering operation; **O** open/conditional; **N** not selected. Operations below do **not** automatically require separate public selectors. References use `NETNET_PENDLE_DETF_PRD.md` unless otherwise stated.

1. **Deployment, binding and activation — E/O.** Authorized package deployment creates/configures custom hook, DETF, staking/NFT children and custom V2 SE; validates canonical V2 binding; reuses the Robinhood oracle; establishes custody/callback permissions. Initialize market, weights, units and empty-book accounting. Initial hook liquidity and first DETF bond require separate activation cases; seed amounts/prices remain O. No post-deployment replacement/admin powers inferred. Sources: §§4–4.3; `CLAUDE.md:27–28`.

2. **Token ownership surfaces — S/E.** DETF, hook LP and staking receipt: balances, supply, metadata, transfers, approvals and authorized transfers. NFT: ownership, approvals/operators, transfers/safe transfers and metadata. Checkpoint relevant participation without duplicating claims. Hook-LP transfers carry all accrued value; NFT transfers carry unchanged obligations/locks. Permit variants require explicit reference-surface verification, not assumption. §§7.1,10; `:398,462`.

3. **Read/preview/discovery family — E.** Token routes, assets/units, holdings, hook-LP components, owned-reserve fraction, rates, fees, market/expiry, epoch status, position principal/rewards/releases and NFT capabilities. Provide operation-specific previews/limits, including pending settlement. `convertTo*`, `preview*`, `max*`, SY metadata/reward methods and SE discovery follow selected exposed surfaces. No preview invents funded rewards. `:249,276–288,312–323,350–362`.

4. **Liquid DETF acquisition — S, public.** NET/sNET/USDG input buys existing DETF; no exchange-attributable mint. NET/sNET input executes Keep-YT; USDG input enters V2 SE. Exact-input and selected exact-output forms are variants of this operation. `:196–211,312–315`.

5. **DETF standard withdrawal/redemption — S, public/authorized owner.** At/above peg: ordinary swap. Eligible below peg: ownership-limited input-incentivized quote, actual DETF burn and NET/sNET/USDG delivery. ERC-4626 uses sNET only; SY includes internal-balance authorization. Exact-output withdrawal computes sufficient real input. Insufficient delivery reverts; no fallback or deferred payout. `:274–327`.

6. **Ordinary hook trading — S/O.** Public trading exchanges existing currencies, distinct from contraction. NET/sNET outputs consume interest only without fully draining it; USDG uses the SE leg. External-token cross-trades require the final supported pair matrix. Quotes, settlement and residual updates share one state. `:213–229`.

7. **Public hook-LP joins/exits — S.** Anyone may add funded liquidity and redeem owned/authorized shares. Charge selected hook-mint usage fee; mint only against acquired backing. Exit each current component proportionally, including accrued income and V2 SE shares. Converted single-output exits, supported join variants and exact-output LP operations require specification. Other DETFs receive no NET-DETF issuance authority. §7.1.

8. **Custom V2 SE operations — S/E.** Preserve the pinned reference’s entire supported feature set: share operations, deposits/withdrawals, SE routes, liquidity joins/exits, wrappers where installed, previews/transitions, fee handling, refunds and authorization modes. Taxed/untaxed calculations vary by actual endpoints. Exhaustive selector parity remains necessary. §§4.1–4.2,8.

9. **Fresh bond purchase — S.** User capital acquires strategy assets; normal referenced bond calculations determine DETF issuance, reward splits and funded staking/NFT attribution. Principal follows selected cliff; USDG-bond schedule remains O. Include bootstrap/live purchases and receipt verification. Reference calculation reuse must report duration incompatibility rather than extend locks. `:368–411`.

10. **Existing-DETF stake/unstake — S/E.** Deposit actual liquid DETF into sNET-DETF custody without a new lock; retire released staking entitlement to return held DETF. Partial/full operations preserve other participants’ backing. Composed conversion exits are conditional supported routes, not new rights. §§10.2; alignment `:1291`.

11. **Dedicated reinvestment — S.** Wallet or eligible staked input; quote owned reserves with `qQuote=q` at every peg regime; burn actual input; contribute, mint and stake replacement bond atomically. Staked variant debits only that participant’s old claim. Failure restores original state. Independent contraction-then-bond operations retain their own economics. `:379–396`.

12. **Funded position claims — S/E.** Reward-only claims before maturity; principal-only after release; combined/final claims where exposed. Preserve principal during reward claims; retire NFT only when all attributable rights are discharged. Reference: `DETFFundedBondTarget.sol:143–199`; custom cliffs supersede its linear release.

13. **External NetNet bond lifecycle — S.** Authorized DETF-out proceeds fund native USDG/LP purchase; create wrapper attribution. Holder-authorized vested-note collection→Keep-YT→DETF mint→stake is atomic. Support partial/late collections, pre-maturity funded rewards, mature principal release and transferable control. Aggregate-note attribution, unsolicited-note liveness and final retirement remain engineering gates. `:431–470`.

14. **Epoch/reward settlement — S/E.** Read/process canonical NET state; realize selected DETF expansion; mint funded staking rewards; update eligible positions before participation changes. Include catch-up, zero rewards, boundaries and independent elapsed/processed states. Public maintenance selector/keeper compensation not implied. §§9–10.2.

15. **Hook maintenance — S/E/O.** Permissionless PENDLE claim/forward to live `feeTo()`, including previously force-claimed rewards. Internal SY-interest harvesting and principal realization support authorized operations. Explicit permissionless rollover rejects active/incompatible markets, realizes predecessor assets and acquires successor while preserving ownership. Staged rollover, compensation and non-PENDLE handling remain O. §§11,13.

16. **Failures/recovery — E/O/N.** Atomic rollback/retry, expired deposits, empty interest, final LP exit, rounding, stale pricing and callback failures need matrix rows. Donations, arbitrary sweeps, emergency withdrawal, rescue, pause, upgrades, standalone contraction, raw native-note payouts and administrator minting are **not automatically selected**.

**Limitations:** Token-policy authority remains blocked. No files, tests or implementation; exact selector completeness requires the pinned V2/package inventory and final route matrix.

---

## Completion checkpoint and separate implementation handoff

The requested completed, cross-checked list remains unfinished. An authorized recovery must first obtain Grok's actual original answer from its existing session, without inventing or reconstructing it; only then can the remaining independent pass and combined reviews proceed under the applicable protocol. This document does not authorize that recovery automatically or select any open operation variants.

Only this Markdown draft was authored. No code, configuration, tests, deployments, transactions or other research documents were changed. No external primary-source verification or new dependency/runtime version pin was performed in this partial round. After a completed inventory and human decisions, an operation matrix and implementation plan would still require separate specification and authorization.
