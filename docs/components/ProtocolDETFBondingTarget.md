### Target: contracts/vaults/protocol/ProtocolDETFBondingTarget.sol

## Validation
- CONFIRMED-WITH-MAINTAINER (2026-02-14)

## Intent
- Protocol bonding operations that create/manage ProtocolNFTVault positions, capture seigniorage, and support protocol liquidity extraction for WETH.

Routes:

- Route ID: TGT-ProtocolDETFBonding-01
  - Selector / Function: `claimLiquidity(uint256,address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: PkgOnly / InternalOnly (restricted to `protocolNFTVault` caller)
  - State Writes: Balancer reserve pool via router, `ERC4626Repo._setLastTotalAssets`
  - External Calls: Balancer prepay router remove single token exact-in; `IERC4626(chirWethVault).redeem/previewRedeem` (indirect), Aerodrome pool `burn`; `chirWethVault.exchangeIn`; Balancer prepay router add-liquidity
  - Inputs: `lpAmount` (BPT) to exit, `recipient` defaults to msg.sender if zero
  - Outputs: extracted WETH amount
  - Execution Outline: verify initialized; require caller is protocol NFT vault; compute conservative min vault token out; single-token exit into `chirWethVault` shares; redeem to Aerodrome LP; burn LP to CHIR+WETH; transfer WETH to recipient; reinvest CHIR by depositing into `chirWethVault` then adding resulting shares back to reserve pool; sync reserve view
  - Invariants: only NFT vault may extract liquidity; CHIR portion is reinvested; min-out math uses Balancer rates and leaves 1 wei slack
  - Failure Modes: `NotNFTVault`, `ReservePoolNotInitialized`, downstream reverts
  - Tests Required: access control; extractedWeth correctness; reinvest path leaves no stray LP; reserve view sync; previewClaimLiquidity (query target) conservative vs execute

- Route ID: TGT-ProtocolDETFBonding-02
  - Selector / Function: `bondWithWeth(uint256,uint256,address,uint256)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: reserve pool via router, ProtocolNFTVault position state
  - External Calls: `weth.transferFrom`, `chirWethVault.exchangeIn`, Balancer prepay add-liquidity, `protocolNFTVault.createPosition`
  - Inputs: `amountIn>0`, lockDuration bounds enforced by NFT vault, `deadline>=now`
  - Outputs: `(tokenId, shares)`
  - Execution Outline: deadline/amount/init; pull WETH; deposit to chirWeth vault -> shares; single-sided add to reserve pool -> BPT; create NFT position with BPT shares
  - Invariants: shares are reserve-pool BPT; lock duration must be enforced by NFT vault
  - Failure Modes: `DeadlineExceeded`, `ZeroAmount`, `ReservePoolNotInitialized`, downstream reverts
  - Tests Required: lock duration bounds; recipient defaulting; preview parity where applicable

- Route ID: TGT-ProtocolDETFBonding-03
  - Selector / Function: `bondWithRich(uint256,uint256,address,uint256)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: reserve pool, ProtocolNFTVault position
  - External Calls: `rich.transferFrom`, `richChirVault.exchangeIn`, Balancer add-liquidity, `protocolNFTVault.createPosition`
  - Inputs/Outputs/Outline: same as Route 02 but using RICH -> `richChirVault` path
  - Invariants: same
  - Failure Modes: same
  - Tests Required: same

- Route ID: TGT-ProtocolDETFBonding-04
  - Selector / Function: `captureSeigniorage()`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (but requires NFT vault to have approved CHIR transfer)
  - State Writes: reserve pool, protocol NFT position
  - External Calls: `transferFrom(protocolNFTVault)` for CHIR, `chirWethVault.exchangeIn`, Balancer add-liquidity, `protocolNFTVault.addToProtocolNFT`
  - Inputs: none
  - Outputs: BPT received
  - Execution Outline: require initialized; read CHIR balance held by protocol NFT vault; pull CHIR; deposit CHIR to chirWeth vault -> shares; add to reserve pool -> BPT; add BPT to protocol NFT
  - Invariants: only captures if CHIR balance > 0; no value leakage; reserve view sync happens inside `_addToReservePool`
  - Failure Modes: `ReservePoolNotInitialized`, `NoSeigniorageToCapture`, downstream reverts
  - Tests Required: requires allowance wiring; permissionless caller cannot redirect funds; BPT credited to protocol NFT

- Route ID: TGT-ProtocolDETFBonding-05
  - Selector / Function: `sellNFT(uint256,address)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless (position authority enforced in NFT vault)
  - State Writes: NFT vault position state, RICHIR supply
  - External Calls: `protocolNFTVault.sellPositionToProtocol`, `richirToken.mintFromNFTSale`
  - Inputs: `tokenId`, recipient defaulting
  - Outputs: RICHIR minted
  - Execution Outline: require initialized; call NFT vault to sell position; get principal shares moved to protocol-owned position; use `BetterMath._convertToSharesDown(principalShares)` to calculate RICHIR shares; mint RICHIR to recipient; return RICHIR minted
  - Invariants: rewards harvested and paid by NFT vault per its rules; sold NFT burned by NFT vault; minted amount matches principal shares
  - Failure Modes: `ZeroAmount`, downstream reverts
  - Tests Required: only NFT owner can sell; RICH rewards paid to recipient; principal moved; RICHIR minted matches shares

- Route ID: TGT-ProtocolDETFBonding-06
  - Selector / Function: `donate(IERC20,uint256,bool)`
  - Entry Context: Proxy -> delegatecall Target
  - Auth: Permissionless
  - State Writes: reserve pool + protocol NFT position (WETH path) OR CHIR supply (burn path)
  - External Calls: if WETH: `chirWethVault.exchangeIn` + Balancer add-liquidity + `protocolNFTVault.addToProtocolNFT`; if CHIR: `ERC20Repo._burn`
  - Inputs: token must be WETH or CHIR; amount>0
  - Outputs: none
  - Execution Outline: require initialized; pull token if needed; if WETH: deposit to chirWeth vault -> shares, add to reserve pool -> BPT, add to protocol NFT; if CHIR: divide amount in half, burn half, transfer remaining half to Protocol DETF NFT as reward for bond holders
  - Invariants: invalid donation tokens revert; CHIR donation reduces supply
  - Failure Modes: `InvalidDonationToken`, `ZeroAmount`, downstream reverts
  - Tests Required: donation token gating; pretransferred behavior; WETH donation increases protocol NFT backing; CHIR donation burns

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
