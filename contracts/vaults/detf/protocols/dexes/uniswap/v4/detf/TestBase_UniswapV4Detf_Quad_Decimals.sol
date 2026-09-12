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
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice Gold Quad DETF with book-decimal pair0/pair1/pair2. DETF token stays 18.
abstract contract TestBase_UniswapV4Detf_Quad_Decimals is TestBase_UniswapV4Detf_Decimals {
    using BetterEfficientHashLib for bytes;
    uint256 internal constant QUAD_BASE_AMP = 100;
    MintableERC20Decimals internal pair0;
    MintableERC20Decimals internal pair1;
    MintableERC20Decimals internal pair2;
    address internal se0;
    address internal se1;
    address internal se2;
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage internal quadHookPkg;

    function _dec0() internal pure virtual returns (uint8) { return _pairDecimals(); }
    function _dec1() internal pure virtual returns (uint8) { return _rateDecimals(); }
    function _dec2() internal pure virtual returns (uint8) { return 18; }
    function _u0(uint256 human) internal pure returns (uint256) { return human * (10 ** uint256(_dec0())); }
    function _u1(uint256 human) internal pure returns (uint256) { return human * (10 ** uint256(_dec1())); }
    function _u2(uint256 human) internal pure returns (uint256) { return human * (10 ** uint256(_dec2())); }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pair0 = new MintableERC20Decimals("Pair0", "P0", _dec0());
        pair1 = new MintableERC20Decimals("Pair1", "P1", _dec1());
        pair2 = new MintableERC20Decimals("Pair2", "P2", _dec2());
        pairToken = pair0;
        detfDecimalsStub = new MintableERC20Decimals("DetfStub", "DSTUB", 18);
        se0 = _deployERC4626SE(address(new SimpleYieldERC4626(pair0)));
        se1 = _deployERC4626SE(address(new SimpleYieldERC4626(pair1)));
        se2 = _deployERC4626SE(address(new SimpleYieldERC4626(pair2)));
        se = se0;
        pm = IPoolManager(address(new PoolManager(address(this))));

        _deployHookFactory();
        _deployQuadHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployQuadHookThenDetf(_nLegDetfArgs(3));
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        pair0.mint(detfUser, _u0(10_000_000));
        pair1.mint(detfUser, _u1(10_000_000));
        pair2.mint(detfUser, _u2(10_000_000));
        vm.startPrank(detfUser);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        pair2.approve(detf, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        IERC20(se2).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _deployQuadHookPkg() internal {
        IFacet hooksFacet = QuadFactory.deployHooksFacet(create3Factory);
        IFacet joinFacet = QuadFactory.deployJoinFacet(create3Factory);
        IFacet exitFacet = QuadFactory.deployExitFacet(create3Factory);
        IFacet seFacet = QuadFactory.deploySeFacet(create3Factory);
        quadHookPkg = QuadFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgInit({
                joinQueryFacet: QuadFactory.deployJoinQueryFacet(create3Factory),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                liquidityFacet: joinFacet,
                exitFacet: exitFacet,
                seFacet: seFacet,
                hooksFacet: hooksFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage).name, "v1", _dec0(), _dec1(), _dec2())._hash()
        );
    }

    function _deployQuadHookForArgs(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        returns (address predicted_)
    {
        predicted_ = _predictDetf(args);
        address[4] memory toks;
        toks[0] = predicted_;
        toks[1] = address(pair0);
        toks[2] = address(pair1);
        toks[3] = address(pair2);
        _sort4(toks);
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == address(pair0)) ses[i] = se0;
            else if (toks[i] == address(pair1)) ses[i] = se1;
            else ses[i] = se2;
        }
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                tokens: toks,
                standardExchanges: ses,
                rateProviders: rps,
                tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals4(toks, predicted_),
                seDecimals: HookPkgArgsDecimalsLib.seDecimals4(ses),
                baseAmp: QUAD_BASE_AMP,
                ownerOnlyLiquidity: args.ownerOnlyLiquidity,
                owner: predicted_
            });
        uint256 mineNonce = QuadFactory.findMineNonce(hookFactory, quadHookPkg, hArgs);
        reserveHook = QuadFactory.deployHook(quadHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
        require(init.finalizeInitialization(), "finalize");
        args.hook = reserveHook;
        vm.label(reserveHook, "quadReserveHook");
    }

    function _deployQuadHookThenDetf(IUniswapV4Detf.PkgArgs memory args) internal virtual returns (address detf_) {
        address predicted_ = _deployQuadHookForArgs(args);
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
    }

    function _sort4(address[4] memory a) internal pure {
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (a[i] > a[j]) (a[i], a[j]) = (a[j], a[i]);
            }
        }
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        _fundBondLegs(detfUser, pairAmount_);
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(address(pair0)), pairAmount_, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
