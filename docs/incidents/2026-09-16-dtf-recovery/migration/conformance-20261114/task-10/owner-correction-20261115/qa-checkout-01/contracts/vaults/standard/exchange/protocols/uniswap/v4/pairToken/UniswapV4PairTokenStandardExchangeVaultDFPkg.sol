// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg} from "./interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {IUniswapV4PairTokenStandardExchangeVaultComponentBindings as IComponentBindings} from "./UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultDFPkg[]
/// @notice Immutable, registry-deployed full-range vault composition.
/// @dev Package arrays are read through SELF when running in another account's context.
contract UniswapV4PairTokenStandardExchangeVaultDFPkg is IUniswapV4PairTokenStandardExchangeVaultDFPkg {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address private immutable SELF;
    IPoolManager private immutable MANAGER;
    IVaultRegistryDeployment private immutable REGISTRY;
    IVaultFeeOracleQuery private immutable ORACLE;
    address private immutable WRAPPED_NATIVE;
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
        ) revert InvalidComponent();
        if (address(init_.wrappedNative).code.length == 0) revert InvalidWrappedNative();
        if (IERC20Metadata(address(init_.wrappedNative)).decimals() != 18) revert InvalidWrappedNative();
        // An ordinary 18-decimal ERC20 is not a native wrapper. Probe both
        // zero-unit interface operations without funding or retaining inventory.
        uint256 wrapperBalance_ = init_.wrappedNative.balanceOf(address(this));
        try init_.wrappedNative.deposit() {} catch { revert InvalidWrappedNative(); }
        try init_.wrappedNative.withdraw(0) {} catch { revert InvalidWrappedNative(); }
        if (init_.wrappedNative.balanceOf(address(this)) != wrapperBalance_) revert InvalidWrappedNative();
        SELF = address(this);
        MANAGER = init_.poolManager;
        REGISTRY = init_.registry;
        ORACLE = init_.oracle;
        WRAPPED_NATIVE = address(init_.wrappedNative);
        DIAMOND_FACTORY = init_.diamondFactory;
        bindingHash = keccak256(abi.encode(init_));
        linkedLibraries = init_.linkedLibraries;
        bool validLinks_ = true;
        for (uint256 i_ = 0; i_ < linkedLibraries.length; ++i_) {
            if (linkedLibraries[i_].code.length == 0) validLinks_ = false;
        }
        if (!validLinks_) revert InvalidComponent();
        _appendComponent(init_.erc20Facet, 0);
        _appendComponent(init_.erc2612Facet, 1);
        _appendComponent(init_.erc5267Facet, 2);
        _appendComponent(init_.basicVaultFacet, 3);
        _appendComponent(init_.standardVaultFacet, 4);
        _appendComponent(init_.moneyFacet, 5);
        _appendComponent(init_.quoteFacet, 6);
        _appendComponent(init_.outFacet, 7);
        _appendComponent(init_.queryFacet, 8);
        _appendComponent(init_.syMoneyFacet, 9);
        _appendComponent(init_.syQueryFacet, 10);
        _appendComponent(init_.callbackFacet, 11);
    }

    // tag::name-06fdde03[]
    /// @inheritdoc IStandardVaultPkg
    /// @custom:signature name()
    /// @custom:selector 0x06fdde03
    function name() public pure returns (string memory) {
        return packageName();
    }
    // end::name-06fdde03[]

    // tag::packageName-abc8b346[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature packageName()
    /// @custom:selector 0xabc8b346
    function packageName() public pure returns (string memory) {
        return type(UniswapV4PairTokenStandardExchangeVaultDFPkg).name;
    }
    // end::packageName-abc8b346[]

    // tag::vaultFeeTypeIds-6a4d3f12[]
    /// @inheritdoc IStandardVaultPkg
    /// @custom:signature vaultFeeTypeIds()
    /// @custom:selector 0x6a4d3f12
    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }
    // end::vaultFeeTypeIds-6a4d3f12[]

    // tag::vaultTypes-36abf3dc[]
    /// @inheritdoc IStandardVaultPkg
    /// @custom:signature vaultTypes()
    /// @custom:selector 0x36abf3dc
    function vaultTypes() public view returns (bytes4[] memory) {
        return facetInterfaces();
    }
    // end::vaultTypes-36abf3dc[]

    // tag::vaultDeclaration-f4efa66f[]
    /// @inheritdoc IStandardVaultPkg
    /// @custom:signature vaultDeclaration()
    /// @custom:selector 0xf4efa66f
    function vaultDeclaration() external view returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration(packageName(), bytes32(0), facetInterfaces());
    }
    // end::vaultDeclaration-f4efa66f[]

    // tag::facetInterfaces-2ea80826[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature facetInterfaces()
    /// @custom:selector 0x2ea80826
    function facetInterfaces() public view returns (bytes4[] memory interfaces_) {
        if (address(this) != SELF) {
            return IUniswapV4PairTokenStandardExchangeVaultDFPkg(SELF).facetInterfaces();
        }
        return declaredInterfaces;
    }
    // end::facetInterfaces-2ea80826[]

    // tag::facetAddresses-52ef6b2c[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature facetAddresses()
    /// @custom:selector 0x52ef6b2c
    function facetAddresses() public view returns (address[] memory addresses_) {
        if (address(this) != SELF) {
            return IUniswapV4PairTokenStandardExchangeVaultDFPkg(SELF).facetAddresses();
        }
        addresses_ = new address[](components.length);
        for (uint256 i_ = 0; i_ < components.length; ++i_) addresses_[i_] = address(components[i_]);
    }
    // end::facetAddresses-52ef6b2c[]

    // tag::facetCuts-a4b3ad35[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature facetCuts()
    /// @custom:selector 0xa4b3ad35
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        if (address(this) != SELF) {
            return IUniswapV4PairTokenStandardExchangeVaultDFPkg(SELF).facetCuts();
        }
        cuts_ = new IDiamond.FacetCut[](components.length);
        for (uint256 i_ = 0; i_ < components.length; ++i_) {
            cuts_[i_] = IDiamond.FacetCut(
                address(components[i_]), IDiamond.FacetCutAction.Add, componentFunctions[i_]
            );
        }
    }
    // end::facetCuts-a4b3ad35[]

    // tag::diamondConfig-65d375b3[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature diamondConfig()
    /// @custom:selector 0x65d375b3
    function diamondConfig() external view returns (DiamondConfig memory) {
        return DiamondConfig(facetCuts(), facetInterfaces());
    }
    // end::diamondConfig-65d375b3[]

    // tag::packageMetadata-f45469e7[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature packageMetadata()
    /// @custom:selector 0xf45469e7
    function packageMetadata() external view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }
    // end::packageMetadata-f45469e7[]

    // tag::calcSalt-d82be56e[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature calcSalt(bytes)
    /// @custom:selector 0xd82be56e
    function calcSalt(bytes memory args_) public view returns (bytes32) {
        return keccak256(abi.encode(bindingHash, abi.decode(args_, (PkgArgs))));
    }
    // end::calcSalt-d82be56e[]

    // tag::processArgs-87c3adb3[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature processArgs(bytes)
    /// @custom:selector 0x87c3adb3
    function processArgs(bytes memory args_) external view returns (bytes memory) {
        if (msg.sender != address(REGISTRY) || address(this) != address(DIAMOND_FACTORY)) {
            revert NotCalledByRegistry();
        }
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        _validate(decoded_);
        return abi.encode(decoded_);
    }
    // end::processArgs-87c3adb3[]

    // tag::deployVault-15a4ac82[]
    /// @inheritdoc IUniswapV4PairTokenStandardExchangeVaultDFPkg
    /// @custom:signature deployVault(((address,address,uint24,int24,address),address,string,string,uint16,int24))
    /// @custom:selector 0x15a4ac82
    function deployVault(PkgArgs memory args_) external returns (address) {
        return REGISTRY.deployVault(this, abi.encode(args_));
    }
    // end::deployVault-15a4ac82[]

    // tag::initAccount-870d4838[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature initAccount(bytes)
    /// @custom:selector 0x870d4838
    function initAccount(bytes memory args_) external {
        if (
            address(this) == SELF || address(DIAMOND_FACTORY.pkgOfAccount(address(this))) != SELF
                || keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(address(this))) != keccak256(args_)
        ) revert InvalidInitializationContext();
        Repo.Storage storage state_ = Repo._layoutStruct();
        if (state_.initialized) revert AlreadyInitialized();
        PkgArgs memory decoded_ = abi.decode(args_, (PkgArgs));
        if (keccak256(args_) != keccak256(abi.encode(decoded_))) revert InvalidInitializationContext();
        uint8 rateDecimals_ = _validate(decoded_);
        state_.initialized = true;
        state_.config = Types.Config({
            poolManager: MANAGER,
            poolKey: decoded_.poolKey,
            registry: address(REGISTRY),
            wrappedNative: WRAPPED_NATIVE,
            rateAsset: decoded_.rateAsset,
            tickLower: TickMath.minUsableTick(decoded_.poolKey.tickSpacing),
            tickUpper: TickMath.maxUsableTick(decoded_.poolKey.tickSpacing),
            maxZapBps: decoded_.maxZapBps,
            maxZapTickMove: decoded_.maxZapTickMove,
            rateAssetDecimals: rateDecimals_
        });
        ERC20Repo._initialize(decoded_.name, decoded_.symbol, 18);
        EIP712Repo._initialize(decoded_.name, "1");
        address[] memory faces_ = _faces(decoded_.poolKey);
        MultiAssetBasicVaultRepo._initialize(faces_);
        if (faces_[0] > faces_[1]) (faces_[0], faces_[1]) = (faces_[1], faces_[0]);
        StandardVaultRepo._initialize(ORACLE, bytes32(0), facetInterfaces(), keccak256(abi.encode(faces_)));
    }
    // end::initAccount-870d4838[]

    // tag::updatePkg-a9089235[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature updatePkg(address,bytes)
    /// @custom:selector 0xa9089235
    function updatePkg(address account_, bytes memory args_) external view returns (bool) {
        _requireFactoryAccount(account_);
        if (keccak256(DIAMOND_FACTORY.pkgArgsOfAccount(account_)) != keccak256(args_)) {
            revert InvalidInitializationContext();
        }
        return true;
    }
    // end::updatePkg-a9089235[]

    // tag::postDeploy-70068fcf[]
    /// @inheritdoc IDiamondFactoryPackage
    /// @custom:signature postDeploy(address)
    /// @custom:selector 0x70068fcf
    function postDeploy(address account_) external view returns (bool) {
        _requireFactoryAccount(account_);
        return true;
    }
    // end::postDeploy-70068fcf[]

    function _requireFactoryAccount(address account_) private view {
        if (
            address(this) != SELF || msg.sender != address(DIAMOND_FACTORY)
                || address(DIAMOND_FACTORY.pkgOfAccount(account_)) != SELF
        ) revert InvalidInitializationContext();
    }

    function _validate(PkgArgs memory args_) private view returns (uint8) {
        address token0_ = Currency.unwrap(args_.poolKey.currency0);
        address token1_ = Currency.unwrap(args_.poolKey.currency1);
        if (
            token0_ >= token1_ || token1_.code.length == 0 || (token0_ != address(0) && token0_.code.length == 0)
                || address(args_.poolKey.hooks) != address(0) || args_.poolKey.fee > 1_000_000
                || args_.poolKey.tickSpacing <= 0 || args_.poolKey.tickSpacing > 32767
                || token0_ == address(this) || token1_ == address(this)
        ) revert InvalidPoolKey();
        address[] memory faces_ = _faces(args_.poolKey);
        if (faces_[0] == faces_[1]) revert InvalidWrappedNative();
        if (args_.rateAsset != faces_[0] && args_.rateAsset != faces_[1]) revert InvalidRateAsset();
        if (args_.maxZapBps == 0 || args_.maxZapBps > 10_000 || args_.maxZapTickMove < 0) {
            revert InvalidZapLimits();
        }
        (uint160 price_,,,) = MANAGER.getSlot0(args_.poolKey.toId());
        if (price_ == 0) revert InvalidPoolKey();
        // Metadata is validated here and cached at initialization, never normalized into the rate.
        return IERC20Metadata(args_.rateAsset).decimals();
    }

    function _faces(PoolKey memory key_) private view returns (address[] memory faces_) {
        faces_ = new address[](2);
        faces_[0] = Currency.unwrap(key_.currency0);
        if (faces_[0] == address(0)) faces_[0] = WRAPPED_NATIVE;
        faces_[1] = Currency.unwrap(key_.currency1);
    }

    function _appendComponent(IFacet facet_, uint256 index_) private {
        if (address(facet_).code.length == 0) revert InvalidComponent();
        if (
            index_ >= 5
                && keccak256(abi.encode(IComponentBindings(address(facet_)).linkedComponents()))
                    != keccak256(abi.encode(linkedLibraries))
        ) revert InvalidComponent();
        bytes4[] memory funcs_ = facet_.facetFuncs();
        bytes4[] memory expected_ = _expectedSelectors(index_);
        if (funcs_.length != expected_.length) revert InvalidComponent();
        bool valid_ = true;
        for (uint256 j_ = 0; j_ < funcs_.length; ++j_) {
            bool found_ = false;
            for (uint256 k_ = 0; k_ < expected_.length; ++k_) {
                if (funcs_[j_] == expected_[k_]) found_ = true;
            }
            valid_ = valid_ && found_;
            for (uint256 k_ = 0; k_ < j_; ++k_) {
                if (funcs_[k_] == funcs_[j_]) valid_ = false;
            }
        }
        if (!valid_) revert InvalidComponent();
        components.push(facet_);
        componentFunctions.push(funcs_);
        bytes4[] memory ids_ = facet_.facetInterfaces();
        for (uint256 j_ = 0; j_ < ids_.length; ++j_) {
            bool found_ = false;
            for (uint256 k_ = 0; k_ < declaredInterfaces.length; ++k_) {
                if (declaredInterfaces[k_] == ids_[j_]) found_ = true;
            }
            if (!found_) declaredInterfaces.push(ids_[j_]);
        }
    }

    function _expectedSelectors(uint256 index_) private pure returns (bytes4[] memory selectors_) {
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
            selectors_ = new bytes4[](3);
            selectors_[0] = IBasicVault.vaultTokens.selector;
            selectors_[1] = IBasicVault.reserveOfToken.selector;
            selectors_[2] = IBasicVault.reserves.selector;
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
            selectors_ = new bytes4[](5);
            selectors_[0] = IStandardExchangeIn.exchangeIn.selector;
            selectors_[1] = IVault.depositPair.selector;
            selectors_[2] = IVault.redeemPair.selector;
            selectors_[3] = IVault.donate.selector;
            selectors_[4] = IVault.compound.selector;
            return selectors_;
        }
        if (index_ == 6) {
            selectors_ = new bytes4[](5);
            selectors_[0] = IStandardExchangeIn.previewExchangeIn.selector;
            selectors_[1] = IVault.previewDepositPair.selector;
            selectors_[2] = IVault.previewRedeemPair.selector;
            selectors_[3] = IVault.previewWithdrawalMode.selector;
            selectors_[4] = IVault.previewZapCredit.selector;
            return selectors_;
        }
        if (index_ == 7) {
            selectors_ = new bytes4[](2);
            selectors_[0] = IStandardExchangeOut.previewExchangeOut.selector;
            selectors_[1] = IStandardExchangeOut.exchangeOut.selector;
            return selectors_;
        }
        if (index_ == 8) {
            selectors_ = new bytes4[](11);
            selectors_[0] = IVault.poolManager.selector;
            selectors_[1] = IVault.poolKey.selector;
            selectors_[2] = IVault.wrappedNative.selector;
            selectors_[3] = IVault.rateAsset.selector;
            selectors_[4] = IVault.tickLower.selector;
            selectors_[5] = IVault.tickUpper.selector;
            selectors_[6] = IVault.positionLiquidity.selector;
            selectors_[7] = IVault.localReserves.selector;
            selectors_[8] = IVault.basket.selector;
            selectors_[9] = IVault.maxZapBps.selector;
            selectors_[10] = IVault.maxZapTickMove.selector;
            return selectors_;
        }
        if (index_ == 9) {
            selectors_ = new bytes4[](4);
            selectors_[0] = IStandardizedYield.deposit.selector;
            selectors_[1] = IStandardizedYield.redeem.selector;
            selectors_[2] = IStandardizedYield.rewardIndexesCurrent.selector;
            selectors_[3] = IStandardizedYield.claimRewards.selector;
            return selectors_;
        }
        if (index_ == 10) {
            selectors_ = new bytes4[](12);
            selectors_[0] = IStandardizedYield.previewDeposit.selector;
            selectors_[1] = IStandardizedYield.previewRedeem.selector;
            selectors_[2] = IStandardizedYield.getTokensIn.selector;
            selectors_[3] = IStandardizedYield.getTokensOut.selector;
            selectors_[4] = IStandardizedYield.yieldToken.selector;
            selectors_[5] = IStandardizedYield.assetInfo.selector;
            selectors_[6] = IStandardizedYield.exchangeRate.selector;
            selectors_[7] = IStandardizedYield.isValidTokenIn.selector;
            selectors_[8] = IStandardizedYield.isValidTokenOut.selector;
            selectors_[9] = IStandardizedYield.getRewardTokens.selector;
            selectors_[10] = IStandardizedYield.accruedRewards.selector;
            selectors_[11] = IStandardizedYield.rewardIndexesStored.selector;
            return selectors_;
        }
        if (index_ == 11) {
            selectors_ = new bytes4[](1);
            selectors_[0] = IUnlockCallback.unlockCallback.selector;
            return selectors_;
        }
        revert InvalidComponent();
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultDFPkg[]
