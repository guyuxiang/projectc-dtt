//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/Constants.sol";
import "./DTTStorage.sol";
import "../ror/RorEnhancement.sol";
import "../kyc/UserPermission.sol";
import "../interfaces/ITradeStatusFacet.sol";
import "../interfaces/IDTTERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SettleFacet is DTTPermission, DTTStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;
    event SettleTrade(string indexed businessIdHash, address dttAddr, address creator, string businessId, SettleStatus status);

    event SendSuspenseAccountReceived(address tokenContractAddress, string businessID, uint256 amount, address receiverAddress, uint256 receiverPermission, string reason);
    event RorConvert(address dttAddress, address rorAddress, uint256 rorId, address owner, SettleStatus settleStatus);

    event SettleTradeWaiting(string indexed businessIdHash, string businessId);

    function _permitIfNeeded(IDTTERC20 token, address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) private {
        if (token.allowance(owner, address(this)) < amount) {
            token.permit(owner, address(this), amount, deadline, v, r, s);
        }
    }

    function _settlementRecipient(
        address tokenAddress,
        address recipient,
        string memory businessId,
        uint256 amount,
        string memory reason
    ) private returns (address) {
        uint256 permission = getUserPermission(tokenAddress, recipient);
        if (permission % 10 <= 1) {
            emit SendSuspenseAccountReceived(tokenAddress, businessId, amount, recipient, permission, reason);
            return getConfig().getSuspense(tokenAddress);
        }
        return recipient;
    }

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
                IDTTERC20 token = IDTTERC20(rrs[i].dttAddress);
                require(
                    token.balanceOf(address(this)) >= rrs[i].amount,
                    ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG
                );
                address dest = _settlementRecipient(rrs[i].dttAddress, rrs[i].owner, _businessId, rrs[i].amount, "trade condition met");
                // Intentionally rely on SafeERC20 revert bubbling here: the settlement flow no longer remaps
                // token permission errors to legacy DTT-specific error codes.
                IERC20(address(token)).safeTransfer(dest, rrs[i].amount);
                emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, SettleStatus.SEND);
            }

            ITradeStatusFacet(address(this)).setTradeStatus(_businessId, SettleStatus.SEND);
        }
        // If the transaction status is Void, update settleStatus to REFUND, call the token contract to transfer funds
        else {
            RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).settle(_businessId);
            for (uint256 i = 0; i < rrs.length; i++) {
                emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, SettleStatus.REFUND);
            }
            require(
                IDTTERC20(ds.businessIndex[_businessId].tokenAddr).balanceOf(address(this)) >= ds.businessIndex[_businessId].amount,
                ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG
            );
            {
                IDTTERC20 token = IDTTERC20(ds.businessIndex[_businessId].tokenAddr);
                address dest = _settlementRecipient(
                    ds.businessIndex[_businessId].tokenAddr,
                    ds.businessIndex[_businessId].from,
                    _businessId,
                    ds.businessIndex[_businessId].amount,
                    "trade voided"
                );
                // Keep the same direct SafeERC20 semantics for refund transfers as for realised settlement.
                IERC20(address(token)).safeTransfer(dest, ds.businessIndex[_businessId].amount);
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
        require(ds.businessIndex[businessId].tokenAddr == erc20Address, ErrorCode.SCM_DTT_settleTradeWithAmount_TOKEN_WRONG);
        // Instantiate ERC20 token contract
        IDTTERC20 token = IDTTERC20(erc20Address);
        require(token.balanceOf(msg.sender) >= amount, ErrorCode.SCM_DTT_erc20TransferFrom_AMOUNT_WRONG);
        _permitIfNeeded(token, msg.sender, amount, deadline, v, r, s);
        // Additional funding also uses SafeERC20 directly and bubbles the token's native revert reason.
        IERC20(erc20Address).safeTransferFrom(msg.sender, address(this), amount);
        RorEnhancement.SettleInfo[] memory rrs = RorEnhancement(getConfig().rorEnhancement()).settle(businessId);

        for (uint256 i = 0; i < rrs.length; i++) {
            IDTTERC20 settleToken = IDTTERC20(rrs[i].dttAddress);
            require(
                settleToken.balanceOf(address(this)) >= rrs[i].amount,
                ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG
            );
            address dest = _settlementRecipient(rrs[i].dttAddress, rrs[i].owner, businessId, rrs[i].amount, "trade condition met");
            IERC20(address(settleToken)).safeTransfer(dest, rrs[i].amount);
            emit RorConvert(address(this), getConfig().rorAddress(), rrs[i].id, rrs[i].owner, ds.businessIndex[businessId].status);
        }
        ITradeStatusFacet(address(this)).setTradeStatus(businessId, SettleStatus.SEND);
        emit SettleTrade(businessId, address(this), ds.businessIndex[businessId].from, businessId, SettleStatus.SEND);
    }
}
