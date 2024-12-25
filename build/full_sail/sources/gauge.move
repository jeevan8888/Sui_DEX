module full_sail::gauge {
    use full_sail::rewards_pool_continuous::{Self, RewardsPool};
    use full_sail::liquidity_pool::{Self, LiquidityPool, LiquidityPoolConfigs};
    use full_sail::fullsail_token::{FULLSAIL_TOKEN};

    use sui::coin::{Coin, CoinMetadata};
    use sui::balance::{Balance};
    use sui::clock::{Clock};
    use sui::event;
    
    public struct Gauge<phantom BaseType, phantom QuoteType> has key, store {
        id: UID,
        rewards_pool: RewardsPool,
        liquidity_pool: LiquidityPool<BaseType, QuoteType>,
    }

    public struct StakeEvent has copy, drop {
        lp: address, 
        // gauge: Gauge<BaseType, QuoteType>,
        amount: u64,
    }

    public struct UnstakeEvent has copy, drop {
        lp: address,
        // gauge: sui::object::Object<Gauge>,
        amount: u64,
    }

    public fun liquidity_pool<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : &mut LiquidityPool<BaseType, QuoteType> {
        &mut gauge.liquidity_pool
    }

    public fun claim_fees<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, ctx: &mut TxContext): (Coin<BaseType>, Coin<QuoteType>) {
        let liquidity_pool = liquidity_pool(gauge);
        liquidity_pool::claim_fees(liquidity_pool, ctx)
    }

    public fun add_rewards<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, balance: Balance<FULLSAIL_TOKEN>, clock: &Clock) {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::add_rewards(rewards_pool, balance, clock);
    }

    public fun claim_rewards<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, ctx: &mut TxContext, clock: &Clock) : Balance<FULLSAIL_TOKEN> {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::claim_rewards(tx_context::sender(ctx), rewards_pool, clock)
    }

    public fun claimable_rewards<BaseType, QuoteType>(user_address: address, gauge: &mut Gauge<BaseType, QuoteType>, clock: &Clock) : u64 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::claimable_rewards(user_address, rewards_pool, clock)
    }

    //#[allow(lint(self_transfer))]
    public fun create<BaseType, QuoteType>(liquidity_pool: LiquidityPool<BaseType, QuoteType>, ctx: &mut TxContext): ID {
        let gauge = Gauge<BaseType, QuoteType> {
            id: object::new(ctx),
            rewards_pool: rewards_pool_continuous::create(rewards_duration(), ctx),
            liquidity_pool: liquidity_pool,
        };
        let gauge_id = object::id(&gauge);
        transfer::share_object(gauge);
        gauge_id
    }

    public fun transfer_gauge<BaseType, QuoteType>(gauge: Gauge<BaseType, QuoteType>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(gauge, sender);
    }

    public fun stake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext, clock: &Clock) {
        // let liquidity_pool = liquidity_pool(gauge);
        // liquidity_pool::transfer(arg0, sui::object::convert<temp::liquidity_pool::LiquidityPool, temp::liquidity_pool::LiquidityPool>(v0), sui::object::object_address<Gauge>(&arg1), arg2);
        let user_address = tx_context::sender(ctx);
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::stake(user_address, rewards_pool, amount, clock);
        event::emit(StakeEvent { lp: user_address, amount: amount })
    }

    public fun stake_balance<BaseType, QuoteType>(user_address: address, gauge: &mut Gauge<BaseType, QuoteType>) : u64 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::stake_balance(user_address, rewards_pool)
    }

    public fun total_stake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : u128 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::total_stake(rewards_pool)
    }

    public entry fun unstake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext) {
        abort 0
    }

    public fun rewards_duration() : u64 {
        604800
    }

    public fun rewards_pool<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : &mut rewards_pool_continuous::RewardsPool {
        &mut gauge.rewards_pool
    }

    // public fun stake_token<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : CoinMetadata<FULLSAIL_TOKEN> {
    //     sui::object::convert<temp::liquidity_pool::LiquidityPool, sui::fungible_asset::Metadata>(borrow_global<Gauge>(sui::object::object_address<Gauge>(&arg0)).liquidity_pool)
    // }

    public fun unstake_lp<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext, clock: &Clock) {
        let sender = tx_context::sender(ctx);
        // let v1 = sui::object::generate_signer_for_extending(&borrow_global<Gauge>(sui::object::object_address<Gauge>(&arg1)).extend_ref);
        // let v2 = liquidity_pool(arg1);
        // temp::liquidity_pool::transfer(&v1, v2, v0, arg2);
        let rewards_pool = rewards_pool(gauge);
        assert!(rewards_pool_continuous::stake_balance(sender, rewards_pool) >= amount, 1);
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::unstake(sender, rewards_pool, amount, clock);
        event::emit(UnstakeEvent { lp: sender, amount: amount })
    }

    #[test_only]
    public fun create_test<BaseType, QuoteType>(pool: LiquidityPool<BaseType, QuoteType>, ctx: &mut TxContext) {
        create(pool, ctx);
    }

    #[test_only]
    public fun unstake_lp_test<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext, clock: &Clock) {
        unstake_lp(gauge, amount, ctx, clock);
    }

    #[test_only]
    public fun claim_rewards_test<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, ctx: &mut TxContext, clock: &Clock): Balance<FULLSAIL_TOKEN> {
        claim_rewards(gauge, ctx, clock)
    }

    #[test_only]
    public fun create_gauge_pool_test<BaseType, QuoteType>(
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        ctx: &mut TxContext
    ): (LiquidityPool<BaseType, QuoteType>, ID) {
        let (pool, id) = liquidity_pool::create_liquidity_pool_test<BaseType, QuoteType>(
            base_metadata, 
            quote_metadata, 
            configs, 
            false, 
            ctx
        );
        // let gauge_id = create<BaseType, QuoteType>(pool, ctx);
        (pool, id)
    }

    #[test_only]
    public fun create_gauge_test<BaseType, QuoteType>(
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        ctx: &mut TxContext
    ) {
        let (pool, id) = liquidity_pool::create_liquidity_pool_test<BaseType, QuoteType>(
            base_metadata, 
            quote_metadata, 
            configs, 
            false, 
            ctx
        );
        let gauge_id = create<BaseType, QuoteType>(
            pool, 
            ctx
        );
    }
}