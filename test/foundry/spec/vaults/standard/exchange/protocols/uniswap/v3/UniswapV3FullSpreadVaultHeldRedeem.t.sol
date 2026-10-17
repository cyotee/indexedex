// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Vm} from "forge-std/Vm.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice RC-01 on the production V3 FullSpread proxy. One family does not close another.
contract UniswapV3FullSpreadVaultHeldRedeem_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 1_000_000e18);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        a.mint(address(this), 2_000 ether);
        b.mint(address(this), 2_000 ether);
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
        recipient = makeAddr("v3SyRecipient");
    }

    /// @dev The IN wrapper still rejects a direct call. That is not the yield path.
    function test_inWrapperRejectsDirectCall_yieldDoesNotUseIt() public {
        address facet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        (bool ok_, bytes memory result_) = facet_.staticcall(
            abi.encodeWithSignature("UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()")
        );
        assertTrue(ok_);
        address delegate_ = abi.decode(result_, (address));
        assertGt(delegate_.code.length, 0);
        assertLe(delegate_.code.length, 24_576);
        bytes memory data_ = abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", address(token0), 1, 0, recipient
        );
        (ok_, result_) = delegate_.call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("DelegateCallRequired()"));
        (ok_, result_) = address(vault).call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        address eoa = makeAddr("v3SyEoa");
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, true);
        assertEq(vault.balanceOf(address(this)), callerBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public {
        uint256 requested = 1e15;
        vault.transfer(address(vault), requested * 2);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.expectCall(address(vault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 quoted = IStandardizedYield(address(vault)).previewRedeem(address(token0), requested);
        assertGt(quoted, 0);
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), quoted, true);
        assertEq(paid, quoted);
        assertEq(vault.balanceOf(address(this)), callerBefore, "caller shares are not the holder");
        assertEq(vault.balanceOf(address(vault)), vaultBefore - requested, "burns only the requested vault shares");
        assertEq(token0.balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCodelessHolder() public {
        address holder = makeAddr("v3OrdinaryHolder");
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

    function test_RC01_bothBurnSites_sameHolder() public {
        address holder = makeAddr("v3BothSites");
        uint256 requested = 1e15;
        vault.transfer(holder, requested * 2);
        assertTrue(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(address(vault)).canOpenBoundPoolOps());
        vm.prank(holder);
        uint256 poolPaid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(poolPaid, 0);
        assertEq(vault.balanceOf(holder), requested, "pool-access burn used the same holder");

        V3LockedRedeem locked = new V3LockedRedeem();
        token0.transfer(address(locked), 1 ether);
        IERC20(pool.token1()).transfer(address(locked), 1 ether);
        locked.redeemWhileLocked(pool, address(vault), holder, address(token0), requested, recipient);
        assertEq(vault.balanceOf(holder), 0, "sleeve burn used the same holder");
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_RC01_insufficientHolderBalance_reverts() public {
        address holder = makeAddr("v3Short");
        uint256 holderBefore = vault.balanceOf(holder);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, false);
        assertEq(vault.balanceOf(holder), holderBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_unmetMinimum_reverts() public {
        address holder = makeAddr("v3Min");
        uint256 requested = 1e15;
        vault.transfer(holder, requested);
        uint256 holderBefore = vault.balanceOf(holder);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.prank(holder);
        vm.expectRevert(UniswapV3FullSpreadStandardExchangeVaultInBase.UniswapV3ExchangeIn_SlippageExceeded.selector);
        IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), type(uint256).max, false);
        assertEq(vault.balanceOf(holder), holderBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), outBefore);
    }

    function test_RC01_publicFalseFlag_pullsThenBurnsVault() public {
        uint256 requested = 1e15;
        address caller = address(this);
        vault.approve(address(vault), requested);
        uint256 callerBefore = vault.balanceOf(caller);
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 paid = vault.exchangeIn(
            IERC20(address(vault)), requested, token0, 0, recipient, false, block.timestamp
        );
        assertGt(paid, 0);
        assertEq(vault.balanceOf(caller), callerBefore - requested, "pulled once; caller is not burned again");
        assertEq(vault.balanceOf(address(vault)), vaultBefore, "pulled shares are burned from the vault");
        assertEq(token0.balanceOf(recipient), paid);
    }

    function test_RC01_publicTrueFlag_creditsUnbookedAndBurnsVault() public {
        uint256 requested = 1e15;
        uint256 extra = requested;
        vault.transfer(address(vault), requested + extra);
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

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/// @dev Enters the real pool lock so the sleeve burn runs. Not a vault mock.
contract V3LockedRedeem is IUniswapV3SwapCallback {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function redeemWhileLocked(
        IUniswapV3Pool pool,
        address vault,
        address holder,
        address tokenOut,
        uint256 shares,
        address receiver
    ) external {
        bool zeroForOne = tokenOut == pool.token0();
        pool.swap(
            address(this),
            zeroForOne,
            1,
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(vault, holder, tokenOut, shares, receiver)
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        (address vault, address holder, address tokenOut, uint256 shares, address receiver) =
            abi.decode(data, (address, address, address, uint256, address));
        require(
            !IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(vault).canOpenBoundPoolOps(),
            "sleeve path requires the pool lock"
        );
        VM.prank(holder);
        IStandardizedYield(vault).redeem(receiver, shares, tokenOut, 0, false);
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        if (amount0Delta > 0) IERC20(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
    }
}
