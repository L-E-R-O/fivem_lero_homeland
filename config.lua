Config = {}

-- Berechtigung: Liste der Identifier (steam/license/discord) die Zugriff haben
-- Beispiel: 'steam:110000xxxxxxxx', 'license:xxxxxx', 'discord:xxxxxx'
Config.AuthorizedIdentifiers = {
    'license:eb361c18eb6b32947edfe8c238abdd014f353e10',    -- LERO
    'license:4a4d46d5e4fa83ef4296c1eebcf13187c7e5c8e8',    -- ANDI
    'license:c10d6c5aed4683fe85c2fac5b0b7f42bd9f54963',    -- GIANLUCA
    'license:71f7a5833ba89b2c60b1b036d575f9c190ca0e56',    -- NIGHT
}

-- Alarm Sound Optionen
--[[
Config.AlarmSound = {
    name = "CHECKPOINT_PERFECT",  -- Soundname
    set = "HUD_MINI_GAME_SOUNDSET", -- Soundset
    repeats = 3,                    -- Anzahl der Wiederholungen
    delay = 1000                     -- Verzögerung zwischen Wiederholungen in ms
}
]]--

Config.AlarmSound = {
    name = "Plane_Alarm_Loop",  -- Soundname
    set = "DLC_GR_WVM_Oppressor2_Sounds", -- Soundset
    repeats = 1,                    -- Anzahl der Wiederholungen
    delay = 0,                    -- Verzögerung zwischen Wiederholungen in ms
    durationMs = 10000             -- Dauer bis zum Abschalten in ms
}

-- FETER ALARM SOUND LAUT!
--[[
-- Option 2:
Config.AlarmSound = {
    name = "Air_Defences_Activated",
    set = "DLC_sum20_Business_Battle_AC_Sounds",
    repeats = 1,
    delay = 0
}
]]



-- Broadcast Notification Sound (dezenter Piep-Ton)
Config.BroadcastSound = {
    name = "Menu_Accept",
    set = "Phone_SoundSet_Default",
    volume = 0.4
}


-- Teleport Location (Homeland Base)
Config.TeleportLocation = {
    x = -2007.626342,
    y =  3117.283448,
    z =    32.801514,
    heading =  8.503936
}

-- Fahrzeuge die gespawnt werden sollen
Config.Vehicles = {
    { model = 'nightshark', pos = {x = -1986.712036, y = 3117.652832, z = 32.801514, heading = 240.0} },
    { model = 'nightshark', pos = {x = -1993.134034, y = 3121.397706, z = 32.801514, heading = 240.0} },
    
    { model = 'insurgent2', pos = {x = -2000.070312, y = 3125.366944, z = 32.801514, heading = 240.0} },
    { model = 'insurgent2', pos = {x = -2008.061524, y = 3129.876954, z = 32.801514, heading = 240.0} },
    { model = 'insurgent2', pos = {x = -2015.353882, y = 3134.281250, z = 32.801514, heading = 240.0} },

    { model = 'akula',      pos = {x = -2030.030762, y = 3142.720948, z = 32.801514, heading = 240.0} },
}

-- Homeland Waffen
Config.HomelandWeapons = {
    {
        weapon = 'WEAPON_PUMPSHOTGUN_MK2',
        ammo = 500
    },
    {
        weapon = 'WEAPON_CARBINERIFLE_MK2',
        ammo = 500
    }
}

-- Homeland Outfit
Config.HomelandOutfit = {
    male = {
        ['tshirt_1'] = 21, ['tshirt_2'] = 0,
        ['torso_1'] = 61, ['torso_2'] = 3,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 176,
        ['pants_1'] = 9, ['pants_2'] = 7,
        ['shoes_1'] = 60, ['shoes_2'] = 0,
        ['helmet_1'] = -1, ['helmet_2'] = -1,
        ['chain_1'] = -1, ['chain_2'] = -1,
        ['ears_1'] = -1, ['ears_2'] = -1,
        ['glasses_1'] = -1, ['glasses_2'] = -1,
        ['bproof_1'] = 16, ['bproof_2'] = 2,
        ['mask_1'] = 28, ['mask_2'] = 0,
        ['bags_1'] = 0, ['bags_2'] = 0
    },
    female = {
        ['tshirt_1'] = 14, ['tshirt_2'] = 0,
        ['torso_1'] = 293, ['torso_2'] = 0,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 14,
        ['pants_1'] = 90, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 125, ['helmet_2'] = 0,
        ['chain_1'] = 0, ['chain_2'] = 0,
        ['ears_1'] = -1, ['ears_2'] = 0,
        ['glasses_1'] = -1, ['glasses_2'] = -1,
        ['bproof_1'] = 13, ['bproof_2'] = 0,
        ['mask_1'] = 52, ['mask_2'] = 0,
        ['bags_1'] = 0, ['bags_2'] = 0
    }
}

-- Homeland Gewitter-Wetter
Config.HomelandWeather = 'THUNDER' -- Wettertyp für Homeland-Operationen
