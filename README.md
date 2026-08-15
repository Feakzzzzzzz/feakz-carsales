# Car Sale Script

Car Sale Script lets players sell their owned vehicles directly in the world using a for-sale sign. Owners can list a vehicle, set a price, show contact details, and let buyers inspect or test drive the car before making an offer.

The script is made for QB/QBX FiveM servers and uses ox resources for targeting, database access, and inventory support.



## Features

- Physical for-sale signs displayed on listed vehicles.
- Owner and buyer ox_target options.
- Owner details menu with phone number copy/save support.
- Vehicle mod inspection.
- Test drive support.
- Negotiation and counter-offer flow.
- Cash-first payment transfer on sale, with bank fallback.
- Vehicle ownership transfer after purchase.

## Performance

The script is well optimized, with a low idle usage of `0.00ms` when away from vehicles for sale.

With 4 DUI sale signs loaded nearby, idle usage is typically around `0.04ms - 0.06ms`.

## Preview

![Car sale signs showcase](https://i.8upload.com/image/582e7bfa5a55551f/desktop-screenshot-2026-08-15-19-26-32-34.png)

## How To

1. Use the sale sign item next to a registered vehicle.
2. Enter the desired sale price and confirm the listing.
3. The owner can offer the vehicle to a nearby buyer.
4. The buyer can accept the listed price or negotiate a counter offer.
5. When accepted, funds are deducted from the buyer's cash first, or bank if cash is not enough.
6. The owner receives cash for cash sales, with bank used as a payout fallback.

## Requirements

- `qb-core`
- `ox_lib`
- `ox_target`
- `oxmysql`
- `ox_inventory`

## Install

1. Run `install/install.sql`.
2. Add the item below to `ox_inventory/data/items.lua`.
3. Ensure the resource after its dependencies.

## Item

```lua
['car_sale_sign'] = {
    label = 'Car Sale Sign',
    weight = 500,
    stack = true,
    close = true,
    consume = 0,
    client = {
        export = 'carsale-script.useCarSaleSign'
    }
},
```
