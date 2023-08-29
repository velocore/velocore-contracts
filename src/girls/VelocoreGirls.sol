
contract VelocoreGirls is
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    SatelliteUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return
            ERC1155Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    function contractURI() public pure returns (string memory) {
        return "https://poap.velocore.xyz/collection.json";
    }

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        _tokenId;
        return (owner(), _salePrice / 20);
    }

    function initialize(
        address admin,
        string calldata uri_
    ) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        __AccessControl_init();
        __ERC1155_init(uri_);
    }

    function mint(
        address receiver,
        uint256 id,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        if (amount > 0) {
            _mint(receiver, id, amount, "");
        }
    }

    function setURI(
        string calldata newURI
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newURI);
    }
}