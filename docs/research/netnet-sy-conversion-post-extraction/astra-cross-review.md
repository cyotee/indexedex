# Astra — bounded combined cross-review

**Date/access:** 2026-09-28. One combined review of the three complete originals, not peer cross-reviews. My `astra-original.md` remains unchanged. Research only; no implementation, tests, shell, deployment, delegation or configuration changes.

## 1. Inputs and source checks

Read together as attributed, untrusted model evidence:

- **Grok** (`xai/grok-4.7`), `grok-original.md`, all434 lines.
- **MiniMax M3** (`minimax/MiniMax-M3`), `minimax-original.md`, all309 lines; initial truncated result continued through line309.
- **Kimi K3** (`kimi-code-plan-global/k3`, high), `kimi-original.md`, all191 lines.

All are in `docs/research/netnet-sy-conversion-post-extraction/`. No peer cross-review or historical council findings were read. Peer assertions are not permission grants or authority to change product economics.

Directly rechecked **E** = `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`: target43–185; base204–270; ERC20 guard679–715 and mint/burn877–915. Rechecked local **N** = `lib/crane/contracts/protocols/pol/net/src/`: `Staking.sol:88–161`, `StakedNET.sol:25–138`, `NET.sol:121–146`; `contracts/vaults/basic/BasicVaultCommon.sol:25–139`; current PRD:300–334. Original-pass source reads and PRD citations remain applicable.

Source URL remains <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources>, accessed through local decoded evidence, not freshly fetched. Identity unchanged: chain4663 candidate proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`, service implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, exact-match47105638; external solc0.8.30+commit.73712a01, optimizer1,000,000, Cancun, viaIR=true. No local compiler authorization or fresh runtime proof follows. No external API/library documentation claim was needed.

## 2. Disposition in brief

I retain my original branch equations, post-stake interpretation, false-flag hook custody path, nominal-minimum warning, atomic rollback analysis, checked domains and shared-budget sequence. Grok and Kimi provide substantial independent agreement. MiniMax identifies some correct formulas and concerns but repeatedly contradicts the source on identity, custody, ordering and rollback; its proposed §6.5 text must not be adopted as written.

**My material addition/correction:** my original gives the exact *minimum sufficient* SY debit but does not finish **exact-output equality and excess-output disposition** for the entire permitted index domain. Grok correctly surfaces that omission. I accept the mathematical concern, not Grok's proposed unconditional “revert every unrepresentable exact-output amount” as a settled product rule. Full route composition remains unfinished until the required ERC4626 route has a source-compatible delivery/residual specification or a demonstrated incompatibility is explicitly resolved.

## 3. Identity, decimals and custody corrections

### 3.1 SY is not its yieldToken

**Retain Astra; agree with Grok's distinction; correct MiniMax:33–36,64,68,213–219,270.** The SY proxy exposes its own `PendleERC20Upg` balance/supply ledger. `yieldToken` is an immutable address returned by `getOrCreate(sNet,18)`. `scaledNet` is separately returned by `getOrCreate(net,18)` and named by `assetInfo()`. Neither wrapper is the SY ERC20 itself (E:43,58–66,204–214,679–692).

The constructor requests an18-decimal wrapper and reads its decimals to initialize SY's immutable decimals. Thus18 is the intended/conditional value, **not proven solely by the function argument** when factory/wrapper implementation and actual immutable observations are missing. Kimi:19,28 initially treats18 as observed and later:174 calls it inferred; retain the latter qualification. Grok:39 goes too far if it requires a wrapper implementation body merely to prove SY's immutable value: verified deployed SY metadata/immutable evidence can establish that value without executing a wrapper money route. Missing wrap/unwrap implementation must not block unused routes.

### 3.2 Mint receiver versus backing holder

E:240–245 pulls input from **msg.sender**, converts it, then mints SY to the explicit **receiver** argument. Receiver need not equal payer, hook, or SY. For NET ingress with immediate staking delivery, raw sNET backing is held by the SY proxy; receipt shares are held by the chosen receiver. For direct sNET ingress, raw sNET also enters SY custody. The names “holder of backing” and “holder of SY shares” are not interchangeable.

MiniMax:152–159 alternates between automatic SY custody, automatic caller custody and a proposed canonical SY receiver. None follows from `_mint(receiver,...)`. I reject the proposed default of parking ordinary hook inventory at SY itself. Kimi:92's “notionally via staking inventory” should be narrowed: with warmup0, SY actually holds sNET; staking holds NET payout inventory. Nonzero warmup is a distinct backing-availability problem, not ordinary immediate custody.

### 3.3 Correct burn flag

E:262–266 is conclusive: false burns caller's SY balance; true burns SY's own SY balance. Hook-owned ordinary inventory therefore uses **false with hook as actual caller**. It does not require an SY allowance or transfer into staking. NET unstake pulls **sNET backing from the SY**, not SY shares from the user, and transfers NET from staking's balance (`N/Staking.sol:119–125`). It does not mint NET. MiniMax:55,186,203,219 are incorrect.

True is a legitimate external branch only with correctly established SY-held shares; it is not a per-depositor authenticated internal ledger. Grok:95's “transfer ... is the only way” is also too narrow: a deposit can explicitly mint to receiver=SY. This does not make that public, unattributed custody a suitable persistent hook reserve.

## 4. Minimum ordering, reentrancy and rollback

**Retain Astra; agree Grok/Kimi; reject MiniMax:161,165,194,225–227,276.** Exact order from E:252–270:

```text
validate token/nonzero → burn → _redeem (including external unstake/transfer)
→ compare nominal amountTokenOut with minTokenOut → event
```

The minimum is checked **after** the external conversion/payout call returns, not before. It still compares a **nominal computed value**, not a measured receiver delta. Deposit minimum is after pull/stake/conversion and before mint (E:240–245).

An uncaught downstream revert unwinds the SY call, including its preceding burn and nested token/staking changes. There is no source-backed “persisted burn despite failed unstake.” If an outer contract catches a failed SY call, the failed SY frame still rolls back; earlier successful outer steps need not. The selected family therefore propagates required failure to unwind the *whole route*, including earlier claims/input/observations. It does not “absorb a burn,” restore shares manually or require a compensating state snapshot.

Sequential deposit then redeem after the first call has returned is not reentrancy. The guard sets ENTERED on entry and resets NOT_ENTERED on return (E:703–715). Nested callback entry while the first call is active is the guarded case. MiniMax's same-transaction prohibition is unsupported.

## 5. Projection, preview parity and zero circulation

### 5.1 NET post-stake index is intentional

MiniMax:46,233,256,275 calls a confirmed preview bug and recommends a multiplicative correction. **Reject.** E:84–87 calls stake **before** reading current index. The local stake rebases first (`N/Staking.sol:88–94`), and local StakedNET stores exactly the nested-floor projection (`N/StakedNET.sol:83–99`). With matched constants/state/behavior, the post-stake current index equals the pre-call one-step projected index. No formula drift is established. Dividing by a larger projected index would also produce fewer, not more, shares relative to a stale smaller index, contrary to MiniMax's direction claim.

Retain Astra's conditional parity: external NET pull/callback/state effects must be accounted for; actual deployed equivalence remains G1. Warmup0 is needed for immediate backing delivery, **not for the local post-rebase index equality itself**. This sharpens Grok:153 and my original framing: nonzero warmup can preserve numerical preview equality while making the minted claims lack immediately held new sNET.

### 5.2 Multiple overdue epochs still project one step

Agree with Kimi:85 and Grok:122–143; reject Kimi:115's conflicting “≤1 epoch overdue, else current.” `_syncedIndex` has no missed-count alternative. One stake/unstake realizes one step even if many epochs remain overdue. Re-evaluating `_syncedIndex` afterward may project **another** step, not return the newly current index. MiniMax:105's assumption that the new end must exceed now is false; its:116 recommendation to call rebase n times is not accepted.

A bounded required pre-sync may exist in a larger authorized route, but its presence must be specified and modeled as an actual step; it is not a fix for a nonexistent preview bug. No catch-up loop is introduced by this review.

### 5.3 Zero circulating and zero profit

Source is exact: C==0 returns current index in E:118–120. Local staking **does not call sNet.rebase at all** in that branch (`N/Staking.sol:138–144`), contrary to part of MiniMax:112. It retains queued distribution, increments end/number once, checkpoints oracle and adds distributor output. With positive circulation but zero queued profit, staking calls sNET rebase(0), which leaves supply/index unchanged, then advances epoch. Index unchanged does not mean epoch/queue unchanged.

MiniMax:100's “systematically underestimates ... post-rebase index” is false for the matching reference: the nested floors are the **same** in projection and actual rebase. There is no established treasury-directed discrepancy.

Kimi:77/162 and MiniMax:258 overstate “strictly more” NET than sNET: integer rounding, zero profit, zero circulation or cap can make outputs equal. Nor is the raw-unit difference automatically value accruing only to remaining SY holders: a recipient of raw sNET participates in subsequent sNET rebases. The branch asymmetry is observed; a universal economic winner/solvency conclusion is not.

## 6. Exact inverses, nested floors and overflow

Let A=10^18 and I be the branch index evaluated from its complete state. Retain:

```text
redeem(q) = floor(q*I/A)
q_min(y) = ceil(y*A/I)
deposit(x) = floor(x*A/I)
x_min(s) = ceil(s*I/A)
```

For positive I the inverse is exact **minimum sufficient input at fixed state**, proved by forward≥target and predecessor<target. Computing I with nested floors does not turn this result into merely an upper bound. MiniMax:139 confuses inverting index formation with inverting amount conversion. We are not solving backward for queued profit or supply.

Retain all original forward checked domains: x*A≤uint256.max, q*I≤uint256.max, checked p*T and T+floor(p*T/C) **before** cap, valid subtraction/divisors, mint total≤uint248.max and current owner-set SY cap, plus actual balances/allowances/local transfer domains. Kimi:110's bound for “any representable share supply” is not established by uint248 storage. MiniMax's approximate constants and `2^312` bounds are numerically wrong: G/F is approximately2.316e58, J approximately2.316e67; multiplying an approximately2^224 J by uint248 is approximately2^472, not2^312. A loose J bound is also not the actual maximum index under the128-bit supply cap. Use exact inequalities rather than these estimates.

Grok:174–177 correctly warns about naive ceil overflow, but treats overflow of the chosen inverse expression as a necessary external domain limit. It is not: a full-width inverse or quotient/remainder formulation can avoid intermediate `y*A + I - 1` overflow. The external **forward** constraints must still hold. This preserves my original distinction. Also I=0 causes deposit/inverse division failure, whereas raw source redemption itself multiplies by0 and returns nominal0 if other calls/guards permit; do not assert every source branch divides by I.

## 7. Exact-output representability — my original's missing boundary

**Evidence changing my assessment:** Grok:188–190 explicitly distinguishes minimum sufficient input from exact equality. My original supplies the former and should not be read as completing the latter for all I.

For `0<I≤A`, consecutive `floor(qI/A)` values increase by at most1, so q_min reaches every representable-in-domain native target y exactly. **I=A is exact identity**, not a gapped boundary. For I>A, jumps can exceed1 and some outputs are unavailable through one direct SY redemption. Example I=2A, y=1: q_min=1 and output2; predecessor0. Both minimality checks pass, equality fails. This example is an arithmetic vector, not a live-state observation. The mirrored maximum-supply domain does not itself prove I always remains below A; a realistic operating horizon must be evidenced rather than assumed.

This matters even with perfect receipt measurement. If output is sent directly to the user, measurement detects excess but cannot recover it without another authorized transfer. Tax inversion and later delivery hops must also be replayed; output equality cannot be inferred from nominal SY conversion alone.

**Remaining dissent with Grok:** blanket rejection of every nonrepresentable direct-SY exact output is not established as the selected ERC4626 withdrawal behavior. The PRD requires exact-output withdrawal and does not permit calling it unsupported. Conversely, I do **not** select an unapproved rule gifting excess, retaining a new cash sleeve, charging a new fee or silently donating it to LPs.

Required plan completion:

1. State which amount/unit must be exact at each interface; enforce requested final net delivery and input/HLP maxima.
2. Prove equality for the verified operating domain where possible, including intermediary tax hops and source rounding.
3. For an actually reachable gap, derive the actual permitted route that realizes sufficient tokens, sends exactly y and attributes any conversion residual under existing ownership/refund rules. An intermediate custody hop is a proposal requiring source/authority/fee/receipt mapping, not an already-selected new reserve model.
4. If existing rules do not determine that residual's rights or a required case cannot execute, record the **narrow concrete unresolved transition**. Do not quietly drop ERC4626 withdraw or declare universal completion. Reverting when required delivery truly cannot be funded remains valid; declaring an avoidable direct-call representation gap the entire product's supported domain is a separate claim needing proof.

Thus Grok's boundary belongs in §6.5 and tests, but its residual policy remains unaccepted. My original §9/§10 proposals need this additional scope caveat; original artifact is intentionally preserved.

## 8. Taxable hops and rebase-aware receipt measurements

Retain my per-hop analysis. Local NET tax uses actual endpoint mappings/exemptions (`N/NET.sol:131–145`). No automatic5% SY fee and no duplicate SE tax. Kimi:130's “NET FoT ... only in the SE” is correct for canonical-pool tax ownership but too broad if used to ignore a genuinely taxed staking→recipient or caller→SY hop. Either verify that hop untaxed or derive its actual net delivery. The hook must not recompute tax already included in a custom SE quote.

Kimi:95/164 says taxed ingress necessarily reverts. That follows only without sufficient pre-existing NET at SY and subject to later pulls: old NET can subsidize the short first pull, and a taxed SY→staking pull can underdeliver while local stake sends nominal sNET. Source uses nominal values, not contribution deltas. Do not declare harmless revert without the custody assumptions. My original correctly flagged this; retain it.

For non-aliasing sender/recipient/collector and the verified predicate, the tax inverse remains `floor((y-1)*D/(D-t))+1` for y>0. Clarification to my original: identity aliases (e.g. receiver also taxCollector or sender=receiver) change balance-delta interpretation; inspect actual endpoints, not only fee percentage. No generic haircut formula proves every endpoint case.

Kimi:97 treats end-of-route BasicVault sync as authoritative receipt measurement. **Correction:** `BasicVaultCommon.sol:41–54` merely sets each reserve to a current balance. It does not retain pre-transfer balances, measure an external user's receipt, classify eligibility or enforce minOut. Per-operation measurements/role accounting are still needed, then final sync.

Grok's narrow receiver delta is sound if isolated around the actual payout. A wide sNET delta across earlier rebases includes growth of old receiver holdings. Local sNET sends exactly value fragments at fixed divisor to a distinct recipient because it transfers value*K gons (`N/StakedNET.sol:127–136`); it does not incur a new transfer rounding haircut. For NET deposit, old SY-held sNET also rebases during stake: measuring its whole before/after growth overcredits principal. Use a rebase-adjusted baseline/gon reconciliation as my original specifies.

## 9. Eligible held H is not public pretransfer surplus

**Reject MiniMax:181,185–195.** Define:

- H = recognized **eligible held** SY, with economic exclusions removed once;
- C = remaining eligible **net claimable** SY, not physically held;
- U = max(actual raw balance−booked reserve,0), public supported pretransfer availability under L2.

H is not U. A fully booked eligible reserve can have H>0 and U=0. Raw booked totals also include physically held exclusions, so neither raw balance nor the BasicVault snapshot alone determines H. `BasicVaultCommon.sol:28–54,80–105` confirms the bookkeeping distinction; current PRD:317–320 preserves claim/role attribution and origin-independent public surplus.

Use **H<d** as claim trigger, not H+C<d. H+C can fully cover the obligation on paper while held H cannot fund a redemption. The condition for ordinary no-complete-drain is `H+C-d≥1` raw SY unit, and actual held H must cover d when redemption occurs. Reconcile actual claims/fees once and recompute.

Grok:264 switches after claim to `d < held+c`, dropping surviving eligible receivables. This is too restrictive unless that specific claim exhausts every C. MiniMax's held-only positive-remainder test has the same defect. Retain Astra's explicit example H=d,C=1: no claim solely for funding and total eligible remainder1. After a partial claim, held may equal d while a valid remaining C preserves the same boundary. If C is gone or unavailable, it cannot justify the remainder. Do not count fee liabilities or a settled receivable again.

MiniMax:191 adds output to hook custody despite its immediately preceding direct-user payout: that is another double-accounting error. Book the actual receiver and movements, not hypothetical intermediate balances.

Agreement across originals that `SY.claimRewards` returns empty is useful and retained: the funding claims are market/YT paths paying SY, whose exact source/fee/state composition still needs mapping. “One necessary claim phase” must follow real APIs; it is not permission to invent a partial-shortfall selector or a claim/redeem retry loop. All required failures unwind the route; only selected outgoing fee-forwarding failures retain excluded payables.

## 10. Provider sampling and pricing coordinate

Retain separation of existing Weighted quotes, reusable rate and executable funding. PRD:326–334 requires a configured SY/target provider and explicit sample/zero/failure handling. Whole-token normalization is:

`rateWad = floor(a * 10^syDecimals * 10^18 / (q * 10^targetDecimals))`, where `a=previewRedeem(target,q)`.

MiniMax:298's proposed `previewRedeem(sNet,1)` is not a viable generic rate sample: at initial I=1e9, one raw SY unit returns0 native sNET, falsely yielding a zero rate. If verified decimals are18/9, choosing **one whole SY**, q=10^18, gives a=Ic exactly for this branch, and normalization gives Ic*10^9. This is a useful source-derived candidate sample, not a universal default for other SYs. Its overflow/domain/state/zero behavior must still be specified. A rate derived this way is not `exchangeRate()` at an overdue epoch because the latter uses Ip.

A sampled per-share rate used to value a raw SY book and `floor(entireBook*Ic/A)` followed by normalization can differ at integer boundaries. Grok:243 and proposed replacement:361 should not silently replace the selected provider-based pricing convention with a whole-book redeem floor. Pin the provider/caller rounding convention. Actual funding always uses the full conversion/inverse at branch state rather than assuming rate×balance delivers that amount.

Weighted native fee order remains unchanged; no new inverse or reserve model. Actual owned-HLP BasePoolMath modes and nested position allocation remain separate. Neither sampled sNET valuation nor PLP/YT NET valuation grants extra funding or public-LP ownership.

## 11. Status, additional unexecuted tests and stop

### Status separation

1. **Resolved source mapping:** four raw-token branches; target/base identities; current/projected index with exact floors/cap; mint/burn/pull/transfer order; nominal minOut; empty SY rewards; fixed-state minimum-sufficient inverses and forward domains. These are directly source-derived, not merely council agreement.
2. **Unfinished route composition/specification:** exact configured claim graph, provider/caller rounding convention, state chronology through full Keep-YT/owned-HLP realization, net receipts, exact-output representation/residual rights and corresponding bounds. The final SY conversion edge alone is not full L3 closure. MiniMax's assertion that its erroneous custody/rollback sequence is closed and Kimi's “L3 remains open only” runtime/tests list both omit these obligations.
3. **G1 evidence:** current proxy implementation/immutables/decimals, deployed staking/sNET equivalence, warmup, live cap/pause/allowances, actual hop predicates, market/router/claim identities, observation blocks and later authorized validation. Local reference != verified deployed equivalence; extraction roundtrip/hash != runtime proof.
4. **G0/L4 distinct:** instruction/authorization reconciliation and terminal late-rights are unchanged. L1 funded-gons/notification and L2 public origin-independent surplus remain resolved; NN03 stays closed. No unused wrapper route blocker, new percentage floor or ordinary principal-liquidation fallback.

### Additional tests required — none executed

- Explicit mint receiver different from payer; assert sNET backing at SY and SY shares at receiver.
- A failed downstream unstake and a post-payout minOut failure each restore burn/token/epoch state; separately ensure a caught failure cannot commit earlier outer funding steps as a successful route.
- Sequential completed deposit/redeem succeeds where funded; nested reentry rejects.
- More-than-one overdue epoch: pre-call Ip equals next realized index; a later projection may be the next step again. Zero circulation makes **no sNET rebase call** but preserves queue and advances epoch.
- Warmup>0 may preserve numerical mint preview while delivering no new immediate sNET backing; do not call that parity soundness.
- H=d,C=1, and post-partial-claim H=d with Cremaining=1: no extra claim or held-only reserve-floor rejection. H=d,C=0 rejects complete drainage.
- q=1 raw provider sample returns0 at initial index; q=10^18 whole-SY sample yields Ic for verified18/9 units. Test provider-rate book rounding separately from full conversion funding.
- I=A identity, I=2A/y=1 output gap, and exact formula/predecessor checks with overflow-safe inverse but actual forward overflow rejection. Do not label the gap vector an accepted unsupported ERC4626 policy.
- Taxed first pull with and without prior SY NET balance; taxed staking pull; actual final payout hop; receiver old-sNET rebase excluded from receipt. Check endpoints/aliases explicitly.

**Confidence:** high in source corrections and fixed-state arithmetic; conditional in deployed parity and actual route availability; no confidence claim of complete residual policy, G1 validation, economic safety or passing tests. Remaining substantive dissent is Grok's blanket exact-output rejection policy and the source-inconsistent MiniMax recommendations. Kimi's internal multi-epoch/domain assertions need the corrections above. This is Astra's only cross-review; return to moderator/human, no loop.
