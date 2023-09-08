import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "./VelocoreGirls.sol";

contract LinearVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    uint256 public immutable vestBeginning;
    uint256 public immutable vestDuration;

    mapping(address => uint256) public claimableTotal;
    mapping(address => uint256) public claimed;
    mapping(address => bool) public registered;

    event ClaimVesting(address addr, uint256 amount);

    constructor(IERC20 rewardToken_, uint256 vestBeginning_, uint256 vestDuration_) {
        rewardToken = rewardToken_;
        vestBeginning = vestBeginning_;
        vestDuration = vestDuration_;
    }

    function _grantVestedReward(address addr, uint256 amount) internal {
        require(!registered[addr], "already registered");
        claimableTotal[addr] = amount;
        registered[addr] = true;
    }

    function claim3(address addr) public nonReentrant returns (uint256) {
        require(registered[addr]);
        uint256 vested = 0;
        if (block.timestamp < vestBeginning) {
            vested = 0;
        } else if (block.timestamp >= vestBeginning + vestDuration) {
            vested = claimableTotal[addr];
        } else {
            vested = Math.mulDiv(claimableTotal[addr], block.timestamp - vestBeginning, vestDuration);
        }

        uint256 delta = vested - claimed[addr];
        claimed[addr] = vested;

        rewardToken.safeTransfer(addr, delta);
        emit ClaimVesting(addr, delta);
        return delta;
    }
}

contract Airdrop is LinearVesting {
    using SafeERC20 for IERC20;

    bytes32 public constant root = 0x14525031c4dec8bf83d547eb3503072d167592cd447414e4025ffbd37412ed32;
    VelocoreGirls public immutable girls;

    VelocoreGirls2 public immutable girls2;

    uint256 constant REWARD_PER_TIER = 250_000e18;
    uint256 public constant REWARD_1 = REWARD_PER_TIER / 12818;
    uint256 public constant REWARD_2 = REWARD_PER_TIER / 3385;
    uint256 public constant REWARD_3 = REWARD_PER_TIER / 100;
    uint256 public constant REWARD_4 = REWARD_PER_TIER / 100;

    event ClaimNFT(address addr, uint256 a1, uint256 a2, uint256 a3, uint256 a4);

    constructor(
        VelocoreGirls girls_,
        VelocoreGirls2 girls2_,
        IERC20 rewardToken_,
        uint256 vestBeginning_,
        uint256 vestDuration_
    ) LinearVesting(rewardToken_, vestBeginning_, vestDuration_) {
        girls = girls_;
        girls2 = girls2_;
    }

    function claimNFT(bytes32[] memory proof, bool p1, bool p2, bool p3, bool p4, uint256 airdrop, uint256 premining)
        public
    {
        require(!registered[msg.sender], "Already claimed");

        uint256 total = premining;

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, p1, p2, p3, p4, airdrop, premining))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");

        if (p1) {
            girls.mint(msg.sender, 7, 1);
            total += REWARD_1;
        }
        if (p2) {
            girls.mint(msg.sender, 8, 1);
            total += REWARD_2;
        }
        if (p3) {
            girls2.mint(msg.sender, 9, 1);
            total += REWARD_3;
        }
        if (p4) {
            girls2.mint(msg.sender, 10, 1);
            total += REWARD_4;
        }

        _grantVestedReward(msg.sender, total * 0.465556e18 / 1e18);
    }
}

contract Airdrop2 is LinearVesting {
    using SafeERC20 for IERC20;

    bytes32 public constant root = 0x14525031c4dec8bf83d547eb3503072d167592cd447414e4025ffbd37412ed32;
    VelocoreGirls public immutable girls;

    event ClaimNFT(address addr, uint256 a1, uint256 a2, uint256 a3, uint256 a4);

    constructor(VelocoreGirls girls_, IERC20 rewardToken_, uint256 vestBeginning_, uint256 vestDuration_)
        LinearVesting(rewardToken_, vestBeginning_, vestDuration_)
    {
        girls = girls_;
    }

    function claimNFT(bytes32[] memory proof, bool p1, bool p2, bool p3, bool p4, uint256 airdrop, uint256 premining)
        public
    {
        require(!registered[msg.sender], "Already claimed");

        uint256 total = airdrop;

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, p1, p2, p3, p4, airdrop, premining))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");

        _grantVestedReward(msg.sender, total * 0.465556e18 / 1e18);
    }
}
