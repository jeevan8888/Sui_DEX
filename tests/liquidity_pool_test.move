#[test_only]
module full_sail::liquidity_pool_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::coin::{Self, CoinMetadata};
    
    // --- modules ---
    use full_sail::liquidity_pool::{Self, LiquidityPoolConfigs, LiquidityPool, FeesAccounting};
    use full_sail::sui::{Self, SUI};
    use full_sail::usdt::{Self, USDT};
    
    // --- addresses ---
    const OWNER: address = @0xab;

    fun setup(scenario: &mut Scenario) {
        // Initialize all modules
        liquidity_pool::init_for_testing(ts::ctx(scenario));
        usdt::init_for_testing_usdt(ts::ctx(scenario));
        sui::init_for_testing_sui(ts::ctx(scenario));
    }

    // test create lp
    #[test]
    fun test_create() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            let pool_id = liquidity_pool::create<SUI, USDT>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            // verify creation
            let all_pools = liquidity_pool::all_pool_ids(&configs);
            assert!(vector::length(&all_pools) == 1, 0);
            assert!(vector::contains(&all_pools, &pool_id), 1);
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let fees = ts::take_shared<FeesAccounting>(scenario);
            let pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            
            // verify pool properties
            assert!(!liquidity_pool::is_stable(&pool), 2);
            let (base_reserve, quote_reserve) = liquidity_pool::pool_reserves(&pool);
            assert!(base_reserve == 0, 3);
            assert!(quote_reserve == 0, 4);
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(configs);
            ts::return_shared(fees);
        };
        
        ts::end(scenario_val);
    }

    // test mint
    #[test]
    fun test_mint_lp() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            let pool_id = liquidity_pool::create<SUI, USDT>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            let all_pools = liquidity_pool::all_pool_ids(&configs);
            assert!(vector::length(&all_pools) == 1, 0);
            assert!(vector::contains(&all_pools, &pool_id), 1);
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            let amount = 100000;
            let base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            
            let liquidity_out = liquidity_pool::mint_lp(
                &mut pool,
                &mut fees,
                &quote_metadata,
                &base_metadata,
                quote_coin,
                base_coin,    
                false,
                ts::ctx(scenario)
            );
            
            // expected: sqrt(100000 * 100000) - 1000 = 100000 - 1000 = 99000
            assert!(liquidity_out == 99000, 2);
            
            let (base_reserve, quote_reserve) = liquidity_pool::pool_reserves(&pool);
            assert!(base_reserve == amount, 3);
            assert!(quote_reserve == amount, 4);
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        ts::end(scenario_val);
    }

    // test swap
    #[test]
    fun test_swap() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            liquidity_pool::create<SUI, USDT>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            // add 100k of each token as initial liquidity
            let base_coin = coin::mint_for_testing<SUI>(100000, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<USDT>(100000, ts::ctx(scenario));
            
            // mint lp
            liquidity_pool::mint_lp(
                &mut pool,
                &mut fees,
                &quote_metadata,
                &base_metadata,
                quote_coin,
                base_coin,    
                false,
                ts::ctx(scenario)
            );
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            let (initial_base_reserve, initial_quote_reserve) = liquidity_pool::pool_reserves(&pool);
            let (initial_fee_base, _initial_fee_quote) = liquidity_pool::gauge_claimable_fees(&pool);
            
            // swap - USDT to SUI
            let amount_in = 10000;
            let coin_in = coin::mint_for_testing<USDT>(amount_in, ts::ctx(scenario));
            
            // swap
            let coin_out = liquidity_pool::swap(
                &mut pool,
                &configs,
                &mut fees,
                &base_metadata,
                &quote_metadata,
                coin_in,
                ts::ctx(scenario)
            );
            
            let (final_base_reserve, final_quote_reserve) = liquidity_pool::pool_reserves(&pool);
            assert!(final_base_reserve > initial_base_reserve, 0); // base reserve increased
            assert!(final_quote_reserve < initial_quote_reserve, 1); // quote reserve decreased
            
            let (final_fee_base, _final_fee_quote) = liquidity_pool::gauge_claimable_fees(&pool);
            assert!(final_fee_base > initial_fee_base, 2); 
            
            // verify output amount (approximately 9900 considering 1% fee)
            let output_amount = coin::value(&coin_out);
            assert!(output_amount > 8900 && output_amount < 9100, 3); 
            
            transfer::public_transfer(coin_out, OWNER);
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(configs);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        ts::end(scenario_val);
    }

    // test claim fees
    #[test]
    fun test_claim_fees() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            liquidity_pool::create<USDT, SUI>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            let base_coin = coin::mint_for_testing<USDT>(100000, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<SUI>(100000, ts::ctx(scenario));
            
            liquidity_pool::mint_lp(
                &mut pool,
                &mut fees,
                &base_metadata,
                &quote_metadata,
                base_coin,
                quote_coin,    
                false,
                ts::ctx(scenario)
            );
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        // some swaps to generate fees
        next_tx(scenario, OWNER);
        {
            let configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            // 10k USDT -> SUI swap
            let coin_in = coin::mint_for_testing<USDT>(10000, ts::ctx(scenario));
            let coin_out = liquidity_pool::swap(
                &mut pool,
                &configs,
                &mut fees,
                &base_metadata,
                &quote_metadata,
                coin_in,
                ts::ctx(scenario)
            );
            
            transfer::public_transfer(coin_out, OWNER);
            
            // verify fees were collected
            let (base_fees, quote_fees) = liquidity_pool::gauge_claimable_fees(&pool);
            assert!(base_fees == 10, 0); // 1% of 10000
            assert!(quote_fees == 0, 1);   // no quote fees yet
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(configs);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            
            let (initial_base_fees, initial_quote_fees) = liquidity_pool::gauge_claimable_fees(&pool);
            assert!(initial_base_fees == 10, 2); // 1% of 10000 USDT
            assert!(initial_quote_fees == 0, 3);
            
            // claim fees
            let (base_fee_coin, quote_fee_coin) = liquidity_pool::claim_fees(
                &mut pool,
                ts::ctx(scenario)
            );
            
            // verify claimed amounts
            assert!(coin::value(&base_fee_coin) == 10, 4); // USDT fees claimed
            assert!(coin::value(&quote_fee_coin) == 0, 5);  // no SUI fees to claim
            
            // verify fees were deducted from pool
            let (final_base_fees, final_quote_fees) = liquidity_pool::gauge_claimable_fees(&pool);
            assert!(final_base_fees == 0, 6); // USDT fees claimed
            assert!(final_quote_fees == 0, 7); // SUI fees
            
            // clean up fee coins
            transfer::public_transfer(base_fee_coin, OWNER);
            transfer::public_transfer(quote_fee_coin, OWNER);
            
            ts::return_to_sender(scenario, pool);
        };
        
        // verify claiming again yields zero
        next_tx(scenario, OWNER);
        {
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            
            let (base_fee_coin, quote_fee_coin) = liquidity_pool::claim_fees(
                &mut pool,
                ts::ctx(scenario)
            );
            
            // verify zero fees claimed
            assert!(coin::value(&base_fee_coin) == 0, 8);
            assert!(coin::value(&quote_fee_coin) == 0, 9);
            
            transfer::public_transfer(base_fee_coin, OWNER);
            transfer::public_transfer(quote_fee_coin, OWNER);
            
            ts::return_to_sender(scenario, pool);
        };
        
        ts::end(scenario_val);
    }

    #[test]
    fun test_burn() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            liquidity_pool::create<USDT, SUI>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            let initial_base = 100000;
            let initial_quote = 100000;
            
            let base_coin = coin::mint_for_testing<USDT>(initial_base, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<SUI>(initial_quote, ts::ctx(scenario));
            
            let liquidity_amount = liquidity_pool::mint_lp(
                &mut pool,
                &mut fees,
                &base_metadata,
                &quote_metadata,
                base_coin,
                quote_coin,    
                false,
                ts::ctx(scenario)
            );
            
            let (base_reserve, quote_reserve) = liquidity_pool::pool_reserves(&pool);
            assert!(base_reserve == initial_base, 0);
            assert!(quote_reserve == initial_quote, 1);
            assert!(liquidity_amount == 99000, 2);
            
            ts::return_to_sender(scenario, pool);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        // Test burn
        next_tx(scenario, OWNER);
        {
            let mut pool = ts::take_from_sender<LiquidityPool<USDT, SUI>>(scenario);
            
            let burn_amount = 50000; // burn about half the liquidity
            
            // calculate expected amounts
            let (base_reserve, quote_reserve) = liquidity_pool::pool_reserves(&pool);
            let total_supply = liquidity_pool::total_supply(&pool);
            
            let expected_base = (((burn_amount as u128) * (base_reserve as u128)) / total_supply) as u64;
            let expected_quote = (((burn_amount as u128) * (quote_reserve as u128)) / total_supply) as u64;
            
            // burn LP tokens
            let (base_coin, quote_coin) = liquidity_pool::burn(
                &mut pool,
                burn_amount,
                ts::ctx(scenario)
            );
            
            // verify received amounts
            assert!(coin::value(&base_coin) == expected_base, 3);
            assert!(coin::value(&quote_coin) == expected_quote, 4);
            
            // verify final reserves
            let (final_base, final_quote) = liquidity_pool::pool_reserves(&pool);
            assert!(final_base == base_reserve - expected_base, 5);
            assert!(final_quote == quote_reserve - expected_quote, 6);
            
            transfer::public_transfer(base_coin, OWNER);
            transfer::public_transfer(quote_coin, OWNER);
            
            ts::return_to_sender(scenario, pool);
        };
        
        ts::end(scenario_val);
    }

}