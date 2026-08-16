local function clone(value)
    if type(value) ~= 'table' then return value end

    local result = {}
    for key, item in pairs(value) do
        result[key] = clone(item)
    end
    return result
end

local function applyDefaults(target, defaults)
    target = type(target) == 'table' and target or {}

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = clone(value)
        elseif type(target[key]) == 'table' and type(value) == 'table' then
            applyDefaults(target[key], value)
        end
    end

    return target
end

local function normalizeFramework(framework)
    framework = type(framework) == 'table' and framework or { resource = framework }
    framework = applyDefaults(framework, { name = 'qb', resource = 'qb-core' })

    local name = type(framework.name) == 'string' and framework.name:lower() or nil
    local resource = type(framework.resource) == 'string' and framework.resource:lower() or nil
    if name == 'qbx' or name == 'qbox' or name == 'qbx_core' or resource == 'qbx_core' then
        framework.name = 'qb'
        framework.resource = 'qb-core'
    end

    return framework
end

local function getCompatibilityValue(...)
    local compatibility = Config.Compatibility or Config.Compatability or Config.Compandibityy
    if type(compatibility) ~= 'table' then return nil end

    for _, key in ipairs({ ... }) do
        if compatibility[key] ~= nil then return compatibility[key] end
    end
end

local function normalizeJgMechanic()
    local mechanic = Config.Mechanic
    local compatibility = getCompatibilityValue('jgMechanic', 'jg-mechanic', 'jg_mechanic')
    local normalized = { enabled = true, resource = 'jg-mechanic' }

    if mechanic == false then
        normalized.enabled = false
    elseif type(mechanic) == 'table' then
        normalized.resource = mechanic.resource or normalized.resource
        if mechanic.enabled ~= nil then normalized.enabled = mechanic.enabled == true end
    end

    if type(compatibility) == 'boolean' then
        normalized.enabled = compatibility
    elseif type(compatibility) == 'table' then
        normalized.resource = compatibility.resource or normalized.resource
        if compatibility.enabled ~= nil then normalized.enabled = compatibility.enabled == true end
    end

    return normalized
end

local function normalizeInventory()
    local inventory = Config.Inventory
    Config.Inventory = type(inventory) == 'table' and inventory or { resource = inventory or 'ox_inventory' }

    local item = Config.Item
    local itemName = 'car_sale_sign'
    local consumeItem = false
    local returnOnSale = true
    local returnOnCancel = true

    if type(item) == 'table' then
        itemName = item.Item or item.item or item.name or itemName
        consumeItem = item.Consume == true or item.consume == true

        if type(item.Return) == 'table' then
            returnOnSale = item.Return.Sale ~= false and item.Return.sale ~= false
            returnOnCancel = item.Return.Cancel ~= false and item.Return.cancel ~= false
        elseif item.Return ~= nil then
            returnOnSale = item.Return == true
            returnOnCancel = item.Return == true
        end
    elseif type(item) == 'string' then
        itemName = item
    end

    Config.Inventory = applyDefaults(Config.Inventory, {
        signItem = itemName,
        consumeSign = consumeItem,
        returnSignOnCancel = returnOnCancel,
        returnSignOnSale = returnOnSale,
        blockListedVehicleStorage = true,
        registerQbItem = true
    })
end

local function normalizePhone()
    local phone = Config.Phone
    Config.Phone = type(phone) == 'table' and phone or { resource = phone or 'sd-phone' }
    Config.Phone = applyDefaults(Config.Phone, {
        saveContacts = true,
        ensureOfflineNumber = false,
        cacheMs = 300000,
        charinfoKeys = { 'phone', 'phoneNumber', 'number' }
    })
end

local function normalizeTestDrive()
    local testDrive = type(Config.TestDrive) == 'table' and Config.TestDrive or {}
    if testDrive.durationSeconds == nil then
        testDrive.durationSeconds = testDrive.Duration or testDrive.duration
    end
    if testDrive.enabled == nil then
        testDrive.enabled = testDrive.Enable
        if testDrive.enabled == nil then testDrive.enabled = testDrive.Enabled end
    end
    Config.TestDrive = testDrive
end

Config = Config or {}
Config.Debug = Config.Debug == true
Config.Framework = normalizeFramework(Config.Framework)
normalizeInventory()
normalizePhone()
normalizeTestDrive()

local keys = Config.Keys
Config.Keys = type(keys) == 'table' and keys or { resource = keys }

for _, section in ipairs({
    'Database', 'Integrations', 'Listing', 'Sign', 'TargetIcons', 'Blip', 'Notifications', 'Optimization'
}) do
    if type(Config[section]) ~= 'table' then Config[section] = {} end
end

local render = type(Config.Render) == 'table' and Config.Render or {}
Config = applyDefaults(Config, {
    Database = {
        vehicleTable = 'player_vehicles',
        ownerColumn = 'citizenid',
        plateColumn = 'plate',
        modelColumn = 'vehicle',
        propsColumn = 'mods',
        extraOwnerColumns = {}
    },
    Keys = {
        giveToBuyer = true,
        removeFromSeller = true,
        qbxResource = Config.Keys.resource or 'qbx_vehiclekeys',
        qbEvent = 'vehiclekeys:client:SetOwner',
        lockStateEvent = 'qb-vehiclekeys:server:setVehLockState',
        customGiveEvent = nil,
        customRemoveEvent = nil
    },
    Integrations = { jgMechanic = normalizeJgMechanic() },
    Listing = {
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
        persistence = { enabled = true },
        vehicleCare = {
            keepClean = true,
            keepWindowsFixed = true,
            preventDisplayDamage = true,
            keepWindowsInvincible = true,
            cleanThreshold = 0.1,
            eventCooldownMs = 250,
            visualRepairDelayMs = 150,
            cosmeticRefreshMs = 2000,
            cosmeticRefreshDistance = 60.0
        }
    },
    Sign = {
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
            tilt = 0.08,
            classOverrides = {
                Motorcycles = {
                    anchorBones = { 'wheel_f', 'wheel_lf', 'wheel_rf', 'forks_f' },
                    fallbackAnchor = vec3(0.0, 1.05, 0.32),
                    offset = vec3(0.0, 0.35, 0.0),
                    baseSize = vec2(0.42, 0.2),
                    tilt = 0.08
                },
                Cycles = {
                    anchorBones = { 'wheel_f', 'wheel_lf', 'wheel_rf', 'forks_f' },
                    fallbackAnchor = vec3(0.0, 1.0, 0.3),
                    offset = vec3(0.0, 0.35, 0.0),
                    baseSize = vec2(0.42, 0.2),
                    tilt = 0.08
                }
            }
        },
        adjustment = {
            x = { min = -120, max = 120 },
            y = { min = -100, max = 100 },
            z = { min = -80, max = 100 },
            width = { min = 30, max = 160 },
            height = { min = 15, max = 90 },
            tilt = { min = -40, max = 40 }
        }
    },
    TargetIcons = {
        details = 'fa-solid fa-address-card',
        inspect = 'fa-solid fa-gears',
        testDrive = 'fa-solid fa-road',
        offer = 'fa-solid fa-handshake',
        cancel = 'fa-solid fa-ban',
        edit = 'fa-solid fa-pen-to-square',
        view = 'fa-solid fa-circle-info',
        adjust = 'fa-solid fa-sliders'
    },
    Blip = {
        enabled = true,
        radius = render.blipDistance or render.blipRenderDistance or render.blipRadius or 75.0,
        scanIntervalMs = 2000,
        farScanIntervalMs = 5000,
        sprite = 225,
        color = 1,
        scale = 0.75,
        name = 'Vehicle For Sale',
        shortRange = true
    },
    TestDrive = {
        enabled = true,
        durationSeconds = 120,
        drawTimer = true,
        spawnOffset = vec4(0.0, 0.0, 0.0, 0.0),
        spawnAttempts = 3,
        fadeOutMs = 350,
        fadeInMs = 500,
        transitionHoldMs = 250,
        collisionTimeoutMs = 3500,
        invincibleVehicle = false,
        endOnExitVehicle = true,
        routingBucketBase = 62000,
        routingBucketMax = 62999,
        maxPropertiesBytes = 32768
    },
    Notifications = { title = 'Vehicle Sale' },
    Optimization = {
        metrics = false,
        metricsIntervalMs = 60000,
        serverMaintenanceMs = 30000,
        transactionStaleSeconds = 120
    }
})
