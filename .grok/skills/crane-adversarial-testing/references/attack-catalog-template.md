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
| A0 | Residual assets with zero/empty share supply | Pre-seed inventory; `totalSupply()==0` | First mint/redeem drains inventory | Dead shares / init gate; first minter pays full NAV | P0 |
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
| E6 | Surplus-refund reclaim | Donate/overpay ETH or tokens; product has refund/`balance−floor` path | Call refund/residual-return as attacker | Refund ≤ this-call overpay / tracked credit; prior inventory untouched | P0 if refund path exists |
| F2–F3 | onlyOwner on NFT/claim | Random EOA | createPosition / mintFromNFTSale | Revert | P0 |
| F5 | Permissionless structural reclaim | Idle inventory on contract + public resize/migrate/reclaim | Attacker calls structural op | No free surplus extract; auth-gated or refund cannot touch inventory | P0 if public structural settle exists |
| G1 | Outer does not brick nested | Nested live | Outer mint/burn | Inner still serves third user | P1 |
| H2 | Failed redeem atomicity | Claim path | Impossible minOut / min balance | Claim balance unchanged on fail | P0 |
| H3 | Failed mint residual | Live | Impossible minOut | No free inventory on diamond | P0 |
| I1 | Claim pretransferred, no transfer | Live vault with existing reserves ≥ amountIn | `exchangeIn(..., pretransferred=true)` without sending tokens | Revert or zero credit; attacker shares unchanged | P0 |
| I2 | Short pretransfer | Transfer amountIn/2 then claim amountIn | pretransferred=true | Exact transfer-not-received / insufficient revert | P0 |
| I3 | Residual reuse | Valid pretransfer then second call without new funds | second entry | No free mint from residual | P0 |
| I4 | Fee-on-transfer shortfall | FoT token pull path | deposit/exchange | Credit ≤ actual delta | P1 |
| J1 | Facet omits Target entry | New facet | Diff Target external API vs facetFuncs | No orphan product selectors | P0 |
| J2 | Proxy loupe missing selector | Production DFPkg deploy | facetAddress(sel) for each product sel | Non-zero for all | P0 |
| J3 | Proxy call surface | Deployed instance | Call each product fn on **proxy** | No FunctionNotFound; access reverts exact | P0 |
| K1 | Donation then deposit mis-credit | Donate to vault then victim deposits | deposit/exchangeIn | No free shares from donation; strict mismatch or documented beneficiary | P0 |
| L1 | Untracked surplus / skim-class extract (pair **or** native/ERC20 reclaim) | Product holds LP, prices from pair, **or** idle balance + public reclaim | Create surplus; try extract via mint/price/refund/migrate | No free extract; books match balances | P0 if AMM-priced/LP or reclaim path |
| L2 | FoT leaves books ≠ balances | FoT underlying | Deposit FoT; check credit/NAV | Credit ≤ actualIn; no phantom NAV | P1 (P0 if FoT claimed) |
| L3 | Burn-from-pair / reserve skew as oracle | Spot-priced mint/burn | Skew pair reserves; mint/burn | No free lunch beyond deadband policy | P0 if spot oracle |
| M1 | Arbitrary call with held allowance | Router/helper with allowance | User `target+data` drains allowance | Revert / no user target | P0 if helper exists |
| M2 | Unvalidated swap target | Issuance/exchange helper | Hostile swap target | Allowlist + measured amountOut | P0 if helper exists |
| M3 | Third-party allowance sweep | Open allowance to SUT | transferFrom victim without intent | Revert / explicit permit only | P0 |
| N1 | Quote–settle TOCTOU via hook | Multi-step issue/bond | Hostile mid-flow unit change | No inflated credit / inventory drain | P0 if callbacks |
| N2 | Preview ≠ execute | Preview then execute | Stale snapshot / unit drift | Match or documented tolerance | P1 |
| O1 | Broken permit / ecrecover address(0) | Permit path | Dummy or zero signer | Revert; no authorize | P0 if permit |
| O2 | Signature replay | Permit path | Replay same sig | Revert | P0 if permit |
| O3 | EIP-712 / Permit2 domain mismatch | Permit2 path | Wrong domain/typehash | Revert; credit actual only | P1 |

**Do not renumber A–K.** A0 and L/M/N/O are extensions.

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

```solidity
/// @notice A0 empty vault / residual inventory; L1–L3 AMM desync when product prices from pairs.
/// @dev Deferred: L2 if product forbids FoT underlyings — document reason.
contract Adversarial_EmptyVault_AmmDesync_Test is TestBase_Feature_Adversarial {
    function test_A0_residualAssets_zeroSupply_firstMinterCannotDrain() public { ... }
    function test_L1_untrackedSurplus_cannotFreeMint() public { ... }
}
```

```solidity
/// @notice M middleware, N TOCTOU, O signatures — only when surface exists.
/// @dev Deferred P2: M* if no router/helper; O* if no permit path.
contract Adversarial_Middleware_Toctou_Sig_Test is TestBase_Feature_Adversarial { ... }
```

## Invariants checklist (assert in multiple tests)

1. Residual free inventory ~0 after success
2. Failed redeem / exit does not permanently burn claim without payout
3. Principal exit ≤ burned claim / authority and ≤ diamond inventory
4. Live/init gates block user mint before product is live (if applicable)
5. Nested reentrancy → IsLocked
6. Access-sensitive mint/burn onlyOwner or equivalent
7. Soft non-dilution: existing holder **balance** unchanged by others' mints (economic claim may move by design)
8. **Credit = observed inbound delta** — never absolute balance, never caller claim alone (`pretransferred` / pull / permit)
9. **Proxy exposes full product API** — Target ↔ facetFuncs ↔ facetCuts ↔ loupe ↔ callable
10. Attacker share/product balance does not increase without a matching asset decrease (or documented fee/seigniorage path)
11. **Empty vault (A0):** residual assets with zero supply cannot be claimed free by first minter
12. **AMM books (L):** protocol-priced inventory does not treat pair surplus as free mint credit
12b. **Surplus-refund (E6/L1/F5):** refund/resize/migrate never pays raw `balance − floor` of protocol inventory to an unprivileged caller
13. **No arbitrary call (M):** helpers cannot spend allowances via user-supplied target+data
14. **Quote=settle (N):** mid-flow hooks cannot inflate units after quote
15. **Valid signer only (O):** address(0) / replay / dummy permit never authorizes