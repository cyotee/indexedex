// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FeeAccrualStageBase} from "./FeeAccrualStageBase.sol";
import {Phase_07_Stage_02_FeeAccrualCustodySe as Custody} from "./Phase_07_Stage_02_FeeAccrualCustodySe.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

contract Phase_07_Stage_02_FeeAccrualCustodySe is FeeAccrualStageBase {
    function run() external {
        _startFee("Phase 07 Stage 02: Fee accrual DTF custody");
        uint256 offset = vm.parseJsonUint(feeConfig, ".custody.decimalOffset");
        require(offset <= 18, "Custody: invalid offset");
        IDiamondPackageCallBackFactory factory = IDiamondPackageCallBackFactory(_configAddress(".diamondPackageFactory"));
        IRebasingAwareERC4626DFPkg pkg = IRebasingAwareERC4626DFPkg(_configAddress(".packages.rebasingAwareErc4626"));
        bytes32 salt = vm.parseJsonBytes32(feeConfig, ".custody.salt");
        _broadcast();
        custodyVault = Custody.execute(manager, factory, pkg, IERC20Metadata(dtf), uint8(offset), salt);
        vm.stopBroadcast();
        _exportProduct(CUSTODY_FILE, "custodyVault", custodyVault);
    }
}
