// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

/// @title TestBase_StandardExchange_Adversarial
/// @notice Abstract SE adversarial cases — wire vault + tokens in protocol instances (Wave 2B).
abstract contract TestBase_StandardExchange_Adversarial {
    function seVaultUnderTest() internal view virtual returns (IStandardExchangeProxy);
    function seTokenA() internal view virtual returns (IERC20);
    function seTokenB() internal view virtual returns (IERC20);
    function seFundTokenA(address to, uint256 amount) internal virtual;
    function seDeadline() internal view virtual returns (uint256);

    address internal seAttacker;
    address internal seVictim;

    function _seInitActors() internal {
        // makeAddr requires Test inheritance — call from child setUp after super
    }
}
