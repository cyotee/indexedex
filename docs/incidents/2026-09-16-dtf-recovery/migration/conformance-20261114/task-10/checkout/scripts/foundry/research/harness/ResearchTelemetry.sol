// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";

/**
 * @title ResearchTelemetry
 * @notice Append-only JSONL writer for IndexedEx research scripts.
 * @dev Research harness only — not production.
 */
library ResearchTelemetry {
    Vm internal constant vm = Vm(VM_ADDRESS);

    struct RunPaths {
        string dir;
        string seriesPath;
        string metaPath;
    }

    function initRun(string memory product_, string memory runId_) internal returns (RunPaths memory paths_) {
        paths_.dir = string.concat("research/out/", product_, "/", runId_);
        paths_.seriesPath = string.concat(paths_.dir, "/series.jsonl");
        paths_.metaPath = string.concat(paths_.dir, "/meta.json");
        vm.createDir(paths_.dir, true);
        vm.writeFile(paths_.seriesPath, "");
    }

    function writeMeta(RunPaths memory paths_, string memory metaJson_) internal {
        vm.writeFile(paths_.metaPath, metaJson_);
    }

    function appendLine(RunPaths memory paths_, string memory line_) internal {
        vm.writeLine(paths_.seriesPath, line_);
    }

    function u(uint256 v) internal pure returns (string memory) {
        return vm.toString(v);
    }

    function a(address v) internal pure returns (string memory) {
        return vm.toString(v);
    }
}
