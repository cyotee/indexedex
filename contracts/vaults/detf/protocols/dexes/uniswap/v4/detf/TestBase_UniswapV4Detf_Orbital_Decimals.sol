// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice Gold Orbital DETF with book-decimal pair0/pair1. DETF token stays 18.
abstract contract TestBase_UniswapV4Detf_Orbital_Decimals is TestBase_UniswapV4Detf_Decimals {
    using BetterEfficientHashLib for bytes;
    MintableERC20Decimals internal pair0;
    MintableERC20Decimals internal pair1;
    address internal se0;
    address internal se1;
    IUniswapV4StandardExchangeOrbitalBufferHookPackage internal orbitalHookPkg;

    function _dec0() internal pure virtual returns (uint8) { return _pairDecimals(); }
    function _dec1() internal pure virtual returns (uint8) { return _rateDecimals(); }
    function _u0(uint256 human) internal pure returns (uint256) { return human * (10 ** uint256(_dec0())); }
    function _u1(uint256 human) internal pure returns (uint256) { return human * (10 ** uint256(_dec1())); }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pair0 = new MintableERC20Decimals("Pair0", "P0", _dec0());
        pair1 = new MintableERC20Decimals("Pair1", "P1", _dec1());
        pairToken = pair0;
        detfDecimalsStub = new MintableERC20Decimals("DetfStub", "DSTUB", 18);
        se0 = _deployERC4626SE(address(new SimpleYieldERC4626(pair0)));
        se1 = _deployERC4626SE(address(new SimpleYieldERC4626(pair1)));
        se = se0;
        pm = IPoolManager(address(new PoolManager(address(this))));

        _deployHookFactory();
        _deployOrbitalHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployOrbitalHookThenDetf(_nLegDetfArgs(2));
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        pair0.mint(detfUser, _u0(10_000_000));
        pair1.mint(detfUser, _u1(10_000_000));
        vm.startPrank(detfUser);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        pair0.approve(se0, type(uint256).max);
        pair1.approve(se1, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _deployOrbitalHookPkg() internal {
        IFacet hooksFacet = OrbitalFactory.deployHooksFacet(create3Factory);
        IFacet depositFacet = OrbitalFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = OrbitalFactory.deployWithdrawFacet(create3Factory);
        IFacet seFacet = OrbitalFactory.deploySeFacet(create3Factory);
        orbitalHookPkg = OrbitalFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgInit({
                depositQueryFacet: OrbitalFactory.deployDepositQueryFacet(create3Factory),
                depositZapFacet: OrbitalFactory.deployDepositZapFacet(create3Factory),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                seFacet: seFacet,
                hooksFacet: hooksFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4StandardExchangeOrbitalBufferHookPackage).name, "v1", _dec0(), _dec1())._hash()
        );
    }

    /// @dev Bind a 3-token orbital hook to `args.hook` without deploying the DETF.
    function _deployOrbitalHookForArgs(IUniswapV4Detf.PkgArgs memory args)
        internal
        returns (address predicted_)
    {
        predicted_ = _predictDetf(args);
        (address t0, address t1, address t2) = _sort3(predicted_, address(pair0), address(pair1));
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                token0: t0,
                token1: t1,
                token2: t2,
                decimals0: HookPkgArgsDecimalsLib.tokenDec(t0, predicted_),
                decimals1: HookPkgArgsDecimalsLib.tokenDec(t1, predicted_),
                decimals2: HookPkgArgsDecimalsLib.tokenDec(t2, predicted_),
                se0: _seOf(t0, predicted_),
                se1: _seOf(t1, predicted_),
                se2: _seOf(t2, predicted_),
                rp0: address(0),
                rp1: address(0),
                rp2: address(0),
                tickSpacing: 0,
                sqrtPriceX96: 0,
                ownerOnlyLiquidity: args.ownerOnlyLiquidity,
                owner: predicted_
            });
        uint256 mineNonce = OrbitalFactory.findMineNonce(hookFactory, orbitalHookPkg, hArgs);
        reserveHook = OrbitalFactory.deployHook(orbitalHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        require(init.finalizeInitialization(), "finalize");
        args.hook = reserveHook;
        vm.label(reserveHook, "orbitalReserveHook");
    }

    function _deployOrbitalHookThenDetf(IUniswapV4Detf.PkgArgs memory args) internal returns (address detf_) {
        address predicted_ = _deployOrbitalHookForArgs(args);
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
    }

    function _seOf(address token_, address predicted_) internal view returns (address) {
        if (token_ == predicted_) return address(0);
        if (token_ == address(pair0)) return se0;
        return se1;
    }

    function _sort3(address a, address b, address c) internal pure returns (address, address, address) {
        if (a > b) (a, b) = (b, a);
        if (b > c) (b, c) = (c, b);
        if (a > b) (a, b) = (b, a);
        return (a, b, c);
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        _fundBondLegs(detfUser, pairAmount_);
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(address(pair0)), pairAmount_, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertNoJoinableDust() internal view virtual override {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        assertLe(IERC20(address(pair0)).balanceOf(detf), 10, "no pair0");
        assertLe(IERC20(address(pair1)).balanceOf(detf), 10, "no pair1");
    }
}
