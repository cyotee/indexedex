// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {ISecurePullErrors} from 'contracts/interfaces/ISecurePullErrors.sol';
import {TestBase_VaultComponents} from 'contracts/vaults/TestBase_VaultComponents.sol';
import {
    ComposedStableCommonDetf_Component_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol';
import {
    IRebasingDETFTokenDFPkg
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol';
import {
    RebasingDETFToken_Facet_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Facet_FactoryService.sol';
import {
    RebasingDETFToken_Pkg_FactoryService
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Pkg_FactoryService.sol';

contract MockRebasingWETH is IERC20 {
    string public constant name = 'Mock WETH';
    string public constant symbol = 'mWETH';
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

contract MockRebasingDETF {
    MockRebasingWETH internal immutable commonToken;
    uint256 internal rebasingValue;
    uint256 internal reserveBptPerRichir = 1 ether;
    uint256 internal commonTokenPerReserveBpt = 1 ether;
    bool internal revertClaimLiquidity;

    constructor(MockRebasingWETH commonToken_) {
        commonToken = commonToken_;
    }

    function setRebasingValue(uint256 rebasingValue_) external {
        rebasingValue = rebasingValue_;
    }

    function setReserveBptQuote(uint256 reserveBptQuote_) external {
        reserveBptPerRichir = reserveBptQuote_;
    }

    function setClaimLiquidityQuote(uint256 claimLiquidityQuote_) external {
        commonTokenPerReserveBpt = claimLiquidityQuote_;
    }

    function setClaimLiquidityRevert(bool shouldRevert_) external {
        revertClaimLiquidity = shouldRevert_;
    }

    function previewRebasingDetfTokenEthValue(uint256) external view returns (uint256) {
        return rebasingValue;
    }

    function previewRebasingDetfTokenReserveBpt(uint256 rebasingClaimAmount) external view returns (uint256) {
        return rebasingClaimAmount * reserveBptPerRichir / 1 ether;
    }

    function previewClaimLiquidity(uint256 reserveBptAmount) external view returns (uint256) {
        return reserveBptAmount * commonTokenPerReserveBpt / 1 ether;
    }

    function claimLiquidity(uint256 reserveBptAmount, address recipient) external returns (uint256) {
        if (revertClaimLiquidity) {
            revert('claim-liquidity');
        }

        uint256 amountOut = reserveBptAmount * commonTokenPerReserveBpt / 1 ether;
        commonToken.mint(recipient, amountOut);
        return amountOut;
    }
}

contract RebasingDETFTokenBehavior_Test is TestBase_VaultComponents {
    using RebasingDETFToken_Facet_FactoryService for ICreate3FactoryProxy;
    using RebasingDETFToken_Pkg_FactoryService for ICreate3FactoryProxy;

    IFacet internal rebasingDetfTokenFacet;
    IRebasingDETFTokenDFPkg internal pkg;
    IRebasingClaimToken internal token;

    MockRebasingWETH internal weth;
    MockRebasingDETF internal detf;
    address internal nftVault;

    address internal alice = makeAddr('alice');
    address internal bob = makeAddr('bob');
    uint256 internal constant PROTOCOL_NFT_ID = 7;

    function setUp() public override {
        super.setUp();

        rebasingDetfTokenFacet = create3Factory.deployRebasingDETFTokenFacet();
        pkg = create3Factory.deployRebasingDETFTokenDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildRebasingDetfTokenPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.RebasingDetfTokenFacets({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet,
                    multiStepOwnableFacet: multiStepOwnableFacet,
                    rebasingDetfTokenFacet: rebasingDetfTokenFacet
                }),
                diamondPackageFactory
            )
        );

        weth = new MockRebasingWETH();
        detf = new MockRebasingDETF(weth);
        nftVault = makeAddr('nftVault');

        token = IRebasingClaimToken(
            pkg.deployToken(IDETF(address(detf)), IDETFNFTVault(nftVault), IERC20(address(weth)), PROTOCOL_NFT_ID, owner)
        );

        _mockPosition(10);
        _mockDetfValue(10 ether);
        detf.setReserveBptQuote(1 ether);
        detf.setClaimLiquidityQuote(1 ether);
    }

    function test_mintFromNFTSale_mintsSharesAtDefaultRate() public {
        vm.prank(owner);
        uint256 minted = token.mintFromNFTSale(10, alice);

        assertEq(minted, 10 ether, 'minted balance');
        assertEq(token.sharesOf(alice), 10, 'external shares');
        assertEq(token.totalShares(), 10, 'total shares');
        assertEq(token.balanceOf(alice), 10 ether, 'balance after mint');
    }

    function test_balanceOf_rebasesWithUpdatedDetfPricing() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        _mockDetfValue(50 ether);
        vm.roll(block.number + 1);

        assertEq(token.redemptionRate(), 5 ether * 1e18, 'updated rate');
        assertEq(token.balanceOf(alice), 50 ether, 'rebased balance');
        assertEq(token.totalSupply(), 50 ether, 'rebased supply');
    }

    function test_transfer_movesUnderlyingSharesAtCurrentRate() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.prank(alice);
        bool success = token.transfer(bob, 4 ether);

        assertTrue(success, 'transfer success');
        assertEq(token.sharesOf(alice), 6, 'alice shares');
        assertEq(token.sharesOf(bob), 4, 'bob shares');
        assertEq(token.balanceOf(alice), 6 ether, 'alice balance');
        assertEq(token.balanceOf(bob), 4 ether, 'bob balance');
    }

    function test_redeem_transfersWethAndBurnsShares() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.prank(alice);
        uint256 wethOut = token.redeem(4 ether, bob, false);

        assertEq(wethOut, 4 ether, 'redeem output');
        assertEq(weth.balanceOf(bob), 4 ether, 'recipient weth');
        assertEq(token.sharesOf(alice), 6, 'alice shares after redeem');
        assertEq(token.totalShares(), 6, 'total shares after redeem');
    }

    function test_previewExchangeIn_returnsConfiguredCommonTokenQuote() public {
        uint256 quotedOut = IStandardExchangeIn(address(token)).previewExchangeIn(IERC20(address(token)), 4 ether, IERC20(address(weth)));

        assertEq(quotedOut, 4 ether, 'preview exchange-in quote');
    }

    function test_exchangeOut_redeemsExactCommonTokenAmount() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.startPrank(alice);
        token.approve(address(token), 5 ether);
        uint256 richirIn = IStandardExchangeOut(address(token)).exchangeOut(
            IERC20(address(token)), 5 ether, IERC20(address(weth)), 4 ether, bob, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(richirIn, 4 ether, 'exact-out richir in');
        assertEq(weth.balanceOf(bob), 4 ether, 'exact-out common token recipient balance');
        assertEq(token.sharesOf(alice), 6, 'alice shares after exact-out redeem');
    }

    function test_exchangeIn_revertsWhenClaimLiquidityFails_withoutBurningShares() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);
        detf.setClaimLiquidityRevert(true);

        vm.startPrank(alice);
        token.approve(address(token), 4 ether);
        vm.expectRevert(bytes('claim-liquidity'));
        IStandardExchangeIn(address(token)).exchangeIn(
            IERC20(address(token)), 4 ether, IERC20(address(weth)), 0, bob, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(token.sharesOf(alice), 10, 'alice shares preserved');
        assertEq(token.totalShares(), 10, 'total shares preserved');
        assertEq(token.sharesOf(address(token)), 0, 'token escrow shares rolled back');
        assertEq(weth.balanceOf(bob), 0, 'recipient received no weth');
    }

    function test_exchangeOut_revertsWhenClaimLiquidityFails_withoutBurningShares() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);
        detf.setClaimLiquidityRevert(true);

        vm.startPrank(alice);
        token.approve(address(token), 5 ether);
        vm.expectRevert(bytes('claim-liquidity'));
        IStandardExchangeOut(address(token)).exchangeOut(
            IERC20(address(token)), 5 ether, IERC20(address(weth)), 4 ether, bob, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(token.sharesOf(alice), 10, 'alice shares preserved after exact-out revert');
        assertEq(token.totalShares(), 10, 'total shares preserved after exact-out revert');
        assertEq(token.sharesOf(address(token)), 0, 'token escrow shares rolled back after exact-out revert');
        assertEq(weth.balanceOf(bob), 0, 'recipient received no weth after exact-out revert');
    }

    function test_burnShares_pretransferred_burnsFromTokenBalance() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        vm.prank(alice);
        token.transfer(address(token), 4 ether);

        vm.prank(owner);
        uint256 sharesBurned = token.burnShares(4 ether, alice, true);

        assertEq(sharesBurned, 4, 'shares burned');
        assertEq(token.totalShares(), 6, 'total shares after burn');
        assertEq(token.sharesOf(address(token)), 0, 'token escrow shares burned');
        assertEq(token.sharesOf(alice), 6, 'alice remaining shares');
    }

    /* ---------------------------------------------------------------------- */
    /*  Catalog I — secure pull free-credit (proxy surface, L-GAPS-9/10)      */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 redeem: inventory on RebasingDETF proxy without in-call transfer cannot free-redeem.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));

        uint256 claimed = 4 ether;
        uint256 balBefore = token.balanceOf(address(token));

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        token.redeem(claimed, alice, true);

        assertEq(token.balanceOf(address(token)), balBefore, 'I1 must not consume inventory');
        assertEq(weth.balanceOf(alice), 0, 'I1 no free weth');
    }

    /// @notice I1 exchangeIn: same gate on SE surface via production proxy.
    function test_I1_pretransferred_exchangeIn_inventoryNoInCallTransfer_revertsDelta0() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, address(token));

        uint256 claimed = 4 ether;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        IStandardExchangeIn(address(token)).exchangeIn(
            IERC20(address(token)), claimed, IERC20(address(weth)), 0, alice, true, block.timestamp + 1
        );
    }

    /// @notice I2: transfer-before-call is outside the pull window (observedDelta 0).
    function test_I2_pretransferred_transferBeforeCall_revertsDelta0() public {
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        uint256 claimed = 4 ether;
        vm.prank(alice);
        token.transfer(address(token), claimed);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        token.redeem(claimed, alice, true);
    }

    /// @notice I3: residual held claim cannot fund a second free pretransfer redeem.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        vm.prank(owner);
        token.mintFromNFTSale(5, address(token));
        vm.prank(owner);
        token.mintFromNFTSale(10, alice);

        uint256 claimed = 4 ether;
        vm.prank(alice);
        uint256 out_ = token.redeem(claimed, bob, false);
        assertGt(out_, 0);

        uint256 residual_ = token.balanceOf(address(token));
        if (residual_ < claimed) {
            vm.prank(owner);
            token.mintFromNFTSale(10, address(token));
            residual_ = token.balanceOf(address(token));
        }
        assertGe(residual_, claimed);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        token.redeem(claimed, alice, true);

        assertEq(token.balanceOf(address(token)), residual_, 'I3 residual preserved');
    }

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

    function _mockDetfValue(uint256 wethValue_) internal {
        detf.setRebasingValue(wethValue_);
    }
}