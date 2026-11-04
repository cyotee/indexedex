// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";

contract WeirVaults_ForkParityTest is Test {
    address internal constant REFERENCE = 0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110;
    bytes32 internal constant PIN_HEADER_HASH = 0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d;

    error ForkPreflightBlocked(string reason);

    function setUp() public {
        string memory url;
        try vm.rpcUrl("robinhood_mainnet_alchemy") returns (string memory resolved) {
            url = resolved;
        } catch Error(string memory reason) {
            revert ForkPreflightBlocked(string.concat("rpcUrl robinhood_mainnet_alchemy: ", reason));
        } catch (bytes memory) {
            revert ForkPreflightBlocked("rpcUrl robinhood_mainnet_alchemy reverted without a string");
        }
        vm.createSelectFork(url, ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK);
        // The selected fork is the pin: the runner block, pin header, and reference code match.
        // NUMBER stays at a stale env block, so roll it to the pin before the equality check.
        if (block.number != ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK) vm.roll(ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK);
        if (block.chainid != 4663 || block.number != ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK) {
            revert ForkPreflightBlocked("pin chain or block mismatch");
        }
        if (keccak256(vm.getRawBlockHeader(ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK)) != PIN_HEADER_HASH) {
            revert ForkPreflightBlocked("pin header hash mismatch");
        }
        if (REFERENCE.code.length == 0 || ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER.code.length == 0) {
            revert ForkPreflightBlocked("reference or manager code empty");
        }
        if (address(WeirVaults(payable(REFERENCE)).poolManager()) != ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER) {
            revert ForkPreflightBlocked("reference poolManager mismatch");
        }
    }

    function test_AC65_forkPreflight() public view {
        assertEq(block.chainid, 4663);
        assertEq(block.number, ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK);
        assertEq(keccak256(vm.getRawBlockHeader(ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK)), PIN_HEADER_HASH);
        assertGt(REFERENCE.code.length, 0);
        assertEq(address(WeirVaults(payable(REFERENCE)).poolManager()), ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER);
    }
}
