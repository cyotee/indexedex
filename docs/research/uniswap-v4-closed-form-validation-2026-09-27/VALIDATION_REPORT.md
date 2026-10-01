# Closed-form validation report

Date: 2026-09-27. No candidate is recommended for adoption.

## Commands

```bash
python3 research/uniswap-v4-closed-form-validation/regenerate.py
forge test --match-path test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol -vv
```

Python wrote `research/uniswap-v4-closed-form-validation/counterexamples/summary.json`.

Forge compiled 9 files with solc 0.8.35 in 31.96 seconds, optimizer settings unchanged, `via_ir` not enabled. Result: **5 passed, 0 failed**.

## What passed

- Production `SwapMath.computeSwapStep` matches the Python vector: input 23,029, output 22,510, fee 70, at the 0.30% candidate root.
- That same production step leaves a 2 bp inventory-ratio error. The accepted alignment bound is 1 bp.
- A 25 bp price cap is exact on production price math (`0.0025e18`). The capped swap reduces mismatch from 1,840 bp to 1,747 bp and does not finish repair.
- Production `_singleExit` refutes CF-B on `(reserve=50, output=12, supply=100)`.
- `floor(120 * 0.2e18 / 1.2e18) = 20`. The old percent-of-total formula returns 24.

## What was not run

No registry-deployed FullSpread proxy test. No PoolManager unlock sequence. No fork. Those gaps block `ADOPTABLE_WITHIN_DOMAIN`; they do not revive a candidate already refuted by production math.

## Compiler

`foundry.toml` remains solc 0.8.35, optimizer runs 1, `via_ir = false`. The first test draft hit stack-too-deep. It was split into helpers. via-IR was not enabled.
