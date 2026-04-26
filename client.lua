local savedOutfit = nil
local savedPosition = nil
local operationState = "INACTIVE" -- INACTIVE | ALERTING | ACTIVE
local savedWeapons = {}
local isAtHomeland = false
local isLeader = false

local activeBlips = {}
local pingBlip = nil

local weatherOverrideActive = false
local homelandVehicleNetIds = {}
local handlingThreadActive = false

local streamerMode = false

local empState = { active = false, leaders = {}, homelandNetIds = {} }
local empAffectedVehicles = {}
local empLocalBlackout = false
local empPtfxLoaded = false

-----------------------------------------------------------------------
-- Outfit System
-----------------------------------------------------------------------
local function SaveOutfit()
    local ped = PlayerPedId()
    savedOutfit = {
        tshirt_1 = GetPedDrawableVariation(ped, 8), tshirt_2 = GetPedTextureVariation(ped, 8),
        torso_1 = GetPedDrawableVariation(ped, 11), torso_2 = GetPedTextureVariation(ped, 11),
        decals_1 = GetPedDrawableVariation(ped, 10), decals_2 = GetPedTextureVariation(ped, 10),
        arms = GetPedDrawableVariation(ped, 3),
        pants_1 = GetPedDrawableVariation(ped, 4), pants_2 = GetPedTextureVariation(ped, 4),
        shoes_1 = GetPedDrawableVariation(ped, 6), shoes_2 = GetPedTextureVariation(ped, 6),
        helmet_1 = GetPedPropIndex(ped, 0), helmet_2 = GetPedPropTextureIndex(ped, 0),
        chain_1 = GetPedDrawableVariation(ped, 7), chain_2 = GetPedTextureVariation(ped, 7),
        ears_1 = GetPedPropIndex(ped, 2), ears_2 = GetPedPropTextureIndex(ped, 2),
        glasses_1 = GetPedPropIndex(ped, 1), glasses_2 = GetPedPropTextureIndex(ped, 1),
        bproof_1 = GetPedDrawableVariation(ped, 9), bproof_2 = GetPedTextureVariation(ped, 9),
        mask_1 = GetPedDrawableVariation(ped, 1), mask_2 = GetPedTextureVariation(ped, 1),
        bags_1 = GetPedDrawableVariation(ped, 5), bags_2 = GetPedTextureVariation(ped, 5)
    }
end

local function ApplyOutfit(outfit)
    local ped = PlayerPedId()

    SetPedComponentVariation(ped, 8, outfit.tshirt_1, outfit.tshirt_2, 0)
    SetPedComponentVariation(ped, 11, outfit.torso_1, outfit.torso_2, 0)
    SetPedComponentVariation(ped, 10, outfit.decals_1, outfit.decals_2, 0)
    SetPedComponentVariation(ped, 3, outfit.arms, 0, 0)
    SetPedComponentVariation(ped, 4, outfit.pants_1, outfit.pants_2, 0)
    SetPedComponentVariation(ped, 6, outfit.shoes_1, outfit.shoes_2, 0)
    SetPedComponentVariation(ped, 7, outfit.chain_1, outfit.chain_2, 0)
    SetPedComponentVariation(ped, 9, outfit.bproof_1, outfit.bproof_2, 0)
    SetPedComponentVariation(ped, 1, outfit.mask_1, outfit.mask_2, 0)
    SetPedComponentVariation(ped, 5, outfit.bags_1, outfit.bags_2, 0)

    if outfit.helmet_1 == -1 then
        ClearPedProp(ped, 0)
    else
        SetPedPropIndex(ped, 0, outfit.helmet_1, outfit.helmet_2, true)
    end

    if outfit.ears_1 == -1 then
        ClearPedProp(ped, 2)
    else
        SetPedPropIndex(ped, 2, outfit.ears_1, outfit.ears_2, true)
    end

    if outfit.glasses_1 == -1 then
        ClearPedProp(ped, 1)
    else
        SetPedPropIndex(ped, 1, outfit.glasses_1, outfit.glasses_2, true)
    end
end

-----------------------------------------------------------------------
-- Weapons System
-----------------------------------------------------------------------
local function SaveWeapons()
    savedWeapons = {}
    ESX.TriggerServerCallback('homeland:getLoadout', function(loadout)
        savedWeapons = loadout
    end)
end

local function RemoveAllWeapons()
    TriggerServerEvent('homeland:removeAllWeapons')
end

local function GiveHomelandWeapons()
    TriggerServerEvent('homeland:giveWeapons')
end

local function RestoreWeapons()
    if not savedWeapons or #savedWeapons == 0 then return end
    TriggerServerEvent('homeland:restoreWeapons', savedWeapons)
    savedWeapons = {}
end

local function RemoveHomelandWeapons()
    TriggerServerEvent('homeland:removeHomelandWeapons')
end

-----------------------------------------------------------------------
-- Teleport
-----------------------------------------------------------------------
RegisterNetEvent('homeland:teleportTo', function()
    if isAtHomeland then return end

    local ped = PlayerPedId()

    savedPosition = GetEntityCoords(ped)
    SaveOutfit()

    Citizen.Wait(100)
    SaveWeapons()

    Citizen.Wait(100)
    RemoveAllWeapons()

    Citizen.Wait(200)

    SetEntityCoords(ped, Config.TeleportLocation.x, Config.TeleportLocation.y, Config.TeleportLocation.z)
    SetEntityHeading(ped, Config.TeleportLocation.heading)

    local gender = 'male'
    if GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') then
        gender = 'female'
    end

    ApplyOutfit(Config.HomelandOutfit[gender])

    Citizen.Wait(200)
    GiveHomelandWeapons()

    isAtHomeland = true

    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = true
    })
end)

RegisterNetEvent('homeland:teleportBack', function()
    if not savedPosition or not isAtHomeland then return end

    local ped = PlayerPedId()

    RemoveHomelandWeapons()
    Citizen.Wait(300)

    SetEntityCoords(ped, savedPosition.x, savedPosition.y, savedPosition.z)

    if savedOutfit then
        ApplyOutfit(savedOutfit)
    end

    Citizen.Wait(300)
    RestoreWeapons()

    savedPosition = nil
    savedOutfit = nil
    isAtHomeland = false

    TriggerServerEvent('homeland:playerReturned')
    TriggerEvent('homeland:removePingBlip')

    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = false
    })
end)

RegisterNetEvent('homeland:forceTeleportBack', function()
    if not isAtHomeland or not savedPosition then return end

    local ped = PlayerPedId()

    RemoveHomelandWeapons()
    Citizen.Wait(300)

    SetEntityCoords(ped, savedPosition.x, savedPosition.y, savedPosition.z)

    if savedOutfit then
        ApplyOutfit(savedOutfit)
    end

    Citizen.Wait(300)
    RestoreWeapons()

    savedPosition = nil
    savedOutfit = nil
    isAtHomeland = false

    TriggerServerEvent('homeland:playerReturned')
    TriggerEvent('homeland:removePingBlip')

    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = false
    })
end)

-----------------------------------------------------------------------
-- Status Sync
-----------------------------------------------------------------------
RegisterNetEvent('homeland:syncStatus', function(stateData)
    operationState = stateData.state

    if operationState == "INACTIVE" and not isAtHomeland then
        SendNUIMessage({
            action = 'updateTeleportState',
            isAtHomeland = false
        })
    end

    SendNUIMessage({
        type = 'updateStatus',
        state = operationState
    })

    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = isAtHomeland
    })

    if operationState == "INACTIVE" then
        TriggerEvent('homeland:removePingBlip')
    end
end)

-----------------------------------------------------------------------
-- Open UI
-----------------------------------------------------------------------
RegisterNetEvent('homeland:openUI', function()
    ESX.TriggerServerCallback('homeland:getStatus', function(statusData)
        operationState = statusData.state
        isLeader = statusData.isLeader

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            state = operationState,
            isAtHomeland = isAtHomeland,
            isLeader = isLeader,
            streamerMode = streamerMode,
            empActive = empState.active
        })
    end)
end)

-----------------------------------------------------------------------
-- NUI Callbacks
-----------------------------------------------------------------------
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('refocus', function(data, cb)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'refocus' })
    cb('ok')
end)

RegisterNUICallback('alertAgents', function(data, cb)
    TriggerServerEvent('homeland:alertAgents')
    cb('ok')
end)

RegisterNUICallback('goLive', function(data, cb)
    TriggerServerEvent('homeland:goLive')
    cb('ok')
end)

RegisterNUICallback('stopHomeland', function(data, cb)
    TriggerServerEvent('homeland:stop')
    cb('ok')
end)

RegisterNUICallback('teleportTo', function(data, cb)
    TriggerServerEvent('homeland:teleportTo')
    cb('ok')
    Citizen.SetTimeout(200, function()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'refocus' })
    end)
end)

RegisterNUICallback('teleportBack', function(data, cb)
    TriggerServerEvent('homeland:teleportBack')
    cb('ok')
    Citizen.SetTimeout(200, function()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'refocus' })
    end)
end)

RegisterNUICallback('getStatus', function(data, cb)
    ESX.TriggerServerCallback('homeland:getStatus', function(statusData)
        cb({
            state = statusData.state,
            isLeader = statusData.isLeader
        })
    end)
end)

RegisterNUICallback('setWeather', function(data, cb)
    TriggerServerEvent('homeland:setWeather')
    cb('ok')
end)

RegisterNUICallback('restoreWeather', function(data, cb)
    TriggerServerEvent('homeland:restoreWeather')
    cb('ok')
end)

RegisterNUICallback('pingPlayer', function(data, cb)
    if data.playerId then
        TriggerServerEvent('homeland:pingPlayer', tonumber(data.playerId))
    end
    cb('ok')
end)

RegisterNUICallback('broadcastMessage', function(data, cb)
    if data.message and data.message ~= '' then
        TriggerServerEvent('homeland:broadcastMessage', data.message)
    end
    cb('ok')
end)

RegisterNUICallback('cinemaMusicEnded', function(data, cb)
    TriggerServerEvent('homeland:cinemaEnded')
    cb('ok')
end)

RegisterNUICallback('toggleStreamer', function(data, cb)
    streamerMode = not streamerMode
    TriggerServerEvent('homeland:setStreamer', streamerMode)
    cb({ enabled = streamerMode })
end)

RegisterNUICallback('toggleEmp', function(data, cb)
    TriggerServerEvent('homeland:toggleEmp')
    cb('ok')
end)

-----------------------------------------------------------------------
-- Weather
-----------------------------------------------------------------------
RegisterNetEvent('homeland:applyWeather', function(weatherType)
    if not weatherOverrideActive then
        weatherOverrideActive = true
    end

    SetWeatherTypePersist(weatherType)
    SetWeatherTypeNowPersist(weatherType)
    SetWeatherTypeNow(weatherType)
    SetOverrideWeather(weatherType)
    SetWeatherTypeTransition(GetHashKey(weatherType), GetHashKey(weatherType), 0.0)
end)

RegisterNetEvent('homeland:restoreWeather', function()
    ClearOverrideWeather()
    ClearWeatherTypePersist()

    SetWeatherTypePersist('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    SetWeatherTypeNow('CLEAR')
    SetOverrideWeather('CLEAR')

    weatherOverrideActive = false
end)

-----------------------------------------------------------------------
-- Cinema Music (played via NUI audio element)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:playCinemaMusic', function()
    SendNUIMessage({
        action = 'playCinemaMusic',
        file = Config.CinemaMusic.file,
        volume = Config.CinemaMusic.volume
    })
end)

RegisterNetEvent('homeland:stopCinemaMusic', function()
    SendNUIMessage({
        action = 'stopCinemaMusic'
    })
end)

-----------------------------------------------------------------------
-- Vehicle Tuning (max upgrades + black)
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- Handling-Profile
-----------------------------------------------------------------------
local function GetHandlingProfile(vehicle)
    local model = GetEntityModel(vehicle)
    local isInsurgent = model == GetHashKey('insurgent2') or model == GetHashKey('insurgent3')
    local isHeli = IsThisModelAHeli(model)

    if isHeli then
        return 'heli', {
            power = 25.0, torque = 20.0, topSpeed = 6.0,
            mass = 2200.0, drag = 1.5, submerged = 70.0
        }
    elseif isInsurgent then
        return 'ground', {
            power = 14.0, torque = 12.0, topSpeed = 4.5,
            brake = 1.0, handBrake = 0.8, brakeBias = 0.42,
            tractionMax = 3.0, tractionMin = 2.5, tractionSpring = 0.2,
            steeringLock = 30.0, antiRoll = 0.5, suspension = 1.2, rebound = 1.0,
            mass = 12000.0, drag = 4.0, seatZ = -0.5
        }
    else -- Nightshark / Default
        return 'ground', {
            power = 20.0, torque = 16.0, topSpeed = 6.5,
            brake = 1.8, handBrake = 1.2, brakeBias = 0.45,
            tractionMax = 4.0, tractionMin = 3.5, tractionSpring = 0.15,
            steeringLock = 35.0, antiRoll = 1.0, suspension = 2.0, rebound = 1.5,
            mass = 8000.0, drag = 3.0, seatZ = -0.3
        }
    end
end

local function ApplyHandling(vehicle, vType, tune)
    SetVehicleEnginePowerMultiplier(vehicle, tune.power)
    SetVehicleEngineTorqueMultiplier(vehicle, tune.torque)
    ModifyVehicleTopSpeed(vehicle, tune.topSpeed)

    if vType == 'heli' then
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass', tune.mass)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff', tune.drag)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPercentSubmerged', tune.submerged)
        SetHeliTurbulenceScalar(vehicle, 0.0)
    else
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', tune.brake)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fHandBrakeForce', tune.handBrake)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeBiasFront', tune.brakeBias)

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', tune.tractionMax)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', tune.tractionMin)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionSpringDeltaMax', tune.tractionSpring)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionBiasFront', 0.50)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fLowSpeedTractionLossMult', 0.0)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionLossMult', 0.0)

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', tune.steeringLock)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fAntiRollBarForce', tune.antiRoll)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', tune.suspension)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp', tune.rebound)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fCamberStiffnesss', 0.0)

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass', tune.mass)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDragCoeff', tune.drag)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSeatOffsetDistZ', tune.seatZ)
    end
end

-----------------------------------------------------------------------
-- Optik-Tuning (einmalig, networked — bleibt auf dem Fahrzeug)
-----------------------------------------------------------------------
local function TuneVehicleVisuals(netId)
    local attempts = 0
    while not NetworkDoesNetworkIdExist(netId) and attempts < 50 do
        Wait(50)
        attempts = attempts + 1
    end

    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end

    NetworkRequestControlOfEntity(vehicle)
    local controlAttempts = 0
    while not NetworkHasControlOfEntity(vehicle) and controlAttempts < 50 do
        Wait(50)
        NetworkRequestControlOfEntity(vehicle)
        controlAttempts = controlAttempts + 1
    end

    if not NetworkHasControlOfEntity(vehicle) then return end

    SetVehicleModKit(vehicle, 0)

    for mod = 0, 49 do
        local maxMod = GetNumVehicleMods(vehicle, mod) - 1
        if maxMod >= 0 then
            SetVehicleMod(vehicle, mod, maxMod, false)
        end
    end

    ToggleVehicleMod(vehicle, 18, true)
    ToggleVehicleMod(vehicle, 22, true)
    SetVehicleColours(vehicle, 12, 12)
    SetVehicleExtraColours(vehicle, 0, 0)
    SetVehicleMod(vehicle, 48, -1, false)
    SetVehicleLivery(vehicle, -1)
    SetVehicleWindowTint(vehicle, 1)
    SetVehicleMod(vehicle, 16, GetNumVehicleMods(vehicle, 16) - 1, false)

    if IsThisModelAHeli(GetEntityModel(vehicle)) then
        SetHeliBladesFullSpeed(vehicle)
        SetHeliTailExplodeThrowDashboard(vehicle, false)
    end

    -- Einmalig Handling setzen
    local vType, tune = GetHandlingProfile(vehicle)
    ApplyHandling(vehicle, vType, tune)
end

-----------------------------------------------------------------------
-- Persistent Handling Thread (1 pro Spieler, applied auf aktuelles Fahrzeug)
-----------------------------------------------------------------------
local function StartHandlingThread()
    if handlingThreadActive then return end
    handlingThreadActive = true

    CreateThread(function()
        while isAtHomeland and operationState ~= "INACTIVE" do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                -- Prüfen ob es ein Homeland-Fahrzeug ist
                local vNetId = NetworkGetNetworkIdFromEntity(vehicle)
                local isHomelandVehicle = false
                for _, netId in ipairs(homelandVehicleNetIds) do
                    if netId == vNetId then
                        isHomelandVehicle = true
                        break
                    end
                end

                if isHomelandVehicle then
                    local vType, tune = GetHandlingProfile(vehicle)
                    ApplyHandling(vehicle, vType, tune)
                end
            end

            Wait(500)
        end

        handlingThreadActive = false
    end)
end

-- Alle Fahrzeuge sequentiell tunen (Optik) + Handling-Thread starten
RegisterNetEvent('homeland:tuneVehicles', function(netIds)
    homelandVehicleNetIds = netIds

    CreateThread(function()
        for _, netId in ipairs(netIds) do
            TuneVehicleVisuals(netId)
            Wait(500)
        end
    end)

    StartHandlingThread()
end)

-----------------------------------------------------------------------
-- Phone Sound (for broadcast messages)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:playPhoneSound', function()
    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, "Menu_Accept", "Phone_SoundSet_Default", false)
    ReleaseSoundId(soundId)
end)

-----------------------------------------------------------------------
-- Agent Alert Sound (custom audio via NUI, only for agents sammeln)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:playBroadcastSound', function()
    if streamerMode then return end
    SendNUIMessage({
        action = 'playBroadcastSound',
        file = Config.NotificationSound.file,
        volume = Config.NotificationSound.volume
    })
end)

-----------------------------------------------------------------------
-- Notification Wrapper (respects Streamer Mode)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:notify', function(data)
    if streamerMode then return end
    if lib and lib.notify then
        lib.notify(data)
    else
        TriggerEvent('ox_lib:notify', data)
    end
end)

-----------------------------------------------------------------------
-- Blip System
-----------------------------------------------------------------------
RegisterNetEvent('homeland:updateBlips', function(agentPositions)
    local myServerId = GetPlayerServerId(PlayerId())
    local seen = {}

    for i = 1, #agentPositions do
        local agent = agentPositions[i]
        if agent.id ~= myServerId then
            seen[agent.id] = true
            local blip = activeBlips[agent.id]
            if blip and DoesBlipExist(blip) then
                SetBlipCoords(blip, agent.coords.x, agent.coords.y, agent.coords.z)
            else
                blip = AddBlipForCoord(agent.coords.x, agent.coords.y, agent.coords.z)
                SetBlipSprite(blip, 303)
                SetBlipColour(blip, 1)
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("HOMELAND Agent")
                EndTextCommandSetBlipName(blip)
                activeBlips[agent.id] = blip
            end
        end
    end

    for id, blip in pairs(activeBlips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            activeBlips[id] = nil
        end
    end
end)

RegisterNetEvent('homeland:clearBlips', function()
    for id, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        activeBlips[id] = nil
    end
end)

RegisterNetEvent('homeland:showPingBlip', function(coords)
    if pingBlip and DoesBlipExist(pingBlip) then
        SetBlipCoords(pingBlip, coords.x, coords.y, coords.z)
    else
        pingBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(pingBlip, 161)
        SetBlipColour(pingBlip, 1)
        SetBlipScale(pingBlip, 1.2)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Gepingter Spieler")
        EndTextCommandSetBlipName(pingBlip)
    end

    SetNewWaypoint(coords.x, coords.y)
end)

RegisterNetEvent('homeland:removePingBlip', function()
    if pingBlip and DoesBlipExist(pingBlip) then
        RemoveBlip(pingBlip)
        pingBlip = nil
    end
    SetWaypointOff()
end)

RegisterNetEvent('homeland:stopClientPing', function()
    SendNUIMessage({ action = 'stopPing' })
end)

-----------------------------------------------------------------------
-- EMP Field
-----------------------------------------------------------------------
local function IsHomelandNetId(netId)
    for i = 1, #empState.homelandNetIds do
        if empState.homelandNetIds[i] == netId then return true end
    end
    return false
end

local function RestoreVehicle(veh)
    if not DoesEntityExist(veh) then return end
    NetworkRequestControlOfEntity(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleLights(veh, 0)
end

local function EmpCleanup()
    for veh in pairs(empAffectedVehicles) do
        RestoreVehicle(veh)
    end
    empAffectedVehicles = {}

    if empLocalBlackout then
        SetArtificialLightsState(false)
        empLocalBlackout = false
    end
end

local function EnsureEmpPtfx()
    if empPtfxLoaded then return true end
    RequestNamedPtfxAsset("core")
    local tries = 0
    while not HasNamedPtfxAssetLoaded("core") and tries < 50 do
        Wait(50)
        tries = tries + 1
    end
    empPtfxLoaded = HasNamedPtfxAssetLoaded("core")
    return empPtfxLoaded
end

local function SparkBurst(coords)
    if not EnsureEmpPtfx() then return end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord(
        "ent_sht_electrical_box",
        coords.x, coords.y, coords.z + 0.5,
        0.0, 0.0, 0.0, 1.2, false, false, false
    )
end

local function StartEmpClientThread()
    CreateThread(function()
        EnsureEmpPtfx()
        while empState.active do
            local radius = Config.Emp.radius
            local pCoords = GetEntityCoords(PlayerPedId())

            local selfInZone = false
            for i = 1, #empState.leaders do
                local l = empState.leaders[i]
                if #(pCoords - vector3(l.x, l.y, l.z)) <= radius then
                    selfInZone = true
                    break
                end
            end

            if selfInZone and not empLocalBlackout then
                SetArtificialLightsState(true)
                SetArtificialLightsStateAffectsVehicles(false)
                empLocalBlackout = true
            elseif not selfInZone and empLocalBlackout then
                SetArtificialLightsState(false)
                empLocalBlackout = false
            end

            local vehicles = GetGamePool('CVehicle')
            local stillAffected = {}

            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) and NetworkGetEntityIsNetworked(veh) then
                    local vCoords = GetEntityCoords(veh)
                    local minDist = 999999.0
                    for i = 1, #empState.leaders do
                        local l = empState.leaders[i]
                        local d = #(vCoords - vector3(l.x, l.y, l.z))
                        if d < minDist then minDist = d end
                    end

                    local vNetId = NetworkGetNetworkIdFromEntity(veh)
                    local isHomeland = IsHomelandNetId(vNetId)

                    if not isHomeland and minDist <= radius then
                        if not empAffectedVehicles[veh] then
                            SparkBurst(vCoords)
                        end
                        NetworkRequestControlOfEntity(veh)
                        SetVehicleEngineOn(veh, false, true, true)
                        SetVehicleUndriveable(veh, true)
                        SetVehicleLights(veh, 1)
                        empAffectedVehicles[veh] = true
                        stillAffected[veh] = true
                    end
                end
            end

            for veh in pairs(empAffectedVehicles) do
                if not stillAffected[veh] then
                    RestoreVehicle(veh)
                    empAffectedVehicles[veh] = nil
                end
            end

            Wait(250)
        end

        EmpCleanup()
    end)
end

RegisterNetEvent('homeland:empUpdate', function(data)
    local wasActive = empState.active
    empState.active = data.active and true or false
    empState.leaders = data.leaders or {}
    empState.homelandNetIds = data.homelandNetIds or {}

    if empState.active and not wasActive then
        StartEmpClientThread()
    end
end)

RegisterNetEvent('homeland:empStateChanged', function(active)
    SendNUIMessage({ action = 'empStateChanged', active = active and true or false })
end)

-----------------------------------------------------------------------
-- Command
-----------------------------------------------------------------------
RegisterCommand('homeland', function()
    ESX.TriggerServerCallback('homeland:checkAuth', function(authorized)
        if authorized then
            TriggerEvent('homeland:openUI')
        else
            ESX.ShowNotification('ZUGRIFF VERWEIGERT | Du hast keine Berechtigung.')
        end
    end)
end, false)

-----------------------------------------------------------------------
-- Cleanup on resource stop
-----------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for id, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips = {}

    if pingBlip and DoesBlipExist(pingBlip) then
        RemoveBlip(pingBlip)
    end

    SetWaypointOff()

    -- Restore EMP-affected vehicles
    for veh in pairs(empAffectedVehicles) do
        if DoesEntityExist(veh) then
            SetVehicleEngineOn(veh, true, true, false)
            SetVehicleUndriveable(veh, false)
            SetVehicleLights(veh, 0)
        end
    end
    if empLocalBlackout then
        SetArtificialLightsState(false)
    end
end)
