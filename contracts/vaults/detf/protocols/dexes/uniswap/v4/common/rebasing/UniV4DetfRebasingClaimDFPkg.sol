// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";

import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {
    UniV4DetfRebasingClaimRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimRepo.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";

/// @title IUniV4DetfRebasingClaimDFPkg
interface IUniV4DetfRebasingClaimDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet rebasingClaimFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IPoolManager poolManager;
        PoolKey poolKey;
        IERC20 pairToken;
        IERC20 detfToken;
        uint24 widthMultiplier;
        address owner;
        bytes32 optionalSalt;
    }

    function deployClaim(PkgArgs memory args) external returns (address claimAddress);
}

/// @title UniV4DetfRebasingClaimDFPkg
/// @notice Pure Crane DFPkg for per-DETF rebasing claim diamonds (not vault-registry).
contract UniV4DetfRebasingClaimDFPkg is IUniV4DetfRebasingClaimDFPkg {
    using BetterEfficientHashLib for bytes;
    using PoolIdLibrary for PoolKey;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable REBASING_CLAIM_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        REBASING_CLAIM_FACET = pkgInit.rebasingClaimFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployClaim(PkgArgs memory args) external returns (address claimAddress) {
        bytes32 salt = args.optionalSalt;
        if (salt == bytes32(0)) {
            salt = abi.encode(args.owner, address(args.pairToken), address(args.detfToken))._hash();
        }
        claimAddress = address(DIAMOND_FACTORY.deploy(this, abi.encode(args)));
    }

    function packageName() public pure returns (string memory) {
        return type(UniV4DetfRebasingClaimDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](4);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(REBASING_CLAIM_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](6);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IUniV4DetfRebasingClaim).interfaceId;
        interfaces_[5] = type(IUnlockCallback).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](4);
        facetCuts_[0] = IDiamond.FacetCut(address(ERC20_FACET), IDiamond.FacetCutAction.Add, ERC20_FACET.facetFuncs());
        facetCuts_[1] =
            IDiamond.FacetCut(address(ERC5267_FACET), IDiamond.FacetCutAction.Add, ERC5267_FACET.facetFuncs());
        facetCuts_[2] =
            IDiamond.FacetCut(address(ERC2612_FACET), IDiamond.FacetCutAction.Add, ERC2612_FACET.facetFuncs());
        facetCuts_[3] = IDiamond.FacetCut(
            address(REBASING_CLAIM_FACET), IDiamond.FacetCutAction.Add, REBASING_CLAIM_FACET.facetFuncs()
        );
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory processedArgs) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        bool pairIs0 = address(args.pairToken) == Currency.unwrap(args.poolKey.currency0);
        PoolId poolId = args.poolKey.toId();

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        UniV4DetfRebasingClaimRepo._initialize(
            args.poolManager,
            args.poolKey,
            poolId,
            args.pairToken,
            args.detfToken,
            pairIs0,
            args.widthMultiplier,
            args.owner
        );
        UniswapV4PositionRepo._initialize(args.widthMultiplier, keccak256("univ4.detf.rebasing.center"));
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
