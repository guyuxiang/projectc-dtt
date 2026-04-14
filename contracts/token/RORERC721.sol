//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "../utils/Counters.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Permission.sol";
import "../kyc/Config.sol";

// ERC721 with permit
contract RORERC721 is NFTPermission, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    struct TokenProperties {
        string refId;
        string currency;
        address ERC20Address;
        uint256 amount;
        uint256 parentTokenId;
        string executionDate;
        string comment;
    }

    uint256 private lastTokenId;
    bytes32 private nameHash;
    bytes32 private versionHash;
    mapping(uint256 => Counters.Counter) private _nonces;

    function initialize(string memory name, string memory symbol, string memory version) public initializer {
        __ERC721_init(name, symbol);
        nameHash = keccak256(bytes(name));
        versionHash = keccak256(bytes(version));
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    Config public config;
    UserPermission public userPermission;

    address public nftIssuer;

    bool public paused;

    // Value is equal to keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    string public SVGTemplate;
    string public SVGText;
    string public tokenURIDescription;

    mapping(uint256 => TokenProperties) public TokenPropertiesMap;

    event setConfigEvent(address configContract);

    modifier onlyRorEnhancementContract() {
        require(_msgSender() == config.rorEnhancement(), ErrorCode.SCM_ERC721_modifer_OnlyRorEnhancement);
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert("Pausable: paused");
        }
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != config.governorAddress()) {
            revert("onlyGovernor");
        }
        _;
    }

    function ownerOfnotRequireOwned(uint256 tokenId) public view returns (address) {
        address owner = _ownerOf(tokenId);
        return owner;
    }

    function pause() public virtual onlyGovernor {
        paused = true;
    }

    function unpause() public virtual onlyGovernor {
        paused = false;
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
        userPermission = UserPermission(config.userPermission());
        emit setConfigEvent(_config);
    }

    function setIssuer(address issuer) public onlyGovernor {
        nftIssuer = issuer;
    }

    function getIssuer() public view returns (address) {
        return nftIssuer;
    }

    /// Gets the current nonce for a token ID
    function nonces(uint256 tokenId) public view returns (uint256) {
        return Counters.current(_nonces[tokenId]);
    }

    function mint(address to) public whenNotPaused CreditDoorNFTMint(userPermission.getPermission(getIssuer(), to)) onlyRorEnhancementContract returns (uint256) {
        _mint(to, ++lastTokenId);
        _nonces[lastTokenId] = Counters.Counter(1);
        return lastTokenId;
    }

    function burn(uint256 tokenId) public whenNotPaused onlyRorEnhancementContract {
        delete _nonces[tokenId];
        _burn(tokenId);
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    nameHash,
                    versionHash,
                    block.chainid,
                    address(this)
                )
            );
    }

    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public payable whenNotPaused {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, nonces(tokenId), deadline))));

        address owner = ownerOf(tokenId);
        require(spender != owner, "ERC721Permit: approval to current owner");
        require(!isContract(owner), "Invalid address");

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0), "Invalid signature");
        require(recoveredAddress == owner, "Unauthorized");
        Counters.increment(_nonces[tokenId]);
        _approve(spender, tokenId, address(0));
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused CreditDoorNFTTransfer(userPermission.getPermission(getIssuer(), to)) DebitDoorNFT(userPermission.getPermission(getIssuer(), from)) {
        require(_isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function transferFromWithoutUserPermission(address from, address to, uint256 tokenId) public whenNotPaused CreditDoorWithoutPermission(config.rorMarket()) {
        require(_isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override whenNotPaused CreditDoorNFTTransfer(userPermission.getPermission(getIssuer(), to)) DebitDoorNFT(userPermission.getPermission(getIssuer(), msg.sender)) {
        require(_isAuthorized(_ownerOf(tokenId), _msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function verifyCreditDoorNFTTransfer(address verifyAddress) public view CreditDoorNFTTransfer(userPermission.getPermission(getIssuer(), verifyAddress)) {}

    function verifyDebitDoorNFT(address verifyAddress) public view DebitDoorNFT(userPermission.getPermission(getIssuer(), verifyAddress)) {}

    function verifyCreditDoorNFTMint(address verifyAddress) public view CreditDoorNFTMint(userPermission.getPermission(getIssuer(), verifyAddress)) {}

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    // svg示例:
    // <svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' width='270px' height='270px' viewBox='0 0 270 270' enable-background='new 0 0 270 270' xml:space='preserve'><rect width='100%' height='100%' fill='#DBEAFE' /><image id='image0' width='270' height='270' x='0' y='0' /><text x='35%' y='50%' font-family='Inter' font-weight='700' font-size='20' fill='#0053F2' dominant-baseline='middle'>ROR #1</text></svg>
    // 设置SVG底图和格式，注意值都带引号，并且是双引号，需要严格符合规范
    function setSVGTemplate(string memory svg) public onlyOwner {
        SVGTemplate = svg;
    }

    // 设置SVG文字格式，注意值都带引号，并且是双引号，需要严格符合规范
    function setSVGText(string memory text) public onlyOwner {
        SVGText = text;
    }

    // 设置tokenUri的description
    function setDescription(string memory text) public onlyOwner {
        tokenURIDescription = text;
    }

    function setTokenProperties(
        uint256 tokenId,
        string memory refId,
        string memory currency,
        address ERC20Address,
        uint256 amount,
        uint256 parentTokenId,
        string memory executionDate,
        string memory comment
    ) external onlyRorEnhancementContract {
        TokenPropertiesMap[tokenId] = TokenProperties({
            refId: refId,
            currency: currency,
            ERC20Address: ERC20Address,
            amount: amount,
            parentTokenId: parentTokenId,
            executionDate: executionDate,
            comment: comment
        });
    }

    function generateAttributes(uint256 tokenId) public view returns (string memory) {
        TokenProperties memory properties = TokenPropertiesMap[tokenId];
        return
            string(
                abi.encodePacked(
                    '[{"trait_type":"Token ID","value":"',
                    Strings.toString(tokenId),
                    '"},{"trait_type":"Original Txn Ref. ID","value":"',
                    properties.refId,
                    '"},{"trait_type":"Currency","value":"',
                    properties.currency,
                    '"},{"trait_type":"Corr. ERC20 Address","value":"',
                    Strings.toHexString(uint160(properties.ERC20Address), 20),
                    '"},{"trait_type":"Amount","value":"',
                    Strings.toString(properties.amount),
                    '"},{"trait_type":"Parent Token ID","value":"',
                    properties.parentTokenId == 0 ? "N/A" : Strings.toString(properties.parentTokenId),
                    '"}]'
                )
            );
    }

    function generateDescription() public view returns (string memory) {
        return string(abi.encodePacked(tokenURIDescription));
    }

    // 生成SVG图片
    function generateSVG(uint256 tokenId) public view returns (string memory) {
        string memory text = string(abi.encodePacked("ROR #", Strings.toString(tokenId)));
        string memory svg = string(abi.encodePacked(SVGTemplate, SVGText, text, "</text></svg>"));

        string memory base64 = Base64.encode(bytes(svg));
        return string(abi.encodePacked('"data:image/svg+xml;base64,', base64, '"'));
    }

    // base64编码的tokenURI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"ROR #',
                            Strings.toString(tokenId),
                            '","attributes":',
                            generateAttributes(tokenId),
                            ',"description":"',
                            generateDescription(),
                            '","image":',
                            generateSVG(tokenId),
                            "}"
                        )
                    )
                )
            );
    }
}
