// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_UniswapV3FullSpreadAccountingNFT} from "./TestBase_UniswapV3FullSpreadAccountingNFT.sol";

interface IV3AccountingDelegateAddress {
    function UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE() external view returns (address);
}

/// @notice Cold standalone calls: fixture setup and all cooling occur before gas measurement.
abstract contract TestBase_UniswapV3FullSpreadColdGas is TestBase_UniswapV3FullSpreadAccountingNFT {
    address[] private vaultFacets;
    address[] private managerFacets;
    address private executionDelegate;

    function setUp() public virtual override {
        super.setUp();
        _setFeeRecipient(address(this));
        vaultFacets = IDiamondLoupe(address(vault)).facetAddresses();
        managerFacets = IDiamondLoupe(address(indexedexManager)).facetAddresses();
        address inFacet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        executionDelegate = IV3AccountingDelegateAddress(inFacet_).UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
    }

    function _cold() private {
        vm.cool(address(vault));
        vm.cool(address(pool));
        vm.cool(address(token0));
        vm.cool(address(token1));
        vm.cool(address(indexedexManager));
        vm.cool(address(uniswapV3Factory));
        vm.cool(address(npm));
        vm.cool(executionDelegate);
        for (uint256 i_; i_ < vaultFacets.length; ++i_) vm.cool(vaultFacets[i_]);
        for (uint256 i_; i_ < managerFacets.length; ++i_) vm.cool(managerFacets[i_]);
    }

    function _moneyGas(string memory state_, address caller_, bytes memory call_)
        internal returns (bytes memory result_)
    {
        _cold();
        vm.prank(caller_);
        uint256 before_ = gasleft();
        (bool ok_, bytes memory returned_) = address(vault).call(call_);
        uint256 body_ = before_ - gasleft();
        if (!ok_) assembly ("memory-safe") { revert(add(returned_, 32), mload(returned_)) }
        uint256 intrinsic_ = 21_000;
        for (uint256 i_; i_ < call_.length; ++i_) intrinsic_ += call_[i_] == 0 ? 4 : 16;
        // The measured CALL includes outer CALL/returndata overhead, so adding
        // intrinsic gas is a conservative standalone transaction upper bound.
        uint256 transaction_ = body_ + intrinsic_;
        emit log_named_string("cold state and route", state_);
        emit log_named_uint("cold public body gas", body_);
        emit log_named_uint("standalone transaction upper bound gas", transaction_);
        assertLe(body_, 11_900_000, "cold public body ceiling");
        assertLe(transaction_, 12_000_000, "standalone transaction ceiling");
        _assertSettled();
        return returned_;
    }

    function _previewGas(string memory state_, bytes memory call_) internal returns (bytes memory result_) {
        _cold();
        uint256 before_ = gasleft();
        (bool ok_, bytes memory returned_) = address(vault).staticcall(call_);
        uint256 used_ = before_ - gasleft();
        if (!ok_) assembly ("memory-safe") { revert(add(returned_, 32), mload(returned_)) }
        emit log_named_string("cold preview state and route", state_);
        emit log_named_uint("cold preview gas", used_);
        assertLe(used_, 5_000_000, "cold preview ceiling");
        return returned_;
    }
}
