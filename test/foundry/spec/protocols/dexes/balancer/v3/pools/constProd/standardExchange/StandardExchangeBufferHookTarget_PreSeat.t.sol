// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    PoolSwapParams,
    SwapKind,
    AddLiquidityKind,
    RemoveLiquidityKind,
    AddLiquidityParams,
    RemoveLiquidityParams
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/vaults/standard/exchange/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/vaults/standard/exchange/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol";

/// @dev Records Vault interactions in observation order.
contract MockBalancerV3Vault {
    enum Sel { SEND_TO, SETTLE, ADD_LIQUIDITY, REMOVE_LIQUIDITY }

    Sel[] public observed;
    bytes[] public payloads;
    uint256 public scriptedSettleReturn;

    function setScriptedSettleReturn(uint256 v) external { scriptedSettleReturn = v; }

    function sendTo(IERC20 token, address to, uint256 amount) external {
        observed.push(Sel.SEND_TO);
        payloads.push(abi.encode(token, to, amount));
    }

    function settle(IERC20 token, uint256 amountHint) external returns (uint256) {
        observed.push(Sel.SETTLE);
        payloads.push(abi.encode(token, amountHint));
        return scriptedSettleReturn;
    }

    function addLiquidity(AddLiquidityParams memory p)
        external
        returns (uint256[] memory, uint256, bytes memory)
    {
        observed.push(Sel.ADD_LIQUIDITY);
        payloads.push(abi.encode(p));
        return (p.maxAmountsIn, 0, "");
    }

    function removeLiquidity(RemoveLiquidityParams memory p)
        external
        returns (uint256, uint256[] memory, bytes memory)
    {
        observed.push(Sel.REMOVE_LIQUIDITY);
        payloads.push(abi.encode(p));
        return (0, p.minAmountsOut, "");
    }

    function observedCount() external view returns (uint256) { return observed.length; }
}

/// @dev Mock that implements IStandardExchange with scripted return values.
contract MockStandardExchange is IStandardExchange {
    uint256 public scriptedPreview;
    uint256 public scriptedAmountOut;

    function setPreview(uint256 v) external { scriptedPreview = v; }
    function setAmountOut(uint256 v) external { scriptedAmountOut = v; }

    // IStandardExchangeIn
    function previewExchangeIn(IERC20, uint256, IERC20) external pure returns (uint256) { return 0; }
    function exchangeIn(IERC20, uint256, IERC20, uint256, address, bool, uint256) external pure returns (uint256) {
        return 0;
    }

    // IStandardExchangeOut
    function previewExchangeOut(IERC20, IERC20, uint256) external view returns (uint256) {
        return scriptedPreview;
    }
    function exchangeOut(IERC20, uint256, IERC20, uint256, address, bool, uint256) external view returns (uint256) {
        return scriptedAmountOut;
    }
}

contract StaticRateProvider is IRateProvider {
    uint256 immutable R;
    constructor(uint256 r) { R = r; }
    function getRate() external view returns (uint256) { return R; }
}

/// @dev Concrete harness that wires the abstract hook target to mock infrastructure.
contract HookHarness is StandardExchangeBufferHookTarget {
    address public immutable VAULT;
    address public immutable FACTORY;

    constructor(address v, address f, IERC20 tta, IERC20 sh, IStandardExchange sev, IRateProvider rp) {
        VAULT = v;
        FACTORY = f;
        Repo._initialize(tta, sh, sev, rp, 0, 1);
    }

    function _balancerV3Vault() internal view override returns (address) { return VAULT; }
    function _expectedFactory() internal view override returns (address) { return FACTORY; }

    function setVirtualTTA(uint256 v) external { Repo._setVirtualTTA(v); }
    function setHookSharesDelta(int256 v) external { Repo._setHookSharesDelta(v); }
    function virtualTTA() external view returns (uint256) { return Repo._virtualTTA(); }
    function hookSharesDelta() external view returns (int256) { return Repo._hookSharesDelta(); }
}

contract HookPreSeatTest is Test {
    MockBalancerV3Vault vault;
    MockStandardExchange seVault;
    StaticRateProvider rp;
    HookHarness hook;

    address ttaAddr = address(0xAAA);
    address shareAddr = address(0xBBB);
    IERC20 tta = IERC20(ttaAddr);
    IERC20 shares = IERC20(shareAddr);

    function setUp() public {
        vault = new MockBalancerV3Vault();
        seVault = new MockStandardExchange();
        rp = new StaticRateProvider(1e18);
        // Stub share token decimals() and approve() so mock token addresses work.
        vm.mockCall(shareAddr, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(shareAddr, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
        hook = new HookHarness(address(vault), address(0xFAC), tta, shares, seVault, rp);
        hook.setVirtualTTA(100e18);
        hook.setHookSharesDelta(0);
    }

    function _sharesInParams(uint256 amountInScaled18, uint256[] memory bal)
        internal
        view
        returns (PoolSwapParams memory)
    {
        return PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: amountInScaled18,
            balancesScaled18: bal,
            indexIn: 1, // sharesIndex
            indexOut: 0, // ttaIndex
            router: address(0),
            userData: ""
        });
    }

    function test_preSeat_executesFourVaultCallsInOrder() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        // Y_TTA_scaled18 = (virtualTTA * amountIn) / (derivedY + amountIn)
        //                 = (100e18 * 10e18) / (100e18 + 10e18)
        uint256 vTTA = 100e18;
        uint256 amtIn = 10e18;
        uint256 Y_TTA = (vTTA * amtIn) / (vTTA + amtIn);
        // Set preview and amountOut to match Y_TTA so the redemption check passes.
        seVault.setPreview(Y_TTA);
        seVault.setAmountOut(Y_TTA);
        vault.setScriptedSettleReturn(Y_TTA);

        vm.prank(address(vault));
        bool ok = hook.onBeforeSwap(_sharesInParams(amtIn, bal), address(hook));
        assertTrue(ok);

        assertEq(vault.observedCount(), 4);
        assertEq(uint256(vault.observed(0)), uint256(MockBalancerV3Vault.Sel.SEND_TO));
        assertEq(uint256(vault.observed(1)), uint256(MockBalancerV3Vault.Sel.SETTLE));
        assertEq(uint256(vault.observed(2)), uint256(MockBalancerV3Vault.Sel.ADD_LIQUIDITY));
        assertEq(uint256(vault.observed(3)), uint256(MockBalancerV3Vault.Sel.REMOVE_LIQUIDITY));
    }

    function test_preSeat_updatesVirtualTTAAndHookSharesDelta() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        // x = virtualTTA = 100e18, amountIn = 10e18
        // y_pre = _derivedY = balancesScaled18[1] = 100e18 (hookSharesDelta=0, rate=1e18, decimals=18)
        // Y_TTA_scaled18 = (x * amountIn) / (y_pre + amountIn) = (100e18 * 10e18) / (100e18 + 10e18)
        uint256 x_ = 100e18;
        uint256 a_ = 10e18;
        uint256 expectedY = (x_ * a_) / (x_ + a_);
        seVault.setPreview(expectedY);
        seVault.setAmountOut(expectedY);
        vault.setScriptedSettleReturn(expectedY);

        vm.prank(address(vault));
        hook.onBeforeSwap(_sharesInParams(10e18, bal), address(hook));

        assertEq(hook.virtualTTA(), 100e18 - expectedY);
        // S = previewExchangeOut = expectedY; hookSharesDelta = 0 - int256(expectedY)
        assertEq(hook.hookSharesDelta(), -int256(expectedY));
    }

    function test_preSeat_revertsWhenDerivedYIsZero() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        // hookSharesDelta = 120e18 > actualSharesScaled=100e18 => _derivedY returns 0
        hook.setHookSharesDelta(int256(120e18));
        vm.expectRevert(IStandardExchangeBufferPool.PoolSharesSideExhausted.selector);
        vm.prank(address(vault));
        hook.onBeforeSwap(_sharesInParams(10e18, bal), address(hook));
    }

    function test_preSeat_revertsWhenVirtualTTAIsZero() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        hook.setVirtualTTA(0);
        vm.expectRevert(IStandardExchangeBufferPool.PoolTTASideExhausted.selector);
        vm.prank(address(vault));
        hook.onBeforeSwap(_sharesInParams(10e18, bal), address(hook));
    }

    function test_preSeat_TTAtoSharesIsNoOp() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        PoolSwapParams memory p = PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: 10e18,
            balancesScaled18: bal,
            indexIn: 0, // ttaIndex -> no-op path
            indexOut: 1,
            router: address(0),
            userData: ""
        });
        vm.prank(address(vault));
        bool ok = hook.onBeforeSwap(p, address(hook));
        assertTrue(ok);
        assertEq(vault.observedCount(), 0);
    }

    function test_preSeat_rejectsWrongCaller() public {
        uint256[] memory bal = new uint256[](2);
        bal[0] = 0;
        bal[1] = 100e18;
        vm.prank(address(0xDEAD));
        bool ok = hook.onBeforeSwap(_sharesInParams(10e18, bal), address(hook));
        assertFalse(ok);
    }
}
