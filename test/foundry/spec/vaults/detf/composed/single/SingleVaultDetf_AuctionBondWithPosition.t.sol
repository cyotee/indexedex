// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {PositionInfo, PositionInfoLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {
    WeightedPool8020Factory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/ISuperChainBridgeTokenRegistry.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {UniswapV4_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    SingleVaultDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol";
import {
    ISingleVaultDetfDFPkg
} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {
    SingleVaultDetf_Facet_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";
import {
    SingleVaultDetf_Pkg_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol";
import {
    ISingleVaultDetfBonding
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {
    LBPInitializationParams
} from "contracts/protocols/launchpads/uniswap/continuous-clearing/src/interfaces/external/ILBPInitializer.sol";
import {
    ContinuousClearingAuction
} from "contracts/protocols/launchpads/uniswap/continuous-clearing/src/ContinuousClearingAuction.sol";
import {
    AuctionParameters
} from "contracts/protocols/launchpads/uniswap/continuous-clearing/src/interfaces/IContinuousClearingAuction.sol";
import {FixedPoint96} from "contracts/protocols/launchpads/uniswap/continuous-clearing/src/libraries/FixedPoint96.sol";

contract AuctionUniswapV4LiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");

        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));

        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            bytes("")
        );

        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());

        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

contract SingleVaultDetf_AuctionBondWithPosition_Test is TestBase_BalancerV3StandardExchangeRouter {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Facet_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for ICreate3FactoryProxy;
    using BaseProtocolDETF_Pkg_FactoryService for IVaultRegistryDeployment;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Pkg_FactoryService for IVaultRegistryDeployment;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant FLOOR_PRICE = 1000 << FixedPoint96.RESOLUTION;
    uint256 internal constant TICK_SPACING = 100 << FixedPoint96.RESOLUTION;
    uint128 internal constant TOTAL_SUPPLY = 1000e18;
    uint256 internal constant AUCTION_DURATION = 100;
    uint256 internal constant CLAIM_BLOCK_OFFSET = 10;
    uint256 internal constant MIN_LOCK_DURATION = 30 days;
    uint24 internal constant STANDARD_MPS_1_PERCENT = 100_000;
    int24 internal constant POSITION_TICK_LOWER = -60;
    int24 internal constant POSITION_TICK_UPPER = 60;
    uint128 internal constant POSITION_LIQUIDITY = 1e18;

    uint256 internal constant TEST_TOKEN_TOTAL_SUPPLY = 10_000_000e18;

    IERC20 internal wethToken;
    IERC20 internal richToken;

    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;
    IFacet internal singleVaultDetfExchangeInFacet;
    IFacet internal singleVaultDetfExchangeInQueryFacet;
    IFacet internal singleVaultDetfExchangeOutFacet;
    IFacet internal singleVaultDetfBondingFacet;
    IFacet internal operableFacet;
    IFacet internal richirFacet;
    IFacet internal protocolNFTVaultFacet;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;

    PoolManager internal poolManager;
    ISingleVaultDetfDFPkg internal singleVaultDetfDFPkg;
    IRICHIRDFPkg internal richirDFPkg;
    IUniswapV4StandardExchangeDFPkg internal wethRichVaultPkg;
    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IProtocolNFTVaultDFPkg internal protocolNFTVaultPkg;
    IWeightedPool8020Factory internal weightedPool8020Factory;

    ISingleVaultDetf internal detf;
    IProtocolNFTVault internal protocolNFTVault;
    ContinuousClearingAuction internal auction;
    IPositionManager internal positionManager;
    AuctionUniswapV4LiquiditySeeder internal liquiditySeeder;
    ERC20PermitDFPkg internal erc20PermitPkg;

    address internal auctionAlice;
    address internal auctionBob;
    address internal tokensRecipient;
    address internal fundsRecipient;

    function setUp() public override {
        super.setUp();

        auctionAlice = makeAddr("alice");
        auctionBob = makeAddr("bob");
        tokensRecipient = makeAddr("tokensRecipient");
        fundsRecipient = makeAddr("fundsRecipient");

        _deployTestTokenPkg();
        wethToken = _deployTestToken("Wrapped Ether", "WETH", keccak256("SingleVaultDetfAuction_WETH"));
        richToken = _deployTestToken("Rich Token", "RICH", keccak256("SingleVaultDetfAuction_RICH"));
        poolManager = new PoolManager(address(this));
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        _deployWeightedPool8020Factory();
        _deployStandardExchangeRateProviderPkg();
        _deployProtocolNFTVaultPkg();
        _deployUniswapV4StandardExchangePkg();

        singleVaultDetfExchangeInFacet = create3Factory.deploySingleVaultDetfExchangeInFacet();
        singleVaultDetfExchangeInQueryFacet = create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
        singleVaultDetfExchangeOutFacet = create3Factory.deploySingleVaultDetfExchangeOutFacet();
        singleVaultDetfBondingFacet = create3Factory.deploySingleVaultDetfBondingFacet();
        operableFacet = create3Factory.deployOperableFacet();
        richirFacet = create3Factory.deployRICHIRFacet();

        richirDFPkg = create3Factory.deployRICHIRDFPkg(
            IRICHIRDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                richirFacet: richirFacet,
                diamondFactory: diamondPackageFactory
            })
        );

        SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets memory facets =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: singleVaultDetfExchangeInFacet,
                exchangeInQueryFacet: singleVaultDetfExchangeInQueryFacet,
                exchangeOutFacet: singleVaultDetfExchangeOutFacet,
                bondingFacet: singleVaultDetfBondingFacet,
                operableFacet: operableFacet
            });

        SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra memory infra =
            SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra({
                feeOracle: indexedexManager,
                vaultRegistryDeployment: indexedexManager,
                permit2: permit2,
                wethToken: wethToken,
                balancerV3Vault: IBalancerVault(address(vault)),
                balancerV3PrepayRouter: seRouter,
                weightedPool8020Factory: weightedPool8020Factory,
                bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
                standardBridge: IStandardBridge(payable(address(0))),
                messenger: ICrossDomainMessenger(address(0)),
                localRelayer: address(0),
                peerRelayer: address(0),
                wethRichVaultPkg: wethRichVaultPkg,
                protocolNFTVaultPkg: protocolNFTVaultPkg,
                richirPkg: richirDFPkg,
                rateProviderPkg: rateProviderPkg,
                diamondFactory: diamondPackageFactory
            });

        vm.startPrank(owner);
        singleVaultDetfDFPkg = IVaultRegistryDeployment(address(indexedexManager)).deploySingleVaultDetfDFPkg(
            SingleVaultDetf_Component_FactoryService.buildPkgInit(facets, infra)
        );

        ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs = SingleVaultDetf_Component_FactoryService.buildPkgArgs(
            "Single Vault DETF",
            "SVDETF",
            richToken,
            10_000e18,
            1_000e18,
            _buildPoolKey(),
            60
        );

        detf = ISingleVaultDetf(
            indexedexManager.deployVault(IStandardVaultPkg(address(singleVaultDetfDFPkg)), abi.encode(pkgArgs))
        );
        vm.stopPrank();

        protocolNFTVault = detf.protocolNFTVault();
        liquiditySeeder = new AuctionUniswapV4LiquiditySeeder(poolManager);
        PositionDescriptor descriptor = new PositionDescriptor(poolManager, address(wethToken), bytes32("ETH"));
        positionManager = IPositionManager(
            address(
                new PositionManager(
                    poolManager,
                    IAllowanceTransfer(address(permit2)),
                    100_000,
                    descriptor,
                    IWETH9(address(wethToken))
                )
            )
        );
        poolManager.initialize(_buildPoolKey(), TickMath.getSqrtPriceAtTick(0));
        _fundWeth(address(liquiditySeeder), 100_000 ether);
        _fundRich(address(liquiditySeeder), 100_000 ether);
        liquiditySeeder.addLiquidity(
            _buildPoolKey(),
            POSITION_TICK_LOWER,
            POSITION_TICK_UPPER,
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(POSITION_TICK_LOWER),
                TickMath.getSqrtPriceAtTick(POSITION_TICK_UPPER),
                100_000 ether,
                100_000 ether
            )
        );

        AuctionParameters memory params = AuctionParameters({
            currency: address(0),
            tokensRecipient: tokensRecipient,
            fundsRecipient: fundsRecipient,
            startBlock: uint64(block.number),
            endBlock: uint64(block.number + AUCTION_DURATION),
            claimBlock: uint64(block.number + AUCTION_DURATION + CLAIM_BLOCK_OFFSET),
            tickSpacing: TICK_SPACING,
            validationHook: address(0),
            floorPrice: FLOOR_PRICE,
            requiredCurrencyRaised: 0,
            auctionStepsData: abi.encodePacked(
                STANDARD_MPS_1_PERCENT,
                uint40(50),
                STANDARD_MPS_1_PERCENT,
                uint40(50)
            )
        });

        auction = new ContinuousClearingAuction(address(richToken), TOTAL_SUPPLY, params);
    _fundRich(address(auction), TOTAL_SUPPLY);
        auction.onTokensReceived();
    }

    function test_auctionLifecycle_canBootstrapDetfBondingFromPostAuctionPosition() public {
        assertTrue(indexedexManager.isVault(address(detf)), "detf deployed through package");
        assertEq(indexedexManager.vaultsOfPackage(address(singleVaultDetfDFPkg)).length, 1, "package vault registered");
        assertEq(IERC20(address(detf.wethRichVault())).totalSupply(), 0, "weth/rich vault starts empty");

        uint256 maxPrice = FLOOR_PRICE + TICK_SPACING;
        uint128 aliceBidAmount = inputAmountForTokens(uint128(TOTAL_SUPPLY / 2), maxPrice);
        uint128 bobBidAmount = inputAmountForTokens(uint128(TOTAL_SUPPLY / 2), maxPrice);

        vm.deal(auctionAlice, aliceBidAmount);
        vm.deal(auctionBob, bobBidAmount);

        vm.prank(auctionAlice);
        uint256 aliceBidId = submitBid(auctionAlice, aliceBidAmount, maxPrice);

        vm.prank(auctionBob);
        uint256 bobBidId = submitBid(auctionBob, bobBidAmount, maxPrice);

        vm.roll(auction.endBlock());
        uint256 clearingPrice = auction.checkpoint().clearingPrice;

        assertTrue(auction.isGraduated(), "auction graduated");
        assertGt(auction.totalCleared(), 0, "tokens cleared");
        assertGt(auction.currencyRaised(), 0, "currency raised");

        if (maxPrice > clearingPrice) {
            vm.prank(auctionAlice);
            auction.exitBid(aliceBidId);

            vm.prank(auctionBob);
            auction.exitBid(bobBidId);
        } else {
            vm.prank(auctionAlice);
            auction.exitPartiallyFilledBid(aliceBidId, auction.startBlock(), 0);

            vm.prank(auctionBob);
            auction.exitPartiallyFilledBid(bobBidId, auction.startBlock(), 0);
        }

        vm.roll(auction.claimBlock());

        uint256 aliceTokenBalanceBefore = richToken.balanceOf(auctionAlice);
        uint256 bobTokenBalanceBefore = richToken.balanceOf(auctionBob);

        vm.prank(auctionAlice);
        auction.claimTokens(aliceBidId);

        vm.prank(auctionBob);
        auction.claimTokens(bobBidId);

        assertGt(richToken.balanceOf(auctionAlice) - aliceTokenBalanceBefore, 0, "alice claimed sold token");
        assertGt(richToken.balanceOf(auctionBob) - bobTokenBalanceBefore, 0, "bob claimed sold token");

        LBPInitializationParams memory lbpParams = auction.lbpInitializationParams();
        assertEq(lbpParams.tokensSold, auction.totalCleared(), "lbp tokens sold");
        assertEq(lbpParams.currencyRaised, auction.currencyRaised(), "lbp currency raised");
        assertGt(lbpParams.initialPriceX96, 0, "lbp initial price");

        uint256 positionTokenId = _createAuctionPosition(auctionAlice, lbpParams);

        {
            assertEq(IERC721(address(positionManager)).ownerOf(positionTokenId), auctionAlice, "auction winner owns position");
            (, PositionInfo positionInfo) = positionManager.getPoolAndPositionInfo(positionTokenId);
            assertEq(
                bytes32(positionInfo.poolId()),
                bytes32(bytes25(PoolId.unwrap(_buildPoolKey().toId()))),
                "position pool id matches initialized pool"
            );
        }

        vm.prank(auctionAlice);
        (uint256 createdTokenId, uint256 shares) = ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            IPositionManager(address(positionManager)), positionTokenId, MIN_LOCK_DURATION, auctionBob, block.timestamp
        );

        assertGt(IERC20(address(detf.wethRichVault())).totalSupply(), 0, "vault bootstrapped from imported position");
        assertGt(shares, 0, "bond minted reserve shares");
        assertEq(shares, IERC20(detf.reservePool()).balanceOf(address(detf)), "bond shares backed by reserve pool");
        assertTrue(createdTokenId != detf.protocolNFTId(), "user bond nft distinct from protocol nft");
        assertEq(
            IERC721(address(positionManager)).ownerOf(positionTokenId),
            address(detf.wethRichVault()),
            "vault owns imported auction position"
        );

        {
            IProtocolNFTVault.Position memory position = protocolNFTVault.getPosition(createdTokenId);
            assertEq(protocolNFTVault.ownerOf(createdTokenId), auctionBob, "bond recipient");
            assertEq(position.originalShares, shares, "created bond shares");
            assertEq(position.unlockTime, block.timestamp + MIN_LOCK_DURATION, "lock duration");
        }
    }

    function submitBid(address owner_, uint128 amount_, uint256 maxPrice_) internal returns (uint256 bidId_) {
        bidId_ = auction.submitBid{value: amount_}(maxPrice_, amount_, owner_, FLOOR_PRICE, bytes(""));
    }

    function inputAmountForTokens(uint128 tokens_, uint256 maxPrice_) internal pure returns (uint128 amountIn_) {
        uint256 numerator = uint256(tokens_) * maxPrice_;
        amountIn_ = uint128((numerator + FixedPoint96.Q96 - 1) / FixedPoint96.Q96);
    }

    function _createAuctionPosition(address owner_, LBPInitializationParams memory lbpParams_) internal returns (uint256 tokenId_) {
        tokenId_ = positionManager.nextTokenId();

        _fundWeth(owner_, lbpParams_.currencyRaised);

        vm.startPrank(owner_);
        _approvePositionManager(address(wethToken), positionManager);
        _approvePositionManager(address(richToken), positionManager);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION), uint8(Actions.CLOSE_CURRENCY), uint8(Actions.CLOSE_CURRENCY)
        );
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            _buildPoolKey(),
            POSITION_TICK_LOWER,
            POSITION_TICK_UPPER,
            uint256(POSITION_LIQUIDITY),
            type(uint128).max,
            type(uint128).max,
            owner_,
            bytes("")
        );
        params[1] = abi.encode(_buildPoolKey().currency0);
        params[2] = abi.encode(_buildPoolKey().currency1);

        positionManager.modifyLiquidities(abi.encode(actions, params), block.timestamp + 1 hours);
        IERC721(address(positionManager)).approve(address(detf.wethRichVault()), tokenId_);
        vm.stopPrank();
    }

    function _approvePositionManager(address token_, IPositionManager positionManager_) internal {
        IERC20(token_).approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            token_, address(positionManager_), type(uint160).max, type(uint48).max
        );
    }

    function _buildPoolKey() internal view returns (PoolKey memory poolKey_) {
        (address token0, address token1) = address(wethToken) < address(richToken)
            ? (address(wethToken), address(richToken))
            : (address(richToken), address(wethToken));

        poolKey_ = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _deployTestTokenPkg() internal {
        IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet
        });

        erc20PermitPkg = ERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256(abi.encode(type(ERC20PermitDFPkg).name, pkgInit, "SingleVaultDetfAuction"))
                )
            )
        );
    }

    function _deployTestToken(string memory name_, string memory symbol_, bytes32 salt_) internal returns (IERC20 token_) {
        IERC20PermitDFPkg.PkgArgs memory pkgArgs = IERC20PermitDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            decimals: 18,
            totalSupply: TEST_TOKEN_TOTAL_SUPPLY,
            recipient: address(this),
            optionalSalt: salt_
        });

        token_ = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc20PermitPkg)), abi.encode(pkgArgs)));
    }

    function _fundWeth(address recipient_, uint256 amount_) internal {
        wethToken.transfer(recipient_, amount_);
    }

    function _fundRich(address recipient_, uint256 amount_) internal {
        richToken.transfer(recipient_, amount_);
    }

    function _deployWeightedPool8020Factory() internal {
        bytes memory initArgs =
            abi.encode(IBalancerVault(address(vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        address factoryAddr = create3Factory.create3WithArgs(
            type(WeightedPool8020Factory).creationCode,
            initArgs,
            keccak256("SingleVaultDetfAuctionWeightedPool8020Factory")
        );
        weightedPool8020Factory = IWeightedPool8020Factory(factoryAddr);
        vm.label(factoryAddr, "SingleVaultDetfAuctionWeightedPool8020Factory");
    }

    function _deployStandardExchangeRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SingleVaultDetfAuction_StandardExchangeRateProviderFacet")
            )
        );

        IStandardExchangeRateProviderDFPkg.PkgInit memory pkgInit = IStandardExchangeRateProviderDFPkg.PkgInit({
            rateProviderFacet: rateProviderFacet,
            diamondFactory: diamondPackageFactory
        });

        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("SingleVaultDetfAuction_StandardExchangeRateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "SingleVaultDetfAuction_StandardExchangeRateProviderDFPkg");
    }

    function _deployProtocolNFTVaultPkg() internal {
        protocolNFTVaultFacet = create3Factory.deployProtocolNFTVaultFacet();
        IFacet erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetfAuction_ERC721Facet"))
        );

        IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService
            .buildProtocolNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            protocolNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        protocolNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployProtocolNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployUniswapV4StandardExchangePkg() internal {
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();

        vm.startPrank(owner);
        wethRichVaultPkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV4StandardExchangePkgInit(
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                uniswapV4StandardExchangeInFacet,
                uniswapV4StandardExchangeOutFacet,
                indexedexManager,
                indexedexManager,
                permit2,
                poolManager
            )
        );
        vm.stopPrank();
    }
}
