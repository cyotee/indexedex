// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {PairTokenTestBase} from "test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol";
import {PairToken} from "contracts/pairtoken-baseline/PairToken.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Reuses the unchanged scripted characterization fixture with a fresh real PairToken.
/// @dev The 10,000-unit scenario uses independent integer receipts: add costs
/// 10,000 each; retained-share removal 8,991 returns 8,990 principal each at P=1.
contract PairTokenBaselineComparisonFixture is PairTokenTestBase {
    function subject() external view returns (PairToken) { return pair; }

    function bootstrapTenThousand() external returns (uint256) {
        manager.queueModify(_delta(-10000, -10000), 0);
        return _bootstrap(10000);
    }

    function redeemHolder() external returns (uint256, uint256) {
        require(pair.balanceOf(address(this)) == 9000, "scenario shares");
        manager.queueModify(0, 0);
        manager.queueModify(_delta(8990, 8990), 0);
        return pair.redeem(9000, 0, 0, address(this));
    }

    function unsolicitedToken0(uint256 amount_) external {
        currency0.mint(address(pair), amount_);
    }
}

/// @notice Preserved behavior and intentional deviations are separate assertions.
/// @dev Scripted baseline evidence is not used as a replacement for real-manager SE acceptance.
// tag::UniswapV4PairTokenStandardExchangeVaultBaselineComparisonTest[]
contract UniswapV4PairTokenStandardExchangeVaultBaselineComparisonTest is
    TestBase_UniswapV4PairTokenStandardExchangeVault
{
    PairTokenBaselineComparisonFixture private baseline;

    function setUp() public override {
        super.setUp();
        baseline = new PairTokenBaselineComparisonFixture();
        baseline.setUp();
    }

    function test_BASE_PreservedGeometricQuoteAndFullRange() public {
        PairToken old_ = baseline.subject();
        (uint256 oldQuote_, uint256 old0_, uint256 old1_) = old_.previewDeposit(10000, 10000);
        (uint256 quote_, uint256 used0_, uint256 used1_) = vault.previewDepositPair(10000, 10000);
        assertEq(oldQuote_, 10000);
        assertEq(quote_, oldQuote_);
        assertEq(used0_, old0_);
        assertEq(used1_, old1_);
        assertEq(vault.tickLower(), old_.tickLower());
        assertEq(vault.tickUpper(), old_.tickUpper());
        assertEq(baseline.bootstrapTenThousand(), 9000);
        assertEq(_bootstrap(10000, 10000, address(this)), 10000);
        assertEq(old_.positionLiquidity(), 10000);
        assertEq(vault.positionLiquidity(), old_.positionLiquidity());
        (uint256 oldBasket0_, uint256 oldBasket1_) = old_.basket();
        (uint256 basket0_, uint256 basket1_) = vault.basket();
        assertEq(oldBasket0_, 9999);
        assertEq(oldBasket1_, 9999);
        assertEq(basket0_, oldBasket0_);
        assertEq(basket1_, oldBasket1_);
    }

    function test_BASE_IntentionalDeadRetentionAndTerminalDeviations() public {
        PairToken old_ = baseline.subject();
        baseline.bootstrapTenThousand();
        _bootstrap(10000, 10000, address(this));
        assertEq(old_.balanceOf(old_.DEAD()), 1000);
        assertEq(IERC20(address(vault)).balanceOf(old_.DEAD()), 0);
        (uint256 old0_, uint256 old1_) = baseline.redeemHolder();
        (uint256 amount0_, uint256 amount1_) = vault.redeemPair(10000, 0, 0, address(this), block.timestamp);
        assertEq(old0_, 8990);
        assertEq(old1_, 8990);
        assertEq(amount0_, 9999);
        assertEq(amount1_, 9999);
        assertEq(old_.totalSupply(), 1000);
        assertEq(old_.positionLiquidity(), 1009);
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        (amount0_, amount1_) = vault.localReserves();
        assertEq(amount0_, 0);
        assertEq(amount1_, 0);
        assertEq(_bootstrap(10000, 10000, address(this)), 10000);
    }

    function test_BASE_UnbookedPolicyDeviationAndNewSYCapability() public {
        PairToken old_ = baseline.subject();
        baseline.bootstrapTenThousand();
        _bootstrap(10000, 10000, address(this));
        baseline.unsolicitedToken0(777);
        token0.mint(address(vault), 777);
        (uint256 old0_,) = old_.basket();
        (uint256 current0_,) = vault.basket();
        assertEq(old0_, 9999 + 777);
        assertEq(current0_, 9999);
        (uint256 book0_,) = vault.localReserves();
        assertEq(book0_, 0);
        assertEq(IStandardizedYield(address(vault)).exchangeRate(), 19998 * uint256(1e18) / 10000);
        (bool supported_,) = address(old_).staticcall(abi.encodeCall(IStandardizedYield.exchangeRate, ()));
        assertFalse(supported_);
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultBaselineComparisonTest[]
