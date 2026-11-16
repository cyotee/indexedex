// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_CamelotV2StandardExchange} from
    "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/// @notice RC-02: the production Camelot proxy bounds zap-out burns in share units.
contract CamelotV2ZapOutMaxAmountIn_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal outputToken;
    IStandardExchangeProxy internal vault;
    address internal recipient;

    /// @notice Register the production package before deploying and funding its vault.
    function setUp() public override {
        super.setUp();
        recipient = makeAddr("camelotZapRecipient");
        outputToken = new ERC20PermitMintableStub("Output", "OUT", 18, address(this), 1000 ether);
        ERC20PermitMintableStub other_ =
            new ERC20PermitMintableStub("Other", "OTHER", 18, address(this), 1_000_000 ether);
        outputToken.approve(address(camelotV2StandardExchangeDFPkg), 1000 ether);
        other_.approve(address(camelotV2StandardExchangeDFPkg), 1_000_000 ether);
        // The lower output reserve gives an exactly reachable integer output quote.
        vault = IStandardExchangeProxy(camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(outputToken)), 1000 ether, IERC20(address(other_)), 1_000_000 ether, address(this)
        ));
    }

    /// @notice A holder-funded request above its share maximum burns and pays nothing.
    function test_RC02_zapOut_pull_aboveShareMaximum_preservesBalances() public {
        _assertMaximumRejection(false);
    }

    /// @notice A prepaid request above its share maximum leaves both share holders unchanged.
    function test_RC02_zapOut_pretransferred_aboveShareMaximum_preservesBalances() public {
        _assertMaximumRejection(true);
    }

    /// @notice The exact share ceiling permits a holder-funded zap-out and exact payout.
    function test_RC02_zapOut_pull_atShareMaximum_burnsQuotedSharesAndPaysOutput() public {
        _assertFundedZap(false);
    }

    /// @notice The exact share ceiling permits a prepaid zap-out without burning caller shares.
    function test_RC02_zapOut_pretransferred_atShareMaximum_burnsQuotedSharesAndPaysOutput() public {
        _assertFundedZap(true);
    }

    function _assertMaximumRejection(bool pretransferred_) internal {
        uint256 requested_ = 1 ether;
        uint256 shares_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(address(outputToken)), requested_);
        require(shares_ > 1, "nonzero share quote");
        if (pretransferred_) vault.transfer(address(vault), shares_);
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 supplyBefore_ = vault.totalSupply();
        uint256 outputBefore_ = outputToken.balanceOf(recipient);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, shares_ - 1, shares_));
        vault.exchangeOut(IERC20(address(vault)), shares_ - 1, IERC20(address(outputToken)), requested_,
            recipient, pretransferred_, block.timestamp + 1 hours);
        assertEq(vault.balanceOf(address(this)), callerBefore_, "caller shares unchanged");
        assertEq(vault.balanceOf(address(vault)), vaultBefore_, "vault shares unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "no burn or fee mint survives");
        assertEq(outputToken.balanceOf(recipient), outputBefore_, "no payout");
    }

    function _assertFundedZap(bool pretransferred_) internal {
        uint256 requested_ = 1 ether;
        uint256 shares_ = vault.previewExchangeOut(IERC20(address(vault)), IERC20(address(outputToken)), requested_);
        require(shares_ > 0, "nonzero share quote");
        if (pretransferred_) vault.transfer(address(vault), shares_);
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = outputToken.balanceOf(recipient);
        uint256 used_ = vault.exchangeOut(IERC20(address(vault)), shares_, IERC20(address(outputToken)), requested_,
            recipient, pretransferred_, block.timestamp + 1 hours);
        assertEq(used_, shares_, "returned cost is the quoted shares, not LP units");
        assertEq(vault.balanceOf(address(this)), callerBefore_ - (pretransferred_ ? 0 : shares_));
        assertEq(vault.balanceOf(address(vault)), vaultBefore_ - (pretransferred_ ? shares_ : 0));
        assertEq(outputToken.balanceOf(recipient) - outputBefore_, requested_, "requested output paid");
    }
}
