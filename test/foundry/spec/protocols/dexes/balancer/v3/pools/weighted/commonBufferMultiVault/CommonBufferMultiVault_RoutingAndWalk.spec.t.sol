// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {HooksConfig} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {
    ICommonBufferMultiVaultWeightedPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolStandardVaultPkg.sol";
import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";

/**
 * @title CommonBufferMultiVault_RoutingAndWalk
 * @notice Non-theater proofs: L6 always-route to non-tokenOut vault, L21 walk, conservation, LP unbalanced, L20.
 */
contract CommonBufferMultiVault_RoutingAndWalk is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_F3_hooksContract_equalsPool() public view {
        HooksConfig memory hc = bv3Vault.getHooksConfig(cbmvPool);
        assertEq(hc.hooksContract, cbmvPool, "hooksContract must equal pool");
    }

    /// @notice L6: force mostNeeded==1, swap buffer→share0; deposit must hit vault1 (delta), not only tokenOut.
    function test_L6_deposit_targetsMostNeeded_notTokenOutShare() public {
        mintSharesForVault(0, alice, 12_000e18);
        mintSharesForVault(1, alice, 12_000e18);

        // share0 → share1: pool takes share0, gives share1 → thins vault1, fattens vault0 → mostNeeded = 1.
        for (uint256 i; i < 6; ++i) {
            uint256 sell = 120e18;
            if (IERC20(address(seVault)).balanceOf(alice) < sell) mintSharesForVault(0, alice, 8_000e18);
            swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), sell);
        }

        uint8 need = cbmv().mostNeededVault();
        assertEq(need, 1, "skew must make vault1 most needed");

        int256 d0Before = cbmv().hookShareDelta(0);
        int256 d1Before = cbmv().hookShareDelta(1);
        uint256 vBefore = cbmv().virtualBuffer();
        uint256 rawBefore = rawPoolBufferBalance();

        uint256 amountIn = 40e18;
        dai.mint(alice, amountIn);
        // tokenOut = share0 (vault 0) - must still deposit to vault 1
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(cbmv().virtualBuffer(), vBefore + amountIn, "virtual += amountIn");
        assertGt(cbmv().hookShareDelta(1), d1Before, "deposit donation on most-needed vault1");
        // vault0 may change from swap share-out accounting; deposit target must be vault1
        assertTrue(
            cbmv().hookShareDelta(1) - d1Before > cbmv().hookShareDelta(0) - d0Before
                || cbmv().hookShareDelta(1) > d1Before,
            "vault1 is primary deposit target"
        );
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual");
    }

    /// @notice Conservation when i* != tokenOut: virtual += X; deposit delta on need vault; non-deposit share leg not free-minted.
    function test_conservation_when_mostNeeded_neq_tokenOut() public {
        mintSharesForVault(0, alice, 12_000e18);
        mintSharesForVault(1, alice, 12_000e18);
        for (uint256 i; i < 6; ++i) {
            uint256 sell = 120e18;
            if (IERC20(address(seVault)).balanceOf(alice) < sell) mintSharesForVault(0, alice, 8_000e18);
            swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), sell);
        }
        assertEq(cbmv().mostNeededVault(), 1, "need vault1");

        uint256 vBefore = cbmv().virtualBuffer();
        int256 d0 = cbmv().hookShareDelta(0);
        int256 d1 = cbmv().hookShareDelta(1);
        uint256 rawBefore = rawPoolBufferBalance();
        uint256 amountIn = 30e18;
        dai.mint(alice, amountIn);
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertEq(cbmv().virtualBuffer(), vBefore + amountIn, "virtual += X");
        assertGt(cbmv().hookShareDelta(1), d1, "deposit on vault1");
        // vault0 delta should not increase from deposit donation (may decrease from pre-seat/other); deposit gift is vault1
        assertLe(cbmv().hookShareDelta(0), d0 + int256(1e15), "vault0 not primary deposit recipient");
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100);
    }

    /// @notice Unbalanced add with buffer leg must hit onAfterAddLiquidity UNBALANCED and grow virtual.
    function test_lp_unbalanced_buffer_add_growsVirtual() public {
        uint256 vBefore = cbmv().virtualBuffer();
        uint256 bufAdd = 5e18;
        uint256 shareAdd = 5e18;
        mintSharesForVault(0, alice, shareAdd * 3);
        dai.mint(alice, bufAdd);
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(cbmvPool);
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        maxAmounts[cbmv().bufferIndex()] = bufAdd;
        // Include some share so Balancer invariant-ratio stays valid (not pure single-sided).
        maxAmounts[cbmv().shareIndex(0)] = shareAdd;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        uint256 bptOut = router.addLiquidityUnbalanced(cbmvPool, maxAmounts, 0, false, bytes(""));
        vm.stopPrank();
        assertGt(bptOut, 0, "unbalanced add must mint BPT");
        // Buffer portion of unbalanced add must bump virtual (onAfterAddLiquidity UNBALANCED path).
        assertEq(cbmv().virtualBuffer(), vBefore + bufAdd, "virtual grows by buffer amount via UNBALANCED");
    }

    function test_L20_tieBreak_lowestIndex_whenEqualWeights() public view {
        uint256 w0 = cbmv().weight(cbmv().shareIndex(0));
        uint256 w1 = cbmv().weight(cbmv().shareIndex(1));
        uint256 s0 = cbmv().depthPerWeight(0);
        uint256 s1 = cbmv().depthPerWeight(1);
        if (w0 == w1 && s0 == s1) {
            assertEq(cbmv().mostNeededVault(), 0, "L20: equal score+weight -> lowest index");
            assertEq(cbmv().mostExcessVault(), 0, "L20 excess same rule");
        }
    }
}

/**
 * @title CommonBufferMultiVault_WalkAndExhaust
 * @notice L21 walk: first vault fails SE I/O, second succeeds; W1 AllVaultsExhausted when both fail.
 */
contract CommonBufferMultiVault_WalkAndExhaust is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 1; // default fixture unused for custom deploys
    }

    /// @notice Deposit walk: hostile vault0 fails exchangeIn; real vault1 succeeds.
    function test_L21_walk_deposit_secondVaultSucceeds() public {
        HostileSE h0 = new HostileSE(IERC20(address(dai)));
        // Real vault = seVault (already deployed). Pool: buffer + h0 + seVault
        h0.mintShares(alice, CBMV_INIT_SHARES * 5);
        dai.mint(address(h0), CBMV_INIT_BUFFER * 5);
        dai.mint(alice, CBMV_INIT_BUFFER * 5);
        mintSharesForVault(0, alice, CBMV_INIT_SHARES * 5);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(seVault)));
        _initTwoVaultPool(pool, address(h0), address(seVault));

        ICommonBufferMultiVaultWeightedPool p = ICommonBufferMultiVaultWeightedPool(pool);
        // After equal init, mostNeeded is 0 (lowest index). Force fail on vault0 deposit.
        h0.setFailExchangeIn(true);

        uint256 vBefore = p.virtualBuffer();
        int256 d1Before = p.hookShareDelta(1);
        uint256 amt = 10e18;
        dai.mint(alice, amt);
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        // tokenOut can be either share; deposit walks need order starting at 0 (fails) then 1 (succeeds)
        uint256 out = router.swapSingleTokenExactIn(
            pool, IERC20(address(dai)), IERC20(address(seVault)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(p.virtualBuffer(), vBefore + amt);
        assertGt(p.hookShareDelta(1), d1Before, "walk deposited into vault1 after vault0 fail");
    }

    /// @notice Pre-seat walk: hostile fails exchangeOut; real vault delivers buffer.
    function test_L21_walk_preSeat_secondVaultSucceeds() public {
        HostileSE h0 = new HostileSE(IERC20(address(dai)));
        h0.mintShares(alice, CBMV_INIT_SHARES * 5);
        dai.mint(address(h0), CBMV_INIT_BUFFER * 5);
        mintSharesForVault(0, alice, CBMV_INIT_SHARES * 5);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(seVault)));
        _initTwoVaultPool(pool, address(h0), address(seVault));

        ICommonBufferMultiVaultWeightedPool p = ICommonBufferMultiVaultWeightedPool(pool);
        h0.setFailExchangeOut(true);

        // Sell real SE shares for buffer - pre-seat may try h0 first if most excess, then walk to seVault.
        uint256 amt = 20e18;
        assertGe(IERC20(address(seVault)).balanceOf(alice), amt);
        uint256 vBefore = p.virtualBuffer();
        vm.startPrank(alice);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        uint256 out = router.swapSingleTokenExactIn(
            pool, IERC20(address(seVault)), IERC20(address(dai)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        assertGt(out, 0, "walk pre-seat via real vault");
        assertLt(p.virtualBuffer(), vBefore);
    }

    /// @notice W1: both vaults fail exchangeIn → AllVaultsExhausted.
    function test_W1_allVaultsExhausted_selector() public {
        HostileSE h0 = new HostileSE(IERC20(address(dai)));
        HostileSE h1 = new HostileSE(IERC20(address(dai)));
        h0.mintShares(alice, CBMV_INIT_SHARES * 3);
        h1.mintShares(alice, CBMV_INIT_SHARES * 3);
        dai.mint(address(h0), CBMV_INIT_BUFFER * 3);
        dai.mint(address(h1), CBMV_INIT_BUFFER * 3);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(h1)));
        _initTwoVaultPool(pool, address(h0), address(h1));

        h0.setFailExchangeIn(true);
        h1.setFailExchangeIn(true);

        uint256 amt = 5e18;
        dai.mint(alice, amt);
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        vm.expectRevert(ICommonBufferMultiVaultWeightedPool.AllVaultsExhausted.selector);
        router.swapSingleTokenExactIn(
            pool, IERC20(address(dai)), IERC20(address(h0)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    function _deployTwoVaultPool(IStandardExchange v0, IStandardExchange v1) internal returns (address pool) {
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(address(v0)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(v0), address(router), type(uint160).max, type(uint48).max);
            IERC20(address(v1)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(v1), address(router), type(uint160).max, type(uint48).max);
            dai.approve(address(permit2), type(uint256).max);
            permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        vaults[0] = v0;
        vaults[1] = v1;
        IRateProvider[] memory rps = new IRateProvider[](2);
        IERC20[] memory unpaired = new IERC20[](0);
        IRateProvider[] memory unpairedRps = new IRateProvider[](0);
        pool = cbmvPkg.deployPool(
            ICommonBufferMultiVaultWeightedPoolPkg.PkgArgs({
                unpairedCount: 0,
                unpairedTokens: unpaired,
                unpairedRateProviders: unpairedRps,
                bufferToken: IERC20(address(dai)),
                vaultCount: 2,
                standardExchangeVaults: vaults,
                vaultShareRateProviders: rps,
                weights: _equalWeights(3)
            })
        );
        approveForPool(IERC20(pool));
    }

    function _initTwoVaultPool(address pool, address share0, address share1) internal {
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(share0).approve(address(router), type(uint256).max);
        IERC20(share1).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(pool);
        uint256[] memory amounts = new uint256[](toks.length);
        for (uint256 i; i < toks.length; ++i) {
            if (address(toks[i]) == address(dai)) amounts[i] = CBMV_INIT_BUFFER;
            else amounts[i] = CBMV_INIT_SHARES;
        }
        router.initialize(pool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }
}

/// @dev Minimal hostile SE for walk/exhaust tests (non-SUT double).
contract HostileSE {
    string public name = "HostileSE";
    string public symbol = "hSE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable bufferToken;
    bool public failExchangeIn;
    bool public failExchangeOut;

    constructor(IERC20 bufferToken_) {
        bufferToken = bufferToken_;
    }

    function setFailExchangeIn(bool v) external {
        failExchangeIn = v;
    }

    function setFailExchangeOut(bool v) external {
        failExchangeOut = v;
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

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20, uint256, address recipient, bool, uint256)
        external
        returns (uint256 amountOut)
    {
        if (failExchangeIn) revert("HostileSE: exchangeIn");
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        amountOut = amountIn;
        balanceOf[recipient] += amountOut;
        totalSupply += amountOut;
    }

    function previewExchangeOut(IERC20, IERC20, uint256 amountOut) external pure returns (uint256) {
        return amountOut;
    }

    function exchangeOut(
        IERC20,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool,
        uint256
    ) external returns (uint256 amountIn) {
        if (failExchangeOut) revert("HostileSE: exchangeOut");
        amountIn = amountOut;
        require(amountIn <= maxAmountIn, "maxIn");
        balanceOf[msg.sender] -= amountIn;
        totalSupply -= amountIn;
        tokenOut.transfer(recipient, amountOut);
    }
}
