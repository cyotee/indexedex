"""Extend the real cross-version registry fixture after the active Forge run exits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
path = Path('test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopE2E.t.sol')
suite_path = Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol')
record = artifacts / 'aave-sy-regression-sources.json'
assert not record.exists(), 'Already applied; preserve the original test provenance.'
before = (root / path).read_text()
imports = '''
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AaveCrossVersionLoopExchangeInFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInFacet.sol";
import {AaveCrossVersionLoopExchangeOutFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutFacet.sol";
import {AaveCrossVersionLoopRebalanceFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceFacet.sol";
import {AaveCrossVersionLoopMarkerFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopMarkerFacet.sol";
'''
tests = '''
    function _fundedSY() private returns (IStandardizedYield sy_) {
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
        uint256 payment_ = 20 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, payment_, IERC20(vault), 0, address(this), false, block.timestamp
        );
        return IStandardizedYield(vault);
    }

    function test_nativeSY_metadataUsesExistingNavUnitAndShareLedger() public {
        IStandardizedYield sy_ = _fundedSY();
        assertEq(sy_.decimals(), 18, "existing share decimals");
        assertEq(sy_.yieldToken(), address(0), "no ERC20 underlying leveraged position");
        (IStandardizedYield.AssetType kind_, address asset_, uint8 precision_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(asset_, vault);
        assertEq(precision_, 8, "retained oracle-base USD accounting precision");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardizedYield).interfaceId));
        assertEq(sy_.getTokensIn().length, 1);
        assertEq(sy_.getTokensIn()[0], address(tokenA));
        assertEq(sy_.getTokensOut()[0], address(tokenA));
        assertFalse(sy_.isValidTokenIn(address(tokenB)));
        assertFalse(sy_.isValidTokenOut(address(tokenB)));
        assertEq(sy_.exchangeRate(), _actualNav() * 1e18 / IERC20(vault).totalSupply());
        assertEq(sy_.getRewardTokens().length, 0);
        assertEq(sy_.accruedRewards(address(this)).length, 0);
        assertEq(sy_.rewardIndexesCurrent().length, 0);
        assertEq(sy_.rewardIndexesStored().length, 0);
        assertEq(sy_.claimRewards(address(this)).length, 0);
    }

    function test_nativeSY_depositAndRedeemUseStandardNavAndNeverBorrowForExit() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        uint256 quote_ = sy_.previewDeposit(address(tokenA), payment_);
        assertEq(quote_, IStandardExchangeIn(vault).previewExchangeIn(tokenA, payment_, IERC20(vault)));
        uint256 before_ = sy_.balanceOf(address(this));
        assertEq(sy_.deposit(address(this), address(tokenA), payment_, quote_), quote_);
        assertEq(sy_.balanceOf(address(this)), before_ + quote_);
        _assertSyExit(sy_, quote_ / 4, false);
    }

    function test_nativeSY_internalBalanceBurnsOnlyRequestedActualShares() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 transferred_ = sy_.balanceOf(address(this)) / 20;
        sy_.transfer(vault, transferred_);
        uint256 userShares_ = sy_.balanceOf(address(this));
        _assertSyExit(sy_, transferred_ / 2, true);
        assertEq(sy_.balanceOf(vault), transferred_ - transferred_ / 2);
        assertEq(sy_.balanceOf(address(this)), userShares_);
    }

    function test_nativeSY_slippageRevertsPreserveFundsAndPosition() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        uint256 quote_ = sy_.previewDeposit(address(tokenA), payment_);
        uint256 wallet_ = tokenA.balanceOf(address(this));
        uint256 supply_ = sy_.totalSupply();
        uint256 nav_ = _actualNav();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, quote_ + 1, quote_));
        sy_.deposit(address(this), address(tokenA), payment_, quote_ + 1);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(sy_.totalSupply(), supply_);
        assertEq(_actualNav(), nav_);
        uint256 shares_ = sy_.balanceOf(address(this)) / 100;
        uint256 output_ = sy_.previewRedeem(address(tokenA), shares_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, output_ + 1, output_));
        sy_.redeem(address(this), shares_, address(tokenA), output_ + 1, false);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(sy_.totalSupply(), supply_);
        assertEq(_actualNav(), nav_);
    }

    function test_exactOutput_positiveSubOracleAmountConsumesShares() public {
        _fundedSY();
        uint256 input_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, 1);
        assertGt(input_, 0, "positive token withdrawal must cost shares");
        uint256 supply_ = IERC20(vault).totalSupply();
        uint256 wallet_ = tokenA.balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, input_ - 1, input_));
        IStandardExchangeOut(vault).exchangeOut(IERC20(vault), input_ - 1, tokenA, 1, address(this), false, block.timestamp);
        assertEq(IERC20(vault).totalSupply(), supply_);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), input_, tokenA, 1, address(this), false, block.timestamp), input_);
        assertEq(IERC20(vault).totalSupply(), supply_ - input_);
        assertEq(tokenA.balanceOf(address(this)), wallet_ + 1);
    }

    function test_nativeSY_unfreeableExitRevertsWithoutNewBorrowing() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 shares_ = sy_.balanceOf(address(this));
        uint256 debtV3_ = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        uint256 debtV4_ = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
        sy_.previewRedeem(address(tokenA), shares_);
        vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
        sy_.redeem(address(this), shares_, address(tokenA), 0, false);
        assertEq(sy_.balanceOf(address(this)), shares_);
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), debtV3_);
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), debtV4_);
    }

    function test_pretransferredInventoryCannotFundPublicDepositOrWithdrawal() public {
        _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, vault, payment_);
        uint256 shares_ = IERC20(vault).balanceOf(address(this)) / 100;
        IERC20(vault).transfer(vault, shares_);
        uint256 supply_ = IERC20(vault).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, payment_, 0));
        IStandardExchangeIn(vault).exchangeIn(tokenA, payment_, IERC20(vault), 0, address(this), true, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares_, 0));
        IStandardExchangeIn(vault).exchangeIn(IERC20(vault), shares_, tokenA, 0, address(this), true, block.timestamp);
        assertEq(tokenA.balanceOf(vault), payment_);
        assertEq(IERC20(vault).balanceOf(vault), shares_);
        assertEq(IERC20(vault).totalSupply(), supply_);
    }

    function _assertSyExit(IStandardizedYield sy_, uint256 shares_, bool internal_) private {
        uint256 output_ = sy_.previewRedeem(address(tokenA), shares_);
        assertGt(output_, 0);
        assertEq(output_, IStandardExchangeIn(vault).previewExchangeIn(IERC20(vault), shares_, tokenA));
        uint256 v3Debt_ = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        uint256 v4Debt_ = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        uint256 wallet_ = tokenA.balanceOf(address(this));
        uint256 supply_ = sy_.totalSupply();
        assertEq(sy_.redeem(address(this), shares_, address(tokenA), output_, internal_), output_);
        assertEq(tokenA.balanceOf(address(this)), wallet_ + output_);
        assertEq(sy_.totalSupply(), supply_ - shares_);
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), v3Debt_, "exit must not borrow on V3");
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), v4Debt_, "exit must not borrow on V4");
    }

    function _actualNav() private view returns (uint256) {
        return _netTokenUsd(tokenA, v4ReserveIdA) + _netTokenUsd(tokenB, v4ReserveIdB);
    }

    function _netTokenUsd(IERC20 token_, uint256 reserve_) private view returns (uint256) {
        uint256 assets_ = AaveV36Service.suppliedOf(v36Pool, address(token_), vault)
            + AaveV4Service.suppliedOf(v4Spoke, reserve_, vault);
        uint256 debts_ = AaveV36Service.debtOf(v36Pool, address(token_), vault)
            + AaveV4Service.debtOf(v4Spoke, reserve_, vault);
        if (assets_ <= debts_) return 0;
        return (assets_ - debts_) * IAaveOracle(v36Oracle).getAssetPrice(address(token_))
            / 10 ** IERC20Metadata(address(token_)).decimals();
    }
'''
anchor = '\n}\n\n/// @dev Minimal marker view'
assert before.count(anchor) == 1
updated = before.replace('pragma solidity ^0.8.0;', 'pragma solidity ^0.8.0;\n' + imports, 1)
updated = updated.replace(anchor, tests + anchor, 1)
suite = (root / suite_path).read_text()
addition = '\nimport "' + str(path) + '";\n'
assert str(path) not in suite
(root / path).write_text(updated)
(root / suite_path).write_text(suite + addition)
def sha(value):
    return hashlib.sha256(value.encode()).hexdigest()
record.write_text(json.dumps({'status': 'applied; build and tests pending',
    'source': str(path), 'before_sha256': sha(before), 'after_sha256': sha(updated),
    'suite_before_sha256': sha(suite), 'suite_after_sha256': sha(suite + addition),
    'scope': 'Seven assertions added to the existing actual V3/V4 market and registry E2E fixture; no production mutation.'}, indent=2) + '\n')
print('Extended the canonical cross-version E2E test; validation pending.')
