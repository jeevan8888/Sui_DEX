#[test_only]
module full_sail::rewards_pool_continuous_tests {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::coin;
    use sui::clock;
    use std::debug;
    use sui::balance::{Balance};
    use full_sail::fullsail_token::{FULLSAIL_TOKEN};
    use full_sail::rewards_pool_continuous::{Self, RewardsPool};

    // --- addresses ---
    const OWNER : address = @0xab;

    fun setup() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        let rewards_pool = rewards_pool_continuous::create(10000, scenario.ctx());
        transfer::public_transfer(rewards_pool, @0x01);
        ts::end(scenario_val);
    }

    #[test]
    public fun add_rewards_test() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        next_tx(scenario, OWNER);
        {
            let _mint_amount = 1000;
            let mut rewards_pool = ts::take_shared<RewardsPool>(scenario);
            let rewards_token = coin::mint_for_testing<FULLSAIL_TOKEN>(_mint_amount, ts::ctx(scenario));
            let rewards_balance = coin::into_balance<FULLSAIL_TOKEN>(rewards_token);
            let clock = clock::create_for_testing(ts::ctx(scenario));

            rewards_pool_continuous::add_rewards_test(&mut rewards_pool, rewards_balance, &clock);

            assert!(rewards_pool_continuous::total_unclaimed_rewards(&rewards_pool) == 1000, 2);

            clock.destroy_for_testing();
            ts::return_shared(rewards_pool);
        };

        ts::end(scenario_val);
    }

    #[test]
    public fun stake_test() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        next_tx(scenario, OWNER);
        {
            let mut rewards_pool = ts::take_shared<RewardsPool>(scenario);
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let test_addr = @0x123;

            rewards_pool_continuous::stake_test(test_addr, &mut rewards_pool, 1000, &clock);

            assert!(rewards_pool_continuous::total_stake(&rewards_pool) == 1000, 1);
            assert!(rewards_pool_continuous::claimable_rewards(test_addr,&mut rewards_pool, &clock) == 0, 1);

            clock.destroy_for_testing();
            ts::return_shared(rewards_pool);
        };
        ts::end(scenario_val);
    }
    
    #[test]
    public fun unstake_test() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        next_tx(scenario, OWNER);
        {
            let mut rewards_pool = ts::take_shared<RewardsPool>(scenario);
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let test_addr = @0x123;

            rewards_pool_continuous::stake_test(test_addr, &mut rewards_pool, 1000, &clock);
            rewards_pool_continuous::unstake_test(test_addr, &mut rewards_pool, 1000, &clock);

            assert!(rewards_pool_continuous::total_stake(&rewards_pool) == 0, 1);
            assert!(rewards_pool_continuous::claimable_rewards(test_addr,&mut rewards_pool, &clock) == 0, 1);

            clock.destroy_for_testing();
            ts::return_shared(rewards_pool);
        };
        ts::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun claim_rewards_test() : Balance<FULLSAIL_TOKEN> {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        // next_tx(scenario, OWNER);
        // {
            let mut rewards_pool = ts::take_shared<RewardsPool>(scenario);
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let test_addr = @0x123;

            rewards_pool_continuous::stake_test(test_addr, &mut rewards_pool, 1000, &clock);

            assert!(rewards_pool_continuous::total_stake(&rewards_pool) == 1000, 1);
            assert!(rewards_pool_continuous::claimable_rewards(test_addr,&mut rewards_pool, &clock) == 0, 1);

            let reward = rewards_pool_continuous::claim_rewards_test(test_addr, &mut rewards_pool, &clock);

            debug::print(&reward);

            clock.destroy_for_testing();
            ts::return_shared(rewards_pool);
        // };
        ts::end(scenario_val);
        reward
    }
}