// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ResearchTelemetry} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title ResearchFixture_UniV4CpDetf
 * @notice Hermetic research world: Uni V4 Single SE CP Buffer DETF (hook + ERC-4626 SE).
 * @dev Call `bootstrapResearch()` on a deployed instance (setUp empty for scripts).
 */
contract ResearchFixture_UniV4CpDetf is TestBase_UniswapV4SingleStandardExchangeDETF {
    ResearchTelemetry.RunPaths public runPaths;
    uint256 public step;
    bool public telemetryReady;

    uint256 public lastPreviewOut;
    uint256 public lastExecOut;
    uint256 public lastUserBondId;

    /// @dev Silence Foundry auto-setUp for script `new` pattern.
    function setUp() public virtual override {
        // intentionally empty — use bootstrapResearch()
    }

    function bootstrapResearch() public {
        TestBase_UniswapV4SingleStandardExchangeDETF.setUp();
    }

    function researchUser() public view returns (address) {
        return detfUser;
    }

    function detfAddress() public view returns (address) {
        return detf;
    }

    function detfInfoView() public view returns (IUniswapV4SingleStandardExchangeDETF) {
        return detfInfo;
    }

    function detfExchangeInView() public view returns (IStandardExchangeIn) {
        return detfExchangeIn;
    }

    function pairTokenAddress() public view returns (address) {
        return address(pairToken);
    }

    function firstBondPublic(uint256 pairAmount_) public returns (uint256 tokenId, uint256 shares) {
        (tokenId, shares) = _firstBond(pairAmount_);
        lastUserBondId = tokenId;
    }

    function mintPairPublic(uint256 pairAmount_) public returns (uint256 userDetf) {
        // preview via exchange path if available — sample stores lastExec
        userDetf = _mintPair(pairAmount_);
        lastExecOut = userDetf;
        lastPreviewOut = userDetf; // closed-form path should match; dedicated D3 refines preview call
    }

    function burnToPairPublic(uint256 detfAmount_) public returns (uint256 pairOut) {
        pairOut = _burnToPair(detfAmount_);
        lastExecOut = pairOut;
    }

    function initTelemetry(string memory runId_) public {
        runPaths = ResearchTelemetry.initRun("uniswapV4/detf/standardExchangeCpSingle", runId_);
        step = 0;
        telemetryReady = true;
        ResearchTelemetry.writeMeta(
            runPaths,
            string.concat(
                '{"campaign":"uniswapV4/detf/standardExchangeCpSingle","runId":"',
                runId_,
                '","product":"uniV4SingleSeCpDetf","reserveHost":"seBufferCpHook","se":"erc4626Wrapper"}'
            )
        );
    }

    function sampleDetf(string memory tag_) public {
        require(telemetryReady, "telemetry not ready");
        ResearchTelemetry.appendLine(runPaths, _sampleJson(tag_));
        unchecked {
            ++step;
        }
    }

    function _sampleJson(string memory tag_) internal view returns (string memory) {
        bool live = detfInfo.isReserveLive();
        uint256 synth = 0;
        uint256 mintTh = 0;
        uint256 burnTh = 0;
        bool mintOk = false;
        bool burnOk = false;
        // Views may revert if inert-path incomplete — use try/static via low-level
        try detfInfo.syntheticPrice() returns (uint256 s) {
            synth = s;
        } catch {}
        try detfInfo.mintThreshold() returns (uint256 m) {
            mintTh = m;
        } catch {}
        try detfInfo.burnThreshold() returns (uint256 b) {
            burnTh = b;
        } catch {}
        try detfInfo.isMintingAllowed() returns (bool m) {
            mintOk = m;
        } catch {}
        try detfInfo.isBurningAllowed() returns (bool b) {
            burnOk = b;
        } catch {}

        uint256 supply = IERC20(detf).totalSupply();
        uint256 userDetfBal = IERC20(detf).balanceOf(detfUser);

        return string.concat(
            "{",
            '"step":',
            ResearchTelemetry.u(step),
            ',"tag":"',
            tag_,
            '","isReserveLive":',
            live ? "true" : "false",
            ',"syntheticPrice":',
            ResearchTelemetry.u(synth),
            ',"mintThreshold":',
            ResearchTelemetry.u(mintTh),
            ',"burnThreshold":',
            ResearchTelemetry.u(burnTh),
            ',"isMintingAllowed":',
            mintOk ? "true" : "false",
            ',"isBurningAllowed":',
            burnOk ? "true" : "false",
            ',"totalSupply":',
            ResearchTelemetry.u(supply),
            ',"userDetf":',
            ResearchTelemetry.u(userDetfBal),
            ',"lastPreviewOut":',
            ResearchTelemetry.u(lastPreviewOut),
            ',"lastExecOut":',
            ResearchTelemetry.u(lastExecOut),
            ',"lastUserBondId":',
            ResearchTelemetry.u(lastUserBondId),
            "}"
        );
    }
}
