// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IRebasingClaimTokenDFPkg
} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                               Mocks                                        */
/* -------------------------------------------------------------------------- */

contract MockClaimRateAsset is IERC20 {
    string public constant name = "Mock Rate Asset";
    string public constant symbol = "mRATE";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
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
}

/// @notice Minimal DETF mock for RebasingClaimToken rate + claimLiquidity.
/// @dev External claim shares are small integers (LP principal units). Rate math treats
///      1 external share ≈ 1e18 rateAsset when preview values position principal 1:1.
contract MockClaimDetf {
    MockClaimRateAsset internal immutable rateAsset_;
    address internal immutable bpt_;
    /// @notice rateAsset wei paid per external LP principal unit on claimLiquidity.
    uint256 internal rateAssetPerExternalShare = 1 ether;
    bool internal revertClaimLiquidity;

    constructor(MockClaimRateAsset rateAsset, address bpt) {
        rateAsset_ = rateAsset;
        bpt_ = bpt;
    }

    function setClaimLiquidityQuote(uint256 quote_) external {
        rateAssetPerExternalShare = quote_;
    }

    function setClaimLiquidityRevert(bool shouldRevert_) external {
        revertClaimLiquidity = shouldRevert_;
    }

    function reservePool() external view returns (address) {
        return bpt_;
    }

    /// @dev Position originalShares are external principal units; value each at 1e18 rateAsset.
    function previewExchangeIn(IERC20, uint256 amountIn, IERC20) external pure returns (uint256) {
        return amountIn * 1 ether;
    }

    function claimLiquidity(uint256 lpPrincipal, address recipient) external returns (uint256) {
        if (revertClaimLiquidity) {
            revert("claim-liquidity");
        }
        uint256 amountOut = lpPrincipal * rateAssetPerExternalShare;
        rateAsset_.mint(recipient, amountOut);
        return amountOut;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Suite                                        */
/* -------------------------------------------------------------------------- */

/**
 * @title RebasingClaimToken_TrustFlags_Test
 * @notice Catalog I1/I2/I3 on production RebasingClaimToken **proxy** (WP-I-CLAIM-001 / L-GAPS-9/10).
 * @dev I1: pretransferred=true, no in-call transfer, inventory present → TransferDeltaInsufficient(claimed, 0)
 *      I2: claimed > observedDelta (pretransfer short / zero delta)
 *      I3: residual inventory after honest pull cannot fund a second free pretransfer credit
 *      Calls go through diamond proxy only (never facet implementation address).
 */
contract RebasingClaimToken_TrustFlags_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;

    IRebasingClaimTokenDFPkg internal pkg;
    IRebasingClaimToken internal token;

    MockClaimRateAsset internal rateAsset;
    MockClaimDetf internal detf;
    address internal nftVault;
    address internal bpt;

    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");
    address internal bob = makeAddr("bob");

    uint256 internal constant PROTOCOL_NFT_ID = 1;
    uint256 internal constant CLAIMED = 4 ether;
    uint256 internal constant INVENTORY = 2 ether;

    function setUp() public override {
        super.setUp();

        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        pkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );

        rateAsset = new MockClaimRateAsset();
        bpt = makeAddr("mockBpt");
        detf = new MockClaimDetf(rateAsset, bpt);
        nftVault = makeAddr("nftVault");

        token = IRebasingClaimToken(
            pkg.deployToken(IDetf(address(detf)), IDETFNFTVault(nftVault), IERC20(address(rateAsset)), PROTOCOL_NFT_ID, owner)
        );

        // Position principal matches mint sizes used below so rate ≈ 1e18 (1 share → 1e18 balance).
        _mockPosition(10);
        detf.setClaimLiquidityQuote(1 ether);
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: inventory present, no in-call transfer, pretransferred=true       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 redeem: mint inventory onto claim proxy; attacker claims pretransferred without
    ///         transferring. Must revert TransferDeltaInsufficient(claimed, 0).
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        // Inventory on diamond via mint-to-proxy (absolute coverage theater would pass).
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));
        assertEq(token.balanceOf(address(token)), 10 ether);
        assertEq(token.balanceOf(attacker), 0);

        uint256 balBefore = token.balanceOf(address(token));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        token.redeem(CLAIMED, attacker, true);

        assertEq(token.balanceOf(address(token)), balBefore, "I1 must not consume inventory");
        assertEq(token.balanceOf(attacker), 0);
        assertEq(rateAsset.balanceOf(attacker), 0, "I1 no free rateAsset");
    }

    /// @notice I1 exchangeIn: same free-credit gate on SE surface.
    function test_I1_pretransferred_exchangeIn_inventoryNoInCallTransfer_revertsDelta0() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        IStandardExchangeIn(address(token)).exchangeIn(
            IERC20(address(token)), CLAIMED, IERC20(address(rateAsset)), 0, attacker, true, block.timestamp + 1
        );
    }

    /// @notice I1 variant: claimed strictly less than inventory still fails (absolute coverage forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));
        uint256 claimed = INVENTORY; // claimed < inventory (10e18)

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        token.redeem(claimed, attacker, true);
    }

    /// @notice I1: transfer-before-call is outside the pull window under L-GAPS-9.
    function test_I1_pretransferred_transferBeforeCall_revertsDelta0() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.prank(alice);
        token.transfer(address(token), CLAIMED);
        assertEq(token.balanceOf(address(token)), CLAIMED);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        token.redeem(CLAIMED, alice, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: short delivery — claimed > observedDelta                          */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: claimed > 0 with observedDelta 0 (pretransferred, no inbound).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        token.redeem(CLAIMED, alice, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest redeem leaves residual held claim, a second pretransferred call
    ///         with no new inbound delta cannot free-credit residual.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        // Keep total external shares aligned with position principal for ~1e18 rate.
        _mockPosition(20);
        // Seed residual inventory on diamond.
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));
        // Alice holds redeemable shares pulled in-call.
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        uint256 claimed_ = token.balanceOf(alice) / 2;
        assertGt(claimed_, 0);

        vm.startPrank(alice);
        uint256 out_ = token.redeem(claimed_, bob, false);
        vm.stopPrank();

        assertGt(out_, 0, "honest redeem ok");
        uint256 residual_ = token.balanceOf(address(token));
        // Residual may drop if rate/share math consumes escrow differently; re-seed if needed.
        if (residual_ < claimed_) {
            _mockPosition(30);
            vm.prank(owner);
            token.mintFromNFTSale(10, address(token));
            residual_ = token.balanceOf(address(token));
        }
        assertGe(residual_, claimed_, "residual covers claimed");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        token.redeem(claimed_, attacker, true);

        assertEq(token.balanceOf(address(token)), residual_, "I3 second call must not move inventory");
        assertEq(rateAsset.balanceOf(attacker), 0, "I3 no free rateAsset");
    }

    /* ---------------------------------------------------------------------- */
    /*  Positive control                                                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Honest !pretransferred redeem succeeds and pays via claimLiquidity.
    function test_I_positive_honestPullRedeem_succeeds() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.prank(alice);
        uint256 out_ = token.redeem(CLAIMED, bob, false);

        assertEq(out_, CLAIMED, "redeem output");
        assertEq(rateAsset.balanceOf(bob), CLAIMED, "recipient rateAsset");
        assertEq(token.sharesOf(alice), 6, "alice shares after redeem");
    }

    /* ---------------------------------------------------------------------- */
    /*  Helpers                                                               */
    /* ---------------------------------------------------------------------- */

    function _mockPosition(uint256 originalShares_) internal {
        IDETFNFTVault.Position memory position = IDETFNFTVault.Position({
            originalShares: originalShares_,
            effectiveShares: originalShares_,
            bonusMultiplier: 1e18,
            unlockTime: 0,
            rewardDebt: 0
        });

        vm.mockCall(
            nftVault,
            abi.encodeWithSelector(IDETFNFTVault.getPosition.selector, PROTOCOL_NFT_ID),
            abi.encode(position)
        );
    }
}
