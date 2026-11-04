// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault as HBase} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook as PBase} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/// USDT-style token: approve/transfer/transferFrom return NO data.
contract NoReturnToken {
    string public name = "Tether-like"; string public symbol = "NRT"; uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    constructor(address to, uint256 amt) { balanceOf[to] = amt; totalSupply = amt; }
    function approve(address s, uint256 a) external { allowance[msg.sender][s] = a; }
    function transfer(address to, uint256 a) external { balanceOf[msg.sender] -= a; balanceOf[to] += a; }
    function transferFrom(address f, address to, uint256 a) external {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        balanceOf[f] -= a; balanceOf[to] += a;
    }
}

/// Differential control: identical no-return token EXCEPT approve returns bool.
contract NoReturnTokenBoolApprove {
    string public name = "Tether-like-B"; string public symbol = "NRTB"; uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    constructor(address to, uint256 amt) { balanceOf[to] = amt; totalSupply = amt; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external { balanceOf[msg.sender] -= a; balanceOf[to] += a; }
    function transferFrom(address f, address to, uint256 a) external {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        balanceOf[f] -= a; balanceOf[to] += a;
    }
}

library LowLevel {
    function xfer(address t, address to, uint256 a) internal {
        (bool ok, bytes memory r) = t.call(abi.encodeWithSelector(0xa9059cbb, to, a));
        require(ok && (r.length == 0 || abi.decode(r, (bool))), "xfer");
    }
}

contract RawApproveHooklessTest is HBase, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    address constant ALICE = address(0xA11CE); // unprivileged pool creator / vault deployer
    PoolKey key;

    function _mkKey(address a, address b) internal pure returns (PoolKey memory k) {
        (address t0, address t1) = a < b ? (a, b) : (b, a);
        k = PoolKey(Currency.wrap(t0), Currency.wrap(t1), 500, 10, IHooks(address(0)));
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        (BalanceDelta d,) = poolManager.modifyLiquidity(key, ModifyLiquidityParams(
            TickMath.minUsableTick(10), TickMath.maxUsableTick(10), int256(uint256(1_000e18)), bytes32(0)), "");
        poolManager.sync(key.currency0); LowLevel.xfer(Currency.unwrap(key.currency0), address(poolManager), uint128(-d.amount0())); poolManager.settle();
        poolManager.sync(key.currency1); LowLevel.xfer(Currency.unwrap(key.currency1), address(poolManager), uint128(-d.amount1())); poolManager.settle();
        return "";
    }

    function test_control_standardTokens_deployOk() public {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", 18, address(this), 1e30);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        key = _mkKey(address(a), address(b));
        poolManager.initialize(key, uint160(1 << 96));
        poolManager.unlock("");
        vm.prank(ALICE, ALICE);
        address v = uniswapV4StandardExchangeDFPkg.deployVault(key);
        console2.log("control vault deployed", v);
        assertTrue(v.code.length > 0);
    }

    function test_noReturnToken_hookless_deployReverts() public {
        NoReturnToken nrt = new NoReturnToken(address(this), 1e30);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        key = _mkKey(address(nrt), address(b));
        poolManager.initialize(key, uint160(1 << 96));
        poolManager.unlock(""); // pool itself is fully usable with the no-return token (V4 core uses low-level transfer)
        console2.log("PM NRT balance after honest LP", nrt.balanceOf(address(poolManager)));
        assertGt(nrt.balanceOf(address(poolManager)), 0);

        vm.prank(ALICE, ALICE);
        (bool ok, bytes memory ret) = address(uniswapV4StandardExchangeDFPkg).call(
            abi.encodeCall(uniswapV4StandardExchangeDFPkg.deployVault, (key)));
        console2.log("deployVault ok?", ok);
        console2.logBytes(ret);
        assertFalse(ok, "deployVault must revert for no-return token");
        assertEq(bytes4(ret), bytes4(0xd6bda275), "factory wraps inner revert as FailedCall()");

        // permanence: retry still reverts (no admin path changes behavior short of a package upgrade)
        vm.prank(ALICE, ALICE);
        vm.expectRevert();
        uniswapV4StandardExchangeDFPkg.deployVault(key);
    }
}

contract RawApproveHooklessDiffTest is RawApproveHooklessTest {
    /// Same no-return transfer/transferFrom, only approve fixed -> deploy succeeds => approve is the sole blocker.
    function test_diff_onlyApproveReturnsBool_deployOk() public {
        NoReturnTokenBoolApprove t = new NoReturnTokenBoolApprove(address(this), 1e30);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        key = _mkKey(address(t), address(b));
        poolManager.initialize(key, uint160(1 << 96));
        poolManager.unlock("");
        vm.prank(ALICE, ALICE);
        address v = uniswapV4StandardExchangeDFPkg.deployVault(key);
        console2.log("diff vault deployed (approve->bool, transfer no-return)", v);
        assertTrue(v.code.length > 0);
    }
}

contract RawApprovePonsTest is PBase {
    function test_noReturnToken_pons_deployReverts() public {
        NoReturnToken nrt = new NoReturnToken(address(this), 1e30);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        (address t0, address t1) = address(nrt) < address(b) ? (address(nrt), address(b)) : (address(b), address(nrt));
        PoolKey memory k = PoolKey(Currency.wrap(t0), Currency.wrap(t1), 0, 60, IHooks(address(ponsHook)));
        ponsHook.registerPool(k, address(b), address(this), address(this), 0, false, ponsHook.currentFeePolicy());
        poolManager.initialize(k, uint160(1 << 96));

        vm.prank(address(0xA11CE), address(0xA11CE));
        (bool ok, bytes memory ret) = address(uniswapV4StandardExchangeDFPkg).call(
            abi.encodeCall(uniswapV4StandardExchangeDFPkg.deployVault, (k)));
        console2.log("pons deployVault ok?", ok);
        console2.logBytes(ret);
        assertFalse(ok);
        assertEq(bytes4(ret), bytes4(0xd6bda275));
    }

    function test_control_pons_standardTokens_deployOk() public {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", 18, address(this), 1e30);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        (address t0, address t1) = address(a) < address(b) ? (address(a), address(b)) : (address(b), address(a));
        PoolKey memory k = PoolKey(Currency.wrap(t0), Currency.wrap(t1), 0, 60, IHooks(address(ponsHook)));
        ponsHook.registerPool(k, address(b), address(this), address(this), 0, false, ponsHook.currentFeePolicy());
        poolManager.initialize(k, uint160(1 << 96));
        vm.prank(address(0xA11CE), address(0xA11CE));
        address v = uniswapV4StandardExchangeDFPkg.deployVault(k);
        assertTrue(v.code.length > 0);
    }
}
