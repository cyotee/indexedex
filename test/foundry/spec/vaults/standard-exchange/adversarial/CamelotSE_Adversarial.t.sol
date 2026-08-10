// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/// @notice Wave 2B SE adversarial P0 on production Camelot V2 Standard Exchange vault.
/// @dev Second protocol for ≥2 SE instances. Catalog: A1, E5, H3, F1, I1–I3 free-credit (L-GAPS-9/10),
///      J1–J3 facetFuncs/loupe/proxy smoke (WP-I-SE-AC-001 / WP-J-SE-AC-001).
///      C-class: CamelotV2StandardExchange_ReentrancyGuard. Production DFPkg proxy only.
contract CamelotSE_Adversarial_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    address internal attacker;

    uint256 internal constant SEED = 1000 ether;
    uint256 internal constant TEST_AMT = 50 ether;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("camelotSeAttacker");
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 10_000 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 10_000 ether);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        vault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenA)), SEED, IERC20(address(tokenB)), SEED, address(this)
            )
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT;
        deal(address(tokenA), attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault), amount_);
        assertEq(IERC20(address(vault)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = address(vault).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = TEST_AMT;
        deal(address(tokenA), attacker, amount_);
        uint256 preview_ =
            vault.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0, "H3 residual");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1–I3: pretransfer trust flags must not free-credit inventory         */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 free credit: donate inventory; claim pretransferred without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 claimed_ = TEST_AMT;

        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault), claimed_);
        assertEq(tokenA.balanceOf(address(vault)), claimed_, "inventory present");
        assertEq(tokenA.balanceOf(attacker), 0, "attacker drained");
        assertEq(tokenA.allowance(attacker, address(vault)), 0, "no allowance");

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 invBefore_ = tokenA.balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(vault.totalSupply(), supplyBefore_, "I1: no free share mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "I1: attacker shares unchanged");
        assertEq(tokenA.balanceOf(address(vault)), invBefore_, "I1: inventory unmoved");
    }

    /// @notice I1 claimed ≤ inventory still reverts when observedDelta is 0.
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        uint256 inventory_ = TEST_AMT * 2;
        uint256 claimed_ = TEST_AMT / 2;

        tokenA.mint(address(vault), inventory_);
        assertGe(tokenA.balanceOf(address(vault)), claimed_, "claimed <= inventory");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice I2: transfer-before-call + pretransferred=true is outside the pull window.
    function test_I2_transferBeforeCall_pretransferred_revertsDelta0() public {
        uint256 claimed_ = TEST_AMT;

        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault), claimed_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice I3: residual inventory after honest pull cannot fund second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        uint256 amount_ = TEST_AMT;
        uint256 residualSeed_ = 10 ether;

        tokenA.mint(address(vault), residualSeed_);

        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        uint256 out_ = vault.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest first pull");

        uint256 residual_ = tokenA.balanceOf(address(vault));
        assertGe(residual_, residualSeed_, "residual inventory remains");

        uint256 claim_ = residualSeed_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claim_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(tokenA.balanceOf(address(vault)), residual_, "I3 second call must not move inventory");
    }

    /// @notice Positive control: honest !pretransferred pull succeeds.
    function test_I_positive_honestPullSwap_succeeds() public {
        uint256 amountIn_ = TEST_AMT;
        tokenA.mint(attacker, amountIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amountIn_);
        uint256 out_ = vault.exchangeIn(
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

    /// @notice J1: CREATE3 facetFuncs cover target money/query selectors.
    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(
                IFacet(address(camelotV2StandardExchangeInFacet)).facetFuncs(), IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(camelotV2StandardExchangeInFacet)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(camelotV2StandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(camelotV2StandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(vault), "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call on proxy (not facet impl).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address exchangeInFacet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault), "proxy cut out");

        uint256 previewIn_ =
            IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)), 0, attacker, true, _deadline()
        );
    }
}
