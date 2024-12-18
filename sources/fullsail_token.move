module full_sail::fullsail_token {
    use sui::coin::{Self, Coin, TreasuryCap};

    // --- structs ---
    // OTW
    public struct FULLSAIL_TOKEN has drop {}
    
    // token manager
    public struct FullSailManager has key {
        id: UID,
        cap: TreasuryCap<FULLSAIL_TOKEN>,
        minter: address
    }

    // init
    fun init(
        otw: FULLSAIL_TOKEN, 
        ctx: &mut TxContext
    ) {
        let (treasury_cap, metadata) = coin::create_currency(
            otw,
            18, // decimals
            b"SAIL", // symbol
            b"FullSail", // name
            b"Coin of FullSail Dex", // description
            option::none(), // icon url
            ctx
        );

        let manager = FullSailManager {
            id: object::new(ctx),
            cap: treasury_cap,
            minter: tx_context::sender(ctx)
        };

        transfer::share_object(manager);
        transfer::public_freeze_object(metadata);
    }

    // mint
    public(package) fun mint(
        authority: &mut TreasuryCap<FULLSAIL_TOKEN>, 
        amount: u64, 
        ctx: &mut TxContext
    ): Coin<FULLSAIL_TOKEN> {
        coin::mint(authority, amount, ctx)
    }

    // burn
    public(package) fun burn(
        authority: &mut TreasuryCap<FULLSAIL_TOKEN>, 
        coin: Coin<FULLSAIL_TOKEN>
    ): u64 {
        coin::burn(authority, coin)
    }

    // transfer
    public(package) fun transfer(
        coin: &mut Coin<FULLSAIL_TOKEN>, 
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin_to_send = coin::split(coin, amount, ctx);
        transfer::public_transfer(coin_to_send, recipient);
    }

    // freeze transfer
    public(package) fun freeze_transfers(coin: Coin<FULLSAIL_TOKEN>) {
        transfer::public_freeze_object(coin);
    }

    public fun withdraw(
        manager: &mut FullSailManager, 
        amount: u64, 
        ctx: &mut TxContext
    ): Coin<FULLSAIL_TOKEN> {
        let coin = mint(&mut manager.cap, amount, ctx);
        coin
    }

    // --- public view functions ---
    // balance
    public fun balance(coin: &Coin<FULLSAIL_TOKEN>): u64 {
        coin::value(coin)
    }

    // total supply
    public fun total_supply(manager: &FullSailManager): u64 {
        coin::total_supply(&manager.cap)
    }

    // cap
    public fun get_treasury_cap(manager: &mut FullSailManager): &mut TreasuryCap<FULLSAIL_TOKEN> {
        &mut manager.cap
    }

    // --- tests funcs ---
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init( FULLSAIL_TOKEN{}, ctx);
    }

    #[test_only]
    public(package) fun cap(manager: &mut FullSailManager): &mut TreasuryCap<FULLSAIL_TOKEN> {
        &mut manager.cap
    }
}