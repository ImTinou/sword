local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")

local VERSION   = "1.0.0"
local SAVE_FILE = "tinouhub_noob_config.json"

-- ════════════════════════ MainRemote ════════════════════════════════════════
local MainRemote = nil
pcall(function() MainRemote = RS:FindFirstChild("MainRemote", true) end)
local function Fire(cmd, ...)
    if not MainRemote then MainRemote = RS:FindFirstChild("MainRemote", true) end
    if not MainRemote then return false end
    local a = {...}
    return (pcall(function() MainRemote:FireServer(cmd, table.unpack(a)) end))
end

-- ════════════════════════ Listes (modules du jeu) ═══════════════════════════
local function loadModule(chain, name)
    local ok, mod = pcall(function()
        if type(require) ~= "function" then return nil end
        local obj = RS
        for _, seg in ipairs(chain) do obj = obj and obj:FindFirstChild(seg) end
        obj = obj and obj:FindFirstChild(name)
        if not obj then return nil end
        return require(obj)
    end)
    if ok and type(mod) == "table" then return mod end
    return nil
end
local function extractNames(mod, fallback)
    local out, seen = {}, {}
    if type(mod) == "table" then
        local src = mod.List or mod
        if type(src) == "table" then
            for k in pairs(src) do if type(k)=="string" and not seen[k] then seen[k]=true table.insert(out,k) end end
        end
    end
    if #out==0 and fallback then for _,v in ipairs(fallback) do if not seen[v] then table.insert(out,v) end end end
    table.sort(out)
    return out
end
local SMF = {"Shared","Modules","FEATURES","_MINE"}
local PICKAXES = extractNames(loadModule(SMF,"Pickaxes"),
    {"StonePickaxe","IronPickaxe","GoldPickaxe","TitaniumPickaxe","RubyPickaxe"})
local ORES_LIST = extractNames(loadModule(SMF,"Ores"),
    {"Copper","Iron","Silver","Gold","Ruby","Emerald","Diamond","Platinum","Titanium","Crystal","Obsidian","Celestium","Cosmic"})

-- ════════════════════════ Config ════════════════════════════════════════════
local MINE_RATE = 0.35
local AUTO_MINE, AUTO_EXCH, ANTI_AFK = false, false, true
local selectedOres = {}
local selectedPickaxe = PICKAXES[1] or "StonePickaxe"

local function saveConfig()
    pcall(function() writefile(SAVE_FILE, HS:JSONEncode({
        mine_rate=MINE_RATE, anti_afk=ANTI_AFK, pickaxe=selectedPickaxe,
    })) end)
end
local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local d = HS:JSONDecode(readfile(SAVE_FILE))
        if d.mine_rate~=nil then MINE_RATE=d.mine_rate end
        if d.anti_afk~=nil then ANTI_AFK=d.anti_afk end
        if d.pickaxe~=nil then selectedPickaxe=d.pickaxe end
    end)
end
loadConfig()

-- ════════════════════════ Anti-AFK ══════════════════════════════════════════
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local function pulseInput()
    if not VIM then return false end
    return (pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end))
end
player.Idled:Connect(function()
    if not ANTI_AFK then return end
    pulseInput()
    pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while true do task.wait(55)
        if ANTI_AFK and not pulseInput() then
            pcall(function() local cam=workspace.CurrentCamera
                VU:Button2Down(cam.ViewportSize/2,cam.CFrame) task.wait(0.1) VU:Button2Up(cam.ViewportSize/2,cam.CFrame) end)
        end
    end
end)

-- ════════════════════════ Mine (TP rotatif sur ores vivants) ════════════════
local oreNameSet = {}
for _, n in ipairs(ORES_LIST) do oreNameSet[n] = true end
local function hrp() local c=player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function orePart(m) return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart") end

local function isOreAlive(m)
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = d.Text
            if t and (string.find(t,"espawn") or string.find(t,"^0 ") or string.find(t,"^0/")) then return false end
        end
    end
    local hum = m:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    return true
end

local oreFolder = nil
local function scanOres()
    local found = {}
    local roots = oreFolder and {oreFolder} or {workspace}
    for _, root in ipairs(roots) do
        for _, m in ipairs(root:GetDescendants()) do
            if m:IsA("Model") and oreNameSet[m.Name] and orePart(m) then
                if not oreFolder and m.Parent then oreFolder = m.Parent end
                table.insert(found, m)
            end
        end
    end
    return found
end
local function oreNamesPresent()
    local set, out = {}, {}
    for _, m in ipairs(scanOres()) do if not set[m.Name] then set[m.Name]=true table.insert(out,m.Name) end end
    if #out==0 then out=ORES_LIST end
    table.sort(out)
    return out
end
local function aliveSelectedOres()
    local useFilter = next(selectedOres) ~= nil
    local list = {}
    for _, m in ipairs(scanOres()) do
        if (not useFilter or selectedOres[m.Name]) and isOreAlive(m) then table.insert(list, m) end
    end
    return list
end
-- ore vivant sélectionné le plus proche
local function nearestAliveOre()
    local h = hrp() if not h then return nil end
    local best, bd = nil, math.huge
    for _, m in ipairs(aliveSelectedOres()) do
        local p = orePart(m)
        if p then local d=(p.Position-h.Position).Magnitude if d<bd then best,bd=m,d end end
    end
    return best
end

local totalMined = 0
local mineStatusLbl

-- ════════════════════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name="TinouHub | Noob Incremental", LoadingTitle="TinouHub v"..VERSION, LoadingSubtitle="Mining",
    ConfigurationSaving={Enabled=false},
    KeySystem=true, KeySettings={Title="TinouHub", Subtitle="Key System", Note="Ask ImTinou for your key",
        FileName="TinouHubKey", SaveKey=true, GrabKeyFromSite=false, Key={"tinoukey1","tinoukey2","tinoukey3"}},
})

-- ═══════════════════ MINE ═══════════════════════════════════════════════════
local MineTab = Window:CreateTab("Mine", "hammer")

MineTab:CreateSection("Ores à farm")
local oreDropdown
oreDropdown = MineTab:CreateDropdown({ Name="Ores (vide = tous)", Options=oreNamesPresent(), CurrentOption={},
    MultipleOptions=true, Flag="OreSel",
    Callback=function(opt) selectedOres={} if type(opt)=="table" then for _,o in ipairs(opt) do selectedOres[o]=true end end end })
MineTab:CreateButton({ Name="↻ Rescanner les ores", Callback=function()
    oreFolder=nil
    pcall(function() oreDropdown:Refresh(oreNamesPresent()) end)
    Rayfield:Notify({Title="Mine", Content="Ores rescannés", Duration=2})
end })

MineTab:CreateSection("Auto-Mine")
mineStatusLbl = MineTab:CreateLabel("Mine: Idle")
MineTab:CreateSlider({ Name="Vitesse TP (s)", Range={0.1,2}, Increment=0.05, CurrentValue=MINE_RATE, Flag="MineRate",
    Callback=function(v) MINE_RATE=v saveConfig() end })
MineTab:CreateToggle({ Name="Auto-Mine (reste sur l'ore jusqu'à le casser)", CurrentValue=false, Flag="AutoMine",
    Callback=function(v)
        AUTO_MINE=v
        if v then task.spawn(function()
            while AUTO_MINE do
                local ore = nearestAliveOre()
                if ore then
                    -- reste sur CET ore tant qu'il est vivant et existe
                    while AUTO_MINE and ore.Parent and isOreAlive(ore) do
                        local h, p = hrp(), orePart(ore)
                        if h and p then h.CFrame = p.CFrame + Vector3.new(0,4,0) end
                        pcall(function() mineStatusLbl:Set("Mining "..ore.Name.." | cassés: "..totalMined) end)
                        task.wait(MINE_RATE)
                    end
                    totalMined = totalMined + 1
                else
                    pcall(function() mineStatusLbl:Set("Aucun ore vivant (rescanne?)") end)
                    task.wait(MINE_RATE)
                end
            end
            pcall(function() mineStatusLbl:Set("Mine: Stopped") end)
        end) end
    end })

MineTab:CreateSection("Pioche")
MineTab:CreateDropdown({ Name="Pioche", Options=PICKAXES, CurrentOption=selectedPickaxe, MultipleOptions=false, Flag="PickSel",
    Callback=function(o) selectedPickaxe=type(o)=="table" and o[1] or o saveConfig() end })
MineTab:CreateButton({ Name="Craft pioche", Callback=function() Fire("CraftPickaxe", selectedPickaxe) Rayfield:Notify({Title="Pioche",Content="Craft "..selectedPickaxe,Duration=2}) end })
MineTab:CreateButton({ Name="Equip pioche", Callback=function() Fire("EquipPickaxe", selectedPickaxe) Rayfield:Notify({Title="Pioche",Content="Equip "..selectedPickaxe,Duration=2}) end })
MineTab:CreateButton({ Name="Awaken Tier", Callback=function() Fire("AwakenTier") Rayfield:Notify({Title="Awaken",Content="Envoyé",Duration=2}) end })

MineTab:CreateSection("Exchange minéraux")
MineTab:CreateButton({ Name="Exchange ALL", Callback=function() Fire("ExchangeAllMinerals") Rayfield:Notify({Title="Exchange",Content="Tout échangé",Duration=2}) end })
MineTab:CreateToggle({ Name="Auto-Exchange (5s)", CurrentValue=false, Flag="AutoExch",
    Callback=function(v) AUTO_EXCH=v if v then task.spawn(function() while AUTO_EXCH do Fire("ExchangeAllMinerals") task.wait(5) end end) end end })

-- ═══════════════════ SETTINGS ═══════════════════════════════════════════════
local SetTab = Window:CreateTab("Settings", "settings")
SetTab:CreateButton({ Name="🔄 Reload script", Callback=function()
    pcall(function() Rayfield:Destroy() end)
    task.wait(0.2)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ImTinou/sword/main/noob_incremental.lua?v="..tostring(os.time())))()
end })
SetTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AFK", Callback=function(v) ANTI_AFK=v saveConfig() end })
SetTab:CreateSection("Info")
SetTab:CreateLabel("TinouHub v"..VERSION.." | Noob Incremental")
SetTab:CreateLabel("Ores:"..#ORES_LIST.." Pioches:"..#PICKAXES)

Rayfield:Notify({Title="TinouHub", Content="Mining v"..VERSION.." chargé!", Duration=4})
