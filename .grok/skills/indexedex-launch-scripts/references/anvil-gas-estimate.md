# Anvil gas / funding quote

Contents:

- When this path applies
- Anvil start flags
- Fee pin
- Forge `simulate` flags
- Funding quote
- Gold files
- What not to copy from 46630

Gold: `scripts/foundry/anvil_robinhood_main/deploy_all.sh` and
`scripts/foundry/anvil_robinhood_main/README.md`.
Human entry: `scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil`.

This path estimates **live 4663** deployer cost. It is not the 46630 local lab.

## When this path applies

Use it when the user wants a **gas estimate** or **how much ETH to fund** before a live Robinhood mainnet (4663) architecture deploy.

Do **not** use it for:

- 46630 demo / UI lab (`anvil_robinhood_testnet.sh`)
- Staged `all` broadcast on Anvil (that path may force legacy 2 gwei)
- Foundry tests

`--restart-anvil` is recommended: a long-lived Anvil node can carry a **decayed local** `baseFee` that is not the fork source.

Public Robinhood RPC is not archive. Default fork is **remote tip** (`FORK_LATEST=1`). Pin `ANVIL_FORK_BLOCK_NUMBER` only when you mean it.

If the fork RPC cannot start, **fail**. Do not fall back to a blank chain.

## Anvil start flags

From `launch_anvil` in `deploy_all.sh`:

```text
anvil
  --host 127.0.0.1
  --port 8545
  --chain-id 4663
  --fork-url <Foundry alias robinhood_mainnet>
  --compute-units-per-second 330
  --fork-retry-backoff 1000
  --disable-min-priority-fee
  --block-base-fee-per-gas <fork-source baseFee wei>
```

**EIP-170 stays on.** Do not pass `--disable-code-size-limit` to Anvil.

Do not pass `--unlocked` to Anvil itself. Localhost `forge script` adds `--unlocked` for Dev 0.

Before start, `fetch_eip1559_fees` on the **fork URL** (not Anvil):

- `cast base-fee`
- `cast gas-price`
- `cast rpc eth_maxPriorityFeePerGas`

Bound `cast` with an alarm (`cast_bounded_n`). A dead RPC must not hang the wrapper.

After Anvil is up, `sync_anvil_base_fee`:

1. `anvil_setNextBlockBaseFeePerGas` with the fork-source `baseFee`
2. `evm_mine` so `latest.baseFeePerGas` matches what Foundry reads

Chain id at `RPC_URL` must be `4663` or the wrapper exits.

Broadcast (when used) is **localhost-only**. Refuse `--broadcast` to a non-localhost `RPC_URL`.

## Forge `simulate` flags

Command: `simulate` / `stagesimulate`. Default **no** `--broadcast` unless `--broadcast` is explicit.

`forge_script_base` for simulate:

```text
forge script Script_SimulateArchitecture.s.sol
  --rpc-url http://127.0.0.1:8545
  --sender $SENDER
  --unlocked                          # localhost only
  --priority-gas-price $FEE_PRIORITY_WEI   # from live eth_maxPriorityFeePerGas, if numeric
```

Never `--legacy`. Never `--gas-price`.
Unset `ETH_GAS_PRICE` and `ETH_PRIORITY_GAS_PRICE` in the simulate process so a pinned max-fee does not leak in.

Do **not** pass `--disable-code-size-limit` to `forge script` on this path.

The Solidity script wraps the txs to quote in **one** `startBroadcast` / `stopBroadcast` window so one dry-run JSON exists:

`scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol`

It calls Stage **libraries** `execute()` (Phases 02–06 architecture catalog). No tokens. No DETF instances.
Do not run after a completed staged `all` on the same Anvil (CREATE3 / CREATE2 collision).

Staged `all` on this tree is a **different** path: it still simulates then broadcasts, and on localhost it appends `--legacy --gas-price 2000000000` plus `--slow --gas-estimate-multiplier 300`. That is an Anvil `feeHistory` workaround, **not** the funding quote.

## Funding quote

After a dry-run `simulate`, `quote_simulate_funding`:

1. Read `broadcast/Script_SimulateArchitecture.s.sol/4663/dry-run/run-latest.json`.
2. Sum inner `transaction.gas` over `transactions` (hex or decimal). These are Foundry **gas limits**; used gas will be lower.
3. **Re-read** live fork-source `baseFee` / `maxPriorityFeePerGas` / `eth_gasPrice` (Anvil local fees are not used).
4. `cost = gas_limit_sum * eth_gasPrice` (fallback `baseFee + priority` if `eth_gasPrice` is 0).
5. `fund = cost * (10000 + FUND_ETH_BUFFER_BPS) / 10000` (default 2500 = 25%).

Log txs, gas-limit sum, expected spend, recommended fund amount.
**Fund from this quote, not Foundry’s on-screen ETH total.** Anvil’s local fee market can still diverge even after the baseFee pin.

## Gold files (copy these, do not restate flags in a new wrapper)

| Piece | Function / file |
|-------|-----------------|
| Fee fetch | `fetch_eip1559_fees` |
| Anvil argv | `launch_anvil` |
| Pin next baseFee | `sync_anvil_base_fee`, `prepare_simulate_fees` |
| Forge argv | `forge_script_base`, `run_stage` (`is_simulate_command`) |
| Quote | `sum_dry_run_gas_limits`, `quote_simulate_funding` |
| Solidity window | `Script_SimulateArchitecture.s.sol` |

A later shared `scripts/shell/lib/anvil_eip1559.sh` is optional. Until it exists, **copy from this tree**, do not invent a third flag set.

## What not to copy from 46630

| 46630 lab | 4663 quote |
|-----------|------------|
| `--disable-code-size-limit` on Anvil and forge | **Forbidden** |
| `--non-interactive` | Fine if not a TTY; not a fee flag |
| Per-Stage simulate then broadcast as `all` | Use `simulate` for the quote |
| Rehearsal `new UniswapV3Factory` | 4663 pins live V3 if the architecture needs it; this architecture tree does not deploy V3 |
| Foundry “Estimated amount required” | Ignore for funding |

46630 does not yet have a `simulate` quote command. Do not add one unless the 46630 PRD/plan is amended. If added, it must follow **this** Anvil/fee law (EIP-170 on, live fees), which **conflicts** with 46630’s V3 rehearsal codesize cheat. A 46630 funding quote would have to exclude oversized rehearsal deploys or run on a tree that does not deploy them.
