# PRD: EtherFi liquidity-pool interface and address root cause (APEX open item 3 follow-up)

- **Parent plan:** [apex-2026-09-17-remediation-and-regression-tests.plan.md](./apex-2026-09-17-remediation-and-regression-tests.plan.md) (D30, D34, D40, D46, R14 EtherFi row, R14.20)
- **Open-items file:** [apex-2026-09-17-review-open-items.md](./apex-2026-09-17-review-open-items.md) item 3
- **Created:** 2026-09-20
- **Status:** ready for research
- **Execution boundary:** read-only chain research, source verification and a written decision. No production change in this PRD. Any change to D40 or to the fork suites is executed under a separate request that cites this PRD's findings.

## 1. Question

`EtherFiStandardExchangeProjectionFork` (second contract in `test/foundry/fork/eth_main/vaults/staking/etherfi/EtherFiWeETHStandardExchange_Fork.t.sol`) reverts in `setUp` at its pinned block 24,000,000 with `unrecognized function selector 0xda748b10` (`pausedUntil()`) on the contract behind `0x308861A430be4cce5502d0A12724771Fc6DaF216`. The production precheck `_etherFiStakeOpen` (`EtherFiWeETHStandardExchangeCommon.sol:400`) reads `pausedUntil()` and `blacklister()` with hard `staticcall`s (D30/D40), so a WETH-to-SE deposit reverts on that block. Determine whether IndexedEx integrates with the wrong address, the wrong interface, or a moving target, and what the integration should rely on.

## 2. Findings already established (2026-09-20, `ethereum_mainnet_alchemy`)

| Fact | Value |
| --- | --- |
| Address under test | `0x308861A430be4cce5502d0A12724771Fc6DaF216` (EtherFi LiquidityPool proxy, EIP-1967 slot read) |
| `etherFiRedemptionManager()` at block 24,000,000 and at 26,023,844 | `0xDadEf1fFBFeaAB4f68A9fD181395F68b4e4E7Ae0` (same; the proxy is the same product across both blocks) |
| Implementation at 24,000,000 | `0xA5C1ddD9185901E3c05E0660126627E039D0a626`: answers `paused()` (false), reverts on `pausedUntil()` and `blacklister()` |
| Implementation at 24,500,000 | `0x8765Bb2F362a4B72e614DF81E2841275b9358F8b` |
| Implementation at 25,000,000 and 25,533,307 | `0x83BC649fcDb2c8DA146b2154a559dDeDf937eF12`: reverts on `pausedUntil()` |
| Implementation from block 25,533,308 (timestamp 1784061383, 14 Jul 2026 20:36:23 UTC) to at least 26,023,844 | `0x17A16747d03006c9754548ac0d0AFF48783A4a45`: answers `paused()` false, `pausedUntil()` 0, `blacklister()` `0x5585996E7cFE95f2D99e61168B8b35C66Ff99B18`; that blacklister answers `blacklistedUntil(address)` |
| Crane port | `lib/crane/contracts/external/etherfi/` at pin `b4a0968087b178bc346cdf6bee6c0597bf4c42c7`; `LiquidityPool is … PausableUntil, …` with `IBlacklister public immutable blacklister` and `deposit(address) … whenNotPaused nonBlacklisted` |
| Fork evidence | `test_FK8_APEX_D40_livePoolPauseGatesOpen` and FK1 to FK5, FK7 pass at block 26,023,844 (`review-20260920/etherfi-fork-26023844.summary.log`) |

Preliminary conclusion: the address is correct and unchanged. The interface D40 targets is the implementation EtherFi activated on 14 July 2026; every earlier implementation lacks `pausedUntil()` and `blacklister()`. The projection contract fails only because it pins a pre-upgrade block. The remaining risk is forward-looking: the precheck hard-depends on two selectors that did not exist eight weeks before the current block, so a future implementation change would make WETH-to-SE deposits revert rather than book.

## 3. Research tasks

R1. **Source-verify the live implementation.** Following the repository's source verification procedure (`docs/` "source verification" notes), confirm that `0x17A16747d03006c9754548ac0d0AFF48783A4a45` matches the Crane pin `b4a0968` `LiquidityPool.sol` (compiler settings, constructor args, immutables including `blacklister`). Record match or the exact diff. If it does not match, identify the EtherFi repository commit that does.

R2. **Reconstruct the upgrade history.** Enumerate every implementation of the proxy since the IndexedEx EtherFi port was written (at least `0xA5C1…`, `0x8765…`, `0x83BC…`, `0x17A1…`), the block and timestamp of each `Upgraded` event, and for each implementation whether `paused()`, `pausedUntil()`, `blacklister()`, `deposit(address)`, `deposit(address,address)`, `depositToRecipient`, `requestWithdraw`, `etherFiRedemptionManager()` and `withdrawRequestNFT()` exist. Use `cast storage <proxy> <eip1967 slot> --block N` and `cast call … --block N`; the earlier `cast logs 'Upgraded(address)'` attempt returned nothing and should be repeated with the explicit topic hash and bounded block ranges.

R3. **Confirm the gate semantics on the live implementation.** For `0x17A1…`: does `deposit(address)` carry `whenNotPaused` and `nonBlacklisted` as in the port; what does `PausableUntil.whenNotPaused` check (`paused()` only, `pausedUntil()` only, or both); and what does `Blacklister.nonBlacklisted(user)` check. Confirm from verified source, not from the port alone.

R4. **Check the other EtherFi dependencies for the same drift.** `WithdrawRequestNFT` (`0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c`), `EtherFiRedemptionManager` (`0xDadE…7Ae0`), `eETH`, `weETH`: list the selectors IndexedEx calls on each (from `EtherFiWeETHStandardExchangeCommon.sol`, `EtherFiWeETHRebalanceTarget.sol`, `EtherFiWeETHStandardExchangeInTarget.sol`, `EtherFiWeETHStandardExchangeOutTarget.sol`) and verify each exists on the current implementation and on the implementation at block 24,000,000.

R5. **Evaluate the D40 policy against R1 to R4.** Produce a recommendation among:
   - **Keep D40 as written.** Hard reads of all four selectors; an EtherFi upgrade that removes one makes deposits revert (loud) until IndexedEx ships a new SE package. Consistent with D30.
   - **Pause-only precheck** (owner statement 2026-09-20: "just whether the underlying is paused"). Read `paused()` and `pausedUntil()` only; drop the blacklister probe from the precheck while keeping the operative `deposit` call as the enforcement (the pool's own `nonBlacklisted` still reverts if the vault is ever blacklisted, which D30 propagates).
   - **Tolerant probes.** Treat a missing `pausedUntil()` or `blacklister()` selector (staticcall failure or non-32-byte reply) as "gate absent, capacity open" and rely on the operative call. This conflicts with D30's "a precheck view that reverts is unexpected and propagates" and must say so explicitly.
   For each option: hermetic fixture change needed (`HermeticLiquidityPool`), production diff size, and how the fork suite proves it.

R6. **Fix the fork suites' pins.** Recommend one pinned block for the whole EtherFi fork file (post 25,533,308) and record the implementation address and code hash the pin corresponds to, so a future upgrade is detected as a pin mismatch rather than a mystery revert. Decide what `EtherFiStandardExchangeProjectionFork` was pinned to 24,000,000 for and whether that reason still holds.

## 4. Deliverables

- `docs/audits/apex-2026-09-17-open-item-3-etherfi-interface-findings.md`: the R2 implementation table, R1 verification result, R3 semantics, R4 selector matrix, and the R5 recommendation with its rationale.
- Updated R14 EtherFi evidence row: pool implementation address, code hash, upgrade block, and the four selectors, as D40 requires.
- A one-paragraph decision request for the owner if R5 recommends changing D40; otherwise a note that D40 stands.

## 5. Acceptance criteria

- [ ] A1. Every implementation address the proxy has pointed to since the port date is listed with its activation block, and the presence of the nine selectors in R2 is recorded per implementation from chain reads, not inferred.
- [ ] A2. The current implementation is source-verified against the Crane pin or the diff is documented.
- [ ] A3. The recommendation in R5 states which locked decisions it touches (D30, D40, D46) and what each option costs in production and fixture changes.
- [ ] A4. The fork pin recommendation names a block at or after 25,533,308 and the implementation hash it binds to.
- [ ] A5. No RPC credential, and no `cast` output containing one, is written into the findings file or the repository.

## 6. Commands (secret-free; the alias resolves `${ALCHEMY_KEY}` from `foundry.toml`)

```bash
RPC=<ethereum_mainnet_alchemy>
P=0x308861A430be4cce5502d0A12724771Fc6DaF216
SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc   # EIP-1967 implementation

cast storage $P $SLOT --block <N> --rpc-url $RPC
cast call $P 'paused()(bool)' --block <N> --rpc-url $RPC
cast call $P 'pausedUntil()(uint256)' --block <N> --rpc-url $RPC
cast call $P 'blacklister()(address)' --block <N> --rpc-url $RPC
cast call <blacklister> 'blacklistedUntil(address)(uint256)' <vault> --block <N> --rpc-url $RPC
cast logs --from-block <a> --to-block <b> --address $P 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b --rpc-url $RPC   # Upgraded(address)
cast code <impl> --rpc-url $RPC | shasum -a 256

FOUNDRY_PROFILE=fork forge test --fork-url $RPC --fork-block-number <pinned> \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/etherfi/**' -vv
```

## 7. Out of scope

Changing `_etherFiStakeOpen`, `HermeticLiquidityPool`, the fork pins, or D40 itself. Those follow from the R5 decision under a separate request.
