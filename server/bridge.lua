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

local function applyServerConfigDefaults()
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
        vehicleBlacklist = {},
        classBlacklist = {},
        persistence = {
            enabled = true
        }
    })

    Config.Sign = applyDefaults(Config.Sign, {
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

    Config.TestDrive = applyDefaults(type(Config.TestDrive) == 'table' and Config.TestDrive or {}, {
        durationSeconds = 120,
        routingBucketBase = 62000,
        routingBucketMax = 62999,
        transitionHoldMs = 250,
        maxPropertiesBytes = 32768
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
end

applyServerConfigDefaults()

Bridge = {}

local QBCore
local phoneCache = {}
local pendingPhoneLookups = {}

local function getCore()
    if QBCore then return QBCore end
    if Config.Framework.name == 'qb' and GetResourceState(Config.Framework.resource) == 'started' then
        QBCore = exports[Config.Framework.resource]:GetCoreObject()
    end
    return QBCore
end

local function useSaleSign(source)
    TriggerClientEvent('car-sales:client:useSign', source)
end

local function normalizePhone(phone)
    phone = phone and tostring(phone) or nil
    if not phone or phone == '' or phone == 'Unknown' then return nil end
    return phone
end

local function getPhoneResource()
    local phone = Config.Phone or {}
    if phone.resource and phone.resource ~= '' then return phone.resource end

    -- Backwards compatibility for configs from older versions of this resource.
    if phone.sdPhone and phone.sdPhone.enabled and phone.sdPhone.resource then return phone.sdPhone.resource end
    if phone.lbPhone and phone.lbPhone.enabled and phone.lbPhone.resource then return phone.lbPhone.resource end

    return nil
end

local function getEnsureOfflineNumber()
    local phone = Config.Phone or {}
    if phone.ensureOfflineNumber ~= nil then return phone.ensureOfflineNumber == true end
    return phone.sdPhone and phone.sdPhone.ensureOfflineNumber == true
end

local function getCharinfoPhoneKeys()
    local phone = Config.Phone or {}
    return phone.charinfoKeys or { 'phone', 'phoneNumber', 'number' }
end

local function isPhoneResourceAvailable(resource)
    return resource
        and getPhoneResource() == resource
        and GetResourceState(resource) == 'started'
end

local function isLbPhoneAvailable()
    return isPhoneResourceAvailable('lb-phone')
end

local function getLbPhoneResource()
    return getPhoneResource()
end

local function isSdPhoneAvailable()
    return isPhoneResourceAvailable('sd-phone')
end

local function getSdPhoneResource()
    return getPhoneResource()
end

local function getLbPhoneBySource(src)
    if not isLbPhoneAvailable() then return nil end

    local statePlayer = Player and Player(src) or nil
    local playerState = statePlayer and statePlayer.state or nil
    local statePhone = playerState and normalizePhone(playerState.phoneNumber)
    if statePhone then return statePhone end

    local ok, phone = pcall(function()
        return exports[getLbPhoneResource()]:GetEquippedPhoneNumber(src)
    end)

    if ok then return normalizePhone(phone) end

    return nil
end

local function getSdPhoneBySource(src)
    if not isSdPhoneAvailable() then return nil end

    local ok, phone = pcall(function()
        return exports[getSdPhoneResource()]:getPhoneNumber(tonumber(src))
    end)

    if ok then return normalizePhone(phone) end

    return nil
end

local function getQbPhoneByIdentifier(identifier, cb)
    MySQL.prepare('SELECT charinfo FROM players WHERE citizenid = ?', { identifier }, function(charinfoJson)
        local phone = 'Unknown'
        local charinfo = CarSale.DecodeJson(charinfoJson, {})
        for _, key in ipairs(getCharinfoPhoneKeys()) do
            if charinfo[key] and tostring(charinfo[key]) ~= '' then
                phone = tostring(charinfo[key])
                break
            end
        end
        cb(phone)
    end)
end

local function getLbPhoneByIdentifier(identifier, cb)
    if not isLbPhoneAvailable() or not identifier then
        cb(nil)
        return
    end

    local player = Bridge.GetPlayerByIdentifier(identifier)
    local src = player and player.PlayerData and (player.PlayerData.source or player.PlayerData.src) or nil
    local phone = src and getLbPhoneBySource(src) or nil
    if phone then
        cb(phone)
        return
    end

    MySQL.prepare('SELECT phone_number FROM phone_last_phone WHERE id = ? LIMIT 1', { identifier }, function(lastPhone)
        lastPhone = normalizePhone(lastPhone)
        if lastPhone then
            cb(lastPhone)
            return
        end

        MySQL.prepare([[
            SELECT phone_number
            FROM phone_phones
            WHERE owner_id = ? OR id = ?
            ORDER BY last_seen DESC
            LIMIT 1
        ]], { identifier, identifier }, function(rowPhone)
            cb(normalizePhone(rowPhone))
        end)
    end)
end

local function getSdPhoneByIdentifier(identifier, cb)
    if not isSdPhoneAvailable() or not identifier then
        cb(nil)
        return
    end

    local ok, phone = pcall(function()
        return exports[getSdPhoneResource()]:getPhoneNumberByIdentifier(identifier, getEnsureOfflineNumber())
    end)

    phone = ok and normalizePhone(phone) or nil
    if phone then
        cb(phone)
        return
    end

    MySQL.prepare([[
        SELECT phone_number
        FROM phone_settings
        WHERE citizenid = ? AND device = 'phone'
        LIMIT 1
    ]], { identifier }, function(rowPhone)
        cb(normalizePhone(rowPhone))
    end)
end

local function splitContactName(name)
    name = tostring(name or ''):match('^%s*(.-)%s*$')
    if name == '' then return 'Seller', '' end

    local first, last = name:match('^(%S+)%s*(.-)%s*$')
    return first or name, last or ''
end

local function registerQbItem(core)
    if not Config.Inventory.registerQbItem or not core or not core.Shared then return false end

    core.Shared.Items = core.Shared.Items or {}
    if core.Shared.Items[Config.Inventory.signItem] then return true end

    core.Shared.Items[Config.Inventory.signItem] = {
        name = Config.Inventory.signItem,
        label = 'Car Sale Sign',
        weight = 500,
        type = 'item',
        image = Config.Inventory.signItem .. '.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Place a for-sale sign in one of your owned vehicles.'
    }

    return true
end

local function registerUsableItem()
    local registered = false

    if GetResourceState(Config.Inventory.resource) == 'started' then
        if Config.Inventory.registerQbItem then
            local itemCheckOk, oxItem = pcall(function()
                return exports[Config.Inventory.resource]:Items(Config.Inventory.signItem)
            end)

            if itemCheckOk and not oxItem then
                CarSale.Debug(
                    ('ox_inventory item "%s" is not registered. Add the item definition from README.md to ox_inventory/data/items.lua.')
                        :format(Config.Inventory.signItem)
                )
            elseif not itemCheckOk then
                CarSale.Debug(
                    ('Could not check ox_inventory item "%s". Add the item definition from README.md to ox_inventory/data/items.lua.')
                        :format(Config.Inventory.signItem)
                )
            elseif oxItem and (not oxItem.client or oxItem.client.export ~= 'carsale-script.useCarSaleSign') then
                CarSale.Debug(
                    ('ox_inventory item "%s" should use client.export = "carsale-script.useCarSaleSign".')
                        :format(Config.Inventory.signItem)
                )
            end
        end

        registered = true
        return registered
    end

    local core = getCore()
    if core then
        registerQbItem(core)

        if core.Functions.CreateUseableItem then
            core.Functions.CreateUseableItem(Config.Inventory.signItem, function(source)
                useSaleSign(source)
            end)
            registered = true
        end
    end

    return registered
end

function Bridge.GetPlayer(src)
    local core = getCore()
    if core then return core.Functions.GetPlayer(tonumber(src)) end
    return nil
end

function Bridge.GetPlayerByIdentifier(identifier)
    local core = getCore()
    if core then return core.Functions.GetPlayerByCitizenId(identifier) end
    return nil
end

function Bridge.GetIdentifier(src)
    local player = Bridge.GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

function Bridge.GetLicense(src)
    local player = Bridge.GetPlayer(src)
    return player and player.PlayerData and player.PlayerData.license or nil
end

function Bridge.GetName(src)
    local player = Bridge.GetPlayer(src)
    if not player or not player.PlayerData then return GetPlayerName(src) or 'Unknown' end
    local charinfo = player.PlayerData.charinfo or {}
    local name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):match('^%s*(.-)%s*$')
    return name ~= '' and name or player.PlayerData.name or GetPlayerName(src) or 'Unknown'
end

function Bridge.GetFirstName(src)
    local player = Bridge.GetPlayer(src)
    local charinfo = player and player.PlayerData and player.PlayerData.charinfo or {}
    if charinfo.firstname and tostring(charinfo.firstname) ~= '' then
        return tostring(charinfo.firstname)
    end

    local fullName = Bridge.GetName(src)
    return (fullName:match('^(%S+)') or fullName or 'Unknown')
end

function Bridge.GetPhoneByPlayer(player)
    if not player or not player.PlayerData then return 'Unknown' end
    local src = player.PlayerData.source or player.PlayerData.src
    local sdPhone = src and getSdPhoneBySource(src) or nil
    if sdPhone then return sdPhone end

    local lbPhone = src and getLbPhoneBySource(src) or nil
    if lbPhone then return lbPhone end

    local charinfo = player.PlayerData.charinfo or {}
    for _, key in ipairs(getCharinfoPhoneKeys()) do
        if charinfo[key] and tostring(charinfo[key]) ~= '' then
            return tostring(charinfo[key])
        end
    end
    return 'Unknown'
end

function Bridge.GetPhoneByIdentifier(identifier, cb)
    if not identifier then
        cb('Unknown')
        return
    end

    local now = GetGameTimer()
    local cached = phoneCache[identifier]
    if cached and cached.expiresAt > now then
        cb(cached.phone)
        return
    end

    if pendingPhoneLookups[identifier] then
        pendingPhoneLookups[identifier][#pendingPhoneLookups[identifier] + 1] = cb
        return
    end
    pendingPhoneLookups[identifier] = { cb }

    local function finish(phone)
        phone = normalizePhone(phone) or 'Unknown'
        phoneCache[identifier] = {
            phone = phone,
            expiresAt = GetGameTimer() + (Config.Phone.cacheMs or 300000)
        }

        local callbacks = pendingPhoneLookups[identifier] or {}
        pendingPhoneLookups[identifier] = nil
        for _, callback in ipairs(callbacks) do callback(phone) end
    end

    local player = Bridge.GetPlayerByIdentifier(identifier)
    if player then
        finish(Bridge.GetPhoneByPlayer(player))
        return
    end

    getSdPhoneByIdentifier(identifier, function(sdPhone)
        if sdPhone then
            finish(sdPhone)
            return
        end

        getLbPhoneByIdentifier(identifier, function(lbPhone)
            if lbPhone then
                finish(lbPhone)
                return
            end

            getQbPhoneByIdentifier(identifier, finish)
        end)
    end)
end

local function saveSdPhoneContact(src, contactName, contactPhone, cb)
    if not isSdPhoneAvailable() then
        cb(false, 'sd-phone is not running.')
        return
    end

    contactPhone = normalizePhone(contactPhone)
    if not contactPhone then
        cb(false, 'Seller phone number is not available.')
        return
    end

    local ok, result = pcall(function()
        return exports[getSdPhoneResource()]:addContact(tonumber(src), {
            name = tostring(contactName or 'Seller'),
            phone = contactPhone
        })
    end)

    if not ok then
        cb(false, 'Could not save contact.')
        return
    end

    if type(result) == 'table' then
        cb(result.success == true, result.message or (result.success and 'Contact saved.' or 'Could not save contact.'))
        return
    end

    cb(result ~= false, result ~= false and 'Contact saved.' or 'Could not save contact.')
end

local function saveLbPhoneContact(src, contactName, contactPhone, cb)
    if not isLbPhoneAvailable() then
        cb(false, 'lb-phone is not running.')
        return
    end

    contactPhone = normalizePhone(contactPhone)
    if not contactPhone then
        cb(false, 'Seller phone number is not available.')
        return
    end

    local ownerPhone = getLbPhoneBySource(src)
    local finish = function(phone)
        phone = normalizePhone(phone)
        if not phone then
            cb(false, 'Your lb-phone number is not available.')
            return
        end
        if phone == contactPhone then
            cb(false, 'You cannot save your own number.')
            return
        end

        local firstName, lastName = splitContactName(contactName)
        MySQL.update([[
            INSERT INTO phone_phone_contacts (phone_number, contact_phone_number, firstname, lastname)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                firstname = VALUES(firstname),
                lastname = VALUES(lastname)
        ]], { phone, contactPhone, firstName, lastName }, function(affectedRows)
            cb(affectedRows ~= nil, affectedRows ~= nil and 'Contact saved.' or 'Could not save contact.')
        end)
    end

    if ownerPhone then
        finish(ownerPhone)
        return
    end

    getLbPhoneByIdentifier(Bridge.GetIdentifier(src), finish)
end

function Bridge.SavePhoneContact(src, contactName, contactPhone, cb)
    if isSdPhoneAvailable() then
        saveSdPhoneContact(src, contactName, contactPhone, cb)
        return
    end

    if isLbPhoneAvailable() then
        saveLbPhoneContact(src, contactName, contactPhone, cb)
        return
    end

    cb(false, 'No supported phone resource is running.')
end

function Bridge.GetBank(src)
    local player = Bridge.GetPlayer(src)
    if not player then return 0 end
    return tonumber(player.Functions.GetMoney('bank')) or 0
end

function Bridge.GetCash(src)
    local player = Bridge.GetPlayer(src)
    if not player then return 0 end
    return tonumber(player.Functions.GetMoney('cash')) or 0
end

function Bridge.RemoveBank(src, amount, reason)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    if Bridge.GetBank(src) < amount then return false end
    local result = player.Functions.RemoveMoney('bank', amount, reason or 'Vehicle purchase')
    return result ~= false
end

function Bridge.RemoveCash(src, amount, reason)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    if Bridge.GetCash(src) < amount then return false end
    local result = player.Functions.RemoveMoney('cash', amount, reason or 'Vehicle purchase')
    return result ~= false
end

function Bridge.AddBank(src, amount, reason)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    local result = player.Functions.AddMoney('bank', amount, reason or 'Vehicle sale')
    return result ~= false
end

function Bridge.AddCash(src, amount, reason)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    local result = player.Functions.AddMoney('cash', amount, reason or 'Vehicle sale')
    return result ~= false
end

function Bridge.HasItem(src, item, amount)
    amount = amount or 1
    if GetResourceState(Config.Inventory.resource) == 'started' then
        local count = exports[Config.Inventory.resource]:Search(src, 'count', item)
        return (tonumber(count) or 0) >= amount
    end

    local player = Bridge.GetPlayer(src)
    local invItem = player and player.Functions.GetItemByName(item)
    return invItem and invItem.amount >= amount
end

function Bridge.RemoveItem(src, item, amount)
    amount = amount or 1
    if GetResourceState(Config.Inventory.resource) == 'started' then
        return exports[Config.Inventory.resource]:RemoveItem(src, item, amount)
    end

    local player = Bridge.GetPlayer(src)
    return player and player.Functions.RemoveItem(item, amount)
end

function Bridge.AddItem(src, item, amount)
    amount = amount or 1
    if GetResourceState(Config.Inventory.resource) == 'started' then
        return exports[Config.Inventory.resource]:AddItem(src, item, amount)
    end

    local player = Bridge.GetPlayer(src)
    return player and player.Functions.AddItem(item, amount)
end

function Bridge.GiveKeys(src, vehicle, plate)
    if not Config.Keys.giveToBuyer then return end

    if GetResourceState(Config.Keys.qbxResource) == 'started' then
        local ok = pcall(function()
            exports[Config.Keys.qbxResource]:GiveKeys(src, vehicle, true)
        end)
        if ok then return end
    end

    if Config.Keys.customGiveEvent then
        TriggerEvent(Config.Keys.customGiveEvent, src, plate, vehicle)
        return
    end

    TriggerClientEvent(Config.Keys.qbEvent, src, plate)
end

function Bridge.RemoveKeys(src, vehicle, plate)
    if not Config.Keys.removeFromSeller then return end

    if GetResourceState(Config.Keys.qbxResource) == 'started' then
        pcall(function()
            exports[Config.Keys.qbxResource]:RemoveKeys(src, vehicle)
        end)
    end

    if Config.Keys.customRemoveEvent then
        TriggerEvent(Config.Keys.customRemoveEvent, src, plate, vehicle)
    end
end

CreateThread(function()
    Wait(1000)
    registerUsableItem()
end)
