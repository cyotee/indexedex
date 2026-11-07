// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookClaimQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {HookExactNetComponentAccountingBehavior} from "../../HookComponentAccountingBehavior.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../../SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow
} from "./UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Component behavior adapter using a registry-deployed hook and real FullSpread leg.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_ComponentAccounting is
    FullSpreadRow,
    HookExactNetComponentAccountingBehavior
{
    /// @notice Every installed single-input facade pays for its basket before minting.
    function test_fullSpread_singleInputFacades_payForBasketAndAgree() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(hook, _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        uint256[] memory funded_ = _hbFundShares(HB_BOB, 10 ether);
        address[3] memory inputs_ = [raw, face, seUT];
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            address input_ = inputs_[i_];
            uint256 amount_ = i_ == 2 ? funded_[0] : 1 ether;
            uint256 quote_ = single.previewDepositSingle(input_, amount_);
            assertGt(quote_, 0, "paid single-leg preparation supports positive LP");
            assertEq(single.previewJoinSingleAssetExactIn(input_, amount_), quote_);
            (uint256 sePreview_,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(input_), amount_, IERC20(hook));
            assertEq(sePreview_, quote_);
            assertEq(IStandardizedYield(hook).previewDeposit(input_, amount_), quote_);
            bytes[] memory calls_ = new bytes[](3);
            calls_[0] = abi.encodeWithSignature(
                "joinSingleAssetExactIn(address,uint256,address,uint256,uint256)", input_, amount_, HB_BOB, quote_, block.timestamp
            );
            calls_[1] = abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
                input_, amount_, hook, quote_, HB_BOB, false, block.timestamp
            );
            calls_[2] = abi.encodeWithSignature("deposit(address,address,uint256,uint256)", HB_BOB, input_, amount_, quote_);
            bytes32 canonical_;
            for (uint256 j_; j_ < calls_.length; ++j_) {
                uint256 checkpoint_ = vm.snapshotState();
                ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
                uint256 inputBefore_ = IERC20(input_).balanceOf(HB_BOB);
                vm.prank(HB_BOB);
                (bool ok_, bytes memory result_) = hook.call(calls_[j_]);
                if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
                uint256 net_ = abi.decode(result_, (uint256));
                assertEq(net_, quote_);
                uint256 spent_ = inputBefore_ - IERC20(input_).balanceOf(HB_BOB);
                assertGt(spent_, 0);
                assertLe(spent_, amount_, "preparation respects caller input budget");
                _hbAssertFee(before_, _hbSnapshot(HB_BOB), net_);
                if (j_ == 0) canonical_ = _hbCompleteState(HB_BOB);
                else assertEq(_hbCompleteState(HB_BOB), canonical_, "aliases produce identical final books and custody");
                assertTrue(vm.revertToStateAndDelete(checkpoint_));
            }
        }
        assertGt(IUniswapV4SeBufferHookClaimQuote(hook).previewClaimAfterJoin(1 ether, 1 ether), 0,
            "claim-after-join includes the paid preparation");
    }

    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](2);
        pairs_[0] = face;
        pairs_[1] = raw;
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](2);
        exchanges_[0] = seUT;
    }

    function _hbSetFee(uint256 fee_) internal override {
        if (fee_ == 0) {
            // Zero clears the vault override; clear the fixture's global fallback too.
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        }
        _enableProtocolFee(fee_);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(hook),
            fee_, "configured hook LP fee");
    }
    function _hbFeeRecipient() internal view override returns (address) { return _feeTo(); }

    function _hbFundShares(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](2);
        amounts_[0] = SeMatrix_FullSpreadV4Fixture(address(fx)).acquireShares(seUT, face, actor_, budget_);
        amounts_[1] = budget_;
        rawToken.mint(actor_, budget_);
        vm.startPrank(actor_);
        IERC20(seUT).approve(hook, type(uint256).max);
        IERC20(raw).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _hbFundPairs(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](2);
        amounts_[0] = budget_;
        amounts_[1] = budget_;
        fx.fund(actor_, budget_);
        rawToken.mint(actor_, budget_);
        vm.startPrank(actor_);
        IERC20(face).approve(hook, type(uint256).max);
        IERC20(raw).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _hbJoinShares(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        vm.prank(actor_);
        (net_,,) = single.depositWithSeShares(amounts_[1], amounts_[0], actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        (uint256 a0_, uint256 a1_) = _ordered(amounts_[0], amounts_[1]);
        vm.prank(actor_);
        (net_,,) = single.deposit(a0_, a1_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        vm.prank(actor_);
        single.withdraw(burned_, actor_, 1, 1, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        SeMatrix_FullSpreadV4Fixture(address(fx)).acquireShares(seUT, face, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) {
        return IRateProvider(single.rateProvider(face)).getRate();
    }

    function _hbMinimumError() internal pure override returns (bytes4) {
        return bytes4(keccak256("InsufficientLpOut()"));
    }

    function _hbInitialPairError() internal pure override returns (bytes4) {
        return bytes4(keccak256("InvalidRoute()"));
    }

    function _hbExactNetRequest() internal view override returns (uint256 net_, uint256 maximum_) {
        maximum_ = 1 ether;
        net_ = single.previewDepositSingle(raw, maximum_);
    }

    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal override returns (uint256) {
        vm.prank(actor_);
        return IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(raw, net_, actor_, maximum_, block.timestamp);
    }

    function _hbDisable(bool byPackage_, bool disabled_) internal override {
        address package_ = SeMatrix_FullSpreadV4Fixture(address(fx)).pkg();
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(package_, disabled_);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, disabled_);
    }

    function _hbTrade(address actor_, uint256 inputIndex_, uint256 outputIndex_, uint256 amount_)
        internal override returns (uint256 output_)
    {
        address[] memory pairs_ = _hbPairs();
        vm.prank(actor_);
        (output_,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(pairs_[inputIndex_]), amount_, IERC20(pairs_[outputIndex_]), 1, actor_, false, block.timestamp
        );
    }
}
