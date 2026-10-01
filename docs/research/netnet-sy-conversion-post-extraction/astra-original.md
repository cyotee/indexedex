# Astra — independent original: extracted PendleStakedNetSY conversion

Access/analysis date: **2026-09-28**. Independent original pass, not a cross-review or consolidation. Research/document authoring only; no shell, tests, deployment, transactions, delegation or product edits. No peer artifacts were consulted. This report preserves the current PRD economics and makes no security, profitability or runtime-equivalence certification.

## 1. Evidence and scope

Normative documents read directly: `CLAUDE.md`; `docs/agent/RESEARCH_COUNCIL.md`; `docs/agent/SKILL_CATALOG.md`; relevant agent law and canonical Crane/local testing/adversarial skills; current `NETNET_PENDLE_DETF_PRD.md` v0.33, implementation plan v0.7 and `PRD_OPEN_QUESTIONS.md`. References below abbreviate the strategy directory as **P** = `docs/strategies/ohm-style/netnet-pendle/`.

**E** = `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`. E line numbers refer to the compilation extract document, not invented local Solidity files. The target and base/helper bodies were read there. **N** = `lib/crane/contracts/protocols/pol/net/src/`; those NetNet bodies are local references, **not verified deployed equivalence**.

Source identity recorded by the supplied manifest/current plan:

- Chain4663 candidate proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`.
- Service-resolved implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`.
- Target `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`.
- Exact-match record47105638, creation/runtime exact_match, verified2026-09-04T08:05:04Z.
- External compiler0.8.30+commit.73712a01, optimizer1,000,000, Cancun, viaIR=true (P/plan:425–433). This does **not** authorize those settings locally.
- Primary URL: <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources>. Accessed as the supplied local decoded evidence on2026-09-28, **not freshly fetched** in this pass.
- E:3–25 reports complete25-source extraction, round-trip equality and matching target hash `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`. I did not independently rerun that extraction/hash or a block-pinned bytecode check.

No external library/API documentation claims are needed: this is source analysis, so no Context7 or web search was necessary. No missing wrapper body was substituted from another version.

## 2. Main findings

**Observed:** this SY exposes exactly NET and sNET deposit/redemption token branches. Its scaled wrapper addresses are metadata/construction dependencies, not extra supported inputs/outputs. The conversion is an integer index ratio, not1:1. NET uses one-step projected index in previews/redemption; sNET uses current index without a staking call. The actual NET deposit reads the index **after** staking. The base's output minimum checks a computed nominal value, not recipient balance growth.

**Derived:** at a fixed valid branch state, the exact minimal SY amount for a nominal native output y is `ceil(y*10^18/Ibranch)`, subject to the external contract's checked multiplication domain. It needs a forward check and predecessor check; it is neither a one-share sample nor a guessed +1 adjustment. A taxed final transfer needs its own exact hop inverse before the SY inverse.

**Integration:** Weighted quotation remains in the selected NET/sNET coordinate. SY expenditure is a separate funding calculation. Ordinary NET/sNET share the same eligible held/net-claimable SY budget, with held-first/claim-only-if-short and a positive native SY remainder. Claim settlement or another epoch-triggering call invalidates stale conversion/state assumptions. No ordinary PLP/YT liquidation follows from a NET quote.

**Limit:** this narrows L3 materially, but does not close full L3/G1: current bindings/state, deployed NetNet equivalence, claim execution and the complete owned-HLP realization graph still require evidence. G0 and L4 are distinct. L1 funded-gons/notification and L2 origin-independent public surplus credit stay resolved; NN03 stays closed.

## 3. Units and exact branch table

Define `B=10^9`, `O=10^9`, `A=O*B=10^18`, `Ic=sNET.index()`, `Ip=_syncedIndex()`. x is raw input token units; q is raw SY units. Local NET/sNET decimals are9 (`N/NET.sol:33–35`, `N/StakedNET.sol:19–21`). Target hard-codes the9→18 conversion; deployed decimals must match. SY decimals come from `IERC20Metadata(yieldToken).decimals()` in the base, where construction requested the18-decimal sNET wrapper (E:58–66,211–214,692,723–725). Verify actual metadata; do not infer it solely from symbols.

| Branch | Preview | Execution/order | Units/output |
|---|---|---|---|
| NET deposit | `floor(x*A/Ip)` | Base pulls x NET caller→SY; SY calls `staking.stake(SY,x)`; reads resulting current index `Ia`; mints `floor(x*A/Ia)` | NET9→SY18 under verified metadata |
| sNET deposit | `floor(x*A/Ic)` | Base pulls x sNET caller→SY; no staking/rebase; reads current index; same floor | sNET9→SY18 |
| NET redeem | `floor(q*Ip/A)` | Burn q SY first; calculate projected amount; call `staking.unstake(receiver,amount)` | SY18→nominal NET9; actual net receipt separately checked |
| sNET redeem | `floor(q*Ic/A)` | Burn q SY first; read current index; transfer sNET SY→receiver; no staking call | SY18→sNET9 |
| scaledNET/scaled sNET/native/other token | Invalid token | Rejected by base token validation | No supported conversion branch |

Sources: E:80–102,131–168,231–270,339–353. A zero requested deposit/redeem is rejected by stateful entrypoints. Views can return0. Positive x/q can round to0; no additional positive-result guard exists in these bodies if minimum0 is used. Family money routes must preserve their own zero/domain rules.

`yieldToken` is the scaled sNET wrapper; `assetInfo()` instead returns `(TOKEN,scaledNet,18)`; `pricingInfo()` returns `(sNet,false)` (E:58–66,163–168). `exchangeRate()=Ip*O` (E:108–125). For an18-decimal SY, multiplying q by that WAD rate gives scaled-NET units, not raw9-decimal NET. Moreover `Ip` can differ from `Ic` at a due epoch: that rate must not silently become an executable current-sNET quote. A per-SY sNET provider uses the sNET branch/current index and explicit normalization. Whole-book executable funding uses the full integer amount, never a sampled rate rounded twice.

Wrapper implementation absence is relevant to wrapper-route behavior if such a route is later needed. It is **not** a blocker for these raw NET/sNET branches, which never call wrap/unwrap. Metadata identity/decimals remain finite verification requirements.

## 4. Current/projected index, floors and clock ordering

The target mirrors constants (E:44–51):

```text
F = 5_000_000_000 * 10^9
G = uint256.max - (uint256.max mod F)
J = B * floor(G/F)
M = uint128.max
```

`_syncedIndex()` does exactly (E:113–125):

```text
read epoch end e and queued profit p; read current index Ic
if now < e or p == 0: return Ic
read supply T and staking fragment balance Z
C = T - Z
if C == 0: return Ic
delta = floor(p*T/C)
Tnext = min(T + delta, M)
Knext = floor(G/Tnext)
Ip = floor(J/Knext)
```

Do not replace these nested floors with `Ic*(1+p/C)` or cap an overflowing intermediate after the fact. p*T and T+delta are checked **before** the cap. If Z>T, subtraction fails. Zero denominators/invalid state are not zero-price results.

Local compatibility evidence: `N/StakedNET.sol:25–48,58–77,83–99` uses the same inventory/gons constants, floors, index initialization and cap. It does not establish live equivalence, and source comments claiming exact aggregate growth are not permission to erase integer dust.

Local `N/Staking.sol:88–104,119–150` establishes this call schedule:

1. stake/unstake require enabled, then `_rebaseIfDue()` **before** principal transfers.
2. If not due, return without advancing.
3. If due, compute circulating; when positive, pass old queued distribution to sNET rebase and clear that queue. With zero circulating, skip sNET rebase and retain queued NET.
4. Advance end by one length and number by one even if no profit/circulation. Then oracle checkpoint; then add newly distributed profit to queue.
5. stake pulls nominal NET from SY and sends equal nominal sNET when warmup0. unstake pulls nominal sNET from SY and sends nominal NET to receiver.

Thus Ip predicts **one** rebase, not catch-up to wall-clock time. `p==0` makes Ip unchanged but does not mean execution leaves epoch state unchanged. C==0 also leaves index unchanged but due execution advances epoch and preserves/adds queue. A subsequent call while still overdue can apply a newly queued distribution. A custom pre-sync followed by NET redemption can process two epochs; a composed NET deposit/redeem can too. Do not add a missed-epoch loop, or assume that a just-synchronized current index is the index a later due unstake will use.

For ordinary hook callers, the initial NET pull into SY does not change sNET circulation. However source-valid arbitrary caller cases (e.g. custody transfers involving staking itself) and extra calls can change state; preview/execution parity is conditional on the actual route/caller and dependencies. Nonzero warmup is especially material: local stake can record warmup instead of delivering sNET while target still mints SY using nominal x. The target contains no claim-warmup route. Verify warmup0 for the intended instant NET ingress; do not invent its value.

## 5. Fixed-state inverse and arithmetic domain

For fixed positive I:

```text
D_I(x) = floor(x*A/I)       // nominal deposit shares
R_I(q) = floor(q*I/A)       // nominal redeem tokens
x_min(s) = ceil(s*I/A)
q_min(y) = ceil(y*A/I)
```

Zero desired result has mathematical inverse0, but must not be sent to an external zero-rejecting deposit/redeem. Use exact quotient/remainder or suitable full-width arithmetic for the off-contract inverse; avoid overflowing `(numerator+denominator-1)`. Still enforce the actual forward implementation domain.

Proof for redemption: `floor(qI/A)>=y` iff `qI>=yA`; hence q_min is minimal. Require `R(q_min)>=y` and, for q_min>0, `R(q_min-1)<y`. Deposit has the identical proof with A and I exchanged. These establish fixed-state **nominal** conversion minimality, not global minimal DETF input through an approximate Weighted power implementation or mutable protocol graph.

Example: I=1,500,000,000 and y=1 native unit imply q_min=666,666,667 raw SY; forward gives1, predecessor gives0. For one native input at that I, deposit gives666,666,666 SY, whose redemption returns0 native units. This is a useful dust vector, not a live-state observation. At I=B, one whole NET (`10^9` native) deposits to `10^18` SY.

Checked-forward domains include:

- deposit's left-associated `x*O*B`: require x≤floor(uint256.max/A), I>0;
- redeem: q≤floor(uint256.max/I), denominator A fixed;
- projection: Z≤T, p*T fits256, T+floor(p*T/C) fits256 before cap, positive resulting supply/divisor;
- exchangeRate: Ip*O fits256;
- mint: amount and resulting total supply fit248 bits (`PendleERC20Upg`, E:877–887,988–990); current owner-set SY cap also holds (E:175–184,426–443);
- balances, allowances, sNET `amount*gonsPerFragment`, NetNet tax products and epoch uint64 increments fit their actual reference domains; enabled/pauses/recipients/available backing allow execution.

Do not widen the external contract's supported domain merely because a custom inverse uses512-bit arithmetic. Reject/revert faithfully when the source would overflow. The supply cap is independent of sNET's128-bit rebase cap: initial unlimited cap does not prove current unlimited mint capacity; redemption does not run the mint-only cap test.

If a NET hop is taxed according to verified reference semantics `T(g)=g-floor(g*t/D)`, invert positive net y with `g_min=floor((y-1)*D/(D-t))+1` for0≤t<D; invert each taxed hop backward, then q_min(g_min), and replay each forward step. D10000,t500,y19 gives gross19, not20. The conditional predicate is `taxEnabled && !exempt[from] && !exempt[to] && (taxedPair[from] || taxedPair[to])` (`N/NET.sol:121–145`). Resolve actual endpoints and state. Do not apply5% blindly or add SE tax a second time in the hook.

## 6. Caller, custody, receipts and minimums

**Deposit (E:231–246,1414–1417):** `msg.sender` is the payer; receiver is the minted-share recipient. No deposit pretransfer flag. TokenHelper safeTransferFrom pulls nominal x; it does not measure net receipt. A caller must approve the SY proxy. For NET, proxy then uses its staking allowance initialized at E:69–74 to stake x, with the proxy both staking caller and sNET recipient. Target ignores stake's return. Mint calculation uses nominal x, not observed sNET growth. With nonstandard/taxed required hops this can revert or rely on old custody; a successful nominal call alone does not prove contributed backing. Measure isolated receipts and verify required hop behavior, do not subsidize a short pull from unrelated existing inventory.

**Redeem (E:252–270):** false flag burns **caller-held SY**, no allowance-based owner argument and no pull from an arbitrary third party. If the hook owns SY and calls directly, false is the natural custody path. If a router is caller, it must actually hold those shares or use a correctly funded internal path. True burns `SY.balanceOf(SY)`—not hook-held SY, router-held SY or a per-caller deposit account. It performs no depositor ownership authentication. A transfer-to-SY then true-burn must be atomic and limited to the operation's intended shares; never treat ambient SY-held shares as the hook's funding.

Burn occurs before `_redeem`; NET computes nominal amount using Ip and calls unstake directly to receiver. There is no NET return hop through SY in that branch. sNET sends directly SY→receiver. Base then checks **the computed nominal amount** against minTokenOut; it neither measures receiver's delta nor adopts staking's return. `TokenHelper._transferOut` checks safe transfer success, not economic receipt (E:1423–1430). All revert effects unwind including prior burn/stake/rebase.

Family adapters therefore need actual recipient delivery protection in addition to SY's minimum. For NET ordinary non-rebasing balances, isolate the recipient delta across the exact final delivery. For sNET, the direct external SY branch has no rebase, so a narrow before/after transfer delta matches native fragments under the reference. A wide snapshot across an earlier rebase can include growth of the receiver's old sNET and is **not** receipt. For NET deposit, SY's sNET pre/post balance across staking likewise includes old inventory rebase: use a post-rebase baseline or gon/index-aware reconciliation, not all balance growth as new capital. Final transfer via an intermediate recipient adds a real hop with its own tax/measurement/limits.

This is internal operation accounting, not a revision of L2: public supported pretransfer still consumes max(raw−booked,0) regardless of donor identity. External SY deposit itself does not gain a pretransfer mode from that policy.

## 7. Weighted pricing versus one physical funding budget

Inspected helper: `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49`: exact-in applies mulDown(input,1−fee), exact-out divUp(netInput,1−fee). Inspected native wrapper: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:186–227`: exact-in raw fee→scale→Weighted→descale down; exact-out scale output up→Weighted inverse→descale input up→gross-up once. Preserve P/plan §6.4. A fee-inclusive helper followed by another gross-up is wrong; substituting scaled fee order for native fee order changes rounding.

Quote NET from the PRD PLP/YT-derived virtual balance, sNET from accounted SY rated into sNET. The Weighted result is a requested/quoted **token output**, not a raw SY amount. Convert that output backward into a raw SY debit at the same branch state. Do not insert the SY budget as a new NET pricing reserve, or mechanically decrement the PLP/YT NET balance when SY alone is spent. Conversely, a large NET valuation does not fund a large payment. Reconstruct the pricing vector after actual custody/index/claim changes (PRD:398–419).

Proposed deterministic ordinary sequence:

1. Authenticate route/caller/limits; protect operation/callback phases; capture supported pretransfer credit before internal booking can erase it. Accumulate prior-price observations and perform only the route's required epoch/expansion processing before participation changes.
2. Reconcile recognized held SY H, net-claimable eligible SY C, excluded payables/exclusive principal and any previously settled receivable. Quote selected coordinate using the coherent state; derive nominal delivery/tax requirements and raw d via the branch inverse. Check domain and actual share custody.
3. Require `d < H+C` in native SY units, without a percentage reserve floor. If `H>=d`, fund from held and **do not claim merely for this output**. Equality H=d is permissible only when positive genuinely eligible C remains; no demand that the held component alone remain positive is selected.
4. If H<d, claim available interest/rewards for the hook through the configured Pendle claim route. That external API may collect more than the exact shortfall; 'claim only if short' is a trigger policy, not an invented partial-claim selector. Retain eligible SY; attempt fee-token forwarding to dynamic feeTo, retaining excluded payable on allowed failure. Required funding claim failure reverts.
5. Measure actual SY received, replace the settled receivable once, reconcile claim fees and remaining C. SY's own `claimRewards` is empty (E:309–332); it is not the source of market/YT interest. Book market claims by their actual configured source, never fabricate them from that empty method.
6. Recompute branch index, projected next epoch, net-output requirement, pricing/funding snapshot and d after every preceding state change capable of affecting them. Use one bounded actual route graph, not an iterative redeem/guess loop. If new requirements cannot be funded from now-held H, or `H+C-d<1`, revert; do not add another claim/redeem loop or silently change user limits.
7. Redeem d from operation-owned SY under nominal minimum plus family net-receipt checks. Check actual SY spent and resulting eligible held+remaining net-claimable inventory; require at least1 raw SY unit remains. Preserve exact-output net obligation, maximum input and actual exact-input minimum.
8. Commit actual economic debits and rebuilt pricing values; perform authorized refunds then full expected-token BasicVault synchronization. On any required failure, revert claim, burn, rebase, ledger, input/output, markers and observations together. Fee forwarding alone retains the selected best-effort treatment.

No ordinary output liquidates PLP/YT, spends principal-exit SY or fee payables, creates pending payout, or falls back to a different economic route. Sequential NET then sNET (or reverse) must share the updated budget. Keep-YT ingress transient SY is not eligible interest cash.

**Owned-HLP burns/reinvestment:** build the actual owned book before quoting, realize only authorized owned components under actual BasePoolMath proportional/unbalanced/single-token mode, and apply nested PLP/YT allocation only after outer allocation. A universal h/H shortcut is forbidden. This conversion report supplies the final SY→NET/sNET edge; it does not prove the earlier Pendle position/HLP inverse, entitlement or complete route. Quote-only contraction bonus remains once-only; actual q burns only; reinvestment gets no bonus. No new off-pool cash reserve or fee model.

## 8. Finite dependency and evidence matrix

| Path | Needed source/state | Not an automatic blocker |
|---|---|---|
| All SY calls | Current proxy implementation/immutable bindings, SY metadata/pause, correct caller/custody, supported tokens, balances/allowances, arithmetic bounds | Decimal-wrapper wrap implementation for unused routes |
| sNET deposit | Actual sNET decimals/index/transfer behavior and allowance; SY cap/current supply | Staking enabled/oracle/distributor if no earlier operation calls them |
| sNET redeem | Current sNET index/backing/transfer, caller/internal share balance; coherent receipt window | Projected rebase, warmup, NET tax if route never touches NET/staking |
| NET deposit | Above plus staking/net/sNet relationship, enabled, warmup0/instant delivery, actual due-state and staking rebase/oracle/distributor source; caller→SY and SY→staking NET hop predicates | Wrapper conversions |
| NET redeem | Projection T/Z/p/end/constants; actual unstake equivalence/enabled; sNET staking allowance/backing, staking NET backing, due oracle/distributor liveness, staking→recipient NET predicate | Mint cap as a redemption guard; unrelated unused wrap routes |
| Claim-if-short | Configured market/YT/router identity, actual claim fees/index/entitlement/SY recipient and historical attribution, balances, fee reward forwarding | SY's empty own reward array is not proof market has no interest |
| Owned-HLP/rollover | Actual BasePoolMath mode, owned HLP, fee-diluted supply, authorized PLP/YT execution, old/new SY branches and state chronology | Conversion mapping alone cannot close these |

For NET projection, deployed NetNet constants/index initialization and staking behavior must match the mirrored assumptions. One observed index is not proof. Required observations need a chain/block and code identities, not a timeless configured-address assertion. The evidence obligations are branch-specific; do not reopen NN03 to demand survival of arbitrary essential dependency failure.

## 9. Exact proposed changes to plan §6.5 (not applied here)

Moderator should replace §6.5's stale extraction-limit narrative (plan:435–450) with the following structure/content, preserving identity table425–433 and evidence limitations:

1. Rename heading to **“Actual PendleStakedNetSY conversion, execution ordering and remaining binding proof.”** Replace “Not yet read” with “Target/base/token helper bodies read from the complete25-source extract on2026-09-28; extraction/hash manifest is not fresh runtime proof.”
2. Insert report §3's four supported branch rows and unsupported-token row, with E citations, native units and metadata distinction. Explicitly say no wrapper transfer/conversion is executed by those branches.
3. Insert §4's exact Ip computation, including C==0, p==0, cap after checked arithmetic, nested floors and one-step epoch behavior. State NET deposit post-stake index versus sNET current index; require actual hop chronology rather than a global 'synced' boolean.
4. Insert §5's two closed-form inverses, forward/predecessor checks and checked-forward domains. State tax inverse is hop-specific and nominal SY minimum is not net receipt. Preserve §6.4 Weighted native fee order without another fee.
5. Insert §6's custody table/receipt semantics: caller pull on deposit, false burns caller, true burns SY's own balance, burn before conversion, nominal minimum after conversion, actual isolated receipts and rebase-aware baseline.
6. Insert §7's numbered held-first sequence, recomputation, strict native remainder and rollback; explicitly separate ordinary SY funding from owned-HLP realization and pricing coordinates.
7. Insert §8's finite branch-specific evidence matrix and §10 tests with status **UNEXECUTED**. Replace “no guessed conversion equation” with “source-derived equations specified; live bindings, supported state domains and composed funding validation remain pending.”

Related status correction proposed, not executed: §2 L3 should read **“target/base conversion mapping recorded; deployed-state equivalence and complete composed funding proof pending”**, not “body extraction/analysis pending” and not “closed.” NN07/NN10 should link the accepted conversion specification without asserting runtime validation. Preserve G0 authorization/instruction reconciliation, G1 bindings and L4 terminal rights independently. No changes to L1/L2/NN03 economics or reopening of those questions.

## 10. Unexecuted tests and acceptance vectors

All below are **proposed, not written/run**. Use production-first Crane/IndexedEx TestBases, real registered proxy surfaces and separately authorized build-before-test workflow. Local NetNet reference arithmetic tests and block-pinned fork equivalence tests are different evidence tiers; neither is replaced by a mock SY formula.

| Case | Exact expected property |
|---|---|
| Four branches/discovery | Only actual NET/sNET accepted. Scaled wrappers/native/unrelated token rejected; decimals boundaries9/18 checked. |
| Initial index | I=1e9, x=1e9 native →1e18 SY; reverse returns1e9 native. |
| Dust/minimality | I=1.5e9,y=1 →q=666666667, predecessor0 output; x=1 →666666666 shares→0 output. minOut1 rejects that zero. |
| Index threshold | now=end−1 current; now=end queued-positive/circulating-positive exactly nested projected formula; sNET still current until actual rebase. |
| Zero-profit due | Same index, but epoch increments and new queue can be populated; no inference of no state change. |
| Zero circulation | Ip=Ic; due staking skips rebase, retains queue, increments epoch, adds distributor output. |
| Cap and overflow | Below/at/above128 cap calculation; overflowing p*T or T+delta reverts before cap. x*A/q*I domain boundaries and248-bit SY supply/cap checked. |
| Overdue composition | Two fixed staking-triggering calls advance two epochs if each remains due; second uses updated queue/index. No wall-clock catch-up loop. |
| sNET branch isolation | Deposit/redeem do not call staking; current-index conversion can execute independently of unused projected-index paths when no common pre-step requires them. |
| Warmup/enabled | NET instant ingress verified warmup0; nonzero warmup exposes nominal-mint/no-immediate-sNET incompatibility rather than claiming equivalence. Disabled NET path fails atomically. |
| Custody flags | Hook-owned q false succeeds; true with no SY-owned shares fails; router cannot burn hook balance via false; atomic exact pretransfer true consumes only intended shares. |
| Nominal minimum | Taxed final NET transfer can satisfy source nominal min but fail outer measured net min; whole operation rolls back. Untaxed path receives exact nominal. |
| Rebase-aware receipt | Receiver with old sNET does not count old-balance rebase as newly delivered output; SY old sNET rebase does not count as new NET-deposit principal. |
| Held sufficient | H=d+1,C=0: no claim, remainder1. H=d,C=1: no funding claim, total eligible remainder1. |
| Exact drainage | H=d,C=0 reverts despite sufficient physical shares; no percentage buffer. |
| Claim short | H<d with sufficient net claims: one necessary claim, once-only receivable replacement; excluded fees never become eligible. |
| Claim underdelivery | Actual net funding too small or total remainder0: revert all upstream claim/input/epoch/ledger changes, no partial payout. |
| Changed state | Claim or preceding stake changes relevant index/book: recalculate d and quote limits; stale arithmetic rejected, no +1/redeem loop. |
| Shared budget | Sequential NET/sNET and HLP interleavings never count two independent cash pools; only authorized owned-HLP path realizes principal. |
| Weighted boundaries | Preserve native fee/scale order and original ratios/domain guards. No duplicated gross-up; funding failure possible despite valid Weighted quote. |
| Reward exception | Failed fee forward retains excluded payable and operation continues if required funding succeeds; failed required claim reverts. |
| Public credit | Origin-independent unbooked donation/force-claim may be consumed by next eligible supported pretransfer caller; booked balance cannot, consumed receipt cannot remain a duplicate receivable. |
| Exact-output composed route | Requested net sNET delivered within max DETF/HLP debit; actual BasePoolMath mode and owned fraction preserved, quote-only bonus never minted/burned. |

## 11. Confidence, counterarguments and unresolved evidence

**High confidence:** extracted target branch selection and equations; base caller/internal-share and nominal-minimum semantics; local reference one-epoch ordering; fixed-I inverse proof; separation of Weighted quote from SY funding.

**Conditional confidence:** projected index matches actual deployed unstake/stake, exact NET transfer tax classification, raw decimals and immediate delivery. Those depend on binding/runtime/state evidence not established here. Complete owned-HLP route closure and exact claim source graph remain incomplete, not obscured by this conversion result.

Counterarguments considered:

- “exchangeRate is enough”: it uses projected index/scaledNET metadata while sNET execution uses current index, and does not measure receipt or prove funding.
- “minTokenOut proves delivery”: base compares the target's nominal computed amount, not balance delta.
- “sync once solves every route”: overdue state can advance again inside a later stake/unstake; recomputation must model the next actual call.
- “wrapper source absence blocks everything”: supported raw-token branches never execute wrapping; only relevant metadata/binding proof is required there.
- “linear inverse closes L3”: only fixed-state final edge is linear; actual claims, earlier owned-HLP realization, receipts, runtime identity and state changes remain separate obligations.
- “a positive remainder is a new reserve floor”: it is the existing strict native-unit no-complete-drain condition, not a percentage policy.

No speculative exploit, live cap/exemption, economic safety or passing-test claim is made. Current PRD instructions remain normative. This original is submitted to the moderator for the bounded council process and human checkpoint.
