// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
    Modified ERC173 Ownership contract
 */
abstract contract Ownable {
    address public owner;
    address public newOwner;

    address internal constant ZERO_ADDRESS = address(0x0);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(ZERO_ADDRESS, msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only for Owner");
        _;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() external {
        require(newOwner != ZERO_ADDRESS, "newOwner not set");
        require(msg.sender == newOwner, "Only newOwner");
        emit OwnershipTransferred(owner, newOwner);
        newOwner = ZERO_ADDRESS;
        owner = msg.sender;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, ZERO_ADDRESS);
        owner = ZERO_ADDRESS;
    }
}
