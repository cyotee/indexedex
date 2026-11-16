# Manual / MCP browser TX journeys

Use when Playwright live specs skip or for exploratory proof. Prefer **Playwright inject** for CI; this is the human/MCP checklist.

## Contents

- Shared setup
- Fee DETF bond (`/staking`)
- Strategy deposit (`/earn`)
- Swap deposit
- Assert commands

## Shared setup

1. Anvil RH: `cast chain-id` → **4663**
2. Wallet: Anvil #0 or #1 on RPC `http://127.0.0.1:8545`, chain **4663**
3. App: `npm run dev:dtf` → `http://127.0.0.1:3002`
4. Network selection stored as `indexedex:selected-network` = `4663`
5. Read addresses from `platform.json` / featured fee list — never invent

```bash
CHIR=$(jq -r .chir frontend/packages/protocol/src/addresses/chain/4663/platform.json)
WETH=$(jq -r .weth frontend/packages/protocol/src/addresses/chain/4663/platform.json)
echo "CHIR=$CHIR WETH=$WETH"
```

## Journey A — Fee DETF bond (rate asset)

**Stack:** `anvil_robinhood_fee_detf` (CHIR live after stage 11)

1. Open `/staking?detf=$CHIR`
2. Connect wallet; confirm banner chain matches **4663**
3. Bond panel: lock days ≥ on-chain min; amount `0.01` WETH
4. Click **Bond WETH** (`data-testid=staking-bond-rate-asset-submit`)
5. Expect approve (if needed) then bond tx
6. Assert:

```bash
# WETH down and/or bond NFT up (nft address from DETF reads / platform)
cast call $WETH "balanceOf(address)(uint256)" $ACCOUNT --rpc-url http://127.0.0.1:8545
```

7. UI status should mention confirmation hash

## Journey B — First bond on inert lab DETF

**Stack:** `anvil_robinhood_main` (DETFs inert until UI bond)

1. Open `/staking?detf=<cpDetfGentle from platform.json>`
2. Bond small TT/pair per product chrome
3. After success, reserve should go live (`isReserveLive` if available)

## Journey C — Earn strategy deposit

1. `/earn/<strategy vault from strategy-vaults.tokenlist.json>`
2. Deposit mode; select underlying; amount small
3. Multi-leg ActionCta: connect → approve → deposit
4. Assert vault share `balanceOf` increases

## Journey D — Swap vault deposit

1. `/swap` → pool = strategy vault; tokenIn = underlying; tokenOut = vault
2. Deposit vault toggle on when shown
3. Preview → approve legs → submit
4. Assert share balance up

## UI testids (staking bond)

| testid | Control |
|--------|---------|
| `staking-bond-lock-days` | Lock duration |
| `staking-bond-rate-asset-amount` | Rate asset amount |
| `staking-bond-rate-asset-submit` | Bond CTA |
| `staking-bond-pair-token-amount` | Pair token amount |
| `staking-bond-pair-token-submit` | Bond pair CTA |
| `detf-workspace-full` | Full staking shell |

Swap / Earn testids match IndexedEx (`swap-submit`, `earn-deposit-submit`, …).
