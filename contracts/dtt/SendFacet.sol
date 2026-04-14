//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "./DTTStorage.sol";
import "../interfaces/ITradeStatusFacet.sol";
import "../ror/RorEnhancement.sol";
import "../kyc/Permission.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Config.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import "../interfaces/IDTTERC20.sol";
import "../interfaces/IConditionCalculateFacet.sol";
import "../interfaces/IConditionCreateFacet.sol";
import "../interfaces/ISettleFacet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SendFacet is DTTPermission, DTTStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    event CreateTrade(
        string indexed businessIdHash,
        string businessId,
        address tokenAddress,
        uint256 tokenAmount,
        address creator,
        address receiver,
        string timeScId,
        string conditionSetId,
        string parentBusinessId,
        bool partialAcceptEnable,
        address partialAcceptAddress,
        string partialAcceptScId,
        SingleCondition[] scSet,
        ConditionSet[] csSet,
        string extension
    );

    event ConditionPartialAccept(string indexed businessIdHash, string businessId, string subBusinessId, uint256 acceptedAmount, uint256 remainingAmount);

    event ConditionAccept(string indexed businessIdHash, string businessId, string scId, string commentsHash, string[] filesHash);

    event setConfigEvent(address configContract);

    function setConfig(address _config) public {
        if (address(getConfig()) == address(0)) {
            if (msg.sender != Config(_config).governorAddress()) {
                revert("onlyGovernor");
            }
        } else {
            if (msg.sender != getConfig().governorAddress()) {
                revert("onlyGovernor");
            }
        }
        ds.config = Config(_config);
        emit setConfigEvent(_config);
    }

    function pause() public virtual onlyGovernor {
        ds.paused = true;
    }

    function unpause() public virtual onlyGovernor {
        ds.paused = false;
    }

    function sendRealisedToken(
        address to,
        address erc20Address,
        uint256 amount,
        SingleCondition[] memory scs,
        ConditionSet[] memory css,
        string memory timeScId, // Condition ID for transaction time
        string memory csId, // Condition set ID for transaction operations
        bool partialAcceptEnable,
        address partialAcceptAddress,
        string memory partialAcceptScId,
        uint256 deadline,
        uint256 guaranteeAmount,
        string memory extension,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused SendDoor(getUserPermission(erc20Address, msg.sender)) {
        // Check that parameters are not empty
        require(to != address(0), ErrorCode.SCM_DTT_sendRealisedToken_PARAMETER_ERROR);
        require(erc20Address != address(0), ErrorCode.SCM_DTT_sendRealisedToken_PARAMETER_ERROR);
        require(amount > 0, ErrorCode.SCM_DTT_sendRealisedToken_PARAMETER_ERROR);
        require(scs.length > 0, ErrorCode.SCM_DTT_sendRealisedToken_PARAMETER_ERROR);
        require(bytes(timeScId).length > 0, ErrorCode.SCM_DTT_sendRealisedToken_PARAMETER_ERROR);
        TransactionIDFactory IDFactory = TransactionIDFactory(getConfig().idFactoryAddress());

        // When partial acceptance is not allowed, the partial acceptance address must be empty
        if (partialAcceptEnable) {
            IConditionCalculateFacet(address(this)).checkPartialAcceptSc(scs, partialAcceptScId, partialAcceptAddress);
        }

        // Instantiate ERC20 token contract
        IDTTERC20 token = IDTTERC20(erc20Address);

        // Fund transfer
        if (guaranteeAmount != 0) {
            token.permit(msg.sender, address(this), guaranteeAmount, deadline, v, r, s);
            try token.transferFrom(msg.sender, address(this), guaranteeAmount) returns (bool success) {
                require(success, ErrorCode.SCM_DTT_sendRealisedToken_TRANSFER_FAILED);
            } catch Error(string memory reason) {
                // If the call is unsuccessful
                if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                    revert(ErrorCode.SCM_Permission_Token_Transfer_ERROR);
                } else {
                    revert(reason);
                }
            }
        }

        // Generate businessId
        string memory businessId = IDFactory.generateTransactionID(token.symbol(), "SEND");
        // string memory businessId = "1698322846LDASEND000001"; // 勿删！！！测试时使用
        string memory tempPartialAcceptScId = "";
        if (partialAcceptEnable) {
            tempPartialAcceptScId = string(abi.encodePacked(businessId, "_", partialAcceptScId));
        }
        string memory tempCsId = string(abi.encodePacked(businessId, "_", csId));
        if (Strings.equal(csId, "")) {
            tempCsId = "";
        }
        // Organize trade struct
        RealisedTokenTrade memory trade = RealisedTokenTrade(
            msg.sender,
            to,
            erc20Address,
            amount,
            block.timestamp,
            string(abi.encodePacked(businessId, "_", timeScId)),
            tempCsId,
            partialAcceptEnable,
            partialAcceptAddress,
            tempPartialAcceptScId,
            "",
            new string[](0),
            SettleStatus.INIT
        );

        ds.pendingRefIdsSet.add(bytes32(bytes(businessId)));
        ds.businessIndex[businessId] = trade;
        ds.businessIndexExpand[businessId] = RealisedTokenTradeExpand(guaranteeAmount);
        // Loop through scs and change their ids to "businessId_id"
        for (uint256 i = 0; i < scs.length; i++) {
            scs[i].id = string(abi.encodePacked(businessId, "_", scs[i].id));
        }
        // Loop through css and change their ids to "businessId_id"
        for (uint256 i = 0; i < css.length; i++) {
            css[i] = IConditionCalculateFacet(address(this)).refactorCsId(css[i], businessId);
        }
        IConditionCreateFacet(address(this)).create(scs, css, string(abi.encodePacked(businessId, "_", timeScId)));
        // Call tradeStatus to check the transaction status, revert if it's VOID
        TradeStatus status_get = ITradeStatusFacet(address(this)).tradeStatus(businessId);
        require(status_get != TradeStatus.Void, ErrorCode.SCM_DTT_sendRealisedToken_CREATE_VOID);
        RorEnhancement(getConfig().rorEnhancement()).send(businessId, erc20Address, amount, to);
        if (status_get == TradeStatus.Realised && !isBusinessTokenPaused(erc20Address)) {
            ISettleFacet(address(this)).settleTrade(businessId);
        }

        emit CreateTrade(
            businessId,
            businessId,
            erc20Address,
            amount,
            msg.sender,
            to,
            string(abi.encodePacked(businessId, "_", timeScId)),
            tempCsId,
            "",
            partialAcceptEnable,
            partialAcceptAddress,
            tempPartialAcceptScId,
            scs,
            css,
            extension
        );
    }

    function conditionPartialAccept(
        string memory businessId,
        uint256 amount,
        uint256 guaranteeAmount,
        string memory commentsHash,
        string[] memory filesHash
    ) public whenNotPaused RtSendTradeActionDoor(getUserPermission(ds.businessIndex[businessId].tokenAddr, msg.sender)) {
        // Check if msg.sender is the specified partial acceptance address
        require(msg.sender == ds.businessIndex[businessId].partialAcceptAddress, ErrorCode.SCM_DTT_conditionPartialAccept_SENDER_WRONG);
        // Check if partial acceptance is allowed
        require(ds.businessIndex[businessId].partialAcceptEnable, ErrorCode.SCM_DTT_conditionPartialAccept_ACCEPT_ERROR);
        // Check if the value meets the partial acceptance rules (0 < value < transaction value)
        require(amount > 0 && amount < ds.businessIndex[businessId].amount, ErrorCode.SCM_DTT_conditionPartialAccept_AMOUNT_WRONG);
        // Check if the parent transaction is in unsettled status
        require(ds.businessIndex[businessId].status == SettleStatus.INIT, ErrorCode.SCM_DTT_conditionPartialAccept_SETTLE_STATUS_WRONG);
        // Transaction status must be Unrealised
        require(ITradeStatusFacet(address(this)).tradeStatus(businessId) == TradeStatus.Unrealised, ErrorCode.SCM_DTT_conditionPartialAccept_TRADE_STATUS_WRONG);
        // Generate a new sub-businessId
        TransactionIDFactory IDFactory = TransactionIDFactory(getConfig().idFactoryAddress());
        string memory subBusinessId = IDFactory.generateTransactionID(IDTTERC20(ds.businessIndex[businessId].tokenAddr).symbol(), "SEND");
        // string memory subBusinessId = "1698322846LDASEND000002";
        // Get the csId of the parent transaction and call the copy method to generate new scs and css
        string memory csId = ds.businessIndex[businessId].conditionSetId;
        (SingleCondition[] memory scs_get, ConditionSet[] memory css) = IConditionCreateFacet(address(this)).copy(csId, subBusinessId, ds.businessIndex[businessId].timeScId);
        IConditionCreateFacet(address(this)).deleteArray();
        string memory partialAcceptScId = string(abi.encodePacked(ds.businessIndex[businessId].partialAcceptScId, "_", subBusinessId));
        SingleCondition[] memory scs = IConditionCalculateFacet(address(this)).changeFactorWhenPartialAccept(scs_get, partialAcceptScId, msg.sender, commentsHash, filesHash);
        IConditionCreateFacet(address(this)).create(scs, css, string(abi.encodePacked(ds.businessIndex[businessId].timeScId, "_", subBusinessId)));
        // Generate a new sub-transaction
        RealisedTokenTrade memory subTrade = RealisedTokenTrade(
            ds.businessIndex[businessId].from,
            ds.businessIndex[businessId].to,
            ds.businessIndex[businessId].tokenAddr,
            amount,
            block.timestamp,
            string(abi.encodePacked(ds.businessIndex[businessId].timeScId, "_", subBusinessId)),
            string(abi.encodePacked(csId, "_", subBusinessId)),
            false,
            address(0),
            "",
            businessId,
            new string[](0),
            SettleStatus.INIT
        );

        ds.pendingRefIdsSet.add(bytes32(bytes(subBusinessId)));
        ds.businessIndex[subBusinessId] = subTrade;
        ds.businessIndexExpand[subBusinessId] = RealisedTokenTradeExpand(guaranteeAmount);

        // Check the transaction status of the newly generated sub-transaction, trigger its settlement logic if it is Realised or Void
        TradeStatus status_get = ITradeStatusFacet(address(this)).tradeStatus(subBusinessId);
        require(status_get == TradeStatus.Realised || status_get == TradeStatus.Confirmed, ErrorCode.SCM_DTT_conditionPartialAccept_TRADE_STATUS_WRONG2);
        RorEnhancement(getConfig().rorEnhancement()).partialAccept(businessId, subBusinessId, amount);

        if ((status_get == TradeStatus.Realised || status_get == TradeStatus.Void) && !isBusinessTokenPaused(ds.businessIndex[subBusinessId].tokenAddr)) {
            ISettleFacet(address(this)).settleTrade(subBusinessId);
        }

        // Update the status of the parent transaction
        ds.businessIndex[businessId].subBusinessIds.push(subBusinessId);
        ds.businessIndex[businessId].amount = ds.businessIndex[businessId].amount - amount;
        ds.businessIndexExpand[businessId].guaranteeAmount = ds.businessIndexExpand[businessId].guaranteeAmount - guaranteeAmount;

        emit CreateTrade(
            subBusinessId,
            subBusinessId,
            ds.businessIndex[businessId].tokenAddr,
            amount,
            ds.businessIndex[businessId].from,
            ds.businessIndex[businessId].to,
            string(abi.encodePacked(ds.businessIndex[businessId].timeScId, "_", subBusinessId)),
            string(abi.encodePacked(csId, "_", subBusinessId)),
            businessId,
            false,
            address(0),
            "",
            scs,
            css,
            ""
        );
        emit ConditionAccept(subBusinessId, subBusinessId, partialAcceptScId, commentsHash, filesHash);
        emit ConditionPartialAccept(businessId, businessId, subBusinessId, amount, ds.businessIndex[businessId].amount);
    }

    function getPendingRefIds() external view returns (string[] memory) {
        bytes32[] memory data = ds.pendingRefIdsSet.values();
        string[] memory result = new string[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            result[i] = bytes32ToString(data[i]);
        }
        return result;
    }

    function bytes32ToString(bytes32 data) public pure returns (string memory) {
        uint256 len = 0;
        while (len < 32 && data[len] != 0) {
            len++;
        }
        bytes memory bytesArray = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            bytesArray[i] = data[i];
        }
        return string(bytesArray);
    }
}
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
