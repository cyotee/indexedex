// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @dev Non-SUT quote dependency for D48 staticcall tests. Not an SE SUT mock.
contract ApexD48QuoteReplyFixture {
    error QuoteBoom();

    enum Reply {
        Ok32,
        RevertCustom,
        RevertString,
        Panic,
        EmptyRevert,
        OkEmpty,
        OkShort,
        OkOverlong
    }

    Reply public reply = Reply.Ok32;
    uint256 public okValue = 1e18;
    uint256 public failAbove;
    uint256 public totalSupply_ = 1e18;
    uint8 public decimals_ = 18;

    function setReply(Reply r, uint256 okValue_) external {
        reply = r;
        okValue = okValue_;
    }

    function setFailAbove(uint256 v) external {
        failAbove = v;
    }

    function setSupply(uint256 s, uint8 d) external {
        totalSupply_ = s;
        decimals_ = d;
    }

    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function previewExchangeIn(address, uint256 amount, address) external view returns (uint256) {
        return _emit(amount);
    }

    function quoteAssets(bytes calldata, uint256 shares) external view returns (uint256) {
        return _emit(shares);
    }

    function quoteTotalSupply(bytes calldata) external view returns (uint256) {
        return totalSupply_;
    }

    function _emit(uint256 amount) internal view returns (uint256) {
        if (failAbove != 0 && amount > failAbove) {
            revert QuoteBoom();
        }
        Reply r = reply;
        if (r == Reply.RevertCustom) revert QuoteBoom();
        if (r == Reply.RevertString) revert("quote fail");
        if (r == Reply.Panic) {
            assert(false);
        }
        if (r == Reply.EmptyRevert) {
            assembly {
                revert(0, 0)
            }
        }
        if (r == Reply.OkEmpty) {
            assembly {
                return(0, 0)
            }
        }
        if (r == Reply.OkShort) {
            assembly {
                mstore(0, 1)
                return(0, 16)
            }
        }
        if (r == Reply.OkOverlong) {
            uint256 v = okValue;
            assembly {
                mstore(0, v)
                mstore(32, 1)
                return(0, 64)
            }
        }
        return okValue;
    }
}
