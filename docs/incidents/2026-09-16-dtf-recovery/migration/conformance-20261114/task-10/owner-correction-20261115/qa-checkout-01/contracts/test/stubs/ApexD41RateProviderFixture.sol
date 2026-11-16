// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @dev Non-SUT programmable IRateProvider / ERC-165 probe for D41 staticcall tests.
contract ApexD41RateProviderFixture {
    enum ProbeKind {
        Revert,
        Empty,
        Short,
        Overlong,
        DecodeTrue,
        DecodeFalse
    }

    enum RateKind {
        Value,
        Revert,
        Empty,
        Short,
        Overlong,
        Zero
    }

    ProbeKind public probeKind = ProbeKind.DecodeFalse;
    RateKind public getRateKind = RateKind.Value;
    RateKind public quoteRateKind = RateKind.Value;
    uint256 public getRateValue = 1e18;
    uint256 public quoteRateValue = 2e18;

    function setProbe(ProbeKind k) external {
        probeKind = k;
    }

    function setGetRate(RateKind k, uint256 v) external {
        getRateKind = k;
        getRateValue = v;
    }

    function setQuoteRate(RateKind k, uint256 v) external {
        quoteRateKind = k;
        quoteRateValue = v;
    }

    function supportsInterface(bytes4) external view {
        _probe();
    }

    function getRate() external view {
        _rate(getRateKind, getRateValue);
    }

    function quoteRate(address, address, bytes calldata) external view {
        _rate(quoteRateKind, quoteRateValue);
    }

    function _probe() internal view {
        ProbeKind k = probeKind;
        if (k == ProbeKind.Revert) revert("probe");
        if (k == ProbeKind.Empty) {
            assembly {
                return(0, 0)
            }
        }
        if (k == ProbeKind.Short) {
            assembly {
                mstore(0, 1)
                return(0, 16)
            }
        }
        if (k == ProbeKind.Overlong) {
            assembly {
                mstore(0, 1)
                mstore(32, 1)
                return(0, 64)
            }
        }
        uint256 word = k == ProbeKind.DecodeTrue ? 1 : 0;
        assembly {
            mstore(0, word)
            return(0, 32)
        }
    }

    function _rate(RateKind k, uint256 v) internal pure {
        if (k == RateKind.Revert) revert("rate");
        if (k == RateKind.Empty) {
            assembly {
                return(0, 0)
            }
        }
        if (k == RateKind.Short) {
            assembly {
                mstore(0, 1)
                return(0, 16)
            }
        }
        if (k == RateKind.Overlong) {
            assembly {
                mstore(0, v)
                mstore(32, 1)
                return(0, 64)
            }
        }
        uint256 word = k == RateKind.Zero ? 0 : v;
        assembly {
            mstore(0, word)
            return(0, 32)
        }
    }
}
