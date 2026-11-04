Ask: Recommend the best V4 fee-vault foundation for ERC20 rate-aware pool shares and atomic single-token entry/exit - wanted: a concrete ranked original, not implementation. For you: I recommend lpTOKEN’s accounting and strict zap semantics on the existing local full-range model, with Weir as strategy runner-up. `apply_patch` remains inactive, so `/members/kimi/response.md` was not written; the complete original follows inline without using another write mechanism. Now: none - all tasks closed. Next: none.

# Kimi recommendation: adaptation base for a hook-composable V4 fee vault

## Recommendation

**Adapt lpTOKEN's two-currency ownership and strict zap semantics into the existing local full-range stage-one model; do not adopt WeirVaults wholesale merely by adding ERC-20.** My ranking is:

1. **lpTOKEN — best external accounting/periphery reference and best overall external base.** Its proportional two-currency portfolio claim and full-spend-or-revert zap are the closest matches to the required economics. Use the existing local stage-one full-range strategy and packaging rather than importing lpTOKEN's launch-specific range, launch-fee NAV, share fees, or dead shares.
2. **WeirVaults — best simple strategy reference and runner-up.** Its direct-PoolManager full-range position is the right strategy shape, but its internal share ledger, liquidity-ratio issuance, residual-token withdrawal, locked shares, fee policy, and nested unlock make “add ERC-20” insufficient.
3. **The Pool — useful fixed-asset alternative, but the weakest fit.** Its fixed-asset ERC-4626 NAV and selected-output-or-revert behavior are useful references, but the external adapter, owner-managed range/reference, PositionManager/NFT route, reserve-sale complexity, and native-ETH rejection add rather than remove adaptation work.

**Best strategy model:** Weir/local stage-one full-range direct ownership.  
**Best accounting and conversion reference:** lpTOKEN plus its strict `ZapRouter` semantics.  
**Lowest actual adaptation burden:** the existing local stage-one implementation, corrected with lpTOKEN's output postcondition and a new explicitly authorized already-unlocked entry—not a vanilla import of any candidate.

No candidate supplies a safe downstream rate multiplier ready-made.

## Requirement fit

| Requirement | lpTOKEN | WeirVaults | The Pool |
|---|---|---|---|
| Transferable share | Native ERC-20; best starting point | Internal `sharesOf` ledger with `transferShares`; ERC-20 must be introduced | ERC-4626 share already exists |
| Strategy | One fixed, supply-derived range; not the local full-range goal | One direct full-range position per PoolId; simplest fit | PositionManager NFT with owner-managed range |
| Exact one-token result | `zapOut`/`zapOutTarget` require complete unwanted-leg consumption or revert | Attempts conversion but settles both deltas; partial fill can pay a second token | Fixed-asset payout or revert; no automatic pair fallback |
| Entry/exit conversion | Same-pool direct legs; restricted native/stable routed entry | Same-pool native conversion | Configured external `IZapRouter`; current venue/wiring unverified |
| Same-manager hook callback | Vanilla vault and zap each require new unlocks | Vanilla deposit/withdraw/compound require new unlocks | Ordinary PositionManager route also has unlock-based flows; without-unlock is possible but adds NFT/adapter machinery |
| Ownership/idle accounting | Strong proportional portfolio accounting including idle and pending fees | Liquidity-ratio issuance plus idle dust; ERC-20 wrapper alone does not fix entrant attribution | Net-added-NAV issuance is useful, but fixed-asset, escrow, and reserve-sale accounting is more complex |
| No independent market | Can convert in backing pool; no fair-price guarantee | Can convert in backing pool; no fair-price guarantee | Depends on adapter and owner-refreshable reference; poor fit for the premise |
| Local policy fit | Remove 30-bps share fee, dead shares, launch range/NAV | Remove performance fee, locked shares, residual exit, admin/policy mismatch | Native ETH unsupported; fixed single asset and ERC-4626 should not be forced |

## Why “just add ERC-20” is not enough

Weir's full-range position is attractive because it avoids keeper-dependent range management. The rest of the user contract still has to change:

1. **Exact output:** `_withdraw` swaps the unwanted leg but never requires it to be fully consumed. Per-leg minima cannot prove the other output is zero. The local requirement must instead assert complete unwanted-input consumption and zero other-token payout, or revert the outer transaction.
2. **Unlocked execution:** `deposit`, `withdraw`, and `compound` call `poolManager.unlock`. A hook already executing inside the manager's global unlock cannot call them.
3. **Issuance and idle value:** Weir issues subsequent shares from liquidity added relative to existing liquidity, while the portfolio also contains idle dust. That does not by itself establish correct entrant charging for conversion cost, addition rounding, idle fees, or refunds. Use attributable reserve-growth accounting, not an ERC-20 wrapper around the existing ratio.
4. **Fee ownership:** pre-entry compounding changes the incumbent book before issuance. Entry-swap fees earned by the pre-mint position must remain incumbent-owned; a post-swap checkpoint is needed before mint. Partial V4 removal can settle all position fees, so exit allocation must be preceded by a fee checkpoint rather than assigning the whole receipt to the exiter.
5. **Local economics:** Weir's permanently unassigned first shares and default performance fee differ from stage one's no-dead-share, no-vault-fee decisions. Those are economic changes, not interface edits.
6. **Read consistency and terminal states:** a downstream pool needs a defined rate during ordinary and reentrant reads, floor rounding, zero-supply behavior, and a truthful terminal single-token failure when no post-removal depth exists.

lpTOKEN is stronger on points 1 and 3, but its vanilla code is not drop-in either: its core and zap use unlocks, its range is not the desired full-range strategy, and its launch/share-fee/dead-share features conflict with local policy.

## Same-PoolManager hook execution

Canonical `PoolManager.unlock` reverts when the manager is already unlocked. Local stage-one `_start` and `_action` also explicitly reject `ManagerAlreadyUnlocked`, and Wings `Common.execute` does the same. The current implementation therefore is not hook-composable merely by changing its ABI.

The minimal safe adaptation is an **authorized unlocked-entry engine**, not an unguarded `isUnlocked` bypass:

1. The share-consuming hook calls a narrow vault method with operation kind, backing `PoolKey`, input, recipient, minimum, and deadline. Accept this path only from the exact configured hook and only while the manager is already unlocked and that outer operation is active.
2. Preserve the ordinary locked path separately: it may call `poolManager.unlock` with an operation/payload commitment. The hook path enters the same economic engine without another unlock. Callback authentication still checks manager, active operation, and expected payload; hook-entry authentication checks the exact hook and operation. Do not expose a public arbitrary “execute while unlocked” money method.
3. Use direct `modifyLiquidity` and `swap` on the vault-owned full-range position. Canonical PositionManager now has `modifyLiquiditiesWithoutUnlock`, so a without-unlock NFT route is technically available, but it adds PositionManager ownership and delta-resolver dependencies without helping the simple local model.
4. PoolManager's unlocked state is global to the outer operation, but currency deltas are caller-specific. The vault reads and closes only `currencyDelta(manager, address(vault), currency)`. It never clears the hook's deltas or uses the outer global nonzero-delta count as its own accounting. The outer PoolManager unlock still requires every participant to settle before final lock.
5. Reserve caller input, incumbent booked idle, and exit allocation separately. On entry, collect incumbent fees before sizing, swap only caller inventory, checkpoint incumbent fees again, then add and mint against attributable reserve growth. On exit, allocate principal and idle to the exiter, sell only the unwanted allocation, require its complete consumption and the target minimum, and pay only the selected token. Any shortfall, residual second payout, or stale state reverts everything.
6. Keep the backing pool hookless under the stage-one constraint. Otherwise `modifyLiquidity` and `swap` invoke another hook and can introduce nested recursion. A different PoolManager avoids nested unlock only as a topology condition; it does not solve malicious hook recursion, price manipulation, bad issuance, or an unsafe rate.

Economic/rate reads must reject while the vault operation is busy or use a deliberately committed snapshot. Basic reserve views may expose the last committed book, but must not present it as live NAV. The current stage-one `exchangeRate` already follows a guard-first policy.

## Issuance, accounting rate, executable quote, and invariant multiplier

These are four different concepts and should remain separate:

- **Ownership/issuance:** proportional claims on position principal plus booked idle and fees. New shares are based on the entrant's attributable reserve growth, not gross deployed assets or a scalar SY quote.
- **Accounting/SY value:** fee-inclusive basket value per share. Current stage-one `exchangeRate` is raw rate-asset units per `1e18` raw shares, explicitly spot accounting and not issuance or an exit quote. Current Wings `getRate` is whole-portfolio liquidation value divided by supply; it is not evidence that normalized one-share exit quoting is already implemented.
- **Executable withdrawal-and-sale quote:** simulate the actual share allocation and sale of the unwanted leg against post-removal pool liquidity. It is amount-specific, path-specific, fee/rounding-sensitive, and can revert.
- **Downstream invariant multiplier:** an 18-decimal value the downstream pool applies in its own math. Balancer's official Vault uses `tokenRates` when scaling raw token amounts into and out of pool computations, with direction-sensitive rounding. This is not equivalent to asking what one share would fetch in a particular sale.

A normalized one-share executable quote can be useful for display or a transition-quote interface, with `1e18` raw shares meaning one whole 18-decimal share. **I do not recommend it as the generic Balancer-style invariant multiplier.** `Q(1 share)` does not linearly promise `Q(s) = s × Q(1)` for arbitrary size: post-removal depth, price impact, fees, rounding, and partial-fill reverts remain amount-dependent. Matching `IRateProvider` ABI does not resolve that economic mismatch.

For a downstream accounting multiplier, use an explicitly selected **accounting NAV rate**, preferably a conservative TWAP-marked basket rate if the backing pool provides a suitable reference. That is a **new product choice**, not an accepted replacement for the previously discussed executable `getRate`. Existing spot SY accounting may remain the SY policy without automatically being blessed as an invariant-safe Balancer input. Any such rate can fall through IL, price movement, fees, and execution costs; fee exposure does not imply monotonic appreciation or a peg.

The decimal contract also needs an explicit adapter decision. One whole share is `1e18` raw shares, while stage-one SY reports raw asset units per `1e18` shares rather than a human-normalized WAD price. Do not copy that formula into an 18-decimal downstream rate without defining target-asset scaling and rounding.

## No-independent-market premise

lpTOKEN and Weir show that conversion can execute in the backing pool itself, which is why they outrank The Pool for this use. They do not show that the execution price is fair.

An underlying-pool TWAP can be a useful accounting reference where available, but V4 core does not supply one automatically. It is not independent of the venue being valued: it introduces multi-block manipulation cost, staleness, and divergence from current execution. A TWAP-marked NAV and an executable quote answer different questions. If no defensible reference exists, the honest choices are spot accounting with disclosed limitations or no rate-provider integration—not inventing Chainlink, a peg, or a second deep pool.

Amount-specific entry/exit previews must reproduce the actual fee checkpoint, allocation, and complete sale against remaining liquidity, with the same bounded step/crossing/bitmap domain as execution. They do not need a new general swap simulator. The existing 12M execution and independent preview budgets are context for bounded planning, not permission to weaken atomicity or owner-approved limits.

## Minimal required adaptations

1. Keep local full-range direct ownership, canonical Diamond/ERC-20 facets, native SY/SE surfaces, no dead shares, and no vault-level fee. Do not force ERC-4626 on a naturally two-currency basket.
2. Adopt lpTOKEN's strict full-spend-or-revert conversion postcondition, with the local requirement of no residual second-token payout or custody.
3. Add the narrowly authorized already-unlocked engine described above; preserve existing locked callbacks and read guards rather than deleting `ManagerAlreadyUnlocked` checks.
4. Use stage-one attributable entry credit and categorized idle/input/exit inventories, not Weir's liquidity-only issuance or gross deployment.
5. Keep accounting NAV, executable amount-specific quotes, and any downstream rate adapter as separate interfaces and product decisions.
6. Preserve exact-input SE routes and explicit exact-output unsupported behavior. A rate-provider interface alone does not add exact-output execution.
7. Keep native ETH/wrapped-face settlement and the local no-independent-market policy; do not import The Pool's native-ETH restriction or external-adapter assumption.
8. Retain bounded execution-equivalent previews and operation guards. Rate and economic reads must not observe half-mutated transient state.

## Other candidates, briefly

- **ALPS:** managed multi-pool basket and keeper model exceed the simple strategy; V4 non-base conversion is skipped without a TWAP, so exact single-USDC exit is conditional.
- **USDa/Ascnt:** requires an off-pool conversion market and can automatically pay two tokens, contrary to the exact one-token requirement.
- **Unoxi:** asynchronous two-sided rounds and confidential wrappers are incompatible with synchronous hook-swap settlement.
- **ZapVault:** per-user rather than pooled shares, no enforced user min-out/deadline, and residual-custody concerns make it unsuitable.

## Decisions that remain genuinely open

1. **Downstream rate semantics:** spot accounting NAV, TWAP-marked accounting NAV, or a separate executable quote used only for transitions. My recommendation is accounting NAV for the multiplier and executable quotes for actual exits; the owner must approve that as a new choice rather than treating it as prior policy.
2. **Reference availability:** whether the backing pool can supply a bounded TWAP worth its staleness/manipulation tradeoff. This must not be assumed.
3. **Exit-depth policy:** terminal single-token exit can be impossible when the vault was the only effective liquidity. Reverting is consistent with the requirement; promising unlimited exit is not. Paired redemption is a separate user choice, not a silent fallback.
4. **Code copying:** lpTOKEN is BSD-3-Clause and Weir's matched source is MIT, but exact copied code still needs provenance and dependency review. The Pool's exact copying terms were not established here. Public source verification alone is not a license grant.

## Sources read and limits

- New adaptation brief and prior common report: `docs/research/v4-vault-adaptation-20261029-01a18660/brief.md`; `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`.
- Local PRD: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, especially S1-D03/P03/P06/P07, S1-ACC-01–07, S1-OP-01–05, S1-API-04–05, S1-QUOTE-01–02, and S1-SEC-01.
- Local execution: `UniswapV4PairTokenStandardExchangeVaultExecution.sol`, `_start` at line 323, `_action` at line 548, settlement, inventory, and final publication.
- Local rates: `UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol`, `exchangeRate`; `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol`, `getRate`; `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`, `execute`; `contracts/interfaces/IStandardExchangeTransitionQuote.sol`.
- Balancer interface and current Vault: local `IRateProvider.sol`; official https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/vault/contracts/Vault.sol, including token-rate scaling and rounding in swap/liquidity math.
- Weir matched source: https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources, principal `src/WeirVaults.sol` (MIT).
- lpTOKEN: https://github.com/Steemhunt/lptoken-contracts and https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/LICENSE; prior reads of `LpTokenVault.sol` and `ZapRouter.sol` in the admitted research.
- The Pool matched-source record: https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources. Its principal behavior is taken from the admitted prior report/source inspection; this turn's large bundle fetch was truncated before the principal implementation.
- Canonical V4: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol and https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/PositionManager.sol, including global unlock, caller deltas, and `modifyLiquiditiesWithoutUnlock`.

No broad candidate search, peer response from this run, code/PRD changes, tests, builds, shell, Git, installs, deployment, wallets, delegation, or external messages. Local files can change; this is not a frozen repository snapshot, an audit, or implementation authorization.
