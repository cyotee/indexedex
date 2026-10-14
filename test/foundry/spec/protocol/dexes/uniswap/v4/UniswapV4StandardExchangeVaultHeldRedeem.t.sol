// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeSYExecutionAssertions} from "contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol";

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";

/// @notice RC-01 on the production legacy V4 proxy. The V3 file does not close this family.
contract UniswapV4StandardExchangeVaultHeldRedeem_Test is TestBase_UniswapV4StandardExchange, NativeSYExecutionAssertions {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    PoolKey internal poolKey;
    IERC20 internal token0;
    address internal recipient;
    Rc01V4LiquiditySeeder internal seeder;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        (address token0Address, address token1Address) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        poolKey = PoolKey({
            currency0: Currency.wrap(token0Address),
            currency1: Currency.wrap(token1Address),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));
        seeder = new Rc01V4LiquiditySeeder(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liquidity);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        token0 = IERC20(token0Address);
        IERC20 token1 = IERC20(token1Address);
        tokenA.mint(address(this), 2_000 ether);
        tokenB.mint(address(this), 2_000 ether);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000 ether;
        amounts[1] = 1_000 ether;
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 1, address(this), false, block.timestamp
        );
        recipient = makeAddr("v4SyRecipient");
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        vault.transfer(address(vault), 1 ether);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        address eoa = makeAddr("v4SyEoa");
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, true);
        assertEq(vault.balanceOf(address(this)), callerBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public noSelfCalls(address(vault)) {
        uint256 requested = 1e15;
        vault.transfer(address(vault), requested * 2);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        address third = makeAddr("v4Third");
        vm.expectCall(address(vault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 quoted = IStandardizedYield(address(vault)).previewRedeem(address(token0), requested);
        assertGt(quoted, 0);
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), quoted, true);
        assertEq(paid, quoted);
        assertEq(vault.balanceOf(address(this)), callerBefore, "caller shares are not the holder");
        assertEq(vault.balanceOf(address(vault)), vaultBefore - requested, "burns only the requested vault shares");
        assertEq(vault.balanceOf(third), 0, "a third-party wallet is not the holder");
        assertEq(token0.balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCodelessHolder() public noSelfCalls(address(vault)) {
        address holder = makeAddr("v4OrdinaryHolder");
        assertEq(holder.code.length, 0);
        uint256 requested = 1e15;
        vault.transfer(holder, requested);
        uint256 holderBefore = vault.balanceOf(holder);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 thirdBefore = vault.balanceOf(address(this));
        vm.expectCall(address(vault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        vm.prank(holder);
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(paid, 0);
        assertEq(vault.balanceOf(holder), holderBefore - requested, "burns the code-less caller");
        assertEq(vault.balanceOf(address(vault)), vaultBefore, "does not move shares onto the vault");
        assertEq(vault.balanceOf(address(this)), thirdBefore, "a third-party wallet is not the holder");
        assertEq(token0.balanceOf(recipient), paid);
        assertEq(vault.allowance(holder, address(vault)), 0, "ordinary redemption needs no share allowance");
    }

    function test_RC01_bothBurnSites_sameHolder() public noSelfCalls(address(vault)) {
        address holder = makeAddr("v4BothSites");
        uint256 requested = 1e15;
        vault.transfer(holder, requested * 2);
        assertTrue(IUniswapV4StandardExchangeLiquidReserve(address(vault)).canOpenPoolManagerUnlock());
        vm.prank(holder);
        uint256 poolPaid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(poolPaid, 0);
        assertEq(vault.balanceOf(holder), requested, "pool-access burn used the same holder");

        V4LockedRedeem locked = new V4LockedRedeem(poolManager);
        locked.redeemWhileLocked(address(vault), holder, address(token0), requested, recipient);
        assertEq(vault.balanceOf(holder), 0, "sleeve burn used the same holder");
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_RC01_insufficientHolderBalance_reverts() public {
        address holder = makeAddr("v4Short");
        uint256 holderBefore = vault.balanceOf(holder);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        vm.prank(holder);
        vm.expectRevert();
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, false);
        assertEq(vault.balanceOf(holder), holderBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_unmetMinimum_reverts() public {
        address holder = makeAddr("v4Min");
        uint256 requested = 1e15;
        vault.transfer(holder, requested);
        uint256 holderBefore = vault.balanceOf(holder);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.prank(holder);
        vm.expectRevert(UniswapV4StandardExchangeInBase.UniswapV4ExchangeIn_SlippageExceeded.selector);
        IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), type(uint256).max, false);
        assertEq(vault.balanceOf(holder), holderBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), outBefore);
    }

    function test_RC01_publicFalseFlag_pullsThenBurnsVault() public {
        uint256 requested = 1e15;
        vault.approve(address(vault), requested);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 paid = vault.exchangeIn(
            IERC20(address(vault)), requested, token0, 0, recipient, false, block.timestamp
        );
        assertGt(paid, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore - requested, "pulled once; caller is not burned again");
        assertEq(vault.balanceOf(address(vault)), vaultBefore, "pulled shares are burned from the vault");
        assertEq(token0.balanceOf(recipient), paid);
    }

    function test_RC01_publicTrueFlag_creditsUnbookedAndBurnsVault() public {
        uint256 requested = 1e15;
        vault.transfer(address(vault), requested * 2);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 paid = vault.exchangeIn(
            IERC20(address(vault)), requested, token0, 0, recipient, true, block.timestamp
        );
        assertGt(paid, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore, "does not burn the original caller again");
        assertEq(vault.balanceOf(address(vault)), vaultBefore - requested, "credits and burns only the requested unbooked shares");
        assertEq(token0.balanceOf(recipient), paid);
    }

    function test_exchangeOut_stillBurnsCallerShares() public {
        uint256 desired = 1e12;
        uint256 shares = vault.previewExchangeOut(IERC20(address(vault)), token0, desired);
        uint256 before = vault.balanceOf(address(this));
        uint256 burned = vault.exchangeOut(
            IERC20(address(vault)), shares, token0, desired, recipient, false, block.timestamp
        );
        assertEq(burned, shares);
        assertEq(vault.balanceOf(address(this)), before - burned);
        assertGe(token0.balanceOf(recipient), desired);
    }
}

contract Rc01V4LiquiditySeeder is IUnlockCallback {
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
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
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

/// @dev Enters the real PoolManager unlock so the sleeve burn runs. Not a vault mock.
contract V4LockedRedeem is IUnlockCallback {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function redeemWhileLocked(address vault, address holder, address tokenOut, uint256 shares, address receiver)
        external
    {
        poolManager.unlock(abi.encode(vault, holder, tokenOut, shares, receiver));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");
        (address vault, address holder, address tokenOut, uint256 shares, address receiver) =
            abi.decode(data, (address, address, address, uint256, address));
        require(
            !IUniswapV4StandardExchangeLiquidReserve(vault).canOpenPoolManagerUnlock(),
            "sleeve path requires the pool manager lock"
        );
        VM.prank(holder);
        IStandardizedYield(vault).redeem(receiver, shares, tokenOut, 0, false);
        return "";
    }
}
