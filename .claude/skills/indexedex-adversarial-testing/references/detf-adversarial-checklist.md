# DETF / SE adversarial checklist (porting)

Use when implementing or reviewing adversarial suites for any IndexedEx DETF or Standard Exchange vault.

## Prerequisites

- [ ] Feature happy-path specs green on production TestBase
- [ ] Gold TestBase exists (no greenfield deploy hacks)
- [ ] Role naming: `rateAsset` / `pairToken` / `underlyingVault` / `rebasingClaimToken` only

## P0 (must for "adversarially tested")

| ID | Test exists? | Drives real entry? | Notes |
|----|--------------|--------------------|-------|
| A1 Donate vault shares | | exchangeIn / transfer | No free DETF |
| A3 Donate BPT / reserve | | redeemClaim without claim | No principal drain |
| B1 Skew mint/burn | | real AMM + exchangeIn | Bounds or no free lunch |
| B3 Threshold gates | | isMinting/BurningAllowed | Coupling |
| C1 Reenter init/first join | | hostile transferFrom | IsLocked |
| C2 Reenter redeem/claim | | hostile path | IsLocked |
| C3 Cross mint→bond | | hostile path | IsLocked |
| D2 Redeem no claim | | redeemClaim | BPT intact |
| D3 Double redeem | | redeemClaim ×2 | Second reverts |
| D6 Over-claim principal | | redeemClaim | Cap by claim + inventory |
| E1 Round-trip | | mint + burn | residual 0 |
| E5 Zero / deadline | | exchangeIn | exact selectors |
| F2 Bond NFT onlyOwner | | createPosition | revert |
| F3 Claim onlyOwner | | mintFromNFTSale / burnShares | revert |
| H2 Redeem atomicity | | redeemClaim fail | claim unchanged |
| H3 Failed mint residual | | minOut fail | inventory 0 |
| **I1** pretransferred claim, no transfer | | exchangeIn/mint with pretransferred=true | Vault has reserves; attacker shares **unchanged** |
| **I2** short pretransfer | | transfer < amountIn, pretransferred=true | Exact revert |
| **I3** residual reuse | | second call without new transfer | No free mint |
| **J1** Target ⊆ facetFuncs | | declaration + Target enum | No omitted product selectors |
| **J2** loupe after DFPkg deploy | | facetAddress(sel) | All product sels non-zero |
| **J3** proxy smoke | | call each product fn on instance | No FunctionNotFound |
| **K1** donation then deposit | | donate + victim mint | No free credit / strict mismatch |

## P1 (should)

| ID | Notes |
|----|-------|
| A2 Donate product token | Idle free DETF not spent by others |
| D4 Junk rateAsset | InvalidRoute |
| D5 Lock clamp | min revert / max clamp |
| E4 Holder balance non-dilution | balance units unchanged |
| F1 No free diamondCut / unowned | |
| F4 Weights/rates immutable | no setter |
| G1 Nested outer does not brick inner | third user on nested |

## P2 (explicit defer OK)

A4–A5, B2/B4–B5, C4–C5, D7, E2–E3, G2–G3, H1, peer product ports — each needs one-line reason in suite NatSpec.

## Reference suite

`test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/`
