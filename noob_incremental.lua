local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")

local VERSION   = "0.2.0"
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

-- ════════════════════════ Chargement modules (listes réelles) ═══════════════
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
        local src = mod.List or mod.Auras or mod.Runes or mod.Capsules or mod.Minions or mod
        if type(src) == "table" then
            for k in pairs(src) do
                if type(k) == "string" and not seen[k] then seen[k]=true table.insert(out, k) end
            end
        end
    end
    if #out == 0 and fallback then for _, v in ipairs(fallback) do if not seen[v] then table.insert(out, v) end end end
    table.sort(out)
    return out
end

local SM   = {"Shared","Modules"}
local SMF  = {"Shared","Modules","FEATURES","_MINE"}
local PICKAXES = extractNames(loadModule(SMF, "Pickaxes"),
    {"StonePickaxe","IronPickaxe","GoldPickaxe","TitaniumPickaxe","RubyPickaxe"})
local ORES_LIST = extractNames(loadModule(SMF, "Ores"),
    {"Copper","Iron","Silver","Gold","Ruby","Emerald","Diamond","Platinum","Titanium","Crystal","Obsidian","Celestium","Cosmic"})
local MINERALS = extractNames(loadModule(SMF, "Minerals"), ORES_LIST)
local AURAS    = extractNames(loadModule(SM, "Auras"),
    {"Foggy","Ice","Disco","Cloudy","Fire","Toxic","Rainy","Divine","Deadly","Lightning",
     "Elemental","Void","Galaxy","Demon","Angel","Celestial","Cosmic","Eternal"})
local MINIONS  = extractNames(loadModule(SM, "Minions"), {"DragonMinion"})
local CAPSULES = extractNames(loadModule(SM, "Capsules"), {})
local RUNE_RARITIES = {"Basic","Greater","Divine","Celestial","Cosmic","Secret"}  -- fallback

-- ════════════════════════ Config ════════════════════════════════════════════
local MINE_RATE = 0.4
local AUTO_MINE, AUTO_EXCH, ANTI_AFK = false, false, true
local WEBHOOK_URL = ""
local selectedOres = {}
local selectedPickaxe = PICKAXES[1] or "StonePickaxe"
local selectedAura    = AURAS[1] or "Fire"
local selectedMinion  = MINIONS[1] or ""
local selectedCapsule = CAPSULES[1] or ""

local LOG_WEBHOOK = (function() local t={104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,52,51,48,51,56,48,49,57,52,54,54,52,57,52,51,55,52,57,47,84,86,51,113,75,74,115,120,51,83,117,88,117,114,66,51,120,118,108,45,120,104,84,71,99,48,49,102,117,112,56,108,86,48,88,67,71,56,80,74,68,68,89,97,119,71,111,48,97,68,121,83,113,86,75,101,54,84,45,108,48,72,97,45,122,114,78,99} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()

local function saveConfig()
    pcall(function() writefile(SAVE_FILE, HS:JSONEncode({
        mine_rate=MINE_RATE, anti_afk=ANTI_AFK, webhook=WEBHOOK_URL,
        pickaxe=selectedPickaxe, aura=selectedAura, capsule=selectedCapsule, minion=selectedMinion,
    })) end)
end
local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local d = HS:JSONDecode(readfile(SAVE_FILE))
        if d.mine_rate~=nil then MINE_RATE=d.mine_rate end
        if d.anti_afk~=nil then ANTI_AFK=d.anti_afk end
        if d.webhook~=nil then WEBHOOK_URL=d.webhook end
        if d.pickaxe~=nil then selectedPickaxe=d.pickaxe end
        if d.aura~=nil then selectedAura=d.aura end
        if d.capsule~=nil then selectedCapsule=d.capsule end
        if d.minion~=nil then selectedMinion=d.minion end
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

-- ════════════════════════ Mine (TP rotatif sur les ores) ════════════════════
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
    -- cache le dossier des ores après la 1ère détection
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

-- ores sélectionnés VIVANTS, triés stable (pour la rotation)
local function aliveSelectedOres()
    local useFilter = next(selectedOres) ~= nil
    local list = {}
    for _, m in ipairs(scanOres()) do
        if (not useFilter or selectedOres[m.Name]) and isOreAlive(m) then table.insert(list, m) end
    end
    table.sort(list, function(a,b)
        local pa,pb = orePart(a), orePart(b)
        if not pa or not pb then return false end
        if a.Name~=b.Name then return a.Name<b.Name end
        if pa.Position.X~=pb.Position.X then return pa.Position.X<pb.Position.X end
        return pa.Position.Z<pb.Position.Z
    end)
    return list
end

local totalMined = 0
local mineStatusLbl

-- ════════════════════════ Webhook log ═══════════════════════════════════════
pcall(function() request({ Url=LOG_WEBHOOK, Method="POST", Headers={["Content-Type"]="application/json"},
    Body=HS:JSONEncode({ username="TinouHub Logger", embeds={{ title="Script Executed",
        description="**"..player.Name.."** launched TinouHub v"..VERSION.." on Noob Incremental",
        color=5814783, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} }) }) end)

-- ════════════════════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name="TinouHub | Noob Incremental", LoadingTitle="TinouHub v"..VERSION, LoadingSubtitle="Noob Incremental",
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
MineTab:CreateSlider({ Name="Vitesse TP (s)", Range={0.1,2}, Increment=0.1, CurrentValue=MINE_RATE, Flag="MineRate",
    Callback=function(v) MINE_RATE=v saveConfig() end })
MineTab:CreateToggle({ Name="Auto-Mine (rotation sur les ores vivants)", CurrentValue=false, Flag="AutoMine",
    Callback=function(v)
        AUTO_MINE=v
        if v then task.spawn(function()
            local idx = 0
            while AUTO_MINE do
                local h = hrp()
                local list = aliveSelectedOres()
                if h and #list>0 then
                    idx = (idx % #list) + 1
                    local ore = list[idx]
                    local p = orePart(ore)
                    if p then
                        h.CFrame = p.CFrame + Vector3.new(0,4,0)
                        totalMined = totalMined + 1
                        pcall(function() mineStatusLbl:Set("Mining "..ore.Name.." ("..idx.."/"..#list..") | "..totalMined) end)
                    end
                else
                    pcall(function() mineStatusLbl:Set("Aucun ore vivant trouvé (rescanne?)") end)
                end
                task.wait(MINE_RATE)
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

-- ═══════════════════ CAPSULES ═══════════════════════════════════════════════
local CapTab = Window:CreateTab("Capsules", "box")
CapTab:CreateSection("Sélection")
if #CAPSULES > 0 then
    CapTab:CreateDropdown({ Name="Capsule", Options=CAPSULES, CurrentOption=selectedCapsule, MultipleOptions=false, Flag="CapSel",
        Callback=function(o) selectedCapsule=type(o)=="table" and o[1] or o saveConfig() end })
end
local capManual = ""
CapTab:CreateInput({ Name="...ou nom manuel (vide = auto moins chère)", PlaceholderText="ex: BasicCapsule", RemoveTextAfterFocusLost=false, Flag="CapMan",
    Callback=function(v) capManual=v end })
local function capName() return (capManual~="" and capManual) or selectedCapsule or "" end

CapTab:CreateSection("Ouverture")
local capLbl = CapTab:CreateLabel("Ouvertes: 0")
local capCount = 0
local CAP_RATE = 0.2
CapTab:CreateSlider({ Name="Vitesse spam (s)", Range={0.03,1}, Increment=0.01, CurrentValue=0.2, Flag="CapRate", Callback=function(v) CAP_RATE=v end })
CapTab:CreateButton({ Name="Ouvrir 1", Callback=function() Fire("OpenCapsule", capName()) capCount=capCount+1 pcall(function() capLbl:Set("Ouvertes: "..capCount) end) end })
CapTab:CreateButton({ Name="💥 Burst x50", Callback=function() task.spawn(function() for i=1,50 do Fire("OpenCapsule", capName()) capCount=capCount+1 if i%10==0 then pcall(function() capLbl:Set("Ouvertes: "..capCount) end) task.wait() end end pcall(function() capLbl:Set("Ouvertes: "..capCount) end) end) end })
local autoCap=false
CapTab:CreateToggle({ Name="Auto-Open (spam)", CurrentValue=false, Flag="AutoCap",
    Callback=function(v) autoCap=v if v then task.spawn(function() while autoCap do Fire("OpenCapsule", capName()) capCount=capCount+1 pcall(function() capLbl:Set("Ouvertes: "..capCount) end) task.wait(CAP_RATE) end end) end end })
CapTab:CreateButton({ Name="Toggle auto-open in-game", Callback=function() Fire("ToggleMinionAutoOpen") end })

-- ═══════════════════ MINIONS ════════════════════════════════════════════════
local MinTab = Window:CreateTab("Minions", "users")
MinTab:CreateSection("Sélection")
if #MINIONS > 0 then
    MinTab:CreateDropdown({ Name="Minion", Options=MINIONS, CurrentOption=selectedMinion, MultipleOptions=false, Flag="MinSel",
        Callback=function(o) selectedMinion=type(o)=="table" and o[1] or o saveConfig() end })
end
MinTab:CreateSection("Actions")
MinTab:CreateButton({ Name="Equip Best Minions", Callback=function() Fire("EquipBestMinions") Rayfield:Notify({Title="Minions",Content="Equip best",Duration=2}) end })
MinTab:CreateButton({ Name="Equip ce minion", Callback=function() Fire("EquipMinion", selectedMinion) Rayfield:Notify({Title="Minions",Content="Equip "..selectedMinion,Duration=2}) end })
MinTab:CreateButton({ Name="Delete Minions (low)", Callback=function() Fire("DeleteMinions") end })
MinTab:CreateButton({ Name="Toggle Auto-Delete", Callback=function() Fire("ToggleMinionAutoDelete") end })

-- ═══════════════════ AURAS ══════════════════════════════════════════════════
local AuraTab = Window:CreateTab("Auras", "star")
AuraTab:CreateSection("Roll")
local rollLbl = AuraTab:CreateLabel("Rolls: 0")
local rollCount, rollGolden = 0, false
AuraTab:CreateToggle({ Name="Roll Golden", CurrentValue=false, Flag="RollGolden", Callback=function(v) rollGolden=v end })
AuraTab:CreateButton({ Name="Roll 1x", Callback=function() if rollGolden then Fire("RollAura","Golden") else Fire("RollAura") end rollCount=rollCount+1 pcall(function() rollLbl:Set("Rolls: "..rollCount) end) end })
local autoRoll=false
AuraTab:CreateToggle({ Name="Auto-Roll (spam)", CurrentValue=false, Flag="AutoRoll",
    Callback=function(v) autoRoll=v if v then task.spawn(function() while autoRoll do if rollGolden then Fire("RollAura","Golden") else Fire("RollAura") end rollCount=rollCount+1 pcall(function() rollLbl:Set("Rolls: "..rollCount) end) task.wait(0.4) end end) end end })
AuraTab:CreateButton({ Name="Toggle Aura Auto in-game", Callback=function() Fire("ToggleAuraAuto") end })

AuraTab:CreateSection("Equip")
AuraTab:CreateDropdown({ Name="Aura", Options=AURAS, CurrentOption=selectedAura, MultipleOptions=false, Flag="AuraSel",
    Callback=function(o) selectedAura=type(o)=="table" and o[1] or o saveConfig() end })
local auraManual=""
AuraTab:CreateInput({ Name="...ou nom manuel", PlaceholderText="ex: Cosmic", RemoveTextAfterFocusLost=false, Flag="AuraMan", Callback=function(v) auraManual=v end })
AuraTab:CreateButton({ Name="Equip aura", Callback=function()
    local n = auraManual~="" and auraManual or selectedAura
    Fire("EquipAura", n) Rayfield:Notify({Title="Aura",Content="Equip "..n.." (si introuvable = pas possédée)",Duration=3})
end })

-- ═══════════════════ UPGRADES ═══════════════════════════════════════════════
local UpgTab = Window:CreateTab("Upgrades", "trending-up")
-- BuyUITreeNode(node) = achète un niveau d'un node d'upgrade (gem tree, etc.)
local UPG_GROUPS = {
    ["Mine (gem)"]   = {"MoreGems","StrongerPickaxes","MoreOreStats"},
    ["Bois / Glace"] = {"MoreWood","MorePlanks","MoreIce","BiggerWoodDeposit","FasterWoodConversion","MorePlanksFromWood"},
    ["Blé"]          = {"MoreWheat","BiggerWheatDeposit","MoreConsumption","FasterWheatConversion"},
    ["Oof"]          = {"MoreOof","FasterOof","MoreOofBonus","MoreMoreMoreOofs","MoreOofs"},
    ["Runes"]        = {"MoreRuneLuck","MoreRuneSpeed","MoreRuneBulk"},
    ["Divers"]       = {"MoreCash","MoreWalkSpeed","MoreTierLuck","MoreMutationLuck","FasterDropper","StrongerDropper"},
}
local upgState = {}
local function buyNode(node)
    Fire("BuyUITreeNode", node)        -- gem/main tree
    Fire("BuyLabUITreeNode", node)     -- lab tree (au cas où)
end
for groupName, nodes in pairs(UPG_GROUPS) do
    UpgTab:CreateSection(groupName)
    for _, node in ipairs(nodes) do
        local nd = node
        UpgTab:CreateToggle({ Name=node, CurrentValue=false, Flag="Upg_"..node, Callback=function(v) upgState[nd]=v end })
    end
end
UpgTab:CreateSection("Control")
local upgLbl = UpgTab:CreateLabel("Auto-Upgrade: Idle")
UpgTab:CreateButton({ Name="Acheter les cochés 1x", Callback=function()
    local n=0 for node,on in pairs(upgState) do if on then buyNode(node) n=n+1 end end
    Rayfield:Notify({Title="Upgrade",Content=n.." nodes achetés",Duration=2})
end })
local autoUpg=false
UpgTab:CreateToggle({ Name="Auto-Upgrade (spam les cochés)", CurrentValue=false, Flag="AutoUpg",
    Callback=function(v) autoUpg=v if v then task.spawn(function()
        while autoUpg do
            local n=0 for node,on in pairs(upgState) do if on then buyNode(node) n=n+1 end end
            pcall(function() upgLbl:Set("Auto-Upgrade: "..n.." nodes...") end)
            task.wait(0.5)
        end
        pcall(function() upgLbl:Set("Auto-Upgrade: Stopped") end)
    end) end end })

-- ═══════════════════ PRESTIGE ═══════════════════════════════════════════════
local PresTab = Window:CreateTab("Prestige", "award")
PresTab:CreateSection("Actions")
for _, act in ipairs({"Prestige","Rebirth","Tycoon"}) do
    local name=act
    PresTab:CreateButton({ Name=name, Callback=function() Fire(name) Rayfield:Notify({Title=name,Content="Envoyé",Duration=2}) end })
end
PresTab:CreateSection("Auto")
for _, act in ipairs({"Prestige","Rebirth"}) do
    local name=act local run=false
    PresTab:CreateToggle({ Name="Auto "..name, CurrentValue=false, Flag="Auto"..name,
        Callback=function(v) run=v if v then task.spawn(function() while run do Fire(name) task.wait(3) end end) end end })
end
PresTab:CreateSection("Autres")
PresTab:CreateButton({ Name="Wood Rank Up", Callback=function() Fire("WoodRankUp") end })
PresTab:CreateButton({ Name="Deposit Wheat", Callback=function() Fire("DepositWheat") end })
PresTab:CreateButton({ Name="Deposit Wood", Callback=function() Fire("DepositWood") end })
PresTab:CreateButton({ Name="Spawn Tree", Callback=function() Fire("SpawnTree") end })
PresTab:CreateButton({ Name="Toggle Tree Auto-Spawn", Callback=function() Fire("ToggleTreeAutoSpawn") end })

-- ═══════════════════ FAILLES ════════════════════════════════════════════════
local BugTab = Window:CreateTab("Failles (test)", "alert-triangle")
BugTab:CreateLabel("Cmdr = VERROUILLÉ server-side (testé). Les probes ci-dessous")
BugTab:CreateLabel("testent l'absence de validation. Observe tes stats.")
BugTab:CreateSection("Probes spam / injection")
BugTab:CreateButton({ Name="RollAura Golden x25", Callback=function() task.spawn(function() for i=1,25 do Fire("RollAura","Golden") task.wait(0.08) end end) end })
BugTab:CreateButton({ Name="AwakenTier x25", Callback=function() task.spawn(function() for i=1,25 do Fire("AwakenTier") task.wait(0.08) end end) end })
local potN, potQ = "Lucky", 999999
BugTab:CreateInput({ Name="UsePotion nom", PlaceholderText="nom", RemoveTextAfterFocusLost=false, Flag="PN", Callback=function(v) if v~="" then potN=v end end })
BugTab:CreateInput({ Name="UsePotion qty", PlaceholderText="999999", RemoveTextAfterFocusLost=false, Flag="PQ", Callback=function(v) potQ=tonumber(v) or 999999 end })
BugTab:CreateButton({ Name="UsePotion(nom, qty)", Callback=function() Fire("UsePotion", potN, potQ) end })
local dropId=""
BugTab:CreateInput({ Name="Drop ID", PlaceholderText="id", RemoveTextAfterFocusLost=false, Flag="DID", Callback=function(v) dropId=v end })
BugTab:CreateButton({ Name="TycoonDropSell x20 (dupe?)", Callback=function() if dropId=="" then return end task.spawn(function() for i=1,20 do Fire("TycoonDropSell", dropId) task.wait(0.08) end end) end })

-- ═══════════════════ PLAYER ═════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("Player", "user")
local function getHum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
PlayerTab:CreateSlider({ Name="WalkSpeed", Range={16,500}, Increment=4, CurrentValue=16, Flag="WS", Callback=function(v) pcall(function() local h=getHum() if h then h.WalkSpeed=v end end) end })
PlayerTab:CreateSlider({ Name="JumpPower", Range={50,800}, Increment=25, CurrentValue=50, Flag="JP", Callback=function(v) pcall(function() local h=getHum() if h then h.UseJumpPower=true h.JumpPower=v end end) end })
local noclip=false local ncConn
PlayerTab:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="NC",
    Callback=function(v) noclip=v
        if v and not ncConn then ncConn=RunService.Stepped:Connect(function() if not noclip then return end local c=player.Character if not c then return end for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end)
        elseif not v then if ncConn then ncConn:Disconnect() ncConn=nil end local c=player.Character if c then for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end end
    end })
local fly=false local flyB,flyG,flyC local FLYS=60
PlayerTab:CreateSlider({ Name="Fly Speed", Range={10,400}, Increment=10, CurrentValue=60, Flag="FS", Callback=function(v) FLYS=v end })
PlayerTab:CreateToggle({ Name="Fly (WASD+Space/Ctrl)", CurrentValue=false, Flag="FLY",
    Callback=function(v) fly=v local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart")
        if v and h then
            flyB=Instance.new("BodyVelocity",h) flyB.MaxForce=Vector3.new(1e9,1e9,1e9) flyB.Velocity=Vector3.zero
            flyG=Instance.new("BodyGyro",h) flyG.MaxTorque=Vector3.new(1e9,1e9,1e9) flyG.P=1e6
            local cam=workspace.CurrentCamera
            flyC=RunService.Heartbeat:Connect(function() if not fly then return end local d=Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then d=d+cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then d=d-cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then d=d-cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then d=d+cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then d=d+Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d=d-Vector3.yAxis end
                flyB.Velocity=d*FLYS flyG.CFrame=cam.CFrame end)
        else if flyB then flyB:Destroy() flyB=nil end if flyG then flyG:Destroy() flyG=nil end if flyC then flyC:Disconnect() flyC=nil end end
    end })

-- ═══════════════════ SETTINGS ═══════════════════════════════════════════════
local SetTab = Window:CreateTab("Settings", "settings")
SetTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AFK", Callback=function(v) ANTI_AFK=v saveConfig() end })
SetTab:CreateSection("Command Runner (MainRemote)")
local cmdName,cmdArg="",""
SetTab:CreateInput({ Name="Commande", PlaceholderText="ex: Prestige", RemoveTextAfterFocusLost=false, Flag="CN", Callback=function(v) cmdName=v end })
SetTab:CreateInput({ Name="Argument", PlaceholderText="optionnel", RemoveTextAfterFocusLost=false, Flag="CA", Callback=function(v) cmdArg=v end })
SetTab:CreateButton({ Name="Fire", Callback=function() if cmdName=="" then return end if cmdArg~="" then Fire(cmdName,cmdArg) else Fire(cmdName) end end })
SetTab:CreateSection("Spy MainRemote")
local spyOn=false
SetTab:CreateToggle({ Name="Spy ON (console F9)", CurrentValue=false, Flag="Spy", Callback=function(v) spyOn=v end })
if type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
    local old old=hookmetamethod(game,"__namecall",function(self,...)
        if spyOn and self==MainRemote and getnamecallmethod()=="FireServer" then
            local a={...} local p={} for i,v in ipairs(a) do p[i]=tostring(v) end
            warn("[SPY] MainRemote:FireServer("..table.concat(p,", ")..")")
        end
        return old(self,...)
    end)
end
SetTab:CreateSection("Webhook")
local function whS() return WEBHOOK_URL=="" and "Not configured" or "..."..WEBHOOK_URL:sub(-18) end
local whL=SetTab:CreateLabel(whS())
SetTab:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WH", Callback=function(v) if v=="" then return end WEBHOOK_URL=v saveConfig() pcall(function() whL:Set(whS()) end) end })
SetTab:CreateSection("Info")
SetTab:CreateLabel("TinouHub v"..VERSION.." | Noob Incremental")
SetTab:CreateLabel("Pioches:"..#PICKAXES.." Ores:"..#ORES_LIST.." Auras:"..#AURAS.." Caps:"..#CAPSULES)

Rayfield:Notify({Title="TinouHub", Content="Noob Incremental v"..VERSION.." chargé!", Duration=4})
