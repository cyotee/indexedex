# Kimi independent response: full-spread blocker resolutions

## Identity

- Member: `kimi`
- Profile: `research`
- Phase: initial independent response
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity beyond the requested route: not exposed
- Peers read before submission: no

## Source observations

- `REMEDIATION_PRD.md` leaves F1 through F15 open and does not select their procedures.
- `IMPLEMENTATION_PLAN_BLOCKERS.md` locks the surrounding economics: no sleeve, fees netted from new shares and clamped at 30%, no pass-through fee, raw-liquidity shares, no both-token maintenance swap, mathematical quotes, no `PkgInit.wrappedNative`, initialization ownership from `feeTo()`, and no shortfall pull for an overstated maximum.
- `PRETRANSFER_DIRECTIVE.md` also locks the unbooked-balance snapshot domain, payer refunds in the provided token, preservation of unrelated staged balances, and a remainder in the provided token.
- The PRD supplies FS-OWN-33's “about half,” FS-A01's absence row, FS-A22's unlocked-route guard, and the compound and idle sentences named by F14; the function review keeps `donate(token, amount)`.

The sentences below are recommendations and inference from those observations, not statements of an existing owner lock.

## Recommended lock sentences

### F1 — Overstated-maximum order

**Recommended sentence:** On every route or bundle leg accepting `pretransferred`, snapshot the provided token’s unbooked held balance before any use, and if the declared maximum exceeds that snapshot, process none of the call, refund the entire snapshot to the payer in the provided token, and make previews and minimum-out checks follow that same no-processing branch without pulling the shortfall.

**Rejected alternative:** Processing up to the unbooked balance is rejected because it cannot also refund the entire unbooked balance as the owner locked.

### F2 — Fees collected on liquidity-adding user routes

**Recommended sentence:** On a deposit, bundle deposit, or share-minting `exchangeIn`, any position fees collected by `modifyLiquidity` are added to the booked token balances and left undeployed until a later `donate()` or `compound()`, they never enter the depositor’s consumed input, refund, or share credit, and if no fees are collected the route books none and still does not call `compound()`.

**Rejected alternative:** Leaving collected fees unbooked or crediting them to the depositor is rejected because it conflicts with the locked separation of collected fees from user principal.

### F3 — Booked total and zero added liquidity

**Recommended sentence:** After the one permitted deposit in `donate()` or `compound()`, set each token’s booked balance to its actual post-deposit held balance rather than adding a calculated excess, and if that deposit adds zero liquidity, return successfully with all inputs still booked and make no second attempt.

**Rejected alternative:** Booking only the calculated excess or incrementing it onto the post-deposit balance is rejected because the later actual-balance sentence governs the total and prevents double counting.

### F4 — Position ratio

**Recommended sentence:** “Position ratio” means the ratio of the full-range position’s current principal token0 and token1 amounts implied by the pool’s current `sqrtPriceX96`, excluding unpaid fees and booked balances, and that same ratio determines both the scarcer token and proportional matching.

**Rejected alternative:** Including unpaid fees in the ratio is rejected because fees are collected and booked separately rather than treated as position principal.

### F5 — One-token swap size

**Recommended sentence:** FS-OWN-33’s “about half” is made exact for both one-sided user deposits and one-token `donate()` or `compound()`: swap `floor(pre-swap processed-token balance / 2)`, and leave any post-deposit remainder in the processed token.

**Rejected alternative:** A separate exact-ratio or optimal-planner swap for maintenance is rejected because the booking lock expressly points to the one-sided user-deposit rule.

### F6 — One-token exit residual

**Recommended sentence:** The no-leftover-shortfall-revert sentence is confined to the removed sleeve top-up, so if the one-token exit swap leaves any unconverted withdrawn principal, the redemption reverts rather than paying the unwanted token, booking it, or leaving it behind.

**Rejected alternative:** Paying or booking an unconverted residual is rejected because the accepted one-token exit pays only the selected token or reverts.

### F7 — `Compounded()` predicate and amount source

**Recommended sentence:** Emit `Compounded()` once exactly when `donate()` or `compound()` adds positive liquidity and its combined processing balance includes newly collected or previously booked fees, including a mixed balance but excluding donation-only and zero-liquidity results, and keep the event argument-free while observers reconstruct amounts from PoolManager currency deltas and any `Swap` event rather than from `ModifyLiquidity` fields.

**Rejected alternative:** Deriving token amounts from `ModifyLiquidity` alone is rejected because that event carries the liquidity delta, not token amounts.

### F8 — Seven-address storage write

**Recommended sentence:** At vault-instance initialization, copy each of the seven package-immutable architecture addresses once into that instance’s Protocol Aware Repo, which is their only per-vault storage copy, so “no second copy” prohibits another repo or family-storage duplicate rather than the required instance write.

**Rejected alternative:** Reading “no second copy” as forbidding the instance write is rejected because it would make the required Crane getters unable to serve the package addresses.

### F9 — Crane getters and FS-A01

**Recommended sentence:** In FS-A01, replace the blanket absence assertion for `poolManager()` and `poolKey()` with the B-07 requirement that their information is exposed through the externally callable Crane Protocol Aware and `UniswapV4SinglePositionAware` facets, with no full-spread-family duplicate getters.

**Rejected alternative:** Keeping FS-A01’s absence row unchanged is rejected because it would contradict the locked externally callable Crane pairs.

### F10 — `donate` signature and pretransfer input

**Recommended sentence:** Keep `donate(address token, uint256 amount)` as the only full-spread family donation selector, with the shared Standard Exchange interface’s `pretransferred` value treated as dispatch context that selects held-balance use or pulling rather than as an added argument or overload.

**Rejected alternative:** Appending a Boolean to `donate` is rejected because the function review keeps the two-argument signature and F10 does not authorize a selector change.

### F11 — Batch-swap route scope

**Recommended sentence:** The batch-swap permission applies only to canonical `exchangeIn` on the borrowed-unlock path, including underlying-to-underlying, share-minting, and share-redeeming cases, while `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` retain `ManagerAlreadyUnlocked` when the manager is already unlocked.

**Rejected alternative:** Extending the borrowed-unlock permission to bundle and maintenance routes is rejected because the owner’s batch-swap sentence does not expressly remove FS-A22’s guards for those routes.

### F12 — Owner snapshot, later oracle changes, and zero

**Recommended sentence:** Proxy initialization stores the then-current `feeTo()` as a one-time owner snapshot that later Fee Oracle changes do not alter, and if that value is zero the stored owner is `address(0)`, so maintenance remains callable by an authorized operator and is unavailable when no operator is authorized.

**Rejected alternative:** Reading `feeTo()` live on every maintenance call is rejected because the lock says to set the owner at initialization, not to track the oracle forever.

### F13 — Deployed liquidity versus deployed token reserves

**Recommended sentence:** Use “deployed liquidity” only for the raw V4 liquidity number in share mint and burn denominators, and “deployed token reserves” only for the per-token position principal plus unpaid fees returned by `reserves()` and `reserveOfToken()`.

**Rejected alternative:** Using “deployed reserve” for both quantities is rejected because it can make the token-denominated view return the liquidity-denominated share input.

### F14 — PRD sentences removed by the no-compound lock

**Recommended sentence:** In the comprehensive PRD pass, replace FS-MONEY-01’s pre-deposit and pre-withdrawal `_compound` and pro-rata-idle withdrawal language, FS-A11’s matching assertions, and FS-A33’s borrowed-path compound assertion with the B-02 rules that deposit, withdrawal, and `exchangeIn` never call `compound()`, withdrawals book collected fees, and callers receive only their principal fraction.

**Rejected alternative:** Editing only the PRD rows cited directly by B-02 is rejected because it leaves the older compound and pro-rata-idle requirements in force.

### F15 — Thirty-two-byte preview consumers

**Recommended sentence:** The comprehensive PRD pass is complete only after it names every source, test, and integration consumer of the old 32-byte `previewExchangeIn` return and specifies that each reads `(uint256 amountOut, uint256 amountRefunded)`, with that enumeration required to finish the pass rather than gate its start and no consumer list invented from the blockers file alone.

**Rejected alternative:** Treating B-08 as already containing the consumer list is rejected because both B-08 and F15 expressly assign that enumeration to the comprehensive pass.

## Limits

These are advisory proposals only; they do not authorize implementation, a PRD edit, or an owner lock, and no tests or implementation commands were run.
