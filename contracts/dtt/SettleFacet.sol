//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "./DTTStorage.sol";
import "../ror/RorEnhancement.sol";
import "../kyc/Permission.sol";
import "../kyc/UserPermission.sol";
import "../interfaces/ITradeStatusFacet.sol";
import "../interfaces/IDTTERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SettleFacet is DTTPermission, DTTStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    event SettleTrade(string indexed businessIdHash, address dttAddr, address creator, string businessId, SettleStatus status);

    event SendSuspenseAccountReceived(address tokenContractAddress, string businessID, uint256 amount, address receiverAddress, uint256 receiverPermission, string reason);
    event RorConvert(address dttAddress, address rorAddress, uint256 rorId, address owner, SettleStatus settleStatus);

    event SettleTradeWaiting(string indexed businessIdHash, string businessId);

    function settleTrade(string memory _businessId) public whenNotPaused {
        // Check if the parameter is not empty
        require(bytes(_businessId).length > 0, ErrorCode.SCM_DTT_settleTrade_ID_ERROR);
        // Check transaction settlement status, only allow settlement for transactions with status INIT
        if (ds.businessIndex[_businessId].status == SettleStatus.WAIT) {
            return;
        }
        require(ds.businessIndex[_businessId].status == SettleStatus.INIT, ErrorCode.SCM_DTT_settleTrade_SETTLE_STATUS_WRONG);
        // Call tradeStatus to check the transaction status, only allow settlement for transactions with status Realised/Void
        TradeStatus status_get = ITradeStatusFacet(address(this)).tradeStatus(_businessId);
        require(status_get == TradeStatus.Realised || status_get == TradeStatus.Void, ErrorCode.SCM_DTT_settleTrade_TRADE_STATUS_WRONG);
        ds.pendingRefIdsSet.remove(bytes32(bytes(_businessId)));
        // If the transaction status is Realised, call the token contract to transfer funds, update settleStatus to SEND
        if (status_get == TradeStatus.Realised) {
            // todo
            if (ds.businessIndex[_businessId].amount != ds.businessIndexExpand[_businessId].guaranteeAmount) {
                ITradeStatusFacet(address(this)).setTradeStatus(_businessId, SettleStatus.WAIT);
                emit SettleTrade(_businessId, address(this), ds.businessIndex[_businessId].from, _businessId, SettleStatus.WAIT);
                emit SettleTradeWaiting(_businessId, _businessId);

                return;
            }

            RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).settle(_businessId);
            for (uint256 i = 0; i < rrs.length; i++) {
                try IDTTERC20(rrs[i].dttAddress).transfer(rrs[i].owner, rrs[i].amount) {
                    emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, SettleStatus.SEND);
                    // ds.businessIndex[_businessId].status
                } catch Error(string memory reason1) {
                    // If the call is unsuccessful
                    if (Strings.equal(reason1, "ERC20: transfer amount exceeds balance")) {
                        revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                    }

                    if (Strings.equal(reason1, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                        try IDTTERC20(ds.businessIndex[_businessId].tokenAddr).transfer(getConfig().getSuspense(ds.businessIndex[_businessId].tokenAddr), rrs[i].amount) {
                            emit SendSuspenseAccountReceived(
                                ds.businessIndex[_businessId].tokenAddr,
                                _businessId,
                                rrs[i].amount,
                                ds.businessIndex[_businessId].to,
                                getUserPermission(ds.businessIndex[_businessId].tokenAddr, ds.businessIndex[_businessId].to),
                                "trade condition met"
                            );
                        } catch Error(string memory reason2) {
                            if (Strings.equal(reason2, "ERC20: transfer amount exceeds balance")) {
                                revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                            } else {
                                revert(ErrorCode.SCM_DTT_settleTrade_TRANSFER_FAILED_WHEN_REALISED);
                            }
                        }
                    } else {
                        handleError(reason1);
                    }
                }
            }

            ITradeStatusFacet(address(this)).setTradeStatus(_businessId, SettleStatus.SEND);
        }
        // If the transaction status is Void, update settleStatus to REFUND, call the token contract to transfer funds
        else {
            RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).settle(_businessId);
            for (uint256 i = 0; i < rrs.length; i++) {
                emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, SettleStatus.REFUND);
            }
            try IDTTERC20(ds.businessIndex[_businessId].tokenAddr).transfer(ds.businessIndex[_businessId].from, ds.businessIndex[_businessId].amount) {} catch Error(string memory reason1) {
                // If the call is unsuccessful
                if (Strings.equal(reason1, "ERC20: transfer amount exceeds balance")) {
                    revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                }
                if (Strings.equal(reason1, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                    try IDTTERC20(ds.businessIndex[_businessId].tokenAddr).transfer(getConfig().getSuspense(ds.businessIndex[_businessId].tokenAddr), ds.businessIndex[_businessId].amount) {
                        emit SendSuspenseAccountReceived(
                            ds.businessIndex[_businessId].tokenAddr,
                            _businessId,
                            ds.businessIndex[_businessId].amount,
                            ds.businessIndex[_businessId].from,
                            getUserPermission(ds.businessIndex[_businessId].tokenAddr, ds.businessIndex[_businessId].from),
                            "trade voided"
                        );
                    } catch Error(string memory reason2) {
                        if (Strings.equal(reason2, "ERC20: transfer amount exceeds balance")) {
                            revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                        } else {
                            revert(ErrorCode.SCM_DTT_settleTrade_TRANSFER_FAILED_WHEN_VOID);
                        }
                    }
                } else {
                    handleError(reason1);
                }
            }
            ITradeStatusFacet(address(this)).setTradeStatus(_businessId, SettleStatus.REFUND);
        }
        emit SettleTrade(_businessId, address(this), ds.businessIndex[_businessId].from, _businessId, ds.businessIndex[_businessId].status);
    }

    function settleExpire(string[] memory businessIds) public whenNotPaused {
        for (uint256 i = 0; i < businessIds.length; i++) {
            settleTrade(businessIds[i]);
        }
    }

    function settleTradeWithAmount(string memory businessId, address erc20Address, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public whenNotPaused {
        require(ds.businessIndex[businessId].status == SettleStatus.WAIT, ErrorCode.SCM_DTT_settleTradeWithAmount_STATUS_WRONG);
        require(ds.businessIndex[businessId].amount == ds.businessIndexExpand[businessId].guaranteeAmount + amount, ErrorCode.SCM_DTT_settleTradeWithAmount_AMOUNT_WRONG);
        // Instantiate ERC20 token contract
        IDTTERC20 token = IDTTERC20(erc20Address);
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        try IDTTERC20(erc20Address).transferFrom(msg.sender, address(this), amount) {} catch Error(string memory reason) {
            // If the call is unsuccessful
            if (Strings.equal(reason, "ERC20: transfer amount exceeds balance")) {
                revert(ErrorCode.SCM_DTT_erc20TransferFrom_AMOUNT_WRONG);
            } else {
                revert(reason);
            }
        }
        RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).settle(businessId);

        for (uint256 i = 0; i < rrs.length; i++) {
            try IDTTERC20(rrs[i].dttAddress).transfer(rrs[i].owner, rrs[i].amount) {
                emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, ds.businessIndex[businessId].status);
            } catch Error(string memory reason1) {
                // If the call is unsuccessful
                if (Strings.equal(reason1, "ERC20: transfer amount exceeds balance")) {
                    revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                }
                if (Strings.equal(reason1, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                    try IDTTERC20(ds.businessIndex[businessId].tokenAddr).transfer(getConfig().getSuspense(ds.businessIndex[businessId].tokenAddr), rrs[i].amount) {
                        emit SendSuspenseAccountReceived(
                            ds.businessIndex[businessId].tokenAddr,
                            businessId,
                            rrs[i].amount,
                            ds.businessIndex[businessId].to,
                            getUserPermission(ds.businessIndex[businessId].tokenAddr, ds.businessIndex[businessId].to),
                            "trade condition met"
                        );
                    } catch Error(string memory reason2) {
                        if (Strings.equal(reason2, "ERC20: transfer amount exceeds balance")) {
                            revert(ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
                        } else {
                            revert(ErrorCode.SCM_DTT_settleTrade_TRANSFER_FAILED_WHEN_REALISED);
                        }
                    }
                } else {
                    handleError(reason1);
                }
            }
        }
        ITradeStatusFacet(address(this)).setTradeStatus(businessId, SettleStatus.SEND);
        emit SettleTrade(businessId, address(this), ds.businessIndex[businessId].from, businessId, SettleStatus.SEND);
    }

    function handleError(string memory reason) private pure {
        if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Debit_ERROR)) {
            revert(ErrorCode.SCM_DTT_settleTrade_DttContractPermissionError);
        } else {
            revert(reason);
        }
    }
}
