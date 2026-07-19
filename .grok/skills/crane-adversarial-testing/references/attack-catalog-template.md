# Attack catalog template (copy into feature adversarial plan)

## Threat model (fill)

| Actor | Capabilities | Cannot |
|-------|--------------|--------|
| External user / MEV | Atomic multicall, flash capital, pool trades, ERC20 transfers to diamond | Diamond cut instance (if unowned), change immutables |
| Malicious ERC20 | Reentrancy on transfer/transferFrom | Bypass nonReentrant if wired |
| Nested product user | Outer + inner entry points | Own outer after deploy |
| Claim / NFT holder | Sell NFT, redeem claim | Invent principal beyond burned claim |

**Assets of concern:** user shares, product tokens, reserve BPT/LP, bond principal, fee slices.

## Catalog table skeleton

| ID | Attack | Setup | Action | Pass criteria | P |
|----|--------|-------|--------|---------------|---|
| A1 | Donate vault shares to diamond | Live | `transfer` shares without mint | No free product mint | P0 |
| A2 | Donate product token to diamond | Live | Direct transfer | Victim balances unchanged | P1 |
| A3 | Donate reserve BPT/LP | Live + bond accounting | Transfer BPT | Cannot redeem others' principal | P0 |
| B1 | Skew → mint → reverse → burn | Open or default gates | Underlying swap + mint/burn | No free lunch **or** bounded seigniorage + safety | P0 |
| B3 | Rate jump at threshold | Rated leg | Trade until gate flips | Mint/burn gates couple to synthetic/spot rule | P0 |
| C1 | Reenter initialize / first deposit | Hostile share | Nested init | IsLocked | P0 |
| C2 | Reenter redeem/claim mid-path | Hostile path | Nested redeem | IsLocked; no double-spend | P0 |
| C3 | Cross-entry mint → bond | Hostile share | Nested bond during mint | IsLocked | P0 |
| D2 | Redeem without claim inventory | Live | redeem(amount) as EOA w/ 0 claim | Revert; principal not drained | P0 |
| D3 | Double redeem | After sell | Redeem twice | Second reverts | P0 |
| D6 | Over-claim principal | After sell | Redeem more than burned claim | Cap by claim + diamond inventory | P0 |
| E1 | Round-trip conservation | Open path | mint then burn | out ≤ in + fees/slippage; residual 0 | P0 |
| E5 | Zero / expired deadline | Live | amount=0 / past deadline | Revert exact selector | P0 |
| F2–F3 | onlyOwner on NFT/claim | Random EOA | createPosition / mintFromNFTSale | Revert | P0 |
| G1 | Outer does not brick nested | Nested live | Outer mint/burn | Inner still serves third user | P1 |
| H2 | Failed redeem atomicity | Claim path | Impossible minOut / min balance | Claim balance unchanged on fail | P0 |
| H3 | Failed mint residual | Live | Impossible minOut | No free inventory on diamond | P0 |

## Suite NatSpec stubs

```solidity
/// @notice A1–A3 donation / inflation.
/// @dev Deferred P2: A4 (dust first deposit), A5 (fee double-claim) — reason...
contract Adversarial_Donation_Test is TestBase_Feature_Adversarial {
    function test_A1_donateShares_cannotMintFree() public { ... }
}
```

```solidity
/// @notice C1–C3 reentrancy expansion.
/// @dev Deferred P2: C4 (hostile rateAsset callback), C5 (preview read-only).
contract Adversarial_Reentrancy_Test is TestBase_Feature_Adversarial { ... }
```

## Invariants checklist (assert in multiple tests)

1. Residual free inventory ~0 after success
2. Failed redeem / exit does not permanently burn claim without payout
3. Principal exit ≤ burned claim / authority and ≤ diamond inventory
4. Live/init gates block user mint before product is live (if applicable)
5. Nested reentrancy → IsLocked
6. Access-sensitive mint/burn onlyOwner or equivalent
7. Soft non-dilution: existing holder **balance** unchanged by others' mints (economic claim may move by design)
