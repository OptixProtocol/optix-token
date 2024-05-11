// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OptixToken is ERC20, Ownable {
    bool isInitialized;

    constructor() ERC20("Optix", "OPTIX") Ownable(msg.sender) {
    }

    function initialize(address vestingWallet, address publicTokens, address liquidityTokens) public onlyOwner {
        require(!isInitialized, 'Contract is already initialized!');
        isInitialized = true;

        _mint(publicTokens, 24_000_000 * 10 ** decimals());
        _mint(liquidityTokens, 24_000_000 * 10 ** decimals());
        _mint(vestingWallet, 1_152_000_000 * 10 ** decimals());

        require(totalSupply()==1_200_000_000 * 10 ** decimals(), 'Total supply must be 1.2B!');
    }
}
