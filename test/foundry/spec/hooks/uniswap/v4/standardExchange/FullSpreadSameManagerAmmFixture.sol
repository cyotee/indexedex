// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {SeMatrixFixture} from "./SeMatrixFixture.sol";
import {SeMatrix_RebasingAwareFixture} from "./SeMatrix_RebasingAwareFixture.sol";
import {FullSpreadSameManagerWeightedFixture as WeightedFixture} from "./FullSpreadSameManagerWeightedFixture.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as CpPkg} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHook as CpHook} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpFactory} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as DualPkg} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHook as DualHook} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHookPackage as OrbitalPkg} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHook as OrbitalHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalFactory} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as CurvePkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHook as CurveHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookTestDeployLib as CurveDeploy} from "./stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTestDeployLib.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as BalancerPkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHook as BalancerHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib as BalancerDeploy} from "./stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTestDeployLib.sol";

/// @notice Production package adapters for the four remaining same-manager EO consumers.
/// @dev No mocked SE, rate provider, manager or hook. Extra raw tokens are funding stubs.
library FullSpreadSameManagerAmmFixture {
    enum Family { Dual, Orbital, CurveQuad, BalancerQuad, SingleCp, Weighted }

    struct Request {
        SeMatrixFixture.Ctx c;
        HookFactory factory;
        address manager;
        address vault;
        address face;
        address owner;
        uint8 identityAssetDecimals;
    }

    struct Fixture {
        address hook;
        address output;
        address[] tokens;
        uint256[] amounts;
        int24 spacing;
        bytes seedCall;
        address identityFixture;
        address identityAsset;
    }

    function deploy(Family family, Request memory r) external returns (Fixture memory f) {
        uint256 n = family == Family.Dual || family == Family.SingleCp || family == Family.Weighted ? 2 : family == Family.Orbital ? 3 : 4;
        f.tokens = new address[](n);
        f.tokens[0] = r.face;
        if (family == Family.Dual) (f.output, f.identityFixture, f.identityAsset) = _identityOutput(r);
        else f.output = _rawToken(r.owner);
        f.tokens[1] = f.output;
        for (uint256 i = 2; i < n; ++i) f.tokens[i] = _rawToken(r.owner);
        for (uint256 i; i < n; ++i) for (uint256 j = i + 1; j < n; ++j) {
            if (f.tokens[j] < f.tokens[i]) (f.tokens[i], f.tokens[j]) = (f.tokens[j], f.tokens[i]);
        }
        f.amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) f.amounts[i] = 10 ** uint256(IERC20Metadata(f.tokens[i]).decimals());
        f.spacing = family == Family.Dual || family == Family.Orbital || family == Family.SingleCp ? int24(60) : int24(1);
        if (family == Family.Dual) {
            f.hook = _dual(r, f.output);
            f.seedCall = abi.encodeCall(DualHook.deposit, (f.amounts[0], f.amounts[1], r.owner, 0, block.timestamp));
        } else if (family == Family.Orbital) {
            f.hook = _orbital(r, f.tokens);
            f.seedCall = abi.encodeCall(OrbitalHook.addLiquidity, (f.amounts[0], f.amounts[1], f.amounts[2], r.owner, 0, block.timestamp, bytes("")));
        } else if (family == Family.CurveQuad) {
            f.hook = _curve(r, f.tokens);
            f.seedCall = abi.encodeCall(CurveHook.joinUnbalanced, (f.amounts, r.owner, 0, block.timestamp));
        } else if (family == Family.BalancerQuad) {
            f.hook = _balancer(r, f.tokens);
            f.seedCall = abi.encodeCall(BalancerHook.joinUnbalanced, (f.amounts, r.owner, 0, block.timestamp));
        } else if (family == Family.SingleCp) {
            f.hook = _singleCp(r, f.output);
        } else {
            // This adapter already opens the pair and finalizes the real weighted package.
            f.hook = WeightedFixture.deploy(r.c, r.manager, r.vault, r.face, f.output, r.owner);
            return f;
        }
        for (uint256 i; i < n; ++i) for (uint256 j = i + 1; j < n; ++j) {
            IUniswapV4HookStagedPairInit(f.hook).deployPair(f.tokens[i], f.tokens[j]);
        }
        require(IUniswapV4HookStagedPairInit(f.hook).finalizeInitialization(), "AMM finalized");
    }

    function _rawToken(address owner) private returns (address) {
        SimpleMintableERC20 token = new SimpleMintableERC20("EO raw reserve", "EOR");
        token.mint(owner, 1 ether);
        token.mint(address(this), 1 ether);
        return address(token);
    }

    function _identityOutput(Request memory r) private returns (address output, address fixture, address assetAddress) {
        SeMatrix_RebasingAwareFixture wrapper = new SeMatrix_RebasingAwareFixture(r.c, address(0));
        fixture = address(wrapper);
        output = wrapper.se();
        assetAddress = wrapper.faceToken();
        uint256 funding = 2 ether;
        if (r.identityAssetDecimals == 0) wrapper.fund(address(this), funding);
        else {
            funding = 2 * 10 ** uint256(r.identityAssetDecimals);
            assetAddress = address(new ERC20PermitMintableStub("Identity asset", "IDAS", r.identityAssetDecimals, address(this), funding));
            output = address(IRebasingAwareERC4626DFPkg(wrapper.pkg()).deployVault(IERC20Metadata(assetAddress), 10, bytes32(0)));
        }
        IERC20 asset = IERC20(assetAddress);
        asset.approve(output, funding);
        uint256 shares = IStandardExchangeIn(output).exchangeIn(asset, funding, IERC20(output), 0, address(this), false, block.timestamp);
        uint256 seed = 10 ** uint256(IERC20Metadata(output).decimals());
        require(shares >= 2 * seed, "funded identity shares");
        IERC20(output).transfer(r.owner, seed);
    }

    /// @dev Fund raw/identity inventory at its actual decimals; never mint the H/P subject's shares.
    function fundInventory(Fixture memory f, address token, address to, uint256 amount) external {
        if (token != f.output || f.identityFixture == address(0)) {
            SimpleMintableERC20(token).mint(to, amount);
            return;
        }
        SeMatrix_RebasingAwareFixture wrapper = SeMatrix_RebasingAwareFixture(f.identityFixture);
        IERC20 asset = IERC20(f.identityAsset);
        uint256 assets = amount / 1e10 + (amount % 1e10 == 0 ? 0 : 1);
        if (f.identityAsset == wrapper.faceToken()) wrapper.fund(address(this), assets);
        else ERC20PermitMintableStub(f.identityAsset).mint(address(this), assets);
        asset.approve(f.output, assets);
        uint256 shares = IStandardExchangeIn(f.output).exchangeIn(asset, assets, IERC20(f.output), amount, to, false, block.timestamp);
        require(shares >= amount, "funded wrapper inventory");
    }

    /// @dev Share-input bootstrap avoids trying to zap tiny assets at the range boundary.
    function shareSeedCall(Family family, Fixture memory f, address face, uint256 shares, address recipient)
        external view returns (bytes memory)
    {
        bool[] memory shareInputs = new bool[](f.tokens.length);
        for (uint256 i; i < f.tokens.length; ++i) if (f.tokens[i] == face) {
            shareInputs[i] = true;
            f.amounts[i] = shares;
        }
        if (family == Family.SingleCp) {
            uint256 raw = f.tokens[0] == face ? f.amounts[1] : f.amounts[0];
            return abi.encodeCall(CpHook.depositWithSeShares, (raw, shares, recipient, 0, block.timestamp));
        }
        if (family == Family.Dual) return abi.encodeCall(DualHook.depositFlexible,
            (f.amounts[0], shareInputs[0], f.amounts[1], shareInputs[1], recipient, 0, block.timestamp));
        if (family == Family.Orbital) return abi.encodeCall(OrbitalHook.depositFlexible,
            (f.amounts[0], shareInputs[0], f.amounts[1], shareInputs[1], f.amounts[2], shareInputs[2], recipient, 0, block.timestamp));
        return abi.encodeWithSignature("joinProportionalFlexible(uint256[],bool[],address,uint256,uint256)",
            f.amounts, shareInputs, recipient, 0, block.timestamp);
    }

    function _singleCp(Request memory r, address raw) private returns (address) {
        CpPkg.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(r.c.indexedexManager));
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(r.c.indexedexManager));
        init.seFacet = CpFactory.deploySeFacet(r.c.create3Factory);
        init.depositFacet = CpFactory.deployDepositFacet(r.c.create3Factory);
        init.depositSingleFacet = CpFactory.deployDepositSingleFacet(r.c.create3Factory);
        init.depositPreviewFacet = CpFactory.deployDepositPreviewFacet(r.c.create3Factory);
        init.withdrawFacet = CpFactory.deployWithdrawFacet(r.c.create3Factory);
        init.erc20Facet = r.c.erc20Facet; init.erc5267Facet = r.c.erc5267Facet; init.erc2612Facet = r.c.erc2612Facet;
        init.multiAssetBasicVaultFacet = r.c.multiAssetBasicVaultFacet; init.multiAssetStandardVaultFacet = r.c.multiAssetStandardVaultFacet;
        init.multiStepOwnableFacet = IFacetRegistry(address(r.c.create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        CpPkg pkg = CpFactory.deployPackage(init.vaultRegistryDeployment, r.c.owner, init);
        CpPkg.PkgArgs memory args;
        args.poolManager = r.manager; args.feeOracle = address(r.c.indexedexManager);
        args.standardExchange = r.vault; args.pairToken = r.face; args.rawToken = raw;
        args.pairTokenDecimals = IERC20Metadata(r.face).decimals(); args.rawTokenDecimals = IERC20Metadata(raw).decimals();
        args.ownerOnlyLiquidity = true; args.owner = r.owner;
        args.rateProvider = RateProviderFixtureLib.providerForCp(r.c.create3Factory, r.c.create3Factory.diamondPackageFactory(), r.vault, r.face);
        return CpFactory.deployHook(pkg, args, CpFactory.findMineNonce(r.factory, pkg, args));
    }

    function _dual(Request memory r, address output) private returns (address) {
        DualPkg.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(r.c.indexedexManager));
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(r.c.indexedexManager));
        init.hooksFacet = DualFactory.deployHooksFacet(r.c.create3Factory);
        init.depositFacet = DualFactory.deployDepositFacet(r.c.create3Factory);
        init.withdrawFacet = DualFactory.deployWithdrawFacet(r.c.create3Factory);
        init.seFacet = DualFactory.deploySeFacet(r.c.create3Factory);
        init.erc20Facet = r.c.erc20Facet; init.erc5267Facet = r.c.erc5267Facet; init.erc2612Facet = r.c.erc2612Facet;
        init.multiAssetBasicVaultFacet = r.c.multiAssetBasicVaultFacet; init.multiAssetStandardVaultFacet = r.c.multiAssetStandardVaultFacet;
        DualPkg pkg = DualFactory.deployPackage(init.vaultRegistryDeployment, r.c.owner, init);
        DualPkg.PkgArgs memory args;
        args.poolManager = r.manager; args.feeOracle = address(r.c.indexedexManager);
        args.standardExchange0 = r.vault; args.token0 = r.face;
        args.standardExchange1 = output; args.token1 = output;
        args.rateProvider0 = RateProviderFixtureLib.providerForCp(r.c.create3Factory, r.c.create3Factory.diamondPackageFactory(), r.vault, r.face);
        return DualFactory.deployHook(pkg, args, DualFactory.findMineNonce(r.factory, pkg, args));
    }

    function _orbital(Request memory r, address[] memory tokens) private returns (address) {
        OrbitalPkg pkg = _orbitalPackage(r.c);
        OrbitalPkg.PkgArgs memory args;
        args.poolManager = r.manager; args.feeOracle = address(r.c.indexedexManager);
        args.token0 = tokens[0]; args.token1 = tokens[1]; args.token2 = tokens[2];
        args.decimals0 = IERC20Metadata(tokens[0]).decimals(); args.decimals1 = IERC20Metadata(tokens[1]).decimals(); args.decimals2 = IERC20Metadata(tokens[2]).decimals();
        address rp = RateProviderFixtureLib.providerForCp(r.c.create3Factory, r.c.create3Factory.diamondPackageFactory(), r.vault, r.face);
        if (tokens[0] == r.face) { args.se0 = r.vault; args.rp0 = rp; }
        else if (tokens[1] == r.face) { args.se1 = r.vault; args.rp1 = rp; }
        else { args.se2 = r.vault; args.rp2 = rp; }
        args.tickSpacing = 60; args.sqrtPriceX96 = uint160(1 << 96);
        args.ownerOnlyLiquidity = true; args.owner = r.owner;
        return OrbitalFactory.deployHook(pkg, args, OrbitalFactory.findMineNonce(r.factory, pkg, args));
    }

    function _orbitalPackage(SeMatrixFixture.Ctx memory c) private returns (OrbitalPkg) {
        OrbitalPkg.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.depositZapFacet = OrbitalFactory.deployDepositZapFacet(c.create3Factory);
        init.depositQueryFacet = OrbitalFactory.deployDepositQueryFacet(c.create3Factory);
        init.depositFacet = OrbitalFactory.deployDepositFacet(c.create3Factory);
        init.withdrawFacet = OrbitalFactory.deployWithdrawFacet(c.create3Factory);
        init.seFacet = OrbitalFactory.deploySeFacet(c.create3Factory);
        init.hooksFacet = OrbitalFactory.deployHooksFacet(c.create3Factory);
        init.erc20Facet = c.erc20Facet; init.erc5267Facet = c.erc5267Facet; init.erc2612Facet = c.erc2612Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet; init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        init.multiStepOwnableFacet = IFacetRegistry(address(c.create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        return OrbitalFactory.deployPackage(init.vaultRegistryDeployment, c.owner, init);
    }

    function _curve(Request memory r, address[] memory tokens) private returns (address) {
        (HookFactory factory, CurvePkg pkg) = _curvePackage(r.c);
        CurvePkg.PkgArgs memory args;
        args.poolManager = r.manager; args.feeOracle = address(r.c.indexedexManager);
        args.baseAmp = 100; args.ownerOnlyLiquidity = true; args.owner = r.owner;
        for (uint256 i; i < 4; ++i) {
            args.tokens[i] = tokens[i]; args.tokenDecimals[i] = IERC20Metadata(tokens[i]).decimals();
            if (tokens[i] == r.face) {
                args.standardExchanges[i] = r.vault;
                args.seDecimals[i] = IERC20Metadata(r.vault).decimals();
                args.rateProviders[i] = RateProviderFixtureLib.providerForCp(r.c.create3Factory, r.c.create3Factory.diamondPackageFactory(), r.vault, r.face);
            }
        }
        return CurveDeploy.deployHookInstance(factory, pkg, args);
    }

    function _curvePackage(SeMatrixFixture.Ctx memory c) private returns (HookFactory, CurvePkg) {
        return CurveDeploy.deployFactoryAndPackage(c.create3Factory, c.owner, address(c.indexedexManager),
            c.erc20Facet, c.erc5267Facet, c.erc2612Facet, c.multiAssetBasicVaultFacet, c.multiAssetStandardVaultFacet,
            IFacetRegistry(address(c.create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId));
    }

    function _balancer(Request memory r, address[] memory tokens) private returns (address) {
        (HookFactory factory, BalancerPkg pkg) = _balancerPackage(r.c);
        BalancerPkg.PkgArgs memory args;
        args.poolManager = r.manager; args.feeOracle = address(r.c.indexedexManager);
        args.tokens = tokens; args.baseAmp = 100;
        args.standardExchanges = new address[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) if (tokens[i] == r.face) args.standardExchanges[i] = r.vault;
        args.rateProviders = RateProviderFixtureLib.providersFor(r.c.create3Factory, r.c.create3Factory.diamondPackageFactory(), tokens, args.standardExchanges);
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        return BalancerDeploy.deployHookInstance(factory, pkg, args);
    }

    function _balancerPackage(SeMatrixFixture.Ctx memory c) private returns (HookFactory, BalancerPkg) {
        return BalancerDeploy.deployFactoryAndPackage(c.create3Factory, c.owner, address(c.indexedexManager),
            c.erc20Facet, c.erc5267Facet, c.erc2612Facet, c.multiAssetBasicVaultFacet, c.multiAssetStandardVaultFacet);
    }
}
