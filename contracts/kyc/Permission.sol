//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";

abstract contract TokenPermission {
    // Credit Door
    modifier CreditDoorTransfer(uint256 permission) {
        if (permission % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_Token_Transfer_ERROR);
        }
        _;
    }

    modifier CreditDoorMint(uint256 permission) {
        if (permission % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_Token_Mint_ERROR);
        }
        _;
    }

    // Debit Door
    modifier DebitDoor(uint256 permission) {
        if (permission / 10 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_Token_Debit_ERROR);
        }
        _;
    }
}

abstract contract EncashPermission {
    error EncashContractPermissionError(address addr);

    // Encash Door
    modifier EncashDoor(uint256 permission) {
        if (permission / 100 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_Encash_ERROR);
        }
        _;
    }
}

abstract contract DTTPermission {
    // Send Door
    modifier SendDoor(uint256 permission) {
        if (permission / 1000 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_DTT_Send_ERROR);
        }
        _;
    }

    // RtSendTradeAction Door
    modifier RtSendTradeActionDoor(uint256 permission) {
        if (permission / 10000 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_DTT_RtSendTradeAction_ERROR);
        }
        _;
    }

    // Call Door 允许：facet之间的内部调用 (msg.sender == Diamond地址) 例如，SendFacet → Diamond合约 → ConditionCreateFacet (通过call + delegatecall)，call会改变msg.sender，变为 Diamond地址
    modifier CallDoor() {
        if (msg.sender != address(this)) {
            revert(ErrorCode.SCM_CDN_modifier_CALLER_ERROR);
        }
        _;
    }
}

abstract contract NFTPermission {
    modifier CreditDoorNFTTransfer(uint256 permission) {
        if (permission / 100000 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_NFT_Transfer_ERROR);
        }
        _;
    }

    modifier CreditDoorNFTMint(uint256 permission) {
        if (permission / 100000 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_NFT_Mint_ERROR);
        }
        _;
    }

    modifier DebitDoorNFT(uint256 permission) {
        if (permission / 1000000 % 10 <= 1) {
            revert(ErrorCode.SCM_Permission_NFT_Debit_ERROR);
        }
        _;
    }

    modifier CreditDoorWithoutPermission(address rorMarket) {
        if (msg.sender != rorMarket) {
            revert(ErrorCode.SCM_Permission_NFT_WITHOUTPERMISSION_ERROR);
        }
        _;
    }
}
