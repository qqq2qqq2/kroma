// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Bytes32 } from "../libraries/Bytes32.sol";

/**
 * @title IPoseidon2
 */
interface IPoseidon2 {
    function poseidon(bytes32[2] memory inputs) external pure returns (bytes32);
}

/**
 * @custom:proxied
 * @title ZKTrieHasher
 * @notice The ZKTrieHasher is contract which can produce a hash according to ZKTrie.
 *         This owns an interface of Poseidon2 that is required to compute hash used by ZKTrie.
 */
contract ZKTrieHasher {
    /**
     * @notice Poseidon2 contract generated by circomlibjs.
     */
    IPoseidon2 public immutable POSEIDON2;

    /**
     * @param _poseidon2 The address of poseidon2 contract.
     */
    constructor(address _poseidon2) {
        POSEIDON2 = IPoseidon2(_poseidon2);
    }

    /**
     * @notice Computes a hash of values.
     *
     * @param _compressedFlags Compressed flags.
     * @param _values          Values.
     *
     * @return A hash of values.
     */
    function _valueHash(uint32 _compressedFlags, bytes32[] memory _values)
        internal
        view
        returns (bytes32)
    {
        require(_values.length >= 1, "ZKTrieHasher: too few values for _valueHash");
        bytes32[] memory ret = new bytes32[](_values.length);
        for (uint256 i = 0; i < _values.length; ) {
            if ((_compressedFlags & (1 << i)) != 0) {
                ret[i] = _hashElem(_values[i]);
            } else {
                ret[i] = _values[i];
            }
            unchecked {
                ++i;
            }
        }
        if (_values.length < 2) {
            return ret[0];
        }
        return _hashElems(ret);
    }

    /**
     * @notice Computes a hash of an element.
     *
     * @param _elem Bytes32 to be hashed.
     *
     * @return A hash of an element.
     */
    function _hashElem(bytes32 _elem) internal view returns (bytes32) {
        (bytes32 high, bytes32 low) = Bytes32.split(_elem);
        return POSEIDON2.poseidon([high, low]);
    }

    /**
     * @notice Computes a root hash of elements tree.
     *
     * @param _elems Bytes32 array to be hashed.
     *
     * @return A hash of elements tree.
     */
    function _hashElems(bytes32[] memory _elems) internal view returns (bytes32) {
        require(_elems.length >= 4, "ZKTrieHasher: too few values for _hashElems");
        IPoseidon2 iposeidon = POSEIDON2;

        uint256 idx;
        uint256 adjacent_idx;

        uint256 adjacent_offset = 1;
        uint256 jump = 2;
        uint256 length = _elems.length;
        for (; adjacent_offset < length;) {
            for (idx = 0; idx < length;) {
                unchecked {
                    adjacent_idx = idx + adjacent_offset;
                }
                if (adjacent_idx < length) {
                    _elems[idx] = iposeidon.poseidon( [_elems[idx], _elems[adjacent_idx]] );
                }
                unchecked {
                    idx += jump;
                }
            }
            adjacent_offset = jump;
            jump <<= 1;
        }

        return _elems[0];
    }

    /**
     * @notice Computes a root hash of 2 elements.
     *
     * @param left_leaf  Bytes32 left leaf to be hashed.
     * @param right_leaf Bytes32 right leaf to be hashed.
     *
     * @return A hash of 2 elements.
     */
    function _hashFixed2Elems(bytes32 left_leaf, bytes32 right_leaf) internal view returns (bytes32) {
        return POSEIDON2.poseidon([left_leaf, right_leaf]);
    }

   /**
     * @notice Computes a root hash of 3 elements.
     *
     * @param left_leaf  Bytes32 left leaf to be hashed.
     * @param right_leaf Bytes32 right leaf to be hashed.
     * @param up_leaf    Bytes32 up leaf to be hashed with left||right hash.
     *
     * @return A hash of 3 elements.
     */
    function _hashFixed3Elems(bytes32 left_leaf, bytes32 right_leaf, bytes32 up_leaf) internal view returns (bytes32) {
        IPoseidon2 iposeidon = POSEIDON2;
        left_leaf = iposeidon.poseidon([left_leaf, right_leaf]);
        return iposeidon.poseidon([left_leaf, up_leaf]);
    }
}
