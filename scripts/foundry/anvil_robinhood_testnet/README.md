# Robinhood Testnet (46630) — launch groups

**PRD:** [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) v2.0  
**Plan:** [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md)

These Foundry groups are the **46630 deploy path**. Set `DEPLOYER_ADDRESS`; forge uses `--sender` and the **cast wallet** signs (Anvil fork or public RPC). Point them at a **local Anvil fork** to rehearse and drive the UI, or `--live` to broadcast to public Robinhood Chain Testnet.

| | Value |
|--|--|
| Chain id | **46630** |
| Broadcast | `--sender $DEPLOYER_ADDRESS` (cast wallet; no `--private-key`, no `--unlocked`) |
| Local RPC | `http://127.0.0.1:8545` (default) |
| Live RPC | `--live` → Foundry alias `robinhood_testnet`, or `--rpc-url` |
| Anvil node (local only) | `--chain-id 46630 --disable-code-size-limit` |
| Anvil fork source | `robinhood_testnet_alchemy` → fallback `robinhood_testnet` |
| Artifacts | `deployments/anvil_robinhood_testnet/` |
| Frontend | `frontend/packages/protocol/src/addresses/chain/46630/` |

No Balancer. No pons. No Uni V3. No `vm.warp`. No nested DETFs. Demo products are the required fee DETF (`TTRICH` / `TTCHIR` / `TTRICHIR`) and the USD quad (`TTDOL-Q`).

## Groups

| Group | Script | What |
|-------|--------|------|
| 00 | `Script_00_Preflight.s.sol` | Required RH pins only |
| 01 | `Script_01_Factories.s.sol` | CREATE3, diamond factory, hook factory, shared facets |
| 02 | `Script_02_Platform.s.sol` | FeeCollector, manager, RP pkg, D46/D52/bond terms |
| 03 | `Script_03_UniV4Packages.s.sol` | Uni V4 SE + CP (Protocol DETF / TTCHIR) + Curve Quad (Double Dollar / `$$DETF`) **packages**. No instances. No Orbital or Weighted. |
| 03b | `Script_03b_OrbitalWeightedPackages.s.sol` | **Opt-in later.** Orbital + Weighted hook / DETF packages. Not in `all`. |
| 04 | `Script_04_Tokens.s.sol` | `TTRICH`, `TTUSDG`, `TTUSDE`, `TTWETH` + facade + 1e12 to deployer and `UI_WALLET` |
| 04b | `Script_04b_SevenTestTokens.s.sol` | Mag7 `TTNVDA`…`TTTSLA`. Facade as **global** operator on those plus group-04 tokens. 1e6 of each Mag7 token and of `TTWETH` to `DEPLOYER_ADDRESS`. |
| 05 | `Script_05_LeafPoolsAndSEs.s.sol` | `TTRICH`/`TTWETH` SE + three USD SEs for `TTDOL-Q` |
| 06t | `Script_06_Ttchir.s.sol` | Required first DETF: `TTCHIR` (pair `TTWETH`, SE `TTRICH`/`TTWETH`). Claim `TTRICHIR`. First-bond 10 TTWETH as the deployer EOA. Opening WAD is launch-rich. |
| 06e | `Script_06e_DolQ.s.sol` | USD quad `TTDOL-Q` (TTUSDE, TTUSDG, TTWETH) + first-bond as the deployer EOA. Opening WAD is launch-rich. |
| 06 | `Script_06_LeafDETFs.s.sol` | Both DETFs in one script (resume-safe). Used by SimulateLaunch |
| 09 | `Script_09_ExportFrontend.s.sol` | `chain/46630/` export (no on-chain txs). Includes Mag7 from `04b_seven_test_tokens.json`. Final step of `all` / `fresh_deploy.sh`. |
| Sim | `Script_SimulateLaunch.s.sol` | **Alternate** to staged 00–06: groups **01–06** plus **04b** in one script for a gas estimate. Not part of `all`. |

## Local Anvil rehearsal

```bash
export DEPLOYER_ADDRESS=0x...   # cast wallet account; required

# Official public 46630 RPC at the remote tip (Anvil default; no historical pin).
bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --public-rpc --fork-latest
# --public-rpc alone still pins head-64 (prunes mid-run on this node).

# Alchemy archive (needs ALCHEMY_KEY + working DNS)
# export ALCHEMY_KEY=...
# bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh
# wait for [SUCCESS]

cast chain-id --rpc-url http://127.0.0.1:8545   # must print 46630
```

No Anvil account default. `DEPLOYER_ADDRESS` must have ETH on the fork. Anvil may run `--disable-code-size-limit` (node flag).

If Anvil is already a 46630 fork on `:8545`:

```bash
export DEPLOYER_ADDRESS=0x...
bash scripts/shell/anvil_robinhood_testnet.sh all
```

Replay after reset: `--restart-anvil` then `all` again. Resume `TTCHIR` with `stage06t`. Resume `TTDOL-Q` with `stage06e`. Resume Mag7 with `stage04b`.

If the public RPC returns `metadata is not found` mid-run, `detach-fork` dumps the overlay and restarts Anvil without a fork, then retries the failed group.

## Live public 46630

```bash
export DEPLOYER_ADDRESS=0x...     # same cast wallet account as local
# optional: export UI_WALLET=0x...  (defaults to DEPLOYER_ADDRESS)
bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh --live
# or:
bash scripts/shell/anvil_robinhood_testnet.sh all --live
# or an explicit RPC:
bash scripts/shell/anvil_robinhood_testnet.sh all --rpc-url https://rpc.testnet.chain.robinhood.com
```

`--live` does not start Anvil. The deployer needs real 46630 ETH (faucet).

Every group **simulates first**, then broadcasts only if that sim passes. `--skip-simulation` is not used. Dry-run a group against public 46630, then broadcast the same group:

```bash
bash scripts/shell/anvil_robinhood_testnet.sh stage01 --live --dry-run
bash scripts/shell/anvil_robinhood_testnet.sh stage01 --live
```

`all --live` does the same per group (00, 01, 02, 03, 04, 04b, 05, 06t, 06e, 09). Group 09 only writes frontend JSON.

`all` / `fresh_deploy.sh` runs `00`–`05`, `04b`, `06t` (`TTCHIR`), `06e` (`TTDOL-Q`), `09`. It does **not** run `03b` (Orbital + Weighted). Product names: underlying `TTRICH`, DETF `TTCHIR`, claim `TTRICHIR`. USD quad is `TTDOL-Q` / `$$DETF`.

Each leaf script premines via `UniswapV4DetfHookPremineLib` **before** `startBroadcast` (Foundry otherwise folds `findMineNonce` into `eth_estimateGas`), then `deployVault(args, mineNonce)` (nonce is not in PkgArgs; `0` is a legal nonce). `deployVault` leaves a bootstrap hook only (not a ready reserve). Scripts then send one `deployPair` per product door, `finalizeInitialization`, `completeReserveBondNft`, `completeReserveClaim`, then first-bond as the EOA. Opening WAD is launch-rich. Do not impersonate the diamond.

## Gas estimate (alternate path, not mixed with `all`)

Fresh Anvil, then SimulateLaunch only. Do **not** run this after a completed staged `all`.

```bash
export DEPLOYER_ADDRESS=0x...
bash scripts/shell/anvil_robinhood_testnet.sh simulate --restart-anvil --dry-run
# or omit --dry-run to broadcast 01–06 in one script
```

## DTF (port 3002)

```bash
cd frontend
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_testnet \
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545 \
npm run dev -w @indexedex/app-dtf
```

Wallet: RPC `http://127.0.0.1:8545`, chain id **46630**, currency ETH.  
Lists `TTCHIR` and `TTDOL-Q`. `/mint` offers `TTRICH`, `TTUSDG`, `TTUSDE`, `TTWETH` (not canonical WETH, not faucet stocks). Canonical RH WETH still exists for V4/Permit2 pins; demo pools wrap nothing and mint `TTWETH` instead.
