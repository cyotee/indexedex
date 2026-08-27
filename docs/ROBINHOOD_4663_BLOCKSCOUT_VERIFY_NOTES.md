# Robinhood 4663 Blockscout verification notes

Handoff from the 2026-08-26 explorer-verify work. Goal: source on [robinhoodchain.blockscout.com](https://robinhoodchain.blockscout.com) for the public `anvil_robinhood_main` deploy (chain id 4663).

Related scripts:

- `scripts/shell/verify_robinhood_main.sh`
- `scripts/shell/lib/rh_4663_verify_inventory.py`

This note is current process. The shell script still uses `forge verify-contract` against instance `/api?`. That path 429s and 500s on this explorer. Use flatten as described below until the script is rewritten.

Do not put `BLOCKSCOUT_API_KEY` in this file. It lives in `~/.zshenv`.

---

## Current progress

Inventory from broadcast `Phase_*/4663/run-latest.json` plus `deployments/anvil_robinhood_main/*.json`: **96** IndexedEx addresses (pins skipped: Permit2, WETH, Uni V4 cores, Morpho).

| Bucket | Count | Notes |
|--------|------:|-------|
| On explorer (best count) | ~64 | 15 Phase 02-01 already in inventory-not-in-results, plus 40 from the first remaining pass, plus 9 from the one-by-one leftover pass (4 already + 5 new) |
| Leftover queue after first remaining pass | 41 | Re-walked one at a time |
| Of those 41: already on explorer | 4 | ERC2612Facet, ERC4626StandardVaultFacet, ERC721Facet, StandardExchangeRateProviderFacet |
| Of those 41: newly verified this pass | 5 | See list below |
| Of those 41: not indexed | 29 | Explorer `is_contract` is false / `creation_status` null. Do not POST. |
| Of those 41: flatten submitted, bytecode did not match | 2 | Hook ClaimLib and PullLib |
| Of those 41: one POST 500, not retried | 1 | ERC20Facet |

Live `getabi` counts drifted because PRO/instance returned 500 or empty on addresses that already had source. Treat a later `is_verified` / `SourceCode` read as truth, not a single failed getabi.

Scratch files from this work (not in git): `/tmp/rh-flatten/*.sol`, `/tmp/rh-verify-rest/inventory.json`, `one_by_one.json`, `one_by_one_log.json`, `addr_tx.json`.

---

## Compiler pins (must match foundry.toml)

- solc `v0.8.35+commit.47b9dedd`
- optimizer on, runs `1`
- EVM `prague`
- `via_ir` off
- license `gnu_agpl_v3` (AGPL-3.0-or-later)

CREATE3 facets: empty constructor. Pass `autodetect_constructor_args: true` on flatten. Packages often have ctor ABI from inventory `constructorArgs`; flatten still verified several packages with autodetect once indexed.

Do **not** pass `--guess-constructor-args`. Blockscout `getcontractcreation` is empty for CREATE3. Foundry then errors `Response result is unexpectedly empty`.

---

## What failed (and why)

### Sourcify file import

Sourcify already has `exact_match` for Phase 02-01 (and likely more) at `https://sourcify.dev/server/v2/contract/4663/{addr}`.

Blockscout `verify_via_sourcify` does **not** fetch that repo. GET without files: `You should attach at least 2 files`. POST metadata + sources: `500 Internal Server Error`.

Sourcify **v1 API was turned off 7 July 2026**. Blockscout still talks to v1 (`/files/any/...`, old verify). File import is dead until the instance uses Sourcify v2.

### Bulk `forge verify-contract`

- `--verifier-url https://robinhoodchain.blockscout.com/api` (no `?`) hits HTML.
- Instance `/api?` without a key: 429.
- `--verifier-api-key` on PRO without putting the key on the URL: X402 "Proceed with API key or make a X402 payment".
- Fix for PRO Etherscan-compat: `--verifier-url "https://api.blockscout.com/4663/api?apikey=$BLOCKSCOUT_API_KEY"`.
- PRO `verifysourcecode` / standard-JSON over ~100KB: 413 then 500. Create3Factory standard-JSON ~890KB failed this way.

### Bulk flatten POST

POST to `/api/v2/smart-contracts/{addr}/verification/via/flattened-code` while `is_contract` is false returns `Internal server error` or `Address is not a smart-contract`. Doing that for dozens of CREATE3 addresses in a row is what produced the "every contract 500" run.

### Other footguns

- zsh: never assign `path=...`. `$path` is tied to `$PATH`. Forge then becomes "command not found".
- CREATE3 additionalContracts include a tiny CREATE2 proxy (`0x67363d3d...`). Inventory skips that init. Verify the CREATE implementation address, not the proxy.
- Python stdout is fully buffered when not a TTY. Use `python3 -u` or results never appear until the process exits.
- Do not treat a 429 or 500 as a bytecode mismatch.

---

## What works

### 1. Flatten

```bash
forge flatten <source.sol> > /tmp/rh-flatten/<Name>.sol
```

Single SPDX, single pragma. File sizes here ranged from 5KB (UniswapV4HookFlagsFacet) to ~1.1MB (DETF facets). Create3Factory flatten is 826KB and did verify.

### 2. Only submit if the explorer has indexed the address

```text
GET https://robinhoodchain.blockscout.com/api/v2/addresses/{addr}
```

Need `is_contract: true` (often with `creation_status: "success"`). If false, open the deploy tx page once:

```text
GET https://robinhoodchain.blockscout.com/tx/{hash}
GET https://robinhoodchain.blockscout.com/tx/{hash}?tab=internal
GET https://robinhoodchain.blockscout.com/address/{addr}
```

Wait. Recheck. If still not a contract, **do not POST**.

Tx hash map: broadcast `additionalContracts` plus the parent CREATE3 factory call. Built at `/tmp/rh-verify-rest/addr_tx.json`.

### 3. Submit flatten (large files: instance v2)

```text
POST https://robinhoodchain.blockscout.com/api/v2/smart-contracts/{addr}/verification/via/flattened-code
Content-Type: application/json
```

Body:

```json
{
  "compiler_version": "v0.8.35+commit.47b9dedd",
  "license_type": "gnu_agpl_v3",
  "source_code": "<flattened solidity>",
  "is_optimization_enabled": true,
  "optimization_runs": 1,
  "contract_name": "<Name>",
  "evm_version": "prague",
  "autodetect_constructor_args": true
}
```

Success: `{"message":"Smart-contract verification started"}`. Then poll:

```text
GET https://robinhoodchain.blockscout.com/api/v2/smart-contracts/{addr}
```

`is_verified: true` is enough. Indexed contracts usually pass on poll 0.

### 4. Small files only: PRO Etherscan-compat

Works for flatten under ~50KB (CallTargetRegistryQueryFacet 17KB, OperableFacet 45KB):

```text
POST https://api.blockscout.com/4663/api?apikey=$BLOCKSCOUT_API_KEY
module=contract
action=verifysourcecode
codeformat=solidity-single-file
compilerversion=v0.8.35+commit.47b9dedd
optimizationUsed=1
runs=1
evmversion=prague
licenseType=gnu_agpl_v3
```

PRO v2 `verification/via/flattened-code` is 404. Use the instance for v2 flattened-code.

### 5. Cadence

One address at a time. One POST. No immediate retry on 500. Pause 8-15s between addresses. Instance GET `/api` without a key 429s; prefer v2 JSON reads, or PRO `?apikey=`.

---

## Phase 02-01 (CREATE3 factory + initFactory): done (18/18)

All on the explorer. Flatten was the path that landed source.

| Contract | Address |
|----------|---------|
| Create3Factory | `0xd7786b10bc8bc97dc7651cab7b97086c8b227882` |
| ERC165Facet | `0x69a470758a14176c86927ee080f9419d30c49480` |
| DiamondLoupeFacet | `0x343590ed92498739225e351c27133bc2c11b91b9` |
| ERC8109IntrospectionFacet | `0xe3d915c0211a87077b14dfe995009741dac2f5da` |
| PostDeployAccountHookFacet | `0xc08a6221f2a93b965a5a12ec0f645e9eba717703` |
| DiamondCutFacet | `0xa8fb4aa08f910026d33579bd680fc133a399c447` |
| MultiStepOwnableFacet | `0xf03fad914ec73b6a7d41cece447656ae97b8b16f` |
| OperableFacet | `0xc6367d76d4b04eba5deaebdeea379dc9ea70447e` |
| Create3FactoryFacet | `0x4e6509e792d7aa5d714ff3dd3a4299269c9b3411` |
| FacetRegistryFacet | `0x5186d17216b2b5f809b318e8af4fabd649bb5b1b` |
| DiamondFactoryPackageRegistryFacet | `0x195d9af10c8d1766ce341bd80123d83b472e4dfe` |
| CallTargetRegistryQueryFacet | `0xbd33463cb05a8d1dd74a0f1f323d4fe2c70233c0` |
| CallTargetRegistryManagementFacet | `0xc19edc48b9f7d290546d7eb6bd6970e23f545099` |
| BountyCommonFacet | `0x141418f09ed11176453c782939c5c71774e7111b` |
| SingleFinalBountyFacet | `0x40fb9dc4d3db6c83b1c4edaa1d7d7bb5d1a5470c` |
| MilestoneBountyFacet | `0xa14a4be39980dccc87ab073d8960a2bfd1ab93b1` |
| ContestBountyFacet | `0xe3cda6f203d2c1627cb8ff77f2b495ba390c83cb` |
| ContinuousBountyFacet | `0xb4103dd20d189e63dfdf1595ea640c09cc24c406` |

Explorer: `https://robinhoodchain.blockscout.com/address/<addr>?tab=contract`

---

## Later phases: verified in this work (not exhaustive)

When indexed, flatten verified on first poll. Includes large files (Morpho facets ~470KB, DETF facet ~1.1MB, Create3Factory 826KB, diamond proxy 549KB).

Confirmed in the leftover one-by-one pass:

- VaultRegistryDisableQueryFacet `0x10e1211a99126304d4dadaec39146c2ac45f7f91`
- VaultRegistryVaultPackageQueryFacet `0x3daa2843d5fe3484094cd3598091fcd6043bb21b`
- DETFNFTVaultDFPkg `0xe4866b5ca0f41f0a8545d39282bbf03050182f94`
- UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg `0x407a1e8e8799a30c111ccb7358b976fa9a30f876`
- UniswapV4SingleStandardExchangeDETDFPkg `0x961b4e050492e2744b8d20404cd43a11d371577c`

Also landed earlier (first remaining pass / retries), among others: ERC4626Facet, ERC4626BasedBasicVaultFacet, ERC5267Facet, FeeCollectorManagerFacet, MorphoBlue* facets and MorphoBlueStandardExchangeDFPkg, RebasingClaimTokenFacet / DFPkg, MultiAssetBasicVaultFacet, UniswapV4HookFlagsFacet, UniswapV4MultiPoolTwapOracleFacet, UniswapV4SingleStandardExchangeDETFFacet, DiamondPackageCallBackFactory, UniswapV4HookDiamondPackageCallBackFactory, UniswapV4StandardExchangeDFPkg, indexedex manager / fee collector diamond proxies, several buffer-hook math libraries.

Rebuild a live list with:

```bash
python3 scripts/shell/lib/rh_4663_verify_inventory.py \
  --repo . --deployments deployments/anvil_robinhood_main --chain-id 4663
```

Then `GET .../api/v2/smart-contracts/{addr}` for `is_verified`. Do not bulk-GET instance `/api`.

---

## Remaining blockers

### CREATE3 not indexed (29 on the leftover queue)

Explorer has the address page but `is_contract` is false and `creation_transaction_hash` is null. On-chain `cast code` is non-empty. Opening the factory CALL tx sometimes promotes the inner CREATE. Sometimes it does not (12s wait was not enough).

Do not flatten-POST these until `is_contract` is true. That is the 500 generator.

Includes many Phase 03/05/06 facets (ERC20 retry, MultiAssetStandardVault, most weighted/curve-quad buffer and DETF facets, several DFPkgs, TwapAdapterFactory). Full list: `/tmp/rh-verify-rest/one_by_one_log.json` status `not-indexed`.

### Flatten bytecode mismatch (libraries)

`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib` and `...PullLib`: explorer accepted the job (`verification started`) but never set `is_verified`. Flatten likely diverges from linked library bytecode. Next try: Sourcify stdJsonInput (v2 fields=stdJsonInput) via instance `verification/via/standard-input`, not flatten.

### ERC20Facet

Indexed after tx open. One flatten POST returned 500. Not retried in that pass. Recheck `is_verified` first; it may already be on the explorer from an earlier killed retry.

---

## Next agent steps

1. One address at a time. Check `is_verified`, then `is_contract`, then one flatten POST.
2. Prefer the leftover `not-indexed` list. Re-open each deploy tx, wait longer if needed, submit only after index.
3. Recheck ERC20Facet before resubmitting.
4. For ClaimLib / PullLib, use standard-JSON from Foundry artifacts or Sourcify, not flatten.
5. Rewrite `verify_robinhood_main.sh` to: skip `--guess-constructor-args`, flatten, instance v2 flattened-code, gate on `is_contract`, sleep between addresses, never hammer instance `/api`.
6. Sourcify import stays unused until Blockscout wires Sourcify v2.

Diamonds at `MinimalDiamondCallBackProxy` (manager / fee collector / TWAP oracle) flatten the proxy contract `lib/crane/contracts/proxies/MinimalDiamondCallBackProxy.sol`. Same bytecode at multiple addresses; submit per address once indexed.
