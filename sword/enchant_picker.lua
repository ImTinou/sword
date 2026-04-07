local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player       = game:GetService("Players").LocalPlayer
local remote       = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
local remoteFunc   = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
local TweenService = game:GetService("TweenService")

local VERSION     = "0.1.4"
local SCAN_RATE   = 0.5
local MATCH_ALL   = true
local scanning    = false
local AUTO_BANK   = true
local AUTO_SELL   = false
local WEBHOOK_URL = ""
-- URL raw du Gist GitHub (ex: https://gist.githubusercontent.com/user/GIST_ID/raw/sword_control.json)
-- Laisser vide pour desactiver le controle Discord
local CONTROL_URL = ""

local LOG_WEBHOOK = ""  -- ton webhook de log Discord (optionnel)
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
            auto_bank    = AUTO_BANK,
            auto_sell    = AUTO_SELL,
            match_all    = MATCH_ALL,
            scan_rate    = SCAN_RATE,
            webhook      = WEBHOOK_URL,
            control_url  = CONTROL_URL,
            anti_afk     = ANTI_AFK,
            profiles     = profiles,
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
        if data.anti_afk     ~= nil then ANTI_AFK    = data.anti_afk     end
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
task.spawn(function()
    while true do
        task.wait(60)
        if ANTI_AFK then
            VirtualUser:Button2Down(workspace.CurrentCamera.ViewportSize / 2, workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(workspace.CurrentCamera.ViewportSize / 2, workspace.CurrentCamera.CFrame)
        end
    end
end)

-- Discord remote control (poll Gist toutes les 5s)
-- Le Gist contient un objet par joueur: { "Username": { id, scanning, ... } }
local lastCmdId = -1
task.spawn(function()
    while true do
        task.wait(5)
        if CONTROL_URL == "" then continue end
        pcall(function()
            -- Cache-bust avec timestamp pour eviter le cache GitHub CDN
            local url = CONTROL_URL .. "?t=" .. tostring(os.time())
            local res = request({ Url = url, Method = "GET",
                Headers = { ["Cache-Control"] = "no-cache" } })
            if not res or res.StatusCode ~= 200 then return end
            local root = HS:JSONDecode(res.Body)
            -- Lire uniquement l'entree de ce joueur
            local data = root[player.Name]
            if type(data) ~= "table" then return end
            if type(data.id) ~= "number" or data.id == lastCmdId then return end
            lastCmdId = data.id

            -- Scanner
            if data.scanning ~= nil then
                if data.scanning and not scanning then
                    startScan(nil)
                elseif not data.scanning and scanning then
                    scanning = false
                end
            end

            -- Farm
            if data.farming ~= nil then
                if not data.farming then
                    farming = false
                end
            end

            -- Ascender
            if data.ascending ~= nil then
                if not data.ascending then
                    ascending = false
                end
            end

            -- Options
            if data.auto_bank ~= nil then AUTO_BANK = data.auto_bank end
            if data.auto_sell ~= nil then AUTO_SELL = data.auto_sell end
            if data.scan_rate ~= nil and data.scan_rate > 0 then SCAN_RATE = data.scan_rate end

            -- Profiles
            if type(data.profiles) == "table" then
                for i = 1, 3 do
                    if data.profiles[i] then
                        profiles[i].active = data.profiles[i].active
                        if type(data.profiles[i].slots) == "table" then
                            profiles[i].slots = data.profiles[i].slots
                        end
                    end
                end
            end

            saveConfig()
        end)
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

local enchantList = {
    "Any","Fortune","Sharpness","Protection","Haste","Swiftness",
    "Critical","Resistance","Healing","Looting","Attraction",
    "Stealth","Ancient","Desperation","Insight","Thorns","Knockback"
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

local totalPicked  = 0
local ascending     = false
local ascAttempts   = 0
local targetQuality = "Miraculous"
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
    Common=9807270, Uncommon=5763719, Rare=3447003,
    Epic=10181046, Legendary=16766720, Mythical=15158332,
    Unique=1752220, Godly=16711680, Celestial=16777215,
}

local qualityOrder = {
    "Common","Uncommon","Rare","Epic","Legendary",
    "Mythical","Unique","Godly","Celestial",
    "Astounding","Fabulous","Glorious","Miraculous",
    "Staggering","Supernatural","Unbeatable",
}
local function qualityRank(text)
    if not text then return 0 end
    for i = #qualityOrder, 1, -1 do
        if text:find(qualityOrder[i]) then return i end
    end
    return 0
end

local function sendWebhook(sword, enchants, info)
    if WEBHOOK_URL == "" then return end
    info = info or getSwordInfo(sword)
    pcall(function()
        local color = 6559471
        for rarity, col in pairs(rarityColors) do
            if info.rarity and info.rarity:find(rarity) then color = col break end
        end

        local fields = {}
        for idx, e in ipairs(enchants) do
            table.insert(fields, { name = "Enchant "..idx, value = e, inline = true })
        end
        table.insert(fields, { name = "Level",   value = info.level   or "?", inline = true })
        table.insert(fields, { name = "Rarity",  value = info.rarity  or "?", inline = true })
        table.insert(fields, { name = "Worth",   value = info.worth   or "?", inline = true })
        table.insert(fields, { name = "Price",   value = info.selling or "?", inline = true })
        table.insert(fields, { name = "Server",  value = tostring(#game:GetService("Players"):GetPlayers()).." players", inline = true })

        request({
            Url    = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode({
                username   = "TinouHUB",
                avatar_url = "https://tr.rbxcdn.com/180DAY-placeholder/150/150/AvatarHeadshot/Webp/noFilter",
                embeds = {{
                    title       = "Sword Sniped — "..(info.name or "Unknown"),
                    description = "**"..player.Name.."** picked up a matching sword!",
                    color       = color,
                    fields      = fields,
                    footer      = { text = "TinouHub v"..VERSION.." | Sword Factory X" },
                    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
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
    return workspace.Swords:FindFirstChild(children[1].Name)
end

local function sendAscenderWebhook(sword, quality, attempts)
    if WEBHOOK_URL == "" then return end
    local info    = getSwordInfo(sword)
    local enchants = getSwordEnchants(sword)
    pcall(function()
        local color = 16766720
        for rarity, col in pairs(rarityColors) do
            if quality and quality:find(rarity) then color = col break end
        end
        local fields = {}
        for idx, e in ipairs(enchants) do
            table.insert(fields, { name = "Enchant "..idx, value = e, inline = true })
        end
        table.insert(fields, { name = "Quality",  value = quality or "?",     inline = true })
        table.insert(fields, { name = "Attempts", value = tostring(attempts), inline = true })
        table.insert(fields, { name = "Level",    value = info.level or "?",  inline = true })
        table.insert(fields, { name = "Worth",    value = info.worth or "?",  inline = true })
        request({
            Url    = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HS:JSONEncode({
                username   = "TinouHUB",
                avatar_url = "https://tr.rbxcdn.com/180DAY-placeholder/150/150/AvatarHeadshot/Webp/noFilter",
                embeds = {{
                    title       = "Ascender — Target Reached!",
                    description = "**"..player.Name.."** reached **"..quality.."** in "..attempts.." tries!",
                    color       = color,
                    fields      = fields,
                    footer      = { text = "TinouHub v"..VERSION.." | Sword Factory X" },
                    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }}
            })
        })
    end)
end

local childAddedConn = nil

local function handleSword(sword, lbl)
    if not scanning then return end
    if not isProtected(sword) and swordMatches(sword) then
        local enchants = getSwordEnchants(sword)
        local info     = getSwordInfo(sword)
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
        pcall(function() lbl:Set("Sniped! Total: "..totalPicked) end)
        Rayfield:Notify({Title="Sword Found!", Content=table.concat(enchants,", "), Duration=3})
        sendWebhook(sword, enchants, info)
    end
end

local function startScan(lbl)
    scanning = true

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
Tab:CreateToggle({ Name="Auto-Bank matched swords", CurrentValue=AUTO_BANK, Flag="AutoBank", Callback=function(v) AUTO_BANK=v saveConfig() end })
Tab:CreateToggle({ Name="Auto-Sell after bank",      CurrentValue=AUTO_SELL, Flag="AutoSell", Callback=function(v) AUTO_SELL=v saveConfig() end })
Tab:CreateToggle({ Name="Match ALL enchants",        CurrentValue=MATCH_ALL, Flag="MatchAll", Callback=function(v) MATCH_ALL=v saveConfig() end })
Tab:CreateSlider({ Name="Scan Rate (s)", Range={0.1,3}, Increment=0.1, CurrentValue=SCAN_RATE, Flag="ScanRate", Callback=function(v) SCAN_RATE=v saveConfig() end })

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
local statusLbl = Tab:CreateLabel("Status: Ready")
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
    ProfTab:CreateSection("Profile "..i)
    ProfTab:CreateToggle({ Name="Enable Profile "..i, CurrentValue=prof.active, Flag="P"..i.."On",
        Callback=function(v) profiles[i].active=v saveConfig() end })
    ProfTab:CreateDropdown({ Name="Enchant 1", Options=enchantList, CurrentOption=prof.slots[1], MultipleOptions=false, Flag="P"..i.."S1",
        Callback=function(o) profiles[i].slots[1]=getOpt(o) saveConfig() end })
    ProfTab:CreateDropdown({ Name="Enchant 2", Options=enchantList, CurrentOption=prof.slots[2], MultipleOptions=false, Flag="P"..i.."S2",
        Callback=function(o) profiles[i].slots[2]=getOpt(o) saveConfig() end })
    ProfTab:CreateDropdown({ Name="Enchant 3", Options=enchantList, CurrentOption=prof.slots[3], MultipleOptions=false, Flag="P"..i.."S3",
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


SettingsTab:CreateSection("Discord Control")
local function controlStatus() return CONTROL_URL=="" and "Non configure" or "..."..(CONTROL_URL:sub(-24)) end
local controlLbl = SettingsTab:CreateLabel(controlStatus())
SettingsTab:CreateInput({ Name="Gist URL (Control)", PlaceholderText="https://gist.githubusercontent.com/...", RemoveTextAfterFocusLost=false, Flag="ControlURL",
    Callback=function(val)
        if val=="" then return end
        CONTROL_URL=val saveConfig()
        pcall(function() controlLbl:Set(controlStatus()) end)
        Rayfield:Notify({Title="Discord Control", Content="URL sauvegardee!", Duration=2})
    end })

SettingsTab:CreateSection("Info")
SettingsTab:CreateLabel("TinouHub v"..VERSION.." | Sword Factory X")
SettingsTab:CreateLabel("github.com/ImTinou/sword")

-- Tab Farm
local FarmTab = Window:CreateTab("Farm", "zap")

local zoneList = {
    "Beginner's Trials","Crystal Caverns","Snowy Fields",
    "Mystical Forest","Stranded Island","Heavenly Gates",
    "Intraplanetarium","Volcanic Isles","Ancient Mineshaft"
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
local farming         = false
local MIN_HP_PCT      = 0.35
local FARM_POS_MODE   = "Below"
local FARM_Y_OFFSET   = 5
local farmSafePos     = nil
local FARM_REACH      = 10
local VU              = game:GetService("VirtualUser")

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
    for _, npc in pairs(workspace.NPCs:GetChildren()) do
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
    Options         = {"Below","Above","Behind"},
    CurrentOption   = "Below",
    MultipleOptions = false,
    Flag            = "FarmPosMode",
    Callback        = function(opt)
        FARM_POS_MODE = type(opt) == "table" and opt[1] or opt
    end,
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


FarmTab:CreateSection("Control")

local farmStatusLbl = FarmTab:CreateLabel("Farm: Idle")

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
        task.spawn(function()
            local killed = 0
            while farming do
                local npcs = getNpcsInZone()
                if #npcs == 0 then
                    pcall(function() farmStatusLbl:Set("No mobs found...") end)
                    task.wait(2)
                    continue
                end
                for _, npc in ipairs(npcs) do
                    if not farming then break end
                    local hum = npc:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then continue end
                    -- TP once under the mob
                    goUnderNpc(npc)
                    while hum.Health > 0 and farming do
                        if getHpPct() < MIN_HP_PCT then
                            retreatAndHeal(farmStatusLbl)
                            if not farming then break end
                            goUnderNpc(npc)
                        end
                        -- Reposition only if knocked far away
                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                        if hrp and npcRoot and (hrp.Position - npcRoot.Position).Magnitude > FARM_Y_OFFSET + 10 then
                            goUnderNpc(npc)
                        end
                        activateTool()
                        task.wait(0.15)
                    end
                    if hum.Health <= 0 then
                        killed = killed + 1
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
AscTab:CreateDropdown({ Name="Stop at", Options=qualityOrder, CurrentOption="Miraculous", MultipleOptions=false, Flag="AscTarget",
    Callback=function(o) targetQuality=type(o)=="table" and o[1] or o end })

AscTab:CreateSection("Control")
AscTab:CreateButton({ Name="Start Auto-Ascend", Callback=function()
    if ascending then return end
    if not getAscenderSword() then Rayfield:Notify({Title="Ascender", Content="No sword in Ascender!", Duration=3}) return end
    ascending=true ascAttempts=0
    task.spawn(function()
        while ascending do
            local s=getAscenderSword()
            if not s then ascending=false pcall(function() ascStatusLbl:Set("Sword not found") end) break end
            local q=stripRichText(s.Main.Gui.ItemInfo.RarityQuality.Text)
            if qualityRank(q)>=qualityRank(targetQuality) then
                ascending=false
                pcall(function() ascStatusLbl:Set("Done! "..q.." | "..ascAttempts.." tries") end)
                Rayfield:Notify({Title="Ascender", Content=q.." in "..ascAttempts.." tries!", Duration=6})
                sendAscenderWebhook(s,q,ascAttempts) break
            end
            pcall(function() remote:FireServer("Set Ascender Mode", ascMode) end)
            ascAttempts=ascAttempts+1
            pcall(function() ascStatusLbl:Set(q.." | "..ascAttempts.." tries") end)
            task.wait(0.12)
        end
        ascending=false
    end)
    Rayfield:Notify({Title="Ascender", Content="Started!", Duration=2})
end })
AscTab:CreateButton({ Name="Stop", Callback=function() ascending=false Rayfield:Notify({Title="Ascender", Content="Stopped.", Duration=2}) end })

-- ===================== AUTO-UPGRADE =====================
local autoUpgrading = false
local upgEnabled = { Conveyor=false, Appraiser=false, Polisher=false, Upgrader=false, Molder=false, Classifier=false, Enchanter=false }

local UpgTab = Window:CreateTab("Upgrade", "tool")

UpgTab:CreateSection("Machines")
for _, machine in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter"}) do
    local m = machine
    UpgTab:CreateToggle({ Name=m, CurrentValue=false, Flag="Upg"..m, Callback=function(v) upgEnabled[m]=v end })
end

UpgTab:CreateSection("Control")
local upgStatusLbl = UpgTab:CreateLabel("Auto-Upgrade: Idle")
UpgTab:CreateButton({ Name="Upgrade Now", Callback=function()
    for _, m in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter"}) do
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
            for _, m in ipairs({"Conveyor","Appraiser","Polisher","Upgrader","Molder","Classifier","Enchanter"}) do
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
