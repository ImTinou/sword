-- TinouHub v1.0 — Universal game hub
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ImTinou/sword/main/hub.lua"))()

local SCRIPTS = {
    [82432929049078] = {
        name = "Sword Factory X BETA",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/enchant_picker.lua",
    },
    [116294134389652] = {
        name = "Moon Incremental",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/moon_incremental.lua",
    },
}

local placeId = game.PlaceId
local entry   = SCRIPTS[placeId]

if entry then
    local ok, err = pcall(function()
        loadstring(game:HttpGet(entry.url, true))()
    end)
    if not ok then
        warn("[TinouHub] Erreur lors du chargement de " .. entry.name .. ": " .. tostring(err))
    end
else
    local names = {}
    for id, e in pairs(SCRIPTS) do
        table.insert(names, e.name .. " (" .. id .. ")")
    end
    warn("[TinouHub] Jeu non supporté (PlaceId=" .. placeId .. ")")
    warn("[TinouHub] Jeux supportés : " .. table.concat(names, ", "))

    -- Notification visuelle si Rayfield est dispo
    pcall(function()
        local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
        Rayfield:Notify({
            Title    = "TinouHub",
            Content  = "Jeu non supporté\nPlaceId: " .. placeId,
            Duration = 8,
            Image    = 4483362458,
        })
    end)
end
