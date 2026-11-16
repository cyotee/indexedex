// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IDetfStakingToken} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4DetfMigrationRewardToken, IUniswapV4DetfMigrationRewardTokenDFPkg} from
    "./IUniswapV4DetfMigrationRewardToken.sol";
import {UniswapV4DetfMigrationRewardTokenRepo as Repo} from "./UniswapV4DetfMigrationRewardTokenRepo.sol";

/// @notice Immutable local RT package on the existing generic callback factory.
/// @dev No registered-vault bypass: RT is not a vault package. No post-deployment mint authority setter.
contract UniswapV4DetfMigrationRewardTokenDFPkg is IUniswapV4DetfMigrationRewardTokenDFPkg {
    error ImmutableRewardTokenPackage();

    IFacet internal immutable REWARD_TOKEN_FACET;
    IDiamondPackageCallBackFactory internal immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit_) {
        if (address(pkgInit_.rewardTokenFacet) == address(0) || address(pkgInit_.diamondFactory) == address(0)) {
            revert InvalidMigrationRewardTokenArguments();
        }
        REWARD_TOKEN_FACET = pkgInit_.rewardTokenFacet;
        DIAMOND_FACTORY = pkgInit_.diamondFactory;
    }

    /// @inheritdoc IUniswapV4DetfMigrationRewardTokenDFPkg
    function deployToken(PkgArgs memory args_) external returns (address token_) {
        return address(DIAMOND_FACTORY.deploy(this, abi.encode(args_)));
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageName() public pure returns (string memory) {
        return type(UniswapV4DetfMigrationRewardTokenDFPkg).name;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetAddresses() public view returns (address[] memory facets_) {
        facets_ = new address[](1);
        facets_[0] = address(REWARD_TOKEN_FACET);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetInterfaces() public view returns (bytes4[] memory) {
        return REWARD_TOKEN_FACET.facetInterfaces();
    }

    /// @inheritdoc IDiamondFactoryPackage
    function packageMetadata()
        public view returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    /// @inheritdoc IDiamondFactoryPackage
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        cuts_ = new IDiamond.FacetCut[](1);
        cuts_[0] = IDiamond.FacetCut({
            facetAddress: address(REWARD_TOKEN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REWARD_TOKEN_FACET.facetFuncs()
        });
    }

    /// @inheritdoc IDiamondFactoryPackage
    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /// @inheritdoc IDiamondFactoryPackage
    function calcSalt(bytes memory pkgArgs_) public pure returns (bytes32) {
        return keccak256(abi.encode(pkgArgs_));
    }

    /// @inheritdoc IDiamondFactoryPackage
    function processArgs(bytes memory pkgArgs_) public view returns (bytes memory) {
        PkgArgs memory args_ = abi.decode(pkgArgs_, (PkgArgs));
        if (
            args_.parent == address(0) || args_.receipt == address(0) || args_.parent == args_.receipt
                || bytes(args_.name).length == 0 || bytes(args_.symbol).length == 0
                || keccak256(abi.encode(args_)) != keccak256(pkgArgs_)
        ) revert InvalidMigrationRewardTokenArguments();
        _requireBindings(args_.parent, args_.receipt);
        return pkgArgs_;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function initAccount(bytes memory initArgs_) public {
        PkgArgs memory args_ = abi.decode(processArgs(initArgs_), (PkgArgs));
        Repo._initialize(args_.parent, args_.receipt);
        ERC20Repo._initialize(args_.name, args_.symbol, 27);
    }

    /// @inheritdoc IDiamondFactoryPackage
    function updatePkg(address account_, bytes memory args_) public view returns (bool) {
        // The real factory invokes this before CREATE2. It cannot update an existing token.
        if (msg.sender != address(DIAMOND_FACTORY) || account_.code.length != 0) {
            revert ImmutableRewardTokenPackage();
        }
        processArgs(args_);
        return true;
    }

    /// @inheritdoc IDiamondFactoryPackage
    function postDeploy(address account_) public view returns (bool) {
        IUniswapV4DetfMigrationRewardToken token_ = IUniswapV4DetfMigrationRewardToken(account_);
        _requireBindings(token_.parent(), token_.receipt());
        if (token_.decimals() != 27 || token_.totalSupply() != 0 || token_.migrationAccountingPhase() != 0) {
            revert InvalidMigrationRewardTokenArguments();
        }
        return true;
    }

    function _requireBindings(address parent_, address receipt_) internal view {
        if (
            IStakedDETF(receipt_).detf() != parent_
                || address(IDetfStakingToken(parent_).rebasingClaimToken()) != receipt_
        ) revert InvalidMigrationRewardTokenArguments();
    }
}
