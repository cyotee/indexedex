---
name: morpho-architecture
description: This skill should be used when the user asks about "Morpho architecture", "Morpho Blue", "isolated markets", "MarketParams", "MetaMorpho", "Morpho Vault V2", "Bundler3", "AdaptiveCurveIRM", "how Morpho works", or needs a high-level map of the Morpho lending stack and how pieces connect.
license: MIT
---

# Morpho Architecture

Morpho is a **permissionless isolated-market** lending stack: a Blue singleton holds markets; vaults (MetaMorpho V1.1, Vault V2) and Bundler3 sit on top for curation and UX.

## Stack map

```text
┌─────────────────────────────────────────────────────────────┐
│ End users / bots / vaults / Crane strategies                │
├──────────────┬──────────────────┬───────────────────────────┤
│ Bundler3     │ MetaMorpho V1.1  │ Vault V2 + adapters       │
│ multicall    │ ERC-4626 curator │ MarketV1 / VaultV1        │
├──────────────┴──────────────────┴───────────────────────────┤
│ Public Allocator (permissionless reallocate for vaults)     │
├─────────────────────────────────────────────────────────────┤
│ Morpho Blue singleton                                       │
│   markets = (loan, coll, oracle, irm, lltv)                 │
│   supply / collateral / borrow / repay / liquidate / flash  │
├──────────────────┬──────────────────┬───────────────────────┤
│ AdaptiveCurveIRM │ IOracle (e.g.    │ ERC-20 loan/coll      │
│ (per-market rate)│ Chainlink V2)    │                       │
└──────────────────┴──────────────────┴───────────────────────┘
```

## Core ideas

| Concept | Detail |
|---------|--------|
| **Isolated markets** | Each market is independent; no shared risk pool across unrelated pairs |
| **MarketParams** | `(loanToken, collateralToken, oracle, irm, lltv)` — identity of a market |
| **Id** | `Id = MarketParamsLib.id(params)` = keccak of encoded params |
| **Shares** | Supply and borrow use virtual-share accounting (`SharesMathLib`) |
| **Oracle scale** | Prices use `ORACLE_PRICE_SCALE = 1e36` |
| **IRM** | AdaptiveCurveIRM is bound to one Morpho address (`MORPHO` immutable) |
| **Permissionless create** | Anyone can `createMarket` if IRM + LLTV already enabled by Morpho owner |

## Blue vs vaults vs bundler

| Layer | Role | User mental model |
|-------|------|-------------------|
| **Blue** | Primitive markets | “I pick a market and supply/borrow” |
| **MetaMorpho V1.1** | Curated ERC-4626 over Blue | “I deposit loan asset; curator allocates to markets” |
| **Vault V2** | Next-gen vault + adapters | “Same product idea, adapter-based allocation” |
| **Bundler3** | Atomic multicall + adapters | “One tx: wrap, supply coll, borrow, …” |
| **Public Allocator** | Permissionless rebalance | “Anyone can reallocate within flow caps” |

## Crane placement

| Tree | Path |
|------|------|
| Vendored domain | `contracts/external/morpho/{blue,blue-irm,blue-oracles,metamorpho-v1.1,public-allocator,vault-v2,bundler3}/` |
| Crane wrappers | `contracts/protocols/lending/morpho/{blue,metamorpho,vault-v2,bundler}/` |
| Network constants | `contracts/constants/networks/*` (`MORPHO`, IRM, factories, Bundler3, …) |
| Tests | `test/foundry/spec/protocols/lending/morpho/` + `test/foundry/fork/*/morpho/` |

## Navigation

| Need | Go to |
|------|--------|
| Supply/borrow/liquidate flows | `skill:morpho-blue-operations` |
| MetaMorpho / Vault V2 / Bundler3 | `skill:morpho-vaults` |
| Crane Service, TestBase, forks | `skill:crane-morpho` |
| Addresses & market id math | `references/addresses-and-ids.md` |
| Components & data structures | `references/components.md` |

## Constraints

- Do **not** mock Morpho/MetaMorpho as SUT in Crane tests — use ported bytecode or live fork binds.
- Live AdaptiveCurveIRM only works with the Morpho instance it was constructed for.
- Matching-market fork parity compares **economic state** (local IRM vs live IRM; `irm` field in MarketParams differs).

## See also

- `skill:morpho-blue-operations`, `skill:morpho-vaults`, `skill:crane-morpho`
- `skill:crane-porting`, `skill:crane-testing`
- Plan: `docs/superpowers/plans/2026-07-27-morpho-port.md`
