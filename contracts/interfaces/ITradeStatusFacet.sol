//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface ITradeStatusFacet {
    function setTradeStatus(string memory businessId, DTTStorage.SettleStatus tradeStatus) external;

    function tradeStatus(string memory businessId) external view returns (DTTStorage.TradeStatus);
}
