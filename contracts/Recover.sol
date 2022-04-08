// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";

// Rouge tokens and ETH withdrawal
abstract contract Recover is Ownable {
    string internal constant ERR_NTR = "Nothing to recover";

    function recover(address token, uint256 amount) external virtual onlyOwner {
        if (token == ZERO_ADDRESS) {
            uint256 balance = address(this).balance;
            require(balance > 0, ERR_NTR);
            if (amount > 0 && amount < balance) balance = amount;
            payable(owner).transfer(balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            require(balance > 0, ERR_NTR);
            if (amount > 0 && amount < balance) balance = amount;
            require(IERC20(token).transfer(owner, balance), "");
        }
    }
}
