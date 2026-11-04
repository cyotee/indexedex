// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {INonfungiblePositionManager} from
    "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {V3FSHandler, Actor} from "./V3FSHandler.sol";

contract MockTokenDescriptorP4 {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

/// @notice Shared fixture: real V3 factory + pool (0.3%, P0 = 1), real DFPkg-deployed FullSpread vault (20% sleeve),
///         external full-range LP depth EXT_L (vault ~ 50% of in-range liquidity, the regime where known bugs bite).
abstract contract V3FSFixture is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    uint128 internal constant EXT_L = 800e18;

    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    NonfungiblePositionManager internal npm;
    V3FSHandler internal h;

    function setUp() public virtual override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, EXT_L);
        vault = _deployVault(pool);
        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptorP4()));

        h = new V3FSHandler(pool, vault, INonfungiblePositionManager(address(npm)));
        Actor atk = new Actor(pool, address(vault), address(h));
        h.setActors(
            atk,
            new Actor(pool, address(vault), address(h)),
            new Actor(pool, address(vault), address(h)),
            new Actor(pool, address(vault), address(h)),
            new Actor(pool, address(vault), address(h)),
            new Actor(pool, address(vault), address(h))
        );
        // attacker-owned real NPM NFT (for import attempts on the live vault)
        a.mint(address(this), 10 ether);
        b.mint(address(this), 10 ether);
        IERC20(pool.token0()).approve(address(npm), type(uint256).max);
        IERC20(pool.token1()).approve(address(npm), type(uint256).max);
        (uint256 id,,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: FEE_MEDIUM,
                tickLower: -600,
                tickUpper: 600,
                amount0Desired: 5 ether,
                amount1Desired: 5 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(atk),
                deadline: block.timestamp + 1
            })
        );
        h.init(id);
    }

    /// AUDIT FIX: reset the per-campaign non-vacuity log (setUp runs once per invariant test; afterInvariant appends
    /// once per run). Previously lines from earlier invocations on the same runner slot accumulated.
    function _resetLog(string memory path) internal {
        if (vm.exists(path)) vm.removeFile(path);
    }

    // ------------------------------------------------------------------ invariant checks (shared)
    function _checkAll() internal view {
        (bool ok, int256 profit, uint256 allowance) = h.checkNoFreeValue();
        if (!ok) {
            console2.log("INV-1 no-free-value BROKEN. last op", uint256(h.lastOpId()), "sub", uint256(h.lastSub()));
            console2.log("  attacker profit", profit);
            console2.log("  allowance (fees+tol)", allowance);
        }
        assertTrue(ok, "INV-1 no-free-value");
        if (h.previewMismatch() != 0) {
            console2.log("INV-2 preview!=execute op", uint256(h.pmOp()));
            console2.log("  preview / exec", h.pmPreview(), h.pmExec());
        }
        assertEq(h.previewMismatch(), 0, "INV-2 preview==execute");
        if (h.deliveryMismatch() != 0) {
            console2.log("INV-2b returned!=delivered op", uint256(h.dmOp()));
            console2.log("  want / got", h.dmWant(), h.dmGot());
        }
        assertEq(h.deliveryMismatch(), 0, "INV-2b returned==delivered");
        if (h.rsyncViolations() != 0) console2.log("INV-3 R-sync op", uint256(h.rsOp()));
        assertEq(h.rsyncViolations(), 0, "INV-3 R sync");
        if (h.rateDrops() != 0) {
            console2.log("INV-4a CP rate drop op", uint256(h.rdOp()));
            console2.log("  before / after", h.rdBefore(), h.rdAfter());
        }
        assertEq(h.rateDrops(), 0, "INV-4a CP rate monotone");
        if (h.passiveDrops() != 0) {
            console2.log("INV-4b passive LP value drop op", uint256(h.pdOp()));
            console2.log("  before / after", h.pdBefore(), h.pdAfter());
        }
        assertEq(h.passiveDrops(), 0, "INV-4b passive LP not diluted");
        assertFalse(h.importSucceeded(), "INV-5 import only at genesis");
        if (h.unexplainedPassiveLoss() > h.tolerance()) {
            console2.log("INV-4c per-step unexplained passive loss: op / max step loss", uint256(h.upOp()), h.upMax());
        }
        assertLe(h.unexplainedPassiveLoss(), h.tolerance(), "INV-4c no unexplained per-step passive loss");
        (uint160 sp,,,,,,) = pool.slot0();
        assertEq(uint256(sp), uint256(h.sp0()), "price restored");
    }
}

contract V3FSInvariantTest is V3FSFixture {
    function setUp() public override {
        super.setUp();
        targetContract(address(h));
        bytes4[] memory sels = new bytes4[](24);
        sels[0] = V3FSHandler.h_dualDeposit.selector;
        sels[1] = V3FSHandler.h_dualExit.selector;
        sels[2] = V3FSHandler.h_zapOutExactIn.selector;
        sels[3] = V3FSHandler.h_zapOutExactOut.selector;
        sels[4] = V3FSHandler.h_swapExactIn.selector;
        sels[5] = V3FSHandler.h_swapExactOut.selector;
        sels[6] = V3FSHandler.h_keeperRebalance.selector;
        sels[7] = V3FSHandler.warp.selector;
        sels[8] = V3FSHandler.a_singleDeposit.selector;
        sels[9] = V3FSHandler.a_dualDeposit.selector;
        sels[10] = V3FSHandler.a_mintExactOut.selector;
        sels[11] = V3FSHandler.a_zapOutExactIn.selector;
        sels[12] = V3FSHandler.a_zapOutExactOut.selector;
        sels[13] = V3FSHandler.a_dualExit.selector;
        sels[14] = V3FSHandler.a_swapExactIn.selector;
        sels[15] = V3FSHandler.a_swapExactOut.selector;
        sels[16] = V3FSHandler.a_donate.selector;
        sels[17] = V3FSHandler.a_claimCredit.selector;
        sels[18] = V3FSHandler.a_syDeposit.selector;
        sels[19] = V3FSHandler.a_syRedeem.selector;
        sels[20] = V3FSHandler.a_syRedeemInternal.selector;
        sels[21] = V3FSHandler.a_rebalance.selector;
        sels[22] = V3FSHandler.a_sandwich.selector;
        sels[23] = V3FSHandler.a_importAttempt.selector;
        // QUARANTINED: V3FSHandler.a_blockedCP (known v3fs-blocked-mode-callback-cp; also the in-callback
        // deposit used by fs-maintenance-at-spot-jit). Never targeted.
        targetSelector(StdInvariant.FuzzSelector({addr: address(h), selectors: sels}));
        // QUARANTINED sandwich sub-ops 0/1/2 (single deposit / dual deposit / exact-out mint at an attacker-moved,
        // already-unlocked spot): spot-priced CP-book mint = fs-blocked-entry-spot-mint root cause (V3 idle variant;
        // minimised in V3FSIdleSandwich.t.sol). Exits, rebalance and vault swaps at the moved spot stay enabled.
        h.setSandwichMask(0xf8);
        // QUARANTINED (NEW finding v3fs-idle-book-skew, V3FSBookSkew.t.sol): honest LPs no longer join at the
        // attacker-skewed book ratio; they join at the market ratio with a 50 bp min-shares bound.
        h.setHonestJoinAtBookRatio(false);
        _resetLog("test/apex_audit/p4-v3fs/nonvacuity.log");
    }

    function invariant_short() public view {
        _checkAll();
    }

    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    function invariant_medium() public view {
        _checkAll();
    }

    /// Non-vacuity: per-run selector success counts; most calls must succeed.
    function afterInvariant() external {
        (uint256 c, uint256 k) = h.totals();
        string memory line = string.concat("calls=", vm.toString(c), " ok=", vm.toString(k), " :: ", h.summary());
        console2.log(line);
        vm.writeLine("test/apex_audit/p4-v3fs/nonvacuity.log", line);
        // per-run gate only once the run is long enough to be meaningful (shrunk sequences are tiny)
        if (c >= 20) assertGe(k * 100, c * 60, "non-vacuity: >=60% of handler calls must succeed");
    }
}

/// @notice STRICT campaign: identical, but every attacker single-token zap-in route (exchangeIn token->shares,
///         SY deposit, exact-out mint, pretransfer-credit claim) is excluded, so the book-skew allowance is never
///         granted and INV-1 is tight (attacker allowance = pro-rata fees / passive gains + rounding only).
contract V3FSInvariantStrictTest is V3FSFixture {
    function setUp() public override {
        super.setUp();
        targetContract(address(h));
        bytes4[] memory sels = new bytes4[](20);
        sels[0] = V3FSHandler.h_dualDeposit.selector;
        sels[1] = V3FSHandler.h_dualExit.selector;
        sels[2] = V3FSHandler.h_zapOutExactIn.selector;
        sels[3] = V3FSHandler.h_zapOutExactOut.selector;
        sels[4] = V3FSHandler.h_swapExactIn.selector;
        sels[5] = V3FSHandler.h_swapExactOut.selector;
        sels[6] = V3FSHandler.h_keeperRebalance.selector;
        sels[7] = V3FSHandler.warp.selector;
        sels[8] = V3FSHandler.a_dualDeposit.selector;
        sels[9] = V3FSHandler.a_zapOutExactIn.selector;
        sels[10] = V3FSHandler.a_zapOutExactOut.selector;
        sels[11] = V3FSHandler.a_dualExit.selector;
        sels[12] = V3FSHandler.a_swapExactIn.selector;
        sels[13] = V3FSHandler.a_swapExactOut.selector;
        sels[14] = V3FSHandler.a_donate.selector;
        sels[15] = V3FSHandler.a_syRedeem.selector;
        sels[16] = V3FSHandler.a_syRedeemInternal.selector;
        sels[17] = V3FSHandler.a_rebalance.selector;
        sels[18] = V3FSHandler.a_sandwich.selector;
        sels[19] = V3FSHandler.a_importAttempt.selector;
        targetSelector(StdInvariant.FuzzSelector({addr: address(h), selectors: sels}));
        h.setSandwichMask(0xf8);
        h.setHonestJoinAtBookRatio(false);
        _resetLog("test/apex_audit/p4-v3fs/nonvacuity_strict.log");
    }

    function invariant_strict_short() public view {
        _checkAll();
        assertEq(h.skewAllowanceTotal(), 0, "strict: no skew allowance granted");
    }

    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    function invariant_strict_medium() public view {
        _checkAll();
        assertEq(h.skewAllowanceTotal(), 0, "strict: no skew allowance granted");
    }

    function afterInvariant() external {
        (uint256 c, uint256 k) = h.totals();
        string memory line = string.concat("STRICT calls=", vm.toString(c), " ok=", vm.toString(k), " :: ", h.summary());
        console2.log(line);
        vm.writeLine("test/apex_audit/p4-v3fs/nonvacuity_strict.log", line);
        if (c >= 20) assertGe(k * 100, c * 60, "non-vacuity: >=60% of handler calls must succeed");
    }
}
