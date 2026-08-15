local listings = {}
local listingsByPlate = {}
local listingsByStoragePlate = {}
local listingsByNetId = {}
local pendingOffers = {}
local activeTestDrives = {}
local rateLimits = {}
local pendingListingPlates = {}
local pendingListingNetIds = {}
local activeTransactions = {}
local vehicleStorageHookId
local schemaReady = false
local schemaError
local serverMetrics = {
    stateWrites = 0,
    lockSyncs = 0,
    keepAliveRepairs = 0,
    listingsCreated = 0,
    transactionsStarted = 0,
    transactionsCompleted = 0,
    transactionsRequiringReview = 0
}

CreateThread(function()
    Wait(1500)
    local ok, err = pcall(function()
        MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `car_sale_active_locks` (
            `plate` VARCHAR(32) NOT NULL,
            `listing_id` INT DEFAULT NULL,
            `seller_identifier` VARCHAR(100) NOT NULL,
            `vehicle_net_id` INT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`),
            KEY `idx_car_sale_lock_listing` (`listing_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
        MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `car_sale_transactions` (
            `token` VARCHAR(96) NOT NULL,
            `listing_id` INT NOT NULL,
            `plate` VARCHAR(32) NOT NULL,
            `seller_identifier` VARCHAR(100) NOT NULL,
            `buyer_identifier` VARCHAR(100) NOT NULL,
            `amount` INT NOT NULL,
            `status` VARCHAR(32) NOT NULL,
            `last_error` VARCHAR(255) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`token`),
            KEY `idx_car_sale_transaction_status` (`status`, `updated_at`),
            KEY `idx_car_sale_transaction_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
        MySQL.update.await([[
        UPDATE car_sale_history
        SET status = 'cancelled', cancel_reason = 'resource_start_reconcile', completed_at = CURRENT_TIMESTAMP
        WHERE status = 'active'
        ]])
        MySQL.update.await('DELETE FROM car_sale_active_locks')
        local reconciled = MySQL.update.await([[
        UPDATE car_sale_transactions
        SET status = 'manual_review', last_error = 'resource restarted during transaction'
        WHERE status NOT IN ('completed', 'failed', 'refunded', 'rolled_back', 'manual_review')
        ]]) or 0
        serverMetrics.transactionsRequiringReview = serverMetrics.transactionsRequiringReview + reconciled

        local indexCheckOk, plateIndex = pcall(function()
            return MySQL.scalar.await([[
                SELECT 1
                FROM information_schema.statistics
                WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?
                LIMIT 1
            ]], { Config.Database.vehicleTable, Config.Database.plateColumn })
        end)
        if indexCheckOk and not plateIndex then
            print(('[car-sales] warning: %s.%s is not indexed; ownership lookups will slow down as the table grows')
                :format(Config.Database.vehicleTable, Config.Database.plateColumn))
        end
    end)

    if not ok then
        schemaError = tostring(err)
        print(('[car-sales] database initialization failed: %s'):format(schemaError))
        return
    end
    schemaReady = true
end)

local function incrementMetric(name, amount)
    serverMetrics[name] = (serverMetrics[name] or 0) + (amount or 1)
end

local function countEntries(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function rateLimited(src, action)
    local now = GetGameTimer()
    rateLimits[src] = rateLimits[src] or {}
    local last = rateLimits[src][action] or 0
    if now - last < Config.Listing.rateLimitMs then return true end
    rateLimits[src][action] = now
    return false
end

local function getPedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function getNetEntity(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end
    if NetworkDoesNetworkIdExist and not NetworkDoesNetworkIdExist(netId) then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    return entity
end

local function quoteIdentifier(identifier)
    identifier = tostring(identifier or '')
    if not identifier:match('^[%w_]+$') then
        error(('Invalid database identifier: %s'):format(identifier))
    end
    return ('`%s`'):format(identifier)
end

local function findVehicleByPlate(plate)
    local db = Config.Database
    local columns = {}
    local seen = {}
    for _, column in ipairs({ db.ownerColumn, db.modelColumn, db.propsColumn }) do
        if not seen[column] then
            columns[#columns + 1] = quoteIdentifier(column)
            seen[column] = true
        end
    end

    return MySQL.single.await(('SELECT %s FROM %s WHERE %s = ? LIMIT 1'):format(
        table.concat(columns, ', '),
        quoteIdentifier(db.vehicleTable),
        quoteIdentifier(db.plateColumn)
    ), { plate })
end

local function readVehicleProps(row, plate, model)
    local props = CarSale.DecodeJson(row and row[Config.Database.propsColumn], {})
    props.plate = plate
    props.model = props.model or model
    return props
end

local function playerNearListing(src, listing, distance)
    local coords = getPedCoords(src)
    local vehicle = getNetEntity(listing.vehicleNetId)
    if not coords or not vehicle then return false end
    return CarSale.VectorDistance(coords, GetEntityCoords(vehicle)) <= distance
end

local function getDefaultSignSize()
    local base = Config.Sign.placement.baseSize
    local scale = tonumber(Config.Sign.placement.scale) or 1.0
    return base.x * scale, base.y * scale
end

local function getDefaultSignPlacement()
    local width, height = getDefaultSignSize()

    return {
        x = Config.Sign.placement.offset.x,
        y = Config.Sign.placement.offset.y,
        z = Config.Sign.placement.offset.z,
        width = width,
        height = height,
        tilt = Config.Sign.placement.tilt
    }
end

local function clampPlacementValue(value, range, fallback)
    value = tonumber(value) or fallback
    local centimeters = math.floor((value * 100.0) + 0.5)

    if centimeters < range.min then centimeters = range.min end
    if centimeters > range.max then centimeters = range.max end

    return centimeters / 100.0
end

local function sanitizeSignPlacement(raw)
    local base = getDefaultSignPlacement()
    local ranges = Config.Sign.adjustment

    raw = type(raw) == 'table' and raw or {}

    return {
        x = clampPlacementValue(raw.x, ranges.x, base.x),
        y = clampPlacementValue(raw.y, ranges.y, base.y),
        z = clampPlacementValue(raw.z, ranges.z, base.z),
        width = clampPlacementValue(raw.width, ranges.width, base.width),
        height = clampPlacementValue(raw.height, ranges.height, base.height),
        tilt = clampPlacementValue(raw.tilt, ranges.tilt, base.tilt)
    }
end

local function phoneContactsEnabled()
    local phone = Config.Phone or {}
    if phone.saveContacts ~= nil then return phone.saveContacts == true end
    return not phone.contact or phone.contact.enabled ~= false
end

local function normalizeStoragePlate(plate)
    return CarSale.NormalizePlate(plate):gsub('%s+', '')
end

local function getVehicleStoragePlate(payload)
    if type(payload) ~= 'table' then return nil end

    local inventoryId = tostring(payload.inventoryId or '')
    local inventoryType = tostring(payload.inventoryType or ''):lower()
    local plate = inventoryId:match('^[Tt][Rr][Uu][Nn][Kk][%-%_]*(.+)$')
        or inventoryId:match('^[Gg][Ll][Oo][Vv][Ee][Bb][Oo][Xx][%-%_]*(.+)$')
        or inventoryId:match('^[Gg][Ll][Oo][Vv][Ee][%-%_]*(.+)$')

    if not plate and (inventoryType == 'trunk' or inventoryType == 'glovebox' or inventoryType == 'glove') then
        plate = inventoryId
    end

    plate = CarSale.Trim(plate or '')
    if plate == '' then return nil end

    return plate
end

local function isListedVehicleStorage(payload)
    local plate = getVehicleStoragePlate(payload)
    if not plate then return false end

    local normalizedPlate = CarSale.NormalizePlate(plate)
    if listingsByPlate[normalizedPlate] then return true end

    local storagePlate = normalizeStoragePlate(plate)
    return storagePlate ~= '' and listingsByStoragePlate[storagePlate] ~= nil
end

local function registerListedVehicleStorageHook()
    if vehicleStorageHookId or not Config.Inventory.blockListedVehicleStorage then return end

    local inventoryResource = Config.Inventory.resource
    if not inventoryResource or GetResourceState(inventoryResource) ~= 'started' then return end

    local ok, hookId = pcall(function()
        return exports[inventoryResource]:registerHook('openInventory', function(payload)
            if not isListedVehicleStorage(payload) then return end

            if payload.source then
                CarSale.Notify(payload.source, Config.Notifications.title, 'Vehicle storage is locked while listed for sale.', 'error')
            end

            return false
        end, {
            inventoryFilter = {
                '^trunk',
                '^glove',
            }
        })
    end)

    if ok and hookId then
        vehicleStorageHookId = hookId
        CarSale.Debug(('Registered listed vehicle storage lockout hook with %s.'):format(inventoryResource))
    elseif not ok then
        CarSale.Debug(('Could not register listed vehicle storage lockout hook with %s: %s'):format(
            inventoryResource,
            tostring(hookId)
        ))
    end
end

local function isVehicleEntity(entity)
    if IsEntityAVehicle then return IsEntityAVehicle(entity) end
    if GetEntityType then return GetEntityType(entity) == 2 end
    return true
end

local function callNative(fn, ...)
    if fn then return fn(...) end
end

local function getListingStateData(listing)
    return {
        listingId = listing.id,
        seller = listing.sellerSource,
        price = listing.price,
        originalPlate = listing.originalPlate,
        contactName = listing.sellerFirstName,
        contactPhone = listing.sellerPhone,
        placement = listing.signPlacement,
        revision = listing.stateRevision or 1
    }
end

local function publishListingData(listing, vehicle)
    vehicle = vehicle or getNetEntity(listing.vehicleNetId)
    if not vehicle then return false end

    Entity(vehicle).state:set('carSaleData', getListingStateData(listing), true)
    incrementMetric('stateWrites')
    return true
end

local function setSaleState(state, listing)
    if not listing then
        state:set('carSale', false, true)
        state:set('carSaleData', nil, true)
        incrementMetric('stateWrites', 2)
        return
    end

    state:set('carSaleData', getListingStateData(listing), true)
    state:set('carSale', true, true)
    incrementMetric('stateWrites', 2)
end

local function syncFrameworkLockState(listing, vehicle, lockState, force)
    if not Config.Keys.lockStateEvent or not vehicle then return end

    local owner = NetworkGetEntityOwner and NetworkGetEntityOwner(vehicle) or nil
    owner = tonumber(owner)
    if not owner or owner <= 0 then return end
    if not force and listing.lastLockOwner == owner and listing.lastLockState == lockState then return end

    listing.lastLockOwner = owner
    listing.lastLockState = lockState
    TriggerClientEvent('car-sales:client:syncFrameworkLockState', owner, listing.vehicleNetId, lockState)
    incrementMetric('lockSyncs')
end

local function setVehicleState(listing, active)
    local vehicle = getNetEntity(listing.vehicleNetId)
    if not vehicle then return end

    setSaleState(Entity(vehicle).state, active and listing or nil)

    if active then
        if Config.Listing.persistence.enabled then
            callNative(SetEntityAsMissionEntity, vehicle, true, true)
            callNative(SetEntityOrphanMode, vehicle, 2)
        end

        callNative(FreezeEntityPosition, vehicle, true)
        callNative(SetVehicleDoorsLocked, vehicle, 2)
        callNative(SetVehicleEngineOn, vehicle, false, true, true)
        callNative(SetVehicleNumberPlateText, vehicle, listing.originalPlate)
        syncFrameworkLockState(listing, vehicle, 2, true)
    end
end

local function keepListedVehicleAlive(listing)
    if not listing or listing.cleaned then return false end

    local vehicle = getNetEntity(listing.vehicleNetId)
    if not vehicle then return false end

    local state = Entity(vehicle).state
    local stateData = state and state.carSaleData or nil
    if not state or state.carSale ~= true or type(stateData) ~= 'table' or tonumber(stateData.listingId) ~= listing.id then
        setSaleState(Entity(vehicle).state, listing)
        incrementMetric('keepAliveRepairs')
    end

    if not IsEntityPositionFrozen or not IsEntityPositionFrozen(vehicle) then
        callNative(FreezeEntityPosition, vehicle, true)
    end
    if not GetVehicleDoorLockStatus or GetVehicleDoorLockStatus(vehicle) ~= 2 then
        callNative(SetVehicleDoorsLocked, vehicle, 2)
    end
    if not GetIsVehicleEngineRunning or GetIsVehicleEngineRunning(vehicle) then
        callNative(SetVehicleEngineOn, vehicle, false, true, true)
    end
    syncFrameworkLockState(listing, vehicle, 2, false)
    return true
end

local historyUpdateQuery = [[
    UPDATE car_sale_history
    SET status = ?, buyer_identifier = ?, buyer_name = ?, cancel_reason = ?, price = ?, completed_at = CURRENT_TIMESTAMP
    WHERE id = ?
]]

local function updateHistory(listing, status, buyerIdentifier, buyerName, reason, deferred)
    local values = { status, buyerIdentifier, buyerName, reason, listing.salePrice or listing.price, listing.id }
    if deferred then
        MySQL.prepare(historyUpdateQuery, values)
        return true
    end

    local updated = MySQL.prepare.await(historyUpdateQuery, values)
    if not updated or updated < 1 then
        print(('[car-sales] failed to update history for listing %s to %s'):format(listing.id, status))
        return false
    end
    return true
end

local function cleanupListing(listing, reason, sold, buyerSrc, deferHistory)
    if not listing or listing.cleaned then return end
    listing.cleaned = true

    local vehicle = getNetEntity(listing.vehicleNetId)
    if vehicle then
        setSaleState(Entity(vehicle).state)
        callNative(FreezeEntityPosition, vehicle, false)
        callNative(SetVehicleDoorsLocked, vehicle, sold and 1 or 0)
        callNative(SetVehicleNumberPlateText, vehicle, listing.originalPlate)
        syncFrameworkLockState(listing, vehicle, sold and 1 or 0, true)
        TriggerClientEvent('car-sales:client:restoreVehicle', -1, listing.vehicleNetId, listing.originalPlate, sold, buyerSrc)
    end

    listings[listing.id] = nil
    listingsByPlate[listing.originalPlate] = nil
    listingsByStoragePlate[normalizeStoragePlate(listing.originalPlate)] = nil
    listingsByNetId[listing.vehicleNetId] = nil
    MySQL.update('DELETE FROM car_sale_active_locks WHERE plate = ?', { listing.originalPlate })

    if listing.consumedSign then
        local shouldReturn = (sold and Config.Inventory.returnSignOnSale) or ((not sold) and Config.Inventory.returnSignOnCancel)
        if shouldReturn and listing.sellerSource and Bridge.GetPlayer(listing.sellerSource) then
            Bridge.AddItem(listing.sellerSource, Config.Inventory.signItem, 1)
        end
    end

    if sold then
        updateHistory(listing, 'sold', listing.buyerIdentifier, listing.buyerName, nil, deferHistory)
    else
        updateHistory(listing, 'cancelled', nil, nil, reason or 'cancelled', deferHistory)
    end
end

local function sellerOwnsListing(src, listing)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier or identifier ~= listing.sellerIdentifier then return false end
    return true
end

local function setListingSellerSource(listing, sellerSrc)
    if not listing or listing.sellerSource == sellerSrc then return end

    listing.sellerSource = sellerSrc
    listing.stateRevision = (listing.stateRevision or 1) + 1

    local vehicle = getNetEntity(listing.vehicleNetId)
    if vehicle then
        publishListingData(listing, vehicle)
    end
end

local function refreshSellerSource(src, listing)
    if sellerOwnsListing(src, listing) then
        setListingSellerSource(listing, src)
        return true
    end

    return false
end

local function findSellerSource(identifier)
    if not identifier then return nil end
    local player = Bridge.GetPlayerByIdentifier(identifier)
    return player and player.PlayerData and tonumber(player.PlayerData.source or player.PlayerData.src) or nil
end

local function refreshListingRoles()
    for _, listing in pairs(listings) do
        local src = listing.sellerSource
        local currentIdentifier = src and Bridge.GetIdentifier(src) or nil

        if currentIdentifier ~= listing.sellerIdentifier then
            setListingSellerSource(listing, findSellerSource(listing.sellerIdentifier))
        end
    end

    for token, offer in pairs(pendingOffers) do
        local listing = listings[offer.listingId]
        local sellerIdentifier = offer.sellerSrc and Bridge.GetIdentifier(offer.sellerSrc) or nil
        local buyerIdentifier = offer.buyerSrc and Bridge.GetIdentifier(offer.buyerSrc) or nil

        if not listing
            or sellerIdentifier ~= listing.sellerIdentifier
            or buyerIdentifier ~= offer.buyerIdentifier then
            pendingOffers[token] = nil
        end
    end
end

local function pickTestDriveBucket(src)
    local base = Config.TestDrive.routingBucketBase
    local max = Config.TestDrive.routingBucketMax
    local span = (max - base) + 1
    if span <= 0 then return nil end

    local used = {}
    for _, drive in pairs(activeTestDrives) do
        if drive.testBucket then used[drive.testBucket] = true end
    end

    local first = base + (src % span)
    for i = 0, span - 1 do
        local bucket = base + ((first - base + i) % span)
        if not used[bucket] then return bucket end
    end

    return nil
end

local function setPlayerBucket(src, bucket)
    for _ = 1, 3 do
        SetPlayerRoutingBucket(src, bucket)
        Wait(Config.TestDrive.transitionHoldMs or 250)
        if GetPlayerRoutingBucket(src) == bucket then return true end
    end

    return false
end

local function failTestDriveStart(src, message)
    local drive = activeTestDrives[src]
    activeTestDrives[src] = nil

    if drive and drive.originalBucket ~= nil then
        setPlayerBucket(src, drive.originalBucket)
    end

    TriggerClientEvent('car-sales:client:testDriveFailed', src, message or 'Could not start test drive.')
end

local function sanitizeTestDriveProperties(properties)
    if type(properties) ~= 'table' then return nil end
    local ok, encoded = pcall(json.encode, properties)
    if not ok or #encoded > (Config.TestDrive.maxPropertiesBytes or 32768) then return nil end
    return properties
end

local function getPhoneByIdentifierAwait(identifier)
    local result = promise.new()
    Bridge.GetPhoneByIdentifier(identifier, function(phone)
        result:resolve(phone or 'Unknown')
    end)
    return Citizen.Await(result)
end

local function reserveListing(plate, netId, sellerIdentifier)
    if pendingListingPlates[plate] or pendingListingNetIds[netId] then return false end
    pendingListingPlates[plate] = true
    pendingListingNetIds[netId] = true

    local inserted = MySQL.update.await([[
        INSERT IGNORE INTO car_sale_active_locks (plate, seller_identifier, vehicle_net_id)
        VALUES (?, ?, ?)
    ]], { plate, sellerIdentifier, netId })

    if inserted == 1 then return true end
    pendingListingPlates[plate] = nil
    pendingListingNetIds[netId] = nil
    return false
end

local function releaseListingReservation(plate, netId, keepDatabaseLock)
    pendingListingPlates[plate] = nil
    pendingListingNetIds[netId] = nil
    if not keepDatabaseLock then
        MySQL.update.await('DELETE FROM car_sale_active_locks WHERE plate = ?', { plate })
    end
end

RegisterNetEvent('car-sales:server:createListing', function(vehicleNetId, price)
    local src = source
    if rateLimited(src, 'createListing') then return end
    if not schemaReady then
        CarSale.Notify(
            src,
            Config.Notifications.title,
            schemaError and 'Vehicle sales are unavailable because database initialization failed.'
                or 'Vehicle sales are still starting. Try again shortly.',
            'error'
        )
        return
    end
    local netId = tonumber(vehicleNetId) or 0

    price = math.floor(tonumber(price) or 0)
    if price < Config.Listing.minPrice or price > Config.Listing.maxPrice then
        CarSale.Notify(src, Config.Notifications.title, 'Invalid asking price.', 'error')
        return
    end

    local sellerId = Bridge.GetIdentifier(src)
    if not sellerId then
        CarSale.Notify(src, Config.Notifications.title, 'Could not identify your character.', 'error')
        return
    end

    if Config.Inventory.consumeSign and not Bridge.HasItem(src, Config.Inventory.signItem, 1) then
        CarSale.Notify(src, Config.Notifications.title, 'You need a sale sign.', 'error')
        return
    end

    local vehicle = getNetEntity(netId)
    if not vehicle then
        CarSale.Notify(src, Config.Notifications.title, 'Vehicle is not present.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    if (GetVehiclePedIsIn and GetVehiclePedIsIn(ped, false) == vehicle)
        or (GetPedInVehicleSeat and GetPedInVehicleSeat(vehicle, -1) == ped) then
        CarSale.Notify(src, Config.Notifications.title, 'Exit the vehicle before listing it.', 'error')
        return
    end

    if CarSale.VectorDistance(GetEntityCoords(ped), GetEntityCoords(vehicle)) > Config.Listing.useDistance then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    local originalPlate = CarSale.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    if originalPlate == '' then
        CarSale.Notify(src, Config.Notifications.title, 'Could not read the real plate.', 'error')
        return
    end

    if listingsByPlate[originalPlate] or listingsByNetId[netId] then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is already listed.', 'error')
        return
    end

    if not reserveListing(originalPlate, netId, sellerId) then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is already being listed.', 'error')
        return
    end

    local signRemoved = false
    local function abortListing(message)
        if signRemoved then Bridge.AddItem(src, Config.Inventory.signItem, 1) end
        releaseListingReservation(originalPlate, netId, false)
        if Bridge.GetPlayer(src) then CarSale.Notify(src, Config.Notifications.title, message, 'error') end
    end

    local row = findVehicleByPlate(originalPlate)
    if not row then
        abortListing('This vehicle is not registered to a player.')
        return
    end
    if row[Config.Database.ownerColumn] ~= sellerId then
        abortListing('You do not own this vehicle.')
        return
    end

    local model = row[Config.Database.modelColumn] or tostring(GetEntityModel(vehicle))
    if CarSale.TableContains(Config.Listing.vehicleBlacklist, model) then
        abortListing('This vehicle cannot be listed.')
        return
    end
    if GetVehicleClass and CarSale.TableContains(Config.Listing.classBlacklist, GetVehicleClass(vehicle)) then
        abortListing('This vehicle class cannot be listed.')
        return
    end

    local sellerPhone = getPhoneByIdentifierAwait(sellerId)
    vehicle = getNetEntity(netId)
    ped = GetPlayerPed(src)
    if Bridge.GetIdentifier(src) ~= sellerId
        or not vehicle
        or not ped or ped == 0
        or CarSale.NormalizePlate(GetVehicleNumberPlateText(vehicle)) ~= originalPlate
        or CarSale.VectorDistance(GetEntityCoords(ped), GetEntityCoords(vehicle)) > Config.Listing.useDistance
        or listingsByPlate[originalPlate]
        or listingsByNetId[netId] then
        abortListing('Listing conditions changed. Please try again.')
        return
    end

    local props = readVehicleProps(row, originalPlate, model)
    local sellerName = Bridge.GetName(src)
    local sellerFirstName = Bridge.GetFirstName(src)
    local insertId = MySQL.insert.await([[
        INSERT INTO car_sale_history
        (seller_identifier, seller_name, plate, vehicle_model, price, status)
        VALUES (?, ?, ?, ?, ?, 'active')
    ]], { sellerId, sellerName, originalPlate, model, price })

    if not insertId then
        abortListing('Could not create listing.')
        return
    end

    if Config.Inventory.consumeSign then
        if not Bridge.RemoveItem(src, Config.Inventory.signItem, 1) then
            MySQL.prepare.await([[
                UPDATE car_sale_history
                SET status = 'cancelled', cancel_reason = 'sign_item_remove_failed', completed_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ]], { insertId })
            abortListing('Could not use the sale sign item.')
            return
        end
        signRemoved = true
    end

    local listing = {
        id = insertId,
        sellerSource = src,
        sellerIdentifier = sellerId,
        sellerName = sellerName,
        sellerFirstName = sellerFirstName,
        sellerPhone = sellerPhone,
        vehicleNetId = netId,
        originalPlate = originalPlate,
        model = model,
        modelHash = GetEntityModel(vehicle),
        props = props,
        price = price,
        signPlacement = getDefaultSignPlacement(),
        consumedSign = Config.Inventory.consumeSign,
        purchasing = false,
        stateRevision = 1,
        createdAt = os.time()
    }

    listings[listing.id] = listing
    listingsByPlate[originalPlate] = listing.id
    listingsByStoragePlate[normalizeStoragePlate(originalPlate)] = listing.id
    listingsByNetId[listing.vehicleNetId] = listing.id
    MySQL.update('UPDATE car_sale_active_locks SET listing_id = ? WHERE plate = ?', { listing.id, originalPlate })
    releaseListingReservation(originalPlate, netId, true)

    setVehicleState(listing, true)
    incrementMetric('listingsCreated')
    CarSale.Notify(src, Config.Notifications.title, ('Vehicle listed for %s.'):format(CarSale.FormatMoney(price)), 'success')
end)

lib.callback.register('car-sales:server:getSignPlacement', function(src, listingId)
    local listing = listings[tonumber(listingId)]
    if not listing or not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then return nil end
    if not refreshSellerSource(src, listing) then return nil end

    return listing.signPlacement or getDefaultSignPlacement()
end)

RegisterNetEvent('car-sales:server:updateSignPlacement', function(listingId, placement)
    local src = source
    if rateLimited(src, 'updateSignPlacement') then return end

    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer listed.', 'error')
        return
    end
    if not refreshSellerSource(src, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'Only the owner can adjust this sign.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    listing.signPlacement = sanitizeSignPlacement(placement)
    listing.stateRevision = (listing.stateRevision or 1) + 1

    local vehicle = getNetEntity(listing.vehicleNetId)
    if vehicle then
        publishListingData(listing, vehicle)
    end

    CarSale.Notify(src, Config.Notifications.title, 'Sale sign position updated.', 'success')
end)

lib.callback.register('car-sales:server:getSellerDetails', function(src, listingId)
    local listing = listings[tonumber(listingId)]
    if not listing or not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then return nil end
    if refreshSellerSource(src, listing) then return nil end

    local phone = listing.sellerPhone
    if not phone or phone == 'Unknown' then
        phone = getPhoneByIdentifierAwait(listing.sellerIdentifier)
        if phone and phone ~= 'Unknown' then
            listing.sellerPhone = phone
            listing.stateRevision = (listing.stateRevision or 1) + 1
            publishListingData(listing)
        end
    end

    return {
        sellerName = listing.sellerName,
        firstName = listing.sellerFirstName,
        phone = phone or 'Unknown',
        vehicle = CarSale.VehicleDisplayName(listing.model),
        model = listing.model,
        price = listing.price
    }
end)

RegisterNetEvent('car-sales:server:saveSellerContact', function(listingId)
    local src = source
    if rateLimited(src, 'saveSellerContact') then return end
    if not phoneContactsEnabled() then return end

    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer listed.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end
    if refreshSellerSource(src, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'You cannot save your own listing contact.', 'error')
        return
    end

    local phone = listing.sellerPhone
    if not phone or phone == 'Unknown' then
        phone = getPhoneByIdentifierAwait(listing.sellerIdentifier)
        if phone and phone ~= 'Unknown' then
            listing.sellerPhone = phone
            listing.stateRevision = (listing.stateRevision or 1) + 1
            publishListingData(listing)
        end
    end
    if not phone or phone == 'Unknown' then
        CarSale.Notify(src, Config.Notifications.title, 'Seller phone number is not available.', 'error')
        return
    end

    Bridge.SavePhoneContact(src, listing.sellerName, phone, function(success, message)
        CarSale.Notify(
            src,
            Config.Notifications.title,
            message or (success and 'Contact saved.' or 'Could not save contact.'),
            success and 'success' or 'error'
        )
    end)
end)

lib.callback.register('car-sales:server:getListing', function(src, listingId)
    local listing = listings[tonumber(listingId)]
    if not listing or not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then return nil end
    local seller = refreshSellerSource(src, listing)

    return {
        id = listing.id,
        seller = listing.sellerName,
        vehicle = CarSale.VehicleDisplayName(listing.model),
        model = listing.model,
        price = listing.price,
        isSeller = seller
    }
end)

RegisterNetEvent('car-sales:server:updateListingPrice', function(listingId, price)
    local src = source
    if rateLimited(src, 'updateListingPrice') then return end

    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer listed.', 'error')
        return
    end
    if not refreshSellerSource(src, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'Only the owner can edit this listing.', 'error')
        return
    end
    if listing.purchasing then
        CarSale.Notify(src, Config.Notifications.title, 'A transaction is already in progress.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    price = math.floor(tonumber(price) or 0)
    if price < Config.Listing.minPrice or price > Config.Listing.maxPrice then
        CarSale.Notify(src, Config.Notifications.title, 'Invalid asking price.', 'error')
        return
    end
    if price == listing.price then
        CarSale.Notify(src, Config.Notifications.title, 'Asking price unchanged.', 'inform')
        return
    end

    local updated = MySQL.prepare.await(
        'UPDATE car_sale_history SET price = ? WHERE id = ? AND status = ?',
        { price, listing.id, 'active' }
    )

    if not updated or updated < 1 then
        CarSale.Notify(src, Config.Notifications.title, 'Could not update listing price.', 'error')
        return
    end

    listing.price = price
    listing.stateRevision = (listing.stateRevision or 1) + 1

    for token, offer in pairs(pendingOffers) do
        if offer.listingId == listing.id then
            pendingOffers[token] = nil
        end
    end

    local vehicle = getNetEntity(listing.vehicleNetId)
    if vehicle then
        publishListingData(listing, vehicle)
    end

    CarSale.Notify(src, Config.Notifications.title, ('Listing price updated to %s.'):format(CarSale.FormatMoney(price)), 'success')
end)

RegisterNetEvent('car-sales:server:cancelListing', function(listingId)
    local src = source
    if rateLimited(src, 'cancelListing') then return end
    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer listed.', 'error')
        return
    end
    if not refreshSellerSource(src, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'Only the owner can remove this listing.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    cleanupListing(listing, 'seller_cancelled', false)
    CarSale.Notify(src, Config.Notifications.title, 'Sale listing removed.', 'success')
end)

RegisterNetEvent('car-sales:server:startTestDrive', function(listingId, jgMechanicProps)
    local src = source
    if rateLimited(src, 'testDrive') then return end

    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer available.', 'error')
        return
    end
    if Bridge.GetIdentifier(src) == listing.sellerIdentifier then
        CarSale.Notify(src, Config.Notifications.title, 'You cannot test drive your own listing.', 'error')
        return
    end
    if activeTestDrives[src] then
        CarSale.Notify(src, Config.Notifications.title, 'You are already in a test drive.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    local saleVehicle = getNetEntity(listing.vehicleNetId)
    if not saleVehicle then
        CarSale.Notify(src, Config.Notifications.title, 'Sale vehicle is not present.', 'error')
        return
    end

    local bucket = pickTestDriveBucket(src)
    if not bucket then
        CarSale.Notify(src, Config.Notifications.title, 'No test drive space is available right now.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local originalBucket = GetPlayerRoutingBucket(src)
    local saleCoords = GetEntityCoords(saleVehicle)
    local saleHeading = GetEntityHeading(saleVehicle)

    activeTestDrives[src] = {
        listingId = listing.id,
        originalBucket = originalBucket,
        testBucket = bucket,
        returnCoords = vec4(coords.x, coords.y, coords.z, GetEntityHeading(ped)),
        startedAt = os.time(),
        prepareExpiresAt = os.time() + 15,
        status = 'preparing',
        vehicleNetId = nil,
        startData = {
            listingId = listing.id,
            targetBucket = bucket,
            model = listing.model,
            modelHash = listing.modelHash,
            props = listing.props,
            jgMechanicProps = sanitizeTestDriveProperties(jgMechanicProps),
            saleCoords = vec4(saleCoords.x, saleCoords.y, saleCoords.z, saleHeading),
            durationSeconds = Config.TestDrive.durationSeconds
        }
    }

    TriggerClientEvent('car-sales:client:prepareTestDrive', src, listing.id)
end)

RegisterNetEvent('car-sales:server:readyForTestDrive', function(listingId)
    local src = source
    local drive = activeTestDrives[src]
    if not drive or drive.status ~= 'preparing' or drive.listingId ~= tonumber(listingId) then return end

    local listing = listings[drive.listingId]
    if not listing then
        failTestDriveStart(src, 'This vehicle is no longer available.')
        return
    end

    local saleVehicle = getNetEntity(listing.vehicleNetId)
    if not saleVehicle then
        failTestDriveStart(src, 'Sale vehicle is not present.')
        return
    end

    if not setPlayerBucket(src, drive.testBucket) then
        failTestDriveStart(src, 'Could not move you to the test drive.')
        return
    end

    drive.status = 'spawning'
    drive.prepareExpiresAt = nil
    TriggerClientEvent('car-sales:client:startTestDrive', src, drive.startData)
end)

RegisterNetEvent('car-sales:server:setTestDriveVehicle', function(netId)
    local src = source
    local drive = activeTestDrives[src]
    if not drive or (drive.status ~= 'spawning' and drive.status ~= 'active') then return end

    netId = tonumber(netId)
    local vehicle = getNetEntity(netId)
    local ped = GetPlayerPed(src)
    if not vehicle then return end
    if not isVehicleEntity(vehicle) then return end
    if NetworkGetEntityOwner and NetworkGetEntityOwner(vehicle) ~= src then return end
    if drive.startData.modelHash and GetEntityModel(vehicle) ~= tonumber(drive.startData.modelHash) then return end
    if GetEntityRoutingBucket(vehicle) ~= drive.testBucket then
        SetEntityRoutingBucket(vehicle, drive.testBucket)
        Wait(100)
    end
    if GetPlayerRoutingBucket(src) ~= drive.testBucket then return end
    if GetEntityRoutingBucket(vehicle) ~= drive.testBucket then return end
    if CarSale.VectorDistance(GetEntityCoords(ped), GetEntityCoords(vehicle)) > 80.0 then return end

    drive.vehicleNetId = netId
    drive.testPlate = CarSale.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    drive.status = 'active'
end)

local function isValidTestDriveVehicle(src, drive, netId)
    if not drive or tonumber(netId) ~= tonumber(drive.vehicleNetId) then return false end
    local vehicle = getNetEntity(netId)
    local ped = GetPlayerPed(src)
    if not vehicle then return false end
    if not isVehicleEntity(vehicle) then return false end
    if GetPlayerRoutingBucket(src) ~= drive.testBucket then return false end
    if GetEntityRoutingBucket(vehicle) ~= drive.testBucket then return false end
    if CarSale.VectorDistance(GetEntityCoords(ped), GetEntityCoords(vehicle)) > 80.0 then return false end
    return true, vehicle
end

RegisterNetEvent('car-sales:server:endTestDrive', function(reason)
    local src = source
    local drive = activeTestDrives[src]
    if not drive then
        TriggerClientEvent('car-sales:client:testDriveFailed', src, 'Test drive ended.')
        return
    end

    if drive.vehicleNetId then
        local vehicle = getNetEntity(drive.vehicleNetId)
        if vehicle then DeleteEntity(vehicle) end
    end

    drive.status = 'returning'
    drive.returnReason = reason or 'ended'
    drive.returnExpiresAt = os.time() + 15
    TriggerClientEvent('car-sales:client:returnFromTestDrive', src, drive.returnCoords, drive.returnReason)
end)

RegisterNetEvent('car-sales:server:finishTestDriveReturn', function()
    local src = source
    local drive = activeTestDrives[src]
    if not drive or drive.status ~= 'returning' then return end

    activeTestDrives[src] = nil

    local restoreBucket = drive.originalBucket
    if restoreBucket == nil then
        restoreBucket = 0
        CarSale.Debug(('Missing original test-drive bucket for player %s; falling back to bucket 0.'):format(src))
    end

    setPlayerBucket(src, restoreBucket)

    TriggerClientEvent('car-sales:client:finishTestDriveReturn', src, drive.returnReason or 'ended')
end)

RegisterNetEvent('car-sales:server:giveTestDriveKeys', function(netId)
    local src = source
    local drive = activeTestDrives[src]
    local valid, vehicle = isValidTestDriveVehicle(src, drive, netId)
    if valid and drive.testPlate and drive.testPlate ~= '' then
        Bridge.GiveKeys(src, vehicle, drive.testPlate)
    end
end)

local function makeOfferToken()
    return ('%d:%d:%d'):format(os.time(), math.random(100000, 999999), GetGameTimer())
end

local function getNearbyBuyers(sellerSrc, listing)
    local candidates = {}
    local sellerCoords = getPedCoords(sellerSrc)
    local vehicle = getNetEntity(listing.vehicleNetId)
    if not sellerCoords or not vehicle then return candidates end
    local vehicleCoords = GetEntityCoords(vehicle)

    for _, id in ipairs(GetPlayers()) do
        local targetSrc = tonumber(id)
        if targetSrc ~= sellerSrc then
            local identifier = Bridge.GetIdentifier(targetSrc)
            local coords = getPedCoords(targetSrc)
            if identifier and identifier ~= listing.sellerIdentifier and coords then
                if CarSale.VectorDistance(coords, vehicleCoords) <= Config.Listing.offerDistance
                    and CarSale.VectorDistance(coords, sellerCoords) <= Config.Listing.offerDistance + 2.0 then
                    candidates[#candidates + 1] = {
                        source = targetSrc,
                        name = Bridge.GetName(targetSrc)
                    }
                end
            end
        end
    end

    return candidates
end

RegisterNetEvent('car-sales:server:offerPurchase', function(listingId)
    local src = source
    if rateLimited(src, 'offerPurchase') then return end
    local listing = listings[tonumber(listingId)]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer listed.', 'error')
        return
    end
    if not refreshSellerSource(src, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'Only the owner can offer this vehicle for sale.', 'error')
        return
    end
    if listing.purchasing then
        CarSale.Notify(src, Config.Notifications.title, 'A transaction is already in progress.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.targetDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'You are too far from the vehicle.', 'error')
        return
    end

    local candidates = getNearbyBuyers(src, listing)
    if #candidates == 0 then
        CarSale.Notify(src, Config.Notifications.title, 'No nearby buyers found.', 'error')
    elseif #candidates == 1 then
        TriggerEvent('car-sales:server:sendOfferToBuyer', listing.id, candidates[1].source, src)
    else
        TriggerClientEvent('car-sales:client:chooseBuyer', src, listing.id, candidates)
    end
end)

RegisterNetEvent('car-sales:server:selectBuyer', function(listingId, buyerSrc)
    local src = source
    if rateLimited(src, 'selectBuyer') then return end
    TriggerEvent('car-sales:server:sendOfferToBuyer', tonumber(listingId), tonumber(buyerSrc), src)
end)

AddEventHandler('car-sales:server:sendOfferToBuyer', function(listingId, buyerSrc, sellerSrc)
    local listing = listings[tonumber(listingId)]
    if not listing or not buyerSrc or not sellerSrc then return end
    if not refreshSellerSource(sellerSrc, listing) then return end
    if Bridge.GetIdentifier(buyerSrc) == listing.sellerIdentifier then return end
    if not playerNearListing(sellerSrc, listing, Config.Listing.offerDistance + 2.0) then return end
    if not playerNearListing(buyerSrc, listing, Config.Listing.offerDistance + 2.0) then
        CarSale.Notify(sellerSrc, Config.Notifications.title, 'That buyer is too far from the vehicle.', 'error')
        return
    end

    local token = makeOfferToken()
    pendingOffers[token] = {
        listingId = listing.id,
        sellerSrc = sellerSrc,
        buyerSrc = buyerSrc,
        buyerIdentifier = Bridge.GetIdentifier(buyerSrc),
        buyerName = Bridge.GetName(buyerSrc),
        price = listing.price,
        expiresAt = os.time() + Config.Listing.offerExpirySeconds
    }

    TriggerClientEvent('car-sales:client:purchasePrompt', buyerSrc, token, {
        vehicle = CarSale.VehicleDisplayName(listing.model),
        seller = listing.sellerName,
        price = listing.price,
        negotiated = false,
        expires = Config.Listing.offerExpirySeconds
    })
    CarSale.Notify(sellerSrc, Config.Notifications.title, ('Purchase offer sent to %s.'):format(Bridge.GetName(buyerSrc)), 'success')
end)

RegisterNetEvent('car-sales:server:negotiateOffer', function(token, counterAmount)
    local src = source
    if rateLimited(src, 'negotiateOffer') then return end

    local offer = pendingOffers[token]
    if not offer or offer.buyerSrc ~= src then return end

    local listing = listings[offer.listingId]
    if not listing then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer available.', 'error')
        return
    end

    counterAmount = math.floor(tonumber(counterAmount) or 0)
    if counterAmount < Config.Listing.minPrice or counterAmount > Config.Listing.maxPrice then
        CarSale.Notify(src, Config.Notifications.title, 'Invalid counter offer amount.', 'error')
        return
    end
    if os.time() > offer.expiresAt then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'This purchase offer expired.', 'error')
        return
    end
    if Bridge.GetIdentifier(src) ~= offer.buyerIdentifier or offer.buyerIdentifier == listing.sellerIdentifier then
        return
    end
    if not Bridge.GetPlayer(offer.sellerSrc) then
        CarSale.Notify(src, Config.Notifications.title, 'Seller is no longer available.', 'error')
        return
    end
    if not sellerOwnsListing(offer.sellerSrc, listing) then
        CarSale.Notify(src, Config.Notifications.title, 'Seller no longer owns this vehicle.', 'error')
        return
    end
    if not playerNearListing(offer.sellerSrc, listing, Config.Listing.offerDistance + 2.0)
        or not playerNearListing(src, listing, Config.Listing.offerDistance + 2.0) then
        CarSale.Notify(src, Config.Notifications.title, 'Buyer and seller must both be near the vehicle.', 'error')
        return
    end

    offer.awaitingSellerCounter = true
    offer.counterPrice = counterAmount
    offer.expiresAt = os.time() + Config.Listing.offerExpirySeconds

    TriggerClientEvent('car-sales:client:negotiationPrompt', offer.sellerSrc, token, {
        vehicle = CarSale.VehicleDisplayName(listing.model),
        buyer = offer.buyerName,
        askingPrice = listing.price,
        counterPrice = counterAmount,
        expires = Config.Listing.offerExpirySeconds
    })

    CarSale.Notify(src, Config.Notifications.title, ('Counter offer sent for %s.'):format(CarSale.FormatMoney(counterAmount)), 'success')
end)

RegisterNetEvent('car-sales:server:respondNegotiation', function(token, accepted)
    local src = source
    if rateLimited(src, 'respondNegotiation') then return end

    local offer = pendingOffers[token]
    if not offer or offer.sellerSrc ~= src or not offer.awaitingSellerCounter then return end

    local listing = listings[offer.listingId]
    if not listing then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer available.', 'error')
        return
    end

    if os.time() > offer.expiresAt then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'The counter offer expired.', 'error')
        if Bridge.GetPlayer(offer.buyerSrc) then
            CarSale.Notify(offer.buyerSrc, Config.Notifications.title, 'Your counter offer expired.', 'error')
        end
        return
    end

    if not refreshSellerSource(src, listing) then return end

    if not accepted then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'Counter offer declined.', 'inform')
        if Bridge.GetPlayer(offer.buyerSrc) then
            CarSale.Notify(offer.buyerSrc, Config.Notifications.title, 'Seller declined your counter offer.', 'inform')
        end
        return
    end

    if not Bridge.GetPlayer(offer.buyerSrc) then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'Buyer is no longer available.', 'error')
        return
    end
    if not playerNearListing(src, listing, Config.Listing.offerDistance + 2.0)
        or not playerNearListing(offer.buyerSrc, listing, Config.Listing.offerDistance + 2.0) then
        pendingOffers[token] = nil
        CarSale.Notify(src, Config.Notifications.title, 'Buyer and seller must both be near the vehicle.', 'error')
        CarSale.Notify(offer.buyerSrc, Config.Notifications.title, 'Buyer and seller must both be near the vehicle.', 'error')
        return
    end

    offer.price = offer.counterPrice
    offer.negotiated = true
    offer.awaitingSellerCounter = false
    offer.counterPrice = nil
    offer.expiresAt = os.time() + Config.Listing.offerExpirySeconds

    TriggerClientEvent('car-sales:client:purchasePrompt', offer.buyerSrc, token, {
        vehicle = CarSale.VehicleDisplayName(listing.model),
        seller = listing.sellerName,
        price = offer.price,
        negotiated = true,
        expires = Config.Listing.offerExpirySeconds
    })

    CarSale.Notify(src, Config.Notifications.title, ('Counter accepted. Final confirmation sent to %s.'):format(offer.buyerName), 'success')
end)

local function updateVehicleOwner(plate, fromIdentifier, toIdentifier, toSrc)
    local db = Config.Database
    local setClauses = { ('%s = ?'):format(quoteIdentifier(db.ownerColumn)) }
    local values = { toIdentifier }

    if type(db.extraOwnerColumns) == 'table' then
        for column, sourceField in pairs(db.extraOwnerColumns) do
            local value
            if sourceField == 'license' then
                value = Bridge.GetLicense(toSrc)
            elseif sourceField == 'citizenid' then
                value = toIdentifier
            end

            if value then
                setClauses[#setClauses + 1] = ('%s = ?'):format(quoteIdentifier(column))
                values[#values + 1] = value
            end
        end
    end

    values[#values + 1] = plate
    values[#values + 1] = fromIdentifier

    local query = ('UPDATE %s SET %s WHERE %s = ? AND %s = ?'):format(
        quoteIdentifier(db.vehicleTable),
        table.concat(setClauses, ', '),
        quoteIdentifier(db.plateColumn),
        quoteIdentifier(db.ownerColumn)
    )

    return MySQL.update.await(query, values) == 1
end

local function beginSaleTransaction(token, listing, buyerIdentifier, amount)
    local inserted = MySQL.update.await([[
        INSERT IGNORE INTO car_sale_transactions
            (token, listing_id, plate, seller_identifier, buyer_identifier, amount, status)
        VALUES (?, ?, ?, ?, ?, ?, 'validated')
    ]], {
        tostring(token), listing.id, listing.originalPlate, listing.sellerIdentifier,
        buyerIdentifier, amount
    })

    if inserted == 1 then
        activeTransactions[tostring(token)] = true
        incrementMetric('transactionsStarted')
        return true
    end
    return false
end

local function setTransactionStatus(token, status, lastError)
    local updated = MySQL.update.await([[
        UPDATE car_sale_transactions
        SET status = ?, last_error = ?
        WHERE token = ?
    ]], { status, lastError, tostring(token) })

    if status == 'completed' then incrementMetric('transactionsCompleted') end
    if status == 'completed' or status == 'failed' or status == 'refunded'
        or status == 'rolled_back' or status == 'manual_review' then
        activeTransactions[tostring(token)] = nil
    end
    if status == 'manual_review' then
        incrementMetric('transactionsRequiringReview')
        print(('[car-sales] transaction %s requires manual review: %s'):format(token, lastError or 'unknown error'))
    end
    return updated == 1
end

RegisterNetEvent('car-sales:server:respondOffer', function(token, accepted)
    local src = source
    if rateLimited(src, 'respondOffer') then return end
    local offer = pendingOffers[token]
    if not offer or offer.buyerSrc ~= src then return end
    pendingOffers[token] = nil

    local listing = listings[offer.listingId]
    if not listing then
        CarSale.Notify(src, Config.Notifications.title, 'This vehicle is no longer available.', 'error')
        return
    end

    if not accepted then
        CarSale.Notify(src, Config.Notifications.title, 'Purchase offer declined.', 'inform')
        if Bridge.GetPlayer(offer.sellerSrc) then
            CarSale.Notify(
                offer.sellerSrc,
                Config.Notifications.title,
                ('%s declined the purchase offer.'):format(offer.buyerName),
                'inform'
            )
        end
        return
    end
    if offer.awaitingSellerCounter then
        CarSale.Notify(src, Config.Notifications.title, 'Waiting for the seller to respond to your counter offer.', 'inform')
        pendingOffers[token] = offer
        return
    end

    if os.time() > offer.expiresAt then
        CarSale.Notify(src, Config.Notifications.title, 'This purchase offer expired.', 'error')
        return
    end

    if listing.purchasing then
        CarSale.Notify(src, Config.Notifications.title, 'Another transaction is already in progress.', 'error')
        return
    end
    listing.purchasing = true

    local sellerOnline = Bridge.GetPlayer(offer.sellerSrc)
    local buyerIdentifier = Bridge.GetIdentifier(src)
    local fail = function(message)
        listing.purchasing = false
        CarSale.Notify(src, Config.Notifications.title, message, 'error')
        if sellerOnline then CarSale.Notify(offer.sellerSrc, Config.Notifications.title, message, 'error') end
    end

    if not sellerOnline or not sellerOwnsListing(offer.sellerSrc, listing) then
        fail('Seller is no longer available.')
        return
    end
    if buyerIdentifier ~= offer.buyerIdentifier or buyerIdentifier == listing.sellerIdentifier then
        fail('Invalid buyer.')
        return
    end
    local salePrice = math.floor(tonumber(offer.price) or 0)
    if salePrice < Config.Listing.minPrice or salePrice > Config.Listing.maxPrice then
        fail('Invalid sale price.')
        return
    end
    if not offer.negotiated and salePrice ~= listing.price then
        fail('Listing price changed before purchase.')
        return
    end
    if not playerNearListing(offer.sellerSrc, listing, Config.Listing.offerDistance + 2.0)
        or not playerNearListing(src, listing, Config.Listing.offerDistance + 2.0) then
        fail('Buyer and seller must both be near the vehicle.')
        return
    end

    local row = MySQL.single.await(
        ('SELECT %s FROM %s WHERE %s = ? LIMIT 1'):format(
            quoteIdentifier(Config.Database.ownerColumn),
            quoteIdentifier(Config.Database.vehicleTable),
            quoteIdentifier(Config.Database.plateColumn)
        ),
        { listing.originalPlate }
    )
    if not row or row[Config.Database.ownerColumn] ~= listing.sellerIdentifier then
        fail('Seller no longer owns this vehicle.')
        return
    end

    if Bridge.GetBank(src) < salePrice then
        fail('Buyer has insufficient bank funds.')
        return
    end

    if not beginSaleTransaction(token, listing, buyerIdentifier, salePrice) then
        fail('This purchase has already been processed or could not be journaled.')
        return
    end
    if not setTransactionStatus(token, 'debit_pending') then
        activeTransactions[tostring(token)] = nil
        fail('Could not prepare the payment transaction.')
        return
    end

    if not Bridge.RemoveBank(src, salePrice, ('Vehicle purchase %s'):format(listing.originalPlate)) then
        setTransactionStatus(token, 'failed', 'buyer debit failed')
        fail('Payment failed.')
        return
    end
    setTransactionStatus(token, 'buyer_debited')

    setTransactionStatus(token, 'owner_transfer_pending')
    if not updateVehicleOwner(listing.originalPlate, listing.sellerIdentifier, buyerIdentifier, src) then
        local refunded = Bridge.AddBank(src, salePrice, 'Vehicle purchase refund')
        setTransactionStatus(
            token,
            refunded and 'refunded' or 'manual_review',
            refunded and 'ownership transfer failed' or 'ownership transfer and refund failed'
        )
        fail(refunded and 'Ownership transfer failed. Buyer refunded.' or 'Ownership transfer failed and requires staff review.')
        return
    end
    setTransactionStatus(token, 'owner_transferred')

    setTransactionStatus(token, 'seller_credit_pending')
    if not Bridge.AddBank(offer.sellerSrc, salePrice, ('Vehicle sale %s'):format(listing.originalPlate)) then
        local ownershipRestored = updateVehicleOwner(
            listing.originalPlate,
            buyerIdentifier,
            listing.sellerIdentifier,
            offer.sellerSrc
        )
        local refunded = ownershipRestored and Bridge.AddBank(src, salePrice, 'Vehicle purchase refund') or false
        local rolledBack = ownershipRestored and refunded
        setTransactionStatus(
            token,
            rolledBack and 'rolled_back' or 'manual_review',
            rolledBack and 'seller payout failed' or 'seller payout compensation incomplete'
        )
        fail(rolledBack and 'Seller payout failed. Buyer refunded.' or 'Seller payout failed and requires staff review.')
        return
    end
    setTransactionStatus(token, 'seller_credited')

    listing.buyerIdentifier = buyerIdentifier
    listing.buyerName = offer.buyerName
    listing.salePrice = salePrice
    cleanupListing(listing, nil, true, src)
    setTransactionStatus(token, 'completed')

    local vehicle = getNetEntity(listing.vehicleNetId)
    if vehicle then
        callNative(SetVehicleNumberPlateText, vehicle, listing.originalPlate)
        callNative(FreezeEntityPosition, vehicle, false)
        callNative(SetVehicleDoorsLocked, vehicle, 1)

        Bridge.RemoveKeys(offer.sellerSrc, vehicle, listing.originalPlate)
        Bridge.GiveKeys(src, vehicle, listing.originalPlate)
        TriggerClientEvent('car-sales:client:enablePurchasedVehicle', src, listing.vehicleNetId, listing.originalPlate)
    end

    CarSale.Notify(src, Config.Notifications.title, ('Vehicle purchased for %s.'):format(CarSale.FormatMoney(salePrice)), 'success')
    CarSale.Notify(
        offer.sellerSrc,
        Config.Notifications.title,
        ('Vehicle sold to %s for %s.'):format(offer.buyerName, CarSale.FormatMoney(salePrice)),
        'success'
    )
end)

AddEventHandler('playerDropped', function()
    local src = source
    rateLimits[src] = nil

    if activeTestDrives[src] then
        local drive = activeTestDrives[src]
        activeTestDrives[src] = nil
        if drive.vehicleNetId then
            local vehicle = getNetEntity(drive.vehicleNetId)
            if vehicle then DeleteEntity(vehicle) end
        end
    end

    for _, listing in pairs(listings) do
        if listing.sellerSource == src then
            setListingSellerSource(listing, nil)
        end
    end

    for token, offer in pairs(pendingOffers) do
        if offer.sellerSrc == src or offer.buyerSrc == src then
            pendingOffers[token] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == Config.Inventory.resource then
        CreateThread(function()
            Wait(500)
            registerListedVehicleStorageHook()
        end)
    end
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    refreshListingRoles()
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if type(src) ~= 'number' then src = source end

    for _, listing in pairs(listings) do
        if listing.sellerSource == src then
            setListingSellerSource(listing, nil)
        end
    end
end)

CreateThread(function()
    Wait(1000)
    registerListedVehicleStorageHook()
end)

CreateThread(function()
    local nextMetrics = os.time() + math.max(1, math.floor((Config.Optimization.metricsIntervalMs or 60000) / 1000))
    while true do
        Wait(Config.Optimization.serverMaintenanceMs or 30000)
        local now = os.time()
        refreshListingRoles()
        for token, offer in pairs(pendingOffers) do
            if now > offer.expiresAt then pendingOffers[token] = nil end
        end
        for _, listing in pairs(listings) do
            if not keepListedVehicleAlive(listing) then
                cleanupListing(listing, 'vehicle_missing', false)
            end
        end
        for src, drive in pairs(activeTestDrives) do
            if drive.status == 'preparing' and drive.prepareExpiresAt and now > drive.prepareExpiresAt then
                activeTestDrives[src] = nil
                TriggerClientEvent('car-sales:client:testDriveFailed', src, 'Test drive start timed out.')
            elseif drive.status == 'returning' and drive.returnExpiresAt and now > drive.returnExpiresAt then
                activeTestDrives[src] = nil
                setPlayerBucket(src, drive.originalBucket or 0)
                TriggerClientEvent('car-sales:client:finishTestDriveReturn', src, drive.returnReason or 'ended')
            end
        end

        if next(activeTransactions) then
            local cutoff = now - (Config.Optimization.transactionStaleSeconds or 120)
            local stale = MySQL.update.await([[
                UPDATE car_sale_transactions
                SET status = 'manual_review', last_error = 'transaction exceeded the processing timeout'
                WHERE status NOT IN ('completed', 'failed', 'refunded', 'rolled_back', 'manual_review')
                  AND updated_at < FROM_UNIXTIME(?)
            ]], { cutoff }) or 0
            if stale > 0 then incrementMetric('transactionsRequiringReview', stale) end
        end

        if now >= nextMetrics then
            if Config.Optimization.metrics then
                serverMetrics.activeListings = countEntries(listings)
                serverMetrics.pendingOffers = countEntries(pendingOffers)
                serverMetrics.activeTestDrives = countEntries(activeTestDrives)
                serverMetrics.activeTransactions = countEntries(activeTransactions)
                print(('[car-sales] server metrics %s'):format(json.encode(serverMetrics)))
            end
            nextMetrics = now + math.max(1, math.floor((Config.Optimization.metricsIntervalMs or 60000) / 1000))
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if vehicleStorageHookId and Config.Inventory.resource and GetResourceState(Config.Inventory.resource) == 'started' then
        pcall(function()
            exports[Config.Inventory.resource]:removeHooks(vehicleStorageHookId)
        end)
    end

    for _, listing in pairs(listings) do
        cleanupListing(listing, 'resource_stop', false, nil, true)
    end
    for src, drive in pairs(activeTestDrives) do
        if drive.vehicleNetId then
            local vehicle = getNetEntity(drive.vehicleNetId)
            if vehicle then DeleteEntity(vehicle) end
        end
        SetPlayerRoutingBucket(src, drive.originalBucket or 0)
    end
end)

function IsVehicleForSale(identifier)
    if type(identifier) == 'number' then
        return listingsByNetId[identifier] ~= nil
    end
    return listingsByPlate[CarSale.NormalizePlate(identifier)] ~= nil
        or listingsByStoragePlate[normalizeStoragePlate(identifier)] ~= nil
end

function GetListingByPlate(plate)
    return listings[listingsByPlate[CarSale.NormalizePlate(plate)]]
end

function GetListingByNetId(netId)
    return listings[listingsByNetId[tonumber(netId)]]
end

exports('IsVehicleForSale', IsVehicleForSale)
exports('GetListingByPlate', GetListingByPlate)
exports('GetListingByNetId', GetListingByNetId)
