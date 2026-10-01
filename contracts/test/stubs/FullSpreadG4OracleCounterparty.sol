// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

// tag::FullSpreadG4OracleCounterparty[]
/// @notice Controlled external dependency around a genuine oracle; never replaces vault execution.
contract FullSpreadG4OracleCounterparty {
    error UpdateFault();
    IUniswapV4MultiPoolTwapOracle public immutable oracle;
    address public immutable controller;
    address public poolManager;
    bool public failUpdate;

    constructor(IUniswapV4MultiPoolTwapOracle oracle_, address controller_) {
        oracle = oracle_;
        controller = controller_;
        poolManager = oracle_.poolManager();
    }

    /// @notice Select fault behavior on this external counterparty only.
    function configure(address advertisedManager_, bool fail_) external {
        require(msg.sender == controller, "G4 controller");
        poolManager = advertisedManager_;
        failUpdate = fail_;
    }

    /// @notice Forward the genuine update before faulting, so rollback also covers oracle writes.
    function update(PoolKey calldata key_) external returns (bool written_) {
        written_ = oracle.update(key_);
        if (failUpdate) revert UpdateFault();
    }

    /// @notice Other oracle queries/operations retain the genuine dependency implementation.
    fallback() external {
        (bool ok, bytes memory result) = address(oracle).call(msg.data);
        assembly ("memory-safe") {
            if iszero(ok) { revert(add(result, 32), mload(result)) }
            return(add(result, 32), mload(result))
        }
    }
}
// end::FullSpreadG4OracleCounterparty[]
