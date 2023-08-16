// This is the code Vault address will actually hold.

// a Diamond proxy with two ingrained functions
// implementation addresses will be stored on the last 2^32 slots. in other words, bitwise_not(msg.sig).
// the value will be either:
// 1. implementation address --> normal function
// 2. bitwise_not(implementation address) --> view function, implemented with the ingrained function 2

// on creation, it delegatecalls back to the caller.
// the caller is expected to initialize the storage.

// ingrained function 1: 'read' (0x72656164)
// a cheap way to read storage slots
// other contracts are expected to directly read predefined storage slots using this mechanism.
// expected calldata:
//    0x72656164 | bytes32 | bytes32 | bytes32 ... (no length header)
//    the query is interpreted as a series of storage slots.
// returns:
//    bytes32 | bytes32 | bytes32 | ....
//    returns storage values without header

// ingraned function 2: 'view' (0x76696577)
// delegatecall any contract; revert if the call didn't, and vice versa.
// used to calculate the result of a state-modifying function, without actually modifying the state.
// expected calldata: 0x76696577 | destination address padded to 32 bytes | calldata to be forwarded

contract Diamond {
    constructor() {
        assembly {
            let success := delegatecall(gas(), caller(), 0, 0, 0, 0)
            if iszero(success) { revert(0, 0) }
        }
    }

    fallback() external payable {
        assembly {
            if calldatasize() {
                let selector := shr(0xe0, calldataload(0x00))
                if eq(selector, 0x72656164) {
                    // 'read'
                    for { let i := 4 } lt(i, calldatasize()) { i := add(i, 0x20) } { mstore(i, sload(calldataload(i))) }
                    return(4, sub(calldatasize(), 4))
                }
                if eq(selector, 0x76696577) {
                    // view
                    calldatacopy(0, 36, sub(calldatasize(), 36))
                    let success := delegatecall(gas(), calldataload(4), 0, sub(calldatasize(), 36), 0, 0)
                    returndatacopy(0, 0, returndatasize())
                    if success { revert(0, returndatasize()) }
                    return(0, returndatasize())
                }
                let implementation := sload(not(selector))
                if implementation {
                    if lt(implementation, 0x10000000000000000000000000000000000000000) {
                        // registered as a function
                        calldatacopy(0, 0, calldatasize())
                        let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
                        returndatacopy(0, 0, returndatasize())
                        switch result
                        case 0 { revert(0, returndatasize()) }
                        default { return(0, returndatasize()) }
                    }
                    // registered as a view function
                    mstore(0, 0x7669657700000000000000000000000000000000000000000000000000000000)
                    mstore(4, not(implementation))
                    calldatacopy(36, 0, calldatasize())
                    let success := delegatecall(gas(), address(), 0, add(calldatasize(), 36), 0, 0)
                    returndatacopy(0, 0, returndatasize())
                    if success { revert(0, returndatasize()) }
                    return(0, returndatasize())
                }
                revert(0, 0)
            }
        }
    }
}
