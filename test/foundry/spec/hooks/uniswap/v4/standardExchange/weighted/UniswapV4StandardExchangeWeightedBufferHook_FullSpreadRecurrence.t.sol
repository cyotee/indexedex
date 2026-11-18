// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from
    "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as Package} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as Deploy} from
    "./UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IFullSpreadPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService as Components} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IBindings} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {FullSpreadV4ExternalLp} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";

/// @notice Exhaustive 24 n=2 homogeneous/raw assignment cells for this local, empty-core join/exit state.
/// @dev Explicitly not exhaustive for larger arities, economic states, heterogeneous families or DETF routes.
contract UniswapV4StandardExchangeWeightedBufferHook_FullSpreadRecurrence is IndexedexTest {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    HookFactory internal consumerFactory;
    Package internal consumerPackage;
    IPoolManager internal pool;
    IPoolManager internal otherManager;
    IFullSpreadPackage internal fullSpreadPackage;
    IFullSpreadPackage internal otherFullSpreadPackage;
    IWETH internal weth;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETH9()));
        pool = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("Recurrence.FullSpread.PoolManager")
        ));
        otherManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("Recurrence.FullSpread.OtherManager")
        ));
        IFacet erc20 = create3Factory.deployERC20Facet();
        IFacet erc5267 = create3Factory.deployERC5267Facet();
        IFacet erc2612 = create3Factory.deployERC2612Facet();
        IFacet basic = create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet standard = create3Factory.deployMultiAssetStandardVaultFacet();
        (consumerFactory, consumerPackage) = Deploy.deployFactoryAndPackage(
            create3Factory,
            owner,
            address(indexedexManager),
            erc20,
            erc5267,
            erc2612,
            basic,
            standard,
            multiStepOwnableFacet
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(consumerFactory));
        IFullSpreadPackage.PkgInit memory init = _packageInit(pool, erc20, erc2612, erc5267, basic, standard);
        vm.prank(owner);
        fullSpreadPackage = Components.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, init);
        init.poolManager = otherManager;
        bytes memory creationCode = ArtifactCreationCode.creationCode(
            "UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"
        );
        vm.prank(owner);
        otherFullSpreadPackage = IFullSpreadPackage(indexedexManager.deployPkg(
            creationCode, abi.encode(init), keccak256("Recurrence.FullSpread.OtherPackage")
        ));
    }

    function test_recurrence_FullSpreadWeightedN2EveryOrderedTargetManagerAssignment() public {
        for (uint256 encoded = 1; encoded < 25; ++encoded) {
            uint256 snapshot = vm.snapshotState();
            uint8[] memory choices = new uint8[](2);
            choices[0] = uint8(encoded % 5);
            choices[1] = uint8(encoded / 5);
            _roundTrip(choices);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_recurrence_FullSpreadWeightedEightBufferedMixedTargetsAndManagers() public {
        uint8[] memory choices = new uint8[](8);
        for (uint256 i; i < 8; ++i) choices[i] = uint8(1 + i % 4);
        _roundTrip(choices);
    }

    function _packageInit(
        IPoolManager manager,
        IFacet erc20,
        IFacet erc2612,
        IFacet erc5267,
        IFacet basic,
        IFacet standard
    ) private returns (IFullSpreadPackage.PkgInit memory init_) {
        address infra_ = address(new FullSpreadRecurrenceInfrastructure());
        IFacet money_ = Components.deployMoneyFacet(create3Factory);
        init_.erc20Facet = erc20;
        init_.erc2612Facet = erc2612;
        init_.erc5267Facet = erc5267;
        init_.basicVaultFacet = basic;
        init_.standardVaultFacet = standard;
        init_.moneyFacet = money_;
        init_.quoteFacet = Components.deployQuoteFacet(create3Factory);
        init_.outFacet = Components.deployOutFacet(create3Factory);
        init_.queryFacet = Components.deployQueryFacet(create3Factory);
        init_.callbackFacet = Components.deployCallbackFacet(create3Factory);
        init_.uniswapV4ProtocolAwareFacet = Components.deployProtocolAwareFacet(create3Factory);
        init_.uniswapV4SinglePositionAwareFacet = Components.deploySinglePositionAwareFacet(create3Factory);
        init_.poolManager = manager;
        init_.positionDescriptor = infra_;
        init_.positionManager = infra_;
        init_.quoter = infra_;
        init_.stateView = infra_;
        init_.reservesLens = infra_;
        init_.universalRouter = infra_;
        init_.registry = indexedexManager;
        init_.oracle = IVaultFeeOracleQuery(address(indexedexManager));
        init_.weth = weth;
        init_.diamondFactory = diamondFactory;
        init_.linkedLibraries = IBindings(address(money_)).linkedComponents();
    }

    function _orderedTokens(uint256 n) private returns (address[] memory tokens) {
        tokens = new address[](2 * n);
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = address(new ERC20PermitMintableStub(
                "Recurrence face", "FACE", i % 2 == 0 ? 6 : 18, address(this), 1e25
            ));
        }
        for (uint256 i; i < tokens.length; ++i) for (uint256 j = i + 1; j < tokens.length; ++j) {
            if (tokens[j] < tokens[i]) (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
        }
    }

    // Sort all 2n tokens before assigning adjacent pairs. Either face of pair i
    // then precedes either face of pair i+1, preserving the enumerated ordered assignment.
    function _bindLeg(address first, address second, uint8 choice) private returns (address face, address vault) {
        if (choice == 0) return (first, address(0));
        bool different = choice >= 3;
        face = choice == 1 || choice == 3 ? first : second;
        PoolKey memory market = PoolKey(Currency.wrap(first), Currency.wrap(second), 3000, 60, IHooks(address(0)));
        IPoolManager manager = different ? otherManager : pool;
        manager.initialize(market, uint160(1) << 96);
        _seed(manager, market, first, second);
        IFullSpreadPackage pkg = different ? otherFullSpreadPackage : fullSpreadPackage;
        vault = pkg.deployVault(IFullSpreadPackage.PkgArgs(market));
    }

    function _seed(IPoolManager manager, PoolKey memory market, address first, address second) private {
        int24 lower = TickMath.minUsableTick(market.tickSpacing);
        int24 upper = TickMath.maxUsableTick(market.tickSpacing);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            uint160(1) << 96,
            TickMath.getSqrtPriceAtTick(lower),
            TickMath.getSqrtPriceAtTick(upper),
            50_000 ether,
            50_000 ether
        );
        FullSpreadV4ExternalLp lp = new FullSpreadV4ExternalLp(manager);
        ERC20PermitMintableStub(first).mint(address(lp), 100_000 ether);
        ERC20PermitMintableStub(second).mint(address(lp), 100_000 ether);
        lp.add(market, lower, upper, liquidity);
    }

    function _consumer(uint8[] memory choices) private returns (Weighted, address[] memory) {
        uint256 n = choices.length;
        address[] memory pairs = _orderedTokens(n);
        Package.PkgArgs memory args;
        args.poolManager = address(pool);
        args.feeOracle = address(indexedexManager);
        args.n = uint8(n);
        args.tokens = new address[](n);
        args.standardExchanges = new address[](n);
        args.rateProviders = new address[](n);
        args.weights = new uint256[](n);
        uint256 assigned;
        for (uint256 i; i < n; ++i) {
            (args.tokens[i], args.standardExchanges[i]) = _bindLeg(pairs[2 * i], pairs[2 * i + 1], choices[i]);
            args.rateProviders[i] = RateProviderFixtureLib.providerFor(
                create3Factory, diamondFactory, args.standardExchanges[i], args.tokens[i]
            );
            args.weights[i] = i + 1 == n ? 1e18 - assigned : (i + 1) * 1e18 / (n * (n + 1) / 2);
            assigned += args.weights[i];
        }
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.ownerOnlyLiquidity = true;
        args.owner = address(this);
        address deployed = Deploy.deployHookInstance(consumerFactory, consumerPackage, args);
        for (uint256 i; i < n; ++i) for (uint256 j = i + 1; j < n; ++j) {
            IUniswapV4HookStagedPairInit(deployed).deployPair(args.tokens[i], args.tokens[j]);
        }
        assertTrue(IUniswapV4HookStagedPairInit(deployed).finalizeInitialization());
        for (uint256 i; i < n; ++i) IERC20(args.tokens[i]).approve(deployed, type(uint256).max);
        return (Weighted(deployed), args.tokens);
    }

    function _roundTrip(uint8[] memory choices) private {
        (Weighted consumer, address[] memory faces) = _consumer(choices);
        uint256[] memory amounts = new uint256[](faces.length);
        uint256[] memory balances = new uint256[](faces.length);
        bool[] memory flags = new bool[](faces.length);
        address[] memory inputs = new address[](faces.length);
        for (uint256 i; i < faces.length; ++i) {
            amounts[i] = 100 * 10 ** IERC20Metadata(faces[i]).decimals();
            address se = consumer.standardExchange(i);
            inputs[i] = se == address(0) ? faces[i] : se;
            if (se != address(0)) {
                uint256 deposit_ = 1_000 ether;
                ERC20PermitMintableStub(faces[i]).mint(address(this), deposit_);
                IERC20(faces[i]).approve(se, deposit_);
                (amounts[i],) = IStandardExchangeIn(se).exchangeIn(
                    IERC20(faces[i]), deposit_, IERC20(se), 1, address(this), false, block.timestamp
                );
                IERC20(se).approve(address(consumer), type(uint256).max);
                flags[i] = true;
            }
            balances[i] = IERC20(inputs[i]).balanceOf(address(this));
        }
        (uint256 expected, uint256[] memory quotedUsed) = consumer.previewJoinProportionalFlexible(amounts, flags);
        (uint256 minted, uint256[] memory used) = consumer.joinProportionalFlexible(
            amounts, flags, address(this), expected, block.timestamp
        );
        assertGt(minted, 0);
        assertEq(minted, expected);
        assertEq(used, quotedUsed);
        for (uint256 i; i < faces.length; ++i) {
            assertEq(balances[i] - IERC20(inputs[i]).balanceOf(address(this)), used[i]);
        }
        uint256 burn = minted / 5;
        uint256[] memory expectedOut = consumer.previewExitProportional(burn);
        for (uint256 i; i < faces.length; ++i) balances[i] = IERC20(faces[i]).balanceOf(address(this));
        uint256[] memory paid = consumer.exitProportional(burn, address(this), expectedOut, block.timestamp);
        assertEq(paid, expectedOut);
        for (uint256 i; i < faces.length; ++i) {
            assertEq(IERC20(faces[i]).balanceOf(address(this)) - balances[i], paid[i]);
        }
        assertEq(IERC20(address(consumer)).balanceOf(address(this)), minted - burn);
    }
}

contract FullSpreadRecurrenceInfrastructure {}
