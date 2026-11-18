// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {StandardExchangeFrozenQuoteLib as Quote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {TestBase_UniswapV4DetfMigrationSnapshot} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";

contract UniswapV4DetfMigrationFrozenDepositTest is TestBase_UniswapV4DetfMigrationSnapshot {
    function test_usageFeeClampAndRecipientRemainFrozen() public {
        IVaultFeeOracleManager manager = IVaultFeeOracleManager(address(indexedexManager));
        address recipient = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        assertNotEq(recipient, address(0));
        vm.prank(owner);
        manager.setFeeTo(IFeeCollectorProxy(address(0)));
        Pricing.InputsV3 memory beforeBook = _observedInputs();
        Frozen.VersionedInputs memory noFee = beforeBook.legs[beforeBook.ethIndex].deposit;
        (uint256 gross, uint256 refund) =
            IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 1 ether, IERC20(se0));
        assertGt(gross, 0);
        ExchangeInAmount.Result memory frozen = Quote.evaluate(noFee, 1 ether);
        assertEq(frozen.amountOut, gross);
        assertEq(frozen.amountRefunded, refund);

        vm.startPrank(owner);
        manager.setFeeTo(IFeeCollectorProxy(recipient));
        manager.setUsageFeeOfVault(se0, 9e17);
        vm.stopPrank();
        (uint256 net, uint256 afterRefund) =
            IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 1 ether, IERC20(se0));
        assertEq(net, gross - FullMath.mulDiv(gross, 3e17, 1e18), "fee deducted at the 30 percent clamp");
        assertEq(afterRefund, refund);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(se0), 9e17, "oracle not clamped in storage");
        assertEq(Quote.evaluate(noFee, 1 ether).amountOut, gross, "captured zero recipient remains effective");

        Pricing.InputsV3 memory feeBook = _observedInputs();
        Frozen.VersionedInputs memory withFee = feeBook.legs[feeBook.ethIndex].deposit;
        frozen = Quote.evaluate(withFee, 1 ether);
        assertEq(frozen.amountOut, net);
        assertEq(frozen.amountRefunded, refund);
        vm.prank(owner);
        manager.setFeeTo(IFeeCollectorProxy(address(0)));
        (uint256 liveWithoutFee,) =
            IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 1 ether, IERC20(se0));
        assertEq(liveWithoutFee, gross);
        assertEq(Quote.evaluate(withFee, 1 ether).amountOut, net, "captured fee recipient is not a live dependency");
    }
}
