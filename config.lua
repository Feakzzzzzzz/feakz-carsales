Config = {}

Config.Debug = false

Config.Framework = 'qb-core'
Config.Inventory = 'ox_inventory'
Config.Phone = 'sd-phone'



Config.Item = {
    Item = 'car_sale_sign',
    Consume = true,
    Return = true
}

Config.Render = {
    -- How far away sale vehicle blips show.
    blipDistance = 75.0,

    -- How far away sale signs are tracked.
    signDistance = 25.0,

    -- How far away sale signs are drawn.
    signDrawDistance = 7.0,

    -- How many DUI textures can exist at once.
    duiPoolSize = 4,

    -- How many nearby signs can use DUI textures.
    duiClosestSigns = 4
}

Config.TestDrive = {
    -- How long test drives last, in seconds.
    durationSeconds = 120,

    -- Shows a countdown timer while test driving.
    drawTimer = true
}

Config.Listing = {
    minPrice = 100,
    maxPrice = 10000000
}

Config.Keys = {
    resource = 'qbx_vehiclekeys'
}

Config.Mechanic = {
    resource = 'jg-mechanic'
}
