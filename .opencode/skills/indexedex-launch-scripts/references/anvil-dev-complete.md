# Dev-complete Anvil (local lab)

Contents:

- When EIP-170 may be off
- 46630 Anvil and forge flags
- Staged simulate then broadcast
- Public shell
- 4663 staged `all` vs `simulate`
- What this path is not

Gold: `scripts/shell/anvil_robinhood_testnet.sh`, `scripts/shell/robinhood_testnet.sh`,
`scripts/shell/lib/rh_46630_stages.sh`, `scripts/foundry/anvil_robinhood_testnet/README.md`.

This path stands up a **local fork lab** (or public testnet Stages). It is **not** a live
mainnet funding quote. See [anvil-gas-estimate.md](anvil-gas-estimate.md) for that.

## When EIP-170 may be off

`--disable-code-size-limit` is allowed only when a **rehearsal** contract on this chain
exceeds 24kb and the product still needs that bytecode locally.

On 46630 that contract is rehearsal `UniswapV3Factory` (`Phase_01_Stage_04`).
Pass the flag on **both** the Anvil node **and** `forge script` (Foundry also enforces EIP-170
during simulation).

Do **not** pass it on:

- 4663 gas / funding `simulate`
- any chain whose launch is pin-only for that bytecode
- hermetic `forge test` (not this skill)

`--disable-block-gas-limit` appears only on the 46630 **offline** Anvil path
(`launch_anvil_offline` after `anvil_dumpState`). Do not use it on a live-fork gas quote.

## 46630 Anvil and forge flags

Anvil (`launch_anvil`):

```text
anvil
  --host 127.0.0.1
  --port 8545
  --chain-id 46630
  --fork-url <robinhood_testnet_alchemy, fallback robinhood_testnet>
  --compute-units-per-second …
  --fork-retry-backoff …
  --disable-code-size-limit
  [--fork-block-number …]   # public RPC is not archive; wrapper may pin head-lag
```

Forge (Anvil shell `forge_script_base`):

```text
forge script Phase_<PP>_Stage_<SS>_*.s.sol
  --rpc-url http://127.0.0.1:8545
  --sender <Anvil Dev 0>
  --unlocked
  --disable-code-size-limit
  --non-interactive
```

Then, if not `--dry-run`: `--broadcast`. Never `--skip-simulation`.

`--non-interactive` avoids `IO error: not a terminal` under agent/CI `tee`.

Signer is Anvil Dev 0 (`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`).
`--live` on the **Anvil** shell is rejected; use `scripts/shell/robinhood_testnet.sh`.

Fork 46630 **always**. No blank-chain Anvil for this tree.

## Staged simulate then broadcast

`rh_run_catalog` runs each catalog row: simulate the Stage, then broadcast.
Skip-if-JSON-valid happens **inside** the Stage (`_shouldSkipStage`). A skip still
rewrites JSON and typically prints `No transactions to broadcast`.

Resume: `--from-phase PP --from-stage SS` (decimal, not octal).
`FORCE=1` / `--force` re-runs (purge JSON when restarting Anvil).

Phase 00 is Anvil-only. Public catalog starts at 01.

## Public shell

`scripts/shell/robinhood_testnet.sh`:

- Requires `DEPLOYER_ADDRESS`
- `--sender $DEPLOYER_ADDRESS` (cast wallet). No `--unlocked`
- No Phase 00
- Currently Phases 01–09. Comment in the shell: public subset is **not locked**
- Still simulate then broadcast. Never `--skip-simulation`
- `--non-interactive`

Do not broadcast the 46630 tree to 4663. Do not overwrite `frontend/.../chain/4663/`.

## 4663 staged `all` vs `simulate`

`anvil_robinhood_main.sh all --restart-anvil` is a **dev-complete** architecture deploy
on a 4663 fork: EIP-170 **on**, localhost broadcast, and `--legacy --gas-price 2gwei` on
broadcast as an Anvil `feeHistory` workaround.

That `all` path is **not** the funding quote. The quote is `simulate --restart-anvil`
with EIP-1559 and live fork-source fees.

Do not “fix” 4663 `simulate` by copying 46630 `--disable-code-size-limit`.
Do not “fix” 46630 V3 rehearsal by removing that flag without another way to deploy
the oversized factory.

## What this path is not

- Not a live 4663 ETH funding number
- Not permission to `new` facets/DFPkgs
- Not permission to `createMarket` or deploy Morpho / Uni V3 SE **instances**
- Not a second `Script_SimulateLaunch` deploy orchestrator
