// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/// @notice Wave 2B SE adversarial P0 on production Aerodrome Standard Exchange vault.
/// @dev Catalog: A1 donation, E5 zero/deadline, H3 residual, F1 cut, I1–I3 free-credit (L-GAPS-9/10),
///      J1–J3 facetFuncs/loupe/proxy smoke (WP-I-SE-AC-001 / WP-J-SE-AC-001).
///      C-class: see ReentrancyGuard suite. Production DFPkg proxy only (no mock SUT).
contract AerodromeSE_Adversarial_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("seAttacker");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT;
        deal(address(tokenA), attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault_)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), amount_);
        assertEq(IERC20(address(vault_)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    /// @notice E5: expired deadline reverts with `DeadlineExceeded` (WP-E5-AERO-001).
    function test_E5_expiredDeadline_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 2;
        uint256 expired_ = _expiredDeadline();
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 2;
        deal(address(tokenA), attacker, amount_);
        uint256 preview_ = vault_.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_F1_diamondCut_blocked() public {
        IStandardExchangeProxy vault_ = _vault();
        (bool ok,) = address(vault_).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_E1_swapRoundTrip_bounded() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 4;
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 outB_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        assertTrue(outB_ > 0, "got tokenB");
        tokenB.approve(address(vault_), outB_);
        uint256 backA_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenB)), outB_, IERC20(address(tokenA)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        // Round-trip loses fees/slippage - out <= in
        assertLe(backA_, amount_, "E1: no free lunch on SE swap round-trip");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1–I3: pretransfer trust flags must not free-credit inventory         */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 free credit: donate inventory; claim pretransferred without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 claimed_ = TEST_AMOUNT / 4;

        // Seed inventory so absolute balance theater would have passed.
        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), claimed_);
        assertEq(tokenA.balanceOf(address(vault_)), claimed_, "inventory present");
        assertEq(tokenA.balanceOf(attacker), 0, "attacker drained");
        assertEq(tokenA.allowance(attacker, address(vault_)), 0, "no allowance");

        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 attackerSharesBefore_ = vault_.balanceOf(attacker);
        uint256 invBefore_ = tokenA.balanceOf(address(vault_));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free share mint");
        assertEq(vault_.balanceOf(attacker), attackerSharesBefore_, "I1: attacker shares unchanged");
        assertEq(tokenA.balanceOf(address(vault_)), invBefore_, "I1: inventory unmoved");
    }

    /// @notice I1 claimed ≤ inventory still reverts when observedDelta is 0 (absolute credit forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 inventory_ = TEST_AMOUNT / 2;
        uint256 claimed_ = TEST_AMOUNT / 8;

        tokenA.mint(address(vault_), inventory_);
        assertGe(tokenA.balanceOf(address(vault_)), claimed_, "claimed <= inventory");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice I2: transfer-before-call + pretransferred=true is outside the pull window (delta 0).
    function test_I2_transferBeforeCall_pretransferred_revertsDelta0() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 claimed_ = TEST_AMOUNT / 10;

        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), claimed_);

        // Prior external transfer is not in-window delta under L-GAPS-9.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice I3: residual inventory after an honest pull cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 8;
        uint256 residualSeed_ = TEST_AMOUNT / 16;

        // Pre-seed residual that remains after first honest pull.
        tokenA.mint(address(vault_), residualSeed_);

        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest first pull");

        uint256 residual_ = tokenA.balanceOf(address(vault_));
        assertGe(residual_, residualSeed_, "residual inventory remains");

        // Second call: pretransferred=true, claim against residual, no new transfer.
        uint256 claim_ = residualSeed_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claim_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(tokenA.balanceOf(address(vault_)), residual_, "I3 second call must not move inventory");
    }

    /// @notice Positive control: honest !pretransferred pull succeeds.
    function test_I_positive_honestPullSwap_succeeds() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amountIn_ = TEST_AMOUNT / 8;
        tokenA.mint(attacker, amountIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amountIn_);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), amountIn_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest !pretransferred swap");
        assertEq(tokenB.balanceOf(attacker), out_, "attacker received tokenB");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: diamond surface on production proxy (WP-J-SE-AC-001)           */
    /* ---------------------------------------------------------------------- */

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](4);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IStandardExchangeOut.exchangeOut.selector;
        sels_[3] = IStandardExchangeOut.previewExchangeOut.selector;
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: CREATE3 facetFuncs cover target money/query selectors (Target ⊆ facetFuncs).
    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeInFacet)).facetFuncs(), IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeInFacet)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(_vault()));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(_vault()), "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        address exchangeInFacet_ = IDiamondLoupe(address(vault_)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault_)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault_), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault_), "proxy cut out");

        uint256 previewIn_ =
            IStandardExchangeIn(address(vault_)).previewExchangeIn(IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        // Money path smoke: product revert (not missing selector) for free-credit I1 path.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)), 0, attacker, true, _deadline()
        );
    }
}
