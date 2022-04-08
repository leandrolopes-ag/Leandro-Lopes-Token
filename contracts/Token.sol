// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./ERC20.sol";
import "./ERC2612.sol";
import "./ERC3009.sol";
import "./Recover.sol";

/**
    ERC20 token contract for LeandroLopes project
 */
contract LLT is ERC20, ERC2612, ERC3009, Recover {
    //
    // constructor
    //

    /**
        Contract constructor
        @param tokenName token name
        @param tokenSymbol token symbol
        @param contractVersion contract version
        @param supply token supply minted to deployer
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        string memory contractVersion,
        uint256 supply
    ) ERC20(tokenName, tokenSymbol) {
        // generate domainSeparator for EIP712
        uint256 chainId = block.chainid;
        DOMAIN_SEPARATOR = EIP712.makeDomainSeparator(
            tokenName,
            contractVersion,
            chainId
        );
        CHAINID = chainId;
        EIP712_DOMAIN_TYPEHASH = EIP712.EIP712_DOMAIN_TYPEHASH;
        // mint tokens
        _balances[msg.sender] = supply;
        _supply = supply;
        emit Transfer(ZERO_ADDRESS, msg.sender, supply);
    }
}
