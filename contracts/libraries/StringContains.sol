//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

library StringContains {
    function contains(string memory str, string memory substring) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory subBytes = bytes(substring);

        if (subBytes.length == 0) {
            return true;
        }
        if (strBytes.length < subBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - subBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < subBytes.length; j++) {
                if (strBytes[i + j] != subBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }

        return false;
    }
}
