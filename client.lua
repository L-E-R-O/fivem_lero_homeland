local playerData = {}
local savedOutfit = nil
local savedPosition = nil
local isHomelandActive = false
local savedWeapons = {}
local isAtHomeland = false

local activeBlips = {}
local pingBlip = nil
local lastPingCoords = nil

local weatherOverrideActive = false
local savedWeatherType = nil

-- Save current outfit
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

-- Apply outfit
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

-- Save current weapons (ESX)
local function SaveWeapons()
    savedWeapons = {}
    
    ESX.TriggerServerCallback('homeland:getLoadout', function(loadout)
        savedWeapons = loadout
    end)
end

-- Remove all weapons (ESX)
local function RemoveAllWeapons()
    TriggerServerEvent('homeland:removeAllWeapons')
end

-- Give Homeland weapons (ESX)
local function GiveHomelandWeapons()
    TriggerServerEvent('homeland:giveWeapons')
end

-- Restore saved weapons (ESX)
local function RestoreWeapons()
    if not savedWeapons or #savedWeapons == 0 then
        return
    end
    
    TriggerServerEvent('homeland:restoreWeapons', savedWeapons)
    savedWeapons = {}
end

-- Remove Homeland weapons
local function RemoveHomelandWeapons()
    TriggerServerEvent('homeland:removeHomelandWeapons')
end

-- Teleport to Homeland
RegisterNetEvent('homeland:teleportTo', function()
    if isAtHomeland then
        ESX.ShowNotification('❌ FEHLER | Du bist bereits im Einsatz!')
        return
    end
    
    local ped = PlayerPedId()
    
    -- Save current position, outfit and weapons
    savedPosition = GetEntityCoords(ped)
    SaveOutfit()
    
    Citizen.Wait(100)
    SaveWeapons()
    
    Citizen.Wait(100)
    RemoveAllWeapons()
    
    Citizen.Wait(200)
    
    -- Teleport
    SetEntityCoords(ped, Config.TeleportLocation.x, Config.TeleportLocation.y, Config.TeleportLocation.z)
    SetEntityHeading(ped, Config.TeleportLocation.heading)
    
    -- Apply Homeland outfit
    local gender = 'male'
    if GetEntityModel(ped) == GetHashKey('mp_f_freemode_01') then
        gender = 'female'
    end
    
    ApplyOutfit(Config.HomelandOutfit[gender])
    
    Citizen.Wait(200)
    
    -- Give Homeland weapons
    GiveHomelandWeapons()
    
    -- Mark as at Homeland
    isAtHomeland = true
    
    -- Update UI
    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = true
    })
    
    ESX.ShowNotification('⚠️ EINSATZBEREIT | Du bist jetzt im Dienst.')
end)

-- Attempt teleport back (called from server to check if valid)
RegisterNetEvent('homeland:attemptTeleportBack', function()
    -- Check if we have a saved position
    if savedPosition and isAtHomeland then
        -- We were at Homeland, allow teleport back
        TriggerEvent('homeland:teleportBack')
    else
        ESX.ShowNotification('❌ FEHLER | Du warst nicht im Einsatz.')
    end
end)

-- Teleport back
RegisterNetEvent('homeland:teleportBack', function()
    if not savedPosition then
        ESX.ShowNotification('❌ FEHLER | Keine Rückkehrposition gefunden.')
        return
    end
    
    if not isAtHomeland then
        ESX.ShowNotification('❌ FEHLER | Du warst nicht im Einsatz.')
        return
    end
    
    local ped = PlayerPedId()
    
    -- Remove Homeland weapons specifically
    RemoveHomelandWeapons()
    
    Citizen.Wait(300)
    
    -- Teleport back
    SetEntityCoords(ped, savedPosition.x, savedPosition.y, savedPosition.z)
    
    -- Restore outfit
    if savedOutfit then
        ApplyOutfit(savedOutfit)
    end
    
    Citizen.Wait(300)
    
    -- Restore weapons
    RestoreWeapons()
    
    savedPosition = nil
    savedOutfit = nil
    isAtHomeland = false
    
    -- Notify server that we're back
    TriggerServerEvent('homeland:playerReturned')
    -- Blip entfernen, falls vorhanden
    TriggerEvent('homeland:removePingBlip')
    
    -- Update UI
    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = false
    })
    
    ESX.ShowNotification('✓ ZURÜCKGEKEHRT | Zivile Identität wiederhergestellt.')
end)

-- Force teleport back (called when Homeland ends)
RegisterNetEvent('homeland:forceTeleportBack', function()
    if not isAtHomeland or not savedPosition then
        print('[HOMELAND] Force teleport back called but player not at Homeland or no saved position')
        return
    end
    
    print('[HOMELAND] Force teleporting player back')
    
    local ped = PlayerPedId()
    
    -- Remove Homeland weapons
    RemoveHomelandWeapons()
    
    Citizen.Wait(300)
    
    -- Teleport back
    SetEntityCoords(ped, savedPosition.x, savedPosition.y, savedPosition.z)
    
    -- Restore outfit
    if savedOutfit then
        ApplyOutfit(savedOutfit)
    end
    
    Citizen.Wait(300)
    
    -- Restore weapons
    RestoreWeapons()
    
    savedPosition = nil
    savedOutfit = nil
    isAtHomeland = false
    
    -- Notify server
    TriggerServerEvent('homeland:playerReturned')
    -- Blip entfernen, falls vorhanden
    TriggerEvent('homeland:removePingBlip')
    
    -- Update UI
    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = false
    })
    
    ESX.ShowNotification('☠️ EVAKUIERT | Notfall-Rückkehr abgeschlossen.')
end)

-- Sync status
RegisterNetEvent('homeland:syncStatus', function(active)
    isHomelandActive = active
    
    -- Reset teleport state when Homeland stops
    if not active and not isAtHomeland then
        -- Only reset if we're not at Homeland (force teleport will handle it)
        SendNUIMessage({
            action = 'updateTeleportState',
            isAtHomeland = false
        })
    end
    
    SendNUIMessage({
        type = 'updateStatus',
        active = active
    })
    
    -- Update teleport state
    SendNUIMessage({
        action = 'updateTeleportState',
        isAtHomeland = isAtHomeland
    })
    
    if not active then
        -- Blip entfernen, falls Job beendet wird
        TriggerEvent('homeland:removePingBlip')
    end
end)

-- Open UI Event
RegisterNetEvent('homeland:openUI', function()
    -- Hole aktuellen Status
    ESX.TriggerServerCallback('homeland:getStatus', function(active)
        -- Öffne NUI mit Focus für Keyboard-Input
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            status = active,
            isAtHomeland = isAtHomeland -- Send current teleport state
        })
    end)
end)

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('refocus', function(data, cb)
    -- Restore focus after teleport
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'refocus'
    })
    cb('ok')
end)

RegisterNUICallback('startHomeland', function(data, cb)
    TriggerServerEvent('homeland:start')
    cb('ok')
end)

RegisterNUICallback('stopHomeland', function(data, cb)
    TriggerServerEvent('homeland:stop')
    cb('ok')
end)

RegisterNUICallback('teleportTo', function(data, cb)
    TriggerServerEvent('homeland:teleportTo')
    cb('ok')
    -- Restore focus after teleport
    Citizen.SetTimeout(200, function()
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'refocus'
        })
    end)
end)

RegisterNUICallback('teleportBack', function(data, cb)
    TriggerServerEvent('homeland:teleportBack')
    cb('ok')
    -- Restore focus after teleport
    Citizen.SetTimeout(200, function()
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'refocus'
        })
    end)
end)

RegisterNUICallback('getStatus', function(data, cb)
    ESX.TriggerServerCallback('homeland:getStatus', function(active)
        cb({active = active})
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

-- Apply Homeland Weather
RegisterNetEvent('homeland:applyWeather', function(weatherType)
    if not weatherOverrideActive then
        savedWeatherType = GetPrevWeatherTypeHashName()
        weatherOverrideActive = true
        print('[HOMELAND] Saved current weather: ' .. tostring(savedWeatherType))
    end

    SetWeatherTypePersist(weatherType)
    SetWeatherTypeNowPersist(weatherType)
    SetWeatherTypeNow(weatherType)
    SetOverrideWeather(weatherType)

    SetWeatherTypeTransition(GetHashKey(weatherType), GetHashKey(weatherType), 0.0)

    print('[HOMELAND] Weather set to: ' .. weatherType)

    ESX.ShowNotification('⛈️ UNWETTER | Schwere Gewitterfront zieht auf.')
end)

RegisterNetEvent('homeland:restoreWeather', function()
    ClearOverrideWeather()
    ClearWeatherTypePersist()

    SetWeatherTypePersist('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    SetWeatherTypeNow('CLEAR')
    SetOverrideWeather('CLEAR')

    weatherOverrideActive = false
    savedWeatherType = nil

    print('[HOMELAND] Weather restored to CLEAR')

    ESX.ShowNotification('☀️ ENTWARNUNG | Wetterlage normalisiert sich.')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Cleanup blips
    for i = 1, #activeBlips do
        if DoesBlipExist(activeBlips[i]) then
            RemoveBlip(activeBlips[i])
        end
    end
    
    if pingBlip and DoesBlipExist(pingBlip) then
        RemoveBlip(pingBlip)
    end
end)

-- Play alarm sound when Homeland starts
RegisterNetEvent('homeland:playAlarm', function()
    local soundConfig = Config.AlarmSound
    
    -- Play first sound immediately
    PlaySoundFrontend(-1, soundConfig.name, soundConfig.set, true)
    
    -- Play additional repeats
    for i = 1, soundConfig.repeats - 1 do
        Citizen.SetTimeout(soundConfig.delay * i, function()
            PlaySoundFrontend(-1, soundConfig.name, soundConfig.set, true)
        end)
    end
end)

-- Command to open Homeland UI
RegisterCommand('homeland', function()
    ESX.TriggerServerCallback('homeland:checkAuth', function(authorized)
        if authorized then
            TriggerEvent('homeland:openUI')
        else
            ESX.ShowNotification('❌ ZUGRIFF VERWEIGERT | Du hast keine Berechtigung für diesen Befehl.')
        end
    end)
end, false)

RegisterNetEvent('homeland:updateBlips', function(agentPositions)
    for i = #activeBlips, 1, -1 do
        if DoesBlipExist(activeBlips[i]) then
            RemoveBlip(activeBlips[i])
        end
        activeBlips[i] = nil
    end
    
    local myId = PlayerId()
    for i = 1, #agentPositions do
        local agent = agentPositions[i]
        if agent.id ~= myId then
            local blip = AddBlipForCoord(agent.coords.x, agent.coords.y, agent.coords.z)
            SetBlipSprite(blip, 303)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("HOMELAND Agent")
            EndTextCommandSetBlipName(blip)
            activeBlips[#activeBlips + 1] = blip
        end
    end
end)

RegisterNetEvent('homeland:clearBlips', function()
    for i = #activeBlips, 1, -1 do
        if DoesBlipExist(activeBlips[i]) then
            RemoveBlip(activeBlips[i])
        end
        activeBlips[i] = nil
    end
end)

RegisterNetEvent('homeland:showPingBlip', function(coords)
    if pingBlip and DoesBlipExist(pingBlip) then
        SetBlipCoords(pingBlip, coords.x, coords.y, coords.z)
    else
        pingBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(pingBlip, 161)
        SetBlipColour(pingBlip, 1)
        SetBlipScale(blip, 1.2)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Gespingter Spieler")
        EndTextCommandSetBlipName(pingBlip)
    end
    lastPingCoords = coords
end)

RegisterNetEvent('homeland:removePingBlip', function()
    if pingBlip and DoesBlipExist(pingBlip) then
        RemoveBlip(pingBlip)
        pingBlip = nil
    end
    lastPingCoords = nil
end)

RegisterNetEvent('homeland:stopClientPing', function()
    SendNUIMessage({
        action = 'stopPing'
    })
end)

-- Play broadcast notification sound
RegisterNetEvent('homeland:playBroadcastSound', function()
    if Config.BroadcastSound then
        PlaySoundFrontend(
            -1, 
            Config.BroadcastSound.name, 
            Config.BroadcastSound.set, 
            true
        )
        
        -- Optional: Adjust volume if supported
        if Config.BroadcastSound.volume then
            -- Note: Volume control is limited in FiveM, this is a workaround
            Citizen.CreateThread(function()
                local soundId = GetSoundId()
                PlaySoundFrontend(soundId, Config.BroadcastSound.name, Config.BroadcastSound.set, true)
                -- Volume adjustment would require additional natives if available
                ReleaseSoundId(soundId)
            end)
        end
    end
end)