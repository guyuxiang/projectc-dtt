
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



contract DummyDiamondImplementation {


    struct Tuple94732 {
        string id;
        string conditionType;
        string description;
        Tuple6899206[] fixFactors;
        Tuple4909803[] dynamicFactors;
    }

    struct Tuple6899206 {
        string name;
        string value;
        bool changeFlag;
        bool changeAble;
        address changeAddr;
        uint256 beginTime;
        uint256 endTime;
        string commentsHash;
        string[] filesHash;
    }

    struct Tuple4909803 {
        string name;
        string value;
        bool changeFlag;
        bool changeAble;
        address changeAddr;
        uint256 beginTime;
        uint256 endTime;
        string commentsHash;
        string[] filesHash;
    }

    struct Tuple3874433 {
        string id;
        string conditionType;
        string description;
        Tuple6899206[] fixFactors;
        Tuple4909803[] dynamicFactors;
    }

    struct Tuple0701114 {
        string name;
        string value;
        bool changeFlag;
        bool changeAble;
        address changeAddr;
        uint256 beginTime;
        uint256 endTime;
        string commentsHash;
        string[] filesHash;
    }

    struct Tuple1903470 {
        string id;
        string[] scIDs;
        string[] csIDs;
        uint8 join;
    }

    struct Tuple9253010 {
        string id;
        string conditionType;
        string description;
        Tuple6899206[] fixFactors;
        Tuple4909803[] dynamicFactors;
    }

    struct Tuple5341480 {
        string id;
        string[] scIDs;
        string[] csIDs;
        uint8 join;
    }

    struct Tuple5756957 {
        string id;
        string[] scIDs;
        string[] csIDs;
        uint8 join;
    }

    struct Tuple7024534 {
        string id;
        string conditionType;
        string description;
        Tuple6899206[] fixFactors;
        Tuple4909803[] dynamicFactors;
    }

    struct Tuple1773676 {
        string name;
        string value;
        bool changeFlag;
        bool changeAble;
        address changeAddr;
        uint256 beginTime;
        uint256 endTime;
        string commentsHash;
        string[] filesHash;
    }

    struct Tuple9014807 {
        string id;
        string[] scIDs;
        string[] csIDs;
        uint8 join;
    }

    struct Tuple8891658 {
        string id;
        string[] scIDs;
        string[] csIDs;
        uint8 join;
    }
    

   function conditionAccept(string memory businessId, string memory scId, string memory commentsHash, string[] memory filesHash) external {}

   function conditionReject(string memory businessId, string memory scId, string memory commentsHash, string[] memory filesHash) external {}

   function conditionSetDate(string memory businessId, string memory scId, string memory date, string memory commentsHash, string[] memory filesHash) external {}

   function calculateTimeRange(Tuple94732 memory singleCondition) external pure returns (bool , uint256 , uint256 ) {}

   function changeFactorWhenPartialAccept(Tuple3874433[] memory scs, string memory partialAcceptScId, address  changeAddr, string memory commentsHash, string[] memory filesHash) external view returns (Tuple7024534[] memory) {}

   function checkPartialAcceptSc(Tuple3874433[] memory scs, string memory partialAcceptScId, address  partialAcceptAddress) external pure {}

   function dateNotSet(string memory scID) external view returns (bool ) {}

   function queryCSStatus(string memory csID) external view returns (uint8  res) {}

   function queryFactor(Tuple0701114[] memory factors, string memory name) external pure returns (Tuple1773676 memory res) {}

   function queryFactorIndex(Tuple0701114[] memory factors, string memory name) external pure returns (uint256 ) {}

   function querySCStatus(string memory scID) external view returns (uint8 ) {}

   function refactorCsId(Tuple1903470 memory cs, string memory addContent) external pure returns (Tuple9014807 memory) {}

   function timeRangeValidate(string memory txTimeScID, string[] memory actionScIDs) external view {}

   function copy(string memory csID, string memory businessID, string memory txTimeScID) external returns (Tuple7024534[] memory, Tuple8891658[] memory) {}

   function create(Tuple9253010[] memory scSet, Tuple5341480[] memory csSet, string memory txTimeScID) external {}

   function deleteArray() external {}

   function bytes32ToString(bytes32  data) external pure returns (string memory) {}

   function conditionPartialAccept(string memory businessId, uint256  amount, uint256  guaranteeAmount, string memory commentsHash, string[] memory filesHash) external {}

   function getPendingRefIds() external view returns (string[] memory) {}

   function pause() external {}

   function sendRealisedToken(address  to, address  erc20Address, uint256  amount, Tuple3874433[] memory scs, Tuple5756957[] memory css, string memory timeScId, string memory csId, bool  partialAcceptEnable, address  partialAcceptAddress, string memory partialAcceptScId, uint256  deadline, uint256  guaranteeAmount, string memory extension, uint8  v, bytes32  r, bytes32  s) external {}

   function setConfig(address  _config) external {}

   function unpause() external {}

   function settleExpire(string[] memory businessIds) external {}

   function settleTrade(string memory _businessId) external {}

   function settleTradeWithAmount(string memory businessId, address  erc20Address, uint256  amount, uint256  deadline, uint8  v, bytes32  r, bytes32  s) external {}

   function setTradeStatus(string memory businessId, uint8  _tradeStatus) external {}

   function tradeStatus(string memory businessId) external view returns (uint8 ) {}

   function verifySendRealisedToken(address  to, address  erc20Address, uint256  amount, Tuple3874433[] memory scs, Tuple5756957[] memory css, string memory timeScId, string memory csId, bool  partialAcceptEnable, address  partialAcceptAddress, string memory partialAcceptScId, uint256  deadline, uint256  guaranteeAmount, string memory extension, uint8  v, bytes32  r, bytes32  s) external {}

   function verifySettleTradeWithAmount(string memory businessId, address  erc20Address, uint256  amount, uint256  deadline, uint8  v, bytes32  r, bytes32  s) external view {}
}
