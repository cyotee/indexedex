// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {TestBase_UniswapV4StandardExchange} from
    "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

import {
    UniV4DetfBondNft_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNft_FactoryService.sol";
import {
    IUniV4DetfBondNftDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftDFPkg.sol";
import {
    UniV4DetfRebasingClaim_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaim_FactoryService.sol";
import {
    IUniV4DetfRebasingClaimDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeDETF_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETF_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeDETFDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFDFPkg.sol";
import {
    IUniswapV4SingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFInfoTarget.sol";

/// @title TestBase_UniswapV4SingleStandardExchangeDETF
/// @notice Gold hermetic TestBase: Crane Uni V4 + Uni V4 SE backing + DETF family.
abstract contract TestBase_UniswapV4SingleStandardExchangeDETF is TestBase_UniswapV4StandardExchange {
    using UniV4DetfBondNft_FactoryService for ICreate3FactoryProxy;
    using UniV4DetfRebasingClaim_FactoryService for ICreate3FactoryProxy;
    using UniswapV4SingleStandardExchangeDETF_FactoryService for ICreate3FactoryProxy;
    using UniswapV4SingleStandardExchangeDETF_FactoryService for IVaultRegistryDeployment;

    IFacet internal uniV4DetfBondNftFacet;
    IFacet internal uniV4DetfRebasingClaimFacet;
    IFacet internal uniV4SingleSeDetfFacet;
    IUniV4DetfBondNftDFPkg internal bondNftPkg;
    IUniV4DetfRebasingClaimDFPkg internal rebasingClaimPkg;
    IUniswapV4SingleStandardExchangeDETFDFPkg internal uniV4SingleSeDetfPkg;

    IStandardExchangeProxy internal backingSeVault;
    IERC20 internal pairToken;
    IERC20 internal otherSeToken;
    address internal detfInstance;
    ERC20PermitMintableStub internal backingTokenA;
    ERC20PermitMintableStub internal backingTokenB;
    PoolKey internal backingPoolKey;

    uint24 internal constant LISTING_FEE = 3000;
    int24 internal constant LISTING_TICK_SPACING = 60;
    uint24 internal constant WIDTH_MULTIPLIER = 10;
    uint24 internal constant BACKING_FEE = 3000;
    int24 internal constant BACKING_TICK_SPACING = 60;

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchange.setUp();

        // Deploy family facets + child DFPkgs (pure Crane) + DETF DFPkg (registry).
        uniV4DetfBondNftFacet = create3Factory.deployUniV4DetfBondNftFacet();
        uniV4DetfRebasingClaimFacet = create3Factory.deployUniV4DetfRebasingClaimFacet();
        uniV4SingleSeDetfFacet = create3Factory.deployUniswapV4SingleStandardExchangeDETFFacet();

        bondNftPkg = create3Factory.deployUniV4DetfBondNftDFPkg(
            IUniV4DetfBondNftDFPkg.PkgInit({
                bondNftFacet: uniV4DetfBondNftFacet, diamondFactory: diamondPackageFactory
            })
        );

        rebasingClaimPkg = create3Factory.deployUniV4DetfRebasingClaimDFPkg(
            IUniV4DetfRebasingClaimDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                rebasingClaimFacet: uniV4DetfRebasingClaimFacet,
                diamondFactory: diamondPackageFactory
            })
        );

        vm.startPrank(owner);
        uniV4SingleSeDetfPkg = UniswapV4SingleStandardExchangeDETF_FactoryService
            .deployUniswapV4SingleStandardExchangeDETFDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            IUniswapV4SingleStandardExchangeDETFDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                exchangeInFacet: uniV4SingleSeDetfFacet,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                poolManager: IPoolManager(address(poolManager)),
                bondNftPkg: bondNftPkg,
                rebasingClaimPkg: rebasingClaimPkg,
                diamondFactory: diamondPackageFactory
            })
        );
        vm.stopPrank();
    }

    /// @dev Deploy mintable tokens + backing Uni V4 pool + SE vault with seed liquidity/shares.
    function _deployBackingSeAndSeed() internal {
        backingTokenA = new ERC20PermitMintableStub("Backing A", "BKA", 18, address(this), 0);
        backingTokenB = new ERC20PermitMintableStub("Backing B", "BKB", 18, address(this), 0);
        if (address(backingTokenA) < address(backingTokenB)) {
            pairToken = IERC20(address(backingTokenA));
            otherSeToken = IERC20(address(backingTokenB));
        } else {
            pairToken = IERC20(address(backingTokenB));
            otherSeToken = IERC20(address(backingTokenA));
        }

        backingPoolKey = PoolKey({
            currency0: Currency.wrap(address(pairToken) < address(otherSeToken) ? address(pairToken) : address(otherSeToken)),
            currency1: Currency.wrap(address(pairToken) < address(otherSeToken) ? address(otherSeToken) : address(pairToken)),
            fee: BACKING_FEE,
            tickSpacing: BACKING_TICK_SPACING,
            hooks: IHooks(address(0))
        });
        // Ensure currency0 < currency1 by address.
        if (Currency.unwrap(backingPoolKey.currency0) > Currency.unwrap(backingPoolKey.currency1)) {
            (backingPoolKey.currency0, backingPoolKey.currency1) =
                (backingPoolKey.currency1, backingPoolKey.currency0);
        }

        poolManager.initialize(backingPoolKey, TickMath.getSqrtPriceAtTick(0));

        UniV4DetfLiquiditySeeder seeder = new UniV4DetfLiquiditySeeder(IPoolManager(address(poolManager)));
        backingTokenA.mint(address(seeder), 1_000_000 ether);
        backingTokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(backingPoolKey, tickLower, tickUpper, liquidity);

        backingSeVault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(backingPoolKey, 60));

        // Bootstrap SE shares for tests.
        address user = address(this);
        backingTokenA.mint(user, 50_000 ether);
        backingTokenB.mint(user, 50_000 ether);
        IERC20(address(backingTokenA)).approve(address(backingSeVault), type(uint256).max);
        IERC20(address(backingTokenB)).approve(address(backingSeVault), type(uint256).max);
        IStandardExchangeIn(address(backingSeVault)).exchangeIn(
            IERC20(address(backingTokenA)),
            10_000 ether,
            IERC20(address(backingSeVault)),
            0,
            user,
            false,
            block.timestamp + 1 days
        );
    }

    function _deployDetfInstance(uint160 sqrtPriceX96_, ThresholdMode mode_) internal returns (address detf_) {
        require(address(backingSeVault) != address(0), "backing SE not deployed");

        IUniswapV4SingleStandardExchangeDETFDFPkg.PkgArgs memory args = IUniswapV4SingleStandardExchangeDETFDFPkg
            .PkgArgs({
            name: "UniV4 Single SE DETF",
            symbol: "U4DETF",
            standardExchangeVault: backingSeVault,
            standardExchangeVaultShare: IERC20(address(0)),
            pairToken: pairToken,
            poolFee: LISTING_FEE,
            tickSpacing: LISTING_TICK_SPACING,
            hooks: address(0),
            sqrtPriceX96: sqrtPriceX96_,
            twapSeconds: 1800,
            widthMultiplier: WIDTH_MULTIPLIER,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: mode_,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });

        detf_ = uniV4SingleSeDetfPkg.deployVault(args);
        detfInstance = detf_;
        vm.label(detf_, "UniV4SingleSeDetf");
    }

    function _detfInfo() internal view returns (IUniswapV4SingleStandardExchangeDETFInfo) {
        return IUniswapV4SingleStandardExchangeDETFInfo(detfInstance);
    }
}

/// @dev Minimal liquidity seeder for hermetic PoolManager tests.
contract UniV4DetfLiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta delta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, delta.amount0());
        _settle(poolKey.currency1, delta.amount1());
        return abi.encode(delta);
    }

    function _settle(Currency currency, int128 amount) internal {
        if (amount < 0) {
            poolManager.sync(currency);
            currency.transfer(address(poolManager), uint128(-amount));
            poolManager.settle();
        } else if (amount > 0) {
            poolManager.take(currency, address(this), uint128(amount));
        }
    }
}
