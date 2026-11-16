// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {IUniswapV4ProtocolAware} from "@crane/contracts/interfaces/IUniswapV4ProtocolAware.sol";
import {IUniswapV4SinglePositionAware} from "@crane/contracts/interfaces/IUniswapV4SinglePositionAware.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {
    IStandardExchangeBundleIn,
    IStandardExchangeBundleOut
} from "./interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV4FullSpreadStandardExchangeVaultRepo.sol";

contract UniswapV4FullSpreadStandardExchangeVaultDFPkg is IUniswapV4FullSpreadStandardExchangeVaultDFPkg {
    using StateLibrary for IPoolManager;

    bytes4 private constant GET_RATE = bytes4(keccak256("getRate()"));
    bytes4 private constant RATE_ASSET = bytes4(keccak256("rateAsset()"));

    address private immutable SELF;
    IPoolManager private immutable MANAGER;
    address private immutable POSITION_DESCRIPTOR;
    address private immutable POSITION_MANAGER;
    address private immutable QUOTER;
    address private immutable STATE_VIEW;
    address private immutable RESERVES_LENS;
    address private immutable UNIVERSAL_ROUTER;
    IVaultRegistryDeployment private immutable REGISTRY;
    IVaultFeeOracleQuery private immutable ORACLE;
    address private immutable WETH;
    IDiamondPackageCallBackFactory private immutable DIAMOND_FACTORY;
    bytes32 public immutable bindingHash;
    IFacet[] private components;
    bytes4[][] private componentFunctions;
    bytes4[] private declaredInterfaces;
    address[6] private linkedLibraries;

    constructor(PkgInit memory init_) {
        if (
            address(init_.poolManager).code.length == 0 || address(init_.registry).code.length == 0
                || address(init_.oracle).code.length == 0 || address(init_.diamondFactory).code.length == 0
                || address(init_.weth).code.length == 0 || init_.positionDescriptor.code.length == 0
                || init_.positionManager.code.length == 0 || init_.quoter.code.length == 0
                || init_.stateView.code.length == 0 || init_.reservesLens.code.length == 0
                || init_.universalRouter.code.length == 0
        ) revert InvalidComponent();
        SELF = address(this);
        MANAGER = init_.poolManager;
        POSITION_DESCRIPTOR = init_.positionDescriptor;
        POSITION_MANAGER = init_.positionManager;
        QUOTER = init_.quoter;
        STATE_VIEW = init_.stateView;
        RESERVES_LENS = init_.reservesLens;
        UNIVERSAL_ROUTER = init_.universalRouter;
        REGISTRY = init_.registry;
        ORACLE = init_.oracle;
        WETH = address(init_.weth);
        DIAMOND_FACTORY = init_.diamondFactory;
        bindingHash = keccak256(abi.encode(init_));
        linkedLibraries = init_.linkedLibraries;
        for (uint256 i_; i_ < linkedLibraries.length; ++i_) {
            if (linkedLibraries[i_].code.length == 0) revert InvalidComponent();
        }
        _append(init_.erc20Facet, 0);
        _append(init_.erc2612Facet, 1);
        _append(init_.erc5267Facet, 2);
        _append(init_.basicVaultFacet, 3);
        _append(init_.standardVaultFacet, 4);
        _append(init_.moneyFacet, 5);
        _append(init_.quoteFacet, 6);
        _append(init_.outFacet, 7);
        _append(init_.queryFacet, 8);
        _append(init_.callbackFacet, 9);
        _append(init_.uniswapV4ProtocolAwareFacet, 10);
        _append(init_.uniswapV4SinglePositionAwareFacet, 11);
    }

    function name() public pure returns (string memory) {
        return packageName();
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4FullSpreadStandardExchangeVaultDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public view returns (bytes4[] memory) {
        return facetInterfaces();
    }

    function vaultDeclaration() external view returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration(packageName(), bytes32(0), facetInterfaces());
    }

    function facetInterfaces() public view returns (bytes4[] memory interfaces_) {
        if (address(this) != SELF) return IUniswapV4FullSpreadStandardExchangeVaultDFPkg(SELF).facetInterfaces();
        return declaredInterfaces;
    }

    function facetAddresses() public view returns (address[] memory addresses_) {
        if (address(this) != SELF) return IUniswapV4FullSpreadStandardExchangeVaultDFPkg(SELF).facetAddresses();
        addresses_ = new address[](components.length);
        for (uint256 i_; i_ < components.length; ++i_) addresses_[i_] = address(components[i_]);
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        if (address(this) != SELF) return IUniswapV4FullSpreadStandardExchangeVaultDFPkg(SELF).facetCuts();
        cuts_ = new IDiamond.FacetCut[](components.length);
        for (uint256 i_; i_ < components.length; ++i_) {
            cuts_[i_] = IDiamond.FacetCut(address(components[i_]), IDiamond.FacetCutAction.Add, componentFunctions[i_]);
        }
    }

    function diamondConfig() external view returns (DiamondConfig memory) {
        return DiamondConfig(facetCuts(), facetInterfaces());
    }

    function packageMetadata() external view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    function calcSalt(bytes memory args_) public view returns (bytes32) {
        return keccak256(abi.encode(bindingHash, abi.decode(args_, (PkgArgs))));
    }

    function processArgs(bytes memory args_) external view returns (bytes memory) {
        if (msg.sender != address(REGISTRY) || address(this) != address(DIAMOND_FACTORY)) revert NotCalledByRegistry();
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        _validate(decoded_);
        return abi.encode(decoded_);
    }

    function deployVault(PkgArgs memory args_) external returns (address) {
        return REGISTRY.deployVault(this, abi.encode(args_));
    }

    function initAccount(bytes memory args_) external {
        if (
            address(this) == SELF || address(DIAMOND_FACTORY.pkgOfAccount(address(this))) != SELF
                || keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(address(this))) != keccak256(args_)
        ) revert InvalidInitializationContext();
        if (Repo._layoutStruct().initialized) revert AlreadyInitialized();
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        _validate(decoded_);
        Repo._layoutStruct().initialized = true;
        UniswapV4ProtocolAwareRepo._initialize(
            MANAGER, POSITION_DESCRIPTOR, POSITION_MANAGER, QUOTER, STATE_VIEW, RESERVES_LENS, UNIVERSAL_ROUTER
        );
        WETHAwareRepo._setWeth(IWETH(WETH));
        int24 lower_ = TickMath.minUsableTick(decoded_.poolKey.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(decoded_.poolKey.tickSpacing);
        UniswapV4SinglePositionAwareRepo._initialize(decoded_.poolKey, lower_, upper_, bytes32(0));
        string memory name_ = _shareName(decoded_.poolKey);
        ERC20Repo._initialize(name_, "UV4X", 18);
        EIP712Repo._initialize(name_, "1");
        address[] memory faces_ = _faces(decoded_.poolKey);
        MultiAssetBasicVaultRepo._initialize(faces_);
        StandardVaultRepo._initialize(ORACLE, bytes32(0), facetInterfaces(), keccak256(abi.encode(faces_)));
    }

    function updatePkg(address account_, bytes memory args_) external view returns (bool) {
        _requireFactoryAccount(account_);
        if (keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(account_)) != keccak256(args_)) revert InvalidInitializationContext();
        return true;
    }

    function postDeploy(address account_) external view returns (bool) {
        _requireFactoryAccount(account_);
        return true;
    }

    function _requireFactoryAccount(address account_) private view {
        if (address(this) != SELF || msg.sender != address(DIAMOND_FACTORY) || address(DIAMOND_FACTORY.pkgOfAccount(account_)) != SELF) {
            revert InvalidInitializationContext();
        }
    }

    function _validate(PkgArgs memory args_) private view {
        if (address(args_.poolKey.hooks) != address(0)) revert InvalidPoolKey();
        (uint160 price_,,,) = MANAGER.getSlot0(args_.poolKey.toId());
        if (price_ == 0) revert InvalidPoolKey();
    }

    function _shareName(PoolKey memory key_) private view returns (string memory) {
        address[] memory faces_ = _faces(key_);
        return string.concat(
            "UniV4 Vault of (",
            IERC20Metadata(faces_[0]).symbol(),
            " / ",
            IERC20Metadata(faces_[1]).symbol(),
            " ",
            _feeLabel(key_.fee),
            ")"
        );
    }

    function _feeLabel(uint24 fee_) private pure returns (string memory) {
        if (fee_ == 100) return "0.01%";
        if (fee_ == 500) return "0.05%";
        if (fee_ == 3000) return "0.3%";
        if (fee_ == 10000) return "1%";
        return "fee";
    }

    function _faces(PoolKey memory key_) private view returns (address[] memory faces_) {
        faces_ = new address[](2);
        faces_[0] = Currency.unwrap(key_.currency0);
        if (faces_[0] == address(0)) faces_[0] = WETH;
        faces_[1] = Currency.unwrap(key_.currency1);
        if (faces_[1] == address(0)) faces_[1] = WETH;
    }

    function _append(IFacet facet_, uint256 index_) private {
        if (address(facet_).code.length == 0) revert InvalidComponent();
        if (index_ >= 5 && index_ <= 9) {
            if (keccak256(abi.encode(IComponentBindings(address(facet_)).linkedComponents())) != keccak256(abi.encode(linkedLibraries))) {
                revert InvalidComponent();
            }
        }
        bytes4[] memory funcs_ = _installed(facet_, index_);
        for (uint256 i_; i_ < funcs_.length; ++i_) {
            if (funcs_[i_] == GET_RATE || funcs_[i_] == RATE_ASSET) revert InvalidComponent();
        }
        components.push(facet_);
        componentFunctions.push(funcs_);
        bytes4[] memory ids_ = facet_.facetInterfaces();
        for (uint256 i_; i_ < ids_.length; ++i_) {
            bool found_;
            for (uint256 j_; j_ < declaredInterfaces.length; ++j_) {
                if (declaredInterfaces[j_] == ids_[i_]) found_ = true;
            }
            if (!found_) declaredInterfaces.push(ids_[i_]);
        }
    }

    function _installed(IFacet facet_, uint256 index_) private view returns (bytes4[] memory installed_) {
        bytes4[] memory expected_ = _expected(index_);
        bytes4[] memory funcs_ = facet_.facetFuncs();
        if (index_ == 3) {
            installed_ = expected_;
            bool found_;
            for (uint256 i_; i_ < funcs_.length; ++i_) if (funcs_[i_] == IBasicVault.vaultTokens.selector) found_ = true;
            if (!found_) revert InvalidComponent();
            return installed_;
        }
        if (funcs_.length != expected_.length) revert InvalidComponent();
        for (uint256 i_; i_ < expected_.length; ++i_) {
            bool found_;
            for (uint256 j_; j_ < funcs_.length; ++j_) if (funcs_[j_] == expected_[i_]) found_ = true;
            if (!found_) revert InvalidComponent();
        }
        return expected_;
    }

    function _expected(uint256 index_) private pure returns (bytes4[] memory selectors_) {
        if (index_ == 0) {
            selectors_ = new bytes4[](9);
            selectors_[0] = IERC20Metadata.name.selector;
            selectors_[1] = IERC20Metadata.symbol.selector;
            selectors_[2] = IERC20Metadata.decimals.selector;
            selectors_[3] = IERC20.totalSupply.selector;
            selectors_[4] = IERC20.balanceOf.selector;
            selectors_[5] = IERC20.allowance.selector;
            selectors_[6] = IERC20.approve.selector;
            selectors_[7] = IERC20.transfer.selector;
            selectors_[8] = IERC20.transferFrom.selector;
            return selectors_;
        }
        if (index_ == 1) {
            selectors_ = new bytes4[](3);
            selectors_[0] = IERC20Permit.permit.selector;
            selectors_[1] = IERC20Permit.nonces.selector;
            selectors_[2] = IERC20Permit.DOMAIN_SEPARATOR.selector;
            return selectors_;
        }
        if (index_ == 2) {
            selectors_ = new bytes4[](1);
            selectors_[0] = IERC5267.eip712Domain.selector;
            return selectors_;
        }
        if (index_ == 3) {
            selectors_ = new bytes4[](1);
            selectors_[0] = IBasicVault.vaultTokens.selector;
            return selectors_;
        }
        if (index_ == 4) {
            selectors_ = new bytes4[](4);
            selectors_[0] = IStandardVault.vaultFeeTypeIds.selector;
            selectors_[1] = IStandardVault.contentsId.selector;
            selectors_[2] = IStandardVault.vaultTypes.selector;
            selectors_[3] = IStandardVault.vaultConfig.selector;
            return selectors_;
        }
        if (index_ == 5) {
            selectors_ = new bytes4[](7);
            selectors_[0] = IStandardExchangeIn.exchangeIn.selector;
            selectors_[1] = IStandardExchangeBundleIn.exchangeBundleInForSingleOut.selector;
            selectors_[2] = IStandardExchangeBundleOut.exchangeBundleOut.selector;
            selectors_[3] = IVault.donate.selector;
            selectors_[4] = IVault.compound.selector;
            selectors_[5] = IOperable.setOperator.selector;
            selectors_[6] = IOperable.setOperatorFor.selector;
            return selectors_;
        }
        if (index_ == 6) {
            selectors_ = new bytes4[](3);
            selectors_[0] = IStandardExchangeIn.previewExchangeIn.selector;
            selectors_[1] = IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut.selector;
            selectors_[2] = IStandardExchangeBundleOut.previewExchangeBundleOut.selector;
            return selectors_;
        }
        if (index_ == 7) {
            selectors_ = new bytes4[](2);
            selectors_[0] = IStandardExchangeOut.previewExchangeOut.selector;
            selectors_[1] = IStandardExchangeOut.exchangeOut.selector;
            return selectors_;
        }
        if (index_ == 8) {
            selectors_ = new bytes4[](2);
            selectors_[0] = IBasicVault.reserveOfToken.selector;
            selectors_[1] = IBasicVault.reserves.selector;
            return selectors_;
        }
        if (index_ == 9) {
            selectors_ = new bytes4[](1);
            selectors_[0] = IUnlockCallback.unlockCallback.selector;
            return selectors_;
        }
        if (index_ == 10) {
            selectors_ = new bytes4[](7);
            selectors_[0] = IUniswapV4ProtocolAware.poolManager.selector;
            selectors_[1] = IUniswapV4ProtocolAware.positionDescriptor.selector;
            selectors_[2] = IUniswapV4ProtocolAware.positionManager.selector;
            selectors_[3] = IUniswapV4ProtocolAware.quoter.selector;
            selectors_[4] = IUniswapV4ProtocolAware.stateView.selector;
            selectors_[5] = IUniswapV4ProtocolAware.reservesLens.selector;
            selectors_[6] = IUniswapV4ProtocolAware.universalRouter.selector;
            return selectors_;
        }
        if (index_ == 11) {
            selectors_ = new bytes4[](5);
            selectors_[0] = IUniswapV4SinglePositionAware.poolKey.selector;
            selectors_[1] = IUniswapV4SinglePositionAware.tickLower.selector;
            selectors_[2] = IUniswapV4SinglePositionAware.tickUpper.selector;
            selectors_[3] = IUniswapV4SinglePositionAware.positionSalt.selector;
            selectors_[4] = IUniswapV4SinglePositionAware.positionLiquidity.selector;
            return selectors_;
        }
        revert InvalidComponent();
    }
}
