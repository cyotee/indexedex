// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {HostileCallbackERC20} from "contracts/test/stubs/HostileCallbackERC20.sol";
import {ERC20TestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/ERC20TestToken.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

contract Adversarial_ComposedStable_SecRemediation_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    HostileCallbackERC20 internal hostile;

    function _createAerodromeTestPool() internal override {
        hostile = new HostileCallbackERC20(18);
        dai = ERC20TestToken(address(hostile));
        super._createAerodromeTestPool();
    }

    function _payment() internal pure returns (uint256) {
        return 10e18;
    }

    function _probe(bool outerBond_, bool nestedBond_) internal {
        _bootstrapReserveGraph();
        uint256 amount_ = _payment();
        hostile.mint(bob, amount_ * 2);
        vm.startPrank(bob);
        hostile.approve(deployedDetfVault, amount_ * 2);
        uint256 control_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(hostile, amount_, detfToken, 0, bob, false, block.timestamp);
        vm.stopPrank();
        assertGt(control_, 0, "same route succeeds without callback");
        bytes memory call_ = nestedBond_
            ? abi.encodeCall(
                IComposedStableCommonDetfBonding.bond,
                (IERC20(address(hostile)), amount_, 30 days, bob, block.timestamp)
            )
            : abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (IERC20(address(hostile)), amount_, detfToken, 0, bob, false, block.timestamp)
            );
        hostile.arm(deployedDetfVault, call_);
        vm.startPrank(bob);
        if (outerBond_) {
            (uint256 id_, uint256 principal_) = IComposedStableCommonDetfBonding(deployedDetfVault)
                .bond(hostile, amount_, 30 days, bob, block.timestamp);
            assertGt(principal_, 0);
            assertEq(IDetfBondNFT(address(bondNFTVault)).ownerOf(id_), bob);
        } else {
            uint256 paid_ = IStandardExchangeIn(deployedDetfVault)
                .exchangeIn(hostile, amount_, detfToken, 0, bob, false, block.timestamp);
            assertGt(paid_, 0);
            assertEq(detfToken.balanceOf(bob), control_ + paid_);
        }
        vm.stopPrank();
        assertEq(hostile.attempts(), 1, "payment callback reached real DETF");
        assertFalse(hostile.succeeded());
        assertEq(hostile.errorSelector(), IReentrancyLock.IsLocked.selector);
        assertEq(hostile.balanceOf(bob), 0, "only funded outer payments spent");
    }

    function test_C1_hostilePairToken_reenterExchangeIn_hitsIsLocked() public {
        _probe(false, false);
    }

    function test_C2_hostilePairToken_reenterBond_hitsIsLocked() public {
        _probe(true, true);
    }

    function test_C3_mintReenterBond_hitsIsLocked() public {
        _probe(false, true);
    }

    function _assertNoPublicMint(address token_, address caller_) internal {
        bytes4 selector_ = IERC20MintBurn.mint.selector;
        assertEq(IDiamondLoupe(token_).facetAddress(selector_), address(0));
        uint256 supply_ = IERC20(token_).totalSupply();
        vm.prank(caller_);
        vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", selector_));
        IERC20MintBurn(token_).mint(caller_, 1e9);
        assertEq(IERC20(token_).totalSupply(), supply_);
    }

    function test_F_detfToken_hasNoExternalMintAuthority() public {
        _assertNoPublicMint(deployedDetfVault, owner);
    }

    function test_F_stakingToken_hasNoExternalMintAuthority() public {
        _assertNoPublicMint(address(rebasingDetfToken), owner);
    }

    function test_F_deployer_cannotMintAfterGoLive() public {
        _bootstrapReserveGraph();
        _assertNoPublicMint(deployedDetfVault, owner);
    }

    function test_F_stranger_mint_reverts() public {
        _assertNoPublicMint(deployedDetfVault, bob);
    }

    function test_F_fundedBond_isTheAuthorizedIssuancePath() public {
        _bootstrapReserveGraph();
        uint256 before_ = detfToken.totalSupply();
        _buyFixtureBond(bob);
        assertGt(detfToken.totalSupply(), before_);
    }

    function test_F_stakingRewards_requireDetfAuthorization() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", bob));
        IStakedDETF(address(rebasingDetfToken)).fundRewards(1e9);
    }

    function test_A0_cs_preLive_donatedPairToken_cannotBeFirstMinted() public {
        uint256 amount_ = _payment();
        hostile.mint(bob, amount_ * 2);
        vm.startPrank(bob);
        hostile.transfer(deployedDetfVault, amount_);
        hostile.approve(deployedDetfVault, amount_);
        vm.expectRevert(bytes4(keccak256("ReservePoolNotInitialized()")));
        IStandardExchangeIn(deployedDetfVault).exchangeIn(hostile, amount_, detfToken, 0, bob, false, block.timestamp);
        vm.stopPrank();
        assertEq(hostile.balanceOf(deployedDetfVault), amount_);
        assertEq(detfToken.balanceOf(bob), 0);
    }

    function test_A0_cs_preLive_donatedPairToken_survivesFirstBond() public {
        uint256 amount_ = _payment();
        hostile.mint(bob, amount_);
        vm.prank(bob);
        hostile.transfer(deployedDetfVault, amount_);
        _bootstrapReserveGraph();
        assertEq(hostile.balanceOf(deployedDetfVault), amount_);
        assertEq(detfToken.balanceOf(bob), 0);
    }
}
