// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/lib/Token.sol";
import "contracts/interfaces/IVault.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IAuthorizer.sol";
import "contracts/pools/Satellite.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Voter is Satellite {
    using TokenLib for Token;

    Token immutable ballot;
    address public owner;

    event Owner(address);

    constructor(address owner_, IVault vault_, Token ballot_) Satellite(vault_, msg.sender) {
        owner = owner_;
        ballot = ballot_;
        emit Owner(owner);
    }

    function execute(Token[] memory tokenRef, int128[] memory, VelocoreOperation[] memory ops) external {
        require(msg.sender == owner, "not owner");
        for (uint256 i = 0; i < ops.length; i++) {
            require(ops[i].poolId[0] == bytes1(0x03) || ops[i].poolId[0] == bytes1(0x04), "unauthorized");

            if (ops[i].poolId[0] == bytes1(0x04)) {
                for (uint256 j = 0; j < ops[i].tokenInformations.length; j++) {
                    require(tokenRef[uint8(ops[i].tokenInformations[j][0])] != ballot, "cannot withdraw ballot");
                }
            }
        }
        vault.execute(tokenRef, new int128[](tokenRef.length), ops);
    }

    function sudo_execute(Token[] memory tokenRef, int128[] memory, VelocoreOperation[] memory ops)
        external
        authenticate
    {
        vault.execute(tokenRef, new int128[](tokenRef.length), ops);
    }

    function changeOwner(address newOwner) external {
        require(msg.sender == owner, "not owner");
        owner = newOwner;
        emit Owner(newOwner);
    }

    function withdrawTokens(Token[] memory tokens) external authenticate {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].transferFrom(address(this), msg.sender, tokens[i].balanceOf(address(this)));
        }
    }
}

contract VoterFactory is Satellite {
    using TokenLib for Token;

    Token immutable ballot;

    event VoterCreated(address owner, uint256 amount, address voter);

    constructor(IVault vault_, Token ballot_) Satellite(vault_, address(this)) {
        ballot = ballot_;
    }

    function deploy(address owner, uint256 amount) external authenticate returns (address) {
        Voter voter = new Voter(owner, vault, ballot);
        ballot.transferFrom(msg.sender, address(voter), amount);
        emit VoterCreated(owner, amount, address(voter));

        return address(voter);
    }
}
