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
import {LibDiamond} from "../libraries/LibDiamond.sol";
import "../interfaces/IDTTERC20.sol";
import "../interfaces/IRORERC721.sol";
import "../interfaces/IConditionCalculateFacet.sol";
import "../interfaces/IConditionCreateFacet.sol";
import "../interfaces/ISettleFacet.sol";

contract VerifyFacet is DTTPermission, DTTStorage {
    function verifySendRealisedToken(
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

        // When partial acceptance is not allowed, the partial acceptance address must be empty
        if (partialAcceptEnable) {
            IConditionCalculateFacet(address(this)).checkPartialAcceptSc(scs, partialAcceptScId, partialAcceptAddress);
        }

        // Instantiate ERC20 token contract
        IDTTERC20 token = IDTTERC20(erc20Address);

        // Fund transfer
        if (guaranteeAmount != 0) {
            // 验证用户担保金额，erc20出入账权限
            require(token.balanceOf(msg.sender) >= guaranteeAmount, ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
            token.verifyDebitDoor(msg.sender);
            token.verifyCreditDoorTransfer(address(this));
        }

        // Generate businessId
        string memory businessId = Strings.toString(ds.verifyCount++);
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
        RealisedTokenTradeExpand memory tradeExpand = RealisedTokenTradeExpand(guaranteeAmount);

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
        TradeStatus status_get = verifyTradeStatus(trade);
        require(status_get != TradeStatus.Void, ErrorCode.SCM_DTT_sendRealisedToken_CREATE_VOID);
        // Fund transfer
        if (guaranteeAmount != 0) {
            // 验证用户担保金额，erc20出入账权限
            require(token.balanceOf(msg.sender) >= guaranteeAmount);
            token.verifyDebitDoor(msg.sender);
            token.verifyCreditDoorTransfer(address(this));
        }
        // ror入账校验
        IRORERC721 ror = IRORERC721(getConfig().rorAddress());
        {
            ror.verifyCreditDoorNFTMint(to);
        }
        // settle处理
        if (status_get == TradeStatus.Realised) {
            if (trade.amount != tradeExpand.guaranteeAmount) {
                return;
            }
            // 校验出账门禁，没有出账门禁就转账到第三方账户
            {
                token.verifyDebitDoor(address(this));
                try token.verifyCreditDoorTransfer(to) {}
                catch Error(string memory reason) {
                    if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                        token.verifyCreditDoorTransfer(getConfig().getSuspense(trade.tokenAddr));
                    }
                }
            }
        }
    }

    function verifySettleTradeWithAmount(
        string memory businessId,
        address erc20Address,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view whenNotPaused {
        require(
            ds.businessIndex[businessId].status == SettleStatus.WAIT,
            ErrorCode.SCM_DTT_settleTradeWithAmount_STATUS_WRONG
        );
        require(
            ds.businessIndex[businessId].amount == ds.businessIndexExpand[businessId].guaranteeAmount + amount,
            ErrorCode.SCM_DTT_settleTradeWithAmount_AMOUNT_WRONG
        );
        require(ds.businessIndex[businessId].tokenAddr == erc20Address, ErrorCode.SCM_DTT_settleTradeWithAmount_TOKEN_WRONG);
        // Instantiate ERC20 token contract
        IDTTERC20 token = IDTTERC20(erc20Address);
        // 校验合约入账权限
        {
            require(token.balanceOf(msg.sender) >= amount, ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
            token.verifyDebitDoor(msg.sender);
            token.verifyCreditDoorTransfer(address(this));
        }

        RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).verifySettle(businessId);
        uint256 payedAmount = 0;
        for (uint256 i = 0; i < rrs.length; i++) {
            // 校验出账门禁，没有出账门禁就转账到第三方账户
            token.verifyDebitDoor(address(this));
            payedAmount += rrs[i].amount;
            try token.verifyCreditDoorTransfer(rrs[i].owner) {}
            catch Error(string memory reason) {
                if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                    token.verifyCreditDoorTransfer(getConfig().getSuspense(ds.businessIndex[businessId].tokenAddr));
                }
            }
        }
        require(payedAmount == ds.businessIndex[businessId].amount, "pay amount is not eight");
    }

    function verifyTradeStatus(RealisedTokenTrade memory trade) private view returns (DTTStorage.TradeStatus) {
        if (trade.status == SettleStatus.SEND) {
            return TradeStatus.Realised;
        } else if (trade.status == SettleStatus.REFUND) {
            return TradeStatus.Void;
        } else if (trade.status == SettleStatus.WAIT) {
            return TradeStatus.Confirmed;
        } else if (trade.status == SettleStatus.INIT) {
            ConditionStatus timeConditionStatus = IConditionCalculateFacet(address(this)).querySCStatus(trade.timeScId);
            ConditionStatus conditionStatus = ConditionStatus.Met;
            if (!Strings.equal(trade.conditionSetId, "")) {
                conditionStatus = IConditionCalculateFacet(address(this)).queryCSStatus(trade.conditionSetId);
            }
            // calculate tx status
            if (conditionStatus == ConditionStatus.NotMet) {
                return TradeStatus.Void;
            } else if (conditionStatus == ConditionStatus.RightNowNotMet) {
                if (timeConditionStatus == ConditionStatus.NotMet) {
                    return TradeStatus.Void;
                } else {
                    return TradeStatus.Unrealised;
                }
            } else if (conditionStatus == ConditionStatus.RightNowMet) {
                if (timeConditionStatus == ConditionStatus.RightNowNotMet) {
                    return TradeStatus.Unrealised;
                } else {
                    return TradeStatus.Realised;
                }
            } else if (conditionStatus == ConditionStatus.Met) {
                if (timeConditionStatus == ConditionStatus.RightNowNotMet) {
                    bool dateNotSet = IConditionCalculateFacet(address(this)).dateNotSet(trade.timeScId);
                    if (dateNotSet) {
                        return TradeStatus.Unrealised;
                    } else {
                        return TradeStatus.Confirmed;
                    }
                } else {
                    return TradeStatus.Realised;
                }
            } else {
                revert(ErrorCode.SCM_DTT_tradeStatus_UNKNOWN_CONDITION_ERROR);
            }
        } else {
            revert(ErrorCode.SCM_DTT_tradeStatus_UNKNOWN_TRADE_ERROR);
        }
    }
}
