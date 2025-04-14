# Balancer V3 Pool Workflows with Camelot V2 LP Tokens

This document summarizes the workflows for swapping, adding liquidity, and removing liquidity in a custom Balancer V3 pool composing Camelot V2 LP tokens, as outlined in the Product Requirements Document (PRD). Each workflow details the sequence of steps, including hook calls, pool functions, and alignment with PRD design requirements (e.g., routing swaps via Camelot V2, supporting ZapIn/ZapOut, and yield fee collection). Workflows cover both single-hop and multi-hop operations.

## PRD Specifications

- The pool holds only Camelot V2 LP tokens, with tokens A, B, LP, and BPT registered
- Swaps (A ↔ B, A/B ↔ LP, LP ↔ BPT) route through Camelot V2 via the Camelot Router, with no additional swap fees
- Liquidity operations support proportional joins/exits and ZapIn (A or B → BPT) and ZapOut (BPT → A or B) using `AddLiquidityKind.CUSTOM` and `RemoveLiquidityKind.CUSTOM`
- Hooks manage routing and yield fee collection
- Multi-hop swaps enable ZapIn (A → LP → BPT) and ZapOut (BPT → LP → A/B)

## 1. Single-Hop Swap (A ↔ B, A/B ↔ LP, LP ↔ BPT)

### Description
A single-hop swap exchanges one token for another, routed through the Camelot V2 LP using the Camelot Router.

### Steps

#### Vault Validation
- The Vault's swap function validates the pool's state (initialized, not paused) and swap inputs (non-zero amount, distinct tokens)
- **PRD Alignment:** Ensures secure and robust operation

#### Before Swap Hook (`onBeforeSwap`)
- If `shouldCallBeforeSwap` is true, the Vault calls `onBeforeSwap` in `CamelotHooks.sol`
- Validates swap parameters (e.g., tokens are A, B, LP, or BPT) and optionally checks Camelot V2 reserves
- Returns true to proceed or reverts if invalid
- **PRD Alignment:** Ensures only valid swap pairs are processed

#### Pool Swap Calculation (`onSwap`)
- The Vault calls `onSwap` in `CamelotComposedPool.sol`
- Computes the output amount (`amountCalculatedScaled18`) using Camelot V2 reserves:
  - A ↔ B: Based on LP reserves (mocked or cached)
  - A/B ↔ LP: ZapIn (A → LP) or ZapOut (LP → A)
  - LP ↔ BPT: BPT swap amounts (if tradable)
- Vault updates deltas, applies zero swap fees, and emits a `Swap` event
- **PRD Alignment:** Computes amounts view-only, leveraging Camelot V2 pricing

#### After Swap Hook (`onAfterSwap`)
- If `shouldCallAfterSwap` is true, the Vault calls `onAfterSwap`
- Routes the swap via Camelot V2:
  - A ↔ B: Transfers tokenIn (A) to Camelot Router, swaps to tokenOut (B)
  - A/B ↔ LP: Transfers A to LP or burns LP to A/B
  - LP ↔ BPT: Converts LP to BPT or vice versa
- Returns true and optionally adjusted amounts
- **PRD Alignment:** Routes swaps through Camelot V2, supports ZapIn/ZapOut

#### Delta Settlement
- The Vault settles all token deltas
- **PRD Alignment:** Ensures secure transaction completion

### PRD Design Components
- **Swap Routing:** Handled by `onAfterSwap` via Camelot Router
- **Zero Swap Fees:** Enforced with `staticSwapFeePercentage = 0`
- **ZapIn/ZapOut:** Supported for A/B ↔ LP and LP ↔ BPT
- **Validation:** Managed by `onBeforeSwap`

## 2. Multi-Hop Swap (ZapIn: A → LP → BPT, ZapOut: BPT → LP → A/B)

### Description
Multi-hop swaps chain single-hop swaps via the Balancer Router's `batchSwap` to enable ZapIn (A → BPT) or ZapOut (BPT → A/B).

### Steps

#### Batch Swap Setup
- The Balancer Router's `batchSwap` processes a sequence of swaps
- **PRD Alignment:** Enables multi-hop operations

#### First Hop (e.g., A → LP)
Follows single-hop workflow:
- Vault Validation: Checks pool state
- Before Swap Hook: Validates A → LP
- Pool Swap Calculation: Computes LP output
- After Swap Hook: Routes A to LP via Camelot Router
- **PRD Alignment:** Implements ZapIn's first step

#### Second Hop (e.g., LP → BPT)
Follows single-hop workflow:
- Vault Validation: Checks pool state
- Before Swap Hook: Validates LP → BPT
- Pool Swap Calculation: Computes BPT output
- After Swap Hook: Converts LP to BPT
- **PRD Alignment:** Completes ZapIn

#### ZapOut (BPT → LP → A/B)
- First Hop (BPT → LP): Computes LP output, converts BPT to LP
- Second Hop (LP → A): Burns LP to A/B, outputs A
- **PRD Alignment:** Implements ZapOut

#### Batch Settlement
- Ensures all deltas settle
- **PRD Alignment:** Secures multi-hop execution

### PRD Design Components
- **Multi-Hop Support:** Enabled by `batchSwap`
- **Routing:** Each hop routed via Camelot V2 in `onAfterSwap`
- **BPT Trading:** Requires BPT registration
- **Validation:** Ensured by `onBeforeSwap`

## 3. Add Liquidity (Proportional, ZapIn)

### Description
Adds liquidity to the pool, supporting proportional joins (A and B or LP) and ZapIn (A or B → BPT) using `AddLiquidityKind.CUSTOM`.

### Steps

#### Vault Validation
- The Vault's `addLiquidity` function validates the pool and inputs
- **PRD Alignment:** Supports custom liquidity

#### Before Add Liquidity Hook (`onBeforeAddLiquidity`)
- If `shouldCallBeforeAddLiquidity` is true, validates CUSTOM kind, subKind (0-3), and amounts
- Returns true to proceed
- **PRD Alignment:** Ensures valid inputs

#### Pool Liquidity Calculation (`onAddLiquidityCustom`)
- The Vault calls `onAddLiquidityCustom` in `CamelotComposedPool.sol`
- Computes LP and BPT amounts:
  - subKind=0 (A and B): Converts A and B to LP via Camelot Router
  - subKind=1 (LP): Proportional BPT for LP
  - subKind=2 (ZapIn A): Swaps A to LP, computes BPT
  - subKind=3 (ZapIn B): Swaps B to LP, computes BPT
- Vault mints BPT and updates balances
- **PRD Alignment:** Supports proportional joins and ZapIn

#### After Add Liquidity Hook (`onAfterAddLiquidity`)
- If `shouldCallAfterAddLiquidity` is true, calculates yield fees based on LP reserve growth and updates reserves
- **PRD Alignment:** Implements yield fee collection

#### Delta Settlement
- Ensures all deltas settle
- **PRD Alignment:** Secures completion

### PRD Design Components
- **Proportional Joins:** Supports A and B or LP inputs
- **ZapIn:** Handles A or B → BPT
- **Yield Fees:** Collected in `onAfterAddLiquidity`
- **Routing:** Uses Camelot Router

## 4. Remove Liquidity (Proportional, ZapOut)

### Description
Removes liquidity, supporting proportional exits (A and B or LP) and ZapOut (BPT → A or B) using `RemoveLiquidityKind.CUSTOM`.

### Steps

#### Vault Validation
- The Vault's `removeLiquidity` function validates inputs
- **PRD Alignment:** Supports custom removal

#### Before Remove Liquidity Hook (`onBeforeRemoveLiquidity`)
- If `shouldCallBeforeRemoveLiquidity` is true, validates CUSTOM kind, subKind (0-3), and BPT amount
- **PRD Alignment:** Ensures valid inputs

#### Pool Liquidity Calculation (`onRemoveLiquidityCustom`)
- The Vault calls `onRemoveLiquidityCustom`
- Computes outputs:
  - subKind=0 (A and B): Burns LP to A and B
  - subKind=1 (LP): Returns proportional LP
  - subKind=2 (ZapOut A): Burns LP, swaps to A
  - subKind=3 (ZapOut B): Burns LP, swaps to B
- Vault burns BPT and updates balances
- **PRD Alignment:** Supports proportional exits and ZapOut

#### After Remove Liquidity Hook (`onAfterRemoveLiquidity`)
- If `shouldCallAfterRemoveLiquidity` is true, calculates yield fees and updates reserves
- **PRD Alignment:** Implements yield fee collection

#### Delta Settlement
- Ensures all deltas settle
- **PRD Alignment:** Secures completion

### PRD Design Components
- **Proportional Exits:** Supports A and B or LP outputs
- **ZapOut:** Handles BPT → A/B
- **Yield Fees:** Collected in `onAfterRemoveLiquidity`
- **Routing:** Uses Camelot Router

## Complete Token Routes and Operations Table

### Swap Operations

| Operation Type | Route | Hops | Functions Involved | Steps in Order |
|---------------|-------|------|-------------------|----------------|
| Swap (Single-Hop) | A ↔ B | 1 | `onBeforeSwap`, `onSwap`, `onAfterSwap` | 1. Vault validates swap<br>2. `onBeforeSwap` validates pair<br>3. `onSwap` computes output<br>4. `onAfterSwap` routes via Camelot V2 |
| | A/B ↔ LP | 1 | `onBeforeSwap`, `onSwap`, `onAfterSwap` | 1. Vault validates swap<br>2. `onBeforeSwap` validates pair<br>3. `onSwap` computes output<br>4. `onAfterSwap` routes via Camelot V2 |
| | LP ↔ BPT | 1 | `onBeforeSwap`, `onSwap`, `onAfterSwap` | 1. Vault validates swap<br>2. `onBeforeSwap` validates pair<br>3. `onSwap` computes output<br>4. `onAfterSwap` converts LP/BPT |
| Swap (Multi-Hop) | A → LP → BPT | 2 | `batchSwap`, `onBeforeSwap`, `onSwap`, `onAfterSwap` (per hop) | 1. Vault processes `batchSwap`<br>2. For each hop: `onBeforeSwap` validates, `onSwap` computes, `onAfterSwap` routes |
| | BPT → LP → A | 2 | `batchSwap`, `onBeforeSwap`, `onSwap`, `onAfterSwap` (per hop) | 1. Vault processes `batchSwap`<br>2. For each hop: `onBeforeSwap` validates, `onSwap` computes, `onAfterSwap` routes |

### Liquidity Operations

| Operation | Route | Hops | Functions Involved | Steps in Order |
|-----------|-------|------|-------------------|----------------|
| Add Liquidity | A and B → LP → BPT (subKind=0) | 2 | `onBeforeAddLiquidity`, `onAddLiquidityCustom`, `onAfterAddLiquidity` | 1. Vault validates operation<br>2. `onBeforeAddLiquidity` validates inputs<br>3. `onAddLiquidityCustom` converts A/B to LP via Camelot V2, mints BPT<br>4. `onAfterAddLiquidity` collects fees, updates reserves |
| | LP → BPT (subKind=1) | 1 | `onBeforeAddLiquidity`, `onAddLiquidityCustom`, `onAfterAddLiquidity` | 1. Vault validates operation<br>2. `onBeforeAddLiquidity` validates inputs<br>3. `onAddLiquidityCustom` mints BPT<br>4. `onAfterAddLiquidity` collects fees, updates reserves |
| | A → LP → BPT (subKind=2) | 2 | `onBeforeAddLiquidity`, `onAddLiquidityCustom`, `onAfterAddLiquidity` | 1. Vault validates operation<br>2. `onBeforeAddLiquidity` validates inputs<br>3. `onAddLiquidityCustom` swaps A to LP via Camelot V2, mints BPT<br>4. `onAfterAddLiquidity` collects fees, updates reserves |
| | B → LP → BPT (subKind=3) | 2 | `onBeforeAddLiquidity`, `onAddLiquidityCustom`, `onAfterAddLiquidity` | 1. Vault validates operation<br>2. `onBeforeAddLiquidity` validates inputs<br>3. `onAddLiquidityCustom` swaps B to LP via Camelot V2, mints BPT<br>4. `onAfterAddLiquidity` collects fees, updates reserves |
| Remove Liquidity | BPT → LP → A and B (subKind=0) | 2 | `onBeforeRemoveLiquidity`, `onRemoveLiquidityCustom`, `onAfterRemoveLiquidity` | 1. Vault validates operation<br>2. `onBeforeRemoveLiquidity` validates inputs<br>3. `onRemoveLiquidityCustom` burns BPT to LP, LP to A/B via Camelot V2<br>4. `onAfterRemoveLiquidity` collects fees, updates reserves |
| | BPT → LP (subKind=1) | 1 | `onBeforeRemoveLiquidity`, `onRemoveLiquidityCustom`, `onAfterRemoveLiquidity` | 1. Vault validates operation<br>2. `onBeforeRemoveLiquidity` validates inputs<br>3. `onRemoveLiquidityCustom` burns BPT to LP<br>4. `onAfterRemoveLiquidity` collects fees, updates reserves |
| | BPT → LP → A (subKind=2) | 2 | `onBeforeRemoveLiquidity`, `onRemoveLiquidityCustom`, `onAfterRemoveLiquidity` | 1. Vault validates operation<br>2. `onBeforeRemoveLiquidity` validates inputs<br>3. `onRemoveLiquidityCustom` burns BPT to LP, LP to A via Camelot V2<br>4. `onAfterRemoveLiquidity` collects fees, updates reserves |
| | BPT → LP → B (subKind=3) | 2 | `onBeforeRemoveLiquidity`, `onRemoveLiquidityCustom`, `onAfterRemoveLiquidity` | 1. Vault validates operation<br>2. `onBeforeRemoveLiquidity` validates inputs<br>3. `onRemoveLiquidityCustom` burns BPT to LP, LP to B via Camelot V2<br>4. `onAfterRemoveLiquidity` collects fees, updates reserves |

## Summary Table

| Operation | Key Steps | PRD Design Components |
|-----------|-----------|---------------------|
| Single-Hop Swap | Vault Validation, `onBeforeSwap`, `onSwap`, `onAfterSwap`, Delta Settlement | Routing via Camelot V2, zero fees, ZapIn/ZapOut |
| Multi-Hop Swap | Batch Setup, First Hop (e.g., A → LP), Second Hop (e.g., LP → BPT), Settlement | Multi-hop ZapIn/ZapOut, Camelot V2 routing |
| Add Liquidity | Vault Validation, `onBeforeAddLiquidity`, `onAddLiquidityCustom`, `onAfterAddLiquidity`, Settlement | Proportional joins, ZapIn, yield fees, routing |
| Remove Liquidity | Vault Validation, `onBeforeRemoveLiquidity`, `onRemoveLiquidityCustom`, `onAfterRemoveLiquidity`, Settlement | Proportional exits, ZapOut, yield fees, routing |

## Additional Notes

- **Yield Fees:** Collected in `onAfterAddLiquidity` and `onAfterRemoveLiquidity` using cached reserves, updated by keepers
- **Camelot V2 Integration:** All operations route through the Camelot Router
- **Security:** Vault validations and hooks ensure robust execution

This document provides a clear, concise reference for understanding and implementing the pool's workflows, ensuring alignment with the PRD. 🔄
