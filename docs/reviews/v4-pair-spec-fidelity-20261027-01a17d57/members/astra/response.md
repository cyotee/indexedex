# Astra independent fidelity and completeness audit

## Verdict

**No. The supplied report is not an accurate behavior specification of the supplied PairToken source. It is not ready for source-equivalent implementation or for a clean-room handoff represented as source-equivalent.** Its core accounting, fee ownership, initialization, entry, exit, and deployment requirements deliberately describe another product. These are not small omissions that an implementer can resolve through ordinary engineering judgment.

The report itself discloses that substitution: `specification.md:19` says the requested PairToken specification was not admitted and that the report does not translate that source. This is a truthful limitation in the document, not evidence of fidelity. The question in this audit is whether the document nevertheless describes the source; the comparison below establishes that it does not.

The document remains useful as an **independent-design proposal** for a Crane diamond with liquidity-unit issuance and separately claimable fees. That is a different assessment from equivalence. I do not certify even that proposal as a fully determined implementation specification: public interfaces, initialization/genesis, native-asset accounting, executable quotation mechanics, and some fee-ledger boundary behavior still need specification decisions.

The strongest common ground is narrow: one ERC-20 receipt with 18 decimals, one PoolManager position, direct position ownership by the vault address, no position NFT, and immutable position identity after initialization. None of those similarities establishes the same economic claim.

## Evidence, scope, and locator convention

- Independent initial response. No peer responses or coordinator draft were read. No delegation occurred.
- The complete `evidence/specification.md` and all 28 source files in `evidence/sources.md` were read. `evidence/sourcify-sources.json` was parsed to recover original-source line numbers and compare its source contents with the readable bundle; all 28 contents occur in the bundle.
- `R:n` below means line `n` of this run's `evidence/specification.md`, the frozen snapshot of `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md`.
- `P:n` means original-source line `n` of **`src/pair/PairToken.sol`**, not the surrounding Markdown bundle's line number. Other dependencies are cited by original source path and symbol or line.
- Source text, declarations, branches, and formulas below are **source observations**. The consequences, equivalence judgments, severities, and readiness verdict are **inferences from those observations**. Metadata is **supplied evidence**, not a chain-state observation.
- Supplied retrieval: `2026-10-27T12:48:44.213Z`; chain `4663`; address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`; match ID `55980642`; `creationMatch`, `runtimeMatch`, and `match` are `exact_match`; `verifiedAt` is `2026-10-12T10:33:37Z`.
- Supplied source endpoint: `https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources`.
- Manifest hashes: source JSON `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98`; specification `15c6d7790aa1f8eca1c36ec0d147483359e2ff7d018c56ed8240e394d2c878e3`. Hashing the read helper's text reproduces each supplied hash after removal of one trailing presentation newline. This is a text-reader consistency check, not an independent Sourcify fetch or deployed-bytecode check.
- No runtime execution, project tests, builds, installs, Git operations, wallet operations, deployment, or external messages were performed. This response is the only authored artifact.
- Other PRDs, plans, audits, prior council originals, and the report's cited Crane/V2 source files were not supplied as normative targets. Their reported contents are not independently validated here.

Severity is relative to **using this document to produce the source's behavior**, not a vulnerability classification. **Blocker** means a foundational substitution makes equivalence impossible. **High** means a material externally observable behavior would differ or be absent. **Medium** means interface/integration detail or a material qualification is missing.

## Findings

### F01 - Blocker: the document expressly substitutes a different specification target

**Report:** Question `R:6`; Authorization `R:19`; Product `R:42-44`; Evidence/Coverage `R:255-279`; Recommendations `R:297-301`.

**Source:** `src/pair/PairToken.sol:31-40`, and the executable functions cited in F02-F11.

**Observed:** The report asks for IndexedEx's own liquidity-unit Crane vault and prohibits consulting the PairToken source to fill gaps. PairToken instead issues a claim on a live-price two-token basket, compounds fees into the collective property, offers paired and single-leg entry/exit, and describes deployment as an EIP-1167 clone. Its source has no per-holder fee escrow or `getRate`.

**Conflict/type:** Intentional design replacement, explicitly disclosed. Treating the report as a specification of PairToken would turn that replacement into a direct fidelity error.

**Implementation consequence:** A diligent implementation of the report would fail equivalence by design. Filling a few missing functions would not reconcile the ownership/accounting model.

**Smallest specification correction:** Preserve the existing report as an independently proposed design, and explicitly mark it unsuitable as the requested source-equivalent target. A source-equivalent specification needs a separate, source-traceable baseline covering F02-F12; do not silently relabel the present equations and fee rules as PairToken behavior.

### F02 - Blocker: mint math, receipt denomination, and genesis protection are different

**Report:** Terms `R:50-62`; section 1 `R:64-80`; entry `R:135`; invariants 1-3 and 14, `R:234-236,247`.

**Source:** `P:59-66`, `P:221-241` (`basket`, `previewDeposit`), `P:256-302` (`deposit`, `_addAll`), `P:500-529` (`_quoteShares`, `_minShares`); `src/base/PriceMath.sol:29` (`sqrt`); `lib/v4-core/src/libraries/FullMath.sol` (`mulDiv`, `mulDivRoundingUp`).

**Observed:** Report issuance is `floor(uReceived * (S + 10^9) / (U_before + 1))`. PairToken contains no such conversion, virtual liquidity unit, `10^9` offset, or stored `U` ledger. For deposit amounts `a0,a1`, pre-deposit basket `r0,r1`, and supply `S`, its quote is:

| Branch | Quoted gross shares and amounts used |
| --- | --- |
| `S == 0` **or** both reserves zero | `g = floor(sqrt(a0 * a1))`; use both requested amounts. If `S == 0` and `g <= 1000`, revert `BadGenesis`. The multiplication is ordinary checked `uint256` multiplication before `sqrt`. |
| Only `r0 == 0` | `g = floor(a1*S/r1)`; `used0=0`, `used1=a1`. |
| Only `r1 == 0` | `g = floor(a0*S/r0)`; `used0=a0`, `used1=0`. |
| Both reserves nonzero | `g = min(floor(a0*S/r0), floor(a1*S/r1))`; `used_i = min(a_i, ceil(g*r_i/S))`. |

`deposit` calls `_compound()` first, samples the basket and supply, computes this quote, and checks `g != 0 && g >= minShares` **before** pulling tokens and adding liquidity. On first issuance it requires actual `added > 0`, mints `1000` shares to `0x000000000000000000000000000000000000dEaD`, subtracts `1000` from `g`, and mints/returns the remainder to the recipient. Thus the genesis `minShares` check is on the gross quote, not the recipient's final net shares. `previewDeposit` also returns the gross quote. For non-genesis deposits, no explicit `added > 0` condition is applied after quoting.

PairToken's share denomination is 18 decimals, but that fact does not imply the report's offset or conversion. Deposits use underlying raw integer amounts, without underlying-token decimal normalization.

**Conflict/type:** Direct mathematical contradiction arising from an intentional accounting change; missing genesis branches and rounding/ordering.

**Implementation consequence:** Initial supply, depositor shares, relative ownership, behavior with one-sided reserves, and threshold failures differ. The report's `S=0` last-burn lifecycle is also not the normal PairToken lifecycle: its dead-address shares remain in supply unless that address itself acts; the source has no privileged dead-share burn.

**Smallest specification correction:** Replace the liquidity-unit mint rule in any source-equivalent baseline with the complete piecewise basket quote, actual first-deposit dead-share treatment, checked-arithmetic behavior, and gross-versus-net preview/slippage distinction. Keep the report's equation only under an explicit alternative-design label.

### F03 - Blocker: fee ownership is reversed, and automatic compounding is replaced with personal escrow

**Report:** Product `R:44`; Terms `R:54-60`; section 3 `R:90-129`; transfer/claims `R:113-127`; sequences `R:204-228`; invariants 6, 11, 12, 15.

**Source:** `P:162-181` (`transfer`, `transferFrom`, `_transfer`); `P:265,325,358,377` (automatic `_compound` calls); `P:412-465` (`compound`, `_compound`, `_carve`); `P:550-568` (`Collect` branch); `P:610-625` (`_modify`).

**Observed:** PairToken has no `feePerShare`, `debt`, `unclaimed`, `collected`, `liability`, `remainder`, or `claimFees`. It collects into the vault, optionally pays a protocol fraction, and redeploys eligible idle balances. Compound does not mint shares. Net fees therefore benefit the collective basket/position backing shares, not a historical seller's separate claim.

Transfers do not call PoolManager, collect, compound, crystallize, or assign debt. They move the balance and emit `Transfer`. The transferred shares consequently retain their economic exposure to the basket and future collection of position earnings; there is no seller-retained accrued-fee account.

The source's zero-liquidity `Collect` branch returns `_modify(0)`'s **`callerDelta`**, cast per currency to `uint128` then `uint256`, not the separately returned `feesAccrued`. `IPoolManager.modifyLiquidity` explicitly describes caller delta as principal plus fee plus applicable hook deltas. An equivalence specification must not quietly substitute `feesAccrued` for this behavior, particularly for hooks. `_compound` only attempts this collection if position liquidity is positive.

**Conflict/type:** Direct contradiction and intentional redesign, not an omitted implementation detail.

**Implementation consequence:** Fee recipients, transferable property, deposit denominators, exit amounts, costs and external calls during transfers, and existence of a standalone claim API all change.

**Smallest specification correction:** In a source-equivalent baseline, specify collective fee collection, protocol routing and redeployment, and absence of a per-holder fee ledger. State exactly which returned delta is consumed. Do not present the report's escrow and transfer crystallization as a description of PairToken.

### F04 - High: redemption omits 10-basis-point retention, idle property, and the paired exit

**Report:** section 5 `R:143-161`; fixed target Product `R:44`; exit sequence `R:218-228`; invariant 7 `R:240`; last-burn rule `R:249`.

**Source:** `P:59-66`, `P:243-250`, `P:351-407` (`redeem`, `redeemZap`, `_redeemToSelf`), `P:538-544` (`_swapOnly`).

**Observed:** Both redemption routes first compound. Let `s` be shares to burn, `S` the supply before burning, `L` the position liquidity, and `idle_i` the balances sampled before burning:

```text
payout = floor(s * 9990 / 10000)
liqOut = floor(L * payout / S)
amount_i = removalCallerDelta_i + floor(idle_i * payout / S)
```

All `s` shares are burned from `msg.sender`; only `payout` share units participate in payout. `s == 0` or `S == 0` reverts `MinShares`; insufficient holder balance fails checked subtraction. Zero `liqOut` is allowed: the removal is skipped, and any proportional idle proceeds remain payable. Small positive burns can pay zero when minima permit it.

`redeem(s,min0,min1,to)` pays **both** currencies, checks their individual minima, and does not swap. `redeemZap(s,tokenOut,minOut,to)` chooses either pool currency on each call, swaps the unwanted redeemed amount, and pays the selected currency. There is no permanent target currency.

For zap redemption, `_skipAdd` prevents redeployment during the exit swap. The requested swap is exact-input at the global near-extreme sqrt-price limit, but PairToken does not assert that the whole requested input was consumed, impose a tick-movement limit on this route, or require positive output independently of `minOut`. Output is the desired redeemed leg plus the positive output delta returned by the swap. Any unconsumed opposing balance is not separately refunded on this path. The interface documents that swaps may consume unexpected amounts in low liquidity.

**Conflict/type:** Direct mathematical/property contradiction; missing paired exit and retention; stricter report failures than source.

**Implementation consequence:** Recipient assets and amounts differ even in ordinary operation. The report excludes idle fees/donations that the source includes, burns against virtual terms absent from the source, and forces a swap on exits for which PairToken has a two-currency route.

**Smallest specification correction:** Document both source routes, the payout-share haircut before the independent liquidity/idle floors, the actual sender-only burn, per-route minima and output selection, and zero/partial-fill behavior. Treat the report's fixed-target principal-only exit as a new product choice.

### F05 - High: an implemented single-leg deposit and its precise guards are explicitly forbidden

**Report:** section 4 `R:131-141`; sequence `R:208`; Recommendations `R:301`.

**Source:** `P:308-345` (`zapDeposit`), `P:521-529` (`_minShares`), `P:576-608` (`_deployInLock`); factory-view declarations `P:20-25`.

**Observed:** PairToken provides `zapDeposit`. It validates `to` and the input token; validates native value; reserves native input while compounding; then takes a pre-zap basket and supply. It requires nonzero supply and both nonzero reserves (`BadGenesis`). It rejects zero input or:

```text
amountIn > floor(selected pre-zap vault basket reserve * factory.maxZapBps() / 10000)
```

The source comment mentions a pool reserve, but the actual check uses **`r0` or `r1` from this vault's `basket()`**. After a balance-measured pull, the swap input is `floor(actualReceived / 2)`. The same `Deploy` unlock swaps and adds all fitting idle balances at the post-swap price. It then rejects absolute tick movement greater than the runtime `factory.maxZapTickMove()`.

Shares are `min(floor(res.used0*S/r0), floor(res.used1*S/r1))`, against the **pre-zap** basket. `_modify` computes `used_i` as the positive part of `fees_i - callerDelta_i`. They are not the deposited nominal amount or the report's `uReceived`. Both used sides may include pre-existing idle deployment; the source does not track a segregated per-depositor principal sub-balance. There is no zap-specific leftover refund.

**Conflict/type:** Intentional exclusion of a material public entrypoint; absent math, failure cases, and factory dependencies.

**Implementation consequence:** The document forbids a supported source operation and cannot produce its share allocation or guards.

**Smallest specification correction:** Add the actual single-leg route and precise pre/post-state distinction to a source-equivalent baseline. Do not describe external-router swaps as equivalent to this vault's own zap, and do not replace the runtime cap with an assumed constant.

### F06 - High: native reservations, ERC-20 pulls, donation ownership, and leftovers are unspecified or contradicted

**Report:** share property `R:86`; entry/refunds `R:135`; exit exclusions `R:153`; invariant 5 `R:238`.

**Source:** `P:133`, `P:221-230`, `P:256-302`, `P:334-345`, `P:646-691` (`_idle`, `_checkNative`, `_pull`, `_refundNative`, token-call helpers).

**Observed:**

- Native currency is represented by address zero. Paired deposit requires exactly `msg.value == amount0` when currency0 is native; otherwise it requires `msg.value == 0`. Native zap input similarly requires `msg.value == amountIn`; other zap inputs reject value.
- `_reservedNative` excludes newly arrived native input from the initial compound/basket calculation. After a paired pull it retains only the refund reservation; `_refundNative` clears it and sends that refund to **`msg.sender`**, not `to`, failing with `TransferFailed` if the send fails.
- Paired ERC-20 deposit pulls only the calculated used amounts. Unselected requested excess is not first transferred in and then refunded. Amounts that are pulled but do not fit the final add remain idle.
- `_pull` measures received ERC-20 balance differences. However, ordinary `deposit` computes/checks shares **before** those measured pulls and does not recompute them afterward. Balance measurement must not be paraphrased as a guarantee that paired shares are priced on actual receipt. Zap uses actual received input to size its half-swap.
- `_idle` is the actual currency balance, minus the reservation only for native currency. No separate donation ledger excludes unsolicited transfers. Such balances are included in `basket`, redemption's idle allocation, and eligible compounding. `receive()` accepts native value without restriction.

**Conflict/type:** Missing native/token mechanics, and direct contradiction of the exclusion of donations and of universal refunds for amounts not becoming liquidity.

**Implementation consequence:** Share quotes, refunds, later compounding, ownership of leftover funds, and behavior with nonstandard tokens will differ. The source's balance measurement is an observation, not evidence of complete fee-on-transfer support or safety.

**Smallest specification correction:** Specify the actual reservation/pull/refund sequence and the all-idle-balance property model. Document nominal quote versus measured receipt as it executes. Any prohibition on nonstandard tokens or exclusion of donations is an additional design policy, not a check present in this source.

### F07 - High: initialization, full-range identity, and deployment are replaced

**Report:** Product `R:42`; section 2 `R:84`; section 6 `R:163-175`; invariant 4 `R:237`.

**Source:** `P:31-40`, `P:68-85`, `P:138-152`, `P:214-218`, `P:610-618`; `lib/v4-core/src/libraries/TickMath.sol:39-49`; `lib/v4-core/src/types/PoolId.sol` (`toId`); `lib/v4-core/src/libraries/Position.sol:48` (`calculatePositionKey`).

**Observed:** Initialization accepts a manager, full `PoolKey`, name, and symbol. It rejects repeated initialization and a zero manager; sets `factory = msg.sender`; stores the key and its hash; and computes:

```text
tickLower = truncTowardZero(-887272 / tickSpacing) * tickSpacing
tickUpper = truncTowardZero( 887272 / tickSpacing) * tickSpacing
salt = bytes32(0)
```

There is no supplied arbitrary range, salt, or target currency. The position key uses `address(this)`, those ticks, and zero salt. The instance exposes no setter for these fields.

`initialize` does **not** authenticate a preconfigured factory. `NotFactory` is declared but unused. The first successful caller becomes the stored factory. There is no constructor in this source that locks implementation initialization, no explicit initialized modifier on the operating functions, and no call to initialize the underlying pool. The initializer itself does not validate currency ordering, a hook policy, or the permitted tick-spacing interval; some invalid inputs fail arithmetic or later dependencies.

The EIP-1167 deployment is described in the source comment. The factory implementation and actual clone bytecode/transaction are not supplied, so deployment mechanics cannot be independently confirmed beyond that comment and the executable initializer. The report's Crane diamond, facet repo, DFPkg, registry, and rejection of clones are not behaviors of this contract.

**Conflict/type:** Direct architecture/parameter contradiction plus missing initialization permissions and validation boundaries.

**Implementation consequence:** Address ownership may retain the same abstract direct-owner property, but initialization ABI, deployer trust, position range/salt, and storage/deployment shape do not match.

**Smallest specification correction:** Separate externally observed initializer/position behavior from unverified factory deployment details. Specify full usable range and zero salt exactly. Mark any Crane port as an architectural adaptation, not source equivalence.

### F08 - High: callback authorization and operation ordering are stronger and structurally different in the report

**Report:** collection `R:94`; callback rule `R:171`; both one-callback sequences `R:204-228`; invariant 10 `R:243`.

**Source:** `P:80-85`, `P:120-130`, `P:256-345`, `P:351-465`, `P:533-644` (`_unlock`, `unlockCallback`, `_deployInLock`, `_modify`, `_resolve`); `lib/v4-core/src/interfaces/IPoolManager.sol:113,142,163,189-201`.

**Observed:** `deposit`, `zapDeposit`, `redeem`, `redeemZap`, and `compound` use `_entered` as a non-reentrancy guard. ERC-20 functions, initializer, receiver, views, and `unlockCallback` do not use that modifier. The callback checks **only** that its sender equals the configured PoolManager, then decodes `(Op,bytes)`. There is no independently armed single-use request, caller/receiver binding, or stored budget check. `_skipAdd` controls redeployment for an exit swap; it is not callback authentication.

Operations are `None=0`, `Add=1`, `Remove=2`, `Collect=3`, `Deploy=4`. Add and Remove decode a liquidity amount; Deploy decodes direction and swap amount. A decoded `None` reaches `NotPoolManager` even from the manager; malformed encoding or an invalid enum fails decoding.

One user action can cause several separate unlocks: compound may collect, then deploy; deposit subsequently adds; redemption subsequently removes and optionally swaps. Pulls, minting, and burning are not all performed inside one encompassing callback as the report requires.

Each `_modify` settles/takes both currencies from its returned caller delta. Negative ERC-20 deltas use `sync`, token transfer to manager, then `settle`; negative native deltas use payable `settle`; positive deltas use `take` to the vault. Deploy similarly resolves the swap deltas before adding. Hook data is empty. Swaps use negative `amountSpecified` and price limits `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`, not user-selected swap limits.

**Conflict/type:** Intentional strengthened callback design and different transactional sequence; missing exact operation/settlement behavior.

**Implementation consequence:** Trust boundaries, callback admission, externally visible call order, and when hooks or token calls execute differ. Static comparison does not establish that either design is runtime-safe.

**Smallest specification correction:** State the actual guard scope, callback sender-only authorization, operation encoding, separate unlock boundaries, and settlement ordering. Record an armed-callback design as an added hardening requirement rather than an existing source fact.

### F09 - High: runtime protocol routing and idle-ratio compounding are absent

**Report:** section 3 `R:92-129`, especially rejection of a protocol take at `R:129`; rejection of compounding `R:78`; no-swap entry `R:133`.

**Source:** `P:20-28`, `P:412-498` (`_compound`, `_carve`, `_ratioSwap`); `P:576-608` (`_deployInLock`).

**Observed:** When collection returns positive amounts, `_compound` reads `factory.feeManager()` and `factory.protocolFeeBps()`. If manager and rate are nonzero, each attempted take is `floor(fees_i * feeBps / 10000)`. These are runtime values, not fixed values supplied by the source bundle.

Native routing calls payable `notify(token,amount,poolId)`. A caught notification revert returns zero protocol payment and leaves funds in the vault. ERC-20 routing first tries approving the manager for the amount, calls `notify`, and on a caught notification revert tries to clear approval and returns zero. A successful notification is reported as payment without a post-notification balance measurement or unconditional approval reset. The source does not supply the notification implementation. Factory getter failures are not caught; malformed nonempty approval return data can fail ABI decoding. Thus the comment's "best effort" must not be expanded to immunity from every external failure.

If either idle currency is **strictly greater than `1000`**, compounding may ratio-swap and redeploy. It computes liquidity fitting both idle sides, estimates required amounts with upward rounding, subtracts to form nonnegative leftovers, and values token0 leftovers in token1 units by two sequential floors:

```text
left0In1 = floor(floor(left0 * sqrtP / 2^96) * sqrtP / 2^96)
```

If `left0In1 >= left1`, choose token0; otherwise token1. If the chosen leftover is at most `1000`, swap zero; otherwise the proposed swap is half that leftover, floored. If active pool liquidity is zero, swap zero. Otherwise cap it at:

```text
floor(floor(active-pool-liquidity-implied input reserve * maxZapBps / 10000) / 4)
```

This compounding cap uses `poolManager.getLiquidity(poolId)` and full-range amount math, unlike the zap-deposit cap that uses the vault basket. `_compound` does not apply `maxZapTickMove`. Clipping the proposed amount is not a guarantee that downstream execution cannot revert. Deployment then adds all idle balances that fit at the resulting price. This can run inside an ordinary paired deposit or redemption even though those entrypoints are not named "zap."

**Conflict/type:** Omitted material behavior and direct rejection of source compounding/protocol routing.

**Implementation consequence:** Ongoing position growth, protocol economics, externally callable factory dependencies, donation deployment, price movement during regular actions, and failure propagation differ.

**Smallest specification correction:** Add the exact trigger, ratio/cap math, runtime factory reads, notification semantics and failure qualifications. Do not invent live factory settings, ownership controls, or fee-manager token-pull behavior; those require additional evidence.

### F10 - High: the report invents a rate API while failing to specify the source's previews

**Report:** section 7 `R:177-200`; invariant 9 `R:242`; Terms `R:62`.

**Source:** `P:201-250` (`poolKey`, `token0`, `token1`, `positionLiquidity`, `basket`, `previewDeposit`, `previewRedeem`); `P:500-519`; `lib/v4-core/src/libraries/SqrtPriceMath.sol:188,234`.

**Observed:** PairToken has no `getRate`, `redeemTarget`, rate-provider normalization, or one-whole-share domain restriction. `basket()` reads the current sqrt price, position liquidity, and actual idle balances. With `A0`/`A1` denoting the library's amount-delta functions:

```text
r0 = A0(sqrtP, sqrtUpper, L, roundDown) + idle0
r1 = A1(sqrtLower, sqrtP, L, roundDown) + idle1
```

When `L==0` it skips these principal calculations. The source passes the live price directly; it does not explicitly clamp it to the range before those calls. The library sorts endpoints and applies integer math. A fidelity specification must record the executed behavior rather than silently substitute an idealized range valuation.

`previewDeposit` invokes the piecewise quote in F02 without compounding; its notice explicitly excludes pending fees. `previewRedeem(s)` returns `(0,0)` if supply or requested shares is zero; otherwise it returns each basket reserve times `floor(s*9990/10000) / S`, floored. It does not check ownership or reject `s > S`. Neither view performs the automatic compounding that execution performs. Preview redemption also rounds proportional total basket amounts rather than separately flooring removed liquidity and idle claims, so exact execution equality is not promised.

**Conflict/type:** New independent feature and missing source view semantics.

**Implementation consequence:** An integration using the documented methods cannot call the source as described; quotations and revert domains differ. The target-token rate is neither evidence of source valuation nor a substitute for its two-token previews.

**Smallest specification correction:** Specify the actual two-token views, rounding, pending-fee exclusion, and execution differences. Label `getRate` as an additional proposed API, not a documented PairToken method.

### F11 - Medium: ERC-20 permissions, events, and observable failures are not sufficiently specified

**Report:** Product `R:42`; section 3 transfer prose `R:123`; sequences `R:202-228`; otherwise absent.

**Source:** `P:47-55`, `P:102-130`, `P:156-198`, events at `P:116-118`, emissions at `P:291,345,363,388,442`, token helpers `P:678-691`; `lib/v4-core/src/types/Currency.sol` (`transfer`).

**Observed:** Approval directly replaces the allowance and emits `Approval`; there is no zero-spender restriction. Transfers reject a zero recipient, use checked sender-balance subtraction, and emit `Transfer`. `transferFrom` subtracts finite allowance, leaves `uint256.max` allowance unchanged, and emits no separate `Approval` on allowance consumption. It requires allowance even when called by `from`. Ordinary transfers do not synchronize fees.

Deposits and redemptions reject a zero recipient. Redemption burns only the caller's balance, not an arbitrary owner's approved balance. `Deposit` reports actual pulled used amounts for paired entry and deployment used amounts for zap entry. Genesis reports net recipient shares. `Redeem` on the zap route reports the **pre-swap pair amounts**, not just the final selected-token payout. `Compounded` reports collected amounts, reported protocol payments, and added liquidity, and emits only when collection or addition is positive.

Important observable failures include `AlreadyInitialized`, `ZeroAddress`, `NotPoolManager`, `Reentrancy`, `BadGenesis`, `MinShares`, `MinOut`, `BadToken`, `NativeMismatch`, `ZapTooLarge`, `ZapMovesPrice`, and `TransferFailed`. `NotFactory` is declared but unused. Checked arithmetic failures and underlying external errors remain possible; failed outbound `Currency.transfer` uses the dependency's wrapped transfer errors rather than invariably using PairToken's `TransferFailed`.

**Conflict/type:** Missing ABI/event/error contract; direct conflict in transfer side effects.

**Implementation consequence:** Indexers, allowances, delegated transfer callers, transaction minima, refund recipients, and error handling would not have deterministic source-equivalent requirements.

**Smallest specification correction:** Add the full ABI/getter/event/error inventory and exact caller/recipient rules. Do not rely on the words "ERC-20" or "revert" to specify nonstandard side effects and operation-specific event payloads.

### F12 - Medium: dependency evidence and clean-room provenance cannot support the claimed handoff

**Report:** Authorization `R:19`; Evidence `R:255-268`; Coverage `R:270-279`; Limitations `R:303-309`.

**Source/evidence:** `P:20-28` factory/notification interfaces; `P:138-152`; `P:416-498`; `evidence/manifest.md`; the source bundle's `IPoolManager` and `IHooks` interfaces.

**Observed:** The bundle includes the PairToken implementation, libraries, and external interfaces, but not the factory implementation, fee-manager implementation, concrete PoolManager implementation, actual hook contract, underlying token implementations, live parameter settings, or deployment transaction. The old report instead cites V2/Crane math and openly says PairToken was not examined.

This reviewer has now read the public source, and this audit is source-informed. The evidence directory itself contains that source. Neither is an unexposed implementer's clean-room input merely because it is stored under an audit path. SPDX headers, a Sourcify exact-match status, and a faithful behavioral document do not themselves establish legal clearance. Conversely, source exposure does not by itself establish a blanket prohibition on factual comparison.

**Conflict/type:** Evidence/provenance gap, separate from the mathematical contradictions.

**Implementation consequence:** The current record cannot establish complete deployed-system behavior or an unexposed implementation process. It cannot substantiate a production-use grant or a legal conclusion either way.

**Smallest specification correction:** State exactly which behavioral dependencies remain assumptions, preserve source-exposure/provenance records, and separate any later implementer-facing approved specification from raw source and this source-informed audit. Any legal clearance determination needs its own authorized basis; this static audit makes none.

## Exact math and ordering qualifications

These qualifications are part of the comparison, not a recommendation to implement the source.

### Price and liquidity math actually used

`lib/v4-core/src/libraries/SqrtPriceMath.sol:getAmount0Delta` sorts endpoints `a <= b`, rejects `a==0`, and for downward rounding computes:

```text
floor(floor((L * 2^96) * (b-a) / b) / a)
```

Its upward branch uses upward full-precision division and then upward division by `a`. `getAmount1Delta` computes `floor(L*abs(b-a)/2^96)` and adds one on a nonzero remainder when upward rounding is requested.

`src/vendor/uniswap/LiquidityAmounts.sol` computes:

```text
L0(a,b,x) = floor(x * floor(a*b/2^96) / (b-a))
L1(a,b,y) = floor(y * 2^96 / (b-a))
```

It orders bounds and uses only `L0` below/equal to the lower bound, the minimum of `L0(p,b,x)` and `L1(a,p,y)` inside, and only `L1` at/above the upper bound. Conversion to `uint128` is checked. Therefore, "liquidity units received" cannot be substituted for the basket-denominated shares simply because both routes eventually invoke liquidity math.

`FullMath.mulDiv` floors with full-precision intermediate multiplication and rejects zero denominator/overflow; `mulDivRoundingUp` adds one for a remainder and also checks overflow. By contrast, such expressions as `amount0 * amount1`, `shares * 9990`, and `fees * feeBps` in PairToken use Solidity checked arithmetic before division. An exact observable specification must preserve those distinctions.

Tick constants are `MIN_TICK=-887272`, `MAX_TICK=887272`, `MIN_SQRT_PRICE=4295128739`, and `MAX_SQRT_PRICE=1461446703485210103287273052203988822378723970342`. `getSqrtPriceAtTick` rounds up in its final Q128-to-Q96 conversion. The source's swap price limits are one unit inside the sqrt extrema, not its usable tick-boundary prices.

### Source operation order, condensed

| Route | Observed sequence |
| --- | --- |
| Paired deposit | Guard; recipient/native checks; reserve native input; compound; snapshot basket/supply; quote/check gross shares; pull selected amounts; update native refund reservation; add all fitting idle; genesis check/dead mint if applicable; mint recipient; refund native sender; emit. |
| Zap deposit | Guard; recipient/token/native checks; reserve native input; compound; snapshot basket/supply; genesis/cap checks; measured pull; clear reservation; swap half and add in Deploy unlock; check tick move; quote shares from used amounts against pre-zap basket; check/mint; emit. |
| Paired redemption | Guard; recipient check; compound; require positive shares/supply; snapshot idle; burn caller shares; compute retention-adjusted payout and position slice; remove if positive; add proportional idle; check both minima; transfer both positive amounts; emit. |
| Zap redemption | Guard; recipient/output-token checks; compound and shared burn/removal/idle allocation; swap opposing amount under `_skipAdd`; compute selected-token total; check minimum; transfer; emit pair amounts. |
| Compound | Guard at public entry; collect if position liquidity positive; runtime factory reads and optional protocol routing; if either idle exceeds dust, ratio-size/clamp swap and deploy; conditionally emit; return collected pair amounts. |
| Share transfer | Allowance adjustment for `transferFrom` when finite; zero-recipient check; balance update; `Transfer`. No fee or pool operation. |

There is no basis to rewrite these into a single armed callback without acknowledging a behavior/architecture change.

## Complete report-section coverage

All sections below were **examined**. "Contradiction" describes fidelity to PairToken, not an accusation that the report hid its redesign. Administrative statements about its earlier council are read as supplied assertions, not independently corroborated history.

| Snapshot section and lines | Fidelity/completeness assessment |
| --- | --- |
| Title / Question, `R:1-9` | States a different research target. F01. |
| Authorization and scope, `R:11-19` | Explicitly excludes source reconstruction; establishes why this cannot be accepted as the requested equivalent spec. F01/F12. |
| Participation, `R:21-34` | Administrative provenance; not source behavior. Participant identities and prior task outcomes not independently checked. |
| Conclusions introduction, `R:36-38` | Describes implementation target and review limitations, not evidence of source fidelity. |
| Product, `R:40-44` | One fungible/directly owned position partly aligns. Diamond, separate escrow, and fixed-target exit contradict source. F03/F04/F07. |
| Terms, `R:46-62` | 18 decimals aligns. Stored `U`, offset, account indexes and remainder model are absent from source. F02/F03. |
| 1. Receipt and mint, `R:64-80` | Fundamentally different formula and explicit rejection of compounding/basket approaches. F02/F03. |
| 2. One share, one range, `R:82-88` | Single immutable position partly aligns; configurable range/salt/target and exclusion of fees/donations do not. F06/F07. |
| 3. Fees, `R:90-129` | Replaces collective compound/protocol routing with personal fee escrow and altered transfer rights. F03/F09/F11. |
| 4. Entry, `R:131-141` | Paired input shape partly aligns; liquidity-unit pricing, no swaps, refunds, and omitted zap conflict. F02/F05/F06/F09. |
| 5. Share exit, `R:143-161` | Different burn conversion, property, output choice, zero/partial-fill rules, and last-burn model. F04. |
| 6. Diamond boundary, `R:163-175` | Direct ownership and manager callback partly align; diamond deployment and armed single-use guard are additions. F07/F08. |
| 7. getRate, `R:177-200` | New proposed API, not source behavior. Omits actual preview semantics. F10. |
| 8. Sequences, `R:202-228` | Pre-entry/exit handling of existing earnings is broadly related, but operation ordering and one-callback implementation differ materially. F02/F03/F08. |
| 9. Invariants, `R:230-249` | Detailed classification below. Most are requirements for the alternate design, not source invariants. |
| What this does not deliver, `R:251-253` | Correctly disclaims several proposed-design properties; does not repair equivalence. The entry-swap exclusion conflicts with source. |
| Evidence, `R:255-268` | Cites different implementations/reports and labels PairToken not examined. Those citations do not establish PairToken equations. F01/F12. |
| Coverage, `R:270-279` | Earlier coverage expressly excludes the target now being audited; no source-equivalent completeness claim follows. F12. |
| Disagreement and missing responses, `R:281-286` | Documents earlier alternative choices; selecting one does not select the source's behavior. Prior responses not read in this independent pass. |
| Advisory review, `R:288-295` | Administrative review record; not runtime/source-fidelity evidence. Member approval of final wording expressly disclaimed. |
| Recommendations, `R:297-301` | Implementation authorization caveat is procedural. Test list concerns alternative accounting; explicit no-zap instruction conflicts with source. F05. |
| Limitations, `R:303-309` | Static/unrun qualifications are useful but omit an affirmative source-equivalence rejection. F01/F12. |
| Publication, `R:311-319` | Administrative publication status; does not establish implementability, provenance isolation, or legal clearance. |

### Section 9 invariant-by-invariant comparison

| Item | Result against supplied source |
| --- | --- |
| 1 | Contradicted: basket/geometric-mean issuance, not the virtual-offset formula. |
| 2 | Contradicted: basket denominators expressly include live-price principal and idle balances. |
| 3 | Not a source property in these terms: source issuance is not parameterized by booked `U` and `uReceived`. |
| 4 | Partial: pool and computed ticks remain fixed and salt is constant zero; there is no target field. |
| 5 | Contradicted/absent: no booked `U` or fee-per-share index; compounding grows position liquidity; donated balances enter the basket. |
| 6 | Different ownership model: no `unclaimed` or remainder, and new issuance is against the post-compound basket. |
| 7 | Contradicted: zap exit includes proportional idle and compounded property, not only removed principal. |
| 8 | Qualified agreement: a reverting swap rolls back the transaction; the source does not independently treat every incomplete fill as failure. |
| 9 | Absent: no `getRate`. |
| 10 | Partial: manager-only callback and direct vault ownership align; diamond, armed flag, and direct-facet restriction are not source features. Manager implementation itself is not supplied. |
| 11 | Contradicted: transfers do not crystallize or retain personal earnings. |
| 12 | Absent/contradicted: no `claimFees` or separate escrow rights. |
| 13 | Not this source interface/model: no `redeemLiquidity(mintShares(u))` conversion. No general round-trip theorem was tested here. |
| 14 | Not established by the source or this static audit; source has different mint inputs, dead shares, donations, and compounding. |
| 15 | Absent: no liability/remainder ledger. |
| 16 | Different lifecycle: no virtual-offset residual accounting, and genesis dead shares remain in supply under ordinary holder redemptions. |

## PairToken public-entrypoint coverage

Every entry below is **examined**. This includes all 17 named public/external functions declared by PairToken, its payable receiver, and all 17 public-variable/constant getters. The factory and fee-manager interface functions are dependencies, not PairToken entrypoints.

| Entrypoint / original source locator | Observed behavior and report coverage |
| --- | --- |
| `initialize(manager,key,name,symbol)`, `P:138` | One-shot first-caller factory assignment, full usable ticks, key hash. Contradicted/underspecified by R section 2/6; F07. |
| `approve(spender,amount)`, `P:156` | Replace allowance, emit, return true. Exact semantics missing; F11. |
| `transfer(to,amount)`, `P:162` | Balance transfer only, zero recipient rejected. Report instead requires fee sync/crystallization; F03/F11. |
| `transferFrom(from,to,amount)`, `P:167` | Finite allowance consumption or max sentinel, then transfer. Missing allowance specifics and conflicting fee behavior; F11. |
| `poolKey()`, `P:201` | Returns stored full key. Broad pool concept covered, exact getter absent; F07. |
| `token0()`, `P:205` | Unwrap first currency address; zero means native. Getter/native semantics missing; F06. |
| `token1()`, `P:209` | Unwrap second currency address. Getter/native semantics missing; F06. |
| `positionLiquidity()`, `P:214` | Reads manager storage at owner=this/ticks/zero-salt key. Report substitutes booked `U` plus equality checks; F07/F10. |
| `basket()`, `P:221` | Live-price position principal plus all idle, without pending fees. Deliberately rejected/absent; F02/F06/F10. |
| `previewDeposit(a0,a1)`, `P:233` | Piecewise basket quote, gross genesis shares, no compound. Missing; F02/F10. |
| `previewRedeem(shares)`, `P:243` | Two-token basket fraction net of retention; zero handling; no ownership check. Missing; F04/F10. |
| `deposit(a0,a1,minShares,to)`, `P:256` | Payable guarded paired deposit, compound before quote/pulls, native refund, dead-share genesis. Partial route shape but changed semantics; F02/F06/F08. |
| `zapDeposit(tokenIn,amountIn,minShares,to)`, `P:308` | Guarded payable single-leg route with runtime cap/tick checks and half-swap. Expressly forbidden; F05. |
| `redeem(shares,min0,min1,to)`, `P:351` | Guarded sender burn and two-token payout. Missing paired output/minima; F04. |
| `redeemZap(shares,tokenOut,minOut,to)`, `P:366` | Guarded sender burn and selectable single-leg payout. Superficially resembles report exit but property, retention, selection and fill behavior differ; F04. |
| `compound()`, `P:412` | Permissionless guarded fee/protocol/ratio-swap/redeploy operation. Replaced, not specified; F03/F09. |
| `unlockCallback(bytes)`, `P:550` | Configured-manager-only operation dispatch; no armed flag. Partial/contradicted; F08. |
| `receive()`, `P:133` | Unrestricted payable empty receiver. Missing, economically material through idle balance; F06. |
| `name()`, `P:47` | Initialized metadata string. Exact initialization/getter omitted. |
| `symbol()`, `P:48` | Initialized metadata string. Exact initialization/getter omitted. |
| `decimals()`, `P:49` | Constant 18. Matches R:62. |
| `totalSupply()`, `P:50` | ERC-20 supply including dead shares. Report's `S` concept exists but genesis/ownership differs; F02. |
| `balanceOf(account)`, `P:51` | ERC-20 mapping. General concept covered; associated fee rights differ; F03. |
| `allowance(owner,spender)`, `P:52` | ERC-20 mapping. Exact behavior omitted; F11. |
| `BPS()`, `P:59` | Constant 10000. Source fee/retention basis omitted; F04/F09. |
| `DEAD_SHARES()`, `P:61` | Constant 1000. Omitted; F02. |
| `RETENTION_BPS()`, `P:63` | Constant 10. Omitted; F04. |
| `DUST()`, `P:65` | Constant 1000 raw units. Omitted; F09. |
| `DEAD()`, `P:66` | Constant dead address. Omitted; F02. |
| `factory()`, `P:68` | First initializer caller; runtime dependency. Replaced with registry narrative; F07/F09. |
| `poolManager()`, `P:69` | Stored manager set at initialization. General concept covered, initializer/guard specifics differ; F07/F08. |
| `poolId()`, `P:71` | Hash of stored key. Exact getter/hash omitted; F07. |
| `tickLower()`, `P:72` | Computed minimum usable tick. Report instead leaves configured range; F07. |
| `tickUpper()`, `P:73` | Computed maximum usable tick. Report instead leaves configured range; F07. |
| `initialized()`, `P:74` | One-shot initializer flag. Initialization state/permission behavior omitted; F07. |

No `permit`, delegated-owner redemption, governance setter, rescue/sweep function, range rebalance, per-holder fee claim, or `getRate` is implemented in the examined PairToken source. This is an inventory observation, not a claim about unsupplied wrappers or factory contracts.

## Dependency coverage and limits

All 28 supplied files were read in full. "Examined" means inspected for this fidelity comparison, not independently proved correct. Grouping below does not leave any supplied file unaccounted for.

| Source path(s) | Status and relevance |
| --- | --- |
| `src/pair/PairToken.sol` | Examined completely: contract, embedded factory/fee-manager interfaces, all public and internal paths. |
| `src/vendor/uniswap/LiquidityAmounts.sol` | Examined: token-to-liquidity piecewise conversion, floor behavior, checked uint128 cast. |
| `src/base/PriceMath.sol` | Examined: genesis `sqrt`; `sqrtPriceFor` also read, but not called by PairToken. |
| `lib/v4-core/src/interfaces/IPoolManager.sol` | Examined: unlock/modify/swap/settlement interface, hook-inclusive delta contract, partial-fill warning. Concrete manager execution not supplied. |
| `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` | Examined: unlock caller/callback interface. |
| `lib/v4-core/src/types/PoolKey.sol`, `PoolId.sol` | Examined: key fields and key hash. |
| `lib/v4-core/src/types/Currency.sol` | Examined: native representation, balance reads, transfer behavior and wrapped errors. |
| `lib/v4-core/src/types/BalanceDelta.sol` | Examined: signed int128 components and extraction. |
| `lib/v4-core/src/libraries/TickMath.sol` | Examined: full usable bounds, constants, tick/sqrt math and errors. No numerical runtime validation. |
| `lib/v4-core/src/libraries/StateLibrary.sol` | Examined: storage access assumptions; direct uses are slot0, active liquidity, and position liquidity. Other accessors were read, not treated as additional PairToken behavior. |
| `lib/v4-core/src/libraries/Position.sol` | Examined: owner/range/salt key, underlying position fee-growth mechanism, empty-position poke restriction. Not a PairToken account fee-index implementation. |
| `lib/v4-core/src/libraries/SqrtPriceMath.sol`, `FullMath.sol` | Examined: amount delta rounding, arithmetic/error behavior. No proof or testing of the library algorithms. |
| `lib/v4-core/src/interfaces/IHooks.sol` | Examined: possible modify/swap hook delta and fee-override interfaces. Actual configured hook not supplied. |
| `lib/v4-core/src/interfaces/external/IERC6909Claims.sol` | Examined: inherited manager claim interface; PairToken does not use claim mint/burn in its settlement path. |
| `lib/v4-core/src/interfaces/IProtocolFees.sol` | Examined: manager's protocol-fee interface; distinct from PairToken's factory-directed protocol carve. No manager controller implementation supplied. |
| `lib/v4-core/src/interfaces/IExtsload.sol`, `IExttload.sol` | Examined: storage interfaces; StateLibrary uses external persistent storage reads. |
| `lib/v4-core/src/interfaces/external/IERC20Minimal.sol` | Examined: balance/transfer/approval interface, not underlying token implementations. |
| `lib/v4-core/src/libraries/CustomRevert.sol`, `SafeCast.sol` | Examined: transfer error wrapping and checked casts. |
| `lib/v4-core/src/libraries/BitMath.sol`, `FixedPoint128.sol`, `LiquidityMath.sol`, `UnsafeMath.sol`, `FixedPoint96.sol` | Examined: supporting arithmetic/constants; no separate mathematical proof or execution. |
| `lib/v4-core/src/types/BeforeSwapDelta.sol` | Examined: hook-delta encoding dependency; actual hook behavior not supplied. |
| PairTokenFactory concrete implementation/deployment, fee-manager implementation, concrete PoolManager/Pool swap engine, actual hook, underlying tokens, live factory values | **Not examined: not supplied.** Embedded/external interfaces are only partial system coverage and cannot prove these implementations or live settings. |
| Earlier report's Crane/V2 implementations, cited prior research, original council responses, feedback | **Not examined: not normative targets for this pass.** The snapshot's assertions about them were read, not independently revalidated. No peer-original consultation occurred. |

## Independent-design usability versus source-equivalent implementability

| Question | Assessment |
| --- | --- |
| Does the report specify this source's observable economic behavior? | **No.** F02-F10 cover fundamental contradictions, not merely missing edge cases. |
| Could a developer implement some coherent vault from the report? | **Yes, as a different design**, with additional decisions. The liquidity receipt, detached fee claims, and target-only exit are intentional choices. |
| Is that alternative already fully determined by the report? | **Not established.** It lacks a complete ABI/error/event contract, initialization and first-entry specification, detailed native refund/reservation rules, a concrete supported-hook/quote boundary, and precise treatment of several fee-ledger execution cases. |
| Does source agreement prove runtime correctness? | **No.** No tests, runtime traces, deployed-state reads, or theorem proofs were performed. There is substantial disagreement anyway. |
| Does the original report's source-exclusion statement establish a clean room? | **No such conclusion follows.** It is an assertion about that earlier author's scope. This reviewer is now source-exposed, and this audit is source-informed. |
| Does public verified source or this audit establish legal clearance? | **No determination made.** Metadata and SPDX text are observations, not a production-use grant or a legal conclusion. |

The independent-design gaps should not be repaired by quietly importing PairToken behavior: some of it is precisely what the report rejected. Nor should this audit's reproduction of source behavior be treated as authorization to implement it.

## Outstanding blockers and final readiness decision

1. **Target identity:** The implementer-facing artifact must unambiguously choose source equivalence or the alternate IndexedEx product. The present report expressly chooses the latter.
2. **Economic contract:** An equivalent baseline must specify the basket claim, piecewise mint/genesis, dead shares, collective compounding, runtime protocol take, donation/idle ownership, and retention-adjusted dual exit routes. The current report contradicts all of these.
3. **Observable completeness:** Source public methods, getters, errors, events, minima, rounding, native/token transfers, callbacks, and operation ordering need complete coverage in the baseline. A method name or abstract invariant is insufficient.
4. **Dependency boundary:** Factory deployment, runtime fee/cap values, manager/hook behavior, and token behavior remain unverified beyond the supplied interfaces. An equivalent specification must state assumptions or obtain separately authorized evidence, rather than invent values or guarantees.
5. **Handoff provenance:** Any future claim of an unexposed implementation process must distinguish this source-informed analysis and raw source bundle from the intended implementer-facing material. Document accuracy alone neither establishes that process nor settles legal clearance.

**Final verdict: NOT READY as a source-equivalent specification or source-equivalent clean-room handoff.** Useful as a separately labeled alternative-design proposal; not a substitute for the requested PairToken behavior specification. The findings are high-confidence static document/source comparisons, with the concrete-dependency and legal/provenance limitations above.
