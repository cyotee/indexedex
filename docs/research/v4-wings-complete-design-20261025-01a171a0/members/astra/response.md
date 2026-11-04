# Astra: complete V4 Wings vault recommendation

## Identity

- Run ID: `v4-wings-complete-design-20261025-01a171a0`.
- Member label: `astra`, as assigned by the caller.
- Profile: research.
- Phase: initial independent response, fresh assignment.
- Owned path: `members/astra/response.md`.
- Requested role: `council-member`.
- Requested model/reasoning: `chatgpt-subscription/gpt-6-astra:high`, from the brief.
- Actual runtime role, model, reasoning setting, provider/account route, and structured Native task/session identity: **not exposed** in an identity record available to this response. Tool-generated artifact paths contain identifiers, but I do not treat those paths as verification of the requested model route.
- Current-run peers, coordinator draft, and feedback read: **none**.
- No delegation, shell, project tests, installation, Git, deployment, wallet operation, or project code/configuration modification was performed.

## Question and recommendation

Recommend the complete replacement V4 Upper Lower Wings Standard Exchange: ownership, issuance, entry, fees, compounding, maintenance, redemption, previews, canonical `getRate`, and external-pool use.

**My preferred design is one fungible share of the entire portfolio, independent-reference valuation for issuance, and actual proportional withdrawals followed by an optional sale of only the withdrawing holder's opposing inventory. Preserve `getRate` as a normalized one-whole-share execution preview. Add an always-available-in-principle, quote-independent in-kind exit.**

This is a conditional deployment recommendation, not an assertion that the necessary price source already exists. It sacrifices arbitrary-pair deployment without a suitable independent price reference. For a pair without that reference, I would not deploy this preferred unbalanced-entry design. The credible alternative is a separately specified oracle-free proportional-join product with refunds, not a secretly spot-priced fallback in the same vault.

The three values must have different names and contracts:

1. **Issuance NAV:** reference-valued economic equity, used to divide ownership when new assets join.
2. **Redemption proceeds:** actual tokens recovered from a particular proportional withdrawal and its actual swap.
3. **`getRate`:** the execution preview for exactly one whole share, normalized to WAD target tokens. It is neither NAV nor a promise that another redemption size receives the same price.

These are recommendations/inferences throughout the design sections below, unless a passage is explicitly labeled source observation or supplied evidence.

## Evidence

### Source index

All local paths are relative to `/Users/cyotee/Projects/indexedex`. For the source citations below, `W/` means:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`

Within that directory, a short name such as `Money` means the exact file `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`. This abbreviation is solely to make the citations readable.

| ID | Source actually read | Classification and observation |
| --- | --- | --- |
| B | This run's `brief.md`, complete | **Coordinator-supplied evidence:** preferences, conversation history, authorization, and the fourteen decision questions. The user prefers actual-slice exits and one-share execution-quoted `getRate`; no independent price source has been chosen. Those statements are not implementation or security evidence. |
| R | `CLAUDE.md`, complete; relevant sections of `docs/agent/INDEXEDEX_AGENT_LAW.md` | **Source observation:** Wings is the supported V4 family; retired V4 families must not return; registry deployment, production-first tests, token policy, and build-before-test rules apply. The law's D60 section distinguishes held-share rate valuation from buffering execution. |
| A12 | `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md:268-330`, APEX-2026-012 | **Source observation of an audit report:** High, **Latent: not deployed** at the audit's stated review point. The report presents both unsettled and settled JIT/spot PoCs, not merely a hypothetical. I read the report, not a fresh execution of its PoCs. |
| A25 | Same audit, `:1109-1169`, APEX-2026-025 | **Source observation of an audit report:** Medium, **Latent: not deployed**. It reports both self-impact/backrun and front-run/keeper/backrun results. |
| A26 | Same audit, `:1173-1236`, APEX-2026-026 | **Source observation of an audit report:** Medium, **Latent: not deployed**. It reports dust-tick and natural spacing-1 liveness failures under the 512-step quote cap. |
| A24 | Same audit, `:1605-1675`, APEX-2026-024 | **Source observation of an audit report:** Low, **Latent: not deployed**. Preserve its distinction: backrun-only behavior was partly classified as a design tradeoff; the sandwich component was identified as a bug. |
| A40 | Same audit, `:2141-2201`, APEX-2026-040, through its Fix section | **Source observation of an audit report:** Low, **Latent: not deployed**. It reports fee-growth donation and one-share mint rounding, with victim losses. None of those runs was repeated here. |
| M | `W/Money`, `begin`, `_deposit`, `_redeem`, `_fund`, `_swapDeficit`, `preview`, `requiredInput`; `W/Accounting`, all | **Source observation:** current issuance credits target input against a full-book liquidation quote before placement; redemption promises a proportional share of that quoted value and funds it from the book. Placement costs are documented as reserve costs. |
| Q | `W/LiquidationQuote`, all; `W/Common`, all | **Source observation:** full owned-liquidity removal, live pool/tick traversal, fee-growth collection, projected pool overlays, and a fixed 512-step request. `Common.execute` rejects an already-unlocked manager, while the Money paths can skip harvest/placement in that context. |
| P | `W/Repo`, `Types`, `Inventory`, `Geometry`, and `Harvest`, all | **Source observation:** three salted positions, booked local balances, fee-growth arithmetic, full-range core, upper/lower geometry, and swap-free harvest/placement. Existing converted wings may be closed; matching local balances can be placed in the core. |
| X | `W/ExecutionDelegate`, all | **Source observation:** authenticated manager callback; actual deltas settle into local books. `_modify` receives but discards the separately returned `feesAccrued` field. That separation becomes important for the proposed entrant/incumbent accounting. |
| E | `W/EconomicTarget`, `QueryTarget`, `QuoteBase`, `Projection`, `SYTarget`, all | **Source observation:** current canonical `getRate` is full-book liquidation value divided by supply, not a one-share exit simulation. Projection carries a pool overlay. SY's current `exchangeRate` also uses full-book liquidation value. |
| I | `W/InExecutionBase`, `InTarget`, `OutTarget`, all; `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol` | **Source observation:** current target/share route facades and exact-output routes use Money's common scalar valuation. The generic execution base read is abstract, not evidence of an additional fee charge. |
| D | `W/DFPkg` and `W/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`, all | **Source observation:** hookless initialized pool, immutable package configuration, target-token share decimals, registry path, and current arguments with no price-reference adapter. |
| RB | `W/RebalanceTarget`, all | **Source observation:** public rebalance closes/replaces wings, may swap, and tests its loss against live liquidation quotes with a progress-derived budget. |
| RP | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`, all | **Source observation:** `_getRate` requests a **full-supply** exit preview, then normalizes; `quoteRate` can use projected `quoteAssets`. It does not just forward the vault's canonical `getRate`. |
| HC | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:390-579` | **Source observation:** `_rate`, `_ratedOf`, `ratedReserve`, `_ratedWith`, and projected-claim functions multiply held shares by a provider rate without redeeming those held shares for the valuation. |
| HW | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:1-125`; `...WeightedBufferHookTarget.sol:300-379`; `...WeightedBufferHookHooksTarget.sol:245-344` | **Source observation:** rated held reserves feed swap calculations. Output settlement may redeem the output leg, but that does not physically redeem every reserve whose rate informed the price. |
| H | `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, complete | **Source observation of historical requirements:** no-oracle settled-target counter, proportional additions, target-only exits, no new range on deposit, no rebalance, immutable-deployment containment. The current brief expressly permits replacing these expectations. |
| T | `W/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol`, complete; relevant canonical Crane and IndexedEx testing/adversarial/deployment/architecture skill sections | **Source observation:** the existing base deploys real registry/package/facets/PoolManager and mixed-decimal tokens. It is the appropriate starting point for later production-first evidence, not a runtime result from this assignment. |
| U | Uniswap official Flash Accounting documentation, fetched as Markdown on 2026-10-25: `https://docs.uniswap.org/contracts/v4/concepts/flash-accounting` | **Public primary-source observation:** swaps and liquidity modifications update deltas during an unlock; the final debts/credits must be resolved. This supports the distinction between visible in-unlock state and completed custody settlement. |

Public research used only public identifiers. The generalized searches were `site.app.uniswap.org whitepaper v3 concentrated liquidity` and `site.docs.uniswap.org contracts v4 concepts flash accounting liquidity fees donate`. A subsequent open requested `https://app.uniswap.org/whitepaper-v3.pdf`. Those provider search/open calls yielded no usable source text in this session, so I rely on neither their presumed contents nor the PDF. The separate official documentation fetch in U succeeded. No private excerpts or local paths were sent to public search.

### Important evidence boundaries

- The audit's numerical profits are **reported PoC results**, not new results and not illustrative calculations invented here. Conversely, the numerical examples below are **illustrative algebra**, not reported exploits.
- The audit's historical “Latent: not deployed” classification is not a current chain inventory. H's statement that existing deployments are immutable is likewise documentary evidence, not chain verification performed here.
- The fee oracle in the current source supplies policies such as the local reserve ratio. Its name is not evidence that a manipulation-resistant token exchange-rate oracle exists. [M, P, D]
- No source or skill grants permission to implement this recommendation. No conclusion here is council consensus or a security proof.

## Assumptions

1. The replacement remains a hookless V4 pool strategy with no more than three managed positions, two non-rebasing, non-FoT ERC20 underlyings, and one fungible ERC20 vault share. Both target orientations and non-18 token decimals are required. [R, D]
2. A specific pair can supply an independent, sufficiently fresh reference ratio under a documented trust model. **This is a deployment prerequisite, not an established fact.** A named chain/pair, feed implementation, addresses, and calibrated risk parameters have not been supplied.
3. The first release need not preserve arbitrary exact-output money routes, a fixed local-target sleeve, same-manager nested buffering, or swap-based permissionless rebalancing. I explicitly recommend changing those expectations.
4. The retained user preference for `getRate` is authoritative for this recommendation. I do not reinterpret it as a request for NAV.
5. Existing deployments are not silently upgraded. Any replacement package and any migration require separate authorization and verification.

## Coverage

| Required target or question | Status | Treatment |
| --- | --- | --- |
| Full brief and `CLAUDE.md` | Examined | Read completely. |
| APEX-012/024/025/026/040 | Examined | All five sections read, classifications retained above. |
| Money, Accounting, LiquidationQuote, Inventory, Geometry, Harvest, Repo, EconomicTarget | Examined | All named source files read completely. |
| Relevant query, projection, SY, package and execution surfaces | Examined | The files enumerated in E, I, D and X were read completely. Not every mechanical metadata facet in the directory was reviewed. |
| Direct Balancer rate adapter | Examined | Full RP source read. |
| Relevant V4 hook rate consumers | Partially examined | Direct CP and weighted valuation/settlement paths inspected. This is enough to establish non-redemption valuation, not a review of all hook families. |
| Questions 1-5: ownership, issuance, deposits, cost/fee attribution, withdrawals | Answered | Preferred machine sections 1-5 below. |
| Questions 6-9: quotes, maintenance, gas, price reference | Answered | Sections 6-9; pair-specific oracle selection remains a deployment gap. |
| Questions 10-13: attacker economics, consumers, findings, validation | Answered | Sections 10-13; no runtime verification claimed. |
| Question 14: requirements, eligibility, simplest surface | Answered | Section 14 and alternatives. |
| Historical apportioned-reserve PRD | Examined | Context, explicitly superseded where this recommendation differs. |
| Other optional old reports, tracker, records, open-questions file | Not examined | Not needed to override the current brief or establish the current paths. No claims about their contents. |
| Existing test results | Not examined as fresh runtime evidence | Base source inspected; no project tests executed. |

## Conclusions

**Recommendation:** accept the cost of a real price-reference dependency rather than pretend that arbitrary imbalanced deposits into one fungible claim can be credited without defining their relative value.

One ERC20 is useful here precisely because its holder owns the same fraction of core, both wings, both idle balances, and every shareholder-owned fee. Separate internal “section accounts” can organize costs; they cannot create different investor entitlements while the externally transferable share remains completely fungible.

The useful replacement for the vulnerable design is not “approximately swap half and keep the existing accounting.” It is a change of ownership boundary:

- Entry buys a measured fraction of a reference-valued portfolio using only the entrant's actual retained contribution.
- Exit takes a measured fraction of the actual portfolio, then executes a trade belonging only to that exiting account.
- Maintenance changes everybody's common portfolio under a separate policy and cost budget.
- Quote reads never create a payable target liability.

An execution quote can be honest and still be a dangerous oracle for somebody else's pool. I recommend listing the vault share as a distinct traded asset first, without a raw-target/share parity assumption. A separate, explicit NAV rate adapter can support selected integrations after their own validation; it must not alter the canonical execution-quote meaning of `getRate`. [E, RP, HC, HW]

## Preferred complete design

### 1. Units, state, and ownership

Use token0/token1 native units at transfer and PoolManager boundaries. Use 18 decimals for the replacement share, independent of target-token decimals. Use a higher-precision accounting numeraire, for example `10^36` accounting units per whole target token, with checked full-precision multiplication/division. This is accounting precision, not extra token backing.

Store:

- The immutable pool key, manager, target orientation, price-reference adapter and risk parameters.
- Exactly three position records: range bounds, salt, actual liquidity, and fee checkpoint information.
- Two shareholder-owned idle balances.
- Explicit current-operation entrant credit and withdrawal escrow, excluded from the common book until their respective ownership transitions.
- Any real non-shareholder liability, separately by token. For the recommended first release, there is no performance-fee accrual or keeper payable.
- Share supply, one vault-wide operation lock, callback authorization, and maintenance reference/epoch/cost-budget state.

For raw share balance `h` and total supply `S`, the ownership fraction is `h/S` of **every shareholder-owned asset**, not just core liquidity. An idle token, an accrued fee, or a wing does not become ownerless merely because a liquidity-add calculation cannot use it.

The first version should charge no additional vault entry, exit, performance, or keeper fee. Pool swap fees and protocol fees are real execution costs. All net LP fees attributable to the vault belong to shareholders. This is an explicit recommended fee policy, not a claim that every surrounding application already charges zero. A future vault usage-fee policy would need a new allocation equation and reviewed route parity, rather than being hidden inside credit.

**Donations.** At positive supply, unsolicited token transfers and fee-growth donations become common equity, never the next depositor's input. Synchronize them separately from observed authorized pulls. At zero supply, pre-existing unsolicited balances are not first-depositor credit: record them as a non-shareholder surplus payable to an immutable deployment-designated recovery recipient, excluded from bootstrap NAV. Paying that identified payable must not let arbitrary callers skim equity. This changes the historical no-separate-surplus preference where necessary and avoids first-minter appropriation.

**Bootstrap.** Require a valid reference, sufficiently funded real initial core liquidity, and contribution NAV of at least one whole target token. Initialize the first share price to one whole target per whole share:

```text
W = 10^36                          accounting units / whole target
U = 10^18                          raw shares / whole share
S_initial = floor(C_initial * U / W)
```

The minimum is a mechanical dust floor, not a claim that one target token is enough economic liquidity for launch. The deployment gate additionally requires meaningful pool/seed liquidity for that pair. A target-only seed can use the same approximate swap as later entries; if no external depth can execute it, bootstrap must be funded with both tokens. Do not pretend an empty pool can buy the missing token from itself for free.

I prefer **no permanent dead shares and no fictional virtual assets** in this design. High precision, minimum minted units, and an explicit rounding-loss guard are still mandatory; a bootstrap minimum alone is not the defense against APEX-040.

**Rounding and dust.** Round liquidity funding up and removable amounts down according to V4's actual math. Round share issuance down; leave fractional share value with existing equity, subject to the strict bound below. Unused entrant token dust is either expressly retained and valued as idle equity or refunded. If its accounting value is zero, refund it rather than calling it a credited contribution. Terminal redemption removes all remaining liquidity and pays all remaining equity, instead of applying another fractional floor. [P, X]

### 2. Exact issuance basis and equations

#### Reference-valued positions, not spot-derived principal with a reference multiplier

Let `P` be the independent reference price in **whole token1 per whole token0**. With token decimals `d0,d1`, the raw-unit price used by liquidity math is:

```text
p = P * 10^(d1 - d0)               token1 atoms / token0 atom
r = sqrt(p)
```

For a position with liquidity `L`, lower square-root bound `a`, upper bound `b`, and `z = clamp(r,a,b)`, its mathematical reference composition is:

```text
x0_ref(L,a,b) = L * (1/z - 1/b)
x1_ref(L,a,b) = L * (z - a)
```

These expressions describe the valuation basis; implementation must use the corresponding bounded Q96/full-precision arithmetic and its documented rounding. This is the same range structure observed in `Inventory.principal`, evaluated at the **reference** square-root price rather than live `slot0`. [P: Inventory.principal]

If target is token0:

```text
value(x0,x1;P) = W * (x0/10^d0 + (x1/10^d1)/P)
```

If target is token1:

```text
value(x0,x1;P) = W * (P*(x0/10^d0) + x1/10^d1)
```

For an equity book `B`:

```text
N(B;P) =
    value(owned idle + accrued shareholder fees - real liabilities;P)
  + sum over j in {core,upper,lower} value(x0_ref(L_j),x1_ref(L_j);P)
```

Subtract only real, explicitly booked liabilities; do not subtract invented “liquidation haircuts” or treat pending caller tokens as equity. If liabilities cannot be fully represented without negative equity, stop new issuance.

Live pool inventory remains the inventory actually delivered on withdrawal. The reference composition above is a **valuation of a range claim**, not a representation that the vault presently holds those two token quantities in custody. This distinction is essential.

#### The ownership cut

After the entrant's swap, before adding any entrant liquidity, checkpoint **all old-position fees**, including fees earned from that very swap. Let:

- `S` = old share supply.
- `B_old` = old equity at this cut, including those fees.
- `A = N(B_old;P)` at the operation's fixed reference snapshot.
- `E` = only new liquidity increments and idle tokens acquired from the entrant's segregated credit, after execution costs and refunds.
- `C = N(E;P)`.

No old liquidity may be removed or re-ranged as part of this entry. With unchanged old ranges and liquidity, the range valuation is additive; there is no need to infer the entrant's contribution from the change in a live liquidation quote.

In exact arithmetic:

```text
m = floor(S * C / A)               when S > 0 and A > 0
S_after = S + m
N_after = A + C
```

For integer valuation, compute a conservative old-equity upper value `A_hi` and contributed-equity lower value `C_lo`, with documented numerical error bounds:

```text
m = floor(S * C_lo / A_hi)
```

Do not use an under-rounded denominator and an over-rounded numerator. Verify the final settled book agrees with `B_old + E` within the explicit arithmetic bounds; reject unexplained deltas. This is a conservation check, not an alternative source of deposit credit.

The old holders' ideal post-entry reference claim is:

```text
(S/(S+m)) * (A+C) >= A
```

The new shares buy into every component, including old fees, **by paying for that fraction through the denominator**. “Old fees belong to incumbents” means the entrant does not receive those fees as free credit; it does not require a permanent private fee account that would break fungibility.

Require `m >= 10^12` raw share units and a reference-accounting rounding-loss bound, separately from the user's `minShares`:

```text
newReferenceClaim = floor(m * (A+C) / (S+m))
C - newReferenceClaim <= ceil(C / 10^12) + documented valuation quantum
```

Use conservative interval bounds for this check in implementation. The `10^12` is a proposed precision policy, not a measured security threshold. Its purpose is to reject one-share-atom inflation traps even when a victim accepts a manipulated preview. Highly inflated share prices can make small entries unavailable; they must revert, not silently lose a large percentage. Validate donation profitability, repeated rounding, and the interval arithmetic before claiming APEX-040 closed.

#### Both tokens and retained imbalance

All new core increments, both wing increments, and both retained idle token balances enter `C`. There is no limiting-token issuance formula over only the new core.

For example, in illustrative reference-value units:

```text
old equity 1000; old supply 1000
old positions earn 2 from entrant swap
entrant spends 100; own execution costs leave contribution worth 97
retained contribution: core 80 + upper 12 + lower/idle 5

A = 1002
C = 97
m = 1000 * 97 / 1002, before share rounding
```

Credit is 97, not 80 and not 102. The two fee units belong in `A`, not `C`. The entrant bears the three-unit cost.

Full credit means full **reference value of the assets retained**, not reimbursement of the gross target input or a guarantee that buying liquidity at a displaced market price has no cost. If adding a range increment consumes tokens worth more than its reference value, that difference is an entrant placement cost, disclosed by the preview and constrained by minimum credit/shares. Retaining the overage as idle tokens avoids forcing such a conversion.

### 3. Complete deposit machine

The public exact-input entry supports target-only deposits and an explicit dual-token entry. The dual-token route does not need a swap. A deterministic target-only convenience route initially swaps **50% of the target input**, not a raw-token ratio. A separately supplied plan may select another bounded amount, but the contract validates that plan and never assumes 49%, 50%, or 51% is economically optimal.

1. **Validate before external work.** Check deadline, initialized state, enabled inbound route, nonzero recipient, nonzero input, and vault-wide lock. Reject a manager already unlocked by another operation. Freeze a valid independent price/reference-round snapshot and pair-specific deviation limits.
2. **Checkpoint the old book.** Observe positions, supply, owned idle balances, accrued fees and donations. Collect fees with no swaps and no range replacement. This is a collection checkpoint, not the current harvest routine's potential reshape. No entrant credit is in NAV yet.
3. **Pull actual caller funds.** Measure each authorized inbound delta and segregate it. No credit from an absolute balance. Prefer ordinary authenticated pull/Permit2; reject arbitrary public `pretransferred=true` for this new family unless a separately reviewed, operation-bound receipt identifies payer, tokens, amounts and nonce. SY's internal held-share redemption is not permission for an outsider to claim held assets.
4. **Execute only the entrant's swap.** For target-only input, spend at most the specified portion of its credit, with a finite directional price limit and minimum opposing output. Check live/reference deviation before and after. Use the configured pool directly, not arbitrary caller `target+calldata`. The rest of the entrant's target remains its credit.
5. **Resolve partial fills explicitly.** The default convenience route requires the planned swap input to be fully consumed or reverts atomically. A separate plan can explicitly permit a partial fill; its unused input stays entrant credit and is either retained with value or refunded. A failure is not a zero-output success.
6. **Checkpoint old fees again.** The vault's existing LP positions may have earned part of the entrant's swap fees. Collect or exactly account them before changing their liquidity. Finalize `B_old` and `A`. This prevents entry swap fees being counted as new contribution.
7. **Place only entrant inventory.** Add the maximum affordable matched liquidity to the existing full-range core using its two actual token balances. Route token0 excess into the upper wing and token1 excess into the lower wing **only if the existing wing accepts that token single-sided and passes capacity/reference-cost checks**. Do not add a new range by overwriting a live slot. If a wing is mixed, unavailable, or full, retain that overage as credited idle inventory or return it according to the user's plan.
8. **Record principal and fees separately.** On every `modifyLiquidity`, distinguish liquidity-funding principal from `feesAccrued`. The current callback's aggregate local delta alone is insufficient attribution for this design. No further swap occurs after entrant liquidity has been added.
9. **Settle, measure and credit.** Resolve manager deltas, verify actual custody, determine new `L` increments and retained idle amounts, reserve refunds, compute `C` and `m`, and check `minShares`, optional minimum reference credit, precision bounds and operation caps. A caller-supplied plan is not authority to invent these quantities.
10. **Mint at the ownership cut.** Only after the preceding checks, merge `E` into equity and mint `m`. Refund only this entrant's explicitly unused credit. Emit actual inputs, spent amounts, retained contribution components, reference identifier, shares and refunds. Release the lock after all payments and final backing checks.

The entire transaction reverts on failure; no partially issued shares or stranded partially accepted deposit survives. One manager unlock can execute the ordered operations while the vault remains locked; separate unlocks are also possible, but never skip necessary accounting merely because somebody else has unlocked the manager.

**Cost allocation:** the entrant pays its swap fee, spread/impact, addition rounding, and unfavorable reference-valued placement. Existing holders' old position liquidity and cash are never used to complete its contribution. Existing positions can nevertheless trade as LPs against the entrant's swap; that is ordinary pool participation, not a debit of communal cash to subsidize entry.

### 4. Fees, liabilities, and ownership during execution

Do not make the same money appear as both input and income.

- Fees earned before the entry cut, including the entrant's own trade against old liquidity, increase incumbent equity.
- Fees already collected are removed from the uncollected-fee term when added to idle balances.
- A `modifyLiquidity` principal payment netted against collected fees is not evidence that the entrant supplied the fee amount.
- An unsent refund remains an entrant liability and is excluded from shareholder NAV.
- A withdrawal slice placed in exit escrow is no longer backing remaining shares.
- Pool protocol fees never received by the vault are not vault income.
- Donations received while processing an entry are not authorized entrant credit. Reconciliation must assign them explicitly on the correct side of the ownership cut, or reject an unexplained reconciliation.

After minting, all ordinary fees accrue to the then-current common share supply. No deposit cohort or section has a hidden senior claim. A separate management/performance fee is deliberately absent from the preferred first version.

### 5. Complete withdrawal machine

Expose two honest routes: **pro-rata in-kind redemption**, and **pro-rata redemption plus target conversion**. The latter is the normal target-only experience; the former is a necessary liveness path.

For `q` raw shares, pre-burn supply `S`, and ownership fraction `f=q/S`:

```text
L_remove[j] = floor(q * L[j] / S)
idleSlice[i] = floor(q * ownedIdle[i] / S)
```

Checkpoint all pre-existing fees into idle equity before these amounts are calculated, or produce mathematically equivalent fee attribution. For `q == S`, remove **all** liquidity and take **all** owned idle equity rather than applying the floors.

Sequence:

1. Check deadline, authorization/share balance, nonzero amount, recipient, vault lock, and manager locked-at-entry. Disabling new deposits must not disable exits.
2. Collect pre-exit fees without compounding or re-ranging. Reconcile donations. Fix the slice from every position and both idle balances.
3. Burn or irrevocably reserve `q` shares inside the locked transaction, and deduct the slice from the common book before external recipient calls. There is no external observation of a valid lower-supply/old-assets rate.
4. Remove exactly those liquidity amounts. Attribute actual removal deltas, including collection rounding, to the slice. Never close everybody's core merely to produce a quoted target amount.
5. For in-kind redemption, transfer the slice's actual token0 and token1, subject to per-token minima, and finish. This route does not use a price oracle, swap quote, tick walk, or target liquidity.
6. For target redemption, place the slice in exit escrow. Swap **only its opposing token**, exact-input, through the pool at the requested finite price limit. The remaining vault liquidity can fill this swap and earns its fees. That remaining liquidity and its new fees stay with the remaining shareholders.
7. Compute target payout from actual deltas:

```text
targetPaid = targetRecoveredFromSlice + actualTargetReceivedBySliceSwap
```

8. Check the user's fixed `minTargetOut` and deadline. Default strict target-only mode additionally requires the opposing input to be fully consumed. If it cannot be sold, revert the whole redemption even if an artificially low target minimum would otherwise pass.
9. An explicitly selected residual-return variant may pay `targetPaid` plus the unspent opposing escrow. Its ABI and preview must disclose both outputs. It must not silently retain that opposing token for remaining shareholders or assign it zero value.
10. Transfer payouts, settle all manager deltas, verify backing, and release the lock. Any failure rolls back the burn, removal and swap.

**Last holder:** a complete exit can remove the only liquidity that could buy the opposing token. This is a real absence of a buyer, not an accounting failure. Strict target-only redemption may fail; the same holder must be able to redeem both tokens in kind. There is no guarantee of a target-only terminal exit in every pool state.

**Rounding:** non-terminal liquidity/cash fractions round down, leaving bounded dust with the common book. The quote must expose this. Reject a redemption producing zero meaningful outputs rather than burning a claim unnoticed. Permit a holder to redeem all of its balance, with user minima; terminal cleanup assigns all equity, not another proportional floor. Non-shareholder surplus liabilities remain outside the terminal payout.

Ordinary LP inventory movement caused by the slice's sale is allowed. The correct invariant is preservation of the remaining holders' proportional position ownership, plus attribution of the subsequent pool trade, not a constant target balance or a constant spot mark. [B, H]

### 6. Quotes, `getRate`, projected state, SY, and exact-output

#### Execution preview

`previewRedeem(q, routePolicy)` simulates exactly the sequence above:

- pre-exit collection;
- proportional removal of only `q/S` of each position;
- proportional cash/fee assignment;
- sale of the actual recovered opposing amount through **external liquidity plus the remaining vault liquidity**;
- actual fee rules, finite price limit, tick crossings, partial-fill status, rounding and residual policy.

It must not remove all vault liquidity before quoting a small redemption. The existing full-book `LiquidationQuote.quote` cannot simply be divided by supply to produce this result. Its pool-overlay machinery is potentially reusable, but its ownership/removal semantics must change. [Q, E]

Prefer a quote result containing target output, opposing residual, consumed input, completion status, work used, block/reference identifiers and relevant price limits. In a fixed unchanged state, scalar standard previews return the same strict-route target output or revert if that strict route is not executable.

#### One-whole-share rate

Let `U=10^18` raw shares for the proposed share decimals, `dT` be target decimals, and `T(U)` the strict canonical target-exit preview for those `U` shares:

```text
getRate() = floor(T(U) * 10^18 / 10^dT)
```

More generally, for a declared quote size `q`:

```text
normalizedRate(q) =
    floor(T(q) * 10^shareDecimals * 10^18 / (q * 10^targetDecimals))
```

The canonical call uses only `q=U`. The public size preview uses the actual requested size.

If `S<U`, there is no actual one-whole-share ownership slice to redeem. Return an explicit unavailable/revert result; do not extrapolate a smaller exit and label it a one-share execution quote. The same applies at zero supply. Provide a separate initial issuance-price query for bootstrap integrations. This deliberately replaces the current synthetic empty `1e18` execution rate. [E, RP]

The canonical quote policy must be immutable and match the default target-redemption route: same pool, removal semantics, finite maximum price movement and full-consumption requirement. User executions can choose a stricter limit/minimum. A no-argument rate cannot encode every user's route choice or every slippage tolerance.

In general:

```text
T(q) / q != T(U) / U
```

Neither the full-supply quote nor the one-share quote is universally conservative for all states and sizes. Remaining own liquidity, range crossings, fees and withdrawal size all matter.

#### Projected-state queries

Carry projected position liquidities, idle balances, fee checkpoints, supply, holder shares, reference identity, pool price/tick/liquidity and changed tick-boundary overlays. `quoteRate(state)` performs the **one-share** exit on that projected state; `quoteAssets(state,q)` performs the actual-size exit. After a projected swap, a stale fee or external-liquidity overlay is not usable.

Bind snapshots to vault, chain/pool configuration, schema version and their baseline state. They are read-only calculations, never authorization to settle user-supplied book values. Execution always reads actual custody and recomputes its own checks. Unsupported transitions must fail explicitly rather than quietly falling back to live or linear pricing. [E: Projection.decode, transition, _swap]

#### Exact-output choice

For the preferred first release, **do not support arbitrary exact-target-output withdrawal or swap-dependent exact-share-output deposit**. Remove their advertised support for this new family and return an explicit unsupported-route error on applicable compatibility surfaces. The current `sharesForAssets` and `inputForShares` scalar inversions do not invert a nonlinear actual-slice swap. [M, I]

Users choose an exact input with a minimum output. An off-chain solver may select the share input for a desired target amount, and a router can return any actual surplus to that user. That is not a promise that a linear on-chain `exchangeOut` quote is exact. A later exact-output interface needs a separate correct inverse/forward-verification contract and refund rules.

This sacrifices integrations that require exact-output buffering; they are ineligible until adapted, rather than accidentally “supported.”

#### SY

SY deposit/redeem must call the same money machine, not bypass it. Keep SY's `exchangeRate` as an explicitly documented **accounting reference value per share**, if that integration requires such a value, with accurate asset decimals. It must not silently alias the canonical execution-quoted `getRate`. SY's actual redemption preview remains size-specific. Correct `assetInfo` for the actual target decimals once share decimals are independent. The current implementation's use of share decimals happens to align with its target-decimal share initialization, which this recommendation changes. [D, E: SYTarget]

### 7. Fee compounding, range lifecycle, and maintenance

Shareholder ownership is global. Core fees routed into a wing still belong to all shareholders in the same fractions. No range earns assets for a different shareholder cohort.

Separate **collection** from **strategy mutation**:

- Collection realizes owed fees into the common idle book. It does not change risk allocation or swap inventory.
- Compounding uses fee token0 in the upper wing and fee token1 in the lower wing when each accepts that token at the current/reference-compatible range.
- A mixed or unavailable wing leaves its corresponding fees idle until an eligible maintenance transition. There is no compulsory lossy swap merely to eliminate an idle balance.

**First-release maintenance should perform no portfolio-funded swaps.** Retire the current permissionless `bestSwap` rebalance path. The approximate entrant swap already supplies the core on entry, while trading and fee reinvestment can change the composition over time. This is my preferred simplification for APEX-025, not a claim that merely retaining its current validator with a new name fixes it. [RB, A25]

Permit bounded, deterministic no-swap wing replacement:

1. Use a fresh independent reference and the same live/reference deviation gate as entry.
2. Derive eligible wing boundaries from that reference, with a deployment-fixed gap wider than the allowed instantaneous deviation, tick-aligned outward. Core remains full-range.
3. Keep existing wings until a reference-based movement threshold and maintenance epoch permit replacement. Do not recenter on an arbitrary caller's live spot.
4. Close and collect a replaced wing completely before reusing its slot/salt range record. Never orphan fee claims. Recover tokens as common equity; pair principal into core where the deterministic plan permits, and place remaining token0/token1 into the corresponding wings. Fees intended for wing compounding remain separately identified during the plan, though not separately owned.
5. Evaluate the complete before/after portfolios at the **same reference snapshot**, including the reference composition of both old and new LP ranges.
6. Bound realized reference-value loss:

```text
loss = max(0, N_before(P) - N_after(P))
loss <= remaining immutable epoch budget
```

Each accepted action consumes that budget; a later gain does not replenish it within the epoch. Require minimum non-dust progress and at most one replacement per slot per maintenance epoch. This prevents callers from repeatedly spending a per-call tolerance without an aggregate limit.
7. Validate the fixed plan and budget on chain. Caller `minimumValueAfter=0` cannot loosen protocol constraints. The caller pays gas; no first-release bounty is extracted.

All incumbent holders at maintenance time bear permitted placement/removal rounding and reference-value loss pro rata. An entrant's deposit must not force an unrelated expensive reshape of the old book.

The pair-specific gap, movement trigger, epoch length and maximum budget must be immutable deployment arguments and approved through the validation gate. A live/reference gate and finite loss budget reduce attack opportunities; they are not proof of zero MEV or proof that the oracle is correct. When the reference is unavailable, maintenance stops and exits remain available in kind.

### 8. Independent-price availability and failure policy

A valid adapter must define the ratio direction, decimals, source timestamps/rounds, validity interval, confidence/error policy, and failure result. Accept only a documented source independent of this vault's immediate pool depth and transaction.

A pair may use independent token/reference feeds combined into a cross-price, provided both legs are sufficiently fresh and their timestamp skew is bounded. A robust observation source from genuinely independent liquid markets may also qualify, but “it is a TWAP” alone is insufficient: manipulation horizon, economic depth, update latency and shared dependencies need analysis. A same-pool instantaneous spot or a current full-book exit quote does not qualify.

Use one validated snapshot for the whole operation. Do not read a second oracle value after the entry swap and call that the same valuation cut. Fail issuance closed for stale/zero/inconsistent values, excessive uncertainty, incompatible scaling, sequencer/outage conditions applicable to the chosen chain, or live/reference deviation beyond the deployed bound.

Also cap cumulative accepted entry credit per reference round/interval, without restoring capacity after a withdrawal in that interval. This bounds stale-reference exposure but does not transform a stale price into a correct price.

No oracle failure may prevent proportional in-kind redemption. Target exits depend on actual execution and user minima, not NAV solvency promises. The execution quote can remain available when the independent reference fails, provided its pool/operation state is valid; a NAV integration adapter must fail closed instead.

**Unverified prerequisite:** the brief supplies no pair-specific adapter. I have not established that one exists for every contemplated token pair. Therefore this recommendation is not launch-ready for arbitrary pairs. Do not deploy it with a same-pool fallback to make the checklist appear complete.

### 9. Gas and solver placement

No gas measurements were performed or inferred.

Bounded work:

- Reference valuation over three positions and two idle balances.
- Principal/fee arithmetic, proportional liquidity slices, share mint math.
- At most a fixed number of position collection/addition/removal actions.

Unbounded-by-position-count work:

- A real V4 swap can cross many initialized ticks/bitmap words.
- A faithful execution preview may walk the same boundaries.
- External feed reads and integration calls add cost and failure dependencies.

The preferred approximate entry avoids iterative sizing on chain. Matched-core arithmetic is closed form, and the excess does not need solving because it is credited in wings or idle balances.

A separate oracle-free proportional design can move its sizing search to an off-chain solver or a view call and accept a verified plan. That genuinely removes repeated solver work from the **transaction**, so “exact proportional sizing must always be prohibitively expensive on chain” is too broad. It does not remove real swap tick traversal, RPC computation cost, state-change failures, or the need to verify a plan after actual execution.

Likewise, raising a quote work limit is not a universal liveness fix. Keep bounded quotes with truthful `WorkLimit` versus `MarketLimited` outcomes. Do not skip dust ticks merely because their current net liquidity is small: boundaries can affect fee accounting and the exact simulated path. The principal liveness fix is making in-kind exit independent of that walk, not relabeling an incomplete quote as successful. [Q, A26]

### 10. Attacker economics and what is actually improved

The proposal removes the particular rule “mint from one temporary liquidation value, then pay a different temporary liquidation value out of everybody's target cash.” It does not make LP market risk, oracle risk, or arbitrage disappear.

#### Required attacker ledger

For every round trip measure, at one independent comparison price and after closing positions and debts:

```text
attacker PnL =
    change in attacker wallet token values
  + value of attacker remaining LP/claim positions
  - initial capital or outstanding repayment obligations not already in wallet changes
  - flash/borrow costs
```

Count actual swap fees in the actual flows, not a second time. Report gas separately where it is not part of the token ledger. Do not count both final LP withdrawal proceeds and the LP's pre-withdrawal inventory value.

In parallel measure the remaining holders' reference equity and their actual in-kind ownership, and compare against a matched no-attack/control path. A profitable external arbitrage at the expense of an attacker's own LP is not a vault exploit; a profit funded by incumbent dilution or misattributed escrow is.

#### Depth-only settled JIT

Changing external depth alone does not change the reference value of an unchanged owned `L`/range book. Thus it cannot directly inflate the denominator or create a target withdrawal liability.

It can improve the entrant's actual swap output, giving a larger real contribution and legitimately more shares. It can improve an exiting holder's actual sale. Therefore I reject the historical blanket test that the same gross target input must mint exactly the same shares with and without JIT, regardless of execution. The correct test holds **actual contributed assets** fixed, or accounts for the extra assets and the JIT provider's loss/change of inventory. [H]

Illustratively, a slice with 50 target and opposing tokens worth 50 at the comparison price might receive 40 target without external depth and 50 with it. The 10-unit execution improvement is not paid from an invented vault entitlement. The JIT LP must actually deliver target and acquire opposing inventory; its removal and unwind are part of attacker PnL. This example is not evidence of profitability or non-profitability.

#### Unsettled JIT and nested unlock

Public entry, exit and live portfolio/execution-rate queries reject an already-unlocked manager. The vault's own authenticated callback is the sole permitted exception to that manager condition, while the vault-wide operation lock remains set. The new machine never uses the old “skip harvest/place and pay from local cash” branch. This directly addresses the in-unlock opportunity described in A12, but settled manipulation still requires the other controls. [M, Q, A12, U]

#### Spot manipulation before deposit or redemption

Evaluate every LP at the reference price itself. Valuing its spot-derived principal at the reference price would still let spot motion change the issuance denominator, even with an excellent external feed.

A manipulated entry also changes the assets the entrant buys and the cost of buying new liquidity. Actual contribution measurement, fixed-reference range valuation, and pre/post live/reference bounds act together; neither an approximate swap nor a reference multiplier alone is sufficient.

A redemption pays actual removable inventory and actual swap proceeds. If a manipulator moved the pool first, it must account for both the capital needed to move it and the subsequent unwind against all changing LP positions. The remaining vault can be a counterparty to the exit trade; that market exposure is intended, while selling more than the exit escrow is not.

Even with range-reference valuation, issuance at a stale or erroneous reference can transfer value. A tight deviation bound still permits some deviation and can produce boundary MEV. No untested claim of zero attacker profit is warranted.

#### Donation, fees, and maintenance

Live donations raise common NAV without minting attacker credit. The entrant's own LP fee payment increases incumbent NAV before new shares issue. A donation attacker may recover its own pro-rata donation, but must not recover extra victim principal through coarse share rounding. The minimum minted units and rounding-loss invariant are the proposed defense, subject to production evidence.

Maintenance no longer lets an attacker force a large portfolio-funded swap against a spot-derived loss check. However, even no-swap placement can be disadvantaged by bad reference timing or price manipulation. The reference-based topology, fixed-reference before/after valuation and cumulative budget must be tested as a unit.

### 11. Rate consumers and liquidity usability

**Observed adapter mismatch:** the existing `StandardExchangeRateProviderFacet` prices total supply through the vault's exit-preview/transition interface. A future change to the vault's canonical one-share `getRate` would not automatically change that adapter to one-share semantics. RP's comments intentionally request full-book valuation even if full settlement is unavailable. That contract cannot be treated as a transparent adapter for the new semantics. [RP]

**Observed direct consumers:** CP `ratedReserve` and weighted `ratedPairUnits` turn held shares into rated reserve units by multiplication. No redemption occurs to validate that reserve valuation. A swap may subsequently redeem a different output leg; that does not cure manipulation of the priced input reserve or establish that all rated shares could be liquidated at that scalar rate. [HC, HW]

Consequently, an attacker can improve the real one-share exit quote with temporary depth, sell shares into an external pool that pays at that inflated mark **without redeeming them**, then remove the depth. The vault can have completely correct actual-slice accounting while the external pool loses. A quote being executable for one share is not a manipulation-resistance guarantee for a separate inventory book.

My integration policy is:

1. **Preferred initial listing:** trade the actual vault ERC20 against target or another token in an ordinary price-discovering pool, with no claim of parity and no live execution-quote rate multiplier. Buyers receive shares, not a fixed target claim.
2. **NAV-rated integrations:** use a separately named independent-reference NAV provider with explicit freshness, deviation, exposure and trade-size policy. It returns accounting value per share, not `getRate`. Deploy/validate it separately; do not silently retarget the generic full-supply adapter. Such a provider still does not guarantee liquidation or eliminate oracle-adverse-selection risk.
3. **Execution-backed integrations:** when an integration wants a guaranteed target amount for a trade, redeem the relevant actual-size shares and settle actual target proceeds atomically, subject to minima. Do not price a large payment by multiplying a one-share quote.
4. **Same-manager V4 buffering:** the preferred strict manager-entry rule intentionally makes synchronous automatic buffering inside an unrelated unlock ineligible. Prepare/redeem shares before entering that outer manager unlock, use raw share inventory, or separately design and validate an authenticated shared-unlock integration. Do not retain insecure local-cash shortcuts just to claim composability.

Raw target and a fee-earning two-token/range portfolio share are not economically identical. They differ in inventory risk, fee income, redemption liquidity, size-dependent execution cost, oracle exposure and possible unavailability. A stable/peg-style pool must explicitly absorb and bound those differences; the vault cannot promise them away.

### 12. Audit implications, reentrancy, and liveness

| Finding | Proposed design change | What remains to be demonstrated |
| --- | --- | --- |
| APEX-012, High in the cited audit | Remove live liquidation quotes from issuance and target liabilities; reference-valued actual contribution; real proportional exits; reject foreign unlock context | Settled/unsettled JIT, spot round trips, fee attribution, oracle faults and integrator PnL on production paths. No static closure. |
| APEX-024, Low in the cited audit | Remove exactly `q/S` from each position; sell only the exit escrow; actual payout; strict residual policy | Large/terminal exits and attacker backruns show no sale of remaining holders' escrow-free inventory. Ordinary LP counterparty exposure remains intentional. |
| APEX-025, Medium in the cited audit | No portfolio-funded swap rebalance in the first release; no-swap maintenance uses a fixed independent reference and cumulative budget | Range replacement and fee placement cannot bypass budgets or be churned profitably beyond the disclosed policy. |
| APEX-026, Medium in the cited audit | Dual-token issuance accounting and in-kind exit do not depend on sale quotes; target quote/route truthfully reports work/depth failure | Dust ticks cannot freeze in-kind exits. Target swaps and `getRate` may still be unavailable; do not claim those always live. |
| APEX-040, Low in the cited audit | Independent share precision, seed floor, minimum minted units, donation attribution and rounding-loss guard | First-mint/near-empty attacks, fee-growth donation, repeated dust operations and terminal/rebootstrap paths. |

Apply one reentrancy state across every facet and SY route. Public economic views must not observe an intermediate burn/removal or mint/settlement state. Reject external `getRate`, NAV, supply-to-asset previews, and live transition snapshots while the vault is operating; reject inappropriate manager-unlocked contexts as above. Use internal calculations for the vault's own callback, not a public-view exception keyed only on `msg.sender`.

Authenticate the manager, operation payload and phase. Do not permit arbitrary callback re-entry, an attacker-selected operation array, or a second callback after its authorization has been consumed. Observe and settle actual deltas; a visible manager liquidity balance alone is not settled token custody. [X, U]

A quote budget exhaustion is not evidence that no executable liquidity exists. A lack of liquidity is not evidence that the quote implementation exhausted work. These must remain distinct failure classes. The in-kind route is the escape from both classes, subject to the underlying tokens and manager actually allowing transfers/removals.

### 13. Production-first validation plan

This is a proposed plan; **none of these tests was run here**.

Use the existing Wings TestBase and real registry-deployed package/facets, real manager, fee oracle, and direct V4 pool. Extend the real price-reference adapter with controlled non-SUT external observations where justified; do not mock the vault or replace its accounting with a test implementation. Build the changed production artifacts before executing tests in a future authorized implementation task. [R, T]

Required gates:

1. **Ownership conservation.** At every completed operation, owned locals plus actual positions/fees equal shareholder equity; escrow/refunds/surplus liabilities are separate. Every non-terminal exit removes only its rounded fraction; every terminal exit retires all equity positions.
2. **Credit completeness.** Core-only, upper-only, lower-only, idle-only and every mixed contribution count correctly. Equal retained reference contribution produces equal mint credit independent of how it is partitioned, apart from specified rounding. A large wing overage cannot become an uncredited donation.
3. **Incumbent preservation at entry.** At one fixed reference, old holders' post-entry claim is not reduced by new contribution placement beyond the explicitly bounded arithmetic error. Their share balances are unchanged.
4. **Old and own-swap fee attribution.** Use real swaps and real manager fee growth. Fees already owed and fees earned during the entrant's swap enter the old denominator exactly once. Test additions whose principal/fee net deltas have either sign.
5. **Actual payout conservation.** Target exits pay exactly slice target plus actual swap proceeds, less no undocumented charge. Opposing residuals are returned under an explicit mode or cause atomic revert. Neither refund nor exit can use another user's booked cash.
6. **Preview/execution parity.** At unchanged state, verify native units, share units, both target orientations, live and projected state, collection rounding, price limits, partial fills, current/protocol fees and post-removal liquidity. Compare one-share `getRate` against the actual one-share route, not against full-book value.
7. **Nonlinearity and unsupported exact-output.** Show different sizes receive their own quotes; verify every retired exact-output selector/interface fails as advertised and routers cannot bypass the restriction.
8. **APEX-012 round trips.** Honest baseline; settled JIT; unsettled JIT; deposit before and after spot changes; manipulate/deposit/unwind/exit; deposit/JIT/exit/remove JIT; both target orientations. Close attacker LPs and debts, value both tokens, and compare victim equity with matched controls.
9. **Oracle attacks/failure.** Stale cross-feed leg, inconsistent timestamps, zero/invalid output, decimal inversion, update-boundary entries, reference changes during callbacks, deviation-edge sandwich, round-cap exhaustion and available in-kind exits during outages.
10. **APEX-024 large exits.** Small, majority and full-supply exits with weak/no external depth; no whole-book opposing dump. Separate the remaining LP's legitimate trade/fees from unauthorized liquidation.
11. **APEX-025 maintenance.** Front-run/maintain/back-run; repeated calls; epoch boundaries; no-progress and dust actions; stale/manipulated spot versus unchanged reference; range replacement that tries to exceed the fixed budget. Demonstrate no portfolio-funded swap selector remains in the installed package.
12. **APEX-026 dust.** Real dust-liquidity ticks, spacing 1, empty bitmap words, no external liquidity, work exhaustion and gas-limited actual swaps. In-kind exit must remain independent of all swap walkers. A failed `getRate` must fail closed at consumers, not become zero-price/free acquisition.
13. **APEX-040 inflation.** Front-run bootstrap, dust first mint, fee-growth donations with attacker external liquidity removed/re-added, direct donation, split deposits, huge NAV/tiny supply, repeat rounding, full exit/rebootstrap and zero-supply surplus. The attack must revert or satisfy the documented negligible rounding bound, not merely a user-supplied `minShares=1`.
14. **Real integrations.** Current full-supply adapter is rejected or explicitly replaced; direct CP/weighted consumer tests exercise non-redemption valuation; manipulate one-share executable rates and attempt external pool extraction. Test raw-share pool trading separately from NAV-rated or actual-redemption integrations.
15. **Guards and token edges.** Facet-wide and read-only reentrancy, unauthorized callback, foreign manager unlock, SY held-share path, allowances/Permit2, deadlines, direct donations, pretransfer spoofing, mixed decimals and signed-delta limits. Registry disable stops inbound only.
16. **Installed surface and cost.** Target-to-facet-to-package-to-proxy selector coverage, immutable configuration and no unauthorized upgrade path; deployed runtime size; measured gas across few/many tick crossings and entry plans. No gas claim is accepted from arithmetic complexity alone.

For attacker-profit assertions, require both economic PnL and inventory/ownership invariants. A passing historical test that only compares two manipulated liquidation quotes is not the new acceptance criterion.

### 14. Requirement changes and smallest implementation surface

| Prior expectation or proposal | Recommended decision | Cost |
| --- | --- | --- |
| No independent price source; settled-target counter | Replace issuance valuation with a qualified independent reference. Remove the counter as economic price. | Feed dependency, eligible-pair restriction, stale-price/adverse-selection risk and new deployment arguments. |
| Canonical one-share exit `getRate` | **Preserve.** Correct current implementation to actually simulate that size. | It can fail for insufficient supply/depth/work; it is unsuitable as an unrestricted pricing oracle. |
| Full-supply generic rate adapter | Do not use it as if it forwards the canonical rate. Add an explicitly different NAV adapter only for approved integrations. | Consumer changes and separate integration validation. |
| Approximate half swap with all excess retained | Use 50% as an initial deterministic convenience plan, then value all retained increments and idle amounts. | No exact allocation promise; idle balances are permitted; entrant pays execution/placement costs. |
| Every deposit must open/refresh appropriate wings | Deposit never overwrites live ranges; retain/refund excess when an existing wing cannot accept it. | Some overage waits for maintenance instead of immediately earning fees. |
| Fees compound into wings | Preserve globally shared ownership; collect first, compound under a separate bounded policy. | Temporary idle fees and reference-dependent maintenance. |
| Permissionless swap rebalance | Remove portfolio-funded rebalance swaps from first release. | Less aggressive inventory/core optimization. |
| Target-only withdrawal in every circumstance | Default target route, but add permissionless proportional in-kind redemption. | Dual-output interface/UI; target-only terminal success is not guaranteed. |
| Linear exact-output routes | Unsupported in the preferred first release. | Some buffer/router integrations must change or remain ineligible. |
| Source shares use target decimals | Use 18-decimal shares and explicit scaling. | New share denomination, corrected SY metadata and adapter normalization; no in-place migration assumption. |
| No sink/virtual denominator | Retain no dead-share sink; add strict rounding/seed guards and zero-supply surplus accounting. | Tiny deposits may revert; donation processing is more explicit. |
| Local target sleeve supports nested unlock exits | Remove that solvency promise. Idle target is ordinary pro-rata inventory, not a fixed-price exit facility. | Same-manager automatic buffering is not supported by this first design. |
| Raw target and vault shares treated alike in liquidity | Treat them as distinct assets. | Market price, inventory risk and liquidity discounts are visible rather than hidden. |

The simplest coherent implementation stays within the V4 Wings family:

- Replace `Accounting`'s scalar liquidation-based issue/entitlement assumptions with reference-valued contribution issuance and position/cash slicing.
- Rework `Money` and `ExecutionDelegate` around explicit incumbent, entrant and exit books and separate fee/principal deltas.
- Reuse correct `Inventory` arithmetic and the three-position storage shape, adding only price-reference/precision/maintenance/escrow state actually needed.
- Separate collection and bounded no-swap maintenance from the current `Harvest`/`Rebalance` orchestration.
- Rebuild quote/projection semantics for the actual slice, rather than teaching the old full-book quote to masquerade as every size.
- Align economic/SY/query surfaces and remove unsupported exact-output advertisement.
- Extend package arguments for the immutable reference and risk policy; deploy via the existing registry/factory conventions. Make consumer-adapter changes explicit and separate.

No V3 implementation or retired V4 product is part of this recommendation.

**Decisions genuinely still owned by the owner/deployer:** choose the launch pair/chain and qualified independent reference; approve calibrated deviation, reference-age/uncertainty, entry-exposure and maintenance-budget parameters; choose the immutable zero-supply surplus recipient; accept in-kind exits, exact-output restrictions and initial integration eligibility. These require concrete market information and risk acceptance not present in the brief. The architecture does not leave open whether to substitute spot if those decisions are unresolved: **do not launch the preferred unbalanced-entry product.**

## Alternatives and strongest objection

### Oracle-free strict proportional ownership, with external sizing

This is the strongest alternative, especially for permissionless long-tail pairs.

After collecting old fees, describe the portfolio by the vector:

```text
z = (L_core, L_upper, L_lower, idle0, idle1)
```

For a chosen exact share amount `m` against supply `S`, require:

```text
deltaL[j] >= ceil(m * L[j] / S)
deltaIdle[i] >= ceil(m * idle[i] / S)
```

Mint only after actually adding those liquidity increments at the unchanged ranges and supplying the required cash. Token costs of each liquidity increment are calculated at the actual execution price, with additions rounded up. Include all harvested fees in the required cash vector so they are not gifted to newcomers.

An off-chain solver can choose `m` and the zap swap amount; the contract checks actual costs, balances and ratios in bounded work over three positions. A state change makes the proposed plan fail or reduce the explicitly permitted join; it never authorizes underfunding. Return all unmatched excess, with an explicit small per-coordinate rounding budget and a no-swap immediate in-kind round-trip bound to prevent dust-vector overpayment.

This needs no valuation price because no relative-value exchange is required to decide ownership: every existing asset coordinate grows proportionally. Withdrawal remains the same proportional in-kind primitive plus optional actual-proceeds sale.

**Why it is not my preferred answer to this brief:** the owner wants fully creditable imbalanced additions while retaining arbitrary excess in one portfolio share. Strict proportional issuance cannot both retain arbitrary unpriced excess and give its provider a fair extra fraction of the other components. It must return excess, accept an explicit donation, or price an internal exchange. Nevertheless, it can preserve the user-facing target-only zap and avoid an iterative on-chain solver, so the gas objection alone does not dismiss it.

It is the product I would choose instead if arbitrary pairs without qualified reference feeds are non-negotiable. That is a different tradeoff, not an oracle-free setting of the preferred NAV vault.

### Separate section/range claims

A genuinely separate ERC20/ERC1155/NFT claim can denominate each range's own liquidity and fee balances, accepting its own proportional inputs. That makes a deposit's destination-specific ownership explicit.

It has two materially different forms:

- **Internal section accounts behind one ERC20:** useful attribution, but they do not solve fungible-share pricing. Transfers still transfer a common economic mix. A scalar mint rate still needs either proportionality or valuation.
- **Separate transferable section claims:** different risks and holders. Cross-section fee compounding cannot simply move assets from core holders into a wing owned by different people. The source section must receive destination receipts at a fair exchange rate, retain ownership of the acquired position, or stop cross-section transfers.

A fixed-basket wrapper can restore one fungible token only by accepting/redeeming a fixed proportion of the section claims. That returns to proportional-entry constraints. A dynamically weighted wrapper needs valuation/rebalance pricing. Multiple liquid markets also fragment liquidity and make the user's one-share target quote more complex.

I would use separate claims for a product where investors deliberately choose range exposure, not to conceal an unsolved pricing rule in this common portfolio.

### Invariant-based alternatives

For a **single fixed range**, liquidity units can define proportional ownership without a token price. For several fixed ranges, a fixed vector of those units can likewise define a basket. These are credible, but they lead back to proportional contributions or multiple claims.

I do not recommend `sqrt(totalActualToken0 * totalActualToken1)` for this heterogeneous portfolio. Different ranges change active liquidity and token composition at different boundaries; idle balances and fees add further coordinates. No source read here establishes that aggregate product as a conserved or manipulation-resistant ownership measure.

A custom invariant that deliberately exchanges assets at its own curve could define a new AMM-like portfolio product, but accepting imbalanced deposits then becomes an explicitly priced trade with spread, inventory risk and liquidity rules. It is not a free way to retain arbitrary assets at fair value without a valuation policy. Designing that new invariant is unnecessary for this V4 replacement.

### Strongest counterargument to my preferred design

**The price-reference dependency may be harder and less trustworthy than the proportional zap it replaces.** For many arbitrary tokens there is no sufficiently independent reference. For supported tokens, update latency and confidence bounds can still let informed traders exchange assets with the vault at a stale price. Reference-valued LP equity is not cash and can differ materially from current liquidation proceeds.

That objection is decisive for deployment eligibility. I prefer the NAV design only because it most directly satisfies the brief's combination of one fungible portfolio share and full retained-imbalance credit. I would rather explicitly decline unbalanced issuance for unsupported pairs than call a same-pool reference “independent.”

If the owner instead prioritizes maximal pair coverage and least oracle trust, choose the oracle-free proportional design and accept refunds/external sizing. There is no requirement that makes both tradeoffs disappear.

## Limitations and handoff

- This is an independent architecture recommendation, not a proof, code change, test pass, audit closure, or council consensus.
- All required audit/source targets were read as detailed above. Sources were read from a shared live tree, not an atomic Git snapshot. No current-run peer artifact was read.
- The current source still implements the old liquidation-value machine. The described replacement does not exist merely because its equations are written here.
- A chain/pair-specific price source and calibrated immutable risk parameters remain unresolved deployment prerequisites. No claim is made that an oracle exists for arbitrary token pairs.
- The proposed reference-accounting rounding policy, exact tick overlays, manager integration and consumer eligibility need production-first runtime evidence.
- Target conversion and one-share `getRate` cannot be guaranteed live in every adversarial or illiquid pool state. In-kind redemption protects access to owned assets, not access to an absent buyer or to tokens frozen by their issuer.
- CP and weighted consumer paths were inspected sufficiently to demonstrate the valuation problem; all buffer-hook families and deployment configurations were not exhaustively reviewed.
- Public official flash-accounting documentation was fetched successfully; the provider search/PDF-open attempts supplied no usable evidence.
- This response authorizes no implementation, testing, configuration, deployment, wallet, or Git work. The only authored artifact is this assigned response.
