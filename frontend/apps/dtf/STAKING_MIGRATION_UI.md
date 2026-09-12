# Migrated staking UI

`/staking` includes the original DTF staking position above the general DTF-DETF
workspace. The local 4663 platform and tokenlists now reference the verified
DTF-DETF deployment from block 60445063. The migration adapter is not a DETF entry.
This export represents the existing local rehearsal, not a public deployment.

## User actions

1. Connect an installed wallet through RainbowKit. The page discovers the original
   staking contract's phase, target and claim vault through that wallet's provider.
2. In Wrapped phase, the page checks `targetDetf().detfToken()` against the catalog
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
anvil --fork-url http://127.0.0.1:8545 --fork-block-number 60445063 --chain-id 4663 --port 18545 --host 127.0.0.1
```

From `frontend/apps/dtf`, in a separate shell:

```sh
E2E_SKIP_WEBSERVER=1 \
E2E_MIGRATION_RPC_URL=http://127.0.0.1:18545 \
E2E_MIGRATION_HOLDER=0x47b5337eacaa1756a47198978418b95a87bcd902 \
npx playwright test e2e/staking-migration-live.spec.ts e2e/rainbowkit.spec.ts e2e/connected-wallet.spec.ts

npx vitest run app/lib/tokenStaking app/lib/walletFirstTransport.test.ts
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
