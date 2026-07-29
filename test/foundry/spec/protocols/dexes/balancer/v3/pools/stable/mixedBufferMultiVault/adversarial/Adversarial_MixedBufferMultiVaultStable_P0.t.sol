// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {HooksConfig} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";

/**
 * @notice Adversarial P0: CUSTOM drain, donation, residual buffer, buffer-only remove, reentrancy.
 */
contract Adversarial_MixedBufferMultiVaultStable_P0 is TestBase_MixedBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function test_A1_externalCustomLiquidity_denied() public {
        uint256 n = mbmvs().tokenCount();
        uint256[] memory amounts = new uint256[](n);
        amounts[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mbmvsPool).onAddLiquidityCustom(attacker, amounts, 0, amounts, "");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mbmvsPool).onRemoveLiquidityCustom(attacker, 0, amounts, amounts, "");
    }

    function test_A2_donation_buffer_noFreeBpt() public {
        uint256 bptBefore = IERC20(mbmvsPool).totalSupply();
        uint256 vBefore = mbmvs().virtualBuffer();
        dai.mint(address(this), 100e18);
        dai.transfer(mbmvsPool, 100e18);
        assertEq(IERC20(mbmvsPool).totalSupply(), bptBefore, "no free BPT from bare transfer");
        assertEq(mbmvs().virtualBuffer(), vBefore, "virtual not inflated by bare transfer");
    }

    function test_A3_residual_buffer_after_success_swap() public {
        uint256 amountIn = 25e18;
        dai.mint(alice, amountIn);
        uint256 rawBefore = rawPoolBufferBalance();
        swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 1e18, "residual physical buffer after success");
    }

    function test_A5_virtualBuffer_staysNonZero_afterInit() public view {
        assertGt(mbmvs().virtualBuffer(), 0);
    }

    function test_R1_bufferOnlySingleTokenRemove_reverts() public {
        uint256 bptBal = IERC20(mbmvsPool).balanceOf(alice);
        require(bptBal > 0, "alice needs BPT");
        vm.startPrank(alice);
        IERC20(mbmvsPool).approve(address(router), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IMixedBufferMultiVaultStablePool.BufferOnlyRemoveDisallowed.selector));
        router.removeLiquiditySingleTokenExactIn(mbmvsPool, bptBal / 100, IERC20(address(dai)), 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_F3_hooksInProxy() public view {
        IHooks(mbmvsPool).getHookFlags();
        HooksConfig memory hc = bv3Vault.getHooksConfig(mbmvsPool);
        assertEq(hc.hooksContract, mbmvsPool, "hooksContract == pool");
    }

    /// @notice Hostile ERC20 buffer reenters CUSTOM remove mid transferFrom on live swap path.
    function test_C1_hostileBuffer_reentrancy_onLiveSwap() public {
        HostileBufferToken hostile = new HostileBufferToken();
        address poolAddr = aeroPoolFactory.createPool(address(hostile), address(usdt), false);
        uint256 amt = AERODROME_INIT_AMOUNT;
        hostile.mint(lp, amt);
        usdt.mint(lp, amt);
        vm.startPrank(lp);
        hostile.approve(address(aeroRouter), amt);
        usdt.approve(address(aeroRouter), amt);
        aeroRouter.addLiquidity(address(hostile), address(usdt), false, amt, amt, 1, 1, lp, block.timestamp + 1 hours);
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

        // Unpaired free leg must not be hostile buffer / share (use weth).
        IERC20[] memory unpaired = new IERC20[](1);
        unpaired[0] = IERC20(address(weth));
        IRateProvider[] memory unpairedRps = new IRateProvider[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        vaults[0] = IStandardExchange(seAddr);
        IRateProvider[] memory rps = new IRateProvider[](1);

        address hPool = mbmvsPkg.deployPool(
            IMixedBufferMultiVaultStablePoolPkg.PkgArgs({
                unpairedCount: 1,
                unpairedTokens: unpaired,
                unpairedRateProviders: unpairedRps,
                bufferToken: IERC20(address(hostile)),
                vaultCount: 1,
                standardExchangeVaults: vaults,
                vaultShareRateProviders: rps,
                amplificationParameter: MBMVS_AMP
            })
        );
        approveForPool(IERC20(hPool));

        // Fund SE shares + buffer + unpaired and initialize (mint WETH outside startPrank).
        hostile.mint(alice, MBMVS_INIT_SHARES * 4);
        usdt.mint(alice, MBMVS_INIT_SHARES * 4);
        hostile.mint(alice, MBMVS_INIT_BUFFER * 2);
        _mintToken(address(weth), alice, MBMVS_INIT_UNPAIRED * 2);

        vm.startPrank(alice);
        hostile.approve(address(aeroRouter), type(uint256).max);
        usdt.approve(address(aeroRouter), type(uint256).max);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(hostile),
            address(usdt),
            false,
            MBMVS_INIT_SHARES * 2,
            MBMVS_INIT_SHARES * 2,
            1,
            1,
            alice,
            block.timestamp + 1 hours
        );
        IERC20(poolAddr).approve(seAddr, lpOut);
        IStandardExchangeProxy(seAddr).deposit(lpOut, alice);
        hostile.approve(address(router), type(uint256).max);
        IERC20(seAddr).approve(address(router), type(uint256).max);
        IERC20(address(weth)).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(hPool);
        uint256[] memory amounts = new uint256[](toks.length);
        for (uint256 i; i < toks.length; ++i) {
            if (address(toks[i]) == address(hostile)) amounts[i] = MBMVS_INIT_BUFFER;
            else if (address(toks[i]) == seAddr) amounts[i] = MBMVS_INIT_SHARES;
            else amounts[i] = MBMVS_INIT_UNPAIRED;
        }
        router.initialize(hPool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();

        hostile.arm(hPool, address(this));
        hostile.mint(alice, 10e18);
        vm.startPrank(alice);
        hostile.approve(address(router), type(uint256).max);
        try router.swapSingleTokenExactIn(
            hPool, IERC20(address(hostile)), IERC20(seAddr), 5e18, 0, type(uint256).max, false, bytes("")
        ) {}
            catch {}
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
            uint256[] memory minOut = new uint256[](3);
            minOut[0] = 1;
            minOut[1] = 1;
            minOut[2] = 1;
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
