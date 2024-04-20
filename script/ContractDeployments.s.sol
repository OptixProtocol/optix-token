// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OptixToken} from "src/OptixToken.sol";
import {StakingRewards} from "src/StakingRewards.sol";
import {VestingWallet} from "src/VestingWallet.sol";

contract ContractDeployments is Script {
    OptixToken public optixToken;
    StakingRewards public stakingRewards;
    VestingWallet public vestingWallet;

    function setUp() public {
        optixToken = new OptixToken();
        vestingWallet = new VestingWallet();
        stakingRewards = new StakingRewards(address(optixToken),address(optixToken));

        address publicTokens = address(0xAD15b8d09b95ffCfd0865AF7AE61b4E88F4fF5C2);
        address liquidityTokens = address(0xA4747D8FE7e0Be4962ca376E4c33295110781A81);

        optixToken.initialize(address(vestingWallet), publicTokens, liquidityTokens);
        vestingWallet.initialize(address(optixToken));
    }

    function run() public {
        vm.broadcast();
    }
}
