// SPDX-License-Identifier: UNLICENSED
// Proprietary and Confidential.
// Copyright (c) 2026 Green Link Digital Bank Pte. Ltd.
//
// UPGRADEABILITY NOTICE
// This contract is deployed behind a proxy (or equivalent) and is upgradeable.
// Upgrade authority is controlled by the Bank (Upgrade Admin); upgrades may modify contract logic and behaviour.
// Upgrades are governed by the Bank’s off-chain change and release controls, including for emergency remediation.
//
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Permission.sol";
import "../kyc/Config.sol";
import "../libraries/Constants.sol";

contract DTTERC20 is TokenPermission, ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    struct MintRecord {
        address recipient;
        uint256 amount;
    }

    struct BurnRecord {
        address owner;
        uint256 amount;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        tokenIssuer = _msgSender();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    event Mint(string txID, address recipient, uint256 amount);
    event Burn(string txID, address owner, uint256 amount);
    event setConfigEvent(address configContract);
    event MintLimitChanged(uint256 oldLimit, uint256 newLimit);

    mapping(string => MintRecord) public mintRecords;
    mapping(string => BurnRecord) public burnRecords;

    address public tokenIssuer;
    Config public config;
    bool public paused;

    uint256 public mintLimit;
    address public tokenMintLicensor;

    // Value is equal to keccak256("MintPermit(address to,uint256 amount,string bid)");
    bytes32 public constant MINTPERMIT_TYPEHASH = 0x474e6fa28564e7e00df930e13dc04f5f2abd853c165c80e61cd9c5687ec6c0d7;

    modifier onlyIssuer() {
        require(_msgSender() == tokenIssuer, "only issuer can do");
        _;
    }

    function setIssuer(address issuer) public onlyGovernor {
        tokenIssuer = issuer;
    }

    function getIssuer() public view returns (address) {
        return tokenIssuer;
    }

    function setTokenMintLicensor(address licensor) public onlyGovernor {
        tokenMintLicensor = licensor;
    }

    function getTokenMintLicensor() public view returns (address) {
        return tokenMintLicensor;
    }

    function setMintLimit(uint256 _mintLimit) public onlyGovernor {
        uint256 oldLimit = mintLimit;
        mintLimit = _mintLimit;
        emit MintLimitChanged(oldLimit, _mintLimit);
    }

    function getMintLimit() public view returns (uint256) {
        return mintLimit;
    }

    function setConfig(address _config) public {
        if (address(config) == address(0)) {
            if (msg.sender != Config(_config).governorAddress()) {
                revert("onlyGovernor");
            }
        } else {
            if (msg.sender != config.governorAddress()) {
                revert("onlyGovernor");
            }
        }
        config = Config(_config);
        emit setConfigEvent(_config);
    }

    function pause() public virtual onlyIssuer {
        paused = true;
    }

    function unpause() public virtual onlyIssuer {
        paused = false;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert(ErrorCode.SCM_ERC20_paused_WRONG);
        }
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != config.governorAddress()) {
            revert("onlyGovernor");
        }
        _;
    }

    function mintPermitValidate(address to, uint256 amount, string memory bid, bytes memory signature)
        public
        view
        returns (bool)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparatorV4(),
                keccak256(abi.encode(MINTPERMIT_TYPEHASH, to, amount, keccak256(bytes(bid))))
            )
        );
        return SignatureChecker.isValidSignatureNow(getTokenMintLicensor(), digest, signature);
    }

    function mint(address recipient, uint256 amount, string memory txID, bytes memory signature)
        public
        whenNotPaused
        CreditDoorMint(UserPermission(config.userPermission()).getPermission(getIssuer(), recipient))
        onlyIssuer
    {
        require(mintRecords[txID].recipient == address(0), ErrorCode.SCM_ERC20_mint_ID_REPEAT);
        require(mintPermitValidate(recipient, amount, txID, signature), ErrorCode.SCM_ERC20_mint_Permit_WRONG);
        require(amount <= mintLimit, ErrorCode.SCM_ERC20_mint_Limit_WRONG);
        _mint(recipient, amount);
        mintRecords[txID] = MintRecord(recipient, amount);
        emit Mint(txID, recipient, amount);
    }

    function burn(uint256 amount, string memory txID) public whenNotPaused {
        require(burnRecords[txID].owner == address(0), ErrorCode.SCM_ERC20_mint_ID_REPEAT);
        _burn(_msgSender(), amount);
        burnRecords[txID] = BurnRecord(_msgSender(), amount);
        emit Burn(txID, _msgSender(), amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        CreditDoorTransfer(UserPermission(config.userPermission()).getPermission(getIssuer(), to))
        DebitDoor(UserPermission(config.userPermission()).getPermission(getIssuer(), msg.sender))
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        CreditDoorTransfer(UserPermission(config.userPermission()).getPermission(getIssuer(), to))
        DebitDoor(UserPermission(config.userPermission()).getPermission(getIssuer(), from))
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 value) public virtual override whenNotPaused returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    function forceTransfer(address from, address to, uint256 amount) public onlyIssuer returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    function verifyCreditDoorTransfer(address verifyAddress)
        public
        view
        whenNotPaused
        CreditDoorTransfer(UserPermission(config.userPermission()).getPermission(getIssuer(), verifyAddress))
    {}

    function verifyCreditDoorMint(address verifyAddress)
        public
        view
        whenNotPaused
        CreditDoorMint(UserPermission(config.userPermission()).getPermission(getIssuer(), verifyAddress))
    {}

    function verifyDebitDoor(address verifyAddress)
        public
        view
        whenNotPaused
        DebitDoor(UserPermission(config.userPermission()).getPermission(getIssuer(), verifyAddress))
    {}
}
