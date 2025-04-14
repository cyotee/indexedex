// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                               Indexedex Fees                               */
/* -------------------------------------------------------------------------- */
// All fee percentages use WAD scale (1e18 = 100%).

/* -------------------------------- Usage Fee ------------------------------- */

uint256 constant DEFAULT_VAULT_USAGE_FEE = 1e15; // 0.1% (WAD)

/* ------------------------------- Bond Terms ------------------------------- */

uint256 constant DEFAULT_BOND_MIN_TERM = 30 days;
uint256 constant DEFAULT_BOND_MAX_TERM = 180 days;
uint256 constant DEFAULT_BOND_MIN_BONUS_PERCENTAGE = 5e16; // 5% (WAD)
uint256 constant DEFAULT_BOND_MAX_BONUS_PERCENTAGE = 1e17; // 10% (WAD)

/* -------------------------------- DEX Fees -------------------------------- */

uint256 constant DEFAULT_DEX_FEE = 5e16; // 5% (WAD)

/* ---------------------------- Seigniorage Terms --------------------------- */

uint256 constant DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE = 5e17; // 50% (WAD)

/* ------------------------------ Lending Terms ----------------------------- */

uint256 constant DEFAULT_LENDING_BASE_RATE = 1e15; // 0.1% (WAD)
uint256 constant DEFAULT_LENDING_BASE_MULTIPLIER = 1e18; // 1x multiplier
uint256 constant DEFAULT_KINK_RATE = 1e16; // 1% (WAD) — 10x base rate
uint256 constant DEFAULT_KINK_MULTIPLIER = 5e18; // 5x multiplier

/* ------------------------------- Balancer V3 ------------------------------ */

uint256 constant BALANCER_V3_FEE_DENOMINATOR = 1e18; // WAD scale

/* -------------------------- Preview Buffer BPS ---------------------------- */
// Precision buffer constants for preview calculations.
// These account for rounding differences between pure math and on-chain execution.
// Actual divergence ~0.34% for RICHIR, ~0.0000000000021% for BPT.

uint256 constant PREVIEW_BUFFER_DENOMINATOR = 100_000; // Basis points denominator (100_000 = 100%)
// Reduce RICHIR buffer for empirical tuning — we will search for the minimal
// buffer that keeps previews conservative under tests.
uint256 constant PREVIEW_RICHIR_BUFFER_BPS = 350; // 0.35% buffer for RICHIR preview (was 400)
uint256 constant PREVIEW_WETH_CHIR_BUFFER_BPS = 100; // 0.10% buffer for WETH→CHIR preview

// BPT uses a higher precision denominator due to minimal rounding divergence
uint256 constant PREVIEW_BPT_BUFFER_DENOMINATOR = 1_000_000; // 6 decimal places (1_000_000 = 100%)
// Restore a slightly larger BPT buffer so previews are strictly conservative
// across small-BPT edge-cases observed in tests.
// 10 / 1_000_000 = 0.001% (0.1 bps)
uint256 constant PREVIEW_BPT_BUFFER_BPS = 10; // 0.001% buffer (10/1_000_000) for BPT preview

/* -------------------------------------------------------------------------- */
/*                                  Versions                                  */
/* -------------------------------------------------------------------------- */

string constant SE_ROUTER_VERSION = "1.0.0";
string constant SE_BATCH_ROUTER_VERSION = "1.0.0";
