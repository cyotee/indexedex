# Nested Liquidity Pools with Balancer V3 Dual Constant Product Pools

This document describes a DeFi system integrating an external Constant Product DEX liquidity pool into a Strategy Vault, wrapped in an ERC4626 vault token, and managed by a Balancer V3 SV Conversion Pool and two Constant Product pools with a Rate Provider.

## Explanation

### External Constant Product DEX LP Token
A Constant Product liquidity pool, as used in DEXes like Uniswap V2 or Camelot, holds a pair of tokens (Token A and Token B) and facilitates trading using the constant product formula (`x * y = k`). The pool issues an LP token, denoted `ConstProd_A_B`, representing a share of the pool’s liquidity.

For example:
- A Uniswap V2 pool for Token A and Token B issues `ConstProd_A_B`.
- Liquidity providers deposit Token A and Token B, receiving `ConstProd_A_B`.

### Strategy Vault (SV)
The Strategy Vault (SV), denoted `SV_A_B`, encapsulates the LP token `ConstProd_A_B` to standardize DEX-specific integration logic (e.g., for Uniswap V2 or Camelot). It treats deposits and withdrawals as swaps.

For example:
- Depositing Token A mints `SV_A_B` tokens (swap: Token A → SV).
- Withdrawing burns `SV_A_B` for Token B (swap: SV → Token B).

### ERC4626 Vault Wrapper
The Strategy Vault is wrapped in an ERC4626 vault token, denoted `4626_SV_A_B`, for compatibility with Balancer V3’s Vault system and Liquidity Buffers.

### SV Conversion Pool (Custom Balancer V3 Pool)
The SV Conversion Pool is a custom Balancer V3 pool that:
- Holds only the ERC4626 vault token (`4626_SV_A_B`) in the Balancer V3 Vault.
- Handles swaps (e.g., Token A ↔ Token B, Token A ↔ SV) and deposits/withdrawals by calling the SV’s logic.
- Users interact via Balancer Routers, which call the Balancer V3 Vault, which calls this pool.

### Dual Constant Product Balancer V3 Pools
Two Constant Product pools operate within the Balancer V3 Vault, each using the `x * y = k` formula:
- **Pool 1**: Pairs `4626_SV_A_B` with Token A (e.g., `4626_SV_A_B/Token_A`).
- **Pool 2**: Pairs `4626_SV_A_B` with Token B (e.g., `4626_SV_A_B/Token_B`).
These pools rely on a Rate Provider to adjust the valuation of `4626_SV_A_B`.

### Rate Provider
A custom Rate Provider in the Balancer V3 Vault provides an exchange rate for `4626_SV_A_B` in both Constant Product pools, using the ZapOut valuation of the SV (e.g., the value of underlying Token A and Token B).

For example:
- If a pool calculates a 2:1 exchange for `4626_SV_A_B` to Token A, the Rate Provider may adjust it to 1:1 based on the SV’s ZapOut valuation.
- This enhances pricing flexibility for swaps in both pools.

### Balancer V3 Vault and Routers
The Balancer V3 Vault manages tokens for all pools (SV Conversion Pool and two Constant Product pools). Users interact through Balancer Routers, which call the Vault to execute swaps, deposits, or withdrawals.

Purpose of the architecture:
- **Unified Interface**: Simplifies interactions via Balancer Routers.
- **Scalability**: Supports multiple pools and Strategy Vaults.
- **Flexibility**: Enables advanced pricing via Rate Providers and complex liquidity management.

## Diagram

### Primary Diagram (Dual Constant Product Pools)
This Mermaid diagram illustrates the two Constant Product pools, using simplified labels:

```mermaid
graph TD
    User[User] --> Router[Balancer_Router]
    Router --> Vault[Balancer_V3_Vault]
    Vault --> Pool1[Const_Prod_Pool_1: 4626_SV_A_B/Token_A]
    Vault --> Pool2[Const_Prod_Pool_2: 4626_SV_A_B/Token_B]
    Vault --> RateProvider[Rate_Provider: ZapOut SV_A_B]
    Pool1 --> T1[4626_SV_A_B]
    Pool1 --> T2[Token_A]
    Pool2 --> T3[4626_SV_A_B]
    Pool2 --> T4[Token_B]
    RateProvider -->|Adjusts Valuation| T1
    RateProvider -->|Adjusts Valuation| T3
```

### Diagram Description
- **User**: Interacts with the Balancer Router to initiate swaps.
- **Balancer Router**: Calls the Balancer V3 Vault.
- **Balancer V3 Vault**: Manages the two Constant Product pools and Rate Provider.
- **Const_Prod_Pool_1**: Holds `4626_SV_A_B` and Token A, using `x * y = k`.
- **Const_Prod_Pool_2**: Holds `4626_SV_A_B` and Token B, using `x * y = k`.
- **Rate Provider**: Adjusts the valuation of `4626_SV_A_B` in both pools using the SV’s ZapOut valuation.
- **Tokens**: `4626_SV_A_B`, Token A, and Token B are the pools’ assets.
- Arrows (`-->`) show interaction flow; Rate Provider arrows indicate valuation adjustments.

### Alternative Diagram (Full System)
This diagram shows the full system, including the SV Conversion Pool, LP token, and Token A/B, with corrected labels:

```mermaid
graph TD
    User[User] --> Router[Balancer_Router]
    Router --> Vault[Balancer_V3_Vault]
    Vault --> Pool1[SV_Conversion_Pool]
    Vault --> Pool2[Const_Prod_Pool_1: 4626_SV_A_B/Token_A]
    Vault --> Pool3[Const_Prod_Pool_2: 4626_SV_A_B/Token_B]
    Vault --> RateProvider[Rate_Provider: ZapOut_SV_A_B]
    Pool1 --> Vault4626[4626_SV_A_B: ERC4626_Vault]
    Vault4626 --> SV[SV_A_B: Strategy_Vault]
    SV --> LP[LP_A_B: ConstProd_A_B]
    LP --> T5[Token_A]
    LP --> T6[Token_B]
    Pool2 --> T1[4626_SV_A_B]
    Pool2 --> T2[Token_A]
    Pool3 --> T3[4626_SV_A_B]
    Pool3 --> T4[Token_B]
    RateProvider -->|Adjusts_Valuation| T1
    RateProvider -->|Adjusts_Valuation| T3
    RateProvider -->|Uses_ZapOut| SV
```

## Rendering Instructions
To visualize either diagram:
1. Copy the Mermaid code (starting with `graph TD`).
2. Paste it into a Mermaid-compatible tool, such as the [Mermaid Live Editor](https://mermaid.live/).
3. Use a recent Mermaid version (v10.0.0 or later) for best compatibility.
4. If rendering fails, check for:
   - Extra spaces or line breaks in the copied code.
   - Tool compatibility (e.g., try VS Code with the Mermaid plugin).
   - Incorrect code block formatting (ensure it starts with ```mermaid and ends with ```).

## Iterative Refinements
Potential additions include:
- Clarifying the ZapOut valuation (e.g., based on Token A/B’s market value).
- Specifying tokens (e.g., ETH/USDC for Token A/B).
- Adding a diagram for a swap in a Constant Product pool.
- Detailing Rate Provider mechanics (e.g., exchange rate calculation).
- Exploring interactions between the SV Conversion Pool and Constant Product pools.

## Troubleshooting Rendering Issues
If rendering issues occur:
- Share the exact error message from the Mermaid Live Editor or other tool.
- Verify the tool’s version (e.g., Mermaid Live Editor should be up-to-date).
- Test the alternative diagram.
- Try a different renderer (e.g., GitHub, VS Code, or Mermaid CLI).