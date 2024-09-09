module ape_sui_society::ape {
    use std::string::{String, utf8};

    use sui::display;
    use sui::event::emit;
    use sui::object::{Self, ID, UID};
    use sui::package::{Self, Publisher};
    use sui::transfer::{public_transfer, share_object};
    use sui::tx_context::{Self, sender, TxContext};
    use sui::vec_map::{Self, VecMap};

    // === Errors ===

    const ENotAuthorized: u64 = 0;
    const ENotToReveal: u64 = 1;
    const EAlreadyRevealed: u64 = 2;


    // === Structs ===

    struct APE has drop {}

    struct Ape has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String,
        attributes: VecMap<String, String>,
    }

    struct Reveal has store, drop {
        id: ID,
        revealed: bool,
        image_url: String,
        attributes: VecMap<String, String>,
    }

    struct RevealHub has key {
        id: UID,
        reveals: VecMap<ID, Reveal>
    }

    // ==== Events ====

    struct ApeCreated has copy, drop {
        // The Object ID of the NFT
        id: ID,
        // The owner of the NFT
        owner: address,
    }

    struct ApeRevealed has copy, drop {
        // The Object ID of the NFT
        id: ID,
        // The owner of the NFT
        owner: address,
    }

    // ===== Init =====

    fun init(otw: APE, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"description"),
            utf8(b"image_url"),
            utf8(b"attributes"),
        ];

        let values = vector[
            utf8(b"{name}"),
            utf8(b"{description}"),
            utf8(b"{image_url}"),
            utf8(b"{attributes}"),
        ];

        let publisher = package::claim(otw, ctx);

        let display = display::new_with_fields<Ape>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        let reveal_hub = RevealHub {
            id: object::new(ctx),
            reveals: vec_map::empty<ID, Reveal>(),
        };

        share_object(reveal_hub);
        public_transfer(publisher, tx_context::sender(ctx));
        public_transfer(display, tx_context::sender(ctx));
    }

    // ===== Public view functions =====

    public fun create(
        cap: &Publisher,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        background: vector<u8>,
        rarity: vector<u8>,
        level: vector<u8>,
        fur: vector<u8>,
        clothes: vector<u8>,
        mouth: vector<u8>,
        eyes: vector<u8>,
        hat: vector<u8>,
        earring: vector<u8>,
        ctx: &mut TxContext
    ): Ape {
        check_authority(cap);

        let attributes = vec_map::empty<String, String>();

        vec_map::insert(&mut attributes, utf8(b"background"), utf8(background));
        vec_map::insert(&mut attributes, utf8(b"rarity"), utf8(rarity));
        vec_map::insert(&mut attributes, utf8(b"level"), utf8(level));
        vec_map::insert(&mut attributes, utf8(b"fur"), utf8(fur));
        vec_map::insert(&mut attributes, utf8(b"clothes"), utf8(clothes));
        vec_map::insert(&mut attributes, utf8(b"mouth"), utf8(mouth));
        vec_map::insert(&mut attributes, utf8(b"eyes"), utf8(eyes));
        vec_map::insert(&mut attributes, utf8(b"hat"), utf8(hat));
        vec_map::insert(&mut attributes, utf8(b"earring"), utf8(earring));

        let nft = Ape {
            id: object::new(ctx),
            description: utf8(description),
            name: utf8(name),
            image_url: utf8(image_url),
            attributes
        };

        emit(ApeCreated {
            id: object::id(&nft),
            owner: sender(ctx),
        });

        nft
    }

    public fun insert_into_reveal_hub(
        cap: &Publisher,
        reveal_hub: &mut RevealHub,
        nft_id: ID,
        image_url: vector<u8>,
        background: vector<u8>,
        rarity: vector<u8>,
        level: vector<u8>,
        fur: vector<u8>,
        clothes: vector<u8>,
        mouth: vector<u8>,
        eyes: vector<u8>,
        hat: vector<u8>,
        earring: vector<u8>,
        _: &TxContext
    ) {
        check_authority(cap);

        let attributes = vec_map::empty<String, String>();

        vec_map::insert(&mut attributes, utf8(b"background"), utf8(background));
        vec_map::insert(&mut attributes, utf8(b"rarity"), utf8(rarity));
        vec_map::insert(&mut attributes, utf8(b"level"), utf8(level));
        vec_map::insert(&mut attributes, utf8(b"fur"), utf8(fur));
        vec_map::insert(&mut attributes, utf8(b"clothes"), utf8(clothes));
        vec_map::insert(&mut attributes, utf8(b"mouth"), utf8(mouth));
        vec_map::insert(&mut attributes, utf8(b"eyes"), utf8(eyes));
        vec_map::insert(&mut attributes, utf8(b"hat"), utf8(hat));
        vec_map::insert(&mut attributes, utf8(b"earring"), utf8(earring));

        let reveal = Reveal {
            id: nft_id,
            revealed: false,
            image_url: utf8(image_url),
            attributes,
        };

        vec_map::insert(&mut reveal_hub.reveals, nft_id, reveal);
    }

    public fun delete_from_reveal_hub(
        cap: &Publisher,
        reveal_hub: &mut RevealHub,
        nft_id: ID,
        _: &TxContext
    ) {
        check_authority(cap);

        vec_map::remove(&mut reveal_hub.reveals, &nft_id);
    }


    public fun reveal(
        ape: &mut Ape,
        reveal_hub: &mut RevealHub,
        ctx: &TxContext
    ) {
        assert!(vec_map::contains(&reveal_hub.reveals, &object::id(ape)), ENotToReveal);
        let reveal = vec_map::get_mut(&mut reveal_hub.reveals, &object::id(ape));
        assert!(reveal.revealed == false, EAlreadyRevealed);


        ape.attributes = reveal.attributes;
        ape.image_url = reveal.image_url;
        reveal.revealed = true;

        emit(ApeRevealed {
            id: object::id(ape),
            owner: tx_context::sender(ctx)
        });
    }

    fun check_authority(
        cap: &Publisher,
    ) {
        assert!(package::from_module<APE>(cap), ENotAuthorized);
    }
}