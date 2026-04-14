//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IEncash {
    function encash(address tokenAddress, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function accept(string memory businessId) external;

    function reject(string memory businessId) external;
}
