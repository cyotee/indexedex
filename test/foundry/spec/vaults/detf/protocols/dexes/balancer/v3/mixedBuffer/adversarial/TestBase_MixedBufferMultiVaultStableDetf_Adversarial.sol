// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {HostileReentrantShare, HostileReentrantShareDecimals} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfDFPkg.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";

/// @title TestBase_MixedBufferMultiVaultStableDetf_Adversarial
/// @notice Production MixedBuffer DETF + real SE with a hostile underlying ERC20 (WP-ADV-DETF-MB-001 A–H residual).
/// @dev I CODE (I1–I3 trust-flag / secure pull) lives in Adversarial_MixedBuffer_TrustFlag.t.sol.
abstract contract TestBase_MixedBufferMultiVaultStableDetf_Adversarial is TestBase_MixedBufferMultiVaultStableDetf {
    address internal attacker;
    address internal victim;

    HostileReentrantShare internal hostileBuffer;
    IStandardExchangeProxy internal hostileVault;
    DetfReentryTarget internal reentryTarget;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker"); victim = makeAddr("victim");
        hostileBuffer = new HostileReentrantShareDecimals(IERC20Metadata(address(_fixtureBufferToken())).decimals());
        reentryTarget = new DetfReentryTarget();
    }


    function _bufferOf(address instance_) internal view returns (IERC20) {
        return IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
    }

    function _openLiveGated() internal returns (address instance_) {
        instance_ = _deployDetfN(1, 100e18, 0.1e18);
        _bootstrapDefault(instance_, alice);
        _assertLive(instance_);
    }

    function _openLiveGatedN(uint8 n) internal returns (address instance_) {
        instance_ = _deployDetfN(n, 100e18, 0.1e18);
        _bootstrapDefault(instance_, alice);
        _assertLive(instance_);
    }

    /// @dev The SE leg is deployed by the registered production Aerodrome package.
    function _deployHostileBufferDetf() internal returns (address instance_) {
        address pool_ = aerodromePoolFactory.createPool(address(hostileBuffer), address(_fixtureBufferToken()), false);
        uint256 seed_ = AERODROME_POOL_INIT_AMOUNT;
        hostileBuffer.mint(address(this), seed_); _fundBuffer(address(this), seed_);
        hostileBuffer.approve(address(aerodromeRouter), seed_); _fixtureBufferToken().approve(address(aerodromeRouter), seed_);
        aerodromeRouter.addLiquidity(address(hostileBuffer), address(_fixtureBufferToken()), false, seed_, seed_, 1, 1, address(this), block.timestamp);
        hostileVault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(IPool(pool_)));
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 100e18, 0.1e18);
        args.name = "Hostile underlying Mixed Buffer DETF";
        args.symbol = "DETF";
        args.bufferToken = IERC20(address(hostileBuffer));
        args.standardExchangeVaults[0] = IStandardExchange(address(hostileVault));
        instance_ = _deployWithArgs(args);
    }

    function _fundHostileVaultShares(address user_, uint256 amount_) internal returns (uint256 shares_) {
        hostileBuffer.mint(user_, amount_); _fundBuffer(user_, amount_);
        vm.startPrank(user_);
        hostileBuffer.approve(address(aerodromeRouter), amount_); _fixtureBufferToken().approve(address(aerodromeRouter), amount_);
        (,, uint256 lp_) = aerodromeRouter.addLiquidity(address(hostileBuffer), address(_fixtureBufferToken()), false, amount_, amount_, 1, 1, user_, block.timestamp);
        IERC20(hostileVault.asset()).approve(address(hostileVault), lp_);
        shares_ = hostileVault.deposit(lp_, user_);
        vm.stopPrank();
        assertGt(shares_, 0);
    }


    function _bootstrapHostile(address instance_, address user_, uint256 bufferAmt_, uint256 shareFunding_)
        internal returns (uint256 tokenId_)
    {
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = _fundHostileVaultShares(user_, shareFunding_);
        hostileBuffer.mint(user_, bufferAmt_);
        vm.startPrank(user_);
        hostileBuffer.approve(instance_, bufferAmt_); hostileVault.approve(instance_, shares_[0]);
        (tokenId_,,) = IMixedBufferMultiVaultStableDetfBonding(instance_).bootstrapFirstBond(
            bufferAmt_, shares_, DEFAULT_MIN_LOCK, user_, block.timestamp);
        vm.stopPrank();
        _assertLive(instance_);
    }

    function _executeHostileMint(address instance_, address user_, uint256 amount_) internal returns (uint256 paid_) {
        hostileBuffer.mint(user_, amount_);
        IStandardExchangeIn exchange_ = IStandardExchangeIn(instance_);
        uint256 quote_ = exchange_.previewExchangeIn(IERC20(address(hostileBuffer)), amount_, IERC20(instance_));
        uint256 rawBefore_ = IERC20(instance_).balanceOf(user_);
        uint256 inputBefore_ = hostileBuffer.balanceOf(user_);
        vm.startPrank(user_); hostileBuffer.approve(instance_, amount_);
        paid_ = exchange_.exchangeIn(IERC20(address(hostileBuffer)), amount_, IERC20(instance_), quote_, user_, false, block.timestamp);
        vm.stopPrank();
        assertGt(paid_, 0); assertEq(paid_, quote_);
        assertEq(IERC20(instance_).balanceOf(user_), rawBefore_ + paid_);
        assertEq(hostileBuffer.balanceOf(user_), inputBefore_ - amount_);
    }

    function _fundedNft(address instance_) internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault());
    }

    function _matureClaim(address instance_, uint256 id_, address user_) internal returns (IStakedDETF staking_) {
        IDetfBondNFT nft_ = _fundedNft(instance_);
        Math.BondPosition memory position_ = nft_.positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        staking_ = IStakedDETF(_claimOf(instance_));
        uint256 before_ = staking_.balanceOf(user_);
        uint256 lpBefore_ = nft_.lpToken().balanceOf(address(nft_));
        vm.prank(user_); (uint256 p_, uint256 r_) = nft_.claimBond(id_, user_);
        assertEq(p_, position_.principal - position_.claimedPrincipal);
        assertEq(staking_.balanceOf(user_), before_ + p_ + r_);
        assertEq(nft_.lpToken().balanceOf(address(nft_)), lpBefore_);
    }


    function _claimOf(address instance_) internal view returns (address) {
        return IMixedBufferMultiVaultStableDetfInfo(instance_).rebasingClaimToken();
    }

    /// @dev Outer MixedBuffer over nested live MixedBuffer (leg0) + production SE (leg1).
    function _deployOuterOverNested(address nested_) internal returns (address outer_) {
        _ensureSeVaults(2);
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory outerArgs;
        outerArgs.name = "Adv Outer MBMV Nested";
        outerArgs.symbol = "advOMV";
        outerArgs.bufferToken = IERC20(address(_fixtureBufferToken()));
        outerArgs.standardExchangeVaults = new IStandardExchange[](2);
        outerArgs.vaultShareRateProviders = new IRateProvider[](2);
        outerArgs.standardExchangeVaults[0] = IStandardExchange(nested_);
        outerArgs.standardExchangeVaults[1] = IStandardExchange(address(seVaults[1]));
        outerArgs.amplificationParameter = MBMVS_AMP;
        outerArgs.mintThreshold = 100e18;
        outerArgs.burnThreshold = 0.1e18;

        vm.startPrank(owner);
        outer_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(outerArgs)
        );
        vm.stopPrank();
    }

    function _bootstrapOuterWithNested(address outer_, address nested_, address user) internal {
        uint256 nestedShares_ = _mintDetfFromBuffer(nested_, user, _fixtureAmount(400e18));
        nestedShares_ += _mintDetfFromVaultShare(nested_, 0, user, 200e18);
        require(nestedShares_ > 50e9, "nested shares for bootstrap");

        uint256 se1Shares_ = _fundVaultShares(1, user, 500e18);
        _fundBuffer(user, _fixtureAmount(BOOTSTRAP_BUFFER));

        uint256[] memory amts_ = new uint256[](2);
        amts_[0] = nestedShares_;
        amts_[1] = se1Shares_;

        vm.startPrank(user);
        IERC20(nested_).approve(outer_, nestedShares_);
        seShares[1].approve(outer_, se1Shares_);
        IERC20(address(_fixtureBufferToken())).approve(outer_, _fixtureAmount(BOOTSTRAP_BUFFER));
        IMixedBufferMultiVaultStableDetfBonding(outer_).bootstrapFirstBond(
            _fixtureAmount(BOOTSTRAP_BUFFER), amts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertLive(outer_);
    }
}
