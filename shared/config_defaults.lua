local function clone(value)
    if type(value) ~= 'table' then return value end

    local out = {}
    for key, item in pairs(value) do
        out[key] = clone(item)
    end
    return out
end

local function applyDefaults(target, defaults)
    if type(target) ~= 'table' then target = {} end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = clone(value)
        elseif type(target[key]) == 'table' and type(value) == 'table' then
            applyDefaults(target[key], value)
        end
    end

    return target
end

Config = Config or {}
Config.Debug = Config.Debug == true

local framework = Config.Framework
if type(framework) == 'table' then
    Config.Framework = applyDefaults(framework, {
        name = 'qb',
        resource = 'qb-core'
    })
else
    Config.Framework = {
        name = 'qb',
        resource = framework or 'qb-core'
    }
end

local inventory = Config.Inventory
if type(inventory) == 'table' then
    Config.Inventory = inventory
else
    Config.Inventory = {
        resource = inventory or 'ox_inventory'
    }
end

local item = Config.Item
local itemName = 'car_sale_sign'
local consumeItem = false
local returnItemOnSale = true
local returnItemOnCancel = true

if type(item) == 'table' then
    itemName = item.Item or item.item or item.name or itemName
    consumeItem = item.Consume == true or item.consume == true

    if type(item.Return) == 'table' then
        returnItemOnSale = item.Return.Sale ~= false and item.Return.sale ~= false
        returnItemOnCancel = item.Return.Cancel ~= false and item.Return.cancel ~= false
    elseif item.Return ~= nil then
        returnItemOnSale = item.Return == true
        returnItemOnCancel = item.Return == true
    end
elseif type(item) == 'string' then
    itemName = item
end

Config.Inventory = applyDefaults(Config.Inventory, {
    signItem = itemName,
    consumeSign = consumeItem,
    returnSignOnCancel = returnItemOnCancel,
    returnSignOnSale = returnItemOnSale,
    blockListedVehicleStorage = true,
    registerQbItem = true
})

local phone = Config.Phone
if type(phone) == 'table' then
    Config.Phone = phone
else
    Config.Phone = {
        resource = phone or 'sd-phone'
    }
end

Config.Phone = applyDefaults(Config.Phone, {
    saveContacts = true,
    ensureOfflineNumber = false,
    cacheMs = 300000,
    charinfoKeys = { 'phone', 'phoneNumber', 'number' }
})

Config.Database = applyDefaults(Config.Database, {
    vehicleTable = 'player_vehicles',
    ownerColumn = 'citizenid',
    plateColumn = 'plate',
    modelColumn = 'vehicle',
    propsColumn = 'mods',
    extraOwnerColumns = {}
})

Config.Keys = type(Config.Keys) == 'table' and Config.Keys or { resource = Config.Keys }
Config.Keys = applyDefaults(Config.Keys, {
    giveToBuyer = true,
    removeFromSeller = true,
    qbxResource = Config.Keys.resource or 'qbx_vehiclekeys',
    qbEvent = 'vehiclekeys:client:SetOwner',
    lockStateEvent = 'qb-vehiclekeys:server:setVehLockState',
    customGiveEvent = nil,
    customRemoveEvent = nil
})

local mechanic = Config.Mechanic
local mechanicDefaults = {
    enabled = true,
    resource = 'jg-mechanic'
}

if mechanic == false then
    mechanicDefaults.enabled = false
elseif type(mechanic) == 'table' then
    mechanicDefaults.resource = mechanic.resource or mechanicDefaults.resource
    if mechanic.enabled ~= nil then mechanicDefaults.enabled = mechanic.enabled == true end
end

Config.Integrations = applyDefaults(Config.Integrations, {
    jgMechanic = mechanicDefaults
})

Config.Listing = applyDefaults(Config.Listing, {
    useDistance = 5.0,
    targetDistance = 3.0,
    offerDistance = 5.0,
    minPrice = 100,
    maxPrice = 10000000,
    offerExpirySeconds = 60,
    rateLimitMs = 1200,
    saleVehicleDiscoveryMs = 15000,
    saleVehicleDiscoveryIdleMs = 60000,
    vehicleBlacklist = {},
    classBlacklist = {},
    vehicleCare = {
        keepClean = true,
        keepWindowsFixed = true,
        fixBodyDamage = true,
        preserveHealth = true,
        preventDisplayDamage = true,
        distance = 60.0,
        intervalMs = 1000,
        farIntervalMs = 5000,
        cleanThreshold = 0.1,
        fullRefreshMs = 10000
    },
    persistence = {
        enabled = true
    }
})

local render = type(Config.Render) == 'table' and Config.Render or {}

Config.Sign = applyDefaults(Config.Sign, {
    texture = {
        resolutionScale = render.duiResolutionScale or render.resolutionScale or 0.5,
        poolSize = render.duiPoolSize or render.poolSize or 4,
        closestSigns = render.duiClosestSigns or render.closestSigns or 4,
        idleDestroyMs = 60000,
        initRetries = 2,
        retryDelayMs = 1000,
        poolRetryMs = 15000
    },
    render = {
        distance = render.signDistance or render.signRenderDistance or 25.0,
        drawDistance = render.signDrawDistance or render.drawDistance or 7.0,
        nearScanMs = 1000,
        approachScanMs = 2000,
        farScanMs = 5000,
        visibilityCheckMs = 1000,
        contentCheckMs = 5000
    },
    placement = {
        anchorBones = { 'windscreen', 'windscreen_f', 'window_lf', 'window_rf', 'bodyshell' },
        fallbackAnchor = vec3(0.0, 0.72, 0.93),
        offset = vec3(0.0, 0.0, 0.0),
        baseSize = vec2(0.59, 0.27),
        scale = 1.0,
        tilt = 0.08
    },
    adjustment = {
        x = { min = -120, max = 120 },
        y = { min = -100, max = 100 },
        z = { min = -80, max = 100 },
        width = { min = 30, max = 160 },
        height = { min = 15, max = 90 },
        tilt = { min = -40, max = 40 }
    }
})

Config.TargetIcons = applyDefaults(Config.TargetIcons, {
    details = 'fa-solid fa-address-card',
    inspect = 'fa-solid fa-gears',
    testDrive = 'fa-solid fa-road',
    offer = 'fa-solid fa-handshake',
    cancel = 'fa-solid fa-ban',
    edit = 'fa-solid fa-pen-to-square',
    view = 'fa-solid fa-circle-info',
    adjust = 'fa-solid fa-sliders'
})

Config.Blip = applyDefaults(Config.Blip, {
    enabled = true,
    radius = render.blipDistance or render.blipRenderDistance or render.blipRadius or 75.0,
    scanIntervalMs = 2000,
    farScanIntervalMs = 5000,
    sprite = 225,
    color = 1,
    scale = 0.75,
    name = 'Vehicle For Sale',
    shortRange = true
})

local testDrive = type(Config.TestDrive) == 'table' and Config.TestDrive or {}
if testDrive.durationSeconds == nil then
    testDrive.durationSeconds = testDrive.Duration or testDrive.duration
end

Config.TestDrive = applyDefaults(testDrive, {
    durationSeconds = 120,
    drawTimer = true,
    routingBucketBase = 62000,
    routingBucketMax = 62999,
    spawnOffset = vec4(0.0, 0.0, 0.0, 0.0),
    spawnAttempts = 3,
    fadeOutMs = 350,
    fadeInMs = 500,
    transitionHoldMs = 250,
    collisionTimeoutMs = 3500,
    maxPropertiesBytes = 32768,
    invincibleVehicle = false,
    endOnExitVehicle = true
})

Config.Notifications = applyDefaults(Config.Notifications, {
    title = 'Vehicle Sale'
})

Config.Optimization = applyDefaults(Config.Optimization, {
    metrics = false,
    metricsIntervalMs = 60000,
    serverMaintenanceMs = 30000,
    transactionStaleSeconds = 120
})
