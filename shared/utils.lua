CarSale = CarSale or {}

local containsCache = setmetatable({}, { __mode = 'k' })

function CarSale.Debug(message)
    if Config and Config.Debug then
        print(('[car-sales] %s'):format(tostring(message)))
    end
end

function CarSale.Trim(value)
    if value == nil then return '' end
    return tostring(value):match('^%s*(.-)%s*$') or ''
end

function CarSale.NormalizePlate(plate)
    return CarSale.Trim(plate):upper()
end

function CarSale.FormatMoney(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.floor(amount)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return ('$%s'):format(formatted)
end

function CarSale.TableContains(list, value)
    if type(list) ~= 'table' then return false end

    local lookup = containsCache[list]
    if not lookup then
        lookup = {}
        for _, entry in ipairs(list) do
            lookup[tostring(entry):lower()] = true
        end
        containsCache[list] = lookup
    end

    return lookup[tostring(value):lower()] == true
end

function CarSale.TableContainsVehicleModel(list, model)
    if type(list) ~= 'table' or model == nil then return false end

    local modelText = tostring(model):lower()
    local modelHash = tonumber(model)
    if not modelHash and joaat and type(model) == 'string' then
        modelHash = joaat(model)
    end

    for _, entry in ipairs(list) do
        if tostring(entry):lower() == modelText then return true end

        local entryHash = tonumber(entry)
        if not entryHash and joaat and type(entry) == 'string' then
            entryHash = joaat(entry)
        end

        if modelHash and entryHash and tonumber(entryHash) == tonumber(modelHash) then
            return true
        end
    end

    return false
end

CarSale.VehicleClassNames = {
    [0] = 'Compacts',
    [1] = 'Sedans',
    [2] = 'SUVs',
    [3] = 'Coupes',
    [4] = 'Muscle',
    [5] = 'Sports Classics',
    [6] = 'Sports',
    [7] = 'Super',
    [8] = 'Motorcycles',
    [9] = 'Off-road',
    [10] = 'Industrial',
    [11] = 'Utility',
    [12] = 'Vans',
    [13] = 'Cycles',
    [14] = 'Boats',
    [15] = 'Helicopters',
    [16] = 'Planes',
    [17] = 'Service',
    [18] = 'Emergency',
    [19] = 'Military',
    [20] = 'Commercial',
    [21] = 'Trains',
    [22] = 'Open Wheel'
}

local vehicleClassAliases = {
    compacts = 0,
    compact = 0,
    sedans = 1,
    sedan = 1,
    suvs = 2,
    suv = 2,
    coupes = 3,
    coupe = 3,
    muscle = 4,
    sportsclassics = 5,
    sportsclassic = 5,
    classics = 5,
    sports = 6,
    sport = 6,
    super = 7,
    motorcycles = 8,
    motorcycle = 8,
    bikes = 8,
    bike = 8,
    offroad = 9,
    industrial = 10,
    utility = 11,
    vans = 12,
    van = 12,
    cycles = 13,
    cycle = 13,
    bicycles = 13,
    bicycle = 13,
    boats = 14,
    boat = 14,
    helicopters = 15,
    helicopter = 15,
    helis = 15,
    heli = 15,
    planes = 16,
    plane = 16,
    service = 17,
    emergency = 18,
    military = 19,
    commercial = 20,
    trains = 21,
    train = 21,
    openwheel = 22
}

local function normalizeVehicleClassKey(value)
    return tostring(value or ''):lower():gsub('[%s%-%_]+', '')
end

function CarSale.NormalizeVehicleClass(value)
    local class = tonumber(value)
    if class then
        class = math.floor(class)
        if CarSale.VehicleClassNames[class] then return class end
    end

    return vehicleClassAliases[normalizeVehicleClassKey(value)]
end

function CarSale.GetVehicleClassName(class)
    class = CarSale.NormalizeVehicleClass(class)
    return class and CarSale.VehicleClassNames[class] or nil
end

function CarSale.TableContainsVehicleClass(list, class)
    if type(list) ~= 'table' then return false end

    class = CarSale.NormalizeVehicleClass(class)
    if class == nil then return false end

    for _, entry in ipairs(list) do
        if CarSale.NormalizeVehicleClass(entry) == class then return true end
    end

    return false
end

function CarSale.GetVehicleClassConfig(configs, class)
    if type(configs) ~= 'table' then return nil end

    class = CarSale.NormalizeVehicleClass(class)
    if class == nil then return nil end

    local direct = configs[class]
    if direct ~= nil then return direct end

    local name = CarSale.VehicleClassNames[class]
    if name then
        direct = configs[name] or configs[name:lower()] or configs[normalizeVehicleClassKey(name)]
        if direct ~= nil then return direct end
    end

    for key, value in pairs(configs) do
        if CarSale.NormalizeVehicleClass(key) == class then return value end
    end

    return nil
end

function CarSale.DecodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end

    local ok, decoded = pcall(json.decode, value)
    if ok and decoded then return decoded end
    return fallback
end

function CarSale.Notify(src, title, description, notifyType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or Config.Notifications.title,
        description = description,
        type = notifyType or 'inform'
    })
end

function CarSale.VehicleDisplayName(model)
    if not model or model == '' then return 'Unknown Vehicle' end
    if GetDisplayNameFromVehicleModel and GetLabelText then
        local hash = type(model) == 'number' and model or joaat(model)
        local display = GetDisplayNameFromVehicleModel(hash)
        if display and display ~= '' and display ~= 'CARNOTFOUND' then
            local label = GetLabelText(display)
            if label and label ~= 'NULL' then
                return label
            end
        end
    end
    return tostring(model):gsub('^%l', string.upper)
end

function CarSale.VectorDistance(a, b)
    if not a or not b then return 999999.0 end
    return #(a - b)
end
