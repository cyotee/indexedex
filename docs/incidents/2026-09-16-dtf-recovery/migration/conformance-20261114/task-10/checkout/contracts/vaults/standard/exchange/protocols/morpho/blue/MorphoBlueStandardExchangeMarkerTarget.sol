// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMorpho, Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    MorphoBlueStandardExchangeCommon
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol";
import {
    MorphoBlueStandardExchangeRepo
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeRepo.sol";

contract MorphoBlueStandardExchangeMarkerTarget is MorphoBlueStandardExchangeCommon, IMorphoBlueStandardExchange {
    function morpho() public view returns (IMorpho) {
        return _morpho();
    }

    function marketParams() public view returns (MarketParams memory) {
        return MorphoBlueStandardExchangeRepo._marketParams();
    }

    function marketId() public view returns (Id) {
        return MorphoBlueStandardExchangeRepo._marketId();
    }

    function loanToken() public view returns (address) {
        return MorphoBlueStandardExchangeRepo._marketParams().loanToken;
    }
}
