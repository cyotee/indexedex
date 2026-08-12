// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title Adversarial_MixedLeg_P0
 * @notice P0: D1/D2 CUSTOM, F3 hooks-in-proxy, A3 donation, E1/E2 atomicity,
 *         E3/E4 isolation (U=0 P=2), E7 residual, C1 hostile buffer reentrancy.
 */
contract Adversarial_MixedLeg_P0 is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 0;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 2;
    }

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function test_D1_customRemove_revertsNotHookCaller() public {
        uint256[] memory minOut = new uint256[](4);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMixedLegWeightedBufferPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mixedLegPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_revertsNotHookCaller() public {
        uint256[] memory maxIn = new uint256[](4);
        maxIn[0] = 1e18;
        vm.expectRevert(abi.encodeWithSelector(IMixedLegWeightedBufferPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(mixedLegPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }

    function test_F3_hooksInProxy() public view {
        IHooks(mixedLegPool).getHookFlags();
        assertEq(ml().pairCount(), 2);
        assertEq(ml().unpairedCount(), 0);
    }

    function test_A3_donation_noFreeBpt() public {
        uint256 bptBefore = IERC20(mixedLegPool).totalSupply();
        uint256 vtBefore = ml().virtualBuffer(0);
        dai.mint(alice, 50e18);
        uint256[] memory amounts = new uint256[](4);
        amounts[ml().bufferIndex(0)] = 50e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(mixedLegPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(mixedLegPool).totalSupply(), bptBefore);
        assertEq(ml().virtualBuffer(0), vtBefore);
    }

    function test_E7_eventualZero_physicalBufferAfterBufferIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 rawBefore = rawPoolBufferBalance(0);
        swapExactIn(alice, buffer0, IERC20(address(seVault)), amountIn);
        assertApproxEqAbs(rawPoolBufferBalance(0), rawBefore, 10, "physical buffer residual net");
    }

    function test_E1_preSeatFail_virtualsUnchanged() public {
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        int256 h0 = ml().hookShareDelta(0);
        int256 h1 = ml().hookShareDelta(1);

        mintSharesForPair(0, alice, 10_000e18);
        uint256 huge = IERC20(address(seVault)).balanceOf(alice);
        vm.startPrank(alice);
        vm.expectRevert();
        router.swapSingleTokenExactIn(
            mixedLegPool, IERC20(address(seVault)), buffer0, huge, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();

        assertEq(ml().virtualBuffer(0), v0);
        assertEq(ml().virtualBuffer(1), v1);
        assertEq(ml().hookShareDelta(0), h0);
        assertEq(ml().hookShareDelta(1), h1);
    }

    function test_E2_postSwapDepositFailed_atomic() public {
        HostileStandardExchange hostile = new HostileStandardExchange(IERC20(address(dai)));
        address hPool = _deployHostileSePool(hostile);
        _initHostileSePool(hPool, hostile);
        _assertFailedDepositAtomic(hPool, hostile);
    }

    function _deployHostileSePool(HostileStandardExchange hostile) internal returns (address hPool) {
        hostile.mintShares(alice, ML_INIT_SHARES * 3);
        dai.mint(address(hostile), ML_INIT_BUFFER * 4);
        dai.mint(alice, ML_INIT_BUFFER * 3);
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(address(hostile)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(hostile), address(router), type(uint160).max, type(uint48).max);
            dai.approve(address(permit2), type(uint256).max);
            permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        IERC20[] memory unpaired = new IERC20[](0);
        IRateProvider[] memory unpairedRps = new IRateProvider[](0);
        IERC20[] memory buffers = new IERC20[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        IRateProvider[] memory pairRps = new IRateProvider[](1);
        buffers[0] = IERC20(address(dai));
        vaults[0] = IStandardExchange(address(hostile));
        pairRps[0] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        hPool = mixedLegPkg.deployPool(
            IMixedLegWeightedBufferPoolPkg.PkgArgs({
                unpairedCount: 0,
                unpairedTokens: unpaired,
                unpairedRateProviders: unpairedRps,
                pairCount: 1,
                bufferTokens: buffers,
                standardExchangeVaults: vaults,
                pairRateProviders: pairRps,
                weights: weights
            })
        );
        approveForPool(IERC20(hPool));
    }

    function _initHostileSePool(address hPool, HostileStandardExchange hostile) internal {
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(hostile)).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(hPool);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = address(toks[i]) == address(dai) ? ML_INIT_BUFFER : ML_INIT_SHARES;
        }
        router.initialize(hPool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function _assertFailedDepositAtomic(address hPool, HostileStandardExchange hostile) internal {
        IMixedLegWeightedBufferPool hp = IMixedLegWeightedBufferPool(hPool);
        uint256 v0 = hp.virtualBuffer(0);
        int256 d0 = hp.hookShareDelta(0);
        uint256 bptBefore = IERC20(hPool).totalSupply();
        uint256 shBefore = IERC20(address(hostile)).balanceOf(alice);

        hostile.setFailExchangeIn(true);
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 daiBefore = dai.balanceOf(alice);

        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        vm.expectRevert();
        router.swapSingleTokenExactIn(
            hPool, IERC20(address(dai)), IERC20(address(hostile)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();

        assertEq(hp.virtualBuffer(0), v0, "virtual unchanged");
        assertEq(hp.hookShareDelta(0), d0, "hook delta unchanged");
        assertEq(IERC20(hPool).totalSupply(), bptBefore, "BPT unchanged");
        assertEq(dai.balanceOf(alice), daiBefore, "no DAI spent");
        assertEq(IERC20(address(hostile)).balanceOf(alice), shBefore, "no free shares out");
    }

    function test_E3_crossPair_isolation_withinPair0() public {
        uint256 v1 = ml().virtualBuffer(1);
        int256 h1 = ml().hookShareDelta(1);
        dai.mint(alice, 4e18);
        swapExactIn(alice, buffer0, IERC20(address(seVault)), 4e18);
        assertEq(ml().virtualBuffer(1), v1);
        assertEq(ml().hookShareDelta(1), h1);
    }

    function test_E4_crossPair_noFreeBpt() public {
        uint256 bptBefore = IERC20(mixedLegPool).totalSupply();
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 raw0 = rawPoolBufferBalance(0);
        dai.mint(alice, 5e18);
        swapExactIn(alice, buffer0, IERC20(address(seVault1)), 5e18);
        assertEq(IERC20(mixedLegPool).totalSupply(), bptBefore);
        assertGt(ml().virtualBuffer(0), v0);
        assertEq(ml().virtualBuffer(1), v1);
        assertApproxEqAbs(rawPoolBufferBalance(0), raw0, 10);
    }

    function test_C1_hostileBuffer_reentrancy_onLiveSwap() public {
        HostileBufferToken hostile = new HostileBufferToken();
        (address hPool, address seAddr) = _deployAndInitHostileBufferPool(hostile);

        hostile.arm(hPool);
        hostile.mint(alice, 10e18);
        _trySwapHostileBuffer(hPool, seAddr, hostile);

        assertGe(hostile.reentryAttempts(), 1, "reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "nested CUSTOM must fail");
    }

    function _deployAndInitHostileBufferPool(HostileBufferToken hostile)
        internal
        returns (address hPool, address seAddr)
    {
        address poolAddr = aeroPoolFactory.createPool(address(hostile), address(usdc), false);
        _seedHostileAeroLp(hostile, poolAddr);
        seAddr = aeroStdExDFPkg.deployVault(IPool(poolAddr));
        _approveHostileSe(hostile, poolAddr, seAddr);
        hPool = _deployHostileBufferMixedPool(hostile, seAddr);
        approveForPool(IERC20(hPool));
        _initHostileBufferPool(hostile, hPool, seAddr, poolAddr);
    }

    function _seedHostileAeroLp(HostileBufferToken hostile, address poolAddr) internal {
        uint256 amt = AERODROME_INIT_AMOUNT;
        hostile.mint(lp, amt);
        usdc.mint(lp, amt);
        vm.startPrank(lp);
        hostile.approve(address(aeroRouter), amt);
        usdc.approve(address(aeroRouter), amt);
        aeroRouter.addLiquidity(
            address(hostile), address(usdc), false, amt, amt, 1, 1, lp, block.timestamp + 1 hours
        );
        vm.stopPrank();
        poolAddr;
    }

    function _approveHostileSe(HostileBufferToken hostile, address poolAddr, address seAddr) internal {
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(poolAddr).approve(seAddr, type(uint256).max);
            IERC20(seAddr).approve(address(permit2), type(uint256).max);
            permit2.approve(seAddr, address(router), type(uint160).max, type(uint48).max);
            hostile.approve(address(permit2), type(uint256).max);
            permit2.approve(address(hostile), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
    }

    function _deployHostileBufferMixedPool(HostileBufferToken hostile, address seAddr)
        internal
        returns (address hPool)
    {
        IERC20[] memory unpaired = new IERC20[](0);
        IRateProvider[] memory unpairedRps = new IRateProvider[](0);
        IERC20[] memory buffers = new IERC20[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        IRateProvider[] memory pairRps = new IRateProvider[](1);
        buffers[0] = IERC20(address(hostile));
        vaults[0] = IStandardExchange(seAddr);
        pairRps[0] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        hPool = mixedLegPkg.deployPool(
            IMixedLegWeightedBufferPoolPkg.PkgArgs({
                unpairedCount: 0,
                unpairedTokens: unpaired,
                unpairedRateProviders: unpairedRps,
                pairCount: 1,
                bufferTokens: buffers,
                standardExchangeVaults: vaults,
                pairRateProviders: pairRps,
                weights: weights
            })
        );
    }

    function _initHostileBufferPool(
        HostileBufferToken hostile,
        address hPool,
        address seAddr,
        address poolAddr
    ) internal {
        hostile.mint(alice, ML_INIT_SHARES * 4);
        usdc.mint(alice, ML_INIT_SHARES * 4);
        vm.startPrank(alice);
        hostile.approve(address(aeroRouter), type(uint256).max);
        usdc.approve(address(aeroRouter), type(uint256).max);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(hostile),
            address(usdc),
            false,
            ML_INIT_SHARES * 2,
            ML_INIT_SHARES * 2,
            1,
            1,
            alice,
            block.timestamp + 1 hours
        );
        IERC20(poolAddr).approve(seAddr, lpOut);
        IStandardExchangeProxy(seAddr).deposit(lpOut, alice);
        hostile.mint(alice, ML_INIT_BUFFER * 2);
        hostile.approve(address(router), type(uint256).max);
        IERC20(seAddr).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(hPool);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = address(toks[i]) == address(hostile) ? ML_INIT_BUFFER : ML_INIT_SHARES;
        }
        router.initialize(hPool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function _trySwapHostileBuffer(address hPool, address seAddr, HostileBufferToken hostile) internal {
        vm.startPrank(alice);
        hostile.approve(address(router), type(uint256).max);
        IERC20 tokenIn = IERC20(address(hostile));
        IERC20 tokenOut = IERC20(seAddr);
        try router.swapSingleTokenExactIn(hPool, tokenIn, tokenOut, 5e18, 0, type(uint256).max, false, bytes(""))
        {} catch {}
        vm.stopPrank();
    }
}

/**
 * @dev Adversarial harness: SE that can fail exchangeIn. Not the SUT.
 */
contract HostileStandardExchange {
    string public name = "HostileSE";
    string public symbol = "hSE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable bufferToken;
    bool public failExchangeIn;

    constructor(IERC20 bufferToken_) {
        bufferToken = bufferToken_;
    }

    function setFailExchangeIn(bool v) external {
        failExchangeIn = v;
    }

    function mintShares(address to, uint256 amount) external {
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

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function previewExchangeIn(IERC20, uint256 amountIn, IERC20) external pure returns (uint256) {
        return amountIn;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256, address recipient, bool, uint256)
        external
        returns (uint256 amountOut)
    {
        if (failExchangeIn) revert("HostileSE: exchangeIn");
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        amountOut = amountIn;
        balanceOf[recipient] += amountOut;
        totalSupply += amountOut;
        tokenOut;
    }

    function previewExchangeOut(IERC20, IERC20, uint256 amountOut) external pure returns (uint256) {
        return amountOut;
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool,
        uint256
    ) external returns (uint256 amountIn) {
        amountIn = amountOut;
        require(amountIn <= maxAmountIn, "maxIn");
        balanceOf[msg.sender] -= amountIn;
        totalSupply -= amountIn;
        tokenOut.transfer(recipient, amountOut);
        tokenIn;
    }
}

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

    function arm(address pool) external {
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
