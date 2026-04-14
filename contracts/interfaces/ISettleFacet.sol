//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISettleFacet {
    function settleTrade(string memory _businessId) external;
    function settleTradeWithAmount(
        string memory businessId,
        address erc20Address,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
