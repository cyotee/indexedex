# Migrated staking UI

Both apps share `apps/indexedex/app`. The staking overlay is removed from both
landing pages. DTF retains the domain announcement; dismissing it reveals the
normal landing page. IndexedEx opens directly on its landing page.

`/staking` discovers DTF-DETF from the existing staking contract's migration
adapter on the selected provider. It verifies the adapter belongs to that staking
contract and uses its actual DETF address for prices, bonds and claims. It does
not use the old `platform.protocolDetf` catalog address or a URL-supplied DETF.
This works with both a local fork and public mainnet despite their shared chain ID.
An unset migration target displays an unconfigured state, and failed discovery
removes actionable controls until the provider can be read again.

## User actions

1. Connect an installed wallet through RainbowKit. The page discovers the original
   staking contract's phase, target and claim vault through that wallet's provider.
2. In Wrapped phase, the page checks `targetDetf().detfToken()` against the discovered
   DETF, the claim vault's asset against the DETF's staking SY, and that SY's yield
   token against the actual sDETF. Missing or incompatible contracts disable claims.
3. Claim part or all of the original stake with native `withdrawClaim(stakeAmount)`.
   Deposits and rewards were migrated together. Stake amounts retain the original
   DTF allocation weights; the output is static staking SY, not DTF or sDETF.
4. Redeem wallet-held SY with `redeem(account, amount, sDETF, minimum, false)`.
   The minimum is the fresh `previewRedeem` quote. No approval or pretransfer is
   needed. SY may be held before redemption; its sDETF value is quoted onchain.

Decimals come from token metadata. Zero, negative, out-of-balance, overprecision
and zero-output claims cannot execute. No JavaScript floating-point conversion is
used for amounts. The legacy claim method has no minimum-output argument: its
output is estimated and checked again by preview and simulation before signing.

Writes recheck the current account, chain, contract bindings, balance and quote.
The UI waits for a successful receipt and refreshes balances at or after its block.
A receipt-access failure offers **Check confirmation**, without submitting another
transaction. Reverts and cancellation/replacement are not reported as successful
claims. Account, connector and chain changes discard the previous inputs and quotes.

## RPC behavior

`walletFirstTransport` uses the selected Wagmi connector's EIP-1193 provider for
connected reads, simulations and receipt queries. Provider errors and chain
mismatches never fall back to an HTTP endpoint. HTTP serves disconnected browsing
only; provider/account/network transitions reset query data.

The header says **RPC: connected wallet** while connected. A browser extension does
not expose its actual RPC URL through standard EIP-1193 methods. The disconnected
**Browsing RPC** label describes the app's configured endpoint only.

## Browser verification

Use the existing dev server on port 3002. The money-path test requires a disposable
copy of the already migrated state; it does not deploy contracts. It refuses port
8545, snapshots its own node and restores it after every test. It impersonates a
real historical holder only inside that disposable fork.

Example, with the persistent rehearsal still at the verified block:

```sh
anvil --fork-url http://127.0.0.1:8545 --fork-block-number 62009895 --chain-id 4663 --port 18545 --host 127.0.0.1
```

From `frontend/apps/indexedex`, in a separate shell:

```sh
E2E_SKIP_WEBSERVER=1 \
E2E_BASE_URL=http://127.0.0.1:3002 \
E2E_RPC_URL=http://127.0.0.1:18545 \
E2E_MIGRATION_RPC_URL=http://127.0.0.1:18545 \
E2E_MIGRATION_HOLDER=0x47b5337eacaa1756a47198978418b95a87bcd902 \
npx playwright test e2e/staking-migration-live.spec.ts e2e/staking-bond-live.spec.ts --workers=1

npx vitest run app/lib/tokenStaking app/lib/walletFirstTransport.test.ts app/lib/detf/bondRoute.test.ts app/lib/tx/parseContractError.test.ts
npm run typecheck
```

Coverage includes native partial/full claims, decoded transaction arguments,
confirmed receipt and balance deltas, rejection and retry, lost receipt access,
90-day delayed SY redemption, exact decimal boundaries, zero-output protection,
empty/disconnected accounts, RPC failure, account/network changes, desktop/mobile
layout, and RainbowKit connection regressions. The money-path browser blocks the
app's port-8545 HTTP endpoint while its selected wallet uses port 18545. This proves
that connected operations use the selected provider. No production code injects a
wallet or signing key. Real extension popup behavior remains a manual wallet check.

Verified 2026-09-11: typecheck passed; 24 focused unit tests and all 17 browser tests passed.


## September 13 update

The old overlay and catalog address were still present after the latest contract
rehearsal. Earlier UI verification did not establish compatibility with that new
deployment. This update removes the staking overlay and discovers the actual
product from the staking adapter through the selected wallet provider.

Transaction deadlines now use the latest block timestamp from that provider,
so advancing the rehearsal clock does not expire new staking transactions.
The intentionally small bootstrap liquidity also limits bond purchase size:
`MaxInRatio()` now explains that the amount must be reduced. The live bond test
uses 0.00001 WETH and verifies payment, NFT ownership and funded escrow balances.

Verification uses both existing development servers (IndexedEx 3002, DTF 3003)
and a disposable fork on 18545 of the completed migration at block 62009895.
The extended claim test redeems after advancing time 90 days, then unstakes and
restakes the real product and checks exact token balance changes. The browser's
clock is not overridden. Both synthetic prices are compared independently to
onchain quotes, and the DTF announcement is checked on desktop and mobile.

Verified September 13: both app typechecks passed; 45 focused unit tests passed;
12 DTF announcement checks passed on desktop/mobile. Both apps passed the live
migration claim/redemption/stake/unstake flow and bond purchase. Additional
browser checks passed for both prices, disconnected/empty wallets, provider
failure, account changes and wrong networks. The original Anvil metadata,
including its instance ID, block/hash and snapshots, remained unchanged.
These are local development-server checks; this update has not been published
or verified in a Vercel production build.

## Synthetic prices

The staking page shows the WETH and DTF synthetic prices together. These are
per-leg ratios to each leg's creation benchmark, not USD prices. The UI discovers
the hook's non-DETF tokens in the same order as the creation-rate array and calls
`previewSynthetic` for each one. Supply is scaled from native nine-decimal DETF to
WAD; protocol LP includes both DETF-held and bond-vault-held LP without double counting.
All inputs and quotes use one block. The display matches current settled supply;
transaction previews additionally account for pending expansion. Failed reads show
Unavailable and offer retry instead of substituting the first leg's price.

Read-only browser verification against the existing node:

```sh
E2E_SKIP_WEBSERVER=1 E2E_LIVE_PRICES=1 npx playwright test e2e/staking-prices-live.spec.ts
```
