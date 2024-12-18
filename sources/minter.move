module full_sail::minter {
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use std::u64;

    use full_sail::fullsail_token::{Self, FULLSAIL_TOKEN, FullSailManager};
    use full_sail::epoch;
    use full_sail::voting_escrow::{Self, VeFullSailCollection, VeFullSailToken};

    // --- errors ---
    const E_NOT_OWNER: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_ZERO_TOTAL_POWER: u64 = 3;
    const E_MAX_LOCK_TIME: u64 = 4;

    // --- structs ---
    // otw
    public struct MINTER has drop {}

    public struct MinterConfig has key {
        id: UID,
        team_account: address,
        pending_team_account: address,
        team_emission_rate_bps: u64,
        weekly_emission_amount: u64,
        last_emission_update_epoch: u64,
    }

    public fun initialize(_otw: MINTER, ctx: &mut TxContext, clock: &Clock) {
        let recipient = tx_context::sender(ctx);
        let minter_config = MinterConfig{
            id                         : object::new(ctx),
            team_account               : recipient,
            pending_team_account       : @0x0,
            team_emission_rate_bps     : 30,
            weekly_emission_amount     : 150000000000000,
            last_emission_update_epoch : epoch::now(clock),
        };
        transfer::share_object(minter_config);
    }

    #[lint_allow(self_transfer)]
    public fun initial_mint(manager: &mut FullSailManager, collection: &mut VeFullSailCollection, clock: &Clock, ctx: &mut TxContext): VeFullSailToken<FULLSAIL_TOKEN> {
        let treasury_cap = fullsail_token::get_treasury_cap(manager);
        let recipient = tx_context::sender(ctx);
        let mut initial_mint_amount = fullsail_token::mint(
            treasury_cap, 
            100000000000000000, 
            ctx
        );

        let transfer_coin = coin::split<FULLSAIL_TOKEN>(&mut initial_mint_amount, 100000000000000000 / 5, ctx);
        transfer::public_transfer(transfer_coin, recipient);
        let ve_token = voting_escrow::create_lock_with(initial_mint_amount, voting_escrow::max_lockup_epochs(), recipient, collection, clock, ctx);
        ve_token
    }

    public fun mint(minter: &mut MinterConfig, manager: &mut FullSailManager, collection: &VeFullSailCollection, clock: &Clock, ctx: &mut TxContext): (Coin<FULLSAIL_TOKEN>, Coin<FULLSAIL_TOKEN>) {
        let rebase_amount = current_rebase(minter, manager, collection, clock);
        let current_epoch = epoch::now(clock);
        assert!(current_epoch >= minter.last_emission_update_epoch + 1, E_MAX_LOCK_TIME);
        let weekly_emission = minter.weekly_emission_amount;
        let basis_points = 10000;
        let treasury_cap = fullsail_token::get_treasury_cap(manager);
        assert!(basis_points != 0, E_ZERO_TOTAL_POWER);
        let mut minted_tokens = fullsail_token::mint(treasury_cap, weekly_emission, ctx);
        let transfer_coin = coin::split<FULLSAIL_TOKEN>(&mut minted_tokens, (((weekly_emission as u128) * (minter.team_emission_rate_bps as u128) / (basis_points as u128)) as u64), ctx);
        transfer::public_transfer(transfer_coin, minter.team_account);
        let additional_minted_tokens = if (rebase_amount == 0) {
            coin::zero<FULLSAIL_TOKEN>(ctx)
        } else {
            fullsail_token::mint(treasury_cap, (rebase_amount as u64), ctx)
        };
        let reduction_rate_bps = 10000;
        assert!(reduction_rate_bps != 0, E_ZERO_TOTAL_POWER);
        minter.weekly_emission_amount = u64::max((((weekly_emission) * ((10000 - 100)) / (reduction_rate_bps))), min_weekly_emission(manager));
        minter.last_emission_update_epoch = current_epoch;
        (minted_tokens, additional_minted_tokens)
    }

    public fun weekly_emission_reduction_rate_bps(): u64 {
        100
    }

    public fun team(minter: &MinterConfig): address {
        minter.team_account
    }

    public fun team_emission_rate_bps(minter: &MinterConfig): u64 {
        minter.team_emission_rate_bps
    }

    public entry fun update_team_account(minter: &mut MinterConfig, new_team_account: address, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == minter.team_account, E_NOT_OWNER);
        minter.pending_team_account = new_team_account;
    }

    public entry fun set_team_rate(minter: &mut MinterConfig, new_rate_bps: u64, ctx: &mut TxContext) {
        assert!(new_rate_bps <= 50, E_INSUFFICIENT_BALANCE);
        assert!(tx_context::sender(ctx) == minter.team_account, E_NOT_OWNER);
        minter.team_emission_rate_bps = new_rate_bps;
    }

    public fun mitner_addres(minter: &MinterConfig): address {
        minter.team_account
    }

    public fun min_weekly_emission(manager: &FullSailManager): u64 {
        ((fullsail_token::total_supply(manager) * 2 / 10000) as u64)
    }

    public fun initial_weekly_emission() : u64 {
        150000000000000
    }

    public fun get_init_locked_account(minter: &MinterConfig): u64 {
        let basis_points = 10000;
        (((minter.weekly_emission_amount as u128) * ((10000 - minter.team_emission_rate_bps) as u128) / (basis_points as u128)) as u64)
    }

    public fun current_weekly_emission(minter: &MinterConfig): u64 {
        minter.weekly_emission_amount
    }

    public fun set_weekly_emission(minter: &mut MinterConfig, new_weekly_emission: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == minter.team_account, E_NOT_OWNER);
        minter.weekly_emission_amount = new_weekly_emission;
    }

    public fun gauge_emission(minter: &MinterConfig) : u64 {
        let basis_points = 10000;
        assert!(basis_points != 0, E_ZERO_TOTAL_POWER);
        (((minter.weekly_emission_amount as u128) * ((10000 - minter.team_emission_rate_bps) as u128) / (basis_points as u128)) as u64)
    }

    public fun current_rebase(minter: &MinterConfig, manager: &FullSailManager, collection: &VeFullSailCollection, clock: &Clock): u128 {
        let weekly_emission = current_weekly_emission(minter);
        let total_voting_power = voting_escrow::total_voting_power(collection, clock);
        let total_supply = fullsail_token::total_supply(manager);
        assert!(total_supply != 0, E_ZERO_TOTAL_POWER);
        ((((((((((weekly_emission as u128) as u256) * (total_voting_power as u256) / (total_supply as u256)) as u128) as u256) * (total_voting_power as u256) / (total_supply as u256)) as u128) as u256) * (total_voting_power as u256) / (total_supply as u256)) as u128) / 2
    }

    public entry fun confirm_new_team_account(minter: &mut MinterConfig, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == minter.team_account, E_NOT_OWNER);
        minter.team_account = minter.pending_team_account;
        minter.pending_team_account = @0x0;
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext, clock: &Clock) {
        initialize(MINTER {}, ctx, clock)
    }
}