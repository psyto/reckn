// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RecknZkEscrow} from "../src/RecknZkEscrow.sol";
import {RecknVerdictVerifier} from "../src/RecknVerdictVerifier.sol";
import {SP1Verifier} from "@sp1-contracts/v6.1.0/SP1VerifierGroth16.sol";
import {MockTIP20} from "../test/mocks/MockTIP20.sol";

/// @title TempoEvmProbe
/// @notice Task 011. **Runs the whole settlement path inside the remote node's own EVM,
///         with no key, no transaction and no funds.**
///
///         It is never deployed. It is sent as the `data` of an `eth_call` with `to: null`,
///         so the node executes this constructor and returns whatever the constructor
///         leaves behind as "runtime code". The constructor therefore ends in an assembly
///         `return`, which hands back measurements instead of code.
///
///         **Why it exists.** `tempo.json` records that Tempo's BN254 precompiles answer
///         with Ethereum semantics on three trivial inputs. That is necessary and not
///         sufficient: a Groth16 verification is thousands of field operations and two real
///         pairings, and "0x08 on empty input returns 1" does not imply "an SP1 proof
///         verifies". The only way to settle that without a funded key is to make the node
///         run the real verifier over a real fixture. That is what this does.
///
///         **What a green result does NOT establish**, and no downstream text may say it
///         does: an `eth_call` writes no state, pays no fee, and mines no block. It shows
///         that Tempo's EVM *computes* this path — not that a transaction carrying it can
///         be paid for, included, or persisted, and not that the real TIP-20 will permit the
///         transfers (this probe funds a `MockTIP20`, because giving the probe a balance in
///         a real one needs a faucet). Those are T-4's job and need a funded key (011 §9.1).
///
///         Run it, on Tempo and against a local control, with
///         `bash zk-verdict/scripts/tempo-evm-probe.sh`.
contract TempoEvmProbe {
    /// One storage array rather than locals: the constructor exceeds the stack limit
    /// otherwise, and this repository builds without `via_ir`.
    ///  0 chainid              1 block number          2 mode
    ///  3 SP1Verifier codehash 4 verifier codehash     5 escrow codehash
    ///  6 seller balance       7 buyer balance         8 escrow balance
    ///  9 gas: deploy SP1Verifier                     10 gas: deploy RecknVerdictVerifier
    /// 11 gas: deploy RecknZkEscrow                   12 gas: fund
    /// 13 gas: settleWithProof (0 if it reverted)     14 revert selector, left-aligned
    /// 15 1 if settleWithProof returned, 0 if it reverted
    uint256[16] private r;

    address constant SELLER = address(0x5E11E4);

    address private aSp1;
    address private aVerifier;
    address private aEscrow;
    address private aToken;

    /// @param mode 0 = settle with the proof's own binding (the fixture decides the
    ///             direction: REPRODUCED pays the seller, FAILED refunds the buyer).
    ///             1 = fund with a DIFFERENT binding, so a real proof of another execution
    ///             meets this deal and must move nothing.
    constructor(
        bytes32 vkey,
        bytes memory publicValues,
        bytes memory proof,
        bytes32 dealBinding,
        uint8 decimals_,
        uint256 mode
    ) {
        r[2] = mode;
        _deploy(vkey, decimals_);
        _fund(dealBinding, decimals_, mode);
        _settle(publicValues, proof);
        _report();

        uint256[16] memory out = r;
        assembly {
            return(out, 512)
        }
    }

    /// Deployed inside the call, from the same sources the Foundry tests use, so the
    /// codehashes reported below are comparable across chains.
    function _deploy(bytes32 vkey, uint8 decimals_) private {
        r[9] = gasleft();
        aSp1 = address(new SP1Verifier());
        r[9] -= gasleft();
        r[10] = gasleft();
        aVerifier = address(new RecknVerdictVerifier(aSp1, vkey));
        r[10] -= gasleft();
        r[11] = gasleft();
        aEscrow = address(new RecknZkEscrow());
        r[11] -= gasleft();
        aToken = address(new MockTIP20("Path USD", "pathUSD", decimals_));
    }

    /// This contract is the buyer: `fund` reads msg.sender.
    function _fund(bytes32 dealBinding, uint8 decimals_, uint256 mode) private {
        uint256 amount = 250 * (10 ** uint256(decimals_));
        MockTIP20(aToken).mint(address(this), amount);
        MockTIP20(aToken).approve(aEscrow, amount);
        r[12] = gasleft();
        RecknZkEscrow(aEscrow).fund(
            bytes32(uint256(1)),
            SELLER,
            aToken,
            amount,
            aVerifier,
            aVerifier.codehash,
            // mode 1 flips one bit of the binding, so the proof is real and the deal is not
            // the one it proves. Flipping rather than substituting keeps it non-zero, which
            // `fund` requires, without needing a second fixture.
            mode == 1 ? dealBinding ^ bytes32(uint256(1)) : dealBinding
        );
        r[12] -= gasleft();
    }

    function _settle(bytes memory publicValues, bytes memory proof) private {
        r[13] = gasleft();
        try RecknZkEscrow(aEscrow).settleWithProof(bytes32(uint256(1)), publicValues, proof) {
            r[13] = r[13] - gasleft();
            r[15] = 1;
        } catch (bytes memory err) {
            r[13] = 0;
            r[15] = 0;
            // Custom errors are four bytes. Reported left-aligned so the caller can read the
            // selector without guessing an ABI.
            uint256 sel;
            if (err.length >= 4) {
                assembly {
                    sel := mload(add(err, 0x20))
                }
            }
            r[14] = sel;
        }
    }

    function _report() private {
        r[0] = block.chainid;
        r[1] = block.number;
        r[3] = uint256(aSp1.codehash);
        r[4] = uint256(aVerifier.codehash);
        r[5] = uint256(aEscrow.codehash);
        // Read the outcome from the token, not from a return value: the point is that money
        // moved. `eth_getBalance` is meaningless on Tempo (011 §2.2.3), so this is balanceOf.
        r[6] = MockTIP20(aToken).balanceOf(SELLER);
        r[7] = MockTIP20(aToken).balanceOf(address(this));
        r[8] = MockTIP20(aToken).balanceOf(aEscrow);
    }
}
