# Staking-page swap comparison

`/staking` now has two exact-input swap panels: the base DTF/native-ETH pool and
the reserve's DTF/WETH pair. Both display ETH to the user. Editing either input
updates the shared amount; selecting a direction updates both panels and clears
the amount. Output quotes remain independent and read-only. Slippage is shared.

A separate **Swap DTF-DETF** panel reuses the same component and transaction
controller. It defaults to selling wallet-held DTF-DETF, with an ETH/DTF dropdown
for the output. Changing the output keeps the DTF-DETF amount and invalidates the
old quote. Reversing direction also supports buying DTF-DETF with either asset.
This panel has its own amount and slippage; it does not change the two comparison
inputs. DTF-DETF's onchain decimals (9) are kept distinct from DTF's decimals (18).
It trades the unstaked token, not sDETF, and does not automatically unstake or stake.

## Pool identity

Discover the active DETF through the staking migration adapter, not the stale
catalog address. Read the DTF asset from staking and the reserve hook from the
active DETF. The WETH leg's Standard Exchange stores the base pool key. The
weighted reserve pair uses the hook's WETH/DTF currencies, dynamic-fee flag and
tick spacing 1, as defined by the deployed weighted pair-pool implementation.

Each quoter request is restricted to exactly one named pool. There is no
best-route or external API substitution. A failed quote on one side does not
hide a valid quote on the other. Pool IDs are available in each panel.
The reserve hook may interact with its underlying vaults/pools internally; the
single selected entry pool is not a promise of only one internal pool operation.

DTF-DETF quotes run through the deployed V4 quoter inside `PoolManager.unlock`.
Do not use the hook's direct `previewSwapExactIn` view: the underlying WETH SE
rate depends on whether PoolManager is already unlocked, so the direct view can
overstate executable output even at the same block.

The hook takes input during `beforeSwap`. For DTF-DETF sales, the quote's
`eth_call` temporarily adds exact input to PoolManager's DTF-DETF balance using a
state override of the canonical Crane ERC20Repo balance slot. A balance probe
verifies that the RPC honors that layout/override; failure prevents a quote.
This does not donate tokens, send an approval, or change persistent state.
Other inputs use the deployed quoter without that override.

The balance read, override probe and funded quoter call use `blockTag: 'pending'`.
MetaMask's block cache omits parameters after the block tag from its cache key,
so an ordinary balance read can incorrectly satisfy the subsequent overridden
read. Pending calls bypass that cache. The layout/support probe remains required.

Actual transactions still encode exact-input **SETTLE before SWAP**, then TAKE
(and unwrap for ETH output), all in one Universal Router call. The complete
calldata is simulated with the user's real balances and approvals, with no state
override, before signing. The displayed minimum remains enforced.

The existing SE PoolKey reader was corrected to match Solidity storage packing:
currency1, fee and tick spacing share slot 1; hooks occupy slot 2.

## Transactions

- Base swaps use native ETH directly.
- Reserve buys use Universal Router WRAP_ETH followed by a V4 swap, settling
  router-held WETH. Reserve sells take WETH to the router and unwrap to the caller.
  Each swap is atomic; no separate wrap transaction is required.
- The single-hop encoder includes the deployed router's `minHopPriceX36` field
  before `hookData`. The optional relative bound is zero; the reviewed absolute
  minimum output is enforced in the swap and settlement.
- DTF sales use separate exact-amount ERC20-to-Permit2 and Permit2-to-router
  approvals when required. No approval automatically triggers a swap.
- Quotes are keyed by network, deployment, wallet/connector, pool IDs, direction,
  amount and slippage. No stale placeholder quote enables execution.
- Before signing, verify current wallet/intent, balances and approvals, obtain a
  fresh quote from the selected pool, enforce the displayed minimum, and simulate
  the exact transaction calldata/value. Both panels lock during preparation/signing.
- Confirmation requires a successful receipt and matching sender, target, calldata
  and value. An uncertain receipt retains the hash and blocks resubmission until
  the user checks confirmation. Repriced/replaced transactions are checked explicitly.

The component is excluded from embedded staking instances. Existing bond, claim,
mint/burn and staking controls are unchanged.

## Verification

From `frontend/` with an existing local Robinhood mainnet fork:

```bash
E2E_SWAP_RPC=http://127.0.0.1:8545 npm run test -w @indexedex/app-indexedex -- --run app/staking/lib/swapComparison.fork.test.ts
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545 npm run build:indexedex
E2E_PORT=3012 E2E_RPC_URL=http://127.0.0.1:8545 E2E_STAKING_SWAPS=1 npm run test:e2e -w @indexedex/app-indexedex -- e2e/staking-swap-comparison.spec.ts
E2E_PORT=3012 E2E_RPC_URL=http://127.0.0.1:8545 E2E_STAKING_SWAPS=1 npm run test:e2e -w @indexedex/app-indexedex -- e2e/staking-detf-swap.spec.ts
```

The opt-in browser suite checks synchronization, invalidation, independent failure,
wallet changes during preparation, and actual buy/sell transactions through each
pool. It checks native/token balances, selected pool events, and no ETH/WETH residue
in the router. Fresh random test EOAs are funded only on the fork: known public
Anvil accounts may carry forwarding/delegation code inherited from mainnet.
Transaction tests restore snapshots. No contracts are redeployed.
An injected confirmation-provider failure verifies that both forms stay locked,
the receipt can be checked after recovery, and no second transaction is submitted.
The DTF-DETF suite verifies both output choices, reversing into buys, decimal
precision, independence from the comparison inputs, actual recipient balances,
selected reserve-pair events, PoolManager balance restoration and unchanged
DTF-DETF total supply (no primary mint/burn substitution).

### Resume verification — 2026-09-15

Reviewed the existing implementation without rewriting it. An independent agent
completed a read-only review of the controller, approval helpers, native
settlement, hook execution and tests; it found no actionable bugs. That review
did not run transactions; the checks below were run separately by the primary agent.

- Both existing loopback nodes identified as Anvil 1.5.1, chain 4663, and returned
  the recorded block-63405378 hash in `MAINNET_FORK_VERIFICATION.md`.
- App `check` with `E2E_SWAP_RPC=http://127.0.0.1:8545`: **466 tests passed**
  across 64 files, typecheck passed, and the deployment configuration test passed.
  Lint reported **0 errors and 78 warnings**.
- Shared protocol tests: **22 passed** across four files.
- Sequential IndexedEx and DTF production builds: **both passed**. Both retained
  the MetaMask SDK warning about unresolved `@react-native-async-storage/async-storage`.
- Combined swap browser suites: **9 passed on IndexedEx** (26.6s), then
  **9 passed on DTF** (27.1s), using the verified local fork. The previously
  reported reserve round-trip revert did not recur; its earlier cause remains
  undiagnosed.
- Both running dev pages (3002/3003) displayed the new panel and matching quotes.
  Selling `0.000001` DTF-DETF quoted `0.000000801631479214` ETH or
  `1.262400243672452639` DTF; switching assets preserved the input. These are
  snapshot observations, not fixed price expectations. Initial browser checks
  timed out when typing before pool discovery; waiting for discovery before
  entering the amount passed on both variants.
- Desktop/mobile panel screenshots were inspected. `git diff --check` passed.

Remaining limits: replacement/cancellation receipt branches lack explicit browser
coverage, and pending transaction state is component-local and does not survive
reload. The local Crane router interface has the older single-hop layout; deployed
router compatibility is supported by the fork execution checks. The broader
historical frontend failures documented in `MAINNET_FORK_VERIFICATION.md` remain;
this focused verification does not establish an all-green historical suite.
No contracts, deployment settings, commits or published deployments changed.

### Follow-up: reported 1 DTF-DETF sale failure

The reported hash
`0xad6baa01d44b35b24043971b1e9ba64f06646e622588f846e67b2f71c24ff65e`
decodes to a Permit2 approval for exactly 1 DTF-DETF, not a Universal Router swap.
Its transaction block is ahead of the original fork. After the user authorized
the live read-only check, the public RPC confirmed the approval succeeded at
block 63690690. The wallet had sufficient input balance and both approvals.

An exact 1 DTF-DETF sale passed simulation on disposable fork port 18545. A new
browser regression transfers existing token inventory to a fresh local test EOA
without changing reserve inventory, makes exact approvals, injects a wallet
simulation failure, verifies no new transaction was sent, and then executes the
real 1-token sale after provider recovery. It checks the successful receipt,
full input debit and minimum ETH output, then restores the fork snapshot.

The UI now identifies the last submitted transaction as an approval, permission
or swap. Preparation and simulation failures explicitly say no new transaction
was submitted; submission failures retain their original message because their
broadcast outcome may be unknown. This fixes misleading error/hash presentation,
independently of the quote-calculation fix described below.

The focused new browser regression passed. App checks still report 466 passing
tests, successful typecheck/configuration checks, and 0 lint errors/78 warnings.
The broader dev-server run had 7 passes and 3 failures: two input tests typed
before hydration (now they wait for pool discovery), and the reserve round-trip
test timed out before wallet connection behind a React development error overlay
at the existing `app/layout.tsx` script. That run did not reproduce a reserve
transaction revert. The fresh IndexedEx production build passed; the development
overlay itself has not been changed or conclusively diagnosed.
The corrected combined suites then passed **10/10** against the fresh IndexedEx
production build (28.7s), including the exact 1-token sale and both reserve/base
round-trips. No live transaction was submitted during this investigation.

### Resolved: quote outside the PoolManager swap context

The user confirmed localhost:3002 with a personal wallet using public mainnet.
`walletFirstTransport` makes the connected wallet authoritative for reads, so
this was not a fork/mainnet quote mixup. Public-router bytecode matched the fork.
The real-wallet and fresh-address simulations both returned
`V4TooLittleReceived(uint256,uint256)` (`0x8b063d73`), not a calldata decoder error.
One captured live quote was 0.053048355116091865 ETH, while execution returned
0.030140182503709738 ETH, below the 0.052783113340511405 ETH displayed minimum.

An additional isolated Anvil fork on port 28545 pinned block **63706482**,
hash `0xda43d9f38d8dd32aeecd3c0fba17c8891fba8e79777202cfe12aca4342ca93d6`.
Traces showed the same hook facet and weighted math, but different WETH SE
rating while PoolManager was unlocked. The V4 quoter reproduced the executable
output; a direct hook preview did not. The original 63405378 fork did not expose
this material difference, which explains why its earlier tests were insufficient.

The frontend now uses the V4 quoter with the simulation-only input funding above.
The wallet's complete swap subsequently passed read-only simulation on public
mainnet at a checked quote of 0.030443048982203862 ETH. These are observations,
not fixed price expectations. No slippage increase, contract change, PoolManager
donation, or live transaction was needed. Unknown minimum-output errors now map
to a clear message asking the user to refresh and review the quote.

The injected test wallet now preserves all `eth_call` parameters and original
revert data, including state overrides. The exact 1-token browser test verifies
PoolManager balances remain unchanged by quoting and restored after settlement,
plus unchanged total supply. Another test rejects RPCs that ignore quote funding.

Verification of this fix:

- App checks with the affected **63706482** fork: **467 tests passed**, typecheck
  and deployment configuration checks passed, **0 lint errors / 78 warnings**.
- Both IndexedEx and DTF production builds passed. Existing optional wallet SDK
  dependency warnings remain.
- Combined browser suites: **11/11 IndexedEx** (35.4s), **11/11 DTF** (33.8s),
  including the exact 1-token sale, reverse buys, both settlement selections,
  original comparison swaps, wallet changes, and confirmation recovery.
- The first new-snapshot browser run had **7 passes / 4 failures** after the public
  fork upstream returned `metadata is not found` during simulation and account
  setup. Only the isolated port-28545 fork was recreated at the same verified block
  using the existing authorized archive upstream; both full reruns then passed.
  The original ports 8545 and 18545 were not reset.
- A signing-disabled browser wallet using the user's public RPC on
  `http://localhost:3002/staking` displayed **0.030362727995896723 ETH** for
  1 DTF-DETF. The earlier read-only browser attempts lacked storage-read permission
  in the test wallet; adding `eth_getStorageAt` allowed pool discovery. The live
  UI then requested the Permit2 permission step. These checks submitted nothing.
- The existing DTF dev page on port 3003 also rendered a quote against its older
  local fork; that fork's price is not a live-market comparison. Desktop/mobile
  panel screenshots were inspected.
- Independent static review found no actionable issue in the quote funding,
  storage-layout probe, real-state execution simulation, or new regression tests.
  This review supplements the affected-state execution tests; it is not itself
  an execution test.

DTF-DETF input quotes require an RPC that supports `eth_call` state overrides.
Unsupported or ignored overrides prevent quoting. The historical suite limitations
in `MAINNET_FORK_VERIFICATION.md` and earlier unexplained reserve transient remain
documented; this fix does not diagnose that earlier transient. All changes remain
uncommitted and undeployed.

### Follow-up: MetaMask quote cache compatibility

Reports that Rabby worked while MetaMask failed led to a reproduction with the
published `@metamask/eth-json-rpc-middleware@25.0.0`, installed only in a temporary
test directory. Its real `createBlockCacheMiddleware` wrapped real read-only
calls to the affected-state fork on port 28545. Before the fix, only the ordinary
balance read reached Anvil; the overridden read received that cached result and
the app threw `This RPC could not simulate reserve input funding.` After the fix,
all three calls reached Anvil and the quote matched a direct call:
0.030191340287978048 ETH for 1 DTF-DETF at that snapshot.

The upstream cache key calls `paramsWithoutBlockTag`, which uses
`request.params.slice(0, index)` and drops the state override. Its block cache
explicitly bypasses `pending` calls. Sources:
[cache key](https://github.com/MetaMask/core/blob/main/packages/eth-json-rpc-middleware/src/utils/cache.ts),
[pending bypass](https://github.com/MetaMask/core/blob/main/packages/eth-json-rpc-middleware/src/block-cache.ts).
The fix tags the three funded quote calls as pending and invalidates the UI's
previous quote cache. Exact approvals, router encoding, real-state pre-signing
simulation and minimum-output checks are unchanged.

The exact 1-token browser regression now includes the same block-cache key
behavior while caching only actual RPC responses. It still exercises approval,
simulated provider failure without submission, recovery, actual fork settlement,
unchanged supply and restored PoolManager balance. This reproduction tests the
published middleware and injected-wallet behavior, not the affected user's exact
MetaMask extension/mobile version.

RPC routing remains through the selected connector for connected reads and
pre-signing simulation. Injected wallets receive the calls directly. WalletConnect
can handle non-session read methods through its HTTP provider, configured here
with the chain's public Robinhood RPC; the connector is not a guarantee of the
RPC configured inside the remote wallet. Disconnected production browsing uses
`https://rpc.mainnet.chain.robinhood.com`. Safari success alone does not establish
which wallet/provider was involved.

Validation of this local follow-up: **467 app tests**, typecheck and configuration
checks passed; lint remained **0 errors / 78 existing warnings**. The IndexedEx
production build passed, followed by **11/11 combined swap browser tests** (38.5s),
including the exact 1-token sale through the cache. The new cache regression first
ran against the previous production build and failed with `Quote unavailable`;
it passed after rebuilding the fix. An anonymous public-RPC pending-state quote
also passed (0.032487781734049653 ETH at the time checked). No live transaction was
submitted. These verification results were recorded before the separately
authorized production rollout, with `d8b6148a` as the previous production revision.
