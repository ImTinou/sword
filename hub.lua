-- TinouHub v1.1 — Universal game hub
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ImTinou/sword/main/hub.lua"))()

local SCRIPTS = {
    [82432929049078] = {
        name = "Sword Factory X BETA",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/enchant_picker.lua",
    },
    [135887679143452] = {
        name = "Excuse Me Sir",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/excuse_me_sir.lua",
    },
    [79268393072444] = {
        name = "Sell Lemons",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/sell_lemons.lua",
    },
    [76911729991355] = {
        name = "Noob Incremental",
        url  = "https://raw.githubusercontent.com/ImTinou/sword/main/noob_incremental.lua",
    },
}

local placeId = game.PlaceId
local entry   = SCRIPTS[placeId]

if entry then
    local ok, err = pcall(function()
        -- cache-buster : évite que raw.githubusercontent serve une vieille version (CDN ~5min)
        local sep = entry.url:find("?") and "&" or "?"
        local url = entry.url .. sep .. "_=" .. tostring(os.time()) .. tostring(math.random(1, 1e6))
        loadstring(game:HttpGet(url, true))()
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
