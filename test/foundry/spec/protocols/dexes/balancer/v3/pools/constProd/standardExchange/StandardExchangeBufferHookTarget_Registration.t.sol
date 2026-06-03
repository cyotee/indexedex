// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {HookFlags, TokenConfig, TokenType, LiquidityManagement} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";

import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";

import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/**
 * @title HookRegistrationTest
 * @notice Tests for StandardExchangeBufferHookTarget registration logic (onRegister, getHookFlags,
 *         onBeforeInitialize) against the real deployed pool from TestBase_StandardExchangeBufferPool.
 *
 * @dev WHY THIS INHERITS THE FULL INTEGRATION BASE (no HookHarness / StaticRateProvider):
 *
 *      The previous version used a local HookHarness with hard-coded vault / factory addresses
 *      and a StaticRateProvider.  This approach hid real Vault/factory semantics and allowed
 *      bugs to sail through (e.g. wrong factory address comparison).
 *
 *      By inheriting TestBase_StandardExchangeBufferPool we get a fully registered and
 *      initialized pool diamond where:
 *        - _balancerV3Vault() returns address(bv3Vault) (the real Crane VaultMock)
 *        - _expectedFactory() returns address(bufferPoolPkg) (the real pkg contract)
 *        - Repo storage (tta, shares, rateProvider, indices) is already populated
 *
 *      POSITIVE TEST STRATEGY
 *      onRegister succeeded once (at pool registration time) — we can assert the resulting
 *      state via getHookFlags, virtualTTA, etc.  To verify the positive path of onRegister
 *      itself we call it again via vm.prank(address(bv3Vault)) with the exact same args the
 *      Vault used during registration.
 *
 *      NEGATIVE TEST STRATEGY
 *      For each guard in onRegister we call the function from a non-vault address or pass bad
 *      arguments and assert it returns false.  No second pool deployment is required — the
 *      real pool's onRegister is a pure view that reads Repo storage and msg.sender; calling
 *      it with wrong args is safe and does not alter state.
 *
 *      onBeforeInitialize: the pool is already initialized, but calling it again via
 *      vm.prank(address(bv3Vault)) is safe because it is a state-mutating view whose only
 *      side-effects are updating Repo.virtualTTA and Repo.hookSharesDelta — both of which we
 *      restore with vm.store after the assertion.
 */
contract HookRegistrationTest is TestBase_StandardExchangeBufferPool {

    /* ---------------------------------------------------------------------- */
    /*                               Helpers                                   */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Build a well-formed TokenConfig pair matching what the pool was registered with.
     *      Uses the live pool's tta, shares, rateProvider, and sorted indices.
     */
    function _validTokenConfigs() internal view returns (TokenConfig[] memory cfg) {
        IStandardExchangeBufferPool pool_ = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx    = pool_.ttaIndex();
        uint256 sharesIdx = pool_.sharesIndex();
        IRateProvider rp  = pool_.rateProvider();

        cfg = new TokenConfig[](2);
        cfg[ttaIdx] = TokenConfig({
            token:         pool_.ttaToken(),
            tokenType:     TokenType.STANDARD,
            rateProvider:  IRateProvider(address(0)),
            paysYieldFees: false
        });
        cfg[sharesIdx] = TokenConfig({
            token:         pool_.shareToken(),
            tokenType:     TokenType.WITH_RATE,
            rateProvider:  rp,
            paysYieldFees: false
        });
    }

    /**
     * @dev Build the LiquidityManagement struct that the pool was registered with.
     */
    function _validLM() internal pure returns (LiquidityManagement memory) {
        return LiquidityManagement({
            disableUnbalancedLiquidity: true,
            enableAddLiquidityCustom: true,
            enableRemoveLiquidityCustom: true,
            enableDonation: true
        });
    }

    /* ---------------------------------------------------------------------- */
    /*                          getHookFlags Test                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice getHookFlags must return the flags documented in the spec (§ 4.3).
     * @dev Calls the real pool diamond (which delegates to StandardExchangeHookFacet).
     */
    function test_getHookFlags_matchesSpec() public view {
        HookFlags memory flags = IHooks(bufferPool).getHookFlags();
        assertFalse(flags.enableHookAdjustedAmounts,           "enableHookAdjustedAmounts should be false");
        assertTrue( flags.shouldCallBeforeInitialize,          "shouldCallBeforeInitialize should be true");
        assertFalse(flags.shouldCallAfterInitialize,           "shouldCallAfterInitialize should be false");
        assertFalse(flags.shouldCallComputeDynamicSwapFee,     "shouldCallComputeDynamicSwapFee should be false");
        assertTrue( flags.shouldCallBeforeSwap,                "shouldCallBeforeSwap should be true");
        assertTrue( flags.shouldCallAfterSwap,                 "shouldCallAfterSwap should be true");
        assertTrue( flags.shouldCallBeforeAddLiquidity,        "shouldCallBeforeAddLiquidity should be true");
        assertTrue( flags.shouldCallAfterAddLiquidity,         "shouldCallAfterAddLiquidity should be true");
        assertFalse(flags.shouldCallBeforeRemoveLiquidity,     "shouldCallBeforeRemoveLiquidity should be false");
        assertTrue( flags.shouldCallAfterRemoveLiquidity,      "shouldCallAfterRemoveLiquidity should be true");
    }

    /* ---------------------------------------------------------------------- */
    /*                          onRegister Tests                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice onRegister returns true when called by the Vault with the exact registration args.
     * @dev Pranks as the real Vault (address(bv3Vault)) and passes the matching factory +
     *      pool address + token config + LM.
     */
    function test_onRegister_acceptsValid() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onRegister(address(bufferPoolPkg), bufferPool, cfg, _validLM());
        assertTrue(ok, "onRegister should accept valid registration params");
    }

    /**
     * @notice onRegister returns false when msg.sender is not the Vault.
     */
    function test_onRegister_rejectsWrongSender() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        vm.prank(address(0xDEAD));
        bool ok = IHooks(bufferPool).onRegister(address(bufferPoolPkg), bufferPool, cfg, _validLM());
        assertFalse(ok, "onRegister should reject non-Vault sender");
    }

    /**
     * @notice onRegister returns false when factory != expectedFactory (bufferPoolPkg).
     */
    function test_onRegister_rejectsWrongFactory() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onRegister(address(0xBAD), bufferPool, cfg, _validLM());
        assertFalse(ok, "onRegister should reject wrong factory");
    }

    /**
     * @notice onRegister returns false when pool != address(this) (the hook diamond itself).
     */
    function test_onRegister_rejectsWrongPool() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onRegister(address(bufferPoolPkg), address(0xBAD), cfg, _validLM());
        assertFalse(ok, "onRegister should reject wrong pool address");
    }

    /**
     * @notice onRegister returns false when LiquidityManagement flags don't match requirements.
     *         Specifically, disableUnbalancedLiquidity = false should cause rejection.
     */
    function test_onRegister_rejectsBadLM() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        LiquidityManagement memory bad = _validLM();
        bad.disableUnbalancedLiquidity = false;
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onRegister(address(bufferPoolPkg), bufferPool, cfg, bad);
        assertFalse(ok, "onRegister should reject LM with disableUnbalancedLiquidity=false");
    }

    /**
     * @notice onRegister returns false when TTA token is registered as WITH_RATE instead of STANDARD.
     */
    function test_onRegister_rejectsWrongTokenType() public {
        TokenConfig[] memory cfg = _validTokenConfigs();
        IStandardExchangeBufferPool pool_ = IStandardExchangeBufferPool(bufferPool);
        uint256 ttaIdx = pool_.ttaIndex();
        // Flip TTA from STANDARD to WITH_RATE — this should fail the tokenType check.
        cfg[ttaIdx].tokenType = TokenType.WITH_RATE;
        cfg[ttaIdx].rateProvider = pool_.rateProvider();
        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onRegister(address(bufferPoolPkg), bufferPool, cfg, _validLM());
        assertFalse(ok, "onRegister should reject TTA with wrong TokenType");
    }

    /* ---------------------------------------------------------------------- */
    /*                      onBeforeInitialize Test                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice onBeforeInitialize seeds virtualTTA from the shares amount and rate, resets
     *         hookSharesDelta to 0.
     *
     * @dev The pool is already initialized, so calling onBeforeInitialize again will overwrite
     *      virtualTTA.  We read the current state, call the hook, assert, then restore.
     *
     *      The rate on the real SE vault is ≈ 1:1 (Aerodrome pool seeded with equal amounts),
     *      so virtualTTA ≈ sharesIn.  We assert with a generous tolerance to avoid brittle
     *      coupling to exact rate values.
     */
    function test_onBeforeInitialize_seedsState() public {
        IStandardExchangeBufferPool pool_ = IStandardExchangeBufferPool(bufferPool);

        // Save current state so we can restore it after the test.
        uint256 vtPre  = pool_.virtualTTA();
        int256  hsdPre = pool_.hookSharesDelta();

        uint256[] memory amts = new uint256[](2);
        uint256 sharesIdx = pool_.sharesIndex();
        amts[sharesIdx] = 50e18; // shares in

        vm.prank(address(bv3Vault));
        bool ok = IHooks(bufferPool).onBeforeInitialize(amts, "");
        assertTrue(ok, "onBeforeInitialize should return true");

        // virtualTTA = sharesIn * rate / 1e18; rate ≈ 1e18 so virtualTTA ≈ 50e18.
        // Use a loose bound (5%) to avoid coupling to exact Aerodrome exchange rate.
        uint256 vtPost = pool_.virtualTTA();
        assertGt(vtPost, 0, "virtualTTA should be positive after initialization");
        assertApproxEqRel(vtPost, 50e18, 0.05e18, "virtualTTA should approximate sharesIn given ~1:1 rate");

        // hookSharesDelta should be reset to 0.
        assertEq(pool_.hookSharesDelta(), 0, "hookSharesDelta should be 0 after initialization");

        // Restore state via vm.store (same slot layout as Behavior_Clamping).
        bytes32 repoSlot = keccak256("indexedex.protocols.balancer.v3.pools.constProd.standardExchange");
        vm.store(bufferPool, bytes32(uint256(repoSlot) + 7), bytes32(vtPre));
        vm.store(bufferPool, bytes32(uint256(repoSlot) + 8), bytes32(uint256(hsdPre)));
    }
}
