// a minimal proxy respecting ERC1967 proxy slot
// if the slot is empty, set calldataload(0) as the new implementation.
// usually deployed by another contract.

contract DumbProxy {
    constructor(address impl) {
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, impl)
        }
    }

    fallback() external payable {
        assembly {
            let storageSlot := 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
            let implementation := sload(storageSlot)
            calldatacopy(returndatasize(), returndatasize(), calldatasize())
            if implementation {
                let success :=
                    delegatecall(
                        gas(), implementation, returndatasize(), calldatasize(), returndatasize(), returndatasize()
                    )
                returndatacopy(0, 0, returndatasize())
                if success { return(0, returndatasize()) }
                revert(0, returndatasize())
            }
        }
    }
}
