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
