# Car Sale Script

Physical player-to-player vehicle sales for QB/QBX-style `player_vehicles` servers using `ox_lib`,
`ox_target`, `oxmysql`, and optionally `ox_inventory`.

## Features

- Player-owned vehicles can be listed directly from the world.
- DUI-rendered sale signs display the asking price, seller name, and phone number.
- Seller details, contact saving, test drives, sale offers, and negotiated counter offers are available through `ox_target`.
- Buyers and sellers can inspect listed vehicle upgrades from `ox_target`.
- Sellers can edit a listed vehicle's asking price from `ox_target`.
- Listed vehicles are locked, frozen, repaired, protected from damage, and marked with replicated entity state.
- Listed vehicle trunks and gloveboxes are blocked through an `ox_inventory` hook.
- Nearby map blips are shown for listed vehicles within the configured radius.

## Compatibility

- Framework: QB/QBX through `qb-core`.
- Ownership DB: `player_vehicles`, keyed by `citizenid` and `plate`.
- Vehicle data: `player_vehicles.mods` JSON is preserved; sale transfer only updates the owner column.
- Money: QB player `Functions.GetMoney/AddMoney/RemoveMoney` with bank accounts.
- Keys: `qbx_vehiclekeys` is used when available, with a fallback to the common `vehiclekeys:client:SetOwner` event.
- UI/target/database: `ox_lib`, `ox_target`, and `oxmysql`.
- Sign rendering: DUI runtime textures only. No physical sign prop is spawned.
- Seller Details shows the seller's first name and phone number. The Copy Number action copies only the phone number.
- Purchase offers support buyer negotiation: Accept, Negotiate, or Decline.
  Seller-accepted counter offers still require a final buyer confirmation before payment/ownership transfer.

## Install

1. Put `carsale-script` in your resources folder.
2. Run `install/install.sql`.
3. Copy `install/car_sale_sign.png` to your inventory image folder if your inventory needs item images.
4. Add the inventory item below.
5. Start after dependencies:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure qb-core
# choose one phone resource:
ensure sd-phone
# ensure lb-phone
ensure qbx_vehiclekeys
ensure carsale-script
```

## ox_inventory Item

This resource exposes the ox item callback as `carsale-script.useCarSaleSign`.

Add this to `ox_inventory/data/items.lua`:

```lua
['car_sale_sign'] = {
    label = 'Car Sale Sign',
    weight = 500,
    stack = true,
    close = true,
    consume = 0,
    description = 'Place a for-sale sign in one of your owned vehicles.',
    client = {
        export = 'carsale-script.useCarSaleSign'
    }
},
```

## Storage Lockout

The resource locks/freezes listed vehicles, blocks `ox_inventory` trunk and glovebox access,
and sets replicated entity state:

```lua
Entity(vehicle).state.carSale == true
```

The built-in `ox_inventory` hook is enabled by default:

```lua
Config.Inventory = 'ox_inventory'
```

Server-side integrations can also use:

```lua
exports['carsale-script']:IsVehicleForSale(plateOrNetId)
```

## Configuration

Edit `config.lua` for the resource names, sale item, vehicle database columns, price limits,
key system, and mechanic integration.

The default config targets a standard QB/QBX setup:

```lua
Config.Framework = 'qb-core'
Config.Phone = 'sd-phone'
Config.Inventory = 'ox_inventory'
Config.Item = {
    Item = 'car_sale_sign',
    Consume = true,
    Return = true
}
```

Set `Config.Phone = 'lb-phone'` only if you use lb-phone instead.
With sd-phone, seller numbers are read through sd-phone exports and contacts are saved through `addContact`.

The default database transfer preserves every column in `player_vehicles` except `citizenid`.
If your schema uses different vehicle table or column names, update `Config.Database`.

Advanced defaults such as DUI sign placement, blip styling, test-drive timing, target icons,
and vehicle-care behavior are filled in by `shared/config_defaults.lua`.

## Performance and Recovery

The DUI browser pool is created only when a sign is close enough to draw and is released after
60 seconds idle by default. Entity state changes drive listing discovery; a slower vehicle-pool
scan remains as recovery for missed scope events.

Set `Config.Optimization.metrics = true` to print cumulative client and server counters. Useful
counters include DUI creation/messages, state writes, lock synchronizations, active listings,
and transactions requiring review.

Purchase progress is journaled in `car_sale_transactions`. A transaction interrupted by a
resource restart or an incomplete compensation is marked `manual_review`; staff should resolve
those rows against framework bank logs and `player_vehicles` ownership before changing the row.
`car_sale_active_locks` prevents two asynchronous requests from listing the same plate.

For larger servers, make sure the configured `player_vehicles` plate column has an index. The
resource cannot add that index automatically because the ownership table and schema are
configurable.
