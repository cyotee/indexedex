// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice R3 funded receipt: canonical staking state plus native principal basis and escrowed reward gons.
/// @dev Reuse IStakedDETF.StakingState and its real funding/SE ABI. Q=1e36; k is current gons
/// per native sDETF, 1<=k<=Q. P is native nine-decimal principal; R0/R1/R2, E and U are exact gons.
/// Receipt escrow holds sum(R0+R1+R2)+E+U; those gons are already in canonical totalGons.
interface IUniswapV4DetfMigrationStakedDETF is IStakedDETF, IUniswapV4DetfMigrationAccounting {
    /// @dev Keep uint8 method parameters exactly as R3; these ordinals name the admitted domains.
    enum RewardDomain {
        Wallet,
        Role,
        SY
    }

    error InvalidRewardDomain(uint8 domain);
    error InvalidRewardBeneficiary(address beneficiary);
    error InsufficientLiquidPrincipal(uint256 requested, uint256 available);
    error InsufficientDeferredRewardGons(uint256 requested, uint256 available);
    error MigrationCustodyUnderfunded(address custodian, uint256 heldGons, uint256 requiredGons);

    event RewardGonsDeferred(
        address indexed source, address indexed beneficiary, uint8 indexed domain, uint256 gons, uint256 k
    );
    event DeferredRewardRightsTransferred(
        address indexed from, address indexed to, uint8 indexed domain, uint256 gons
    );
    event DeferredRewardsPaid(
        address indexed beneficiary, uint8 indexed domain, uint256 nativeSDETF, uint256 gons, uint256 k
    );
    event SelfHeldSyRewardsDeferred(address indexed sy, uint256 gons, uint256 k);
    event SyRewardsTokenized(address indexed beneficiary, uint256 nativeRT, uint256 gons, uint256 k);
    event SyRewardRemainderPaid(address indexed beneficiary, uint256 nativeSDETF, uint256 gons, uint256 k);
    event MigrationGonsRetired(address indexed custodian, uint256 gons, uint256 stakingDustAdded, uint256 k);

    /// @notice Stored physical gons, native basis, latent surplus, R0/R1/R2 and executable native cap.
    /// @dev Ordinary balanceOf remains floor(physicalGons/k), not a promise of Stage-1 reward
    /// spendability. Protected custody accounts have zero public maxUnstake and no wallet surplus.
    function egressState(address account_) external view returns (
        uint256 physicalGons, uint256 liquidBasis, uint256 latentGons,
        uint256 walletGons, uint256 roleGons, uint256 syGons, uint256 maxUnstake
    );

    /// @notice Synchronize then move the caller's existing wallet surplus into R0 under receipt custody.
    function checkpointRewards() external returns (uint256 movedGons);

    /// @notice Exact attributed beneficiary gons in domain 0, 1 or 2; excludes tokenized E and self-held U.
    function deferredRewardGons(uint8 domain_, address beneficiary_) external view returns (uint256);

    /// @notice E = 1e18 * RT.totalSupply(), already physically held by receipt escrow.
    function tokenizedSyRewardGons() external view returns (uint256);

    /// @notice Activated native-sDETF release of caller's R0 or R1, debiting only paid*k.
    function claimDeferredRewards(uint8 domain_) external returns (uint256 nativePaid);

    /// @notice Anyone may trigger activated R1 release, but only to the recorded beneficiary.
    function claimDeferredRoleRewards(address beneficiary_) external returns (uint256 nativePaid);

    /// @notice Actual owner assigns exact R0 or R2 rights; no native allowance, mint or custody movement.
    /// @dev R1 cannot be reassigned. Reject protected recipients. Valid before and after activation.
    function transferDeferredRewardRights(uint8 domain_, address to_, uint256 gons_) external;

    /// @notice Fixed bond-only delivery after position/aggregate debit, checked against actual remaining gons.
    /// @dev principal_/reward_ are native sDETF. Independently require activation for positive reward_.
    function deliverBondClaim(address recipient_, uint256 principal_, uint256 reward_, uint256 expectedK_) external;

    /// @notice Fixed staking-SY-only checkpoint after debiting its authoritative backingGons.
    /// @dev Move existing physical gons to escrow/R2; beneficiary_ == stakingSY credits U instead.
    function deferSyRewards(address beneficiary_, uint256 gons_, uint256 expectedK_) external;

    /// @notice Fixed staking-SY-only transfer of principal_*k actual gons and principal_ native basis.
    function transferSyPrincipal(address recipient_, uint256 principal_, uint256 expectedK_) external;

    /// @notice Fixed staking-SY-only burn of principal_*k and payment of principal_ held DETF.
    function withdrawSyPrincipal(address recipient_, uint256 principal_, uint256 expectedK_) external;

    /// @notice Fixed staking-SY-only, activation-gated R2 -> E transition and receipt-only RT mint.
    /// @dev Return floor(R2/1e18) native RT, not native sDETF; retain R2%1e18.
    function issueSyRewardTokens(address beneficiary_, uint256 expectedK_) external returns (uint256 nativeRT);

    /// @notice Fixed staking-SY-only, activation-gated native payout from R2%1e18, retaining unpaid gons.
    function paySyRewardRemainder(address beneficiary_, uint256 expectedK_) external returns (uint256 nativeSDETF);

    /// @notice Fixed RT-only synchronized redemption for RT's actual caller; no public owner substitution.
    /// @dev Synchronize before local accounting, require activation, fix k, call receipt-only RT burn,
    /// verify post-burn supply against E, pay floor(nativeRT_*1e18/k) existing sDETF to receiver_.
    /// Credit every unpaid gon to owner's R0, not receiver_. Enforce minNative_ atomically.
    function redeemSyRewardTokens(address owner_, address receiver_, uint256 nativeRT_, uint256 minNative_)
        external returns (uint256 nativeSDETF, uint256 retainedGons);
}
