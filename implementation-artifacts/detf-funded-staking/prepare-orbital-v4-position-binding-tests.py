from pathlib import Path
p=Path('test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol')
s=p.read_text()
assert 'contract OrbitalV4PositionFundedBindingTest' not in s
s+='''

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_Univ4Se} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol";

/// @notice The same funded bond/SY behavior backed by two actual V4 full-range position vaults.
contract OrbitalV4PositionFundedBindingTest is TestBase_UniswapV4Detf_Orbital_Univ4Se, V4FundedBindingBehavior, DETFFundedStakingArtifacts {
    function setUp() public override {
        super.setUp();
        _activatePositionVault(se0, sePoolKey0);
        _activatePositionVault(se1, sePoolKey1);
    }

    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args_) {
        args_ = super._defaultDetfArgs();
        args_.ownerOnlyLiquidity = false;
    }

    function _activatePositionVault(address vault_, PoolKey memory key_) private {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = Currency.unwrap(key_.currency0);
        tokens_[1] = Currency.unwrap(key_.currency1);
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            amounts_[i_] = 1_000 ether;
            SimpleMintableERC20(tokens_[i_]).mint(address(this), amounts_[i_]);
            IERC20(tokens_[i_]).approve(vault_, amounts_[i_]);
        }
        uint256 shares_ = IStandardExchangeInMulti(vault_).exchangeInManyToOne(
            tokens_, amounts_, IERC20(vault_), 1, address(this), false, block.timestamp
        );
        assertGt(shares_, 0, "both funded tokens activate the position vault");
    }

    function _hookPackage() internal view override returns (address) { return address(orbitalHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return mintToken; }

    function test_bindingPositionShareInputsRedeemThroughEveryNativeSyOutput() public {
        _purchase(1_000 ether);
        IStandardizedYield sy_ = IStandardizedYield(detfInfo.hook());
        address[] memory outputs_ = sy_.getTokensOut();
        for (uint256 i_; i_ < 2; ++i_) {
            IERC20 input_ = IERC20(i_ == 0 ? se0 : se1);
            uint256 amount_ = input_.balanceOf(address(this)) / 1_000;
            assertGt(amount_, 0);
            for (uint256 j_; j_ < outputs_.length; ++j_) {
                uint256 snapshot_ = vm.snapshotState();
                input_.transfer(detfUser, amount_);
                _positionShareSyRoundTrip(sy_, input_, amount_, IERC20(outputs_[j_]));
                assertTrue(vm.revertToStateAndDelete(snapshot_));
            }
        }
    }

    function _positionShareSyRoundTrip(IStandardizedYield sy_, IERC20 in_, uint256 amount_, IERC20 out_) private {
        uint256 detfSupply_ = IERC20(detf).totalSupply();
        uint256 stakingFunding_ = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());
        uint256 quote_ = sy_.previewDeposit(address(in_), amount_);
        assertGt(quote_, 0);
        uint256 payment_ = in_.balanceOf(detfUser);
        vm.startPrank(detfUser);
        in_.approve(address(sy_), amount_);
        uint256 shares_ = sy_.deposit(detfUser, address(in_), amount_, quote_);
        vm.stopPrank();
        assertEq(shares_, quote_, "V4 position-share deposit preview matches execution");
        assertEq(in_.balanceOf(detfUser), payment_ - amount_);
        quote_ = sy_.previewRedeem(address(out_), shares_);
        assertGt(quote_, 0);
        uint256 balance_ = out_.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = sy_.redeem(detfUser, shares_, address(out_), quote_, false);
        assertEq(paid_, quote_, "V4 position-backed exit preview matches execution");
        assertEq(out_.balanceOf(detfUser), balance_ + paid_);
        assertEq(sy_.balanceOf(detfUser), 0);
        assertEq(IERC20(detf).totalSupply(), detfSupply_);
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()), stakingFunding_);
    }
}
'''
p.write_text(s)
print('Applied shared funded binding and ten native SY route combinations over real V4 SE positions.')
