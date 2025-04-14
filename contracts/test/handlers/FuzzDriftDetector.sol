// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Lightweight helper for fuzz harnesses to detect invariant drift.
/// The detector calls a target view function repeatedly (optionally with
/// small perturbations to the encoded args) and fails if results diverge.
contract FuzzDriftDetector {
    /// Returned when two runs produced different results.
    error DriftDetected(bytes expected, bytes actual);

    /// Call `target`'s view function (`sel` + `args`) `repeats` times and ensure
    /// all results are identical. Reverts with `DriftDetected` on mismatch.
    function detect(address target, bytes4 sel, bytes calldata args, uint8 repeats) public view returns (bytes memory) {
        bytes memory baseline = _callStatic(target, sel, args);
        for (uint8 i = 1; i < repeats; ++i) {
            bytes memory out = _callStatic(target, sel, args);
            if (!_equal(baseline, out)) revert DriftDetected(baseline, out);
        }
        return baseline;
    }

    /// Like `detect` but applies a tiny perturbation to `args` for each run.
    /// Useful to detect cases where tiny input changes cause invariant flips.
    function detectWithPerturbations(address target, bytes4 sel, bytes calldata args, uint8 repeats)
        public
        view
        returns (bytes memory)
    {
        bytes memory baseline = _callStatic(target, sel, args);
        for (uint8 i = 1; i < repeats; ++i) {
            bytes memory pert = _perturb(args, i);
            bytes memory out = _callStatic(target, sel, pert);
            if (!_equal(baseline, out)) revert DriftDetected(baseline, out);
        }
        return baseline;
    }

    function _callStatic(address t, bytes4 sel, bytes memory args) internal view returns (bytes memory) {
        (bool ok, bytes memory out) = t.staticcall(abi.encodePacked(sel, args));
        require(ok, "FuzzDriftDetector: staticcall failed");
        return out;
    }

    function _perturb(bytes memory b, uint8 i) internal pure returns (bytes memory) {
        if (b.length == 0) return b;
        bytes memory c = b;
        // Flip a few low-order bits in the final byte; simple, deterministic
        // and keeps the perturbation tiny.
        c[c.length - 1] = bytes1(uint8(c[c.length - 1]) ^ i);
        return c;
    }

    function _equal(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        for (uint256 i = 0; i < a.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }
}
