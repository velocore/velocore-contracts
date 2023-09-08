import "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "src/pools/SatelliteUpgradeable.sol";

contract VelocoreGirls is ERC1155Upgradeable, SatelliteUpgradeable {
    mapping(address => bool) isMinter;

    constructor(IVault vault, address addr) Satellite(vault, addr) {}

    function contractURI() public pure returns (string memory) {
        return "https://poap.velocore.xyz/collection.json";
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        _tokenId;
        return (address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_TREASURY)))), _salePrice / 20);
    }

    function initialize() external initializer {
        __ERC1155_init("https://poap.velocore.xyz/metadata/{id}.json");
    }

    function mint(address receiver, uint256 id, uint256 amount) external {
        require(isMinter[msg.sender], "not minter");
        if (amount > 0) {
            _mint(receiver, id, amount, "");
        }
    }

    function setURI(string calldata newURI) external authenticate {
        _setURI(newURI);
    }

    function addMinter(address minter) external authenticate {
        isMinter[minter] = true;
    }

    function owner() external view returns (address) {
        return address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_TREASURY))));
    }
}

contract VelocoreGirls2 is ERC1155Upgradeable, SatelliteUpgradeable {
    mapping(address => bool) isMinter;

    constructor(IVault vault, address addr) Satellite(vault, addr) {}

    function contractURI() public pure returns (string memory) {
        return "https://poap.velocore.xyz/collection2.json";
    }

    function owner() external view returns (address) {
        return address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_TREASURY))));
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        _tokenId;
        return (address(uint160(uint256(_readVaultStorage(SSLOT_HYPERCORE_TREASURY)))), _salePrice / 20);
    }

    function initialize() external initializer {
        __ERC1155_init("https://poap.velocore.xyz/metadata/{id}.json");
    }

    function mint(address receiver, uint256 id, uint256 amount) external {
        require(isMinter[msg.sender], "not minter");
        if (amount > 0) {
            _mint(receiver, id, amount, "");
        }
    }

    function setURI(string calldata newURI) external authenticate {
        _setURI(newURI);
    }

    function addMinter(address minter) external authenticate {
        isMinter[minter] = true;
    }
}
