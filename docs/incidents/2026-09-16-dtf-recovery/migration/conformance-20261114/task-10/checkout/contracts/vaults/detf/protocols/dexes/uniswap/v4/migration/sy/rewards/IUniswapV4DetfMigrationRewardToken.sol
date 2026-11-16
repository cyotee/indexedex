// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IUniswapV4DetfMigrationAccounting} from "../../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Nonrebasing 27-decimal RT; each native token unit represents exactly 1e18 existing receipt gons.
/// @dev No token exists outside custody before activation. This is not another staking supply:
/// tokenized liability E=totalSupply()*1e18 remains physically within receipt escrow and totalGons.
interface IUniswapV4DetfMigrationRewardToken is IERC20Metadata, IUniswapV4DetfMigrationAccounting {
    error NotMigrationReceipt(address caller);
    error InvalidMigrationRewardReceiver(address receiver);

    event SyRewardTokenRedeemed(
        address indexed owner, address indexed receiver, uint256 nativeRT,
        uint256 nativeSDETF, uint256 retainedGons
    );

    /// @notice Fixed receipt only, inside its activation-gated R2 -> E transition.
    function mintByReceipt(address beneficiary_, uint256 amount_) external;

    /// @notice Fixed receipt only, including its admitted callback during this token's busy redemption.
    function burnByReceipt(address owner_, uint256 amount_) external;

    /// @notice Redeem the caller's native RT through the receipt's synchronized redemption entry.
    /// @dev Receipt burns, checks E/supply, and pays existing sDETF to a normal receiver.
    /// Retained gons belong to msg.sender's R0 even if receiver_ differs. Zero returns zero;
    /// a positive burn with zero native payout requires zero minimum and preserves all gons.
    function redeem(uint256 amount_, address receiver_, uint256 minimum_)
        external returns (uint256 nativeSDETF, uint256 retainedGons);

    /// @notice Native sDETF at the stored funded k: floor(amount_*1e18/k); does not authorize a claim.
    function previewRedeem(uint256 amount_) external view returns (uint256 nativeSDETF);

    /// @notice Once-bound funded receipt, the only mint/burn caller.
    function receipt() external view returns (address);

    /// @notice Once-bound Migration parent, sole activation authority.
    function parent() external view returns (address);
}

/// @notice Local generic callback-factory package, not a registered vault or external protocol rollout.
interface IUniswapV4DetfMigrationRewardTokenDFPkg is IDiamondFactoryPackage {
    /// @dev The selected facet implements the whole guarded RT ERC20/metadata/product surface.
    struct PkgInit {
        IFacet rewardTokenFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Parent/receipt are already wired. Verify receipt.detf()==parent and the parent's receipt
    /// pointer matches. Parent stores the resulting RT once, before deploying its two SY wrappers.
    /// Fixed decimals=27 and gons/native RT=1e18 are not configurable package arguments.
    struct PkgArgs {
        address parent;
        address receipt;
        string name;
        string symbol;
    }

    error InvalidMigrationRewardTokenArguments();

    /// @notice Deploy one once-initialized fixed-binding RT through the existing generic callback factory.
    function deployToken(PkgArgs memory args_) external returns (address token_);
}
