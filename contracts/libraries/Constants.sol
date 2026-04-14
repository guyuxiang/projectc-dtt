//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library ErrorCode {
    // -------------------------- ErrorCode of DigitalTokenTradeDiamond.sol -------------------------
    // ErrorCode of dtt.sendRealisedToken(), function seq: 01
    string public constant SCM_DTT_sendRealisedToken_PARAMETER_ERROR = "SCM_DTT_01_01";
    string public constant SCM_DTT_sendRealisedToken_PERMIT_FAILED = "SCM_DTT_01_02";
    string public constant SCM_DTT_sendRealisedToken_TRANSFER_FAILED = "SCM_DTT_01_03";
    string public constant SCM_DTT_sendRealisedToken_CREATE_VOID = "SCM_DTT_01_04";

    // ErrorCode of dtt.tradeStatus(), function seq: 02
    string public constant SCM_DTT_tradeStatus_UNKNOWN_CONDITION_ERROR = "SCM_DTT_02_01";
    string public constant SCM_DTT_tradeStatus_UNKNOWN_TRADE_ERROR = "SCM_DTT_02_02";

    // ErrorCode of dtt.conditionAction(), function seq: 03
    string public constant SCM_DTT_conditionAction_SETTLE_STATUS_WRONG = "SCM_DTT_03_01";
    string public constant SCM_DTT_conditionAction_TRADE_STATUS_WRONG = "SCM_DTT_03_02";
    string public constant SCM_DTT_conditionAction_SCID_NOT_IN_BUSINESS = "SCM_DTT_03_03";

    // ErrorCode of dtt.conditionSetDate(), function seq: 04
    string public constant SCM_DTT_conditionSetDate_SETTLE_STATUS_WRONG = "SCM_DTT_04_01";
    string public constant SCM_DTT_conditionSetDate_TRADE_STATUS_WRONG = "SCM_DTT_04_02";
    string public constant SCM_DTT_conditionSetDate_SCID_NOT_IN_BUSINESS = "SCM_DTT_04_03";

    // ErrorCode of dtt.conditionPartialAccept(), function seq: 05
    string public constant SCM_DTT_conditionPartialAccept_SENDER_WRONG = "SCM_DTT_05_01";
    string public constant SCM_DTT_conditionPartialAccept_ACCEPT_ERROR = "SCM_DTT_05_02";
    string public constant SCM_DTT_conditionPartialAccept_AMOUNT_WRONG = "SCM_DTT_05_03";
    string public constant SCM_DTT_conditionPartialAccept_SETTLE_STATUS_WRONG = "SCM_DTT_05_04";
    string public constant SCM_DTT_conditionPartialAccept_TRADE_STATUS_WRONG = "SCM_DTT_05_05";
    string public constant SCM_DTT_conditionPartialAccept_TRADE_STATUS_WRONG2 = "SCM_DTT_05_06";

    // ErrorCode of dtt.settleTrade(), function seq: 06
    string public constant SCM_DTT_settleTrade_ID_ERROR = "SCM_DTT_06_01";
    string public constant SCM_DTT_settleTrade_SETTLE_STATUS_WRONG = "SCM_DTT_06_02";
    string public constant SCM_DTT_settleTrade_TRADE_STATUS_WRONG = "SCM_DTT_06_03";
    string public constant SCM_DTT_settleTrade_TRANSFER_FAILED_WHEN_REALISED = "SCM_DTT_06_04";
    string public constant SCM_DTT_settleTrade_TRANSFER_FAILED_WHEN_VOID = "SCM_DTT_06_05";
    string public constant SCM_DTT_settleTrade_DttContractPermissionError = "SCM_DTT_06_06";

    // ErrorCode of dtt.settleTradeWithAmount(), function seq: 07
    string public constant SCM_DTT_settleTradeWithAmount_STATUS_WRONG = "SCM_DTT_07_01";
    string public constant SCM_DTT_settleTradeWithAmount_AMOUNT_WRONG = "SCM_DTT_07_02";

    // ErrorCode of dtt.erc20Transfer(), function seq: 08
    string public constant SCM_DTT_erc20Transfer_AMOUNT_WRONG = "SCM_DTT_08_01";
    string public constant SCM_DTT_erc20TransferFrom_AMOUNT_WRONG = "SCM_DTT_08_02";

    // ------------------------------ ErrorCode of DTTERC20.sol --------------------------------------
    // ErrorCode of ERC20.mint(), function seq: 01
    string public constant SCM_ERC20_mint_ID_REPEAT = "SCM_ERC20_01_01";
    string public constant SCM_ERC20_mint_Permit_WRONG = "SCM_ERC20_01_02";
    string public constant SCM_ERC20_mint_Limit_WRONG = "SCM_ERC20_01_03";
    string public constant SCM_ERC20_paused_WRONG = "SCM_ERC20_01_04";

    // ------------------------------ ErrorCode of kyc/Permission.sol ----------------------------
    // ErrorCode of TokenPermission, function seq: 01
    string public constant SCM_Permission_Token_Transfer_ERROR = "SCM_PEM_01_01";
    string public constant SCM_Permission_Token_Mint_ERROR = "SCM_PEM_01_02";
    string public constant SCM_Permission_Token_Debit_ERROR = "SCM_PEM_01_03";

    // ErrorCode of EncashPermission, function seq: 02
    string public constant SCM_Permission_Encash_ERROR = "SCM_PEM_02_01";

    // ErrorCode of DTTPermission, function seq: 03
    string public constant SCM_Permission_DTT_Send_ERROR = "SCM_PEM_03_01";
    string public constant SCM_Permission_DTT_RtSendTradeAction_ERROR = "SCM_PEM_03_02";

    // ErrorCode of NFTPermission, function seq: 04
    string public constant SCM_Permission_NFT_Transfer_ERROR = "SCM_PEM_04_01";
    string public constant SCM_Permission_NFT_Mint_ERROR = "SCM_PEM_04_02";
    string public constant SCM_Permission_NFT_Debit_ERROR = "SCM_PEM_04_03";
    string public constant SCM_Permission_NFT_WITHOUTPERMISSION_ERROR = "SCM_PEM_04_04";

    // ------------------------------ ErrorCode of condition.sol ----------------------------
    // ErrorCode of Condition.modifier, function seq: 01
    string public constant SCM_CDN_modifier_CALLER_ERROR = "SCM_CDN_01_01";

    // ErrorCode of Condition.create, function seq: 02
    string public constant SCM_CDN_create_INVALID_TIMESCID = "SCM_CDN_02_01";
    string public constant SCM_CDN_create_INVALID_TIMEEND = "SCM_CDN_02_02";
    string public constant SCM_CDN_create_ALREADY_EXISTED = "SCM_CDN_02_03";
    string public constant SCM_CDN_create_EMPTY_FACTORS_ERROR = "SCM_CDN_02_04";
    string public constant SCM_CDN_create_FIXFACTORS_NAME_ERROR = "SCM_CDN_02_05";
    string public constant SCM_CDN_create_FIXFACTORS_VALUE_ERROR = "SCM_CDN_02_06";
    string public constant SCM_CDN_create_FIXFACTORS_CHANGEBLE_ERROR = "SCM_CDN_02_07";
    string public constant SCM_CDN_create_DYNAMICFACTORS_NAME_ERROR = "SCM_CDN_02_08";
    string public constant SCM_CDN_create_DYNAMICFACTORS_ENDTIME_ERROR = "SCM_CDN_02_09";
    string public constant SCM_CDN_create_DYNAMICFACTORS_BEGINTIME_ERROR = "SCM_CDN_02_10";
    string public constant SCM_CDN_create_CSSET_REPEAT = "SCM_CDN_02_11";
    string public constant SCM_CDN_create_SET_EMPTY_ERROR = "SCM_CDN_02_12";
    string public constant SCM_CDN_create_JOIN_ERROR = "SCM_CDN_02_13";
    string public constant SCM_CDN_create_FIXFACTORS_DATE_ERROR = "SCM_CDN_02_14";

    // ErrorCode of Condition.changeFactor, function seq: 03
    string public constant SCM_CDN_changeFactor_INVALID_SCID = "SCM_CDN_03_01";
    string public constant SCM_CDN_changeFactor_INVALID_INDEX = "SCM_CDN_03_02";
    string public constant SCM_CDN_changeFactor_INVALID_CHANGEABLE = "SCM_CDN_03_03";
    string public constant SCM_CDN_changeFactor_INVALID_CHANGEFLAG = "SCM_CDN_03_04";
    string public constant SCM_CDN_changeFactor_INVALID_CHANGEADDR = "SCM_CDN_03_05";
    string public constant SCM_CDN_changeFactor_INVALID_TIME = "SCM_CDN_03_06";
    string public constant SCM_CDN_changeFactor_NO_DATE = "SCM_CDN_03_07";
    string public constant SCM_CDN_changeFactor_ACTIONTIME_ERROR = "SCM_CDN_03_08";
    string public constant SCM_CDN_changeFactor_ACTIONTIME_ERROR2 = "SCM_CDN_03_09";

    // ErrorCode of Condition.queryCSStatus, function seq: 04
    string public constant SCM_CDN_queryCSStatus_INVALID_CSID = "SCM_CDN_04_01";

    // ErrorCode of Condition.querySCStatus, function seq: 05
    string public constant SCM_CDN_querySCStatus_INVALID_SCID = "SCM_CDN_05_01";
    string public constant SCM_CDN_querySCStatus_INVALID_CONDITIONTYPE = "SCM_CDN_05_02";

    // ErrorCode of Condition.timeRangeValidate, function seq: 06
    string public constant SCM_CDN_timeRangeValidate_INVALID_TIME = "SCM_CDN_06_01";

    // ErrorCode of Condition.factorFutureChangeChance, function seq: 07
    string public constant SCM_CDN_factorFutureChangeChance_INVALID_LOGIC = "SCM_CDN_07_01";

    // ErrorCode of Condition.calculateTimeRange, function seq: 08
    string public constant SCM_CDN_calculateTimeRange_INVALID_TYPE = "SCM_CDN_08_01";

    // ErrorCode of Condition.queryFactor, function seq: 09
    string public constant SCM_CDN_queryFactor_NOSUCH_FACTOR = "SCM_CDN_09_01";

    // ErrorCode of Condition.queryFactorIndex, function seq: 10
    string public constant SCM_CDN_queryFactorIndex_NOSUCH_FACTOR = "SCM_CDN_10_01";

    // ErrorCode of Condition.stringToUint, function seq: 11
    string public constant SCM_CDN_stringToUint_INVALID_STRING = "SCM_CDN_11_01";

    // ErrorCode of Condition.changeFactorWhenPartialAccept, function seq: 12
    string public constant SCM_CDN_changeFactorWhenPartialAccept_INVALID_STATUS = "SCM_CDN_12_01";
    string public constant SCM_CDN_changeFactorWhenPartialAccept_INVALID_TIME = "SCM_CDN_12_02";
    string public constant SCM_CDN_changeFactorWhenPartialAccept_INVALID_CHANGEADDR = "SCM_CDN_12_03";
    string public constant SCM_CDN_changeFactorWhenPartialAccept_NO_ACCEPT_FACTOR = "SCM_CDN_12_04";
    string public constant SCM_CDN_changeFactorWhenPartialAccept_NO_PARTIALSC = "SCM_CDN_12_05";

    // ErrorCode of Condition.checkPartialAcceptSc, function seq: 13
    string public constant SCM_CDN_checkPartialAcceptSc_INVALID_ADDRESS = "SCM_CDN_13_01";
    string public constant SCM_CDN_checkPartialAcceptSc_INVALID_SCID = "SCM_CDN_13_02";
    string public constant SCM_CDN_checkPartialAcceptSc_TYPE_WRONG = "SCM_CDN_13_03";
    string public constant SCM_CDN_checkPartialAcceptSc_NO_PARTIALSC = "SCM_CDN_13_04";

    // ------------------------------ ErrorCode of conditioncopy.sol ----------------------------
    // ErrorCode of ConditionCopy.copy, function seq: 01
    string public constant SCM_CDNC_copy_CALLER_ERROR = "SCM_CDNC_01_01";

    // ------------------------------ ErrorCode of token/Encash.sol ----------------------------
    // ErrorCode of Encash.encash(), function seq: 01
    string public constant SCM_RealisedTokenEncash_encash_EncashContractPermissionError = "SCM_ENC_01_01";
    // ErrorCode of Encash.accept(), function seq: 02
    string public constant SCM_RealisedTokenEncash_accept_EncashInfoNotFound = "SCM_ENC_02_01";
    string public constant SCM_RealisedTokenEncash_accept_EncashInfoNotSupportAccept = "SCM_ENC_02_02";
    string public constant SCM_RealisedTokenEncash_accept_OnlyIssuerOperate = "SCM_ENC_02_03";
    // ErrorCode of Encash.reject(), function seq: 03
    string public constant SCM_RealisedTokenEncash_reject_EncashInfoNotFound = "SCM_ENC_03_01";
    string public constant SCM_RealisedTokenEncash_reject_EncashInfoNotSupportReject = "SCM_ENC_03_02";
    string public constant SCM_RealisedTokenEncash_reject_OnlyIssuerOperate = "SCM_ENC_03_03";
    string public constant SCM_RealisedTokenEncash_reject_TransferSuspenseFailed = "SCM_ENC_03_04";
    string public constant SCM_RealisedTokenEncash_reject_EncashContractPermissionError = "SCM_ENC_03_05";

    // ------------------------------ ErrorCode of token/transanctionIDFactory.sol ----------------------------
    string public constant SCM_TransactionIDFactory_generateTransactionID_CALLER_ERROR = "SCM_TID_01_01";

    // ------------------------------ ErrorCode of kyc/Userpermission.sol ----------------------------
    string public constant SCM_UserPermission_setPermission_permission_denied = "SCM_UPEM_01_01";
    string public constant SCM_UserPermission_setPermission_OnlyIssuerOperate = "SCM_UPEM_01_02";

    // ------------------------------ ErrorCode of token/RORERC721.sol ----------------------------
    // ErrorCode of erc721.modifier, function seq: 01
    string public constant SCM_ERC721_modifer_OnlyRorEnhancement = "SCM_ERC721_01_01";

    // ------------------------------ ErrorCode of ror/RorEnhancement.sol ----------------------------
    // ErrorCode of RorEnhancement.send(), function seq: 01
    string public constant SCM_RorEnhancement_send_CALLER_ERROR = "SCM_RE_01_01";

    // ErrorCode of RorEnhancement.partialAccept(), function seq: 02
    string public constant SCM_RorEnhancement_partialAccept_CALLER_ERROR = "SCM_RE_02_01";

    // ErrorCode of RorEnhancement.settle(), function seq: 03
    string public constant SCM_RorEnhancement_settle_CALLER_ERROR = "SCM_RE_03_01";

    // ErrorCode of RorEnhancement.mint(), function seq: 04
    string public constant SCM_RorEnhancement_mint_MintPermissionError = "SCM_RE_04_01";

    // ErrorCode of RorEnhancement.burn(), function seq: 06
    string public constant SCM_RorEnhancement_burn_REVERT_ERROR = "SCM_RE_05_01";

    // ErrorCode of RorEnhancement._splitRor(), function seq: 06
    string public constant SCM_RorEnhancement_splitRor_NOT_TOPAID = "SCM_RE_06_01";
    string public constant SCM_RorEnhancement_splitRor_AMOUNT_EXCEED = "SCM_RE_06_02";

    // ErrorCode of RorEnhancement.transferRor(), function seq: 07
    string public constant SCM_RorEnhancement_transferRor_CALLER_ERROR = "SCM_RE_07_01";

    // ------------------------------ ErrorCode of ror/RorMarket.sol ----------------------------
    // ErrorCode of RorMarket.transferRor(), function seq: 01
    string public constant SCM_RorMarket_transferRor_CALLER_ERROR = "SCM_RM_01_01";
    string public constant SCM_RorMarket_transferRor_TradeStatus = "SCM_RM_01_02";
    // string constant public SCM_RorMarket_transferRor_TransferERROR = "SCM_RM_01_03";

    // ErrorCode of RorMarket.transfereeAcceptWithFN(), function seq: 02
    string public constant SCM_RorMarket_transfereeAcceptWithFN_ConsiderationType = "SCM_RM_02_01";
    string public constant SCM_RorMarket_transfereeAcceptWithFN_Caller_Error = "SCM_RM_02_02";
    string public constant SCM_RorMarket_transfereeAcceptWithFN_CreateTime_Error = "SCM_RM_02_03";
    string public constant SCM_RorMarket_transfereeAcceptWithFN_Transfer_Error = "SCM_RM_02_04";
    string public constant SCM_RorMarket_transfereeAcceptWithFN_Transfer2_Error = "SCM_RM_02_05";
    string public constant SCM_RorMarket_transfereeAcceptWithFN_Amount_Error = "SCM_RM_02_06";

    // ErrorCode of RorMarket.transfereeReject(), function seq: 03
    string public constant SCM_RorMarket_transfereeReject_Caller_Error = "SCM_RM_03_01";
    string public constant SCM_RorMarket_transfereeReject_CreateTime_Error = "SCM_RM_03_02";

    // ErrorCode of RorMarket.expire(), function seq: 04
    string public constant SCM_RorMarket_expire_CreateTime_Error = "SCM_RM_04_01";

    // ErrorCode of RorMarket.accept/reject/expire(), function seq: 05
    string public constant SCM_RorMarket_transferAction_TRANS_NONINIT = "SCM_RM_05_01";
}
