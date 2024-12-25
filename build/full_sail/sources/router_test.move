#[test_only]
module full_sail::router_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock;
    use full_sail::router;
    use full_sail::gauge::{Self, Gauge};
    use full_sail::liquidity_pool::{Self, LiquidityPool, LiquidityPoolConfigs, FeesAccounting};
    use full_sail::coin_wrapper::{Self, WrapperStore, WrapperStoreCap, COIN_WRAPPER};
    use full_sail::vote_manager::{Self, AdministrativeData};
    use full_sail::sui::{Self, SUI};
    use full_sail::usdt::{Self, USDT};

    const OWNER: address = @0xab;

    fun setup(scenario: &mut Scenario) {
        // Initialize all modules
        sui::init_for_testing_sui(ts::ctx(scenario));
        usdt::init_for_testing_usdt(ts::ctx(scenario));
        liquidity_pool::init_for_testing(ts::ctx(scenario));
        coin_wrapper::init_for_testing(ts::ctx(scenario));
        vote_manager::init_for_testing(ts::ctx(scenario));
        next_tx(scenario, OWNER);
        let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
        let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
        ts::return_immutable(base_metadata);
        ts::return_immutable(quote_metadata);
    }

    #[test]
    fun test_add_liquidity_and_stake_entry() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);
        let clock = clock::create_for_testing(ts::ctx(scenario));

        next_tx(scenario, OWNER);
        let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
        let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let cap = ts::take_from_sender<WrapperStoreCap>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        coin_wrapper::register_coin_for_testing<USDT>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        coin_wrapper::register_coin_for_testing<SUI>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        let (mut pool, pool_id) = gauge::create_gauge_pool_test<USDT, SUI>(
            &quote_metadata, 
            &base_metadata, 
            &mut configs, 
            false, 
            ts::ctx(scenario)
        );
        gauge::create_gauge_test<USDT, SUI>(
            &quote_metadata, 
            &base_metadata, 
            &mut configs, 
            false,
            ts::ctx(scenario)
        );

        next_tx(scenario, OWNER);
        {
            let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
            let mut gauge = ts::take_shared<Gauge<USDT, SUI>>(scenario);
            let amount = 100000;
            let base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            let base_wrapped_coin = coin_wrapper::wrap<SUI>(&mut store, base_coin, ts::ctx(scenario));
            let quote_wrapped_coin = coin_wrapper::wrap<USDT>(&mut store, quote_coin, ts::ctx(scenario));
            router::add_liquidity_and_stake_entry<USDT, SUI>(
                &mut pool,
                &mut gauge,
                &quote_metadata,
                &base_metadata,
                false,
                100000,
                100000,
                &mut store,
                &admin_data,
                &mut fees_accounting,
                &clock,
                ts::ctx(scenario)
            );

            transfer::public_transfer(base_wrapped_coin, @0xcafe);
            transfer::public_transfer(quote_wrapped_coin, @0xcafe);
            ts::return_shared(fees_accounting);
            ts::return_shared(gauge);
        };

        let all_pools = liquidity_pool::all_pool_ids(&configs);
        assert!(vector::length(&all_pools) == 2, 0);
        assert!(vector::contains(&all_pools, &pool_id), 1);

        ts::return_immutable(base_metadata);
        ts::return_immutable(quote_metadata);
        ts::return_shared(configs);
        ts::return_shared(store);
        ts::return_to_sender(scenario, cap);
        ts::return_shared(admin_data);
        clock.destroy_for_testing();
        test_utils::destroy(pool);
        ts::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_and_stake_both_coins_entry() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);
        let clock = clock::create_for_testing(ts::ctx(scenario));

        next_tx(scenario, OWNER);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let cap = ts::take_from_sender<WrapperStoreCap>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        coin_wrapper::register_coin_for_testing<USDT>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        coin_wrapper::register_coin_for_testing<SUI>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        let base_metadata = coin_wrapper::get_wrapper<SUI>(&store);
        let quote_metadata = coin_wrapper::get_wrapper<USDT>(&store);
        // ts::return_shared(store);
        next_tx(scenario, OWNER);
        
        let (mut pool, pool_id) = gauge::create_gauge_pool_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false, 
            ts::ctx(scenario)
        );
        gauge::create_gauge_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false,
            ts::ctx(scenario)
        );

        next_tx(scenario, OWNER);
        // let mut store = ts::take_shared<WrapperStore>(scenario);
        {
            let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
            let mut gauge = ts::take_shared<Gauge<COIN_WRAPPER, COIN_WRAPPER>>(scenario);
            let amount = 100000;
            let mut base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let mut quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            // let base_wrapped_coin = coin_wrapper::wrap<SUI>(&mut store, base_coin, ts::ctx(scenario));
            // let quote_wrapped_coin = coin_wrapper::wrap<USDT>(&mut store, quote_coin, ts::ctx(scenario));
            
            let base_metadata1 = coin_wrapper::get_wrapper<SUI>(&store);
            let quote_metadata1 = coin_wrapper::get_wrapper<USDT>(&store);
            let (optimal_a, optimal_b) = router::get_optimal_amounts_for_testing<COIN_WRAPPER, COIN_WRAPPER>(
                &mut pool,
                quote_metadata1,
                base_metadata1,
                100000,
                100000
            );

            let new_base_coin = coin::split(&mut base_coin, optimal_a, ts::ctx(scenario));
            let new_quote_coin = coin::split(&mut quote_coin, optimal_b, ts::ctx(scenario));
            let base_coin_opt = coin_wrapper::wrap<SUI>(&mut store, new_base_coin, ts::ctx(scenario));
            let quote_coin_opt = coin_wrapper::wrap<USDT>(&mut store, new_quote_coin, ts::ctx(scenario));
            assert!(coin::value(&base_coin_opt) == optimal_a, 2);
            assert!(coin::value(&quote_coin_opt) == optimal_b, 3);
            let base_metadata2 = coin_wrapper::get_wrapper<SUI>(&store);
            let quote_metadata2 = coin_wrapper::get_wrapper<USDT>(&store);
            gauge::stake(
                &mut gauge,
                liquidity_pool::mint_lp(
                    &mut pool, 
                    &mut fees_accounting, 
                    quote_metadata2,
                    base_metadata2,
                    base_coin_opt,
                    quote_coin_opt,
                    false,
                    ts::ctx(scenario)
                ),
                ts::ctx(scenario),
                &clock
            );
                
            transfer::public_transfer(base_coin, @0xcafe);
            transfer::public_transfer(quote_coin, @0xcafe);
            ts::return_shared(fees_accounting);
            ts::return_shared(gauge);
        };

        let all_pools = liquidity_pool::all_pool_ids(&configs);
        assert!(vector::length(&all_pools) == 2, 4);
        assert!(vector::contains(&all_pools, &pool_id), 5);

        ts::return_shared(configs);
        ts::return_shared(store);
        ts::return_to_sender(scenario, cap);
        ts::return_shared(admin_data);
        clock.destroy_for_testing();
        test_utils::destroy(pool);
        ts::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_and_stake_coin_entry() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);
        let clock = clock::create_for_testing(ts::ctx(scenario));

        next_tx(scenario, OWNER);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let cap = ts::take_from_sender<WrapperStoreCap>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        coin_wrapper::register_coin_for_testing<USDT>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        coin_wrapper::register_coin_for_testing<SUI>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        let base_metadata = coin_wrapper::get_wrapper<SUI>(&store);
        let quote_metadata = coin_wrapper::get_wrapper<USDT>(&store);
        // ts::return_shared(store);
        next_tx(scenario, OWNER);
        
        let (mut pool, pool_id) = gauge::create_gauge_pool_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false, 
            ts::ctx(scenario)
        );
        gauge::create_gauge_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false,
            ts::ctx(scenario)
        );

        next_tx(scenario, OWNER);
        // let mut store = ts::take_shared<WrapperStore>(scenario);
        {
            let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
            let mut gauge = ts::take_shared<Gauge<COIN_WRAPPER, COIN_WRAPPER>>(scenario);
            let amount = 100000;
            let mut base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let mut quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            // let base_wrapped_coin = coin_wrapper::wrap<SUI>(&mut store, base_coin, ts::ctx(scenario));
            // let quote_wrapped_coin = coin_wrapper::wrap<USDT>(&mut store, quote_coin, ts::ctx(scenario));
            
            let base_metadata1 = coin_wrapper::get_wrapper<SUI>(&store);
            let quote_metadata1 = coin_wrapper::get_wrapper<USDT>(&store);
            let (optimal_a, optimal_b) = router::get_optimal_amounts_for_testing<COIN_WRAPPER, COIN_WRAPPER>(
                &mut pool,
                quote_metadata1,
                base_metadata1,
                100000,
                100000
            );

            let new_base_coin = coin::split(&mut base_coin, optimal_a, ts::ctx(scenario));
            let new_quote_coin = coin::split(&mut quote_coin, optimal_b, ts::ctx(scenario));
            let base_coin_opt = coin_wrapper::wrap<SUI>(&mut store, new_base_coin, ts::ctx(scenario));
            let quote_coin_opt = coin_wrapper::wrap<USDT>(&mut store, new_quote_coin, ts::ctx(scenario));
            assert!(coin::value(&base_coin_opt) == optimal_a, 2);
            assert!(coin::value(&quote_coin_opt) == optimal_b, 3);
            let base_metadata2 = coin_wrapper::get_wrapper<SUI>(&store);
            let quote_metadata2 = coin_wrapper::get_wrapper<USDT>(&store);
            gauge::stake(
                &mut gauge,
                liquidity_pool::mint_lp(
                    &mut pool, 
                    &mut fees_accounting, 
                    quote_metadata2,
                    base_metadata2,
                    base_coin_opt,
                    quote_coin_opt,
                    false,
                    ts::ctx(scenario)
                ),
                ts::ctx(scenario),
                &clock
            );
                
            transfer::public_transfer(base_coin, @0xcafe);
            transfer::public_transfer(quote_coin, @0xcafe);
            ts::return_shared(fees_accounting);
            ts::return_shared(gauge);
        };

        let all_pools = liquidity_pool::all_pool_ids(&configs);
        assert!(vector::length(&all_pools) == 2, 4);
        assert!(vector::contains(&all_pools, &pool_id), 5);

        ts::return_shared(configs);
        ts::return_shared(store);
        ts::return_to_sender(scenario, cap);
        ts::return_shared(admin_data);
        clock.destroy_for_testing();
        test_utils::destroy(pool);
        ts::end(scenario_val);
    }

    #[test]
    fun test_swap_coin_for_coin_entry() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);
        let clock = clock::create_for_testing(ts::ctx(scenario));

        next_tx(scenario, OWNER);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let cap = ts::take_from_sender<WrapperStoreCap>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        coin_wrapper::register_coin_for_testing<USDT>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        coin_wrapper::register_coin_for_testing<SUI>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        let amount = 100000;
        let base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
        let quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
        let base_wrapped_coin = coin_wrapper::wrap<SUI>(&mut store, base_coin, ts::ctx(scenario));
        let quote_wrapped_coin = coin_wrapper::wrap<USDT>(&mut store, quote_coin, ts::ctx(scenario));
        let base_metadata = coin_wrapper::get_wrapper<SUI>(&store);
        let quote_metadata = coin_wrapper::get_wrapper<USDT>(&store);
        
        // ts::return_shared(store);
        next_tx(scenario, OWNER);
        
        let (mut pool, pool_id) = gauge::create_gauge_pool_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false, 
            ts::ctx(scenario)
        );
        gauge::create_gauge_test<COIN_WRAPPER, COIN_WRAPPER>(
            quote_metadata, 
            base_metadata, 
            &mut configs, 
            false,
            ts::ctx(scenario)
        );

        next_tx(scenario, OWNER);
        // let mut store = ts::take_shared<WrapperStore>(scenario);
        {
            let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
            liquidity_pool::mint_lp(
                &mut pool,
                &mut fees_accounting,
                quote_metadata,
                base_metadata,
                base_wrapped_coin,
                quote_wrapped_coin,
                false,
                ts::ctx(scenario)
            );
            let quote_coin_copy = coin_wrapper::unwrap_test<USDT>(&mut store);
            let quote_wrapped_coin_copy = coin_wrapper::wrap<USDT>(&mut store, quote_coin_copy, ts::ctx(scenario));
            let mut gauge = ts::take_shared<Gauge<COIN_WRAPPER, COIN_WRAPPER>>(scenario);
            let recipient = @0x1234;
            let base_metadata_copy = coin_wrapper::get_wrapper<SUI>(&store);
            let quote_metadata_copy = coin_wrapper::get_wrapper<USDT>(&store);
            router::swap_coin_for_coin_entry(
                &mut pool,
                quote_wrapped_coin_copy,
                10,
                &configs,
                &mut fees_accounting,
                quote_metadata_copy,
                base_metadata_copy,
                false,
                recipient,
                ts::ctx(scenario)
            );

            // transfer::public_transfer(base_wrapped_coin, @0xcafe);
            // transfer::public_transfer(quote_wrapped_coin, @0xcafe);
            ts::return_shared(fees_accounting);
            ts::return_shared(gauge);
        };

        let all_pools = liquidity_pool::all_pool_ids(&configs);
        assert!(vector::length(&all_pools) == 2, 0);
        assert!(vector::contains(&all_pools, &pool_id), 1);

        ts::return_shared(configs);
        ts::return_shared(store);
        ts::return_to_sender(scenario, cap);
        ts::return_shared(admin_data);
        clock.destroy_for_testing();
        test_utils::destroy(pool);
        ts::end(scenario_val);
    }
}