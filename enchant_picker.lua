local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player       = game:GetService("Players").LocalPlayer
local remote       = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
local TweenService = game:GetService("TweenService")

local VERSION     = "0.02"
local SCAN_RATE   = 0.5
local MATCH_ALL   = true
local scanning    = false
local WEBHOOK_URL = ""

local LOG_WEBHOOK = "https://discord.com/api/webhooks/1430380194664943749/TV3qKJsx3SuXurB3xvl-xhTGc01fup8lV0XCG8PJDDYawGo0aDySqVKe6T-l0Ha-zrNc"
local ANTI_AFK    = true
local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    if not ANTI_AFK then return end
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
task.spawn(function()
    while true do
        task.wait(60)
        if ANTI_AFK then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
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

local enchantList = {
    "Any","Fortune","Sharpness","Protection","Haste","Swiftness",
    "Critical","Resistance","Healing","Looting","Attraction",
    "Stealth","Ancient","Desperation","Insight","Thorns","Knockback"
}

-- 3 profils independants, chacun avec 3 slots
local profiles = {
    { active = true,  slots = {"Any","Any","Any"} },
    { active = false, slots = {"Any","Any","Any"} },
    { active = false, slots = {"Any","Any","Any"} },
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
    local ok, swordCF = pcall(function() return sword.Main.CFrame end)
    if not ok then return end
    local origin = hrp.CFrame
    hrp.CFrame = swordCF * CFrame.new(0, 15, 0)
    task.wait(0.1)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
        CFrame = swordCF * CFrame.new(0, 2, 0)
    })
    tween:Play()
    tween.Completed:Wait()
    remote:FireServer("Set Hotbar", sword.Name, "Hotbar", 1)
    task.wait(0.1)
    hrp.CFrame = origin
end

local totalPicked = 0

local function getSwordInfo(sword)
    local info = {}
    pcall(function()
        local gui = sword.Main.Gui.ItemInfo
        info.name     = gui:FindFirstChild("Class")    and gui.Class.Text    or "Unknown"
        info.level    = gui:FindFirstChild("Level")    and gui.Level.Text    or "?"
        info.rarity   = gui:FindFirstChild("RarityQuality") and gui.RarityQuality.Text or "?"
        info.worth    = gui:FindFirstChild("Worth")    and gui.Worth.Text    or "?"
        info.selling  = gui:FindFirstChild("Selling")  and gui.Selling.Text  or "?"
    end)
    return info
end

local rarityColors = {
    Common=9807270, Uncommon=5763719, Rare=3447003,
    Epic=10181046, Legendary=16766720, Mythical=15158332,
    Unique=1752220, Godly=16711680, Celestial=16777215,
}

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

local childAddedConn = nil

local function handleSword(sword, lbl)
    if not scanning then return end
    if not isProtected(sword) and swordMatches(sword) then
        -- Lire les donnees AVANT le pickup
        local enchants = getSwordEnchants(sword)
        local info     = getSwordInfo(sword)
        flyPickup(sword)
        totalPicked = totalPicked + 1
        pcall(function() lbl:Set("Sniped! Total: "..totalPicked) end)
        Rayfield:Notify({Title="Sword Found!", Content=table.concat(enchants,", "), Duration=3})
        sendWebhook(sword, enchants, info)
    end
end

local function startScan(lbl)
    scanning = true

    -- Scan initial des swords deja presentes
    task.spawn(function()
        for _, sword in pairs(workspace.Swords:GetChildren()) do
            if not scanning then break end
            handleSword(sword, lbl)
        end
    end)

    -- Event-based: reagit instantanement quand une sword apparait
    if childAddedConn then childAddedConn:Disconnect() end
    childAddedConn = workspace.Swords.ChildAdded:Connect(function(sword)
        task.wait(0.05) -- laisse le temps aux enchants de se charger
        handleSword(sword, lbl)
    end)

    -- Polling de fallback
    task.spawn(function()
        while scanning do
            pcall(function() lbl:Set("Scanning | Total: "..totalPicked) end)
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
    ConfigurationSaving = { Enabled = true, FolderName = "SwordPicker", FileName = "config" },
    KeySystem       = false,
})

-- Tab principal
local Tab = Window:CreateTab("Scanner", "shield")

Tab:CreateSection("Options")

Tab:CreateToggle({
    Name         = "Match all 3 enchants per profile",
    CurrentValue = true,
    Flag         = "MatchAll",
    Callback     = function(val) MATCH_ALL = val end,
})

Tab:CreateSlider({
    Name         = "Scan Rate (s)",
    Range        = {0.1, 3},
    Increment    = 0.1,
    CurrentValue = 0.5,
    Flag         = "ScanRate",
    Callback     = function(val) SCAN_RATE = val end,
})

Tab:CreateSection("Discord Webhook")

Tab:CreateInput({
    Name        = "Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Flag        = "WebhookURL",
    Callback    = function(val) WEBHOOK_URL = val end,
})

Tab:CreateSection("Control")

local statusLbl = Tab:CreateLabel("Status: Ready")

Tab:CreateButton({
    Name     = "Start Auto-Pickup",
    Callback = function()
        if not scanning then
            startScan(statusLbl)
            Rayfield:Notify({Title="Enchant Picker", Content="Scan started!", Duration=2})
        end
    end,
})

Tab:CreateButton({
    Name     = "Stop Auto-Pickup",
    Callback = function()
        scanning = false
        Rayfield:Notify({Title="Enchant Picker", Content="Stopped.", Duration=2})
    end,
})


-- Tab Misc
local MiscTab = Window:CreateTab("Misc", "settings")

MiscTab:CreateSection("Anti-AFK")

MiscTab:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = true,
    Flag         = "AntiAFK",
    Callback     = function(val) ANTI_AFK = val end,
})

MiscTab:CreateSection("Configuration")

MiscTab:CreateButton({
    Name     = "Save Config",
    Callback = function()
        Rayfield:SaveConfiguration()
        Rayfield:Notify({Title="Config", Content="Configuration saved!", Duration=2})
    end,
})

MiscTab:CreateButton({
    Name     = "Load Config",
    Callback = function()
        Rayfield:LoadConfiguration()
        Rayfield:Notify({Title="Config", Content="Configuration loaded!", Duration=2})
    end,
})

MiscTab:CreateSection("Info")

MiscTab:CreateLabel("TinouHub v"..VERSION.." | Sword Factory X")
MiscTab:CreateLabel("github.com/ImTinou/sword")

-- Tabs profils
for i = 1, 3 do
    local pTab = Window:CreateTab("Profile "..i, "star")

    pTab:CreateSection("Profile "..i.." Enchants")

    pTab:CreateToggle({
        Name         = "Enable Profile "..i,
        CurrentValue = i == 1,
        Flag         = "Profile"..i.."Active",
        Callback     = function(val) profiles[i].active = val end,
    })

    local function getOpt(opt)
        return type(opt) == "table" and opt[1] or opt
    end

    pTab:CreateDropdown({
        Name            = "Slot 1",
        Options         = enchantList,
        CurrentOption   = "Any",
        MultipleOptions = false,
        Flag            = "Profile"..i.."Slot1",
        Callback        = function(opt) profiles[i].slots[1] = getOpt(opt) end,
    })

    pTab:CreateDropdown({
        Name            = "Slot 2",
        Options         = enchantList,
        CurrentOption   = "Any",
        MultipleOptions = false,
        Flag            = "Profile"..i.."Slot2",
        Callback        = function(opt) profiles[i].slots[2] = getOpt(opt) end,
    })

    pTab:CreateDropdown({
        Name            = "Slot 3",
        Options         = enchantList,
        CurrentOption   = "Any",
        MultipleOptions = false,
        Flag            = "Profile"..i.."Slot3",
        Callback        = function(opt) profiles[i].slots[3] = getOpt(opt) end,
    })

end
