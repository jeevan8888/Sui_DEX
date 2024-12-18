module full_sail::router {
    use sui::coin::{Self, Coin, CoinMetadata};
    use full_sail::coin_wrapper::{Self, WrapperStore, COIN_WRAPPER};
    use full_sail::liquidity_pool::{Self, LiquidityPool, FeesAccounting, LiquidityPoolConfigs};
    use full_sail::token_whitelist::{Self, TokenWhitelist, TokenWhitelistAdminCap, RewardTokenWhitelistPerPool};
    use full_sail::gauge::{Self, Gauge};
    use full_sail::vote_manager::{Self, AdministrativeData};
    use sui::clock::{Clock};
    use std::debug;

    // --- addresses ---
    const DEFAULT_ADMIN: address = @0x123;

    // --- errors ---
    const E_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 1;
    const E_ZERO_RESERVE: u64 = 2;
    const E_VECTOR_LENGTH_MISMATCH: u64 = 3;
    const E_OUTPUT_IS_WRAPPER: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 6;
    const E_ZERO_AMOUNT: u64 = 7;
    
    public fun swap<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        input_coin: Coin<BaseType>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        ctx: &mut TxContext
    ): Coin<QuoteType> {
        let output_coin = liquidity_pool::swap<BaseType, QuoteType>(
            pool,
            configs,
            fees_accounting,
            base_metadata,
            quote_metadata,
            input_coin,
            ctx
        );
        assert!(coin::value(&output_coin) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        output_coin
    }

    public fun get_amount_out(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        input_amount: u64,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
    ): (u64, u64) {
        liquidity_pool::get_amount_out(
            pool,
            base_metadata,
            quote_metadata,
            input_amount
        )
    }

    public fun get_trade_diff<BaseType, QuoteType>(
        configs: &LiquidityPoolConfigs,
        input_amount: u64,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        input_metadata: &CoinMetadata<BaseType>,
        is_stable: bool
    ): (u64, u64) {
        liquidity_pool::get_trade_diff(
            liquidity_pool::liquidity_pool(configs, base_metadata, quote_metadata, is_stable),
            base_metadata,
            quote_metadata,
            input_metadata,
            input_amount
        )
    }

    public fun add_liquidity<BaseType, QuoteType>(
        _coin_a: Coin<BaseType>,
        _coin_b: Coin<QuoteType>,
        _is_stable: bool,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun add_liquidity_and_stake_entry<BaseType, QuoteType> (
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        gauge: &mut Gauge<BaseType, QuoteType>,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        amount_a: u64,
        amount_b: u64,
        store: &mut WrapperStore,
        admin_data: &AdministrativeData,
        fees_accounting: &mut FeesAccounting,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (optimal_a, optimal_b) = get_optimal_amounts<BaseType, QuoteType>(
            pool,
            // coin_wrapper::get_wrapper<BaseType>(store),
            // coin_wrapper::get_wrapper<QuoteType>(store),
            base_metadata,
            quote_metadata,
            amount_a, 
            amount_b
        );

        let input_base_coin = coin_wrapper::borrow_original_coin<BaseType>(store);
        // let new_base_coin = coin_wrapper::wrap(store, coin::split(input_base_coin, optimal_a, ctx), ctx);
        let new_base_coin = coin::split(input_base_coin, optimal_a, ctx);

        let input_quote_coin = coin_wrapper::borrow_original_coin<QuoteType>(store);
        // let new_quote_coin = coin_wrapper::wrap(store, coin::split(input_quote_coin, optimal_b, ctx), ctx);
        let new_quote_coin = coin::split(input_quote_coin, optimal_b, ctx);

        let lp_tokens = liquidity_pool::mint_lp(
            pool, 
            fees_accounting, 
            // coin_wrapper::get_wrapper<BaseType>(store),
            // coin_wrapper::get_wrapper<QuoteType>(store),
            base_metadata,
            quote_metadata,
            new_base_coin,
            new_quote_coin,
            is_stable, 
            ctx
        );
        gauge::stake(
            gauge,
            lp_tokens,
            ctx,
            clock
        );
    }

    public entry fun add_liquidity_and_stake_coin_entry<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        gauge: &mut Gauge<BaseType, QuoteType>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        input_amount: u64,
        output_amount: u64,
        store: &mut WrapperStore,
        admin_data: &AdministrativeData,
        fees_accounting: &mut FeesAccounting,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (optimal_a, optimal_b) = get_optimal_amounts<COIN_WRAPPER, COIN_WRAPPER>(
            pool,
            coin_wrapper::get_wrapper<QuoteType>(store),
            quote_metadata,
            input_amount, 
            output_amount
        );

        let base_coin = exact_withdraw<BaseType>(optimal_a, store, ctx);
        let quote_coin = exact_withdraw<QuoteType>(optimal_b, store, ctx);

        assert!(coin::value(&base_coin) == optimal_a, E_INSUFFICIENT_OUTPUT_AMOUNT);
        assert!(coin::value(&quote_coin) == optimal_b, E_INSUFFICIENT_OUTPUT_AMOUNT);
        gauge::stake(
            gauge,
            liquidity_pool::mint_lp(
                pool, 
                fees_accounting, 
                coin_wrapper::get_wrapper<BaseType>(store),
                quote_metadata,
                base_coin,
                quote_coin,
                is_stable,
                ctx
            ),
            ctx,
            clock
        );
    }

    public entry fun add_liquidity_and_stake_both_coins_entry<BaseType, QuoteType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        gauge: &mut Gauge<COIN_WRAPPER, COIN_WRAPPER>,
        is_stable: bool,
        input_amount: u64,
        output_amount: u64,
        store: &mut WrapperStore,
        admin_data: &AdministrativeData,
        fees_accounting: &mut FeesAccounting,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);
        let quote_metadata = coin_wrapper::get_wrapper<QuoteType>(store);
        let (optimal_a, optimal_b) = get_optimal_amounts<COIN_WRAPPER, COIN_WRAPPER>(
            pool,
            base_metadata,
            quote_metadata,
            input_amount, 
            output_amount
        );

        let base_coin = exact_withdraw<BaseType>(optimal_a, store, ctx);
        let quote_coin = exact_withdraw<QuoteType>(optimal_b, store, ctx);
        assert!(coin::value(&base_coin) == optimal_a, E_INSUFFICIENT_OUTPUT_AMOUNT);
        assert!(coin::value(&quote_coin) == optimal_b, E_INSUFFICIENT_OUTPUT_AMOUNT);
        let base_metadata1 = coin_wrapper::get_wrapper<BaseType>(store);
        let quote_metadata1 = coin_wrapper::get_wrapper<QuoteType>(store);
        gauge::stake(
            gauge,
            liquidity_pool::mint_lp(
                pool, 
                fees_accounting, 
                base_metadata1,
                quote_metadata1,
                base_coin,
                quote_coin,
                is_stable,
                ctx
            ),
            ctx,
            clock
        );
    }

    public entry fun create_pool<BaseType, QuoteType>(
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        configs: &mut LiquidityPoolConfigs,
        admin_cap: &TokenWhitelistAdminCap,
        pool_whitelist: &mut RewardTokenWhitelistPerPool,
        admin_data: &mut AdministrativeData,
        store: &WrapperStore,
        is_stable: bool,
        ctx: &mut TxContext
    ) {
        let pool = liquidity_pool::create<BaseType, QuoteType>(
            base_metadata, 
            quote_metadata, 
            configs, 
            is_stable, 
            ctx
        );
        vote_manager::whitelist_default_reward_pool(
            liquidity_pool::liquidity_pool(
                configs,
                base_metadata,
                quote_metadata,
                is_stable
            ),
            base_metadata,
            quote_metadata,
            admin_cap,
            pool_whitelist,
            store
        );
        // vote_manager::create_gauge_internal<BaseType, QuoteType>(
        //     admin_data, 
        //     liquidity_pool::liquidity_pool(
        //         configs,
        //         base_metadata,
        //         quote_metadata,
        //         is_stable
        //     ), 
        //     ctx
        // );
    }

    public entry fun create_pool_both_coins<BaseType, QuoteType>(
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        store: &WrapperStore,
        ctx: &mut TxContext
    ) {
        let pool = liquidity_pool::create<COIN_WRAPPER, COIN_WRAPPER>(
            coin_wrapper::get_wrapper<BaseType>(store),
            coin_wrapper::get_wrapper<QuoteType>(store),
            configs,
            is_stable,
            ctx
        );
        // vote_manager::whitelist_default_reward_pool(pool);
        // vote_manager::create_gauge_internal(pool);
    }

    public entry fun create_pool_coin<BaseType>(
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        store: &WrapperStore,
        ctx: &mut TxContext
    ) {
        let pool = liquidity_pool::create<COIN_WRAPPER, COIN_WRAPPER>(
            coin_wrapper::get_wrapper<BaseType>(store),
            quote_metadata,
            configs,
            is_stable,
            ctx
        );
        // vote_manager::whitelist_default_reward_pool(pool);
        // vote_manager::create_gauge_internal(pool);
    }

    public fun quote_liquidity<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        base_metadata: &CoinMetadata<BaseType>, 
        quote_metadata: &CoinMetadata<QuoteType>,
        input_amount: u64
    ): u64 {
        let (reserve_amount_1, reserve_amount_2) = liquidity_pool::pool_reserves<BaseType, QuoteType>(
            pool//liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable)
        );

        let mut reserve_in = reserve_amount_1;
        let mut reserve_out = reserve_amount_2;
        if(!liquidity_pool::is_sorted(base_metadata, quote_metadata)) {
            reserve_out = reserve_amount_1;
            reserve_in = reserve_amount_2;
        };
        if(reserve_in == 0 || reserve_out == 0) {
            0
        } else {
            assert!(reserve_in != 0, E_ZERO_RESERVE);
            (((input_amount as u128) * (reserve_out as u128) / (reserve_in as u128)) as u64)
        }
    }

    fun get_optimal_amounts<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        input_amount: u64,
        output_amount: u64
    ): (u64, u64) {
        assert!(input_amount > 0 && output_amount > 0, E_ZERO_AMOUNT);

        let output = quote_liquidity(pool, base_metadata, quote_metadata, input_amount);
        if(output == 0) {
            (input_amount, output_amount)
        } else if(output <= output_amount) {
            (input_amount, output)
        } else {
            (
                quote_liquidity(
                    pool, 
                    base_metadata, 
                    quote_metadata, 
                    output_amount
                ), 
                output_amount
            )
        }
    }

    public(package) fun exact_deposit<BaseType>(recipient: address, asset: Coin<BaseType>) {
        transfer::public_transfer(asset, recipient);
    }

    public(package) fun exact_withdraw<BaseType>(
        amount: u64, 
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        let input_base_coin = coin_wrapper::borrow_original_coin<BaseType>(store);
        let new_base_coin = coin::split(input_base_coin, amount, ctx);
        assert!(coin::value(&new_base_coin) == amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        coin_wrapper::wrap(store, new_base_coin, ctx)
    }

    public fun get_amounts_out(
        // pool_id: &mut UID, 
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>, 
        input_amount: u64, 
        token_in: &CoinMetadata<COIN_WRAPPER>, 
        intermediary_tokens: &mut vector<CoinMetadata<COIN_WRAPPER>>, 
        is_stable: &mut vector<bool>
    ): u64 {
        assert!(vector::length(intermediary_tokens) == vector::length(is_stable), E_VECTOR_LENGTH_MISMATCH);
        vector::reverse(intermediary_tokens);
        vector::reverse(is_stable);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = input_amount;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let (amount_out, _) = get_amount_out(
                pool, 
                current_amount, 
                token_in, 
                &next_token, 
            );
            current_amount = amount_out;
            token_count = token_count - 1;
            transfer::public_transfer(next_token, @0x0);
        };
        current_amount
    }

    public fun liquidity_amount_out<BaseType, QuoteType>(
        configs: &LiquidityPoolConfigs,
        base_metadata: &CoinMetadata<BaseType>, 
        quote_metadata: &CoinMetadata<QuoteType>, 
        is_stable: bool, 
        input_amount: u64, 
        output_amount: u64
    ): u64 {
        liquidity_pool::liquidity_out(
            liquidity_pool::liquidity_pool(configs, base_metadata, quote_metadata, is_stable), 
            base_metadata, 
            quote_metadata, 
            input_amount, 
            output_amount, 
            is_stable
        )
    }

    fun remove_liquidity_internal<BaseType, QuoteType>(
        // pool_id: &mut UID, 
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        lp_amount: u64, 
        min_input_amount: u64,
        min_output_amount: u64,
        ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        let (coin_in, coin_out) = liquidity_pool::burn<BaseType, QuoteType>(
            pool,//liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable),
            lp_amount,
            ctx
        );
        assert!(coin::value(&coin_in) >= min_input_amount && coin::value(&coin_out) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        (coin_in, coin_out)
    }

    public fun redeemable_liquidity<BaseType, QuoteType>(
        configs: &LiquidityPoolConfigs,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        liquidity_amount: u64
    ): (u64, u64) {
        liquidity_pool::liquidity_amounts<BaseType, QuoteType>(
            liquidity_pool::liquidity_pool(
                configs,
                base_metadata,
                quote_metadata,
                is_stable
            ),
            liquidity_amount
        )
    }

    public fun remove_liquidity<BaseType, QuoteType>(
        _base_metadata: &CoinMetadata<BaseType>,
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public fun remove_liquidity_both_coins<BaseType, QuoteType>(
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public entry fun remove_liquidity_both_coins_entry<BaseType, QuoteType>(
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public fun remove_liquidity_coin<BaseType, QuoteType>(
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public entry fun remove_liquidity_coin_entry<BaseType, QuoteType>(
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public entry fun remove_liquidity_entry<BaseType, QuoteType>(
        _base_metadata: &CoinMetadata<BaseType>,
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public fun swap_router(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>, 
        input_amount: Coin<COIN_WRAPPER>, 
        token_in: &CoinMetadata<COIN_WRAPPER>, 
        intermediary_tokens: &mut vector<CoinMetadata<COIN_WRAPPER>>,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        min_output_amount: u64,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        vector::reverse(intermediary_tokens);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = input_amount;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let coin_in = current_amount;
            let amount_out = swap(
                pool, 
                coin_in, 
                min_output_amount,
                configs,
                fees_accounting,
                token_in, 
                &next_token, 
                ctx
            );
            current_amount = amount_out;
            token_count = token_count - 1; 
            transfer::public_transfer(next_token, @0x0);
        };
        assert!(coin::value(&current_amount) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        current_amount
    }

    public fun swap_coin_for_coin(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        // pool_id: &mut UID,
        input_coin: Coin<COIN_WRAPPER>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        swap(
            pool, 
            input_coin, 
            min_output_amount, 
            configs, 
            fees_accounting, 
            base_metadata, 
            quote_metadata, 
            ctx
        )
    }

    public entry fun swap_coin_for_coin_entry(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        input_coin: Coin<COIN_WRAPPER>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        recipient: address,
        ctx: &mut TxContext
    ) {
        exact_deposit(
            recipient, 
            swap_coin_for_coin(
                pool, 
                input_coin, 
                min_output_amount, 
                configs, 
                fees_accounting, 
                base_metadata, 
                quote_metadata, 
                ctx
            )
        );
    }

    public entry fun swap_entry<BaseType, QuoteType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        input_amount: u64, 
        min_output_amount: u64,
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>, 
        quote_metadata: &CoinMetadata<COIN_WRAPPER>, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        // assert!(!coin_wrapper::is_wrapper(quote_metadata), E_OUTPUT_IS_WRAPPER);
        exact_deposit(
            recipient,
            swap<COIN_WRAPPER, COIN_WRAPPER>(
                pool, 
                exact_withdraw<BaseType>(
                    input_amount,
                    store,
                    ctx
                ),
                min_output_amount, 
                configs, 
                fees_accounting, 
                base_metadata, 
                quote_metadata, 
                ctx
            )
        );
    }

    public entry fun swap_route_entry<QuoteType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        min_output_amount: u64, 
        input_coin: Coin<COIN_WRAPPER>,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        intermediary_tokens: vector<CoinMetadata<COIN_WRAPPER>>, 
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        let mut intermediary_tokens_mut = intermediary_tokens;
        exact_deposit(
            recipient, 
            swap_router(
                pool,
                input_coin,
                base_metadata,
                &mut intermediary_tokens_mut,
                configs,
                fees_accounting,
                min_output_amount,
                ctx
            )
        );
        vector::destroy_empty<CoinMetadata<COIN_WRAPPER>>(intermediary_tokens_mut);
    }

    public entry fun swap_route_entry_both_coins<BaseType, QuoteType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        input_amount: u64, 
        min_output_amount: u64, 
        intermediary_tokens: vector<CoinMetadata<COIN_WRAPPER>>, 
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        let mut intermediary_tokens_mut = intermediary_tokens;
        let base_coin = exact_withdraw<BaseType>(
            input_amount,
            store,
            ctx
        );
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);

        exact_deposit<QuoteType>(
            recipient, 
            coin_wrapper::unwrap<QuoteType>(
                store,
                swap_router(
                    pool,
                    base_coin,
                    base_metadata,
                    &mut intermediary_tokens_mut,
                    configs,
                    fees_accounting,
                    min_output_amount,
                    ctx
                )
            )
        );
        vector::destroy_empty<CoinMetadata<COIN_WRAPPER>>(intermediary_tokens_mut);
    }

    public entry fun swap_route_entry_from_coin<BaseType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        input_amount: u64, 
        min_output_amount: u64, 
        intermediary_tokens: vector<CoinMetadata<COIN_WRAPPER>>, 
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        let mut intermediary_tokens_mut = intermediary_tokens;
        let base_coin = exact_withdraw<BaseType>(
            input_amount,
            store,
            ctx
        );
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);

        exact_deposit(
            recipient, 
            swap_router(
                pool,
                base_coin,
                base_metadata,
                &mut intermediary_tokens_mut,
                configs,
                fees_accounting,
                min_output_amount,
                ctx
            )
        );
        vector::destroy_empty<CoinMetadata<COIN_WRAPPER>>(intermediary_tokens_mut);
    }

    public entry fun swap_route_entry_to_coin<QuoteType>(
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        min_output_amount: u64, 
        input_coin: Coin<COIN_WRAPPER>,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        intermediary_tokens: vector<CoinMetadata<COIN_WRAPPER>>, 
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        let mut intermediary_tokens_mut = intermediary_tokens;
        exact_deposit(
            recipient, 
            coin_wrapper::unwrap<QuoteType>(
                store,
                swap_router(
                    pool,
                    input_coin,
                    base_metadata,
                    &mut intermediary_tokens_mut,
                    configs,
                    fees_accounting,
                    min_output_amount,
                    ctx
                )
            )
        );
        vector::destroy_empty<CoinMetadata<COIN_WRAPPER>>(intermediary_tokens_mut);
    }

    public entry fun unstake_and_remove_liquidity_both_coins_entry<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        gauge: &mut Gauge<COIN_WRAPPER, COIN_WRAPPER>,
        is_stable: bool,
        store: &WrapperStore,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);
        let quote_metadata = coin_wrapper::get_wrapper<QuoteType>(store);
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            gauge,
            lp_amount,
            ctx,
            clock
        );
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }

    public entry fun unstake_and_remove_liquidity_coin_entry<BaseType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        gauge: &mut Gauge<COIN_WRAPPER, COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        store: &WrapperStore,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            gauge,
            lp_amount,
            ctx,
            clock
        ); 
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }

    public entry fun unstake_and_remove_liquidity_entry(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<COIN_WRAPPER, COIN_WRAPPER>,
        gauge: &mut Gauge<COIN_WRAPPER, COIN_WRAPPER>,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            gauge,
            lp_amount,
            ctx,
            clock
        ); 
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }

    #[test_only]
    public fun get_optimal_amounts_for_testing<BaseType, QuoteType>(
        // pool_id: &mut UID,
        pool: &mut LiquidityPool<BaseType, QuoteType>,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        input_amount: u64,
        output_amount: u64
    ): (u64, u64) {
        get_optimal_amounts(
            pool,
            base_metadata,
            quote_metadata,
            input_amount,
            output_amount
        )
    }
}