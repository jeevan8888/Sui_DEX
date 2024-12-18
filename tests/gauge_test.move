// #[test_only]
// module full_sail::gauge_test {
//     use sui::test_scenario::{Self as ts, next_tx, Scenario};
//     use sui::test_utils;
//     use sui::coin::{CoinMetadata};
//     use sui::clock;
//     use full_sail::gauge;
//     use full_sail::sui::{Self, SUI};
//     use full_sail::usdt::{Self, USDT};
//     use full_sail::liquidity_pool::{Self, LiquidityPoolConfigs, LiquidityPool};

//     const OWNER: address = @0xab;

//     #[test_only]
//     fun setup(scenario: &mut Scenario) {
//         // Initialize all modules
//         liquidity_pool::init_for_testing(ts::ctx(scenario));
//         usdt::init_for_testing_usdt(ts::ctx(scenario));
//         sui::init_for_testing_sui(ts::ctx(scenario));
//     }

//     #[test]
//     public fun create_test() {
//         let mut scenario_val = ts::begin(OWNER);
//         let scenario = &mut scenario_val;

//         setup(scenario);

//         next_tx(scenario, OWNER);
//         {
//             let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
//             let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
//             let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
//             liquidity_pool::create<USDT, SUI>(
//                 &base_metadata,
//                 &quote_metadata,
//                 &mut configs,
//                 false,
//                 ts::ctx(scenario)
//             );
            
//             ts::return_shared(configs);
//             ts::return_immutable(base_metadata);
//             ts::return_immutable(quote_metadata);
//         };
        
//         next_tx(scenario, OWNER);
//         {
//             let clock = clock::create_for_testing(ts::ctx(scenario));
//             let _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
//             let mut _gauge = gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
//             assert!(gauge::claimable_rewards(@0x01, &mut _gauge, &clock) == 0, 1);
//             test_utils::destroy(_gauge);
//             clock.destroy_for_testing();
//         };

//         ts::end(scenario_val);
//     }

//     #[test]
//     public fun stake_test() : () {
//         let mut scenario_val = ts::begin(OWNER);
//         let scenario = &mut scenario_val;
        
//         setup(scenario);
        
//         next_tx(scenario, OWNER);
//         {
//             let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
//             let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
//             let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
//             liquidity_pool::create<SUI, USDT>(
//                 &base_metadata,
//                 &quote_metadata,
//                 &mut configs,
//                 false,
//                 ts::ctx(scenario)
//             );
            
//             ts::return_shared(configs);
//             ts::return_immutable(base_metadata);
//             ts::return_immutable(quote_metadata);
//         };

//         next_tx(scenario, OWNER);
//         {
//             let clock = clock::create_for_testing(ts::ctx(scenario));
//             let mut _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
//             let mut _gauge = gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
//             let user_address = tx_context::sender(ts::ctx(scenario));

//             gauge::stake(&mut _gauge, 100, ts::ctx(scenario), &clock);

//             let _stake_balance = gauge::stake_balance(user_address, &mut _gauge);
//             let _total_stake_balance = gauge::total_stake(&mut _gauge);

//             assert!(_stake_balance == 100, 1);
//             assert!(_total_stake_balance == 100, 2);

//             test_utils::destroy(_gauge);
//             clock.destroy_for_testing();
//         };
//         ts::end(scenario_val);
//     }

//     #[test]
//     public fun unstake_test() {
//         let mut scenario_val = ts::begin(OWNER);
//         let scenario = &mut scenario_val;
        
//         setup(scenario);
        
//         next_tx(scenario, OWNER);
//         {
//             let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
//             let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
//             let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
//             liquidity_pool::create<SUI, USDT>(
//                 &base_metadata,
//                 &quote_metadata,
//                 &mut configs,
//                 false,
//                 ts::ctx(scenario)
//             );
            
//             ts::return_shared(configs);
//             ts::return_immutable(base_metadata);
//             ts::return_immutable(quote_metadata);
//         };

//         next_tx(scenario, OWNER);
//         {
//             let clock = clock::create_for_testing(ts::ctx(scenario));
//             let mut _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
//             let mut _gauge = gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
//             let user_address = tx_context::sender(ts::ctx(scenario));

//             gauge::stake(&mut _gauge, 100, ts::ctx(scenario), &clock);

//             let _stake_balance = gauge::stake_balance(user_address, &mut _gauge);
//             let _total_stake_balance = gauge::total_stake(&mut _gauge);

//             assert!(_stake_balance == 100, 1);
//             assert!(_total_stake_balance == 100, 2);

//             gauge::unstake_lp(&mut _gauge, 50, ts::ctx(scenario), &clock);
//             let _stake_balance = gauge::stake_balance(user_address, &mut _gauge);

//             assert!(_stake_balance == 50, 3);

//             test_utils::destroy(_gauge);
//             clock.destroy_for_testing();
//         };
//         ts::end(scenario_val);
//     }

//     #[test]
//     public fun claim_rewards_test() {
//         let mut scenario_val = ts::begin(OWNER);
//         let scenario = &mut scenario_val;
        
//         setup(scenario);
        
//         next_tx(scenario, OWNER);
//         {
//             let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
//             let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
//             let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
//             liquidity_pool::create<SUI, USDT>(
//                 &base_metadata,
//                 &quote_metadata,
//                 &mut configs,
//                 false,
//                 ts::ctx(scenario)
//             );
            
//             ts::return_shared(configs);
//             ts::return_immutable(base_metadata);
//             ts::return_immutable(quote_metadata);
//         };

//         next_tx(scenario, OWNER);
//         {
//             let clock = clock::create_for_testing(ts::ctx(scenario));
//             let mut _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
//             let mut _gauge = gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
//             let user_address = tx_context::sender(ts::ctx(scenario));

//             let _claimable_rewards = gauge::claimable_rewards(user_address, &mut _gauge, &clock);
//             assert!(_claimable_rewards == 0, 1);

//             test_utils::destroy(_gauge);
//             clock.destroy_for_testing();
//         };
//         ts::end(scenario_val);
//     }
// }