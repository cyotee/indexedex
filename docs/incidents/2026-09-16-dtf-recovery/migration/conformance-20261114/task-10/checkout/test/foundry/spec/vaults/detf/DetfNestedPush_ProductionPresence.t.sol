// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// Retired source-text checks are consolidated into actual custody and transfer
// tests in protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_NestedSe.t.sol,
// the Weighted/Orbital/Quad counterparts, and the reserve-hook adversarial suites.
// Funded staking and standard composition may legitimately pull approved tokens.
// Security depends on measured funding and authorization, not a comment literal
// or a blanket prohibition on pretransferred=false in source text.
// See implementation-artifacts/detf-funded-staking/source-presence-consolidation-map.json.
