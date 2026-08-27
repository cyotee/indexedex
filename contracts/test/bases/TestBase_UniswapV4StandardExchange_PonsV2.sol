// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

import {PonsV2FeeEscrow} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2FeeEscrow.sol";
import {PonsV2BuybackVault} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BuybackVault.sol";
import {PonsV2LaunchLocker} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchLocker.sol";
import {PonsV2MemeHook} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {PonsV2LaunchFactory} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchFactory.sol";
import {PonsV2LaunchDeployer} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchDeployer.sol";
import {PonsV2GraduationExecutor} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2GraduationExecutor.sol";
import {PonsV2LauncherToken} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LauncherToken.sol";
import {PonsV2BondingCurve} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {
    GraduationPhase,
    IPonsV2LaunchFactory
} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/**
 * @title TestBase_UniswapV4StandardExchange_PonsV2
 * @notice Hermetic R20 fixture: pons v2 WETH-quoted launch graduates on the **same**
 *         Uniswap V4 PoolManager that IndexedEx Uni V4 SE `PkgInit` is bound to.
 * @dev Does not inherit `TestBase_PonsFamilyV2.setUp` (that path `new`s a second
 *      PoolManager). Wiring is copied from that TestBase with injected manager,
 *      PositionManager, Permit2, and WETH.
 */
abstract contract TestBase_UniswapV4StandardExchange_PonsV2 is TestBase_UniswapV4StandardExchange {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant PONS_V2_LAUNCH_FEE = 0.0005 ether;
    uint256 internal constant PONS_V2_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant PONS_V2_PHANTOM_QUOTE = 1 ether;
    uint256 internal constant PONS_V2_GRADUATION_THRESHOLD = 4.2 ether;
    uint256 internal constant PONS_V2_CURVE_FEE_BPS = 100;
    uint24 internal constant PONS_V2_POOL_FEE = 0;
    int24 internal constant PONS_V2_TICK_SPACING = 60;

    uint160 internal constant MEME_HOOK_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
    );

    IPositionManager internal ponsPositionManager;
    IPositionDescriptor internal ponsPositionDescriptor;

    PonsV2FeeEscrow internal ponsV2FeeEscrow;
    PonsV2MemeHook internal ponsV2MemeHook;
    PonsV2BuybackVault internal ponsV2BuybackVault;
    PonsV2LaunchLocker internal ponsV2Locker;
    PonsV2LaunchFactory internal ponsV2Factory;
    PonsV2LaunchDeployer internal ponsV2LaunchDeployer;
    PonsV2GraduationExecutor internal ponsV2GraduationExecutor;

    address internal ponsV2Owner;
    address internal ponsV2FeeSink;
    address internal ponsV2Launcher;
    uint256 internal ponsV2LaunchConfigId;

    address internal launchToken;
    address internal launchCurve;
    PoolKey internal graduatedPoolKey;
    IStandardExchangeProxy internal ponsSe;

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchange.setUp();
        _deployPonsV2OnIndexedExPoolManager();
        _approveWethPairAndGraduate();
        ponsSe = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(graduatedPoolKey));
        vm.label(address(ponsSe), "UniV4Se_ponsV2");
    }

    /// @notice Deploy the real pons v2 stack against this TestBase's PoolManager / Permit2 / WETH.
    function _deployPonsV2OnIndexedExPoolManager() internal {
        ponsV2Owner = makeAddr("ponsV2Owner");
        ponsV2FeeSink = makeAddr("ponsV2FeeSink");
        ponsV2Launcher = makeAddr("ponsV2Launcher");

        ponsPositionDescriptor =
            new PositionDescriptor(IPoolManager(address(poolManager)), address(weth), bytes32("ETH"));
        ponsPositionManager = IPositionManager(
            address(
                new PositionManager(
                    IPoolManager(address(poolManager)),
                    IAllowanceTransfer(address(permit2)),
                    100_000,
                    ponsPositionDescriptor,
                    IWETH9(address(weth))
                )
            )
        );
        vm.label(address(ponsPositionManager), "ponsPositionManager");

        ponsV2FeeEscrow = new PonsV2FeeEscrow();

        bytes memory hookArgs =
            abi.encode(IPoolManager(address(poolManager)), ponsV2FeeEscrow, ponsV2FeeSink, ponsV2Owner);
        (address predictedHook, bytes32 hookSalt) =
            HookMiner.find(address(this), MEME_HOOK_FLAGS, type(PonsV2MemeHook).creationCode, hookArgs);
        ponsV2MemeHook = new PonsV2MemeHook{salt: hookSalt}(
            IPoolManager(address(poolManager)), ponsV2FeeEscrow, ponsV2FeeSink, ponsV2Owner
        );
        require(address(ponsV2MemeHook) == predictedHook, "hook address mismatch");
        vm.label(address(ponsV2MemeHook), "ponsV2MemeHook");

        vm.startPrank(ponsV2Owner);
        ponsV2BuybackVault = new PonsV2BuybackVault(ponsV2Owner, ponsV2MemeHook, ponsV2FeeEscrow);
        ponsV2Locker = new PonsV2LaunchLocker(ponsV2Owner, address(ponsPositionManager));

        ponsV2Factory = new PonsV2LaunchFactory(
            ponsV2Owner,
            IPoolManager(address(poolManager)),
            ponsPositionManager,
            IAllowanceTransfer(address(permit2)),
            ponsV2Locker,
            ponsV2MemeHook,
            ponsV2FeeEscrow,
            ponsV2BuybackVault,
            PONS_V2_LAUNCH_FEE
        );

        ponsV2LaunchDeployer = new PonsV2LaunchDeployer(address(ponsV2Factory));
        ponsV2GraduationExecutor = new PonsV2GraduationExecutor(
            ponsPositionManager, IAllowanceTransfer(address(permit2)), ponsV2Locker, address(ponsV2Factory)
        );

        ponsV2MemeHook.setFactory(address(ponsV2Factory));
        ponsV2MemeHook.setBuybackVault(ponsV2BuybackVault);
        ponsV2BuybackVault.setFactory(address(ponsV2Factory));
        ponsV2Locker.setFactory(address(ponsV2Factory));
        ponsV2Factory.setLaunchDeployer(ponsV2LaunchDeployer);
        ponsV2Factory.setGraduationExecutor(ponsV2GraduationExecutor);

        ponsV2LaunchConfigId = ponsV2Factory.addLaunchConfig(
            PonsV2LaunchFactory.LaunchConfig({
                supply: PONS_V2_SUPPLY,
                curveFeeBps: PONS_V2_CURVE_FEE_BPS,
                phantomQuote: PONS_V2_PHANTOM_QUOTE,
                graduationThreshold: PONS_V2_GRADUATION_THRESHOLD,
                poolFee: PONS_V2_POOL_FEE,
                tickSpacing: PONS_V2_TICK_SPACING,
                enabled: true
            })
        );
        ponsV2Factory.setPairTokenEconomics(
            address(weth), PONS_V2_PHANTOM_QUOTE, PONS_V2_GRADUATION_THRESHOLD, 18
        );
        ponsV2Factory.setPairTokenApproved(address(weth), true);
        ponsV2Factory.setSnipeTaxStartBps(0);
        ponsV2Factory.setLaunchEnabled(true);
        vm.stopPrank();

        vm.deal(ponsV2Launcher, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    /// @notice Launch with WETH quote, buy through the threshold, seed the V4 pool.
    function _approveWethPairAndGraduate() internal {
        PonsV2LaunchFactory.TokenParams memory params = _defaultV2TokenParams("Pons Se Wrap", "PSEW");
        vm.prank(ponsV2Launcher);
        (launchToken, launchCurve) =
            ponsV2Factory.launchToken{value: PONS_V2_LAUNCH_FEE}(params, ponsV2LaunchConfigId, address(weth));

        uint256 quoteIn = 10 ether;
        weth.deposit{value: quoteIn}();
        IERC20(address(weth)).approve(launchCurve, quoteIn);
        PonsV2BondingCurve(payable(launchCurve)).buy(quoteIn, 0, address(this));

        IPonsV2LaunchFactory.LaunchedToken memory rec = ponsV2Factory.getLaunchedToken(launchToken);
        if (rec.phase == GraduationPhase.NotGraduated) {
            ponsV2Factory.graduate(launchToken);
            rec = ponsV2Factory.getLaunchedToken(launchToken);
        }
        if (rec.phase == GraduationPhase.Swept) {
            ponsV2Factory.createGraduatedPool(launchToken);
        }
        rec = ponsV2Factory.getLaunchedToken(launchToken);
        require(rec.phase == GraduationPhase.PoolCreated, "pons v2 not PoolCreated");

        graduatedPoolKey = _poolKeyForLaunch(launchToken, rec);
    }

    function _poolKeyForLaunch(address token, IPonsV2LaunchFactory.LaunchedToken memory rec)
        internal
        view
        returns (PoolKey memory key)
    {
        address token0;
        address token1;
        if (rec.pairToken < token) {
            token0 = rec.pairToken;
            token1 = token;
        } else {
            token0 = token;
            token1 = rec.pairToken;
        }
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: rec.poolFee,
            tickSpacing: rec.tickSpacing,
            hooks: IHooks(address(ponsV2MemeHook))
        });
    }

    function _defaultV2TokenParams(string memory name_, string memory symbol_)
        internal
        pure
        returns (PonsV2LaunchFactory.TokenParams memory)
    {
        return PonsV2LaunchFactory.TokenParams({
            name: name_,
            symbol: symbol_,
            logo: "ipfs://logo",
            description: "hermetic pons v2 Uni V4 SE wrap",
            socials: PonsV2LauncherToken.Socials({
                twitter: "https://x.com/pons",
                telegram: "",
                discord: "",
                website: "https://pons.family",
                farcaster: ""
            }),
            creatorFeeRecipient: address(0),
            creatorTaxBps: 0,
            buybackEnabled: false,
            expectedEconomics: bytes32(0),
            salt: keccak256(abi.encodePacked(name_, symbol_))
        });
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _fullRangeTicks() internal view returns (int24 minTick, int24 maxTick) {
        minTick = TickMath.minUsableTick(graduatedPoolKey.tickSpacing);
        maxTick = TickMath.maxUsableTick(graduatedPoolKey.tickSpacing);
    }

    function _seLiquidity(address owner_) internal view returns (uint128 liq) {
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (liq,,) = StateLibrary.getPositionInfo(
            IPoolManager(address(poolManager)),
            graduatedPoolKey.toId(),
            owner_,
            minTick,
            maxTick,
            bytes32(0)
        );
    }

    function _wrapWeth(address to, uint256 amount) internal {
        vm.deal(to, to.balance + amount);
        vm.prank(to);
        weth.deposit{value: amount}();
    }
}
