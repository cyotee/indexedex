// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {HermeticWETH} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";

/**
 * @title HostileWETH
 * @notice WETH double that reenters a target mid transfer/transferFrom (adversarial harness only).
 */
contract HostileWETH is HermeticWETH {
    address public reentryTarget;
    bytes public reentryCall;
    bool public armed;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    function arm(address target_, bytes calldata data_) external {
        reentryTarget = target_;
        reentryCall = data_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function disarm() external {
        armed = false;
    }

    function _tryReenter() internal {
        if (!armed || reentryTarget == address(0)) return;
        armed = false;
        ++reentryAttempts;
        (bool ok, bytes memory ret) = reentryTarget.call(reentryCall);
        nestedCallSucceeded = ok;
        if (!ok && ret.length >= 4) {
            bytes4 sel;
            assembly {
                sel := mload(add(ret, 0x20))
            }
            nestedErrorSelector = sel;
        }
    }

    function deposit() public payable override {
        if (armed && msg.sender == reentryTarget) {
            _tryReenter();
        }
        super.deposit();
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (armed && to == reentryTarget) {
            _tryReenter();
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        // Reenter when vault pays WETH out to a recipient (armed with vault as target).
        if (armed && msg.sender == reentryTarget) {
            _tryReenter();
        }
        return super.transfer(to, amount);
    }
}
