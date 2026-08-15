CarSale = CarSale or {}

function CarSale.GetVehicleProperties(vehicle)
    if lib and lib.getVehicleProperties then
        local ok, props = pcall(lib.getVehicleProperties, vehicle)
        if ok and props then return props end
    end

    if not DoesEntityExist(vehicle) then return nil end

    local props = {
        model = GetEntityModel(vehicle),
        plate = CarSale.NormalizePlate(GetVehicleNumberPlateText(vehicle)),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) + 0.5),
        engineHealth = math.floor(GetVehicleEngineHealth(vehicle) + 0.5),
        tankHealth = math.floor(GetVehiclePetrolTankHealth(vehicle) + 0.5),
        fuelLevel = math.floor(GetVehicleFuelLevel(vehicle) + 0.5),
        dirtLevel = math.floor(GetVehicleDirtLevel(vehicle) + 0.5),
        oilLevel = math.floor(GetVehicleOilLevel(vehicle) + 0.5),
        mods = {},
        extras = {},
        neonEnabled = {},
        doors = {},
        windows = {},
        tyres = {}
    }

    local color1, color2 = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    props.color1 = color1
    props.color2 = color2
    props.pearlescentColor = pearlescentColor
    props.wheelColor = wheelColor
    props.wheels = GetVehicleWheelType(vehicle)
    if GetVehicleWheelSize then props.wheelSize = GetVehicleWheelSize(vehicle) end
    if GetVehicleWheelWidth then props.wheelWidth = GetVehicleWheelWidth(vehicle) end
    props.windowTint = GetVehicleWindowTint(vehicle)

    if GetIsVehiclePrimaryColourCustom(vehicle) then
        props.customPrimaryColor = { GetVehicleCustomPrimaryColour(vehicle) }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        props.customSecondaryColor = { GetVehicleCustomSecondaryColour(vehicle) }
    end

    SetVehicleModKit(vehicle, 0)
    for modType = 0, 49 do
        props.mods[tostring(modType)] = GetVehicleMod(vehicle, modType)
    end

    props.customTires = GetVehicleModVariation(vehicle, 23)
    props.turbo = IsToggleModOn(vehicle, 18)
    props.xenonHeadlights = IsToggleModOn(vehicle, 22)
    props.smokeEnabled = IsToggleModOn(vehicle, 20)
    props.xenonColor = GetVehicleXenonLightsColour(vehicle)
    props.livery = GetVehicleLivery(vehicle)
    props.livery2 = GetVehicleRoofLivery(vehicle)

    for i = 0, 3 do
        props.neonEnabled[tostring(i)] = IsVehicleNeonLightEnabled(vehicle, i)
    end
    props.neonColor = { GetVehicleNeonLightsColour(vehicle) }
    props.tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) }

    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            props.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end
    for i = 0, 5 do props.doors[tostring(i)] = IsVehicleDoorDamaged(vehicle, i) end
    for i = 0, 7 do
        props.windows[tostring(i)] = IsVehicleWindowIntact(vehicle, i)
        props.tyres[tostring(i)] = IsVehicleTyreBurst(vehicle, i, false)
    end

    return props
end

function CarSale.SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end

    if lib and lib.setVehicleProperties then
        local ok, result = pcall(lib.setVehicleProperties, vehicle, props)
        if ok and result ~= false then return true end
    end

    SetVehicleModKit(vehicle, 0)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end

    if props.color1 and props.color2 then SetVehicleColours(vehicle, props.color1, props.color2) end
    if props.pearlescentColor and props.wheelColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor) end
    if type(props.customPrimaryColor) == 'table' then
        SetVehicleCustomPrimaryColour(
            vehicle,
            props.customPrimaryColor[1],
            props.customPrimaryColor[2],
            props.customPrimaryColor[3]
        )
    end
    if type(props.customSecondaryColor) == 'table' then
        SetVehicleCustomSecondaryColour(
            vehicle,
            props.customSecondaryColor[1],
            props.customSecondaryColor[2],
            props.customSecondaryColor[3]
        )
    end

    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
        Wait(50)
    end
    if props.wheelSize and SetVehicleWheelSize then SetVehicleWheelSize(vehicle, props.wheelSize + 0.0) end
    if props.wheelWidth and SetVehicleWheelWidth then SetVehicleWheelWidth(vehicle, props.wheelWidth + 0.0) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    if type(props.mods) == 'table' then
        for modType, value in pairs(props.mods) do
            local mod = tonumber(modType)
            value = tonumber(value)
            if mod and value and value > -1 then
                SetVehicleMod(vehicle, mod, value, mod == 23 and props.customTires or false)
            end
        end
    end

    if props.livery and props.livery > -1 then SetVehicleLivery(vehicle, props.livery) end
    if props.livery2 and props.livery2 > -1 then SetVehicleRoofLivery(vehicle, props.livery2) end
    if props.turbo ~= nil then ToggleVehicleMod(vehicle, 18, props.turbo) end
    if props.xenonHeadlights ~= nil then ToggleVehicleMod(vehicle, 22, props.xenonHeadlights) end
    if props.xenonColor then SetVehicleXenonLightsColour(vehicle, props.xenonColor) end
    if props.smokeEnabled ~= nil then ToggleVehicleMod(vehicle, 20, props.smokeEnabled) end

    if type(props.extras) == 'table' then
        for extraId, enabled in pairs(props.extras) do
            local extra = tonumber(extraId)
            if extra and DoesExtraExist(vehicle, extra) then
                SetVehicleExtra(vehicle, extra, enabled and 0 or 1)
            end
        end
    end

    if type(props.neonEnabled) == 'table' then
        for i = 0, 3 do
            local enabled = props.neonEnabled[i] or props.neonEnabled[tostring(i)]
            if enabled ~= nil then SetVehicleNeonLightEnabled(vehicle, i, enabled) end
        end
    end
    if type(props.neonColor) == 'table' then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end
    if type(props.tyreSmokeColor) == 'table' then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if type(props.doors) == 'table' then
        for doorId, damaged in pairs(props.doors) do
            if damaged then SetVehicleDoorBroken(vehicle, tonumber(doorId), true) end
        end
    end
    if type(props.windows) == 'table' then
        for windowId, intact in pairs(props.windows) do
            if intact == false then SmashVehicleWindow(vehicle, tonumber(windowId)) end
        end
    end
    if type(props.tyres) == 'table' then
        for tyreId, burst in pairs(props.tyres) do
            if burst then SetVehicleTyreBurst(vehicle, tonumber(tyreId), true, 1000.0) end
        end
    end

    return true
end
