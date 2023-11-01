// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/lib/Token.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/interfaces/IAuthorizer.sol";
import "contracts/interfaces/IVC.sol";
import "contracts/interfaces/IFacet.sol";
import "contracts/VaultStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract InspectorFacet is VaultStorage, IFacet {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address immutable thisImplementation;

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    constructor() {
        thisImplementation = address(this);
    }

    function initializeFacet() external {
        _setFunction(InspectorFacet.facets.selector, thisImplementation);
        _setFunction(InspectorFacet.facetFunctionSelectors.selector, thisImplementation);
        _setFunction(InspectorFacet.facetAddresses.selector, thisImplementation);
        _setFunction(InspectorFacet.facetAddress.selector, thisImplementation);
    }

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {
        bytes32[] memory aa = _routingTable().sigsByImplementation[_facet].values();
        assembly {
            facetFunctionSelectors_ := aa
        }
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        return _facetAddresses();
    }

    function _facetAddresses() internal view returns (address[] memory facetAddresses_) {
        bytes32[] memory sigs = _routingTable().sigs.values();
        uint256 n_uniq = 0;
        for (uint256 i = 0; i < sigs.length; i++) {
            bool uniq = true;
            for (uint256 j = 0; j < i; j++) {
                (address i1,) = _getImplementation(bytes4(sigs[i]));
                (address i2,) = _getImplementation(bytes4(sigs[j]));
                if (i1 == i2) uniq = false;
            }
            if (uniq) n_uniq++;
        }
        facetAddresses_ = new address[](n_uniq);
        for (uint256 i = 0; i < sigs.length; i++) {
            bool uniq = true;
            for (uint256 j = 0; j < i; j++) {
                (address i1,) = _getImplementation(bytes4(sigs[i]));
                (address i2,) = _getImplementation(bytes4(sigs[j]));
                if (i1 == i2) uniq = false;
            }
            if (uniq) {
                (facetAddresses_[--n_uniq],) = _getImplementation(bytes4(sigs[i]));
            }
        }
    }

    function facets() external view returns (Facet[] memory facets_) {
        address[] memory facetAddresses_ = _facetAddresses();
        facets_ = new Facet[](facetAddresses_.length);

        for (uint256 i = 0; i < facets_.length; i++) {
            facets_[i].facetAddress = facetAddresses_[i];
            bytes32[] memory aa = _routingTable().sigsByImplementation[facetAddresses_[i]].values();
            bytes4[] memory bb;
            assembly {
                bb := aa
            }
            facets_[i].functionSelectors = bb;
        }
    }

    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        (facetAddress_,) = _getImplementation(_functionSelector);
    }
}
