//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "../kyc/Config.sol";
import "../interfaces/IDTTERC20.sol";
import "../kyc/UserPermission.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract DTTStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    DTTStorages internal ds;

    struct DTTStorages {
        Config config;
        bool paused;
        // 交易相关存储
        mapping(string => RealisedTokenTrade) businessIndex;
        mapping(string => RealisedTokenTradeExpand) businessIndexExpand;
        // 条件相关存储
        mapping(string => ConditionSet) conditionSetIndex;
        mapping(string => SingleCondition) singleConditionIndex;
        SingleCondition[] scArray;
        ConditionSet[] csArray;
        mapping(string => SingleCondition) scMap;
        // verify相关存储
        uint256 verifyCount;
        EnumerableSet.Bytes32Set pendingRefIdsSet;
    }

    struct RealisedTokenTrade {
        address from;
        address to;
        address tokenAddr;
        uint256 amount;
        uint256 tradeTime;
        string timeScId; // Condition ID for transaction time
        string conditionSetId; // Condition set ID for transaction operations
        bool partialAcceptEnable;
        address partialAcceptAddress;
        string partialAcceptScId; // Condition ID for partial acceptance
        string parentBusinessId;
        string[] subBusinessIds;
        SettleStatus status;
    }

    struct RealisedTokenTradeExpand {
        uint256 guaranteeAmount;
    }

    struct ConditionSet {
        string id;
        string[] scIDs;
        string[] csIDs;
        JoinType join;
    }

    struct SingleCondition {
        string id;
        string conditionType;
        string description;
        ConditionFactor[] fixFactors;
        ConditionFactor[] dynamicFactors;
    }

    struct ConditionFactor {
        string name; // Atomic type
        string value; // Atomic modification value
        bool changeFlag; // Has the atomic factor been modified
        bool changeAble; // Is it changeable
        address changeAddr; // Operator
        uint256 beginTime; // Operation start time
        uint256 endTime; // Operation end time
        string commentsHash;
        string[] filesHash;
    }

    enum TradeStatus {
        Unrealised,
        Confirmed,
        Realised,
        Void
    }

    enum SettleStatus {
        INIT,
        SEND,
        REFUND,
        WAIT
    }

    enum JoinType {
        AND,
        OR
    }

    /*
    Priority for 'AND' conditions: Met < RightNowMet < RightNowNotMet < NotMet
    Priority for 'OR' conditions: Met > RightNowMet > RightNowNotMet > NotMet
    */
    enum ConditionStatus {
        Met,
        RightNowMet,
        RightNowNotMet,
        NotMet
    }

    modifier whenNotPaused() {
        if (ds.paused) {
            revert("Pausable: paused");
        }
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != getConfig().governorAddress()) {
            revert("onlyGovernor");
        }
        _;
    }

    function getConfig() internal view returns (Config) {
        return ds.config;
    }

    function getUserPermission(address tokenAddress, address user) internal view returns (uint256) {
        return UserPermission(ds.config.userPermission()).getPermission(IDTTERC20(tokenAddress).getIssuer(), user);
    }

    function isBusinessTokenPaused(address tokenAddress) internal view returns (bool) {
        return tokenAddress != address(0) && IDTTERC20(tokenAddress).paused();
    }
}
