local operationState = "INACTIVE" -- INACTIVE | ALERTING | ACTIVE
local spawnedVehicles = {}
local spawnedVehicleNetIds = {}
local activePlayers = {}
local currentWeather = "CLEAR"
local activePings = {}
local pingThreads = {}
local cinemaTransitioned = false
local empActive = false
local empThreadRunning = false
local streamerPlayers = {}

-- Cache authorized players to reduce lookups
local authorizedPlayersCache = {}
local leaderCache = {}
local cacheUpdateTime = 0
local CACHE_LIFETIME = 30000

-- Check if player is a Leader
local function IsLeader(source)
    local currentTime = GetGameTimer()

    if currentTime - cacheUpdateTime > CACHE_LIFETIME then
        authorizedPlayersCache = {}
        leaderCache = {}
        cacheUpdateTime = currentTime
    end

    if leaderCache[source] ~= nil then
        return leaderCache[source]
    end

    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers then
        leaderCache[source] = false
        return false
    end

    for _, configId in ipairs(Config.Leaders) do
        for _, playerId in ipairs(identifiers) do
            if playerId == configId then
                leaderCache[source] = true
                return true
            end
        end
    end

    leaderCache[source] = false
    return false
end

-- Check if player is authorized (Leader OR Agent)
local function IsAuthorized(source)
    if IsLeader(source) then
        return true
    end

    local currentTime = GetGameTimer()

    if currentTime - cacheUpdateTime > CACHE_LIFETIME then
        authorizedPlayersCache = {}
        leaderCache = {}
        cacheUpdateTime = currentTime
    end

    if authorizedPlayersCache[source] ~= nil then
        return authorizedPlayersCache[source]
    end

    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers then
        authorizedPlayersCache[source] = false
        return false
    end

    for _, configId in ipairs(Config.Agents) do
        for _, playerId in ipairs(identifiers) do
            if playerId == configId then
                authorizedPlayersCache[source] = true
                return true
            end
        end
    end

    authorizedPlayersCache[source] = false
    return false
end

-- Get all authorized players (Leaders + Agents)
local function GetAuthorizedPlayers()
    local authorized = {}
    local xPlayers = ESX.GetExtendedPlayers()

    for _, xPlayer in pairs(xPlayers) do
        if IsAuthorized(xPlayer.source) then
            authorized[#authorized + 1] = xPlayer.source
        end
    end

    return authorized
end

-- Unified notification function
local function NotifyPlayer(source, title, message, type, duration)
    if not source then return end

    TriggerClientEvent('homeland:notify', source, {
        title = title,
        description = message,
        type = type or 'info',
        duration = duration or 5000
    })
end

-- Notify all authorized players
local function NotifyAuthorized(title, message, type, duration)
    local authorized = GetAuthorizedPlayers()

    for i = 1, #authorized do
        NotifyPlayer(authorized[i], title, message, type, duration)
    end
end

-- Spawn vehicles
local function SpawnVehicles()
    local vehicleCount = #Config.Vehicles

    for i = 1, vehicleCount do
        local vehicleData = Config.Vehicles[i]
        local vehicle = CreateVehicle(
            GetHashKey(vehicleData.model),
            vehicleData.pos.x,
            vehicleData.pos.y,
            vehicleData.pos.z,
            vehicleData.pos.heading,
            true,
            true
        )

        local timeout = 0
        while not DoesEntityExist(vehicle) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end

        if DoesEntityExist(vehicle) then
            spawnedVehicles[#spawnedVehicles + 1] = vehicle
            spawnedVehicleNetIds[#spawnedVehicleNetIds + 1] = NetworkGetNetworkIdFromEntity(vehicle)
        end
    end

    print('[HOMELAND] Spawned ' .. #spawnedVehicles .. '/' .. vehicleCount .. ' vehicles')
end

-- Delete vehicles
local function DeleteVehicles()
    for i = 1, #spawnedVehicles do
        local vehicle = spawnedVehicles[i]
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end

    spawnedVehicles = {}
    spawnedVehicleNetIds = {}
end

-----------------------------------------------------------------------
-- Phase 1: Agents sammeln (INACTIVE → ALERTING)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:alertAgents', function()
    local source = source

    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können Operationen starten.', 'error')
        return
    end

    if operationState ~= "INACTIVE" then
        NotifyPlayer(source, 'FEHLER', 'Operation ist bereits aktiv.', 'error')
        return
    end

    operationState = "ALERTING"
    SpawnVehicles()

    -- Notification-Sound nur an autorisierte Spieler
    local authorized = GetAuthorizedPlayers()
    for i = 1, #authorized do
        TriggerClientEvent('homeland:playBroadcastSound', authorized[i])
    end

    NotifyAuthorized("HOMELAND SECURITY", "Alle Agents zum Einsatzort! Operation wird vorbereitet.", "warning", 15000)
    TriggerClientEvent('homeland:syncStatus', -1, { state = "ALERTING" })

    print('[HOMELAND] Alert phase started by ' .. GetPlayerName(source))

    -- Blip update thread
    CreateThread(function()
        while operationState ~= "INACTIVE" do
            local authPlayers = GetAuthorizedPlayers()
            local positions = {}

            local orderedIds = {}
            for playerId in pairs(activePlayers) do
                orderedIds[#orderedIds + 1] = playerId
            end
            table.sort(orderedIds)

            for i = 1, #orderedIds do
                local playerId = orderedIds[i]
                local ped = GetPlayerPed(playerId)
                if DoesEntityExist(ped) then
                    positions[#positions + 1] = {
                        id = playerId,
                        coords = GetEntityCoords(ped)
                    }
                end
            end

            for i = 1, #authPlayers do
                TriggerClientEvent('homeland:updateBlips', authPlayers[i], positions)
            end

            Wait(2000)
        end
    end)
end)

-----------------------------------------------------------------------
-- Phase 2: Einsatz starten (ALERTING → ACTIVE)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:goLive', function()
    local source = source

    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können den Einsatz starten.', 'error')
        return
    end

    if operationState ~= "ALERTING" then
        NotifyPlayer(source, 'FEHLER', 'Agents müssen zuerst gesammelt werden.', 'error')
        return
    end

    operationState = "ACTIVE"
    cinemaTransitioned = false

    -- Weather THUNDER for all players
    TriggerClientEvent('homeland:applyWeather', -1, Config.HomelandWeather)

    -- Cinema music for ALL players
    TriggerClientEvent('homeland:playCinemaMusic', -1)

    TriggerClientEvent('homeland:syncStatus', -1, { state = "ACTIVE" })

    print('[HOMELAND] Go live by ' .. GetPlayerName(source))

    -- Fallback timer: transition weather if no client reports music ended
    Citizen.SetTimeout(Config.CinemaMusic.durationMs + 2000, function()
        if operationState == "ACTIVE" and not cinemaTransitioned then
            cinemaTransitioned = true
            TriggerClientEvent('homeland:applyWeather', -1, Config.HomelandWeatherRain)
            print('[HOMELAND] Weather fallback: THUNDER -> RAIN')
        end
    end)
end)

-----------------------------------------------------------------------
-- Cinema music ended (client reports song finished)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:cinemaEnded', function()
    local source = source

    if not IsAuthorized(source) then return end

    -- Only process once (multiple clients will fire this)
    if cinemaTransitioned or operationState ~= "ACTIVE" then return end

    cinemaTransitioned = true
    TriggerClientEvent('homeland:applyWeather', -1, Config.HomelandWeatherRain)

    print('[HOMELAND] Cinema ended, weather: THUNDER -> RAIN')
end)

-----------------------------------------------------------------------
-- Stop Operation (ALERTING/ACTIVE → INACTIVE)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:stop', function()
    local source = source

    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können Operationen beenden.', 'error')
        return
    end

    if operationState == "INACTIVE" then
        NotifyPlayer(source, 'FEHLER', 'Keine aktive Operation.', 'error')
        return
    end

    local wasActive = operationState == "ACTIVE"
    operationState = "INACTIVE"
    cinemaTransitioned = false

    if empActive then
        empActive = false
        TriggerClientEvent('homeland:empStateChanged', -1, false)
    end

    DeleteVehicles()

    -- Stop cinema music for all players
    if wasActive then
        TriggerClientEvent('homeland:stopCinemaMusic', -1)
    end

    -- Force return all active players
    for playerId in pairs(activePlayers) do
        NotifyPlayer(playerId, 'NOTFALL-EVAKUIERUNG', 'Operation abgebrochen! Sofortige Rückkehr eingeleitet.', 'error')
        TriggerClientEvent('homeland:forceTeleportBack', playerId)
    end

    -- Cleanup
    activePlayers = {}
    pingThreads = {}
    activePings = {}

    -- Restore weather for all
    TriggerClientEvent('homeland:restoreWeather', -1)

    NotifyAuthorized("HOMELAND SECURITY", "Operation wurde beendet.", "success")
    TriggerClientEvent('homeland:syncStatus', -1, { state = "INACTIVE" })

    local authorized = GetAuthorizedPlayers()
    for i = 1, #authorized do
        TriggerClientEvent('homeland:clearBlips', authorized[i])
        TriggerClientEvent('homeland:removePingBlip', authorized[i])
    end

    print('[HOMELAND] Stopped by ' .. GetPlayerName(source))
end)

-----------------------------------------------------------------------
-- Teleport
-----------------------------------------------------------------------
RegisterNetEvent('homeland:teleportTo', function()
    local source = source

    if not IsAuthorized(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return
    end

    if operationState == "INACTIVE" then
        NotifyPlayer(source, 'FEHLER', 'Keine aktive Operation.', 'error')
        return
    end

    if activePlayers[source] then
        NotifyPlayer(source, 'FEHLER', 'Du bist bereits im Einsatz!', 'error')
        return
    end

    activePlayers[source] = true
    TriggerClientEvent('homeland:teleportTo', source)

    -- Tuning nach Teleport senden — alle NetIds auf einmal, Client arbeitet sequentiell
    Citizen.SetTimeout(2000, function()
        TriggerClientEvent('homeland:tuneVehicles', source, spawnedVehicleNetIds)
    end)
end)

RegisterNetEvent('homeland:teleportBack', function()
    local source = source

    if not IsAuthorized(source) then return end

    activePlayers[source] = nil
    TriggerClientEvent('homeland:teleportBack', source)
end)

-----------------------------------------------------------------------
-- Status & Auth Callbacks
-----------------------------------------------------------------------
ESX.RegisterServerCallback('homeland:getStatus', function(source, cb)
    cb({
        state = operationState,
        isLeader = IsLeader(source)
    })
end)

ESX.RegisterServerCallback('homeland:checkAuth', function(source, cb)
    cb(IsAuthorized(source))
end)

-----------------------------------------------------------------------
-- Weapons (ox_inventory) — all with auth checks
-----------------------------------------------------------------------
ESX.RegisterServerCallback('homeland:getLoadout', function(source, cb)
    if not IsAuthorized(source) then
        cb({})
        return
    end

    local inv = exports.ox_inventory:GetInventory(source)
    local weapons = {}

    if inv and inv.items then
        for slot, item in pairs(inv.items) do
            if item and item.name and string.match(item.name, "^WEAPON_") then
                weapons[#weapons + 1] = {
                    name = item.name,
                    slot = slot,
                    metadata = item.metadata
                }
            end
        end
    end

    cb(weapons)
end)

RegisterNetEvent('homeland:removeAllWeapons', function()
    local source = source

    if not IsAuthorized(source) then return end

    local inv = exports.ox_inventory:GetInventory(source)

    if inv and inv.items then
        for slot, item in pairs(inv.items) do
            if item and item.name and string.match(item.name, "^WEAPON_") then
                exports.ox_inventory:RemoveItem(source, item.name, item.count, item.metadata, slot)
            end
        end
    end
end)

RegisterNetEvent('homeland:giveWeapons', function()
    local source = source

    if not IsAuthorized(source) then return end

    for _, weaponData in ipairs(Config.HomelandWeapons) do
        local metadata = {
            ammo = weaponData.ammo,
            durability = 100,
            registered = true,
            serial = 'HOMELAND'
        }

        local success = exports.ox_inventory:AddItem(source, weaponData.weapon, 1, metadata)

        if not success then
            print('[HOMELAND] Failed to give ' .. weaponData.weapon .. ' to player ' .. source)
        end
    end

    NotifyPlayer(source, 'AUSRÜSTUNG', 'Taktische Bewaffnung übernommen.', 'success')
end)

RegisterNetEvent('homeland:removeHomelandWeapons', function()
    local source = source

    if not IsAuthorized(source) then return end

    local inv = exports.ox_inventory:GetInventory(source)
    local removedCount = 0

    if inv and inv.items then
        local itemsToRemove = {}
        for slot, item in pairs(inv.items) do
            if item and item.metadata and item.metadata.serial == 'HOMELAND' then
                itemsToRemove[#itemsToRemove + 1] = {
                    name = item.name,
                    slot = slot,
                    count = item.count or 1
                }
            end
        end

        for _, itemData in ipairs(itemsToRemove) do
            local success = exports.ox_inventory:RemoveItem(source, itemData.name, itemData.count, nil, itemData.slot)
            if success then
                removedCount = removedCount + 1
            else
                print('[HOMELAND] Failed to remove ' .. itemData.name .. ' from player ' .. source)
            end
        end
    end

    if removedCount > 0 then
        NotifyPlayer(source, 'ENTWAFFNUNG', removedCount .. ' Waffe(n) konfisziert.', 'warning')
    end
end)

RegisterNetEvent('homeland:restoreWeapons', function(loadout)
    local source = source

    if not IsAuthorized(source) then return end

    if not loadout or #loadout == 0 then return end

    -- Validate loadout entries
    for _, weapon in ipairs(loadout) do
        if weapon.name and string.match(weapon.name, "^WEAPON_") then
            exports.ox_inventory:AddItem(source, weapon.name, 1, weapon.metadata)
        end
    end
end)

-----------------------------------------------------------------------
-- Weather (manual controls)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:setWeather', function()
    local source = source

    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können das Wetter ändern.', 'error')
        return
    end

    currentWeather = "THUNDER"
    TriggerClientEvent('homeland:applyWeather', -1, Config.HomelandWeather)

    NotifyPlayer(source, 'WETTERWARNUNG', 'Wetter auf Gewitter gesetzt.', 'success')
end)

RegisterNetEvent('homeland:restoreWeather', function()
    local source = source

    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können das Wetter ändern.', 'error')
        return
    end

    currentWeather = "CLEAR"
    TriggerClientEvent('homeland:restoreWeather', -1)

    NotifyPlayer(source, 'ENTWARNUNG', 'Wetter zurückgesetzt.', 'success')
end)

-----------------------------------------------------------------------
-- Player state events
-----------------------------------------------------------------------
RegisterNetEvent('homeland:playerReturned', function()
    local source = source

    if not IsAuthorized(source) then return end

    activePlayers[source] = nil
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
    local source = source

    activePlayers[source] = nil
    activePings[source] = nil
    pingThreads[source] = nil
    authorizedPlayersCache[source] = nil
    leaderCache[source] = nil
    streamerPlayers[source] = nil
end)

-----------------------------------------------------------------------
-- Ping System
-----------------------------------------------------------------------
RegisterNetEvent('homeland:pingPlayer', function(playerId)
    local source = source

    if not IsAuthorized(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return
    end

    playerId = tonumber(playerId)
    if not playerId or playerId < 0 or playerId > 1024 then
        NotifyPlayer(source, 'FEHLER', 'Ungültige Spieler-ID.', 'error')
        return
    end

    if playerId == 0 then
        pingThreads[source] = nil
        activePings[source] = nil

        for pid in pairs(activePlayers) do
            TriggerClientEvent('homeland:removePingBlip', pid)
        end
        TriggerClientEvent('homeland:removePingBlip', source)

        NotifyPlayer(source, 'PING RESET', 'Spieler-Tracking wurde zurückgesetzt.', 'info')
        return
    end

    local targetPed = GetPlayerPed(playerId)
    if not DoesEntityExist(targetPed) then
        NotifyPlayer(source, 'FEHLER', 'Spieler nicht gefunden.', 'error')
        TriggerClientEvent('homeland:stopClientPing', source)
        return
    end

    if activePings[source] == playerId and pingThreads[source] then
        return
    end

    activePings[source] = playerId

    if pingThreads[source] then
        pingThreads[source] = nil
        Wait(50)
    end

    NotifyPlayer(source, 'PING AKTIV', 'Spieler wird nun getrackt.', 'success')

    pingThreads[source] = true
    CreateThread(function()
        while pingThreads[source] and activePings[source] == playerId do
            local ped = GetPlayerPed(playerId)

            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)

                if operationState ~= "INACTIVE" then
                    for activePlayerId in pairs(activePlayers) do
                        TriggerClientEvent('homeland:showPingBlip', activePlayerId, coords)
                    end
                end

                TriggerClientEvent('homeland:showPingBlip', source, coords)
            else
                pingThreads[source] = nil
                activePings[source] = nil

                if operationState ~= "INACTIVE" then
                    for activePlayerId in pairs(activePlayers) do
                        TriggerClientEvent('homeland:removePingBlip', activePlayerId)
                    end
                end
                TriggerClientEvent('homeland:removePingBlip', source)

                NotifyPlayer(source, 'PING BEENDET', 'Ziel ist offline gegangen.', 'warning')
                TriggerClientEvent('homeland:stopClientPing', source)
                break
            end

            Wait(2000)
        end
    end)
end)

-----------------------------------------------------------------------
-- Streamer Mode (pro Spieler, clientseitig gespeichert — Server kennt nur Flag fürs Logging)
-----------------------------------------------------------------------
RegisterNetEvent('homeland:setStreamer', function(enabled)
    local source = source
    if not IsAuthorized(source) then return end
    streamerPlayers[source] = enabled and true or nil
end)

-----------------------------------------------------------------------
-- EMP Field (Leader toggle — Kraftfeld folgt Leader-Positionen)
-----------------------------------------------------------------------
local function BroadcastEmpState()
    if not empActive then
        TriggerClientEvent('homeland:empUpdate', -1, {
            active = false,
            leaders = {},
            homelandNetIds = spawnedVehicleNetIds
        })
        return
    end

    local leaders = {}
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        if IsLeader(xPlayer.source) then
            local ped = GetPlayerPed(xPlayer.source)
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                leaders[#leaders + 1] = { x = coords.x, y = coords.y, z = coords.z }
            end
        end
    end

    TriggerClientEvent('homeland:empUpdate', -1, {
        active = true,
        leaders = leaders,
        homelandNetIds = spawnedVehicleNetIds
    })
end

local function StartEmpThread()
    if empThreadRunning then return end
    empThreadRunning = true

    CreateThread(function()
        while empActive do
            BroadcastEmpState()
            Wait(Config.Emp.updateMs)
        end
        -- final off-state
        BroadcastEmpState()
        empThreadRunning = false
    end)
end

RegisterNetEvent('homeland:toggleEmp', function()
    local source = source
    if not IsLeader(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Nur Leader können das EMP-Feld schalten.', 'error')
        return
    end

    empActive = not empActive
    TriggerClientEvent('homeland:empStateChanged', -1, empActive)

    if empActive then
        StartEmpThread()
        NotifyAuthorized('HOMELAND SECURITY', 'EMP-Feld aktiviert.', 'warning')
    else
        NotifyAuthorized('HOMELAND SECURITY', 'EMP-Feld deaktiviert.', 'success')
    end
end)

RegisterNetEvent('homeland:stopPingPlayer', function()
    local source = source

    if not IsAuthorized(source) then return end

    pingThreads[source] = nil
    activePings[source] = nil

    for playerId in pairs(activePlayers) do
        TriggerClientEvent('homeland:removePingBlip', playerId)
    end
    TriggerClientEvent('homeland:removePingBlip', source)

    NotifyPlayer(source, 'PING GESTOPPT', 'Spieler-Tracking wurde beendet.', 'info')
end)

-----------------------------------------------------------------------
-- Broadcast message
-----------------------------------------------------------------------
RegisterNetEvent('homeland:broadcastMessage', function(message)
    local source = source

    if not IsAuthorized(source) then
        NotifyPlayer(source, 'ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return
    end

    if not message or type(message) ~= 'string' then
        NotifyPlayer(source, 'FEHLER', 'Ungültige Nachricht.', 'error')
        return
    end

    message = string.sub(message:gsub("^%s*(.-)%s*$", "%1"), 1, 200)

    if message == '' then
        NotifyPlayer(source, 'FEHLER', 'Nachricht darf nicht leer sein.', 'error')
        return
    end

    local senderName = GetPlayerName(source)
    local authorized = GetAuthorizedPlayers()
    local recipientCount = 0

    for i = 1, #authorized do
        local recipientId = authorized[i]

        TriggerClientEvent('homeland:playPhoneSound', recipientId)

        Citizen.SetTimeout(50, function()
            TriggerClientEvent('homeland:notify', recipientId, {
                title = senderName,
                description = message,
                type = 'inform',
                duration = 12000,
                position = 'top',
                style = {
                    backgroundColor = '#1a1a1a',
                    color = '#00ff41',
                    minWidth = '300px',
                    maxWidth = '450px',
                    ['.description'] = {
                        color = '#ffffff',
                        fontSize = '14px',
                        lineHeight = '1.6',
                        whiteSpace = 'normal',
                        wordWrap = 'break-word',
                        overflowWrap = 'anywhere',
                        display = 'block',
                        maxHeight = 'none'
                    }
                }
            })
        end)

        recipientCount = recipientCount + 1
    end

    NotifyPlayer(source, 'BROADCAST GESENDET', 'Nachricht an ' .. recipientCount .. ' Empfänger gesendet.', 'success')
end)
