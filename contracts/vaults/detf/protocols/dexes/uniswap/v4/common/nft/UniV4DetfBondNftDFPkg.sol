// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

import {
    UniV4DetfBondNftRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftRepo.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";

interface IUniV4DetfBondNftDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet bondNftFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        address detf;
        IPoolManager poolManager;
        PoolKey poolKey;
        IERC20 pairToken;
        IERC20 detfToken;
        uint24 widthMultiplier;
        address owner;
        bytes32 optionalSalt;
    }

    function deployBondNft(PkgArgs memory args) external returns (address bondNft);
}

contract UniV4DetfBondNftDFPkg is IUniV4DetfBondNftDFPkg {
    using BetterEfficientHashLib for bytes;
    using PoolIdLibrary for PoolKey;

    IFacet immutable BOND_NFT_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        BOND_NFT_FACET = pkgInit.bondNftFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployBondNft(PkgArgs memory args) external returns (address bondNft) {
        bondNft = address(DIAMOND_FACTORY.deploy(this, abi.encode(args)));
    }

    function packageName() public pure returns (string memory) {
        return type(UniV4DetfBondNftDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](1);
        facetAddresses_[0] = address(BOND_NFT_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IUniV4DetfBondNft).interfaceId;
        interfaces_[1] = type(IUnlockCallback).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](1);
        facetCuts_[0] =
            IDiamond.FacetCut(address(BOND_NFT_FACET), IDiamond.FacetCutAction.Add, BOND_NFT_FACET.facetFuncs());
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        bool pairIs0 = address(args.pairToken) == Currency.unwrap(args.poolKey.currency0);
        UniV4DetfBondNftRepo._initialize(
            args.detf,
            args.poolManager,
            args.poolKey,
            args.poolKey.toId(),
            args.pairToken,
            args.detfToken,
            pairIs0,
            args.widthMultiplier,
            args.owner
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
