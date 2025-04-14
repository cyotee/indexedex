# IndexedEx Base Mainnet Fork Test Plan

**Status**: COMPLETE
**Last updated**: 2026-01-06
**Fork block**: 40,446,736 (pinned for reproducibility)

## Purpose

Validate IndexedEx protocol integrations against **live Base mainnet infrastructure** using **Foundry fork tests**.

- Chain: Base Mainnet (`chainid = 8453`)
- RPC endpoint name: `base_mainnet_infura` (configured in `foundry.toml`)
- Address source of truth: `@crane/contracts/constants/networks/BASE_MAIN.sol`

This plan is **fork-only**: it intentionally does not track unit tests, local integration tests, or architectural notes.

## Current Test Summary

| Suite | Tests | Status |
|-------|-------|--------|
| TestBase_BaseFork | 1 | PASS |
| TestBase_AerodromeFork | 2 | PASS |
| AerodromeFork_Swap | 28 | PASS |
| AerodromeFork_VaultDeposit | 14 | PASS |
| AerodromeFork_VaultWithdraw | 14 | PASS |
| AerodromeFork_ZapIn | 19 | PASS |
| AerodromeFork_ZapInDeposit | 16 | PASS |
| AerodromeFork_ZapOut | 19 | PASS |
| AerodromeFork_ZapOutWithdraw | 16 | PASS |
| AerodromeFork_IStandardExchangeIn | 12 | PASS |
| TestBase_BalancerV3Fork | 2 | PASS |
| BalancerV3Fork_DirectSwap | 16 | PASS |
| BalancerV3Fork_BatchExactIn | 9 | PASS |
| BalancerV3Fork_BatchExactOut | 9 | PASS |
| BalancerV3Fork_VaultDeposit | 11 | PASS |
| BalancerV3Fork_VaultWithdrawal | 12 | PASS |
| BalancerV3Fork_VaultPassThrough | 12 | PASS |
| BalancerV3Fork_Prepay | 12 | PASS |
| BalancerV3Fork_Prepay_LockedCaller | 3 | PASS |
| TestBase_SeigniorageFork | 2 | PASS |
| SeigniorageFork_NFTVault | 27 | PASS |
| SeigniorageFork_DETFIntegration | 3 | PASS |
| SeigniorageFork_DETFExchangeRoutes | 2 | PASS |
| **Total** | **261** | **ALL PASS** |

## Known Issues

### Balancer V3 Batch Router - Query Pretransfer Workaround

**Status**: RESOLVED

Previously, `BalancerV3Fork_BatchExactIn.t.sol` and `BalancerV3Fork_BatchExactOut.t.sol` used a workaround that
pre-transferred tokens into the Balancer V3 Vault before calling the batch router query functions.
Without that workaround, queries reverted with `BalanceNotSettled()`.

**Resolution**:
- Batch router query hooks now settle transient deltas (same as execution), so Balancer's transient accounting
	invariant is satisfied during simulated execution-style queries.
- Fork tests were updated to remove the obsolete `token.transfer(address(vault), ...)` pretransfer.

**Verification**:
- `forge test --match-path "test/foundry/fork/base_main/balancer/v3/BalancerV3Fork_BatchExact*.t.sol" -vvv`

### Balancer V3 Prepay - Live Revert Reason Differences

**Status**: EXPECTED

Some prepay routes enforce call-path restrictions via reverts. On a Base mainnet fork, the **live** Balancer V3 vault/router bytecode can return different revert reasons than our spec expectations.

**Current approach**:
- Fork tests assert **generic revert** (not exact custom errors) for direct-call / invalid-call-path cases.

## Prerequisites

- Set `INFURA_KEY` in your environment.
- Confirm the fork endpoint works:
	- `forge test --match-path "test/foundry/fork/base_main/**" -vvv`

Optional reproducibility:
- Set `BASE_FORK_BLOCK=<blockNumber>` to pin tests (currently: 40,446,736).

## Fork Test Philosophy

Coverage rule (enforced in-repo):

- Any operation that interacts with **Balancer V3** and/or **Aerodrome** must have a **Base mainnet fork test mirror**.

We want to prove our contracts work with **real deployed external contracts** on Base, while keeping tests deterministic and self-contained.

- Use **mainnet contracts** for:
	- Aerodrome Router + Factory
	- Balancer V3 Vault + Router + Weighted Pool Factory
	- Permit2 (canonical: 0x000000000022D473030F116dDEE9F6B43aC78BA3)
- Use **locally deployed test tokens** for pools and swaps.
- Never deploy contracts with `new` in this repo; use the CREATE3 factory patterns.

## Target Folder Layout

All fork tests live under:

```
test/foundry/fork/base_main/
├── TestBase_BaseFork.sol
├── aerodrome/
│   ├── TestBase_AerodromeFork.sol
│   ├── AerodromeFork_Swap.t.sol
│   ├── AerodromeFork_VaultDeposit.t.sol
│   ├── AerodromeFork_VaultWithdraw.t.sol
│   ├── AerodromeFork_ZapIn.t.sol
│   ├── AerodromeFork_ZapInDeposit.t.sol
│   ├── AerodromeFork_ZapOut.t.sol
│   ├── AerodromeFork_ZapOutWithdraw.t.sol
│   └── AerodromeFork_IStandardExchangeIn.t.sol
├── balancer/v3/
│   ├── TestBase_BalancerV3Fork.sol
│   ├── TestBase_BalancerV3Fork_StrategyVault.sol
│   ├── BalancerV3Fork_DirectSwap.t.sol
│   ├── BalancerV3Fork_BatchExactIn.t.sol
│   ├── BalancerV3Fork_BatchExactOut.t.sol
│   ├── BalancerV3Fork_VaultDeposit.t.sol
│   ├── BalancerV3Fork_VaultWithdrawal.t.sol
│   ├── BalancerV3Fork_VaultPassThrough.t.sol
│   ├── BalancerV3Fork_Prepay.t.sol
│   └── BalancerV3Fork_Prepay_LockedCaller.t.sol
└── seigniorage/
    ├── TestBase_SeigniorageFork.sol
	├── TestBase_SeigniorageDETF_Fork.sol
	├── SeigniorageFork_NFTVault.t.sol
	├── SeigniorageFork_DETFIntegration.t.sol
	└── SeigniorageFork_DETFExchangeRoutes.t.sol
```

## Phase 1 — Core Fork Infrastructure

**Status**: COMPLETE

### Implement `TestBase_BaseFork.sol`

Minimum requirements:

- Fork selection:
	- `vm.createSelectFork("base_mainnet_infura")`
	- If `BASE_FORK_BLOCK` is set, select that block.
- Assert `block.chainid == 8453`.
- Provide helper(s):
	- `_hasCode(address) -> bool` (e.g., `addr.code.length > 0`)
	- `_labelBaseMainAddresses()` (optional but helpful)

Sanity expectations (checked in `setUp()` or a dedicated sanity test):

- `BASE_MAIN.AERODROME_ROUTER` has code
- `BASE_MAIN.AERODROME_POOL_FACTORY` has code
- `BASE_MAIN.BALANCER_V3_VAULT` has code
- `BASE_MAIN.BALANCER_V3_ROUTER` has code
- `BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY` has code

## Phase 2 — Aerodrome Fork Suite

**Status**: COMPLETE (140 tests passing)

### Implement `TestBase_AerodromeFork.sol`

Use onchain addresses from `BASE_MAIN`:

- `BASE_MAIN.AERODROME_ROUTER`
- `BASE_MAIN.AERODROME_POOL_FACTORY`

Setup pattern:

- Deploy local `ERC20PermitMintableStub` tokens.
- Create pools using the **mainnet factory** with different configurations:
  - Balanced pool (50/50 liquidity)
  - Unbalanced pool (80/20 liquidity)
  - Extreme pool (95/5 liquidity)
- Seed liquidity using the **mainnet router**.
- Deploy the Aerodrome StandardExchange vault using canonical deployment patterns.

### Fork Tests Created

| Test File | Description | Tests |
|-----------|-------------|-------|
| `AerodromeFork_Swap.t.sol` | Route 1: Token-to-token swaps | 28 |
| `AerodromeFork_VaultDeposit.t.sol` | Route 4: LP to vault shares | 14 |
| `AerodromeFork_VaultWithdraw.t.sol` | Route 5: Vault shares to LP | 14 |
| `AerodromeFork_ZapIn.t.sol` | Route 2: Token to LP | 19 |
| `AerodromeFork_ZapInDeposit.t.sol` | Route 6: Token to vault shares | 16 |
| `AerodromeFork_ZapOut.t.sol` | Route 3: LP to token | 19 |
| `AerodromeFork_ZapOutWithdraw.t.sol` | Route 7: Vault shares to token | 16 |
| `AerodromeFork_IStandardExchangeIn.t.sol` | Interface compliance | 12 |

Run:

```bash
forge test --match-path "test/foundry/fork/base_main/aerodrome/**" -vvv
```

## Phase 3 — Balancer V3 Fork Suite

**Status**: COMPLETE (86 tests passing)

### Implement `TestBase_BalancerV3Fork.sol`

Use onchain addresses from `BASE_MAIN`:

- `BASE_MAIN.BALANCER_V3_VAULT`
- `BASE_MAIN.BALANCER_V3_ROUTER`
- `BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY`
- `BASE_MAIN.PERMIT2` (0x000000000022D473030F116dDEE9F6B43aC78BA3)

Setup pattern:

- Deploy local `ERC20PermitMintableStub` tokens.
- Create a weighted pool using the **mainnet weighted pool factory**.
- Use the **mainnet vault/router** for all swaps & vault interactions.
- Deploy the Balancer V3 StandardExchange router/vault integration using canonical patterns.
- Configure Permit2 approvals for batch router operations.

### Fork Tests Created

| Test File | Description | Tests |
|-----------|-------------|-------|
| `BalancerV3Fork_DirectSwap.t.sol` | Direct pool swaps via Vault | 16 |
| `BalancerV3Fork_BatchExactIn.t.sol` | Batch router ExactIn operations | 9 |
| `BalancerV3Fork_BatchExactOut.t.sol` | Batch router ExactOut operations | 9 |
| `BalancerV3Fork_VaultDeposit.t.sol` | Route: Vault deposit | 11 |
| `BalancerV3Fork_VaultWithdrawal.t.sol` | Route: Vault withdrawal | 12 |
| `BalancerV3Fork_VaultPassThrough.t.sol` | Route: Vault passthrough | 12 |
| `BalancerV3Fork_Prepay.t.sol` | Prepay pool initialization & liquidity | 12 |
| `BalancerV3Fork_Prepay_LockedCaller.t.sol` | Prepay locked-caller restrictions | 3 |

Note: Strategy-vault dependent routes are exercised via `TestBase_BalancerV3Fork_StrategyVault.sol`, which deploys a fork-local Aerodrome-backed strategy vault during setup.

Run:

```bash
forge test --match-path "test/foundry/fork/base_main/balancer/**" -vvv
```

## Phase 4 — Seigniorage / DETF Fork Suite

**Status**: COMPLETE (34 tests passing)

### Goal

Prove the Seigniorage "DETF" system operates correctly against **live** Base Aerodrome + Balancer V3 deployments.

Reference (existing non-fork tests, for patterns only):

- `test/foundry/spec/protocol/vaults/seigniorage/`

### Implement `TestBase_SeigniorageFork.sol`

Must do:

- Reuse the Base fork infrastructure (inherit `TestBase_BaseFork`).
- Build a reserve vault against a fork-created Aerodrome pool (same approach as Aerodrome fork suite).
- Build the DETF reserve pool using the **mainnet Balancer V3 weighted pool factory**.
- Deploy Seigniorage components via CREATE3 patterns for production contracts (test-only stubs may still use `new` where appropriate).
- Register the package and deploy via the manager `deployVault(...)` path.

Implementation note:

- Seigniorage DETF fork suites use `TestBase_SeigniorageDETF_Fork.sol` which wires a full DETF instance to live Base Balancer V3 + a fork-created Aerodrome reserve vault.
- Fork reality constraints handled in tests:
	- Balancer weighted pools may revert large swaps due to MaxInRatio; tests use chunked swaps.
	- Below-peg transitions are driven deterministically via bounded repeated dumps.

### Fork Tests Created

| Test File | Description | Tests |
|-----------|-------------|-------|
| `SeigniorageFork_NFTVault.t.sol` | NFT vault underwrite/redeem operations | 27 |
| `SeigniorageFork_DETFIntegration.t.sol` | DETF deployment & underwriting | 3 |
| `SeigniorageFork_DETFExchangeRoutes.t.sol` | DETF exchange-in behavior (above/below peg) | 2 |

Run:

```bash
forge test --match-path "test/foundry/fork/base_main/seigniorage/**" -vvv
```

## Common Commands

```bash
# Run all Base fork tests
forge test --match-path "test/foundry/fork/base_main/**" -vvv

# Run all Base fork tests pinned to a specific block
BASE_FORK_BLOCK=40446736 forge test --match-path "test/foundry/fork/base_main/**" -vvv

# Run with summary output
forge test --match-path "test/foundry/fork/base_main/**" --summary
```

## Success Criteria

- Fork suites pass when run against Base mainnet.
- External dependency calls succeed (no ABI/selector mismatch).
- No unexpected token retention (where applicable).
- Preview functions match execution results.

## Future Work

1. **Resolve Balancer V3 batch query pretransfer bug** - Investigate why queries require token settlement
2. **Add UniswapV2 fork tests** - If spec tests exist for UniswapV2 integration
