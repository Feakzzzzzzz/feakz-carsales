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

local function getCompatibilityValue(...)
    local compatibility = Config.Compatibility
        or Config.Compatability
        or Config.Compandibityy

    if type(compatibility) ~= 'table' then return nil end

    for _, key in ipairs({ ... }) do
        if compatibility[key] ~= nil then return compatibility[key] end
    end

    return nil
end

local function normalizeJgMechanicConfig()
    local mechanic = Config.Mechanic
    local compatibility = getCompatibilityValue('jgMechanic', 'jg-mechanic', 'jg_mechanic')
    local normalized = {
        enabled = true,
        resource = 'jg-mechanic'
    }

    if mechanic == false then
        normalized.enabled = false
    elseif type(mechanic) == 'table' then
        normalized.resource = mechanic.resource or normalized.resource
        if mechanic.enabled ~= nil then normalized.enabled = mechanic.enabled == true end
    end

    if compatibility ~= nil then
        if type(compatibility) == 'boolean' then
            normalized.enabled = compatibility
        elseif type(compatibility) == 'table' then
            normalized.resource = compatibility.resource or normalized.resource
            if compatibility.enabled ~= nil then normalized.enabled = compatibility.enabled == true end
        end
    end

    return normalized
end

local function applyClientConfigDefaults()
    Config = Config or {}
    Config.Debug = Config.Debug == true

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
    if type(item) == 'table' then
        itemName = item.Item or item.item or item.name or itemName
    elseif type(item) == 'string' then
        itemName = item
    end

    Config.Inventory = applyDefaults(Config.Inventory, {
        signItem = itemName
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
        saveContacts = true
    })

    Config.Integrations = applyDefaults(Config.Integrations, {
        jgMechanic = normalizeJgMechanicConfig()
    })

    Config.Keys = type(Config.Keys) == 'table' and Config.Keys or { resource = Config.Keys }
    Config.Keys = applyDefaults(Config.Keys, {
        lockStateEvent = 'qb-vehiclekeys:server:setVehLockState'
    })

    Config.Listing = applyDefaults(Config.Listing, {
        useDistance = 5.0,
        targetDistance = 3.0,
        minPrice = 100,
        maxPrice = 10000000,
        saleVehicleDiscoveryMs = 15000,
        saleVehicleDiscoveryIdleMs = 60000,
        vehicleBlacklist = {},
        classBlacklist = {},
        vehicleCare = {
            keepClean = true,
            keepWindowsFixed = true,
            preventDisplayDamage = true,
            distance = 60.0,
            intervalMs = 5000,
            farIntervalMs = 5000,
            cleanThreshold = 0.1,
            fullRefreshMs = 10000
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
            tilt = 0.08,
            classOverrides = {
                ['Motorcycles'] = {
                    anchorBones = { 'wheel_f', 'wheel_lf', 'wheel_rf', 'forks_f' },
                    fallbackAnchor = vec3(0.0, 1.05, 0.32),
                    offset = vec3(0.0, 0.35, 0.0),
                    baseSize = vec2(0.42, 0.2),
                    tilt = 0.08
                },
                ['Cycles'] = {
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
    if testDrive.enabled == nil then
        testDrive.enabled = testDrive.Enable
        if testDrive.enabled == nil then testDrive.enabled = testDrive.Enabled end
    end

    Config.TestDrive = applyDefaults(testDrive, {
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
        endOnExitVehicle = true
    })

    Config.Notifications = applyDefaults(Config.Notifications, {
        title = 'Vehicle Sale'
    })

    Config.Optimization = applyDefaults(Config.Optimization, {
        metrics = false,
        metricsIntervalMs = 60000
    })
end

applyClientConfigDefaults()

local targetRegistered = false
local testDrive = nil
local endingTestDrive = false
local duiSigns = {}
local duiPool = {}
local duiPoolStarted = false
local duiPoolGeneration = 0
local duiLastUsedAt = 0
local duiPoolRetryAt = 0
local duiDrawThread = false
local saleBlips = {}
local saleVehicles = {}
local saleTargetEntities = {}
local saleDoorStates = {}
local saleCareState = {}
local saleProtectionStates = {}
local duiAnchorBoneCache = {}
local targetStateCache = {
    entity = nil,
    expiresAt = 0,
    data = nil
}
local runtimeMetrics = {
    duiCreates = 0,
    duiDestroys = 0,
    duiMessages = 0,
    stateRefreshes = 0,
    vehicleScans = 0,
    carePasses = 0
}
local registerSaleVehicleTarget
local unregisterSaleVehicleTarget

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function distanceSquared(a, b)
    if not a or not b then return math.huge end
    local x = a.x - b.x
    local y = a.y - b.y
    local z = a.z - b.z
    return (x * x) + (y * y) + (z * z)
end

local function shallowCopy(value)
    if type(value) ~= 'table' then return {} end

    local copy = {}
    for key, item in pairs(value) do
        copy[key] = item
    end
    return copy
end

local function incrementMetric(name, amount)
    runtimeMetrics[name] = (runtimeMetrics[name] or 0) + (amount or 1)
end

local function countEntries(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function normalizeSaleData(value)
    if type(value) ~= 'table' then return nil end

    return {
        carSale = true,
        listingId = tonumber(value.listingId or value.id),
        seller = tonumber(value.seller),
        price = tonumber(value.price),
        originalPlate = value.originalPlate,
        contactName = value.contactName,
        contactPhone = value.contactPhone,
        placement = type(value.placement) == 'table' and value.placement or nil,
        revision = tonumber(value.revision) or 0
    }
end

local function readSaleData(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    incrementMetric('stateRefreshes')
    local state = Entity(entity).state
    if not state or state.carSale ~= true then return nil end

    local packed = normalizeSaleData(state.carSaleData)
    if packed then return packed end

    -- Compatibility with listings created by an older version during a rolling restart.
    return {
        carSale = true,
        listingId = tonumber(state.carSaleListingId),
        seller = tonumber(state.carSaleSeller),
        price = tonumber(state.carSalePrice),
        originalPlate = state.carSaleOriginalPlate,
        contactName = state.carSaleContactName,
        contactPhone = state.carSaleContactPhone,
        placement = type(state.carSaleDuiPlacement) == 'table' and state.carSaleDuiPlacement or nil,
        revision = 0
    }
end

local function getSaleData(entity, refresh)
    if not refresh and saleVehicles[entity] then return saleVehicles[entity] end

    local data = readSaleData(entity)
    if data then
        saleVehicles[entity] = data
    elseif refresh then
        saleVehicles[entity] = nil
    end
    return data
end

local function notify(description, notifyType)
    lib.notify({
        title = Config.Notifications.title,
        description = description,
        type = notifyType or 'inform'
    })
end

local function isPhoneProviderRunning(provider)
    if provider and tostring(provider):lower() == 'none' then return false end
    return provider and GetResourceState(provider) == 'started'
end

local function hasServerContactIntegration()
    local resource = Config.Phone and Config.Phone.resource
    return isPhoneProviderRunning(resource) and (resource == 'sd-phone' or resource == 'lb-phone')
end

local function phoneContactsEnabled()
    local phone = Config.Phone or {}
    if phone.saveContacts ~= nil then return phone.saveContacts == true end
    return not phone.contact or phone.contact.enabled ~= false
end

exports('useCarSaleSign', function(data)
    if GetResourceState(Config.Inventory.resource) == 'started' then
        exports[Config.Inventory.resource]:useItem(data, function(used)
            if used then
                TriggerEvent('car-sales:client:useSign')
            end
        end)
        return
    end

    TriggerEvent('car-sales:client:useSign')
end)

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(25) end
    return HasModelLoaded(hash) and hash or nil
end

local function requestControl(entity, timeoutMs)
    timeoutMs = timeoutMs or 2000
    local timeout = GetGameTimer() + timeoutMs

    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(25)
    end

    return NetworkHasControlOfEntity(entity)
end

local function getNetEntity(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    if NetworkDoesNetworkIdExist and not NetworkDoesNetworkIdExist(netId) then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    return entity
end

local function getStateBagEntity(bagName)
    local netId = tonumber(tostring(bagName or ''):match('^entity:(%d+)$'))
    if netId and NetworkDoesNetworkIdExist and not NetworkDoesNetworkIdExist(netId) then return nil end

    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    return entity
end

local function getEntityNetId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if NetworkGetEntityIsNetworked and not NetworkGetEntityIsNetworked(entity) then return nil end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then return nil end

    return netId
end

local function isJgMechanicAvailable()
    local integration = Config.Integrations and Config.Integrations.jgMechanic
    return integration
        and integration.enabled
        and integration.resource
        and GetResourceState(integration.resource) == 'started'
end

local function getJgMechanicStanceState(vehicle)
    if not isJgMechanicAvailable() or not DoesEntityExist(vehicle) then return nil end

    local resource = Config.Integrations.jgMechanic.resource
    local ok, state = pcall(function()
        return exports[resource]:getVehicleStatebagProperties(vehicle)
    end)

    if not ok or type(state) ~= 'table' then return nil end

    local stance = {
        enableStance = state.enableStance,
        wheelsAdjIndv = state.wheelsAdjIndv,
        stance = state.stance
    }

    if GetVehicleWheelSize then stance.wheelSize = GetVehicleWheelSize(vehicle) end
    if GetVehicleWheelWidth then stance.wheelWidth = GetVehicleWheelWidth(vehicle) end

    return stance
end

local function getJgMechanicTestDriveProps(vehicle)
    if not isJgMechanicAvailable() or not DoesEntityExist(vehicle) then return nil end

    local resource = Config.Integrations.jgMechanic.resource
    local ok, props = pcall(function()
        return exports[resource]:getVehicleProperties(vehicle, true)
    end)

    if ok and type(props) == 'table' then
        local state = Entity(vehicle).state
        if state then
            if state.enableStance ~= nil then props.enableStance = state.enableStance end
            if state.wheelsAdjIndv ~= nil then props.wheelsAdjIndv = state.wheelsAdjIndv end
            if type(state.stance) == 'table' then props.stance = state.stance end
            if type(state.defaultStance) == 'table' then props.defaultStance = state.defaultStance end
        end

        return props
    end

    return getJgMechanicStanceState(vehicle)
end

local function applyJgMechanicVehicleProperties(vehicle, props)
    if not isJgMechanicAvailable() or not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end

    local resource = Config.Integrations.jgMechanic.resource
    local ok, result = pcall(function()
        return exports[resource]:setVehicleProperties(vehicle, props, true)
    end)

    return ok and result ~= false
end

local function applyJgMechanicStanceState(vehicle, state)
    if not isJgMechanicAvailable() or not DoesEntityExist(vehicle) or type(state) ~= 'table' then return end

    if state.wheelSize and SetVehicleWheelSize then SetVehicleWheelSize(vehicle, state.wheelSize + 0.0) end
    if state.wheelWidth and SetVehicleWheelWidth then SetVehicleWheelWidth(vehicle, state.wheelWidth + 0.0) end

    local resource = Config.Integrations.jgMechanic.resource
    pcall(function()
        exports[resource]:setVehicleStatebagProperties(vehicle, {
            enableStance = state.enableStance,
            wheelsAdjIndv = state.wheelsAdjIndv,
            stance = state.stance
        })
    end)
end

local function reapplyTestDriveJgStance(vehicle, props)
    if type(props) ~= 'table' then return end

    CreateThread(function()
        for _ = 1, 4 do
            Wait(500)
            if not DoesEntityExist(vehicle) then return end
            applyJgMechanicStanceState(vehicle, props)
        end
    end)
end

local function applySaleDamageProtection(vehicle)
    if not Config.Listing.vehicleCare.preventDisplayDamage or not DoesEntityExist(vehicle) then return end

    if not saleProtectionStates[vehicle] then
        saleProtectionStates[vehicle] = {
            canBeDamaged = GetEntityCanBeDamaged and GetEntityCanBeDamaged(vehicle),
            invincible = GetEntityInvincible and GetEntityInvincible(vehicle),
            tyresCanBurst = GetVehicleTyresCanBurst and GetVehicleTyresCanBurst(vehicle)
        }
    end

    if SetEntityCanBeDamaged then SetEntityCanBeDamaged(vehicle, false) end
    if SetEntityInvincible then SetEntityInvincible(vehicle, true) end
    if SetVehicleCanBeVisiblyDamaged then SetVehicleCanBeVisiblyDamaged(vehicle, false) end
    if SetVehicleCanBreak then SetVehicleCanBreak(vehicle, false) end
    if SetVehicleTyresCanBurst then SetVehicleTyresCanBurst(vehicle, false) end
    if SetVehicleWheelsCanBreak then SetVehicleWheelsCanBreak(vehicle, false) end
    if SetVehicleLightsCanBeVisiblyDamaged then SetVehicleLightsCanBeVisiblyDamaged(vehicle, false) end
    if SetVehicleHasUnbreakableLights then SetVehicleHasUnbreakableLights(vehicle, true) end
end

local function restoreSaleDamageProtection(vehicle)
    if not Config.Listing.vehicleCare.preventDisplayDamage or not DoesEntityExist(vehicle) then return end

    local original = saleProtectionStates[vehicle]
    if not original then return end

    local canBeDamaged = original.canBeDamaged
    if canBeDamaged == nil then canBeDamaged = true end
    local invincible = original.invincible
    if invincible == nil then invincible = false end
    local tyresCanBurst = original.tyresCanBurst
    if tyresCanBurst == nil then tyresCanBurst = true end

    if SetEntityCanBeDamaged then SetEntityCanBeDamaged(vehicle, canBeDamaged) end
    if SetEntityInvincible then SetEntityInvincible(vehicle, invincible) end
    if SetVehicleCanBeVisiblyDamaged then SetVehicleCanBeVisiblyDamaged(vehicle, true) end
    if SetVehicleCanBreak then SetVehicleCanBreak(vehicle, true) end
    if SetVehicleTyresCanBurst then SetVehicleTyresCanBurst(vehicle, tyresCanBurst) end
    if SetVehicleWheelsCanBreak then SetVehicleWheelsCanBreak(vehicle, true) end
    if SetVehicleLightsCanBeVisiblyDamaged then SetVehicleLightsCanBeVisiblyDamaged(vehicle, true) end
    if SetVehicleHasUnbreakableLights then SetVehicleHasUnbreakableLights(vehicle, false) end
    saleProtectionStates[vehicle] = nil
end

local function getSaleDisplayPlate(vehicle)
    local data = getSaleData(vehicle)
    local originalPlate = data and CarSale.NormalizePlate(data.originalPlate)
    if originalPlate and originalPlate ~= '' then return originalPlate end

    return CarSale.NormalizePlate(GetVehicleNumberPlateText(vehicle))
end

local function setFrameworkLockState(vehicle, lockState)
    if not Config.Keys.lockStateEvent then return end

    local netId = getEntityNetId(vehicle)
    if not netId then return end

    TriggerServerEvent(Config.Keys.lockStateEvent, netId, lockState)
end

local function applySaleLock(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleNumberPlateText(vehicle, getSaleDisplayPlate(vehicle))
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)
end

local function captureDoorState(vehicle)
    local state = {}
    for door = 0, 5 do
        state[door] = GetVehicleDoorAngleRatio(vehicle, door) > 0.05
    end
    return state
end

local function restoreDoorState(vehicle, state)
    if not DoesEntityExist(vehicle) or type(state) ~= 'table' then return end

    for door = 0, 5 do
        if state[door] then
            SetVehicleDoorOpen(vehicle, door, false, false)
        else
            SetVehicleDoorShut(vehicle, door, false)
        end
    end
end

local function maintainSalePresentation(vehicle, force)
    if not DoesEntityExist(vehicle) then return end
    local now = GetGameTimer()
    local careState = saleCareState[vehicle] or { lastFullRefresh = 0 }
    local refreshMs = Config.Listing.vehicleCare.fullRefreshMs or 10000
    local fullRefresh = force == true or now - careState.lastFullRefresh >= refreshMs

    if Config.Listing.vehicleCare.keepClean then
        local dirt = GetVehicleDirtLevel(vehicle)
        if force or dirt > (Config.Listing.vehicleCare.cleanThreshold or 0.1) then
            SetVehicleDirtLevel(vehicle, 0.0)
        end

        -- Paint damage decals can exist while the dirt level remains at zero.
        if fullRefresh then
            WashDecalsFromVehicle(vehicle, 1.0)
            RemoveDecalsFromVehicle(vehicle)
        end
    end

    if fullRefresh and Config.Listing.vehicleCare.keepWindowsFixed then
        for window = 0, 7 do
            if not IsVehicleWindowIntact or not IsVehicleWindowIntact(vehicle, window) then
                FixVehicleWindow(vehicle, window)
            end
        end
    end

    if fullRefresh then
        -- Repair natives may reset protection flags, so protection is applied last.
        applySaleDamageProtection(vehicle)
        careState.lastFullRefresh = now
        saleCareState[vehicle] = careState
        incrementMetric('carePasses')
    end
end

local function releaseSaleLock(vehicle, plate, sold, buyerSrc)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleNumberPlateText(vehicle, plate)
    restoreSaleDamageProtection(vehicle)
    SetVehicleUndriveable(vehicle, false)
    FreezeEntityPosition(vehicle, false)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLocked(vehicle, sold and 1 or 0)
    if sold and buyerSrc == GetPlayerServerId(PlayerId()) then
        SetVehicleDoorsLocked(vehicle, 1)
    end

    restoreDoorState(vehicle, saleDoorStates[vehicle])
    saleDoorStates[vehicle] = nil
    saleCareState[vehicle] = nil
end

local function destroySaleBlip(entity)
    local blip = saleBlips[entity]
    if not blip then return end

    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    saleBlips[entity] = nil
end

local function ensureSaleBlip(entity)
    if not Config.Blip.enabled or not DoesEntityExist(entity) then return end
    if saleBlips[entity] and DoesBlipExist(saleBlips[entity]) then return end

    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, Config.Blip.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.name)
    EndTextCommandSetBlipName(blip)

    saleBlips[entity] = blip
end

local function destroyDuiSign(entity)
    local sign = duiSigns[entity]
    if not sign then return end

    sign.entity = nil
    sign.listingId = nil
    sign.geometry = nil
    sign.visible = false
    sign.dataKey = nil
    sign.nextVisibilityCheck = 0
    sign.nextEntityCheck = 0
    sign.nextContentCheck = 0
    duiSigns[entity] = nil
    duiLastUsedAt = GetGameTimer()
end

local function getDuiPayload(entity)
    local data = getSaleData(entity)
    if not data or data.price == nil then return nil end

    return {
        type = 'update',
        price = CarSale.FormatMoney(data.price or 0),
        name = data.contactName or 'Unknown',
        phone = data.contactPhone or 'Unknown'
    }
end

local function buildDuiUrl(slotId, generation, attempt)
    return ('https://cfx-nui-%s/html/sign.html?dui=1&slot=%s&generation=%s&attempt=%s'):format(
        GetCurrentResourceName(),
        slotId,
        generation,
        attempt
    )
end

local function getDuiPoolSize()
    return math.max(1, math.floor(tonumber(Config.Sign.texture.poolSize) or 2))
end

local function getActiveDuiLimit()
    local poolSize = getDuiPoolSize()
    local activeSigns = math.floor(tonumber(Config.Sign.texture.closestSigns) or 2)

    return clamp(activeSigns, 1, poolSize)
end

local function getDuiTextureSize()
    local scale = clamp(tonumber(Config.Sign.texture.resolutionScale) or 1.0, 0.25, 1.0)
    return math.floor(768 * scale), math.floor(384 * scale)
end

local function getDuiScanInterval(scanState)
    local render = Config.Sign.render
    local fallback = tonumber(render.scanIntervalMs) or 500
    local near = tonumber(render.nearScanMs) or fallback
    local far = tonumber(render.farScanMs) or math.max(fallback, 5000)

    if scanState == 'active' then
        return near
    elseif scanState == 'near' then
        return tonumber(render.approachScanMs) or math.min(math.max(near * 2, near), far)
    end

    return far
end

local function getSignPlacementConfig(entity)
    local placement = Config.Sign.placement
    local override

    if entity and entity ~= 0 and DoesEntityExist(entity) and GetVehicleClass then
        local class = GetVehicleClass(entity)
        override = CarSale.GetVehicleClassConfig(placement.classOverrides, class)
    end

    return override or placement
end

local function getDefaultSignSize(placement)
    placement = placement or Config.Sign.placement
    local base = placement.baseSize or Config.Sign.placement.baseSize
    local scale = tonumber(placement.scale or Config.Sign.placement.scale) or 1.0
    return base.x * scale, base.y * scale
end

local function getDuiDataKey(data)
    return ('%s|%s|%s'):format(data.price, data.name, data.phone)
end

local function updateDuiContent(entity, sign, force)
    if not sign or not sign.dui or not DoesEntityExist(entity) then return end

    local data = getDuiPayload(entity)
    if not data then return end

    local key = getDuiDataKey(data)
    if not force and sign.dataKey == key then return end

    if not sign.ready or not IsDuiAvailable(sign.dui) then
        sign.dataKey = nil
        return
    end

    SendDuiMessage(sign.dui, json.encode(data))
    incrementMetric('duiMessages')
    sign.dataKey = key
    sign.lastContentUpdate = GetGameTimer()
end

local function bootstrapDuiSlot(slot, attempt)
    CreateThread(function()
        for _, delay in ipairs({ 500, 750, 1500 }) do
            Wait(delay)
            if not duiPoolStarted
                or duiPool[slot.id] ~= slot
                or slot.generation ~= duiPoolGeneration
                or slot.attempt ~= attempt
                or slot.failed
                or not slot.dui
                or not slot.textureReady then
                return
            end

            slot.ready = true
            slot.dataKey = nil
            if slot.entity and DoesEntityExist(slot.entity) then
                updateDuiContent(slot.entity, slot, true)
            end
        end
    end)
end

local function shouldKeepDuiSign(entity, sign, now)
    if not DoesEntityExist(entity) then return false end

    if sign.nextEntityCheck and now < sign.nextEntityCheck then
        return true
    end

    sign.nextEntityCheck = now + 1000

    return saleVehicles[entity] ~= nil
end

local function maybeUpdateDuiContent(entity, sign, now)
    if sign.nextContentCheck and now < sign.nextContentCheck then return end

    sign.nextContentCheck = now + (Config.Sign.render.contentCheckMs or 5000)
    updateDuiContent(entity, sign)
end

local function destroyDuiPool(retryDelayMs)
    if not duiPoolStarted then return end

    duiPoolGeneration = duiPoolGeneration + 1
    for entity in pairs(duiSigns) do destroyDuiSign(entity) end
    for _, slot in ipairs(duiPool) do
        if slot.dui then
            DestroyDui(slot.dui)
            slot.dui = nil
            incrementMetric('duiDestroys')
        end
    end

    duiPool = {}
    duiPoolStarted = false
    duiPoolRetryAt = retryDelayMs and (GetGameTimer() + retryDelayMs) or 0
end

local function ensureDuiPool()
    if duiPoolStarted then return true end
    if GetGameTimer() < duiPoolRetryAt then return false end
    duiPoolStarted = true
    duiPoolGeneration = duiPoolGeneration + 1
    local generation = duiPoolGeneration
    duiLastUsedAt = GetGameTimer()

    local poolSize = getDuiPoolSize()
    local width, height = getDuiTextureSize()
    local retries = math.max(1, math.floor(tonumber(Config.Sign.texture.initRetries) or 2))
    local retryDelay = math.max(100, math.floor(tonumber(Config.Sign.texture.retryDelayMs) or 1000))

    for i = 1, poolSize do
        local slot = {
            id = i,
            generation = generation,
            txdName = ('car_sale_sign_pool_%s_%s'):format(generation, i),
            txnName = 'sign',
            ready = false,
            textureReady = false,
            failed = false,
            attempt = 0,
            visible = false,
            nextVisibilityCheck = 0,
            lastSeenAt = 0
        }

        duiPool[i] = slot

        CreateThread(function()
            for attempt = 1, retries do
                if not duiPoolStarted or slot.generation ~= duiPoolGeneration then return end

                slot.attempt = attempt
                slot.ready = false
                slot.textureReady = false
                local dui = CreateDui(buildDuiUrl(slot.id, generation, attempt), width, height)
                slot.dui = dui
                incrementMetric('duiCreates')
                local timeout = GetGameTimer() + 5000
                while not IsDuiAvailable(dui) and GetGameTimer() < timeout do
                    Wait(50)
                    if not duiPoolStarted or slot.generation ~= duiPoolGeneration then
                        DestroyDui(dui)
                        incrementMetric('duiDestroys')
                        return
                    end
                end

                if IsDuiAvailable(dui) then
                    local txd = CreateRuntimeTxd(slot.txdName)
                    CreateRuntimeTextureFromDuiHandle(txd, slot.txnName, GetDuiHandle(dui))
                    slot.textureReady = true
                    bootstrapDuiSlot(slot, attempt)
                    return true
                end

                DestroyDui(dui)
                incrementMetric('duiDestroys')
                slot.dui = nil
                slot.ready = false
                slot.textureReady = false
                if attempt < retries then Wait(retryDelay) end
            end

            slot.failed = true
            if slot.entity then destroyDuiSign(slot.entity) end

            local allFailed = true
            for _, candidate in ipairs(duiPool) do
                if not candidate.failed then
                    allFailed = false
                    break
                end
            end
            if allFailed and duiPoolStarted and slot.generation == duiPoolGeneration then
                destroyDuiPool(Config.Sign.texture.poolRetryMs or 15000)
            end
        end)
    end
    return true
end

local function getFreeDuiSlot()
    ensureDuiPool()

    for _, slot in ipairs(duiPool) do
        if not slot.entity and not slot.failed then return slot end
    end

    return nil
end

local function getDuiPlacement(entity)
    local data = getSaleData(entity)
    local placement = data and data.placement or nil
    local placementConfig = getSignPlacementConfig(entity)
    local width, height = getDefaultSignSize(placementConfig)
    local offset = placementConfig.offset or Config.Sign.placement.offset
    local tilt = placementConfig.tilt or Config.Sign.placement.tilt

    if type(placement) ~= 'table' then
        return {
            x = offset.x,
            y = offset.y,
            z = offset.z,
            width = width,
            height = height,
            tilt = tilt
        }
    end

    return {
        x = tonumber(placement.x) or offset.x,
        y = tonumber(placement.y) or offset.y,
        z = tonumber(placement.z) or offset.z,
        width = tonumber(placement.width) or width,
        height = tonumber(placement.height) or height,
        tilt = tonumber(placement.tilt) or tilt
    }
end

local function getEntityBasis(entity)
    local origin = GetEntityCoords(entity)
    local rightPoint = GetOffsetFromEntityInWorldCoords(entity, 1.0, 0.0, 0.0)
    local forwardPoint = GetOffsetFromEntityInWorldCoords(entity, 0.0, 1.0, 0.0)
    local upPoint = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, 1.0)

    return {
        right = vec3(rightPoint.x - origin.x, rightPoint.y - origin.y, rightPoint.z - origin.z),
        forward = vec3(forwardPoint.x - origin.x, forwardPoint.y - origin.y, forwardPoint.z - origin.z),
        up = vec3(upPoint.x - origin.x, upPoint.y - origin.y, upPoint.z - origin.z)
    }
end

local function getDuiAnchorCoords(entity, placementConfig)
    local placement = placementConfig or getSignPlacementConfig(entity)
    if type(placement.anchorBones) == 'table' then
        local model = GetEntityModel(entity)
        local boneIndex = duiAnchorBoneCache[model]

        if boneIndex == nil then
            boneIndex = false
            for _, boneName in ipairs(placement.anchorBones) do
                local candidate = GetEntityBoneIndexByName(entity, boneName)
                if candidate and candidate ~= -1 then
                    boneIndex = candidate
                    break
                end
            end
            duiAnchorBoneCache[model] = boneIndex
        end

        if boneIndex then
            return GetWorldPositionOfEntityBone(entity, boneIndex)
        end
    end

    local fallback = placement.fallbackAnchor
    if fallback then
        return GetOffsetFromEntityInWorldCoords(entity, fallback.x, fallback.y, fallback.z)
    end

    return GetEntityCoords(entity)
end

local function offsetFromDuiAnchor(basis, anchorCoords, x, y, z)
    return vec3(
        anchorCoords.x + (basis.right.x * x) + (basis.forward.x * y) + (basis.up.x * z),
        anchorCoords.y + (basis.right.y * x) + (basis.forward.y * y) + (basis.up.y * z),
        anchorCoords.z + (basis.right.z * x) + (basis.forward.z * y) + (basis.up.z * z)
    )
end

local function getDuiGeometry(entity, placement)
    placement = placement or getDuiPlacement(entity)

    local anchorCoords = getDuiAnchorCoords(entity, getSignPlacementConfig(entity))
    local basis = getEntityBasis(entity)
    local halfWidth = placement.width * 0.5
    local halfHeight = placement.height * 0.5
    local tilt = placement.tilt

    return {
        center = offsetFromDuiAnchor(basis, anchorCoords, placement.x, placement.y, placement.z),
        topLeft = offsetFromDuiAnchor(basis, anchorCoords, placement.x - halfWidth, placement.y - tilt, placement.z + halfHeight),
        topRight = offsetFromDuiAnchor(basis, anchorCoords, placement.x + halfWidth, placement.y - tilt, placement.z + halfHeight),
        bottomLeft = offsetFromDuiAnchor(basis, anchorCoords, placement.x - halfWidth, placement.y + tilt, placement.z - halfHeight),
        bottomRight = offsetFromDuiAnchor(basis, anchorCoords, placement.x + halfWidth, placement.y + tilt, placement.z - halfHeight)
    }
end

local function getDuiCoords(entity)
    return getDuiGeometry(entity).center
end

local function canShowDui(entity)
    if not DoesEntityExist(entity) then return false end
    local pedCoords = GetEntityCoords(PlayerPedId())
    local coords = getDuiCoords(entity)

    local distance = Config.Sign.render.distance
    return distanceSquared(pedCoords, coords) <= distance * distance
end

local function checkDuiVisibility(entity, sign, pedCoords)
    local now = GetGameTimer()
    if sign.nextVisibilityCheck and now < sign.nextVisibilityCheck then
        return sign.visible == true
    end

    sign.nextVisibilityCheck = now + (Config.Sign.render.visibilityCheckMs or 250)

    local geometry = sign.geometry or getDuiGeometry(entity)
    sign.geometry = geometry

    local drawDistance = Config.Sign.render.drawDistance or Config.Sign.render.distance
    local visible = distanceSquared(pedCoords, geometry.center) <= drawDistance * drawDistance

    sign.visible = visible
    if visible then
        sign.lastSeenAt = now
    end

    return visible
end

local function ensureDuiDrawThread()
    if duiDrawThread then return end
    duiDrawThread = true

    CreateThread(function()
        while true do
            local hasSigns = false
            local now = GetGameTimer()
            local pedCoords = GetEntityCoords(PlayerPedId())

            for entity, sign in pairs(duiSigns) do
                if not shouldKeepDuiSign(entity, sign, now) then
                    destroyDuiSign(entity)
                else
                    hasSigns = true
                    if sign.ready and checkDuiVisibility(entity, sign, pedCoords) then
                        maybeUpdateDuiContent(entity, sign, now)

                        local geometry = sign.geometry or getDuiGeometry(entity)
                        local topLeft = geometry.topLeft
                        local topRight = geometry.topRight
                        local bottomLeft = geometry.bottomLeft
                        local bottomRight = geometry.bottomRight

                        DrawSpritePoly(
                            topLeft.x, topLeft.y, topLeft.z,
                            topRight.x, topRight.y, topRight.z,
                            bottomRight.x, bottomRight.y, bottomRight.z,
                            255, 255, 255, 255,
                            sign.txdName, sign.txnName,
                            1.0, 0.0, 1.0,
                            0.0, 0.0, 1.0,
                            0.0, 1.0, 1.0
                        )
                        DrawSpritePoly(
                            topLeft.x, topLeft.y, topLeft.z,
                            bottomRight.x, bottomRight.y, bottomRight.z,
                            bottomLeft.x, bottomLeft.y, bottomLeft.z,
                            255, 255, 255, 255,
                            sign.txdName, sign.txnName,
                            1.0, 0.0, 1.0,
                            0.0, 1.0, 1.0,
                            1.0, 1.0, 1.0
                        )
                    end
                end
            end

            if hasSigns then
                Wait(0)
            else
                duiDrawThread = false
                break
            end
        end
    end)
end

local function ensureDuiSign(entity, geometry)
    if not DoesEntityExist(entity) then return end

    local data = getSaleData(entity)
    if not data then return end

    local listingId = data.listingId
    if not listingId then return end
    duiLastUsedAt = GetGameTimer()

    if not getDuiPayload(entity) then return end
    if not geometry then
        if not canShowDui(entity) then return end
        geometry = getDuiGeometry(entity)
    end

    local existing = duiSigns[entity]
    if existing and existing.listingId == listingId then
        existing.geometry = geometry
        updateDuiContent(entity, existing)
        return
    end

    destroyDuiSign(entity)

    local sign = getFreeDuiSlot()
    if not sign then return end

    sign.entity = entity
    sign.listingId = listingId
    sign.geometry = geometry
    sign.visible = false
    sign.lastSeenAt = GetGameTimer()
    sign.nextVisibilityCheck = 0
    sign.nextEntityCheck = 0
    sign.nextContentCheck = 0
    sign.dataKey = nil
    duiLastUsedAt = GetGameTimer()

    duiSigns[entity] = sign
    updateDuiContent(entity, sign, true)
    ensureDuiDrawThread()
end

local function refreshDuiSign(entity)
    local sign = duiSigns[entity]
    if sign then
        updateDuiContent(entity, sign, true)
    end
end

local function trackSaleVehicle(entity, data)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    data = data and normalizeSaleData(data) or getSaleData(entity, true)
    if not data then return false end

    saleVehicles[entity] = data
    if registerSaleVehicleTarget then registerSaleVehicleTarget(entity) end
    return true
end

local function untrackSaleVehicle(entity)
    if unregisterSaleVehicleTarget then unregisterSaleVehicleTarget(entity) end
    if DoesEntityExist(entity) then restoreSaleDamageProtection(entity) end
    saleProtectionStates[entity] = nil
    saleVehicles[entity] = nil
    saleCareState[entity] = nil
    destroyDuiSign(entity)
    destroySaleBlip(entity)
end

local function isTrackedSaleVehicle(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and saleVehicles[entity] ~= nil
end

local function discoverSaleVehicles()
    incrementMetric('vehicleScans')
    local seen = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local data = readSaleData(vehicle)
        if data then
            trackSaleVehicle(vehicle, data)
            seen[vehicle] = true
        elseif saleVehicles[vehicle] then
            untrackSaleVehicle(vehicle)
        end
    end

    for vehicle in pairs(saleVehicles) do
        if not seen[vehicle] or not DoesEntityExist(vehicle) then
            untrackSaleVehicle(vehicle)
        end
    end
end

local function buildTrackedVehicleSnapshot(pedCoords)
    local snapshot = {}
    for vehicle, data in pairs(saleVehicles) do
        if not DoesEntityExist(vehicle) then
            untrackSaleVehicle(vehicle)
        else
            local coords = GetEntityCoords(vehicle)
            snapshot[#snapshot + 1] = {
                entity = vehicle,
                data = data,
                coords = coords,
                distanceSquared = distanceSquared(pedCoords, coords)
            }
        end
    end
    return snapshot
end

local function insertNearestCandidate(candidates, candidate, limit)
    local insertAt = #candidates + 1
    for i = 1, #candidates do
        local current = candidates[i]
        if candidate.distanceSquared < current.distanceSquared
            or (candidate.distanceSquared == current.distanceSquared and candidate.entity < current.entity) then
            insertAt = i
            break
        end
    end

    table.insert(candidates, insertAt, candidate)
    if #candidates > limit then table.remove(candidates) end
end

local function rebuildDuiAssignments(pedCoords, snapshot)
    pedCoords = pedCoords or GetEntityCoords(PlayerPedId())
    snapshot = snapshot or buildTrackedVehicleSnapshot(pedCoords)
    local candidates = {}
    local nearestDistanceSquared = nil
    local drawDistance = Config.Sign.render.drawDistance or Config.Sign.render.distance
    local scanDistance = Config.Sign.render.distance or drawDistance
    local roughLimitSquared = (drawDistance + 5.0) * (drawDistance + 5.0)
    local candidateLimit = getActiveDuiLimit()

    for _, tracked in ipairs(snapshot) do
        local vehicle = tracked.entity
        local roughDistanceSquared = tracked.distanceSquared
        if not nearestDistanceSquared or roughDistanceSquared < nearestDistanceSquared then
            nearestDistanceSquared = roughDistanceSquared
        end

        if roughDistanceSquared <= roughLimitSquared and getDuiPayload(vehicle) then
            local geometry = getDuiGeometry(vehicle)
            local signDistanceSquared = distanceSquared(pedCoords, geometry.center)

            if signDistanceSquared <= drawDistance * drawDistance then
                insertNearestCandidate(candidates, {
                    entity = vehicle,
                    geometry = geometry,
                    distanceSquared = signDistanceSquared
                }, candidateLimit)
            end
        end
    end

    local desired = {}
    local limit = #candidates

    for i = 1, limit do
        desired[candidates[i].entity] = candidates[i]
    end

    for entity in pairs(duiSigns) do
        if not desired[entity] or not isTrackedSaleVehicle(entity) then
            destroyDuiSign(entity)
        end
    end

    if limit > 0 then ensureDuiPool() end
    for i = 1, limit do
        local candidate = candidates[i]
        ensureDuiSign(candidate.entity, candidate.geometry)
    end

    if #candidates > 0 then return 'active' end
    if nearestDistanceSquared and nearestDistanceSquared <= scanDistance * scanDistance then return 'near' end
    return 'far'
end

local function getTargetSaleState(entity)
    if not entity or not DoesEntityExist(entity) then return nil end

    local now = GetGameTimer()
    if targetStateCache.entity == entity and targetStateCache.expiresAt > now then
        return targetStateCache.data
    end

    local data = saleVehicles[entity]

    targetStateCache.entity = entity
    targetStateCache.expiresAt = now + 250
    targetStateCache.data = data

    return data
end

local function clearTargetSaleState(entity)
    if targetStateCache.entity == entity then
        targetStateCache.entity = nil
        targetStateCache.expiresAt = 0
        targetStateCache.data = nil
    end
end

local function getListingId(entity)
    local state = getTargetSaleState(entity)
    return state and state.listingId or nil
end

local function metersToCentimeters(value)
    return math.floor(((tonumber(value) or 0.0) * 100.0) + 0.5)
end

local function centimetersToMeters(value)
    return (tonumber(value) or 0) / 100.0
end

local function openSignPlacementMenu(entity)
    local listingId = getListingId(entity)
    if not listingId then return end

    local placement = lib.callback.await('car-sales:server:getSignPlacement', false, listingId)
    if not placement then
        notify('Sign placement is not available.', 'error')
        return
    end

    local ranges = Config.Sign.adjustment
    local input = lib.inputDialog('Adjust Sale Sign', {
        {
            type = 'slider',
            label = 'Left / Right',
            description = 'Centimeters. Negative moves left, positive moves right.',
            min = ranges.x.min,
            max = ranges.x.max,
            default = metersToCentimeters(placement.x),
            required = true
        },
        {
            type = 'slider',
            label = 'Back / Front',
            description = 'Centimeters. Higher moves toward the windshield/front.',
            min = ranges.y.min,
            max = ranges.y.max,
            default = metersToCentimeters(placement.y),
            required = true
        },
        {
            type = 'slider',
            label = 'Down / Up',
            description = 'Centimeters from the vehicle origin.',
            min = ranges.z.min,
            max = ranges.z.max,
            default = metersToCentimeters(placement.z),
            required = true
        },
        {
            type = 'slider',
            label = 'Width',
            description = 'Paper width in centimeters.',
            min = ranges.width.min,
            max = ranges.width.max,
            default = metersToCentimeters(placement.width),
            required = true
        },
        {
            type = 'slider',
            label = 'Height',
            description = 'Paper height in centimeters.',
            min = ranges.height.min,
            max = ranges.height.max,
            default = metersToCentimeters(placement.height),
            required = true
        },
        {
            type = 'slider',
            label = 'Tilt',
            description = 'Centimeters. Positive leans with windshield angle.',
            min = ranges.tilt.min,
            max = ranges.tilt.max,
            default = metersToCentimeters(placement.tilt),
            required = true
        }
    })

    if not input then return end

    TriggerServerEvent('car-sales:server:updateSignPlacement', listingId, {
        x = centimetersToMeters(input[1]),
        y = centimetersToMeters(input[2]),
        z = centimetersToMeters(input[3]),
        width = centimetersToMeters(input[4]),
        height = centimetersToMeters(input[5]),
        tilt = centimetersToMeters(input[6])
    })
end

local function formatUpgradeLevel(value)
    local level = tonumber(value)
    if not level or level < 0 then return 'Stock' end

    return ('Level %d'):format(math.floor(level) + 1)
end

local function formatTurbo(value)
    return value and 'Yes' or 'No'
end

local function formatArmour(value)
    local level = tonumber(value)
    if not level or level < 0 then return 'None' end

    local labels = {
        [0] = '20%',
        [1] = '40%',
        [2] = '60%',
        [3] = '80%',
        [4] = '100%'
    }

    return labels[math.floor(level)] or '100%'
end

local function parseToggleValue(value)
    if value == nil then return nil end
    if type(value) == 'boolean' then return value end
    if value == 'true' then return true end
    if value == 'false' then return false end

    local number = tonumber(value)
    if number ~= nil then return number > 0 end

    return nil
end

local function normalizeVehicleProps(props)
    if type(props) == 'string' then
        props = CarSale.DecodeJson(props, nil)
    end

    if type(props) ~= 'table' then return nil end

    if type(props.props) == 'table' then
        props = props.props
    elseif type(props.vehicleProps) == 'table' then
        props = props.vehicleProps
    elseif type(props.properties) == 'table' then
        props = props.properties
    end

    if type(props.mods) == 'string' then
        props.mods = CarSale.DecodeJson(props.mods, props.mods)
    end

    return props
end

local function getSavedModValue(props, modType, ...)
    props = normalizeVehicleProps(props)
    if not props then return nil end

    if type(props.mods) == 'table' then
        local value = props.mods[modType]
        if value == nil then value = props.mods[tostring(modType)] end
        if value == nil then value = props.mods[modType + 1] end
        if value ~= nil then return value end

        for i = 1, select('#', ...) do
            local key = select(i, ...)
            if props.mods[key] ~= nil then return props.mods[key] end
        end
    end

    local value = props[modType]
    if value == nil then value = props[tostring(modType)] end
    if value == nil then value = props[modType + 1] end
    if value ~= nil then return value end

    for i = 1, select('#', ...) do
        local key = select(i, ...)
        if props[key] ~= nil then return props[key] end
    end

    return nil
end

local function getSavedToggleValue(props, ...)
    props = normalizeVehicleProps(props)
    if not props then return nil end

    if type(props.mods) == 'table' then
        for i = 1, select('#', ...) do
            local key = select(i, ...)
            local parsed = parseToggleValue(props.mods[key])
            if parsed ~= nil then return parsed end
        end
    end

    for i = 1, select('#', ...) do
        local key = select(i, ...)
        local parsed = parseToggleValue(props[key])
        if parsed ~= nil then return parsed end
    end

    return nil
end

local function getSavedVehicleModSummary(data)
    if type(data) ~= 'table' then return nil end

    local props = normalizeVehicleProps(data.props)
    if not props then return nil end

    local engine = getSavedModValue(props, 11, 'modEngine', 'engine')
    local brakes = getSavedModValue(props, 12, 'modBrakes', 'brakes')
    local turbo = getSavedToggleValue(props, 'modTurbo', 'turbo')
    local transmission = getSavedModValue(props, 13, 'modTransmission', 'transmission')
    local suspension = getSavedModValue(props, 15, 'modSuspension', 'suspension')
    local armor = getSavedModValue(props, 16, 'modArmor', 'modArmour', 'armor', 'armour')

    if engine == nil
        and brakes == nil
        and turbo == nil
        and transmission == nil
        and suspension == nil
        and armor == nil then
        return nil
    end

    return {
        vehicle = data.vehicle or CarSale.VehicleDisplayName(props.model or data.model),
        mods = {
            {
                label = 'Engine',
                value = formatUpgradeLevel(engine)
            },
            {
                label = 'Transmission',
                value = formatUpgradeLevel(transmission)
            },
            {
                label = 'Brakes',
                value = formatUpgradeLevel(brakes)
            },
            {
                label = 'Suspension',
                value = formatUpgradeLevel(suspension)
            },
            {
                label = 'Armor',
                value = formatArmour(armor)
            },
            {
                label = 'Turbo',
                value = formatTurbo(turbo)
            }
        }
    }
end

local function hasDisplayedUpgrades(summary)
    if not summary or type(summary.mods) ~= 'table' then return false end

    for _, mod in ipairs(summary.mods) do
        local value = mod and mod.value
        if value and value ~= 'Stock' and value ~= 'No' and value ~= 'None' then
            return true
        end
    end

    return false
end

local function pickVehicleModSummary(...)
    local fallback

    for i = 1, select('#', ...) do
        local summary = select(i, ...)
        if summary and type(summary.mods) == 'table' then
            fallback = fallback or summary
            if hasDisplayedUpgrades(summary) then return summary end
        end
    end

    return fallback
end

local function getLiveVehicleModSummary(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    SetVehicleModKit(vehicle, 0)

    return {
        vehicle = CarSale.VehicleDisplayName(GetEntityModel(vehicle)),
        mods = {
            {
                label = 'Engine',
                value = formatUpgradeLevel(GetVehicleMod(vehicle, 11))
            },
            {
                label = 'Transmission',
                value = formatUpgradeLevel(GetVehicleMod(vehicle, 13))
            },
            {
                label = 'Brakes',
                value = formatUpgradeLevel(GetVehicleMod(vehicle, 12))
            },
            {
                label = 'Suspension',
                value = formatUpgradeLevel(GetVehicleMod(vehicle, 15))
            },
            {
                label = 'Armor',
                value = formatArmour(GetVehicleMod(vehicle, 16))
            },
            {
                label = 'Turbo',
                value = formatTurbo(IsToggleModOn(vehicle, 18))
            }
        }
    }
end

local function openVehicleModsMenu(entity)
    local listingId = getListingId(entity)
    if not listingId then return end

    local saved = lib.callback.await('car-sales:server:getVehicleMods', false, listingId)
    local liveVehicleName = CarSale.VehicleDisplayName(GetEntityModel(entity))
    local jgProps = getJgMechanicTestDriveProps(entity)
    local currentProps = CarSale.GetVehicleProperties(entity)
    local summary = pickVehicleModSummary(
        getSavedVehicleModSummary(saved),
        getSavedVehicleModSummary({ vehicle = liveVehicleName, props = jgProps }),
        getSavedVehicleModSummary({ vehicle = liveVehicleName, props = currentProps }),
        getLiveVehicleModSummary(entity)
    )
    if not summary or type(summary.mods) ~= 'table' then
        notify('Vehicle mods are no longer available.', 'error')
        return
    end

    local options = {}
    for _, mod in ipairs(summary.mods) do
        options[#options + 1] = {
            title = mod.label,
            description = mod.value,
            icon = 'fa-solid fa-wrench'
        }
    end

    lib.registerContext({
        id = 'car_sales_vehicle_mods',
        title = summary.vehicle or 'Vehicle Mods',
        options = options
    })
    lib.showContext('car_sales_vehicle_mods')
end

local function openEditListingMenu(entity)
    local listingId = getListingId(entity)
    if not listingId then return end

    local listing = lib.callback.await('car-sales:server:getListing', false, listingId)
    if not listing or not listing.isSeller then
        notify('Listing details are no longer available.', 'error')
        return
    end

    local input = lib.inputDialog('Edit Listing', {
        {
            type = 'number',
            label = 'Asking Price',
            min = Config.Listing.minPrice,
            max = Config.Listing.maxPrice,
            default = listing.price,
            required = true
        }
    })

    if not input then return end

    TriggerServerEvent('car-sales:server:updateListingPrice', listingId, input[1])
end

local saleTargetOptionNames = {
    'car_sales_details',
    'car_sales_inspect_mods',
    'car_sales_testdrive',
    'car_sales_offer',
    'car_sales_edit',
    'car_sales_adjust_sign',
    'car_sales_cancel'
}

local buyerSaleTargetOptions = {
        {
            name = 'car_sales_details',
            icon = Config.TargetIcons.details,
            label = 'Seller Details',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                local listingId = getListingId(data.entity)
                if not listingId then return end
                local details = lib.callback.await('car-sales:server:getSellerDetails', false, listingId)
                if not details then
                    notify('Seller details are no longer available.', 'error')
                    return
                end
                if not data.entity or not DoesEntityExist(data.entity) then
                    notify('Car sale details are no longer available.', 'error')
                    return
                end

                local state = getTargetSaleState(data.entity)
                if not state then
                    notify('Car sale details are no longer available.', 'error')
                    return
                end
                local options = {
                    {
                        title = details.firstName or details.sellerName,
                        icon = 'fa-solid fa-phone'
                    },
                    {
                        title = CarSale.FormatMoney(state.price or 0),
                        icon = 'fa-solid fa-dollar-sign',
                    },
                    {
                        title = 'Copy Number',
                        icon = 'fa-solid fa-copy',
                        onSelect = function()
                            lib.setClipboard(details.phone)
                            notify('Phone number copied.', 'success')
                        end
                    },
                }

                if phoneContactsEnabled() and details.phone ~= 'Unknown' then
                    options[#options + 1] = {
                        title = 'Save Contact',
                        icon = 'fa-solid fa-address-book',
                        onSelect = function()
                            if hasServerContactIntegration() then
                                TriggerServerEvent('car-sales:server:saveSellerContact', listingId)
                            elseif Config.Phone.contact and Config.Phone.contact.exportResource and Config.Phone.contact.exportName then
                                pcall(function()
                                    exports[Config.Phone.contact.exportResource][Config.Phone.contact.exportName](
                                        details.firstName or details.sellerName,
                                        details.phone
                                    )
                                end)
                            elseif Config.Phone.contact and Config.Phone.contact.event then
                                TriggerEvent(Config.Phone.contact.event, details.firstName or details.sellerName, details.phone)
                            end
                        end
                    }
                end

                lib.registerContext({
                    id = 'car_sales_seller_details',
                    title = 'Seller Details',
                    options = options
                })
                lib.showContext('car_sales_seller_details')
            end
        },
        {
            name = 'car_sales_inspect_mods',
            icon = Config.TargetIcons.inspect,
            label = 'Inspect Mods',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                openVehicleModsMenu(data.entity)
            end
        },
        {
            name = 'car_sales_testdrive',
            icon = Config.TargetIcons.testDrive,
            label = 'Test Drive Vehicle',
            distance = Config.Listing.targetDistance,
            canInteract = function()
                return Config.TestDrive.enabled == true
            end,
            onSelect = function(data)
                if Config.TestDrive.enabled ~= true then
                    notify('Test drives are disabled.', 'error')
                    return
                end
                if testDrive then
                    notify('You are already in a test drive.', 'error')
                    return
                end
                local listingId = getListingId(data.entity)
                if listingId then
                    TriggerServerEvent('car-sales:server:startTestDrive', listingId, getJgMechanicTestDriveProps(data.entity))
                end
            end
        }
    }

local sellerSaleTargetOptions = {
        buyerSaleTargetOptions[1],
        buyerSaleTargetOptions[2],
        buyerSaleTargetOptions[3],
        {
            name = 'car_sales_offer',
            icon = Config.TargetIcons.offer,
            label = 'Offer Purchase',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                local listingId = getListingId(data.entity)
                if listingId then TriggerServerEvent('car-sales:server:offerPurchase', listingId) end
            end
        },
        {
            name = 'car_sales_edit',
            icon = Config.TargetIcons.edit or Config.TargetIcons.view,
            label = 'Edit Listing',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                openEditListingMenu(data.entity)
            end
        },
        {
            name = 'car_sales_adjust_sign',
            icon = Config.TargetIcons.adjust,
            label = 'Adjust Sale Sign',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                openSignPlacementMenu(data.entity)
            end
        },
        {
            name = 'car_sales_cancel',
            icon = Config.TargetIcons.cancel,
            label = 'Remove From Sale',
            distance = Config.Listing.targetDistance,
            onSelect = function(data)
                local listingId = getListingId(data.entity)
                if not listingId then return end
                local result = lib.alertDialog({
                    header = 'Remove Sale Listing',
                    content = 'Cancel this vehicle sale listing?',
                    centered = true,
                    cancel = true,
                    labels = { confirm = 'Remove', cancel = 'Keep Listed' }
                })
                if result == 'confirm' then
                    TriggerServerEvent('car-sales:server:cancelListing', listingId)
                end
            end
        }
    }

registerSaleVehicleTarget = function(entity)
    if not targetRegistered
        or not entity
        or entity == 0
        or not DoesEntityExist(entity)
        or GetResourceState('ox_target') ~= 'started' then
        return
    end

    local state = saleVehicles[entity]
    if not state then return end

    local role = state.seller == GetPlayerServerId(PlayerId()) and 'seller' or 'buyer'
    if saleTargetEntities[entity] == role then return end

    if saleTargetEntities[entity] then
        pcall(function()
            exports.ox_target:removeLocalEntity(entity, saleTargetOptionNames)
        end)
        saleTargetEntities[entity] = nil
    end

    local options = role == 'seller' and sellerSaleTargetOptions or buyerSaleTargetOptions
    local ok = pcall(function()
        exports.ox_target:addLocalEntity(entity, options)
    end)

    if ok then
        saleTargetEntities[entity] = role
    end
end

unregisterSaleVehicleTarget = function(entity)
    if not saleTargetEntities[entity] then return end
    saleTargetEntities[entity] = nil

    if GetResourceState('ox_target') ~= 'started' then return end

    pcall(function()
        exports.ox_target:removeLocalEntity(entity, saleTargetOptionNames)
    end)
end

local function registerTargets()
    if targetRegistered or GetResourceState('ox_target') ~= 'started' then return end
    targetRegistered = true

    for entity in pairs(saleVehicles) do
        registerSaleVehicleTarget(entity)
    end
end

RegisterNetEvent('car-sales:client:useSign', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify('Exit the vehicle before placing a sale sign.', 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, Config.Listing.useDistance, true)
    if not vehicle or vehicle == 0 then
        notify('No nearby vehicle found.', 'error')
        return
    end

    if getSaleData(vehicle, true) then
        notify('This vehicle is already listed.', 'error')
        return
    end

    if CarSale.TableContainsVehicleModel(Config.Listing.vehicleBlacklist, GetEntityModel(vehicle)) then
        notify('This vehicle cannot be listed.', 'error')
        return
    end

    if CarSale.TableContainsVehicleClass(Config.Listing.classBlacklist, GetVehicleClass(vehicle)) then
        notify('This vehicle class cannot be listed.', 'error')
        return
    end

    local input = lib.inputDialog('List Vehicle For Sale', {
        {
            type = 'number',
            label = 'Asking Price',
            min = Config.Listing.minPrice,
            max = Config.Listing.maxPrice,
            required = true
        }
    })

    if not input or not input[1] then return end

    local netId = getEntityNetId(vehicle)
    if not netId or netId == 0 then
        notify('This vehicle is not networked.', 'error')
        return
    end
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent('car-sales:server:createListing', netId, input[1], CarSale.GetVehicleProperties(vehicle))
end)

RegisterNetEvent('car-sales:client:lockVehicle', function(netId)
    local vehicle = getNetEntity(netId)
    if vehicle and vehicle ~= 0 then
        trackSaleVehicle(vehicle)
        saleDoorStates[vehicle] = saleDoorStates[vehicle] or captureDoorState(vehicle)
        applySaleLock(vehicle)
        maintainSalePresentation(vehicle, true)
        rebuildDuiAssignments()
        ensureSaleBlip(vehicle)
    end
end)

RegisterNetEvent('car-sales:client:syncFrameworkLockState', function(netId, lockState)
    local vehicle = getNetEntity(netId)
    if vehicle and vehicle ~= 0 then
        setFrameworkLockState(vehicle, tonumber(lockState) or 0)
    end
end)

RegisterNetEvent('car-sales:client:restoreVehicle', function(netId, plate, sold, buyerSrc)
    local vehicle = getNetEntity(netId)
    if vehicle and vehicle ~= 0 then
        if unregisterSaleVehicleTarget then unregisterSaleVehicleTarget(vehicle) end
        saleVehicles[vehicle] = nil
        destroyDuiSign(vehicle)
        destroySaleBlip(vehicle)
        releaseSaleLock(vehicle, plate, sold, buyerSrc)
    end
end)

RegisterNetEvent('car-sales:client:enablePurchasedVehicle', function(netId, plate)
    local vehicle = getNetEntity(netId)
    if not vehicle then return end

    requestControl(vehicle, 2500)

    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleUndriveable(vehicle, false)
    FreezeEntityPosition(vehicle, false)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, false)
end)

AddStateBagChangeHandler('carSale', nil, function(bagName, _, value)
    local entity = getStateBagEntity(bagName)
    if not entity or entity == 0 or not IsEntityAVehicle(entity) then return end
    clearTargetSaleState(entity)
    if value then
        CreateThread(function()
            Wait(100)
            trackSaleVehicle(entity)
            saleDoorStates[entity] = saleDoorStates[entity] or captureDoorState(entity)
            applySaleLock(entity)
            maintainSalePresentation(entity, true)
            rebuildDuiAssignments()
        end)
    else
        untrackSaleVehicle(entity)
        SetVehicleUndriveable(entity, false)
        FreezeEntityPosition(entity, false)
        SetVehicleDoorsLockedForAllPlayers(entity, false)
        restoreSaleDamageProtection(entity)
        restoreDoorState(entity, saleDoorStates[entity])
        saleDoorStates[entity] = nil
    end
end)

AddStateBagChangeHandler('carSaleData', nil, function(bagName, _, value)
    local entity = getStateBagEntity(bagName)
    if entity and entity ~= 0 and IsEntityAVehicle(entity) then
        local data = normalizeSaleData(value)
        if data then
            trackSaleVehicle(entity, data)
            clearTargetSaleState(entity)
            SetVehicleNumberPlateText(entity, getSaleDisplayPlate(entity))

            local sign = duiSigns[entity]
            if sign then
                sign.geometry = nil
                refreshDuiSign(entity)
            end
        end
    end
end)

CreateThread(function()
    registerTargets()
end)

local function runVehicleCare(snapshot)
    local care = Config.Listing.vehicleCare
    if not care.keepClean and not care.keepWindowsFixed and not care.preventDisplayDamage then
        return false
    end

    local hasNearby = false
    local limit = care.distance or 60.0
    local limitSquared = limit * limit
    for _, tracked in ipairs(snapshot) do
        if tracked.distanceSquared <= limitSquared then
            hasNearby = true
            maintainSalePresentation(tracked.entity)
        end
    end
    return hasNearby
end

local function updateSaleBlips(snapshot)
    if not Config.Blip.enabled then
        for entity in pairs(saleBlips) do destroySaleBlip(entity) end
        return false
    end

    local seen = {}
    local hasNearby = false
    local radiusSquared = Config.Blip.radius * Config.Blip.radius
    for _, tracked in ipairs(snapshot) do
        if tracked.distanceSquared <= radiusSquared then
            hasNearby = true
            ensureSaleBlip(tracked.entity)
            seen[tracked.entity] = true
        end
    end

    for entity in pairs(saleBlips) do
        if not seen[entity] or not isTrackedSaleVehicle(entity) then destroySaleBlip(entity) end
    end
    return hasNearby
end

local function refreshSaleSignsAfterReturn()
    CreateThread(function()
        for entity in pairs(duiSigns) do
            destroyDuiSign(entity)
        end

        for attempt = 1, 6 do
            Wait(attempt == 1 and 250 or 750)
            discoverSaleVehicles()

            local pedCoords = GetEntityCoords(PlayerPedId())
            local snapshot = buildTrackedVehicleSnapshot(pedCoords)

            for _, tracked in ipairs(snapshot) do
                trackSaleVehicle(tracked.entity, tracked.data)
                applySaleLock(tracked.entity)
            end

            rebuildDuiAssignments(pedCoords, snapshot)
            updateSaleBlips(snapshot)
        end
    end)
end

CreateThread(function()
    Wait(1500)
    discoverSaleVehicles()

    local now = GetGameTimer()
    local nextDiscovery = now + (next(saleVehicles)
        and (Config.Listing.saleVehicleDiscoveryMs or 15000)
        or (Config.Listing.saleVehicleDiscoveryIdleMs or 60000))
    local nextDui = now
    local nextCare = now
    local nextBlip = now
    local nextMetrics = now + (Config.Optimization.metricsIntervalMs or 60000)
    local duiScanState = 'far'
    local hasNearbyCare = false
    local hasNearbyBlips = false

    while true do
        now = GetGameTimer()

        if now >= nextDiscovery then
            discoverSaleVehicles()
            nextDiscovery = now + (next(saleVehicles)
                and (Config.Listing.saleVehicleDiscoveryMs or 15000)
                or (Config.Listing.saleVehicleDiscoveryIdleMs or 60000))
        end

        local runDui = now >= nextDui
        local runCare = now >= nextCare
        local runBlips = now >= nextBlip
        if runDui or runCare or runBlips then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local snapshot = buildTrackedVehicleSnapshot(pedCoords)

            if runDui then
                duiScanState = rebuildDuiAssignments(pedCoords, snapshot)
                nextDui = now + getDuiScanInterval(duiScanState)
            end
            if runCare then
                hasNearbyCare = runVehicleCare(snapshot)
                nextCare = now + (hasNearbyCare and Config.Listing.vehicleCare.intervalMs
                    or (Config.Listing.vehicleCare.farIntervalMs or 5000))
            end
            if runBlips then
                hasNearbyBlips = updateSaleBlips(snapshot)
                nextBlip = now + (hasNearbyBlips and Config.Blip.scanIntervalMs
                    or (Config.Blip.farScanIntervalMs or 5000))
            end
        end

        local idleDestroyMs = tonumber(Config.Sign.texture.idleDestroyMs) or 60000
        if duiPoolStarted and not next(duiSigns) and now - duiLastUsedAt >= idleDestroyMs then
            destroyDuiPool()
        end

        if now >= nextMetrics then
            if Config.Optimization.metrics then
                runtimeMetrics.trackedVehicles = countEntries(saleVehicles)
                runtimeMetrics.activeSigns = countEntries(duiSigns)
                runtimeMetrics.duiPoolSize = #duiPool
                print(('[car-sales] client metrics %s'):format(json.encode(runtimeMetrics)))
            end
            nextMetrics = now + (Config.Optimization.metricsIntervalMs or 60000)
        end

        local wakeAt = math.min(nextDiscovery, nextDui, nextCare, nextBlip, nextMetrics)
        Wait(clamp(wakeAt - GetGameTimer(), 100, 5000))
    end
end)

RegisterNetEvent('car-sales:client:chooseBuyer', function(listingId, candidates)
    local options = {}
    for _, buyer in ipairs(candidates) do
        options[#options + 1] = {
            label = ('%s (%s)'):format(buyer.name, buyer.source),
            value = buyer.source
        }
    end

    local input = lib.inputDialog('Choose Buyer', {
        {
            type = 'select',
            label = 'Buyer',
            options = options,
            required = true
        }
    })

    if input and input[1] then
        TriggerServerEvent('car-sales:server:selectBuyer', listingId, tonumber(input[1]))
    end
end)

RegisterNetEvent('car-sales:client:purchasePrompt', function(token, offer)
    local input = lib.inputDialog(offer.negotiated and 'Negotiated Vehicle Offer' or 'Vehicle Purchase Offer', {
        {
            type = 'select',
            label = ('%s from %s for %s'):format(offer.vehicle, offer.seller, CarSale.FormatMoney(offer.price)),
            options = {
                { label = 'Decline', value = 'decline' },
                { label = 'Negotiate', value = 'negotiate' },
                { label = 'Accept', value = 'accept' }
            },
            required = true
        }
    })

    if not input or not input[1] then return end

    if input[1] == 'accept' then
        TriggerServerEvent('car-sales:server:respondOffer', token, true)
    elseif input[1] == 'decline' then
        TriggerServerEvent('car-sales:server:respondOffer', token, false)
    elseif input[1] == 'negotiate' then
        local counter = lib.inputDialog('Negotiate Price', {
            {
                type = 'number',
                label = 'Counter Offer',
                min = Config.Listing.minPrice,
                max = Config.Listing.maxPrice,
                default = offer.price,
                required = true
            }
        })

        if counter and counter[1] then
            TriggerServerEvent('car-sales:server:negotiateOffer', token, counter[1])
        end
    end
end)

RegisterNetEvent('car-sales:client:negotiationPrompt', function(token, offer)
    local input = lib.inputDialog('Counter Offer', {
        {
            type = 'select',
            label = ('%s offered %s for %s'):format(offer.buyer, CarSale.FormatMoney(offer.counterPrice), offer.vehicle),
            description = ('Original asking price: %s'):format(CarSale.FormatMoney(offer.askingPrice)),
            options = {
                { label = 'Accept Counter', value = 'accept' },
                { label = 'Decline Counter', value = 'decline' }
            },
            required = true
        }
    })

    if not input or not input[1] then return end

    TriggerServerEvent('car-sales:server:respondNegotiation', token, input[1] == 'accept')
end)

local function fadeOutForTestDrive()
    if IsScreenFadedOut() then return end

    DoScreenFadeOut(Config.TestDrive.fadeOutMs or 350)
    local timeout = GetGameTimer() + 1500
    while not IsScreenFadedOut() and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function fadeInFromTestDrive()
    if IsScreenFadedIn() then return end
    DoScreenFadeIn(Config.TestDrive.fadeInMs or 500)
end

local function waitForCollision(coords, entity)
    local timeout = GetGameTimer() + (Config.TestDrive.collisionTimeoutMs or 3500)

    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)

        local pedReady = HasCollisionLoadedAroundEntity(PlayerPedId())
        local entityReady = not entity or not DoesEntityExist(entity) or HasCollisionLoadedAroundEntity(entity)
        if pedReady and entityReady then return true end

        Wait(50)
    end

    return false
end

local function movePedTo(coords)
    local ped = PlayerPedId()
    local heading = coords.w or 0.0

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    ClearPedTasksImmediately(ped)

    if StartPlayerTeleport then
        StartPlayerTeleport(PlayerId(), coords.x, coords.y, coords.z, heading, false, true, true)

        local timeout = GetGameTimer() + 4000
        while IsPlayerTeleportActive() and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, heading)
    waitForCollision(coords)
end

local function createTestDriveVehicle(hash, spawn)
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)

    for _ = 1, Config.TestDrive.spawnAttempts or 3 do
        local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            requestControl(vehicle, 3000)
            SetVehicleOnGroundProperly(vehicle)
            waitForCollision(spawn, vehicle)
            return vehicle
        end

        Wait(250)
    end

    return nil
end

local function getVehicleNetId(vehicle)
    local timeout = GetGameTimer() + 3000

    while DoesEntityExist(vehicle) and GetGameTimer() < timeout do
        local netId = getEntityNetId(vehicle)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, true)
            return netId
        end
        Wait(50)
    end

    return nil
end

local function putPedInTestVehicle(vehicle)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)

    local timeout = GetGameTimer() + 2500
    while GetGameTimer() < timeout do
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
        Wait(100)
        if GetVehiclePedIsIn(ped, false) == vehicle then return true end
    end

    return GetVehiclePedIsIn(ped, false) == vehicle
end

local returnMessages = {
    timeout = 'Test drive ended.',
    player_died = 'Returned from test drive.',
    vehicle_destroyed = 'Test drive vehicle was destroyed.',
    exited_vehicle = 'Test drive ended.',
    bucket_failed = 'Could not move you to the test drive.',
    model_load_failed = 'Could not load test drive vehicle.',
    spawn_failed = 'Could not create test drive vehicle.',
    network_failed = 'Could not network test drive vehicle.',
    warp_failed = 'Could not enter the test drive vehicle.'
}

local returnErrors = {
    bucket_failed = true,
    model_load_failed = true,
    spawn_failed = true,
    network_failed = true,
    warp_failed = true
}

local function formatTestDriveTime(milliseconds)
    local seconds = math.max(0, math.ceil(milliseconds / 1000))
    return ('%02d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function drawTestDriveTimer()
    if not Config.TestDrive.drawTimer or not testDrive or not testDrive.endsAt then return end

    local remaining = testDrive.endsAt - GetGameTimer()
    local text = ('Test Drive %s'):format(formatTestDriveTime(remaining))

    DrawRect(0.5, 0.92, 0.16, 0.045, 0, 0, 0, 150)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.905)
end

local function endTestDrive(reason)
    if not testDrive or endingTestDrive then return end
    endingTestDrive = true
    fadeOutForTestDrive()

    local vehicle = testDrive.vehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end

    TriggerServerEvent('car-sales:server:endTestDrive', reason or 'ended')
    testDrive = nil
end

RegisterNetEvent('car-sales:client:prepareTestDrive', function(listingId)
    if testDrive then return end

    fadeOutForTestDrive()
    Wait(Config.TestDrive.transitionHoldMs or 250)
    TriggerServerEvent('car-sales:server:readyForTestDrive', listingId)
end)

RegisterNetEvent('car-sales:client:testDriveFailed', function(message)
    if testDrive and testDrive.vehicle and DoesEntityExist(testDrive.vehicle) then
        SetEntityAsMissionEntity(testDrive.vehicle, true, true)
        DeleteVehicle(testDrive.vehicle)
    end

    testDrive = nil
    endingTestDrive = false
    fadeInFromTestDrive()

    if message then
        notify(message, 'error')
    end
end)

RegisterNetEvent('car-sales:client:startTestDrive', function(data)
    if testDrive then return end

    fadeOutForTestDrive()
    Wait(Config.TestDrive.transitionHoldMs or 250)

    local finishStartFailure = function(reason)
        TriggerServerEvent('car-sales:server:endTestDrive', reason)
    end

    local bucketReady = lib.callback.await(
        'car-sales:server:confirmTestDriveBucket',
        false,
        data.listingId,
        data.targetBucket
    )
    if not bucketReady then
        TriggerServerEvent('car-sales:server:cancelTestDriveStart', 'bucket_failed')
        return
    end

    local model = data.props and data.props.model or data.modelHash or data.model
    local hash = loadModel(model)
    if not hash then
        finishStartFailure('model_load_failed')
        return
    end

    local offset = Config.TestDrive.spawnOffset
    local saleCoords = data.saleCoords
    local spawn = vec4(
        saleCoords.x + offset.x,
        saleCoords.y + offset.y,
        saleCoords.z + offset.z,
        saleCoords.w + offset.w
    )

    local vehicle = createTestDriveVehicle(hash, spawn)
    if not vehicle then
        SetModelAsNoLongerNeeded(hash)
        finishStartFailure('spawn_failed')
        return
    end

    SetVehicleHasBeenOwnedByPlayer(vehicle, false)
    SetVehicleNeedsToBeHotwired(vehicle, false)

    local props = shallowCopy(data.props)
    local jgProps = type(data.jgMechanicProps) == 'table' and shallowCopy(data.jgMechanicProps) or nil
    local testPlate = ('TEST%04d'):format(math.random(0, 9999))

    props.plate = testPlate
    props.dirtLevel = 0
    props.bodyHealth = 1000
    props.windows = {}
    for window = 0, 7 do
        props.windows[tostring(window)] = true
    end

    if jgProps then
        jgProps.plate = testPlate
        jgProps.dirtLevel = 0
        jgProps.bodyHealth = 1000
        jgProps.engineHealth = 1000
        jgProps.tankHealth = 1000
    end

    if jgProps and applyJgMechanicVehicleProperties(vehicle, jgProps) then
        Wait(650)
        applyJgMechanicStanceState(vehicle, jgProps)
        Wait(100)
    else
        CarSale.SetVehicleProperties(vehicle, props)
        applyJgMechanicStanceState(vehicle, data.jgMechanicProps)
        Wait(100)
    end

    SetVehicleDirtLevel(vehicle, 0.0)
    for window = 0, 7 do
        FixVehicleWindow(vehicle, window)
    end

    SetVehicleNumberPlateText(vehicle, testPlate)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleUndriveable(vehicle, false)
    SetEntityInvincible(vehicle, Config.TestDrive.invincibleVehicle)

    local netId = getVehicleNetId(vehicle)
    if not netId then
        DeleteVehicle(vehicle)
        SetModelAsNoLongerNeeded(hash)
        finishStartFailure('network_failed')
        return
    end

    if not putPedInTestVehicle(vehicle) then
        DeleteVehicle(vehicle)
        SetModelAsNoLongerNeeded(hash)
        finishStartFailure('warp_failed')
        return
    end

    TriggerServerEvent('car-sales:server:setTestDriveVehicle', netId)
    Wait(150)
    TriggerServerEvent('car-sales:server:giveTestDriveKeys', netId)

    if jgProps then reapplyTestDriveJgStance(vehicle, jgProps) end

    testDrive = {
        vehicle = vehicle,
        netId = netId,
        endsAt = GetGameTimer() + (data.durationSeconds * 1000)
    }

    Wait(Config.TestDrive.transitionHoldMs or 250)
    fadeInFromTestDrive()
    endingTestDrive = false
    notify('Test drive started.', 'success')

    if Config.TestDrive.drawTimer then
        CreateThread(function()
            while testDrive do
                Wait(0)
                drawTestDriveTimer()
            end
        end)
    end

    CreateThread(function()
        local leftVehicleAt = nil

        while testDrive do
            Wait(500)
            local ped = PlayerPedId()
            if GetGameTimer() >= testDrive.endsAt then
                endTestDrive('timeout')
                break
            end
            if IsEntityDead(ped) then
                endTestDrive('player_died')
                break
            end
            if not DoesEntityExist(testDrive.vehicle) or GetEntityHealth(testDrive.vehicle) <= 0 then
                endTestDrive('vehicle_destroyed')
                break
            end
            if Config.TestDrive.endOnExitVehicle then
                if GetVehiclePedIsIn(ped, false) ~= testDrive.vehicle then
                    leftVehicleAt = leftVehicleAt or GetGameTimer()
                    if GetGameTimer() - leftVehicleAt >= 1000 then
                        endTestDrive('exited_vehicle')
                        break
                    end
                else
                    leftVehicleAt = nil
                end
            end
        end
    end)

    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('car-sales:client:returnFromTestDrive', function(coords, reason)
    fadeOutForTestDrive()
    Wait(Config.TestDrive.transitionHoldMs or 250)
    movePedTo(coords)
    TriggerServerEvent('car-sales:server:finishTestDriveReturn')
end)

RegisterNetEvent('car-sales:client:finishTestDriveReturn', function(reason)
    Wait(Config.TestDrive.transitionHoldMs or 250)
    fadeInFromTestDrive()
    testDrive = nil
    endingTestDrive = false
    refreshSaleSignsAfterReturn()
    notify(returnMessages[reason] or 'Returned from test drive.', returnErrors[reason] and 'error' or 'inform')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity in pairs(saleProtectionStates) do
        restoreSaleDamageProtection(entity)
    end
    for entity in pairs(duiSigns) do
        destroyDuiSign(entity)
    end
    destroyDuiPool()
    for entity in pairs(saleBlips) do
        destroySaleBlip(entity)
    end
    if testDrive and testDrive.vehicle and DoesEntityExist(testDrive.vehicle) then
        DeleteVehicle(testDrive.vehicle)
    end
end)
