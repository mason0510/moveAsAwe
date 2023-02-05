## 0x01 一句话简述

Airdropper 合约即是基于 Aptos 的空投工具 —— 可以针对 Aptos 地址列表进行 Coins 空投。

也是在 MoveDID 的基础上的延伸 —— MoveDID 将 Aptos, Ethereum 等多种格式的地址和 Github Account 相绑定，从而可以针对某个 Repo 或 Organization 下的所有 Contributors 进行批量空投。

##0x02 Airdropper 合约源码全面解析

###2.1 合约基本结构

```rust
module my_addr::airdropper {
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::guid;

    use std::error;
    use std::signer;
    use std::vector;
    use std::option::Option;
    use std::string::{String};

    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};

    use aptos_token::token::{Token, TokenId};

    const EAIRDROP_NOT_EXIST: u64 = 1;
    const EINVALID_OWNER: u64 = 2;
    const EOWNER_NOT_HAVING_ENOUGH_COIN: u64 = 3;
    const EOWNER_NOT_HAVING_ENOUGH_TOKEN: u64 = 4;
    const EAIRDROPER_NOT_RECEIVER: u64 = 5;
    const ERROR_NOT_ENOUGH_LENGTH: u64 = 6;

		
    struct AirdropCap has key {
			cap: SignerCapability,
		}

    struct AirdropCoinEvent has drop, store {
        sender_address: address,
        description: String,
        coin_amount: u64,
        timestamp: u64,
        receiver_address: address,
    }

    struct AirdropTokenEvent has drop, store {
        airdrop_id: u64,
        sender_address: address,
        token_id: TokenId,
        amount: u64,
        timestamp: u64,
        receiver_address: address,
    }

    struct ClaimTokenEvent has drop, store {
        airdrop_id: u64,
        sender_address: address,
        token_id: TokenId,
        amount: u64,
        timestamp: u64,
        claimer_address: address,
    }

    struct AirdropTokenItem has store {
        airdrop_id: u64,
        locked_token: Option<Token>,
        timestamp: u64,
        sender_address: address,
        receiver_address: address,
    }

    struct AirdropItemsData has key {
        airdrop_items: Table<u64, AirdropTokenItem>,
        airdrop_coin_events: EventHandle<AirdropCoinEvent>,
        airdrop_token_events: EventHandle<AirdropTokenEvent>,
        claim_token_events: EventHandle<ClaimTokenEvent>,
    }

    // get signer unique id for airdrop
    fun get_unique_airdrop_id() : u64 acquires AirdropCap {
				……
        airdrop_id
    }

    fun get_airdrop_signer_address() : address acquires AirdropCap {
				……
        airdrop_signer_address
    }

    // call after you deploy
    public entry fun initialize_script(sender: &signer) {
        ……
    }

    fun airdrop_coin<CoinType>(
        sender: &signer,
        description: String,
        receiver: address,
        amount: u64,
    ) acquires AirdropCap, AirdropItemsData {
        ……
    }

    public entry fun airdrop_coins_average_script<CoinType>(
        sender: &signer,
        description: String,
        receivers: vector<address>,
        uint_amount: u64,
    ) acquires AirdropCap, AirdropItemsData {
        l……
    }

    public entry fun airdrop_coins_not_average_script<CoinType>(
        sender: &signer,
        description: String, 
        receivers: vector<address>,
        amounts: vector<u64>,
    ) acquires AirdropCap, AirdropItemsData {
        ……
    }

    # tests
}
```

### 2.2 关键函数

#### 2.2.1 入口函数：`public entry fun`

**入口函数列表：**

-  `public entry fun initialize_script(sender: &signer) `：初始化 `AirdropCap`。
- `public entry fun airdrop_coins_average_script<CoinType>(……)acquires AirdropCap, AirdropItemsData`：等额空投
- `public entry fun airdrop_coins_not_average_script<CoinType>(……)acquires AirdropCap, AirdropItemsData `：不等额空投

##### 2.2.1.1 知识点之函数修饰符 —— 函数修饰符的安全性检查是很重要的

> https://aptos.dev/guides/move-guides/move-on-aptos/#visibility

- 默认情况下，函数是私有的，这意味着它们只能被同一文件中的其他函数调用。 您可以使用可见性修饰符 [public、public(entry) 等] 使该函数在文件外部可用。 例如：
- entry - 通过使函数成为实际的入口函数来隔离调用函数，防止重新进入（导致编译器错误）
- public - 允许任何人从任何地方调用该函数
- public(entry) - 只允许相关事务中定义的方法调用函数
- public(friend) - 用于声明当前模块信任的模块。
- public(script) - 允许在 Aptos 网络上提交、编译和执行任意 Move 代码

##### 2.2.1.2 知识点之 Acquires 

> https://aptos.dev/guides/move-guides/move-structure/#acquires

任何时候你需要使用任何全局资源，比如一个结构，你应该首先获取它。 例如，存入和提取一个 NFT 都会获取 TokenStore。 如果您在不同的模块中有一个函数调用模块内部的函数来获取资源，则不必将第一个函数标记为 acquires()。

这使得所有权清晰，因为资源存储在帐户内。 帐户可以决定是否可以在那里创建资源。 定义该资源的模块有权读取和修改该结构。 因此该模块内的代码需要显式获取该结构。

尽管如此，在 Move 中借用或移动的任何地方，您都会自动获取资源。 为清楚起见，使用 acquire 明确包含。 同样，exists() 函数不需要 acquires() 函数。

注意：您可以从您自己的模块中定义的结构中的任何帐户借用模块中的全局。 您不能在模块外借用 global。

##### 2.2.1.3 `public entry fun initialize_script(sender: &signer)`

```rust
    public entry fun initialize_script(sender: &signer) {
      	// 获取 sender 地址
        let sender_addr = signer::address_of(sender);
				// 需要 sender 和部署人一致
        assert!(sender_addr == @my_addr, error::invalid_argument(EINVALID_OWNER));
				// 创建资源账户: 
      	//https://aptos.dev/guides/move-guides/mint-nft-cli/#2-use-resource-account-for-automation
      	// https://aptos.dev/guides/resource-accounts/#:~:text=The%20easiest%20way%20to%20set,under%20the%20resource%20account's%20adddress.
        let (airdrop_signer, airdrop_cap) = account::create_resource_account(sender, x"01");
				// 获取资源账户地址
      	let airdrop_signer_address = signer::address_of(&airdrop_signer);
		// 移动 AirdropCap 到 sender
		if(!exists<AirdropCap>(@my_addr)){
            move_to(sender, AirdropCap {
                cap: airdrop_cap
            })
		};
		// 移动 AirdropItemsData 到 airdrop_signer, AirdropItemsData 用于存储所有 Events
        if (!exists<AirdropItemsData>(airdrop_signer_address)) {
            move_to(&airdrop_signer, AirdropItemsData {
                airdrop_items: table::new(),
                airdrop_coin_events: account::new_event_handle<AirdropCoinEvent>(&airdrop_signer),
                airdrop_token_events: account::new_event_handle<AirdropTokenEvent>(&airdrop_signer),
                claim_token_events: account::new_event_handle<ClaimTokenEvent>(&airdrop_signer),
            });
		};
    }
```

> **💡 Resource Account**
>
> 资源帐户是一种开发人员功能，用于管理独立于用户管理的帐户的资源，特别是发布模块和自动签署交易。 例如，开发人员可以使用资源帐户来管理用于模块发布的帐户，例如管理合约。 合同本身不需要签名者初始化后。 资源帐户为您提供了模块向其他模块提供签名者并代表模块签署交易的方法。
>
> 通常，资源帐户用于两个主要目的：
>
> **存储和隔离资源：** 一个模块创建一个资源帐户只是为了托管特定的资源。
> **将模块作为独立（资源）帐户发布：**这是去中心化设计中的一个构建块，其中没有私钥可以控制资源帐户。 所有权 (SignerCap) 可以保存在另一个模块中，例如治理。

##### 2.2.1.4 `public entry fun airdrop_coins_average_script<CoinType>`

```rust
    public entry fun airdrop_coins_average_script<CoinType>(
        sender: &signer,
        description: String,
        receivers: vector<address>,
        uint_amount: u64,
    ) acquires AirdropCap, AirdropItemsData {
        let sender_addr = signer::address_of(sender);
        let length_receiver = vector::length(&receivers);
        // 确保地址金额足够
        assert!(coin::balance<CoinType>(sender_addr) >= length_receiver * uint_amount, error::invalid_argument(EOWNER_NOT_HAVING_ENOUGH_COIN));
				
        let i = length_receiver;
				// 循环空投
        while (i > 0) {
            let receiver_address = vector::pop_back(&mut receivers);
            airdrop_coin<CoinType>(sender, description, receiver_address, uint_amount);
				// 调用子函数
            i = i - 1;
        }
    }
```

##### 2.2.1.5 `public entry fun airdrop_coins_not_average_script<CoinType>`

```rust
    public entry fun airdrop_coins_not_average_script<CoinType>(
        sender: &signer,
        description: String, 
        receivers: vector<address>,
        amounts: vector<u64>,
    ) acquires AirdropCap, AirdropItemsData {
        let sender_addr = signer::address_of(sender);
        let length_receiver = vector::length(&receivers);
        let length_amounts = vector::length(&amounts);

        assert!(length_receiver == length_amounts, ERROR_NOT_ENOUGH_LENGTH);

        let y = length_amounts;
				
        // 获取金额总数
        let total_amount = 0;
        let calculation_amounts = amounts;

        while (y > 0) {
            let amount = vector::pop_back(&mut calculation_amounts);
            total_amount = total_amount + amount;
            y = y - 1;
        };

        // 判断金额足够
        assert!(coin::balance<CoinType>(sender_addr) >= total_amount, error::invalid_argument(EOWNER_NOT_HAVING_ENOUGH_COIN));

        let i = length_receiver;
				// 循环空投
        while (i > 0) {
            let receiver_address = vector::pop_back(&mut receivers);
            let amount = vector::pop_back(&mut amounts);
            airdrop_coin<CoinType>(sender, description, receiver_address, amount);

            i = i - 1;
        }
    }
```

#### 2.2.2 二级函数：`fun`

#### 2.2.2.1 获取签名人地址 — 资源账户

```rust
    fun get_airdrop_signer_address() : address acquires AirdropCap {
        let airdrop_cap = &borrow_global<AirdropCap>(@my_addr).cap;
        let airdrop_signer = &account::create_signer_with_capability(airdrop_cap);
        let airdrop_signer_address = signer::address_of(airdrop_signer);

        airdrop_signer_address
    }
```

> https://aptos.dev/guides/move-guides/move-on-aptos/#resource-accounts

💡资源账户的签名者获取方式

由于 Move 模型通常需要了解交易的签名者，因此 Aptos 提供了用于分配签名者能力的资源帐户。 创建资源帐户可以访问签名者功能以供自动使用。 签名者能力可以由资源账户的签名者结合创建资源账户的源账户的地址来检索，或者放置在模块本地存储中。 请参阅 create_nft_with_resource_account.move 中的 resource_signer_cap 参考。

当您创建资源帐户时，您还授予该帐户**签名者能力**。 签名者能力中的唯一字段是签名者的地址。 要查看我们如何从签名者功能创建签名者，请查看 create_nft_with_resource_account.move 中的 let resource_signer 函数。

// TODO: ff 的描述

> https://github.com/aptos-labs/aptos-core/blob/916d8b40232040ce1eeefbb0278411c5007a26e8/aptos-move/move-examples/mint_nft/2-Using-Resource-Account/sources/create_nft_with_resource_account.move#L156

```rust
let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
let token_id = token::mint_token(&resource_signer, module_data.token_data_id, 1);
token::direct_transfer(&resource_signer, receiver, token_id, 1);
```

#### 2.2.2.2 `fun airdrop_coin<CoinType>`

```rust
    fun airdrop_coin<CoinType>(
        sender: &signer,
        description: String,
        receiver: address,
        amount: u64,
    ) acquires AirdropCap, AirdropItemsData {
        let sender_addr = signer::address_of(sender);
        let airdrop_signer_address = get_airdrop_signer_address();
        let airdrop_items_data = borrow_global_mut<AirdropItemsData>(airdrop_signer_address);

        // 转账操作
        coin::transfer<CoinType>(sender, receiver, amount);
				
      	//写入 Event
        event::emit_event<AirdropCoinEvent>(
            &mut airdrop_items_data.airdrop_coin_events,
            AirdropCoinEvent { 
                receiver_address: receiver,
                description: description,
                sender_address: sender_addr,
                coin_amount: amount,
                timestamp: timestamp::now_seconds(),
            },
        );
    }
```

### 2.3 测试代码



## 0x03 Airdropper dApp 源码全面解析



