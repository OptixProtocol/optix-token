// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";



interface IVesting {
   
     function registerVestingSchedule(
        address _addressToRegister,
        uint _startTimeInSec,
        uint _cliffTimeInSec,
        uint _endTimeInSec,
        uint _unlockAmount,
        uint _totalAmount
    ) external ;
} 


contract OptixToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bool isInitialized = false;

    constructor() ERC20("Optix", "OPTIX") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize(IVesting vestingWallet) public onlyRole(DEFAULT_ADMIN_ROLE){
        require(!isInitialized, 'Contract is already initialized!');
        _grantRole(MINTER_ROLE, address(vestingWallet));

        isInitialized = true;

//Type: Team
//Tokens: 180M 1.8E+26
//TGE Unlock: 0% 0
//Cliff: 12 Months
//Vesting: 2% linear monthly (50 months)
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1686751200 Thu, 15 Jun 2023 00:00:00 GMT
//End Time:  1786716000 Sat, 15 Aug 2026 00:00:00 GMT
vestingWallet.registerVestingSchedule(0x5Cf047BE700DDE3960E3A83612909a34781731C0,1655215200,1686751200,1786716000,0,180000000000000000000000000);

//Type: Foundation
//Tokens: 120M 1.2E+26
//TGE Unlock: 0% 0
//Cliff: 1 Month
//Vesting: 3% linear monthly (34 months)
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1657807200 Fri, 15 Jul 2022 00:00:00 GMT
//End Time:  1744639200 Tue, 15 Apr 2025 00:00:00 GMT
vestingWallet.registerVestingSchedule(0x887014570F14c58c8551eCDa3D156E4662D92A43,1655215200,1657807200,1744639200,0,120000000000000000000000000);

//Type: Ecosystem Reward
//Tokens: 664.8M  6.648E+26
//TGE Unlock: 0%  0
//Cliff Months: 1
//Vesting: 2% linear monthly (50 months)
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1657807200 Fri, 15 Jul 2022 00:00:00 GMT
//End Time:  1786716000 Sat, 15 Aug 2026 00:00:00 GMT
vestingWallet.registerVestingSchedule(0x196cE66307d36dD036c577FD9C93f36A56d3a6c3,1655215200,1657807200,1786716000,0,664800000000000000000000000);

//Type: Liquidity
//Tokens: 24M 2.4E+25
//TGE Unlock: 100% 2.4E+25
//Cliff Months: 0
//Vesting: n/a
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//End Time:  1655215200 Wed, 15 Jun 2022 00:00:00 GMT
vestingWallet.registerVestingSchedule(0xc7618f514027F9fca8B778E19185F2720AF4d225,1655215200,1655215200,1655215200,24000000000000000000000000,24000000000000000000000000);

//Type: Seed
//Tokens: 204M 2.04E+26
//TGE Unlock: 5% 1.02E+25
//Cliff Months: 0
//Vesting: 5% linear monthly (20 months)
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//End Time:  1707919200 Thu, 15 Feb 2024 00:00:00 GMT
vestingWallet.registerVestingSchedule(0x5eeEB41feE9F46cE1B0E219244D83C68d245DCAC,1655215200,1655215200,1707919200,10200000000000000000000000,204000000000000000000000000);

//Type: Public
//Tokens: 7.2M 7.2E+24
//TGE Unlock: 100% 7.2E+24
//Cliff Months: 0
//Vesting: n/a
//Start Time: 1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//Cliff Time:  1655215200 Wed, 15 Jun 2022 00:00:00 GMT
//End Time:  1655215200 Wed, 15 Jun 2022 00:00:00 GMT
vestingWallet.registerVestingSchedule(0xA5bF3dD5ae768A49387284f65c95c475DF776527,1655215200,1655215200,1655215200,7200000000000000000000000,7200000000000000000000000);

    }


    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }


}
