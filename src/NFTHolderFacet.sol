// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "./VaultStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract NFTHolderFacet is VaultStorage, IFacet, ERC1155Holder, ERC721Holder {
    address immutable thisImplementation;

    constructor() {
        thisImplementation = address(this);
    }

    function initializeFacet() external {
        _setFunction(IERC1155Receiver.onERC1155Received.selector, thisImplementation);
        _setFunction(IERC1155Receiver.onERC1155BatchReceived.selector, thisImplementation);
        _setFunction(IERC721Receiver.onERC721Received.selector, thisImplementation);
    }
}
