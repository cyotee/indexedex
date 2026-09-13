// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as ICurvePkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as CurveFactory} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {IUniswapV4Detf} from "./interfaces/IUniswapV4Detf.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {TestBase_UniswapV4Detf} from "./TestBase_UniswapV4Detf.sol";

/// @notice Actual four-leg Curve reserve bound to the shared funded DETF package.
abstract contract TestBase_UniswapV4Detf_CurveQuad is TestBase_UniswapV4Detf {
    SimpleMintableERC20[3] internal curvePairs;
    address[3] internal curveExchanges;
    ICurvePkg internal curveHookPkg;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);
        for (uint256 i; i < 3; ++i) {
            curvePairs[i] = new SimpleMintableERC20("Curve pair", "CPAIR");
            curveExchanges[i] = _deployERC4626SE(address(new SimpleYieldERC4626(curvePairs[i])));
        }
        pairToken = curvePairs[0];
        se = curveExchanges[0];
        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4Detf_CurveQuad_PoolManager")
        ))));
        _deployHookFactory();
        _deployCurvePackage();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        detf = _deployCurveHookThenDetf(_nLegDetfArgs(3));
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        for (uint256 i; i < 3; ++i) {
            curvePairs[i].mint(detfUser, 10_000_000 ether);
            vm.startPrank(detfUser);
            curvePairs[i].approve(detf, type(uint256).max);
            curvePairs[i].approve(curveExchanges[i], type(uint256).max);
            IERC20(curveExchanges[i]).approve(detf, type(uint256).max);
            vm.stopPrank();
        }
    }

    function _deployCurvePackage() internal {
        ICurvePkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        init_.joinQueryFacet = CurveFactory.deployJoinQueryFacet(create3Factory);
        init_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
        init_.liquidityFacet = CurveFactory.deployJoinFacet(create3Factory);
        init_.exitFacet = CurveFactory.deployExitFacet(create3Factory);
        init_.seFacet = CurveFactory.deploySeFacet(create3Factory);
        init_.hooksFacet = CurveFactory.deployHooksFacet(create3Factory);
        init_.erc20Facet = erc20Facet;
        init_.erc5267Facet = erc5267Facet;
        init_.erc2612Facet = erc2612Facet;
        init_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        init_.multiStepOwnableFacet = multiStepOwnableFacet;
        curveHookPkg = CurveFactory.deployPackage(
            init_.vaultRegistryDeployment, owner, init_, keccak256("funded.detf.curve.package")
        );
    }

    function _deployCurveHookThenDetf(IUniswapV4Detf.PkgArgs memory args_)
        internal returns (address deployed_)
    {
        address predicted_ = _predictDetf(args_);
        ICurvePkg.PkgArgs memory hook_;
        hook_.poolManager = address(pm);
        hook_.feeOracle = address(indexedexManager);
        hook_.tokens = [predicted_, address(curvePairs[0]), address(curvePairs[1]), address(curvePairs[2])];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (hook_.tokens[i] > hook_.tokens[j]) {
                    (hook_.tokens[i], hook_.tokens[j]) = (hook_.tokens[j], hook_.tokens[i]);
                }
            }
        }
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 3; ++j) {
                if (hook_.tokens[i] == address(curvePairs[j])) hook_.standardExchanges[i] = curveExchanges[j];
            }
        }
        hook_.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals4(hook_.tokens, predicted_);
        hook_.seDecimals = HookPkgArgsDecimalsLib.seDecimals4(hook_.standardExchanges);
        hook_.baseAmp = 200;
        hook_.ownerOnlyLiquidity = args_.ownerOnlyLiquidity;
        hook_.owner = predicted_;
        reserveHook = CurveFactory.deployHook(
            curveHookPkg, hook_, CurveFactory.findMineNonce(hookFactory, curveHookPkg, hook_)
        );
        IUniswapV4HookStagedPairInit staged_ = IUniswapV4HookStagedPairInit(reserveHook);
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) staged_.deployPair(hook_.tokens[i], hook_.tokens[j]);
        }
        require(staged_.finalizeInitialization(), "Curve initialization");
        args_.hook = reserveHook;
        vm.prank(owner);
        deployed_ = detfPkg.deployVault(args_);
        require(deployed_ == predicted_, "DETF prediction");
    }
}

