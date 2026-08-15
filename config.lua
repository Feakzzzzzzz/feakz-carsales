Config = {}

Config.Debug = true

Config.Framework = 'qb-core'
Config.Inventory = 'ox_inventory'
Config.Phone = {
    resource = 'sd-phone',

    -- Set to false to hide "Save Contact" from the seller details menu.
    saveContacts = true
}

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
    maxPrice = 10000000,

    --  List model names to disable it
    vehicleBlacklist = {
        -- 'rhino',
        -- 'police'
    },

    -- Uncomment any class to disable it.
    classBlacklist = {
        -- 'Compacts',
        -- 'Sedans',
        -- 'SUVs',
        -- 'Coupes',
        -- 'Muscle',
        -- 'Sports Classics',
        -- 'Sports',
        -- 'Super',
        -- 'Motorcycles',
        -- 'Off-road',
         'Industrial',
         'Utility',
        -- 'Vans',
         'Cycles',
         'Boats',
         'Helicopters',
         'Planes',
         'Service',
         'Emergency',
         'Military',
         'Commercial',
         'Trains',
         'Open Wheel'
    }
}

Config.Sign = {
    placement = {
        -- Per-class placement overrides. Use class names from Config.Listing.classBlacklist.
        classOverrides = {
            ['Motorcycles'] = {
                anchorBones = { 'wheel_f', 'wheel_lf', 'wheel_rf', 'forks_f' },
                fallbackAnchor = vec3(0.0, 1.05, 0.32),
                offset = vec3(0.0, 0.35, 0.0),
                baseSize = vec2(0.42, 0.2),
                tilt = 0.05
            },
            ['Cycles'] = {
                anchorBones = { 'wheel_f', 'wheel_lf', 'wheel_rf', 'forks_f' },
                fallbackAnchor = vec3(0.0, 1.0, 0.3),
                offset = vec3(0.0, 0.35, 0.0),
                baseSize = vec2(0.42, 0.2),
                tilt = 0.05
            }
        }
    }
}

Config.Keys = {
    resource = 'qbx_vehiclekeys'
}

Config.Mechanic = {
    resource = 'jg-mechanic'
}
