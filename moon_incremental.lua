local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game.Players.LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")

local VERSION = "1.0.0"

-- ══ Remote cache ══
local remotes = {}
local function cacheRemote(v)
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        remotes[v.Name] = v
    end
end
for _, v in pairs(RS:GetDescendants()) do cacheRemote(v) end
RS.DescendantAdded:Connect(cacheRemote)

local function fire(name, ...)
    local r = remotes[name]
    if r and r:IsA("RemoteEvent") then
        pcall(r.FireServer, r, ...)
    end
end

local function invoke(name, ...)
    local r = remotes[name]
    if r and r:IsA("RemoteFunction") then
        local ok, res = pcall(r.InvokeServer, r, ...)
        if ok then return res end
    end
end

-- ══ States ══
local autoEssence = false
local autoMine    = false
local autoDmg     = false
local autoUpgrade = false
local autoInfUpg  = false
local autoRebirth = false
local autoRoll    = false
local noclip      = false
local infJump     = false
local antiAfk     = true
local dmgCPS      = 10
local walkSpeed   = 16
local jumpPower   = 50

-- ══ Window ══
local Window = Rayfield:CreateWindow({
    Name            = "🌙 Moon Incremental Hub",
    LoadingTitle    = "Moon Incremental Hub",
    LoadingSubtitle = "v" .. VERSION,
    ConfigurationSaving = { Enabled = false },
    Discord  = { Enabled = false },
    KeySystem = false,
})

-- ════════════════════════════════
--  TAB: FARM
-- ════════════════════════════════
local FarmTab = Window:CreateTab("🌙 Farm", 4483362458)

FarmTab:CreateSection("Collectibles")

FarmTab:CreateToggle({
    Name         = "Auto Collect (Essence / Stars / Fragments)",
    CurrentValue = false,
    Callback     = function(v) autoEssence = v end,
})

FarmTab:CreateToggle({
    Name         = "Auto Mine Rocks",
    CurrentValue = false,
    Callback     = function(v) autoMine = v end,
})

FarmTab:CreateSection("Combat")

FarmTab:CreateSlider({
    Name         = "Click Speed",
    Range        = { 1, 50 },
    Increment    = 1,
    Suffix       = " CPS",
    CurrentValue = 10,
    Callback     = function(v) dmgCPS = v end,
})

FarmTab:CreateToggle({
    Name         = "Auto Click / Damage",
    CurrentValue = false,
    Callback     = function(v) autoDmg = v end,
})

-- ════════════════════════════════
--  TAB: UPGRADES
-- ════════════════════════════════
local UpgTab = Window:CreateTab("⬆️ Upgrades", 4483362458)

UpgTab:CreateSection("Auto")

UpgTab:CreateToggle({
    Name         = "Auto Buy Max Upgrade",
    CurrentValue = false,
    Callback     = function(v) autoUpgrade = v end,
})

UpgTab:CreateToggle({
    Name         = "Auto Infinite Upgrade",
    CurrentValue = false,
    Callback     = function(v) autoInfUpg = v end,
})

UpgTab:CreateSection("Prestige")

UpgTab:CreateToggle({
    Name         = "Auto Rebirth",
    CurrentValue = false,
    Callback     = function(v) autoRebirth = v end,
})

UpgTab:CreateButton({
    Name     = "Force Rebirth Now",
    Callback = function()
        fire("Rebirth")
        Rayfield:Notify({ Title = "Rebirth", Content = "Rebirth envoyé !", Duration = 3, Image = 4483362458 })
    end,
})

UpgTab:CreateButton({
    Name     = "Buy Max Upgrade (1x)",
    Callback = function() fire("BuyMaxUpgrade") end,
})

-- ════════════════════════════════
--  TAB: AURAS
-- ════════════════════════════════
local AuraTab = Window:CreateTab("🎭 Auras", 4483362458)

AuraTab:CreateSection("Auto Roll")

AuraTab:CreateToggle({
    Name         = "Auto Roll Aura (Moon)",
    CurrentValue = false,
    Callback     = function(v) autoRoll = v end,
})

AuraTab:CreateSection("Roll Manuel")

AuraTab:CreateButton({ Name = "Roll Aura (Moon)",   Callback = function() fire("RollAura") end })
AuraTab:CreateButton({ Name = "Roll Mars Aura",     Callback = function() fire("RollMarsAura") end })
AuraTab:CreateButton({ Name = "Roll Venus Aura",    Callback = function() fire("RollVenusAura") end })
AuraTab:CreateButton({ Name = "Roll Easter Aura",   Callback = function() fire("RollEasterAura") end })

-- ════════════════════════════════
--  TAB: TELEPORT
-- ════════════════════════════════
local TpTab = Window:CreateTab("🌍 Teleport", 4483362458)

TpTab:CreateSection("Planètes")

TpTab:CreateButton({ Name = "→ Moon (Base)",    Callback = function() fire("TeleportToMoon") end })
TpTab:CreateButton({ Name = "→ Earth",          Callback = function() fire("TeleportToEarth") end })
TpTab:CreateButton({ Name = "→ Mars",           Callback = function() fire("TeleportToMars") end })
TpTab:CreateButton({ Name = "→ Mercury",        Callback = function() fire("TeleportToMercury") end })
TpTab:CreateButton({ Name = "→ Venus",          Callback = function() fire("TeleportToVenus") end })
TpTab:CreateButton({ Name = "→ Pluto",          Callback = function() fire("TeleportToPluto") end })
TpTab:CreateButton({ Name = "→ Pyramid",        Callback = function() fire("TeleportToPyramid") end })
TpTab:CreateButton({ Name = "→ Easter Moon",    Callback = function() fire("TeleportToMoonEaster") end })

-- ════════════════════════════════
--  TAB: MISC
-- ════════════════════════════════
local MiscTab = Window:CreateTab("⚡ Misc", 4483362458)

MiscTab:CreateSection("Personnage")

MiscTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = { 16, 500 },
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 16,
    Callback     = function(v)
        walkSpeed = v
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v end
        end
    end,
})

MiscTab:CreateSlider({
    Name         = "Jump Power",
    Range        = { 50, 500 },
    Increment    = 10,
    Suffix       = "",
    CurrentValue = 50,
    Callback     = function(v)
        jumpPower = v
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.UseJumpPower = true ; hum.JumpPower = v end
        end
    end,
})

MiscTab:CreateToggle({
    Name         = "Noclip",
    CurrentValue = false,
    Callback     = function(v) noclip = v end,
})

MiscTab:CreateToggle({
    Name         = "Infinite Jump",
    CurrentValue = false,
    Callback     = function(v) infJump = v end,
})

MiscTab:CreateSection("Anti-AFK")

MiscTab:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = true,
    Callback     = function(v) antiAfk = v end,
})

-- ════════════════════════════════
--  LOOPS
-- ════════════════════════════════

-- Auto collect (essence, stars, fragments…)
task.spawn(function()
    local COLLECT_KEYWORDS = { "essence", "star", "fragment", "crystal", "orb", "astral", "egg" }
    while true do
        task.wait(0.08)
        if not autoEssence then continue end
        pcall(function()
            local char = player.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Parent ~= char then
                    local n = obj.Name:lower()
                    for _, kw in ipairs(COLLECT_KEYWORDS) do
                        if n:find(kw) then
                            -- Try firing the remote directly first
                            fire("EssenceCollected",  obj)
                            fire("StarCollected",     obj)
                            fire("FragmentCollected", obj)
                            -- Physical touch fallback
                            hrp.CFrame = CFrame.new(obj.Position)
                            task.wait(0.02)
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto mine
task.spawn(function()
    local MINE_KEYWORDS = { "rock", "ore", "stone", "crystal", "deposit" }
    while true do
        task.wait(0.1)
        if not autoMine then continue end
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    for _, kw in ipairs(MINE_KEYWORDS) do
                        if n:find(kw) then
                            fire("RockHit",    obj)
                            fire("MineRock",   obj)
                            fire("EggHit",     obj)
                            fire("MineshaftMine", obj)
                            task.wait(0.02)
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto damage (respects CPS slider)
task.spawn(function()
    while true do
        task.wait(1 / math.max(dmgCPS, 1))
        if not autoDmg then continue end
        pcall(function()
            -- Try boss damage first, then generic DamageDealt
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    if n:find("boss") or n:find("enemy") or n:find("npc") or n:find("mob") then
                        fire("PlayerDamageBoss",  obj, 999999)
                        fire("YetiPlayerDamageBoss", obj, 999999)
                        fire("DamageDealt",       obj, 999999)
                        return
                    end
                end
            end
            fire("DamageDealt", 999999)
        end)
    end
end)

-- Auto upgrade / rebirth / roll (0.5s tick)
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoUpgrade then
            pcall(function() fire("BuyMaxUpgrade") end)
        end
        if autoInfUpg then
            pcall(function() fire("InfiniteUpgradePurchase") end)
        end
        if autoRebirth then
            pcall(function() fire("Rebirth") end)
        end
        if autoRoll then
            pcall(function() fire("RollAura") end)
        end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if not noclip then return end
    local char = player.Character
    if not char then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- Infinite Jump
UIS.JumpRequest:Connect(function()
    if not infJump then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- Restore speed on respawn
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = walkSpeed
    hum.UseJumpPower = true
    hum.JumpPower = jumpPower
end)

-- Anti-AFK (triple méthode)
player.Idled:Connect(function()
    if not antiAfk then return end
    pcall(function()
        workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(0, math.rad(0.01), 0)
    end)
end)

task.spawn(function()
    while true do
        task.wait(55)
        if antiAfk then
            pcall(function()
                workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(0, math.rad(0.1), 0)
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(math.random(180, 240))
        if antiAfk then
            pcall(function()
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
                end
            end)
        end
    end
end)

Rayfield:Notify({
    Title    = "Moon Incremental Hub",
    Content  = "v" .. VERSION .. " chargé !",
    Duration = 5,
    Image    = 4483362458,
})
