# Car Sale Script

Car Sale Script lets players sell their owned vehicles directly in the world using a for-sale sign. Sellers can list a vehicle, set a price, show contact details, and let buyers inspect or test drive the car before making an offer.

The script is made for QB/QBX FiveM servers and uses ox resources for targeting, database access, and inventory support.

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
