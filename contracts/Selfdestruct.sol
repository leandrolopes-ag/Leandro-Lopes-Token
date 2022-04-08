// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
    Only for testing ETH recovery
 */
contract SelfDestruct {
    constructor(address target) payable {
        selfdestruct(payable(target));
    }
}
