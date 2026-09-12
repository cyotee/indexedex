// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
// Ensure PoolManager artifact is built under the default hermetic profile.
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals
 * @notice CP buffer hook with combo-decimal `pairToken` / `rawToken`. Does not call gold setUp.
 * @dev `pairToken` is the SE asset / pair role. `rawToken` is the other door. After PoolKey sort,
 *      `currency0`/`currency1` may swap roles; amounts use `_humanFor`. vaultShare / hook LP stay 18.
 */
abstract contract TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals is
    TestBase_ERC4626StandardExchange
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    MintableERC20Decimals internal rawToken;
    MintableERC20Decimals internal pairToken;
    SimpleYieldERC4626 internal pairProtocolVault;
    address internal se;
    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal hook;
    IHook internal single;
    PoolKey internal poolKey;
    address internal user = address(0xBEEF);

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant DUST = 10;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function _pairDecimals() internal pure virtual returns (uint8);
    function _rawDecimals() internal pure virtual returns (uint8);

    function _uPair(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_pairDecimals()));
    }

    function _uRaw(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_rawDecimals()));
    }

    /// @dev Mixed ConstProd inverse: 0.01% relative, 1e9 floor, 5% cap (UniV2/Dual decimals).
    function _invSlack(uint256 x) internal pure returns (uint256) {
        uint256 rel = x / 10_000;
        uint256 s = rel > 1e9 ? rel : 1e9;
        if (s == 0) s = 1;
        uint256 cap = x / 20;
        if (cap < 10) cap = 10;
        return s > cap ? cap : s;
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();

        // Product PullLib uses the Uniswap well-known Permit2 address; etch hermetic bytecode there.
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        rawToken = new MintableERC20Decimals("Raw", "RAW", _rawDecimals());
        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        pairProtocolVault = new SimpleYieldERC4626(pairToken);
        se = _deployERC4626SE(address(pairProtocolVault));

        pm = IPoolManager(address(new PoolManager(address(this))));

        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        IFacet seFacet = PkgFactory.deploySeFacet(create3Factory);
        IFacet depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                seFacet: seFacet,
                depositFacet: depositFacet,
                depositSingleFacet: PkgFactory.deployDepositSingleFacet(create3Factory),
                depositPreviewFacet: PkgFactory.deployDepositPreviewFacet(create3Factory),
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(
                type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name,
                "v1",
                _pairDecimals(),
                _rawDecimals()
            )._hash()
        );

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        single = IHook(hook);
        _bindProductPoolKey();

        rawToken.mint(user, _uRaw(1_000_000));
        pairToken.mint(user, _uPair(1_000_000));
        rawToken.mint(owner, _uRaw(1_000_000));
        pairToken.mint(owner, _uPair(1_000_000));
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        IERC20(se).approve(hook, type(uint256).max);
        IERC20(se).approve(se, type(uint256).max);
        vm.stopPrank();
        vm.startPrank(owner);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Mint pair, buffer into SE, leave SE shares on `user` (B6 funding helper).
    function _mintSeSharesToUser(uint256 pairAmount) internal returns (uint256 seShares) {
        pairToken.mint(user, pairAmount);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        seShares = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            pairAmount,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice B6 proportional deposit: face raw + SE vault shares for buffered leg.
    function _depositBothSeShares(uint256 amtRaw, uint256 amtSe) internal returns (uint256 lp) {
        vm.prank(user);
        (lp,,) = single.depositWithSeShares(amtRaw, amtSe, user, 0, block.timestamp + 1 hours);
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory)
    {
        return IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange: se,
            pairToken: address(pairToken),
            rawToken: address(rawToken),
            pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(address(pairToken)),
            rawTokenDecimals: address(rawToken).code.length == 0 ? uint8(18) : HookPkgArgsDecimalsLib.tokenDec(address(rawToken)),
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
    }

    function _pkgOwnerOnlyLiquidity() internal view virtual returns (bool) {
        return false;
    }

    function _pkgOwner() internal view virtual returns (address) {
        return owner;
    }

    /// @notice S42: one public product door then finalize. Not pm.initialize.
    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(hook_, address(rawToken), address(pairToken));
    }

    function _ensureProductDoorsAndFinalize(address hook_, address tokenA_, address tokenB_)
        internal
    {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(tokenA_, tokenB_);
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    /// @notice Construct the product PoolKey. Door is already live after S42; do not initialize.
    function _bindProductPoolKey() internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(single.currency0()),
            currency1: Currency.wrap(single.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    /// @dev Kept for existing product specs. Constructs the live product key; does not initialize.
    function _initPool() internal {
        _bindProductPoolKey();
    }

    function _amountForCurrency(address currency, uint256 amtRaw, uint256 amtPair)
        internal
        view
        returns (uint256)
    {
        if (currency == address(rawToken)) return amtRaw;
        if (currency == address(pairToken)) return amtPair;
        revert("unknown currency");
    }

    /// @dev Human units of raw/pair, mapped onto a pool currency after address sort.
    function _humanFor(address currency, uint256 human) internal view returns (uint256) {
        return _amountForCurrency(currency, _uRaw(human), _uPair(human));
    }

    function _depositBoth(uint256 amtRaw, uint256 amtPair) internal returns (uint256 lp) {
        uint256 a0 = _amountForCurrency(single.currency0(), amtRaw, amtPair);
        uint256 a1 = _amountForCurrency(single.currency1(), amtRaw, amtPair);
        vm.prank(user);
        (lp,,) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
    }

    function _enableProtocolFee(uint256 feeWad) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
        vm.stopPrank();
    }

    function _seedLiveLiquidity() internal returns (uint256 lp) {
        _initPool();
        lp = _depositBoth(_uRaw(200), _uPair(200));
    }

    function _feeTo() internal view virtual returns (address feeTo_) {
        (feeTo_,) = single.dexSwapFeeAndFeeTo();
    }

    function _isRawCurrency0() internal view returns (bool) {
        return single.currency0() == address(rawToken);
    }
}
