local homelandActive = false
local spawnedVehicles = {}
local activePlayers = {}
local currentWeather = "CLEAR"
local activePings = {}
local pingThreads = {}

-- Cache authorized players to reduce lookups
local authorizedPlayersCache = {}
local cacheUpdateTime = 0
local CACHE_LIFETIME = 30000 -- 30 seconds

-- Check if player is authorized (with caching)
local function IsAuthorized(source)
    local currentTime = GetGameTimer()
    
    -- Update cache if expired
    if currentTime - cacheUpdateTime > CACHE_LIFETIME then
        authorizedPlayersCache = {}
        cacheUpdateTime = currentTime
    end
    
    -- Check cache first
    if authorizedPlayersCache[source] ~= nil then
        return authorizedPlayersCache[source]
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        authorizedPlayersCache[source] = false
        return false 
    end
    
    local identifiers = GetPlayerIdentifiers(source)
    
    for _, configId in ipairs(Config.AuthorizedIdentifiers) do
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

-- Get all authorized players (optimized)
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
    
    TriggerClientEvent('ox_lib:notify', source, {
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

-- Spawn vehicles (optimized)
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
        end
    end
    
    print('[HOMELAND] Spawned ' .. #spawnedVehicles .. '/' .. vehicleCount .. ' vehicles')
end

-- Delete vehicles (optimized)
local function DeleteVehicles()
    for i = 1, #spawnedVehicles do
        local vehicle = spawnedVehicles[i]
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    
    spawnedVehicles = {}
end

-- Start Homeland (optimized)
RegisterNetEvent('homeland:start', function()
    local source = source
    
    if not IsAuthorized(source) then
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung für diese Aktion.', 'error')
        return
    end
    
    if homelandActive then
        NotifyPlayer(source, '❌ FEHLER', 'Homeland-Operation bereits aktiv!', 'error')
        return
    end
    
    homelandActive = true
    SpawnVehicles()
    
    NotifyAuthorized("✅ HOMELAND SECURITY", "Operation wurde erfolgreich gestartet.", "success", 15000)
    
    -- Play alarm sound for all authorized players
    local authorized = GetAuthorizedPlayers()
    for i = 1, #authorized do
        TriggerClientEvent('homeland:playAlarm', authorized[i])
    end
    
    TriggerClientEvent('homeland:syncStatus', -1, true)
    
    print('[HOMELAND] Started by ' .. GetPlayerName(source))
    
    -- Blip update thread
    CreateThread(function()
        while homelandActive do
            local authorized = GetAuthorizedPlayers()
            local positions = {}
            
            for playerId in pairs(activePlayers) do
                local ped = GetPlayerPed(playerId)
                if DoesEntityExist(ped) then
                    positions[#positions + 1] = {
                        id = playerId,
                        coords = GetEntityCoords(ped)
                    }
                end
            end
            
            for i = 1, #authorized do
                TriggerClientEvent('homeland:updateBlips', authorized[i], positions)
            end
            
            Wait(2000)
        end
    end)
end)

-- Stop Homeland (optimized)
RegisterNetEvent('homeland:stop', function()
    local source = source
    
    if not IsAuthorized(source) then
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung für diese Aktion.', 'error')
        return
    end
    
    if not homelandActive then
        NotifyPlayer(source, '❌ FEHLER', 'Keine aktive Operation.', 'error')
        return
    end
    
    homelandActive = false
    DeleteVehicles()
    
    -- Force return all active players
    local returnedCount = 0
    for playerId in pairs(activePlayers) do
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '☠️ NOTFALL-EVAKUIERUNG',
            description = 'Operation abgebrochen! Sofortige Rückkehr eingeleitet.',
            type = 'error',
            duration = 5000
        })
        TriggerClientEvent('homeland:forceTeleportBack', playerId)
        returnedCount = returnedCount + 1
    end
    
    -- Cleanup
    activePlayers = {}
    pingThreads = {}
    activePings = {}
    
    NotifyAuthorized("✅ HOMELAND SECURITY", "Operation wurde erfolgreich beendet.", "success")
    TriggerClientEvent('homeland:syncStatus', -1, false)
    
    local authorized = GetAuthorizedPlayers()
    for i = 1, #authorized do
        TriggerClientEvent('homeland:clearBlips', authorized[i])
        TriggerClientEvent('homeland:removePingBlip', authorized[i])
    end
    
    print('[HOMELAND] Stopped - Returned ' .. returnedCount .. ' players')
end)

-- Teleport to Homeland
RegisterNetEvent('homeland:teleportTo', function()
    local source = source
    
    if not IsAuthorized(source) then
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return
    end
    
    if not homelandActive then
        NotifyPlayer(source, '❌ FEHLER', 'Keine aktive Operation. Starte erst das System.', 'error')
        return
    end
    
    if activePlayers[source] then
        NotifyPlayer(source, '❌ FEHLER', 'Du bist bereits im Einsatz! Kehre erst zurück.', 'error')
        return
    end
    
    activePlayers[source] = true
    TriggerClientEvent('homeland:teleportTo', source)
end)

-- Teleport back
RegisterNetEvent('homeland:teleportBack', function()
    local source = source
    
    if not IsAuthorized(source) then
        return
    end
    
    activePlayers[source] = nil
    TriggerClientEvent('homeland:teleportBack', source)
end)

-- Get current status
ESX.RegisterServerCallback('homeland:getStatus', function(source, cb)
    cb(homelandActive)
end)

-- Check authorization callback
ESX.RegisterServerCallback('homeland:checkAuth', function(source, cb)
    cb(IsAuthorized(source))
end)

-- Get player loadout (ox_inventory)
ESX.RegisterServerCallback('homeland:getLoadout', function(source, cb)
    local inv = exports.ox_inventory:GetInventory(source)
    local weapons = {}
    
    if inv and inv.items then
        for slot, item in pairs(inv.items) do
            if item and item.name and string.match(item.name, "^WEAPON_") then
                table.insert(weapons, {
                    name = item.name,
                    slot = slot,
                    metadata = item.metadata
                })
            end
        end
    end
    
    cb(weapons)
end)

-- Remove all weapons (ox_inventory)
RegisterNetEvent('homeland:removeAllWeapons', function()
    local source = source
    local inv = exports.ox_inventory:GetInventory(source)
    
    if inv and inv.items then
        for slot, item in pairs(inv.items) do
            if item and item.name and string.match(item.name, "^WEAPON_") then
                exports.ox_inventory:RemoveItem(source, item.name, item.count, item.metadata, slot)
            end
        end
    end
end)

-- Give Homeland weapons (ox_inventory)
RegisterNetEvent('homeland:giveWeapons', function()
    local source = source
    
    if not IsAuthorized(source) then
        return
    end
    
    print('[HOMELAND] Giving weapons to player ' .. source)
    
    for _, weaponData in ipairs(Config.HomelandWeapons) do
        local metadata = {
            ammo = weaponData.ammo,
            durability = 100,
            registered = true,
            serial = 'HOMELAND'
        }
        
        local success = exports.ox_inventory:AddItem(source, weaponData.weapon, 1, metadata)
        
        if success then
            print('[HOMELAND] Successfully gave ' .. weaponData.weapon .. ' to player ' .. source)
        else
            print('[HOMELAND] Failed to give ' .. weaponData.weapon .. ' to player ' .. source)
        end
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '⚠️ AUSRÜSTUNG',
        description = 'Taktische Bewaffnung übernommen.',
        type = 'success'
    })
end)

-- Remove Homeland weapons specifically
RegisterNetEvent('homeland:removeHomelandWeapons', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        print('[HOMELAND] ERROR: Player not found')
        return
    end
    
    print('[HOMELAND] ========== REMOVING HOMELAND WEAPONS ==========')
    print('[HOMELAND] Player: ' .. source .. ' (' .. xPlayer.identifier .. ')')
    
    local removedCount = 0
    local inv = exports.ox_inventory:GetInventory(source)
    
    if inv and inv.items then
        print('[HOMELAND] Scanning inventory for HOMELAND weapons...')
        
        local itemsToRemove = {}
        for slot, item in pairs(inv.items) do
            if item and item.metadata and item.metadata.serial == 'HOMELAND' then
                print('[HOMELAND] Found: ' .. item.name .. ' in slot ' .. slot .. ' with serial HOMELAND')
                table.insert(itemsToRemove, {
                    name = item.name,
                    slot = slot,
                    count = item.count or 1
                })
            end
        end
        
        for _, itemData in ipairs(itemsToRemove) do
            print('[HOMELAND] Removing ' .. itemData.name .. ' from slot ' .. itemData.slot)
            
            local success = exports.ox_inventory:RemoveItem(source, itemData.name, itemData.count, nil, itemData.slot)
            
            if success then
                removedCount = removedCount + 1
                print('[HOMELAND] Successfully removed ' .. itemData.name)
            else
                print('[HOMELAND] Failed to remove ' .. itemData.name .. ' via API, trying SQL...')
            end
        end
    end
    
    if removedCount == 0 then
        print('[HOMELAND] Attempting SQL removal...')
        
        exports.oxmysql:execute([[
            DELETE FROM ox_inventory 
            WHERE owner = ? 
            AND JSON_EXTRACT(data, '$.metadata.serial') = 'HOMELAND'
        ]], {
            xPlayer.identifier
        }, function(result)
            local affectedRows = type(result) == 'number' and result or 0
            
            print('[HOMELAND] SQL: Deleted ' .. affectedRows .. ' items from database')
            
            if affectedRows > 0 then
                removedCount = affectedRows
                
                Citizen.SetTimeout(500, function()
                    exports.ox_inventory:ClearInventory(source)
                    
                    Citizen.SetTimeout(200, function()
                        TriggerClientEvent('ox_inventory:reload', source)
                        print('[HOMELAND] Inventory reloaded from database')
                    end)
                end)
            end
        end)
        
        Citizen.Wait(1000)
    end
    
    print('[HOMELAND] ========== REMOVAL COMPLETE ==========')
    print('[HOMELAND] Total removed: ' .. removedCount)
    
    if removedCount > 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '☠️ ENTWAFFNUNG',
            description = removedCount .. ' Waffe(n) konfisziert.',
            type = 'warning'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'HOMELAND',
            description = 'Keine taktische Ausrüstung gefunden.',
            type = 'info'
        })
    end
end)

-- Restore weapons (ox_inventory)
RegisterNetEvent('homeland:restoreWeapons', function(loadout)
    local source = source
    
    if not loadout or #loadout == 0 then
        return
    end
    
    for _, weapon in ipairs(loadout) do
        exports.ox_inventory:AddItem(source, weapon.name, 1, weapon.metadata)
    end
end)

-- Set Homeland Weather to Thunder
RegisterNetEvent('homeland:setWeather', function()
    local source = source
    
    if not IsAuthorized(source) then
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung für diese Aktion.', 'error')
        return
    end
    
    currentWeather = "THUNDER"
    TriggerClientEvent('homeland:applyWeather', -1, Config.HomelandWeather)
    
    print('[HOMELAND] Weather changed to THUNDER by ' .. GetPlayerName(source))
    
    NotifyPlayer(source, '✅ WETTERWARNUNG', 'Wetter wurde erfolgreich auf Gewitter gesetzt.', 'success')
end)

-- Restore Weather to Clear
RegisterNetEvent('homeland:restoreWeather', function()
    local source = source
    
    if not IsAuthorized(source) then
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung für diese Aktion.', 'error')
        return
    end
    
    currentWeather = "CLEAR"
    TriggerClientEvent('homeland:restoreWeather', -1)
    
    print('[HOMELAND] Weather restored to CLEAR by ' .. GetPlayerName(source))
    
    NotifyPlayer(source, '✅ ENTWARNUNG', 'Wetter wurde erfolgreich auf Klar gesetzt.', 'success')
end)

-- Player returned from Homeland
RegisterNetEvent('homeland:playerReturned', function()
    local source = source
    activePlayers[source] = nil
    print('[HOMELAND] Player ' .. GetPlayerName(source) .. ' returned from HOMELAND')
end)

-- Cleanup on player disconnect
AddEventHandler('playerDropped', function()
    local source = source
    
    activePlayers[source] = nil
    activePings[source] = nil
    pingThreads[source] = nil
    authorizedPlayersCache[source] = nil
end)

-- Clear cache periodically
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        local currentTime = GetGameTimer()
        if currentTime - cacheUpdateTime > CACHE_LIFETIME then
            authorizedPlayersCache = {}
            cacheUpdateTime = currentTime
        end
    end
end)

RegisterNetEvent('homeland:pingPlayer', function(playerId)
    local source = source
    
    if not IsAuthorized(source) then 
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return 
    end
    
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 or playerId > 1024 then 
        NotifyPlayer(source, '❌ FEHLER', 'Ungültige Spieler-ID.', 'error')
        return 
    end
    
    if playerId == 0 then
        pingThreads[source] = nil
        activePings[source] = nil
        
        for playerId in pairs(activePlayers) do
            TriggerClientEvent('homeland:removePingBlip', playerId)
        end
        TriggerClientEvent('homeland:removePingBlip', source)
        
        NotifyPlayer(source, '✅ PING RESET', 'Spieler-Tracking wurde zurückgesetzt.', 'info')
        return
    end
    
    local targetPed = GetPlayerPed(playerId)
    if not DoesEntityExist(targetPed) then
        NotifyPlayer(source, '❌ FEHLER', 'Spieler nicht gefunden.', 'error')
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
    
    NotifyPlayer(source, '✅ PING AKTIV', 'Spieler wird nun getrackt.', 'success')
    
    pingThreads[source] = true
    CreateThread(function()
        while pingThreads[source] and activePings[source] == playerId do
            local ped = GetPlayerPed(playerId)
            
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                
                if homelandActive then
                    for activePlayerId in pairs(activePlayers) do
                        TriggerClientEvent('homeland:showPingBlip', activePlayerId, coords)
                    end
                end
                
                TriggerClientEvent('homeland:showPingBlip', source, coords)
            else
                pingThreads[source] = nil
                activePings[source] = nil
                
                if homelandActive then
                    for activePlayerId in pairs(activePlayers) do
                        TriggerClientEvent('homeland:removePingBlip', activePlayerId)
                    end
                end
                TriggerClientEvent('homeland:removePingBlip', source)
                
                NotifyPlayer(source, '⚠️ PING BEENDET', 'Ziel ist offline gegangen.', 'warning')
                TriggerClientEvent('homeland:stopClientPing', source)
                break
            end
            
            Wait(2000)
        end
    end)
end)

RegisterNetEvent('homeland:stopPingPlayer', function()
    local source = source
    
    pingThreads[source] = nil
    activePings[source] = nil
    
    for playerId in pairs(activePlayers) do
        TriggerClientEvent('homeland:removePingBlip', playerId)
    end
    TriggerClientEvent('homeland:removePingBlip', source)
    
    NotifyPlayer(source, '✅ PING GESTOPPT', 'Spieler-Tracking wurde beendet.', 'info')
end)

-- Broadcast message to all authorized players
RegisterNetEvent('homeland:broadcastMessage', function(message)
    local source = source
    
    if not IsAuthorized(source) then 
        NotifyPlayer(source, '❌ ZUGRIFF VERWEIGERT', 'Du hast keine Berechtigung.', 'error')
        return 
    end
    
    -- Validate message
    if not message or type(message) ~= 'string' then
        NotifyPlayer(source, '❌ FEHLER', 'Ungültige Nachricht.', 'error')
        return
    end
    
    -- Trim and limit message length
    message = string.sub(message:gsub("^%s*(.-)%s*$", "%1"), 1, 200)
    
    if message == '' then
        NotifyPlayer(source, '❌ FEHLER', 'Nachricht darf nicht leer sein.', 'error')
        return
    end
    
    local senderName = GetPlayerName(source)
    
    print('[HOMELAND] Broadcast from ' .. senderName .. ' (' .. source .. '): ' .. message)
    
    -- Send to all authorized players
    local authorized = GetAuthorizedPlayers()
    local recipientCount = 0
    
    for i = 1, #authorized do
        local recipientId = authorized[i]
        
        -- Play notification sound
        TriggerClientEvent('homeland:playBroadcastSound', recipientId)
        
        -- Small delay before showing notification
        Citizen.SetTimeout(50, function()
            TriggerClientEvent('ox_lib:notify', recipientId, {
                title = '📢 HOMELAND BROADCAST',
                description = message,
                type = 'inform',
                duration = 12000,
                position = 'top',
                style = {
                    backgroundColor = '#1a1a1a',
                    color = '#ff6b00',
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
    
    -- Confirm to sender
    NotifyPlayer(source, '✅ BROADCAST GESENDET', 'Nachricht an ' .. recipientCount .. ' Empfänger gesendet.', 'success')
end)
