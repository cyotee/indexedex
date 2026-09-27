# Universal V4 DETF expansion — source trace and council R6

Date: 2026-09-25. Research only. No Solidity/configuration edits, execution, tests, simulation or deployment. PRD/matrix remain unchanged by this report; the latest human choices below control over their older proposal labels.

## Latest human selections and research question

- **Opening price is selected: 1 DETF = 1,000 NET.** Do not re-ask whether it is merely proposed.
- **Custom expansion price gate is selected: strictly above 1 NET per DETF on processed NET epochs.** Equality does not meet “above.” This does not make the launch opening value the ongoing price target.
- Human requests the actual current Universal DETF behavior before deciding whether to reuse or modify its amount calculation. The prior proposed 0.5% per epoch does not yet specify flat-supply issuance, premium-dependent issuance, or delayed-settlement compounding.
- Existing funded staking custody remains selected. No renewed owner vote over those token/custody identities is needed.

## Executive finding

Universal expands above a premium threshold, but it is **not exactly the requested custom rule**. It uses the highest creation-normalized synthetic price among its non-DETF reserve legs, requires that price to exceed both normalized peg and the configured mint threshold (default 1.05), and computes an annualized premium-dependent amount from total DETF supply. Its clock is first-bond-anchored eight-hour wall time, not the external NetNet processed epoch counter.

Reusable behavior includes explicit actual funding, settling before participation changes, coherent preview/execution, dust/rounding and single aggregate settlement. Reusing the amount formula, rate meaning and catch-up convention remains a human discussion; nothing here selects them for the custom family.

## 1. Exact amount calculation

Observed in `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:9–57`.

Let:

- `W = 1e18`.
- `S` = actual outstanding NET-DETF-equivalent supply in native nine-decimal DETF units, from ERC20 total supply. Pool-held and staking-held DETF are included; sDETF receipt supply is not added.
- `P` = WAD synthetic price described in section 2.
- `T` = resolved WAD mint threshold.
- `r` = configured WAD annual closure parameter.
- `last` = last processed expansion boundary; `now` = current block timestamp.

```text
Require live reserve, positive S, now > last.
Require P > W AND P > T.

n = floor((now - last) / 28,800)
If n == 0: mint = 0.

c = floor(r * 28,800 / 31,536,000)
b = floor(S * (P - W) / P)
e = floor(b * c / W)
mint = e * n
If mint <= 1 native DETF unit: mint = 0.
```

Preserve the two `mulDiv` floors and multiplication order. This is not a whole-token floor. One raw DETF unit is `1e-9 DETF`.

Ignoring rounding, the one-epoch relationship is:

`mint / S = ((P - 1) / P) * annualClosureRate / 1095`.

Here P and rate in that explanatory expression are dimensionless human values. The premium factor tends to zero near normalized peg and toward one at high P. The code calls this premium closure; it is not a guarantee of a particular annual supply growth or market-price trajectory.

### Defaults and configuration

- Epoch: 8 hours; year: 365 days.
- Zero annual-rate argument resolves to `0.10e18`: a **10% annual closure parameter**, not flat 10% supply growth.
- Zero mint-threshold argument resolves to `1.05e18`; zero burn threshold to `0.95e18`.
- Threshold equality is ineligible. With defaults, synthetic P=1.025 or exactly 1.05 does not expand.
- Default dust is one native unit, applied to the aggregate result.

Sources: `DETFEpochNaturalExpansionLib.sol:9–45`; `contracts/vaults/detf/common/core/DETFThresholdPolicy.sol:16–30`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol:246–265`. These are inspected source defaults, not verified settings of a deployed instance.

## 2. What “price” means in this implementation

`UniswapV4DetfCommon.sol:324–340` evaluates `previewSynthetic` for every configured non-DETF pair/numeraire and takes the **maximum**, using the same actual supply and protocol-owned LP but each leg's own creation rate. It neither sums separate expansions nor uses only NET automatically.

For the selected Weighted reference adapter, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–139`:

1. Build a marginal Weighted valuation of non-DETF inventory in the requested numeraire; direct reserve DETF is excluded as external backing.
2. Scale by protocol-owned LP divided by projected fee-adjusted LP supply.
3. Divide that marked inventory by outstanding DETF supply (WAD-normalized by caller).
4. Divide again by the leg's configured creation price.

This is a **normalized marked-inventory-per-outstanding-DETF measure**, not the finite-size amount received by selling DETF, and not simply the raw marginal DETF/NET trading price. Using marginal valuations internally does not make the final inventory/supply ratio identical to trading spot.

### Opening, creation and ongoing target are different

`_openingBondQuote` uses `openingOfPair`, falling back to `creationOfPair` when the opening override is zero (`UniswapV4DetfCommon.sol:258–289`). Expansion explicitly uses creation normalization (`:337`), not the opening override.

Selecting opening 1,000 NET/DETF does not select creation=1,000 and does not prove synthetic P=1 or P=1,000 after bootstrap. That result also depends on marked reserves, weights, actual ownership, G/B/R issuance and total supply. Setting a denominator to 1,000 would make normalized one mean a 1,000-unit inventory mark per DETF—not the owner's continuing 1 NET threshold.

Consequently, selecting only the NET adapter and lowering `mintThreshold` to one may still not implement the owner's desired NET trading-price condition. The custom NET-rated price measurement must be explicit and correctly normalized. Do not silently redefine the target or import the Universal maximum-over-legs policy.

## 3. Clock, catch-up and automatic settlement

- The first successful bond initializes the expansion timestamp (`UniswapV4DetfTarget.sol:581–599`).
- Boundaries occur at first-bond timestamp plus integer multiples of 28,800 seconds; deployment time is not the anchor.
- An applicable transaction settles due expansion. Time alone does not execute a contract.
- `synchronizeRewards()` is callable when unlocked; during an existing DETF lock only the wired staking/NFT child may make the permitted no-op callback (`UniswapV4DetfMaintenanceTarget.sol:11–27`).
- Ordinary relevant mint/burn/bond and staking/NFT participation paths synchronize before changes. Do not claim every transfer or arbitrary raw hook action automatically invokes this code. No custom standalone keeper endpoint is selected merely by inspecting this reference.

**Catch-up:** compute e once using current actual S/P, then mint `e*n`. There is no historical price replay, per-missed-epoch simulated rebase or internal compounding loop. Subsequent separately executed settlements naturally use their new actual state, so “no catch-up compounding” does not mean supply can never grow on previous actual issuance.

**Zero mint still consumes time:** `computeRealization` advances `last += n*EPOCH` even if current price is ineligible or the result is dust. Partial elapsed time remains. At hour 25 after activation, it processes three epochs through hour 24; the next boundary is hour 32. Previously consumed ineligible epochs cannot later be reminted when price rises. Conversely, if many intervals have not been processed, their aggregate is evaluated at the current snapshot, not their unknown historical prices.

No policy catch-up cap, maximum epoch count or supply-relative clipping appears in this path. Solidity arithmetic and transaction/resource limits still exist; absence of a configured cap is not proof of economic safety for very long gaps.

Sources: `DETFEpochNaturalExpansionLib.sol:33–57`; `UniswapV4DetfCommon.sol:308–369`; `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:977–1005`.

## 4. Where newly issued DETF goes

For positive expansion, `_realizeExpansionIfNeeded` calls `_fundStakingRewards` and emits `NaturalSupplyExpanded`. DETF is minted to the DETF proxy and then transferred into the staking contract through `fundRewards` (`UniswapV4DetfCommon.sol:343–379`).

`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:170–183` restricts funding to its DETF and resolves fee/creator recipients through role NFTs. `DETFFundedStakingRepo.sol:182–201` records actual backing, allocates rewards among ordinary staking/fee/creator weights, rebases existing stake, then issues backed fee/creator receipts. Dust is retained in the corresponding accounting stages.

The expansion amount is already a reward source: there is no additional recursive `p * expansion` issuance, no automatic reserve-LP join, and no fresh unbacked reward claim. Source behavior of fee/creator role allocations should not be confused with PENDLE's independent live `feeTo()` forwarding rule.

## 5. Hand-calculated native-unit example

Use the inspected library test fixture values, not selected custom parameters:

```text
S = 1000 * 1e9 raw units = 1000 DETF
P = 2e18
T = 1.05e18
r = 0.10e18
n = 3 completed epochs

c = 91,324,200,913,242
b = 500,000,000,000 raw units
e = 45,662,100 raw units = 0.045662100 DETF
mint = 136,986,300 raw units = 0.136986300 DETF
```

The one-epoch growth here is approximately 0.00456621% of total supply—not 0.5%. A flat 0.5% of the same 1,000-DETF supply would be 5 DETF per epoch before choosing catch-up behavior. These are materially different amount policies.

Tests inspected, **not run**: `test/foundry/spec/vaults/detf/common/core/DETFEpochNaturalExpansionLib.t.sol:9–16,33–62,74–106,108–145`, covering defaults, threshold equality, three-/21-epoch catch-up, zero-eligibility boundary consumption and rounding invariants. Hand arithmetic is not a test result.

## 6. What can be reused versus modified

| Aspect | Existing Universal | Custom selected intent / remaining discussion |
| --- | --- | --- |
| Opening | Configurable opening/creation fallback | Opening 1,000 NET/DETF selected; do not equate with ongoing peg |
| Expansion price | Maximum of creation-normalized synthetic legs | Strict >1 NET per DETF selected; define correct NET price measure, not unrelated-leg maximum |
| Additional gate | Strictly greater than mint threshold, default 1.05 | Do not carry a 1.05 deadband into the selected strict >1 expansion rule |
| Clock | First-bond-anchored eight-hour wall time | Processed NetNet epoch state selected |
| Amount | Premium-dependent fraction of current total supply, annual parameter | Reuse premium-dependent structure or adopt another defined rule; prior 0.5% proposal does not settle meaning |
| Catch-up | Current snapshot, floor per epoch then multiply n, no replay/compounding/cap | Reusable candidate; custom convention still needs selection and NET-epoch mapping |
| Actual funding | Mint to DETF, transfer to staking, funded allocation | Preserve already selected funded staking custody; map appropriate custom reward policy |

Two amount interpretations to discuss, **neither selected here**:

1. **Premium-dependent:** retain `S*(P-1)/P` structure with a carefully defined custom premium P and chosen coefficient.
2. **Flat supply-rate while eligible:** if the intended rule is 0.5% of current total DETF supply per eligible NET epoch, that is conceptually `S*0.005` before explicit rounding/catch-up rules, not the current premium formula.

For dimensional comparison only: in the Universal eight-hour clock there are 1,095 epochs/year. A per-epoch **closure coefficient** of 0.005 corresponds to annual parameter `5.475e18`, not `54.75e18`. It would still be multiplied by `(P-1)/P`; it would **not** mean flat 0.5% supply issuance. Do not encode this example into the custom configuration before the human chooses the meaning.

## 7. Council protocol, corrections and dissent

Four fresh independent first passes and four same-session combined cross-reviews completed. Each continuation received all three other ORIGINAL artifacts, not prior cross-reviews. The prior interrupted readiness round is not represented as complete. Originals remain unchanged:

| Researcher | Original | Preserved session | Reported metadata |
| --- | --- | --- | --- |
| Astra | [Original](./reviews/EXPANSION_R6_ASTRA_ORIGINAL.md) | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | [Original](./reviews/EXPANSION_R6_GROK_ORIGINAL.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax M3 | [Original](./reviews/EXPANSION_R6_MINIMAX_ORIGINAL.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |
| Kimi K3 | [Original](./reviews/EXPANSION_R6_KIMI_ORIGINAL.md) | `ses_f2abe1e07ffe0izL8DAH8boF2W` | `kimi-code-plan-global/k3`, high |

No participant reported a guard denial or lost context. Metadata is not provider attestation. Originals and cross-reviews are model evidence, not authority; specific repeated errors were resolved against source and independent arithmetic rather than by vote.

- **Agreement:** the library formula, floor order, default coefficient/thresholds, highest-leg input, total-supply basis, aggregate catch-up and funded destination are established in inspected code.
- **Astra:** clearest initial distinction between inventory/supply synthetic price and actual NET trading price. Its 1,000-DETF/P=2 example is retained. Its later attempted numerical correction of Kimi's different example was itself inaccurate; it is not used here.
- **Grok:** correctly emphasized default deadband and clock changes. Its suggestion to set creation=1,000, and later wording treating that value as already selected, are rejected: only the opening price was selected. A matched synthetic value at launch was not demonstrated.
- **MiniMax:** rejected errors include Universal already synchronizing NET epochs; opening and creation feeding the same denominator; threshold-only satisfying the user's NET gate; unverified pause-path/package names; annual coefficient 54.75; and multiple whole/native-unit mistakes in the first-bond and synthetic examples. Its cross-review did not adequately retract these. Correct illustrative first-bond values for 1,000 whole NET at opening 1,000 and illustrative multiplier 1.10/p=10% are G=1, U=1.1, B=0.99, R=0.21, total=2.2 whole DETF—not 1101 or 1201.
- **Kimi:** correctly traced the expansion structure but its 1,000,000-DETF example prematurely rounded to whole tokens. The later correction still contained unit errors and an incorrect annual-rate interpretation. Those numbers are not adopted. A literal reuse of the fixed-eight-hour library unchanged cannot simultaneously implement an external processed-NET-epoch clock without an explicit adaptation.
- Final disagreement persists in some researcher wording about creation normalization and parameter-only fixes; this report adopts the direct code interpretation. No claim of unanimous numerical correctness is made.

## 8. Confidence, scope and human checkpoint

High confidence in the inspected source behavior and verified small example. Sources are repository snapshots with Solidity `^0.8.0` in the inspected core contracts; no runtime compiler, deployed address/configuration, revision hash, live price or gas bound was verified. No new external API claims required Context7/web retrieval; this is local business-logic review. The shared-law authority constraints remain separate implementation gates; neither passing tests nor council agreement would prove economic soundness.

For the next discussion, the unresolved economic choice is **premium-dependent versus flat supply-rate amount**, followed by the precise catch-up convention and NET price measurement. Opening 1,000 and strict >1 NET eligibility are now selected and should not be re-asked. A conditional milestone plan can be written before every deployment proof, but an executable economic specification must name the amount rule.

**Separate implementation handoff:** later authorized planning should map NET epoch markers, selected NET price semantics, precise amount/rounding, settlement ordering and actual backing; preserve no-double-payment and zero-result processing semantics if selected. Do not change Universal code or adopt its defaults for the custom family on the strength of this report. Only research Markdown artifacts were created; PRD, matrix, code, instructions and configuration were not changed in this round.
