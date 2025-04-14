# Add Liquidity Test Plan for Uniswap V2-Style Pool (using ConstProdUtils)

## Overview

This document outlines the plan and checklist for implementing and testing the add liquidity logic for a Uniswap V2-style pool (e.g., USDC/DAI) using the `ConstProdUtils` library. The goal is to ensure correct calculation of required token amounts, proper minting, and successful deposit, with full test coverage and documentation. **This helper is specifically for minting Uniswap LP tokens, which can then be deposited into a strategy vault.**

---

## Step-by-Step Plan

1. **Review Pool and Vault Setup**

   - [x] Confirm the correct pool contract and vault are used in the test.
   - [x] Ensure the test base class initializes the pool and vault properly.

2. **Determine Token Addresses and Reserves**

   - [x] Identify the correct token addresses for USDC and DAI (or test tokens).
   - [x] Retrieve the Uniswap V2 pair and its reserves for balanced deposit calculation.

3. **Design and Implement Reusable Uniswap LP Liquidity Function**

   - [x] Design a function that accepts token addresses, desired amounts, and recipient, and calculates the required balanced deposit using `ConstProdUtils`.
   - [x] Allow address(0) or amount 0 for 'don't care' arguments, but require at least one token/amount pair.
   - [x] Implement the function in the Uniswap V2 strategy vault test base.
   - [x] Function should mint/allocate tokens, approve the router, and call `addLiquidity`.
   - [x] Add NatSpec and usage example.
   - [x] **Status:** Function implemented as `addBalancedUniswapLiquidity` in `TestBase_UniswapV2StandardStrategyVault`.

4. **Test the Helper Function**

   - [x] Write a test that uses the helper to add liquidity based on a specified amount of USDC or DAI. 
   - [ ] Verify the correct LP tokens are minted and balances are updated.
   - [ ] Test edge cases (e.g., both amounts provided, only one provided, zero/invalid input).
   - [x] **Status:** `test_addBalancedUniswapLiquidity_tokenA` implemented in `TestBase_UniswapV2StandardStrategyVault`.

5. **Integrate with Strategy Vault Deposit Flow**

   - [ ] Use the helper to mint LP tokens, then deposit them into the strategy vault.
   - [ ] Verify vault share balances and correct accounting.

6. **Document and Review**

   - [ ] Update this plan and checklist as steps are completed.
   - [ ] Add notes on any issues, edge cases, or improvements discovered during implementation.

---

## Progress Checklist

- [ ] Uniswap pool and strategy vault setup reviewed
- [ ] Token addresses and reserves determined
- [ ] Reusable Uniswap add liquidity function designed and implemented
- [ ] Deposit amounts decided and calculated
- [ ] Tokens minted/allocated and approved
- [ ] Uniswap deposit transaction performed
- [ ] LP tokens deposited into strategy vault
- [ ] LP token and vault share receipt verified
- [ ] Assertions and logging added
- [ ] Edge cases tested
- [ ] Documentation and cleanup completed

---

**Reference Functions:**

- `ConstProdUtils._equivLiquidity(amountA, reserveA, reserveB)`
- `ConstProdUtils._depositQuote(amountADeposit, amountBDeposit, lpTotalSupply, lpReserveA, lpReserveB)`

**Next Steps:**

- Work through each checklist item, updating this file as progress is made.
- Reference this plan in test implementation and documentation. 