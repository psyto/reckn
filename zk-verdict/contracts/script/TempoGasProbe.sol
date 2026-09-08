// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @notice Diagnostic sibling of TempoEvmProbe, same eth_call/no-key mechanism. It exists
///         because "the whole path costs 5x more on Tempo" is not a number anyone can budget
///         from -- this says WHICH costs differ. Never deployed.
///
///         `step` selects ONE measurement per call. Measuring them all in one constructor
///         put the call over the node's 50M eth_call cap and returned nothing at all, which
///         is its own small lesson: a probe that measures ten things fails as one thing.
contract TempoGasProbe {
    uint256 private slotA;
    uint256 private slotB;
    uint256 private sink;

    constructor(uint256 step) {
        uint256 used;
        uint256 g = gasleft();
        if (step == 0) {
            // baseline: the measurement harness itself
        } else if (step == 1) {
            slotA = 1; // cold SSTORE, 0 -> 1        (Ethereum: 22100)
        } else if (step == 2) {
            slotA = 1;
            g = gasleft();
            slotA = 2; // warm SSTORE                (Ethereum: 100)
        } else if (step == 3) {
            sink = slotB; // cold SLOAD + warm SSTORE (Ethereum: 2100 + 22100)
        } else if (step == 4) {
            bytes memory k = new bytes(1024);
            sink = 1; // warm the slot FIRST: the first version of this row wrote a cold slot
            g = gasleft(); // and so measured a 254k SSTORE and called it "keccak"
            sink = uint256(keccak256(k)); // keccak over 1 KiB
        } else if (step == 5) {
            _pair(); // bn256Pairing, two real pairs (Ethereum: 45000 + 2*34000)
        } else if (step == 6) {
            _small(0x06, 128); // bn256Add           (Ethereum: 150)
        } else if (step == 7) {
            _small(0x07, 96); // bn256ScalarMul      (Ethereum: 6000)
        } else if (step == 8) {
            new Blob(); // CREATE                    (Ethereum: 32000 + 200/byte)
        } else if (step == 9) {
            _cold(address(0x1234)); // cold account  (Ethereum: 2600)
        }
        used = g - gasleft();

        uint256[3] memory out;
        out[0] = used;
        out[1] = block.chainid;
        out[2] = type(Blob).runtimeCode.length;
        assembly {
            return(out, 96)
        }
    }

    /// e(P,Q) * e(-P,Q) == 1 -- a REAL two-pair pairing, not the empty-input shortcut
    /// `tempo.json` already measured.
    function _pair() private view {
        uint256[12] memory i;
        i[0] = 1;
        i[1] = 2;
        i[2] = 0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2;
        i[3] = 0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed;
        i[4] = 0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b;
        i[5] = 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa;
        i[6] = 1;
        i[7] = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd45; // p - 2
        i[8] = i[2];
        i[9] = i[3];
        i[10] = i[4];
        i[11] = i[5];
        assembly {
            pop(staticcall(gas(), 0x08, i, 384, 0, 32))
        }
    }

    function _small(uint256 which, uint256 len) private view {
        uint256[4] memory i;
        i[0] = 1;
        i[1] = 2;
        i[2] = 1;
        i[3] = 2;
        assembly {
            pop(staticcall(gas(), which, i, len, 0, 64))
        }
    }

    function _cold(address a) private view {
        assembly {
            pop(extcodesize(a))
        }
    }
}

/// Fixed, known runtime size, so CREATE's cost divided by it gives the per-byte deposit.
contract Blob {
    uint256 private x;

    function set(uint256 v) external {
        x = v;
    }

    function get() external view returns (uint256) {
        return x;
    }
}
