// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HooksConfig} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {
    ICommonBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    TestBase_CommonBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool.sol";

/**
 * @title Adversarial_CommonBufferMultiVaultStable_P0
 * @notice P0: CUSTOM drain, donation, residual buffer, buffer-only remove, hooks wiring, reentrancy.
 */
contract Adversarial_CommonBufferMultiVaultStable_P0 is TestBase_CommonBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function test_D1_customRemove_revertsNotHookCaller() public {
        uint256[] memory minOut = new uint256[](3);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvsPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_revertsNotHookCaller() public {
        uint256[] memory maxIn = new uint256[](3);
        maxIn[0] = 1e18;
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvsPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }

    function test_F3_hooksInProxy() public view {
        IHooks(cbmvsPool).getHookFlags();
        HooksConfig memory hc = bv3Vault.getHooksConfig(cbmvsPool);
        assertEq(hc.hooksContract, cbmvsPool, "hooksContract == pool");
        assertEq(cbmvs().vaultCount(), 2);
    }

    function test_A3_donation_noFreeBpt() public {
        uint256 bptBefore = IERC20(cbmvsPool).totalSupply();
        uint256 vtBefore = cbmvs().virtualBuffer();
        dai.mint(alice, 40e18);
        uint256[] memory amounts = new uint256[](3);
        amounts[cbmvs().bufferIndex()] = 40e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(cbmvsPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(cbmvsPool).totalSupply(), bptBefore);
        assertEq(cbmvs().virtualBuffer(), vtBefore);
    }

    function test_E7_eventualZero_afterBufferIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 rawBefore = rawPoolBufferBalance();
        swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual (E7)");
    }

    function test_R1_bufferOnlySingleTokenRemove_reverts() public {
        uint256 bptBal = IERC20(cbmvsPool).balanceOf(alice);
        require(bptBal > 0, "alice needs BPT");
        vm.startPrank(alice);
        IERC20(cbmvsPool).approve(address(router), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultStablePool.BufferOnlyRemoveDisallowed.selector));
        router.removeLiquiditySingleTokenExactIn(cbmvsPool, bptBal / 100, IERC20(address(dai)), 0, false, bytes(""));
        vm.stopPrank();
    }

    /// @notice Oversized share->buffer either reverts (virtual/pre-seat) or conserves residual if partial fills.
    function test_W1_oversized_shareOut_safe() public {
        mintSharesForVault(0, alice, 50_000e18);
        mintSharesForVault(1, alice, 50_000e18);
        uint256 huge = IERC20(address(seVault)).balanceOf(alice);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 vtBefore = cbmvs().virtualBuffer();
        vm.startPrank(alice);
        try router.swapSingleTokenExactIn(
            cbmvsPool, IERC20(address(seVault)), IERC20(address(dai)), huge, 0, type(uint256).max, false, bytes("")
        ) returns (
            uint256 out
        ) {
            // If path succeeds, virtual must not go negative (underflow reverts on-chain) and residual bounded.
            assertGt(out, 0);
            assertLe(cbmvs().virtualBuffer(), vtBefore);
            assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 1e18, "residual after large pre-seat");
        } catch {
            // Expected path when pre-seat / virtual cannot cover quote.
        }
        vm.stopPrank();
        assertGe(cbmvs().virtualBuffer(), 0);
    }

    /// @notice C1 — hostile ERC20 bufferToken reenters CUSTOM remove mid transferFrom on live swap path.
    function test_C1_hostileBuffer_reentrancy_onLiveSwap() public {
        HostileBufferToken hostile = new HostileBufferToken();
        address poolAddr = aeroPoolFactory.createPool(address(hostile), address(usdc), false);
        uint256 amt = AERODROME_INIT_AMOUNT;
        hostile.mint(lp, amt);
        usdc.mint(lp, amt);
        vm.startPrank(lp);
        hostile.approve(address(aeroRouter), amt);
        usdc.approve(address(aeroRouter), amt);
        aeroRouter.addLiquidity(address(hostile), address(usdc), false, amt, amt, 1, 1, lp, block.timestamp + 1 hours);
        vm.stopPrank();

        address seAddr = aeroStdExDFPkg.deployVault(IPool(poolAddr));
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(poolAddr).approve(seAddr, type(uint256).max);
            IERC20(seAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(seAddr, address(router), type(uint160).max, type(uint48).max);
            hostile.approve(address(permit2), type(uint256).max);
            permit2.approve(address(hostile), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }

        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        vaults[0] = IStandardExchange(seAddr);
        IRateProvider[] memory rps = new IRateProvider[](1);

        address hPool = cbmvsPkg.deployPool(
            ICommonBufferMultiVaultStablePoolPkg.PkgArgs({
                bufferToken: IERC20(address(hostile)),
                vaultCount: 1,
                standardExchangeVaults: vaults,
                vaultShareRateProviders: rps,
                amplificationParameter: CBMVS_AMP
            })
        );
        approveForPool(IERC20(hPool));

        // Fund SE shares + buffer and initialize production pool.
        hostile.mint(alice, CBMVS_INIT_SHARES * 4);
        usdc.mint(alice, CBMVS_INIT_SHARES * 4);
        vm.startPrank(alice);
        hostile.approve(address(aeroRouter), type(uint256).max);
        usdc.approve(address(aeroRouter), type(uint256).max);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(hostile),
            address(usdc),
            false,
            CBMVS_INIT_SHARES * 2,
            CBMVS_INIT_SHARES * 2,
            1,
            1,
            alice,
            block.timestamp + 1 hours
        );
        IERC20(poolAddr).approve(seAddr, lpOut);
        IStandardExchangeProxy(seAddr).deposit(lpOut, alice);
        hostile.mint(alice, CBMVS_INIT_BUFFER * 2);
        hostile.approve(address(router), type(uint256).max);
        IERC20(seAddr).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(hPool);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = address(toks[i]) == address(hostile) ? CBMVS_INIT_BUFFER : CBMVS_INIT_SHARES;
        }
        router.initialize(hPool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();

        // Arm hostile: on transferFrom reenter CUSTOM remove against hPool
        hostile.arm(hPool, address(this));
        hostile.mint(alice, 10e18);
        vm.startPrank(alice);
        hostile.approve(address(router), type(uint256).max);
        try router.swapSingleTokenExactIn(
            hPool, IERC20(address(hostile)), IERC20(seAddr), 5e18, 0, type(uint256).max, false, bytes("")
        ) {
        // swap may complete after nested fail
        }
            catch {
            // full revert also OK
        }
        vm.stopPrank();

        assertGe(hostile.reentryAttempts(), 1, "reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "nested CUSTOM must fail (NotHookCaller / lock)");
    }
}

/// @dev Minimal mintable ERC20; transferFrom reenters CUSTOM remove mid live swap pull.
contract HostileBufferToken {
    string public name = "HostileBuf";
    string public symbol = "HBUF";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public reentryTarget;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bool public armed;
    uint256 private _depth;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function arm(address pool, address) external {
        reentryTarget = pool;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0 && reentryTarget != address(0)) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            uint256[] memory minOut = new uint256[](2);
            minOut[0] = 1;
            minOut[1] = 1;
            (bool ok,) = reentryTarget.call(
                abi.encodeWithSelector(
                    IPoolLiquidity.onRemoveLiquidityCustom.selector, address(this), 0, minOut, minOut, bytes("")
                )
            );
            nestedCallSucceeded = ok;
            _depth = 0;
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
