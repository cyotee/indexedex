# Precision and claim accounting review

Review-only; no production edits or Forge commands. Checked the upstream [precision checklist](https://raw.githubusercontent.com/austintgriffith/evm-audit-skills/main/evm-audit-precision-math/references/checklist.md), live code, Alignment D10/N10/D15/D18, and unified coverage R-9/R-22. Findings below are source-confirmed; regression execution remains required. No exploit procedures are included.

## P1 — New LP is booked as original shares without conversion

- **Severity / confidence:** High / high.
- **Locations:** `UniswapV4DetfCommon.sol:375` (compound), `:486` (rejoin); `UniswapV4DetfTarget.sol:662` (`_openBondNft`) and `:353` (claim purchase). Paths are under `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`.
- **Defect:** The NFT `createPosition` and `addToDETFNFT` functions accept original-share units. These callers pass raw physical LP units. R12a donation can make physical LP differ from `totalOriginalShares`; after that, new principal dilutes existing holders or receives the wrong entitlement. The NFT conversion denominator itself correctly uses original rather than effective shares.
- **Callee trace:** V4 NFT `createPosition` passes `(shares, shares)` into `_createPositionInternal`, which records the original argument through `DETFNFTVaultRepo._createPosition`. V4 NFT `addToDETFNFT:342` calls `DETFNFTVaultRepo._addToPosition`; that function directly increments `originalSharesOf` and `totalOriginalShares` at lines 394/397 or 403/406. Neither callee performs an LP-to-share conversion.
- **Correction:** Snapshot physical LP and total original shares before each join. Convert joined LP to original shares at that snapshot using the established N10 decimal-offset helper. Pass original shares into the NFT ledger; use those same units for claim minting. Do not change R12a donation economics. Reward-weight calculation should consume the correctly converted original principal.
- **Required tests:** Production fixtures for CP, Orbital, Weighted and Quad: establish user and id-0 principal, donate unassigned LP to move the conversion ratio, then independently perform a later bond, compound, and mature-close surplus rejoin. Assert credited original shares equal the pre-join conversion and the prior holder's LP entitlement does not fall beyond rounding. Include distinct lock bonuses to demonstrate effective weights do not enter principal math.

## P2 — A first claim mint can silently mint zero against existing id-0 principal

- **Severity / confidence:** High / high for arithmetic and lost mint; remediation policy needs explicit documentation.
- **Location:** `contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol:318`–`:322`; mirrored preview in `UniswapV4DetfTarget.sol:370`–`:372`.
- **Defect:** With positive id-0 original shares and zero claim shares, the proportional formula returns zero for every positive deposit. `_mintShares` accepts zero. This state can arise from protocol LP acquisitions before first claim issuance, or after the last claim burns while protocol LP remains. A positive incoming principal does not establish claim ownership.
- **Correction:** Define and implement the zero-supply initialization branch, and reject zero-share mint results. Alignment §14.2 currently explicitly branches only on zero protocol assets; therefore blindly switching to `totalShares == 0 || totalAssets == 0` also grants the first claimant all previously unrepresented protocol principal. Document the intended ownership of that principal (bootstrap/reserved claim ownership versus first-holder allocation) alongside the fix. Zero-result rejection is the minimum safe behavior and does not itself restore issuance.
- **Required tests:** Before first claim mint, make id-0 principal positive through an ordinary protocol acquisition. Verify the next valid mint gives the intended nonzero claim allocation, or atomically rejects without consuming principal. Repeat after exhausting claim shares while id-0 assets remain. Cover nonzero-supply deposits too small to mint one share.

## P3 — Exact-output claim exchange uses share units as token amounts

- **Severity / confidence:** Medium / high.
- **Locations:** `RebasingClaimTokenTarget.sol:225` and `:402`.
- **Defect:** `amountOut * ONE_WAD / rate` is a share conversion. The result is passed to `_secureTokenTransfer` and `_executeRedeem`, both of which expect rebasing ERC20 balance units and convert again. `previewExchangeIn` already establishes that a claim balance amount redeems to approximately the same DETF amount. At a non-unit rate, exact-output quoting and execution disagree with that identity; rates above one commonly result in short payout/revert, while rates below one consume excess claim balance.
- **Correction:** Compute the smallest rebasing balance input whose existing two-step preview produces the requested output, with appropriate upward rounding; share quantities must stay internal. Use the same helper in preview and execution.
- **Required tests:** On the production claim proxy, make redemption rates materially above and below one, then assert exact-output preview executes with that maximum, delivers at least the target, and consumes the minimum valid rebasing balance. Include rounding-edge targets and insufficient-max rollback.

## P4 — Block-scoped rate cache remains valid after backing changes

- **Severity / confidence:** Medium / high.
- **Locations:** `RebasingClaimTokenTarget.sol:480` (`updateRedemptionRate`) and `:516`–`:523`; `RebasingClaimTokenRepo.sol:215` (`_setCachedRedemptionRate`).
- **Defect:** Anyone can cache a rate for the current block. Subsequent mint, burn, reserve donation, swap, or compound in that block can change backing or supply, yet balance/transfer/redeem keep using the old rate. `totalSupply` independently calculates the live zap-out, so the supply/balance relationship can become inconsistent within one block. A block number is insufficient to version this externally changing valuation.
- **Correction:** Prefer live calculation in `_getCurrentRedemptionRate`; retain the update API as an event/snapshot operation if needed. Invalidating solely on claim mint/burn does not cover changes in the reserve pool or NFT.
- **Required tests:** Call `updateRedemptionRate`, change reserve backing through a production donation or swap without rolling the block, then compare balance/rate and redeem against the live reserve quote. Also cover cached-rate mint and successive partial redemptions.

## P5 — Redemption discards internal share precision before pro-rata conversion

- **Severity / confidence:** Medium / high arithmetic confidence; boundary reachability should be established by production tests.
- **Location:** `RebasingClaimTokenTarget.sol:503`–`:513` (`_convertInternalSharesToProtocolBpt`).
- **Defect:** Both numerator and denominator are floored from 27-decimal internal shares into external units before multiplication. Fractional internal shares exist after ordinary transfers and burns. Discarding those fractions can disproportionately distort small positions, force a nonzero redeem to zero, and return zero when aggregate external shares round down to zero despite outstanding internal shares and backing.
- **Correction:** Calculate `Math.mulDiv(internalShares_, totalAssets_, layoutStruct_.totalShares)` directly, preserving internal precision until the final original-share rounding. Apply the same principle to minting against existing fractional claim supply rather than flooring total supply first.
- **Required tests:** Production claim fixture with a non-unit rate: create fractional internal shares via ordinary transfers/partial redeem; compare original-share release to the full-precision ratio. Include aggregate remaining internal shares below one external-share unit where achievable without storage edits.

## Intentional behavior and limits

- D15 pending-first redemption may leave id-0 original shares unchanged when harvested rewards cover the payout. This is expressly required by D15-3 and is not reported as a bug.
- N10 correctly denominates conversions in `totalOriginalShares`; effective fee/creator weights are excluded from principal. Sell-to-protocol transfers original principal and burns user bonus weight correctly.
- The zero-supply branch in P2 requires reconciling the written §14.2 formula, not an undocumented change to protocol economics.
- No owner impersonation, storage mutation, or mock-based test is evidence of public reachability. Shared claim entrypoints are production proxy APIs; mint remains DETF-owner-only. R-9's historical no-D18-tests note should be reconciled with the currently present DETF `exchangeIn(DETF, claim)` implementation before selecting its regression surface.

## Principal rounding follow-up

Deposit issuance now uses BetterMath's floor conversion, retaining N10's offsets and empty-state branches. Ceiling issuance can materially dilute existing principal after a tiny bootstrap and ordinary unassigned-LP growth; the universal bond and claim-purchase paths therefore reject zero-original-share results atomically.

Close/claim surplus that rejoins less than one original share remains physical unassigned LP under R12a, preserving exits without awarding a whole share. Compound has a stricter ownership requirement: when its joined LP cannot buy one original share, the atomic compound reverts and its best-effort caller preserves id-0 pending rewards. It does not redistribute those rewards as an unassigned gift.

Production regressions are in `UniswapV4Detf_OriginalPrincipal.t.sol` (five CP tiny-principal cases plus floor expectations across four families) and `DETFNFTVault_N10Conversion.t.sol` (deposit floor with a nonzero offset). Execution is pending the coordinating agent's build/test run; formatting and diff checks alone are not runtime evidence.
