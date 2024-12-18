#[test_only]
module full_sail::fullsail_token_tests {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::coin::{Self, Coin};

    // --- modules ---
    use full_sail::fullsail_token::{Self, FullSailManager, FULLSAIL_TOKEN};

    // --- errors ---
    const E_INCORRECT_MINT_AMOUNT: u64 = 1;
    const E_INCORRECT_TOTAL_SUPPLY: u64 = 2;
    const E_INCORRECT_SENDER_BALANCE: u64 = 3;
    const E_INCORRECT_RECIPIENT_BALANCE: u64 = 4;

    // --- addresses ---
    const OWNER : address = @0xab;
    const RECIPIENT: address = @0xcd;

    fun setup() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        fullsail_token::init_for_testing(scenario.ctx());

        ts::end(scenario_val);
    }

    // test mint
    #[test]
    fun test_mint() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        next_tx(scenario, OWNER);
        {
            let mut manager = ts::take_shared<FullSailManager>(scenario);
            let treasurycap = fullsail_token::cap(&mut manager);

            let minted_coin = fullsail_token::mint(treasurycap, 100, ts::ctx(scenario));

            assert!(coin::value(&minted_coin) == 100, E_INCORRECT_MINT_AMOUNT);
            transfer::public_transfer(minted_coin, OWNER);
            ts::return_shared(manager);
        };

        ts::end(scenario_val);
    }

    // test burn
    #[test]
    fun test_burn() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        next_tx(scenario, OWNER);
        {
            let mut manager = ts::take_shared<FullSailManager>(scenario);
            let treasurycap = fullsail_token::cap(&mut manager);

            let minted_coin = fullsail_token::mint(treasurycap, 100, ts::ctx(scenario));

            fullsail_token::burn(treasurycap, minted_coin);

            assert!(fullsail_token::total_supply(&manager) == 0, E_INCORRECT_TOTAL_SUPPLY);

            ts::return_shared(manager);
        };

        ts::end(scenario_val);
    }

    #[test]
    fun test_transfer() {
        setup();
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        // mint coins
        next_tx(scenario, OWNER);
        {
            let mut manager = ts::take_shared<FullSailManager>(scenario);
            let treasurycap = fullsail_token::cap(&mut manager);
            
            let coins = fullsail_token::mint(treasurycap, 100, ts::ctx(scenario));
            transfer::public_transfer(coins, OWNER);
            
            ts::return_shared(manager);
        };

        next_tx(scenario, OWNER);
        {
            let mut manager = ts::take_shared<FullSailManager>(scenario);
            let treasurycap = fullsail_token::cap(&mut manager);
            
            let coins = fullsail_token::mint(treasurycap, 100, ts::ctx(scenario));
            
            // freeze 
            fullsail_token::freeze_transfers(coins);
            
            ts::return_shared(manager);
        };

        // transfer
        next_tx(scenario, OWNER);
        {
            let mut coins = ts::take_from_sender<Coin<FULLSAIL_TOKEN>>(scenario);
            
            fullsail_token::transfer(&mut coins, 30, RECIPIENT, ts::ctx(scenario));
            
            assert!(coin::value(&coins) == 70, E_INCORRECT_SENDER_BALANCE);
            transfer::public_transfer(coins, OWNER);
        };

        // check recipient balance
        next_tx(scenario, RECIPIENT);
        {
            let received_coins = ts::take_from_sender<Coin<FULLSAIL_TOKEN>>(scenario);
            assert!(coin::value(&received_coins) == 30, E_INCORRECT_RECIPIENT_BALANCE);
            transfer::public_transfer(received_coins, RECIPIENT);
        };

        ts::end(scenario_val);
    }
}
