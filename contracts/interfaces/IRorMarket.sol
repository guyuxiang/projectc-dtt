//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IRorMarket {
    enum ConsiderationType {
        NONE,
        FT
    }
    enum PartialType {
        FULL,
        PARTIAL
    }

    function transferRor(
        uint256 rorId,
        address transferee,
        address considerationDttAddr,
        uint256 considerationAmount,
        ConsiderationType considerationType,
        string memory considerationSelfConfig,
        string memory extension,
        PartialType partialType,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transfereeAccept(string memory transferRefId, string memory extension) external;

    function transfereeAcceptWithFN(
        string memory transferRefId,
        string memory extension,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transfereeReject(string memory transferRefId, string memory extension) external;

    function expire(string memory transferRefId) external;

    function settleReject(uint256 rorId) external;
}
