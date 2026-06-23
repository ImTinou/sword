local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")

local VERSION   = "0.1.0"
local SAVE_FILE = "tinouhub_noob_config.json"

-- ════════════════════════ MainRemote ════════════════════════════════════════
-- Toutes les actions: MainRemote:FireServer("Command", ...args)  (vérifié rbxlx)
local MainRemote = nil
pcall(function() MainRemote = RS:FindFirstChild("MainRemote", true) end)
local function Fire(cmd, ...)
    if not MainRemote then MainRemote = RS:FindFirstChild("MainRemote", true) end
    if not MainRemote then return false end
    local args = {...}
    return (pcall(function() MainRemote:FireServer(cmd, table.unpack(args)) end))
end

-- ════════════════════════ Feature modules (listes live) ═════════════════════
-- Les listes (pioches, ores, auras...) sont dans RS.Shared.Modules.FEATURES.*
local function featureModule(...)
    local ok, mod = pcall(function()
        local obj = RS:WaitForChild("Shared", 5):WaitForChild("Modules"):WaitForChild("FEATURES")
        for _, seg in ipairs({...}) do obj = obj:FindFirstChild(seg) end
        return require(obj)
    end)
    if ok and type(mod) == "table" then return mod end
    return nil
end

local function listKeys(mod, fallback)
    local out = {}
    if mod then
        local list = mod.List or mod
        if type(list) == "table" then
            for k in pairs(list) do if type(k) == "string" then table.insert(out, k) end end
        end
    end
    if #out == 0 and fallback then for _, v in ipairs(fallback) do table.insert(out, v) end end
    table.sort(out)
    return out
end

local PICKAXES = listKeys(featureModule("_MINE","Pickaxes"),
    {"StonePickaxe","IronPickaxe","GoldPickaxe","TitaniumPickaxe","RubyPickaxe"})
local ORES_LIST = listKeys(featureModule("_MINE","Ores"),
    {"Copper","Iron","Silver","Gold","Ruby","Emerald","Diamond","Platinum","Titanium","Crystal","Obsidian","Cosmic"})
local MINERALS = listKeys(featureModule("_MINE","Minerals"), ORES_LIST)
local AURAS = listKeys(featureModule("_AURA","Auras"),
    {"FoggyAura","IceAura","DiscoAura","CloudyAura","FireAura","ToxicAura","RainyAura","DivineAura",
     "DeadlyAura","LightningAura","ElementalAura","VoidAura","GalaxyAura","DemonAura","AngelAura",
     "CelestialAura","CosmicAura","EternalAura"})
local CAPSULES = listKeys(featureModule("_MINION","Capsules") or featureModule("_CAPSULE","Capsules"),
    {""})  -- "" = auto-pick la moins chère (géré par le jeu)

-- ════════════════════════ Config ════════════════════════════════════════════
local MINE_RATE   = 0.4
local AUTO_MINE   = false
local AUTO_EXCH   = false
local ANTI_AFK    = true
local WEBHOOK_URL = ""
local selectedOres   = {}   -- set { [oreName]=true }, vide = tous
local selectedPickaxe = PICKAXES[1] or "StonePickaxe"
local selectedAura    = AURAS[1] or "FireAura"
local selectedCapsule = ""
local rollGolden      = false

local LOG_WEBHOOK = (function() local t={104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,52,51,48,51,56,48,49,57,52,54,54,52,57,52,51,55,52,57,47,84,86,51,113,75,74,115,120,51,83,117,88,117,114,66,51,120,118,108,45,120,104,84,71,99,48,49,102,117,112,56,108,86,48,88,67,71,56,80,74,68,68,89,97,119,71,111,48,97,68,121,83,113,86,75,101,54,84,45,108,48,72,97,45,122,114,78,99} local s="" for _,c in ipairs(t) do s=s..string.char(c) end return s end)()

local function saveConfig()
    pcall(function()
        writefile(SAVE_FILE, HS:JSONEncode({
            mine_rate=MINE_RATE, auto_mine=AUTO_MINE, auto_exch=AUTO_EXCH,
            anti_afk=ANTI_AFK, webhook=WEBHOOK_URL, pickaxe=selectedPickaxe,
            aura=selectedAura, capsule=selectedCapsule,
        }))
    end)
end
local function loadConfig()
    pcall(function()
        if not isfile(SAVE_FILE) then return end
        local d = HS:JSONDecode(readfile(SAVE_FILE))
        if d.mine_rate ~= nil then MINE_RATE=d.mine_rate end
        if d.auto_mine ~= nil then AUTO_MINE=d.auto_mine end
        if d.auto_exch ~= nil then AUTO_EXCH=d.auto_exch end
        if d.anti_afk ~= nil then ANTI_AFK=d.anti_afk end
        if d.webhook ~= nil then WEBHOOK_URL=d.webhook end
        if d.pickaxe ~= nil then selectedPickaxe=d.pickaxe end
        if d.aura ~= nil then selectedAura=d.aura end
        if d.capsule ~= nil then selectedCapsule=d.capsule end
    end)
end
loadConfig()

-- ════════════════════════ Anti-AFK (VIM) ════════════════════════════════════
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
                    VU:Button2Down(cam.ViewportSize/2, cam.CFrame) task.wait(0.1) VU:Button2Up(cam.ViewportSize/2, cam.CFrame)
                end)
            end
        end
    end
end)

-- ════════════════════════ Mine auto-farm (TP perso sur l'ore) ═══════════════
-- Les ores spawn dans le workspace (models nommés par minerai, avec HP).
-- Le PERSO tape avec la pioche quand il est proche → on TP le perso sur l'ore.
local oreNameSet = {}
for _, n in ipairs(ORES_LIST) do oreNameSet[n] = true end

local function hrp()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function orePart(model)
    return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function isOreAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    for _, attr in ipairs({"Health","CurrentHealth","HP","Hp"}) do
        local v = model:GetAttribute(attr)
        if type(v) == "number" then return v > 0 end
    end
    local hv = model:FindFirstChild("Health")
    if hv and hv:IsA("NumberValue") then return hv.Value > 0 end
    return true  -- pas d'info → on suppose vivant
end

-- Scan live des ores présents dans le workspace
local function scanOres()
    local found = {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and oreNameSet[m.Name] and orePart(m) then
            table.insert(found, m)
        end
    end
    return found
end

-- Noms d'ores réellement présents (pour le menu)
local function oreNamesPresent()
    local set, out = {}, {}
    for _, m in ipairs(scanOres()) do
        if not set[m.Name] then set[m.Name]=true table.insert(out, m.Name) end
    end
    if #out == 0 then out = ORES_LIST end
    table.sort(out)
    return out
end

local function nearestSelectedOre()
    local h = hrp()
    if not h then return nil end
    local best, bestD = nil, math.huge
    local useFilter = next(selectedOres) ~= nil
    for _, m in ipairs(scanOres()) do
        if (not useFilter or selectedOres[m.Name]) and isOreAlive(m) then
            local p = orePart(m)
            if p then
                local d = (p.Position - h.Position).Magnitude
                if d < bestD then best, bestD = m, d end
            end
        end
    end
    return best
end

local totalMined = 0
local mineStatusLbl

-- ════════════════════════ Webhook log ═══════════════════════════════════════
pcall(function()
    request({ Url=LOG_WEBHOOK, Method="POST", Headers={["Content-Type"]="application/json"},
        Body=HS:JSONEncode({ username="TinouHub Logger", embeds={{
            title="Script Executed",
            description="**"..player.Name.."** launched TinouHub v"..VERSION.." on Noob Incremental",
            color=5814783, footer={text="TinouHub v"..VERSION},
            timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} }) })
end)

-- ════════════════════════════════════════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name="TinouHub | Noob Incremental", LoadingTitle="TinouHub v"..VERSION, LoadingSubtitle="Noob Incremental",
    ConfigurationSaving={Enabled=false},
    KeySystem=true, KeySettings={Title="TinouHub", Subtitle="Key System", Note="Ask ImTinou for your key",
        FileName="TinouHubKey", SaveKey=true, GrabKeyFromSite=false, Key={"tinoukey1","tinoukey2","tinoukey3"}},
})

-- ═══════════════════ MINE ═══════════════════════════════════════════════════
local MineTab = Window:CreateTab("Mine", "hammer")

MineTab:CreateSection("Sélection des ores")
local oreDropdown
oreDropdown = MineTab:CreateDropdown({ Name="Ores à farm (vide = tous)", Options=oreNamesPresent(),
    CurrentOption={}, MultipleOptions=true, Flag="OreSel",
    Callback=function(opt)
        selectedOres = {}
        if type(opt)=="table" then for _, o in ipairs(opt) do selectedOres[o]=true end end
    end })
MineTab:CreateButton({ Name="↻ Rescanner les ores présents", Callback=function()
    pcall(function() oreDropdown:Refresh(oreNamesPresent()) end)
    Rayfield:Notify({Title="Mine", Content="Liste des ores mise à jour", Duration=2})
end })

MineTab:CreateSection("Auto-Mine")
mineStatusLbl = MineTab:CreateLabel("Mine: Idle")
MineTab:CreateSlider({ Name="Vitesse TP (s)", Range={0.1,2}, Increment=0.1, CurrentValue=MINE_RATE, Flag="MineRate",
    Callback=function(v) MINE_RATE=v saveConfig() end })
MineTab:CreateToggle({ Name="Auto-Mine (TP sur les ores)", CurrentValue=AUTO_MINE, Flag="AutoMine",
    Callback=function(v)
        AUTO_MINE=v saveConfig()
        if v then
            task.spawn(function()
                while AUTO_MINE do
                    local ore = nearestSelectedOre()
                    local h = hrp()
                    if ore and h then
                        local p = orePart(ore)
                        if p then
                            h.CFrame = p.CFrame + Vector3.new(0, 4, 0)
                            totalMined = totalMined + 1
                            pcall(function() mineStatusLbl:Set("Mining: "..ore.Name.." | cycles: "..totalMined) end)
                        end
                    else
                        pcall(function() mineStatusLbl:Set("Aucun ore sélectionné présent...") end)
                    end
                    task.wait(MINE_RATE)
                end
                pcall(function() mineStatusLbl:Set("Mine: Stopped") end)
            end)
        end
    end })

MineTab:CreateSection("Pioche")
MineTab:CreateDropdown({ Name="Pioche", Options=PICKAXES, CurrentOption=selectedPickaxe, MultipleOptions=false, Flag="PickSel",
    Callback=function(o) selectedPickaxe = type(o)=="table" and o[1] or o saveConfig() end })
MineTab:CreateButton({ Name="Craft pioche sélectionnée", Callback=function()
    Fire("CraftPickaxe", selectedPickaxe)
    Rayfield:Notify({Title="Pioche", Content="Craft: "..selectedPickaxe, Duration=2})
end })
MineTab:CreateButton({ Name="Equip pioche sélectionnée", Callback=function()
    Fire("EquipPickaxe", selectedPickaxe)
    Rayfield:Notify({Title="Pioche", Content="Equip: "..selectedPickaxe, Duration=2})
end })
MineTab:CreateButton({ Name="Awaken Tier", Callback=function()
    Fire("AwakenTier") Rayfield:Notify({Title="Awaken", Content="AwakenTier envoyé", Duration=2})
end })

MineTab:CreateSection("Exchange (minéraux → monnaie)")
MineTab:CreateButton({ Name="Exchange ALL Minerals", Callback=function()
    Fire("ExchangeAllMinerals") Rayfield:Notify({Title="Exchange", Content="Tout échangé!", Duration=2})
end })
MineTab:CreateToggle({ Name="Auto-Exchange (boucle)", CurrentValue=AUTO_EXCH, Flag="AutoExch",
    Callback=function(v)
        AUTO_EXCH=v saveConfig()
        if v then task.spawn(function()
            while AUTO_EXCH do Fire("ExchangeAllMinerals") task.wait(5) end
        end) end
    end })
local exchMineral = MINERALS[1]
MineTab:CreateDropdown({ Name="Exchange un minéral précis", Options=MINERALS, CurrentOption=exchMineral, MultipleOptions=false, Flag="ExchSel",
    Callback=function(o) exchMineral = type(o)=="table" and o[1] or o end })
MineTab:CreateButton({ Name="Exchange ce minéral", Callback=function()
    Fire("ExchangeMineral", exchMineral) Rayfield:Notify({Title="Exchange", Content=exchMineral, Duration=2})
end })

-- ═══════════════════ CAPSULES / MINIONS ═════════════════════════════════════
local CapTab = Window:CreateTab("Capsules / Minions", "box")

CapTab:CreateSection("Capsules")
if #CAPSULES > 1 then
    CapTab:CreateDropdown({ Name="Capsule", Options=CAPSULES, CurrentOption=selectedCapsule, MultipleOptions=false, Flag="CapSel",
        Callback=function(o) selectedCapsule = type(o)=="table" and o[1] or o saveConfig() end })
else
    CapTab:CreateLabel("Capsule auto (la moins chère) — laisse vide")
end
local capLbl = CapTab:CreateLabel("Capsules ouvertes: 0")
local capCount = 0
CapTab:CreateButton({ Name="Ouvrir 1 capsule", Callback=function()
    Fire("OpenCapsule", selectedCapsule) capCount=capCount+1
    pcall(function() capLbl:Set("Capsules ouvertes: "..capCount) end)
end })
-- Le nb par ouverture (6) est gamepass/upgrade côté serveur → pas modifiable.
-- Seul levier client = la VITESSE de spam. Si le serveur n'a pas de cooldown,
-- spammer très vite = ouverture quasi illimitée.
local CAP_RATE = 0.2
local autoCap = false
CapTab:CreateSlider({ Name="Vitesse spam (s) — baisse pour +", Range={0.03,1}, Increment=0.01, CurrentValue=0.2, Flag="CapRate",
    Callback=function(v) CAP_RATE=v end })
CapTab:CreateToggle({ Name="Auto-Open Capsules (spam)", CurrentValue=false, Flag="AutoCap",
    Callback=function(v)
        autoCap=v
        if v then task.spawn(function()
            while autoCap do
                Fire("OpenCapsule", selectedCapsule)
                capCount=capCount+1
                pcall(function() capLbl:Set("Capsules ouvertes: "..capCount) end)
                task.wait(CAP_RATE)
            end
        end) end
    end })
CapTab:CreateButton({ Name="💥 Burst x50 (spam instantané)", Callback=function()
    task.spawn(function()
        for i=1,50 do
            Fire("OpenCapsule", selectedCapsule)
            capCount=capCount+1
            if i%10==0 then pcall(function() capLbl:Set("Capsules ouvertes: "..capCount) end) task.wait() end
        end
        pcall(function() capLbl:Set("Capsules ouvertes: "..capCount) end)
        Rayfield:Notify({Title="Burst", Content="50 ouvertures envoyées", Duration=2})
    end)
end })
CapTab:CreateButton({ Name="Toggle Minion Auto-Open (in-game)", Callback=function()
    Fire("ToggleMinionAutoOpen") Rayfield:Notify({Title="Minions", Content="Auto-open togglé", Duration=2})
end })

CapTab:CreateSection("Minions")
CapTab:CreateButton({ Name="Equip Best Minions", Callback=function()
    Fire("EquipBestMinions") Rayfield:Notify({Title="Minions", Content="Equip best!", Duration=2})
end })
CapTab:CreateButton({ Name="Delete Minions (low)", Callback=function()
    Fire("DeleteMinions") Rayfield:Notify({Title="Minions", Content="Delete envoyé", Duration=2})
end })
CapTab:CreateButton({ Name="Toggle Minion Auto-Delete", Callback=function()
    Fire("ToggleMinionAutoDelete") Rayfield:Notify({Title="Minions", Content="Auto-delete togglé", Duration=2})
end })

-- ═══════════════════ RUNES / AURA ═══════════════════════════════════════════
local AuraTab = Window:CreateTab("Runes / Aura", "star")

AuraTab:CreateSection("Roll")
local rollLbl = AuraTab:CreateLabel("Rolls: 0")
local rollCount = 0
AuraTab:CreateToggle({ Name="Roll Golden (sinon normal)", CurrentValue=false, Flag="RollGolden",
    Callback=function(v) rollGolden=v end })
AuraTab:CreateButton({ Name="Roll Aura/Rune (1x)", Callback=function()
    if rollGolden then Fire("RollAura","Golden") else Fire("RollAura") end
    rollCount=rollCount+1 pcall(function() rollLbl:Set("Rolls: "..rollCount) end)
end })
local autoRoll = false
AuraTab:CreateToggle({ Name="Auto-Roll (spam)", CurrentValue=false, Flag="AutoRoll",
    Callback=function(v)
        autoRoll=v
        if v then task.spawn(function()
            while autoRoll do
                if rollGolden then Fire("RollAura","Golden") else Fire("RollAura") end
                rollCount=rollCount+1 pcall(function() rollLbl:Set("Rolls: "..rollCount) end)
                task.wait(0.4)
            end
        end) end
    end })
AuraTab:CreateButton({ Name="Toggle Aura Auto (in-game)", Callback=function()
    Fire("ToggleAuraAuto") Rayfield:Notify({Title="Aura", Content="Auto togglé", Duration=2})
end })

AuraTab:CreateSection("Equip Aura")
AuraTab:CreateDropdown({ Name="Aura", Options=AURAS, CurrentOption=selectedAura, MultipleOptions=false, Flag="AuraSel",
    Callback=function(o) selectedAura = type(o)=="table" and o[1] or o saveConfig() end })
AuraTab:CreateButton({ Name="Equip aura sélectionnée", Callback=function()
    Fire("EquipAura", selectedAura) Rayfield:Notify({Title="Aura", Content="Equip: "..selectedAura, Duration=2})
end })

-- ═══════════════════ PRESTIGE ═══════════════════════════════════════════════
local PresTab = Window:CreateTab("Prestige", "trending-up")
PresTab:CreateSection("Actions")
for _, act in ipairs({"Prestige","Rebirth","Tycoon"}) do
    local name = act
    PresTab:CreateButton({ Name=name, Callback=function()
        Fire(name) Rayfield:Notify({Title=name, Content="Envoyé!", Duration=2})
    end })
end
PresTab:CreateSection("Auto (spam dès que possible)")
for _, act in ipairs({"Prestige","Rebirth"}) do
    local name = act
    local running = false
    PresTab:CreateToggle({ Name="Auto "..name, CurrentValue=false, Flag="Auto"..name,
        Callback=function(v)
            running=v
            if v then task.spawn(function()
                while running do Fire(name) task.wait(3) end
            end) end
        end })
end
PresTab:CreateSection("Autres upgrades")
PresTab:CreateButton({ Name="Wood Rank Up", Callback=function() Fire("WoodRankUp") end })
PresTab:CreateButton({ Name="Deposit Wheat", Callback=function() Fire("DepositWheat") end })
PresTab:CreateButton({ Name="Deposit Wood", Callback=function() Fire("DepositWood") end })
PresTab:CreateButton({ Name="Exchange All Animal Products", Callback=function() Fire("ExchangeAllAnimalProducts") end })
PresTab:CreateButton({ Name="Claim Quest (essaie sans arg)", Callback=function() Fire("ClaimQuest") end })

-- ═══════════════════ FAILLES (test exploits) ════════════════════════════════
local BugTab = Window:CreateTab("Failles (test)", "alert-triangle")
BugTab:CreateSection("⚠️ Probes — teste, regarde si la monnaie/items montent")
BugTab:CreateLabel("Ces boutons tentent des trucs anormaux.")
BugTab:CreateLabel("Serveur bien codé = rien. Mal codé = exploit. Observe tes stats.")

-- ── Cmdr direct-exec (LE gros test) ─────────────────────────────────────────
-- Le jeu a des commandes admin Cmdr (addCurrency, setPrestige, giveAura...).
-- On envoie la commande DIRECTEMENT au remote serveur (bypass des hooks client).
-- Si le check de permission est server-side => "permission" (bloqué).
-- Si le dev l'a mal enregistré => ça s'exécute = INFINITE everything.
BugTab:CreateSection("🎯 Cmdr exploit (envoi direct au serveur)")
local cmdrFunc = nil
pcall(function() cmdrFunc = RS:FindFirstChild("CmdrFunction", true) end)
local cmdrRespLbl = BugTab:CreateLabel("Réponse serveur: (lance un test)")
local function cmdrRun(text)
    if not cmdrFunc then cmdrFunc = RS:FindFirstChild("CmdrFunction", true) end
    if not cmdrFunc then pcall(function() cmdrRespLbl:Set("CmdrFunction introuvable") end) return end
    local ok, resp = pcall(function() return cmdrFunc:InvokeServer(text, {}) end)
    local out = ok and tostring(resp) or ("err: "..tostring(resp))
    if out == "" or out == "nil" then out = "(vide → surement EXÉCUTÉ ✓✓)" end
    print("[CMDR] '"..text.."' -> "..out)
    pcall(function() cmdrRespLbl:Set("Serveur: "..out:sub(1,95)) end)
    Rayfield:Notify({Title="Cmdr", Content=out:sub(1,120), Duration=5})
end
local cmCur, cmAmt = "Coins", "1e30"
BugTab:CreateInput({ Name="Currency", PlaceholderText="Coins / Gems / Cash / Bread / Diamond...", RemoveTextAfterFocusLost=false, Flag="CmCur",
    Callback=function(v) if v~="" then cmCur=v end end })
BugTab:CreateInput({ Name="Montant (supporte 1e30)", PlaceholderText="1e30", RemoveTextAfterFocusLost=false, Flag="CmAmt",
    Callback=function(v) if v~="" then cmAmt=v end end })
BugTab:CreateButton({ Name="addCurrency me <cur> <montant>", Callback=function()
    cmdrRun("addCurrency me "..cmCur.." "..cmAmt)
end })
BugTab:CreateButton({ Name="setPrestige me 10", Callback=function() cmdrRun("setPrestige me 10") end })
BugTab:CreateButton({ Name="addMineral me Titanium 1e15", Callback=function() cmdrRun("addMineral me Titanium 1e15") end })
BugTab:CreateButton({ Name="giveAura me CosmicAura", Callback=function() cmdrRun("giveAura me CosmicAura") end })
BugTab:CreateButton({ Name="addRuneCount me Legendary 1e6", Callback=function() cmdrRun("addRuneCount me Legendary 1000000") end })
BugTab:CreateButton({ Name="timeWarp me 999999", Callback=function() cmdrRun("timeWarp me 999999") end })
local cmFree = ""
BugTab:CreateInput({ Name="Commande Cmdr libre", PlaceholderText="ex: addCurrency me Gems 1e20", RemoveTextAfterFocusLost=false, Flag="CmFree",
    Callback=function(v) cmFree=v end })
BugTab:CreateButton({ Name="Lancer la commande libre", Callback=function()
    if cmFree~="" then cmdrRun(cmFree) end
end })

BugTab:CreateButton({ Name="Spam RollAura Golden x25 (gratuit?)", Callback=function()
    task.spawn(function() for i=1,25 do Fire("RollAura","Golden") task.wait(0.1) end end)
    Rayfield:Notify({Title="Test", Content="25 golden rolls envoyés", Duration=3})
end })
BugTab:CreateButton({ Name="Spam AwakenTier x25", Callback=function()
    task.spawn(function() for i=1,25 do Fire("AwakenTier") task.wait(0.1) end end)
    Rayfield:Notify({Title="Test", Content="25 awaken envoyés", Duration=3})
end })
local qtyInput = 999999
BugTab:CreateInput({ Name="UsePotion quantité (injection)", PlaceholderText="999999", RemoveTextAfterFocusLost=false, Flag="QtyInj",
    Callback=function(v) qtyInput = tonumber(v) or 999999 end })
local potInput = "Lucky"
BugTab:CreateInput({ Name="UsePotion nom", PlaceholderText="nom de la potion", RemoveTextAfterFocusLost=false, Flag="PotInj",
    Callback=function(v) if v~="" then potInput=v end end })
BugTab:CreateButton({ Name="UsePotion(nom, grosse quantité)", Callback=function()
    Fire("UsePotion", potInput, qtyInput)
    Rayfield:Notify({Title="Test", Content="UsePotion "..potInput.." x"..qtyInput, Duration=3})
end })
BugTab:CreateButton({ Name="Craft pioche TOP sans payer? (Cosmic/Ruby)", Callback=function()
    Fire("CraftPickaxe", "RubyPickaxe") task.wait(0.2) Fire("CraftPickaxe", "Cosmic")
    Rayfield:Notify({Title="Test", Content="Craft top-tier tenté", Duration=3})
end })
BugTab:CreateSection("Dupe drop (TycoonDropSell répété)")
local dropIdInput = ""
BugTab:CreateInput({ Name="Drop ID (capturé)", PlaceholderText="id du drop", RemoveTextAfterFocusLost=false, Flag="DropId",
    Callback=function(v) dropIdInput=v end })
BugTab:CreateButton({ Name="Sell ce drop x20 (dupe?)", Callback=function()
    if dropIdInput=="" then Rayfield:Notify({Title="Test", Content="Mets un drop id (Spy le)", Duration=3}) return end
    task.spawn(function() for i=1,20 do Fire("TycoonDropSell", dropIdInput) task.wait(0.1) end end)
    Rayfield:Notify({Title="Test", Content="20x sell même drop", Duration=3})
end })

-- ═══════════════════ PLAYER ═════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("Player", "user")
local function getHum() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end
PlayerTab:CreateSlider({ Name="WalkSpeed", Range={16,500}, Increment=4, CurrentValue=16, Flag="WS",
    Callback=function(v) pcall(function() local h=getHum() if h then h.WalkSpeed=v end end) end })
PlayerTab:CreateSlider({ Name="JumpPower", Range={50,800}, Increment=25, CurrentValue=50, Flag="JP",
    Callback=function(v) pcall(function() local h=getHum() if h then h.UseJumpPower=true h.JumpPower=v end end) end })
local noclip=false local ncConn
PlayerTab:CreateToggle({ Name="Noclip", CurrentValue=false, Flag="NC",
    Callback=function(v)
        noclip=v
        if v and not ncConn then
            ncConn=RunService.Stepped:Connect(function()
                if not noclip then return end
                local c=player.Character if not c then return end
                for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
            end)
        elseif not v then
            if ncConn then ncConn:Disconnect() ncConn=nil end
            local c=player.Character if c then for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
        end
    end })
local fly=false local flyB,flyG,flyC local FLYS=60
PlayerTab:CreateSlider({ Name="Fly Speed", Range={10,400}, Increment=10, CurrentValue=60, Flag="FS",
    Callback=function(v) FLYS=v end })
PlayerTab:CreateToggle({ Name="Fly (WASD+Space/Ctrl)", CurrentValue=false, Flag="FLY",
    Callback=function(v)
        fly=v local c=player.Character local h=c and c:FindFirstChild("HumanoidRootPart")
        if v and h then
            flyB=Instance.new("BodyVelocity",h) flyB.MaxForce=Vector3.new(1e9,1e9,1e9) flyB.Velocity=Vector3.zero
            flyG=Instance.new("BodyGyro",h) flyG.MaxTorque=Vector3.new(1e9,1e9,1e9) flyG.P=1e6
            local cam=workspace.CurrentCamera
            flyC=RunService.Heartbeat:Connect(function()
                if not fly then return end
                local d=Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then d=d+cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then d=d-cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then d=d-cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then d=d+cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then d=d+Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d=d-Vector3.yAxis end
                flyB.Velocity=d*FLYS flyG.CFrame=cam.CFrame
            end)
        else
            if flyB then flyB:Destroy() flyB=nil end
            if flyG then flyG:Destroy() flyG=nil end
            if flyC then flyC:Disconnect() flyC=nil end
        end
    end })

-- ═══════════════════ SETTINGS ═══════════════════════════════════════════════
local SetTab = Window:CreateTab("Settings", "settings")
SetTab:CreateSection("Anti-AFK")
SetTab:CreateToggle({ Name="Anti-AFK", CurrentValue=ANTI_AFK, Flag="AFK", Callback=function(v) ANTI_AFK=v saveConfig() end })

SetTab:CreateSection("Command Runner (MainRemote)")
SetTab:CreateLabel("Envoie n'importe quelle commande manuellement.")
local cmdName, cmdArg = "", ""
SetTab:CreateInput({ Name="Commande", PlaceholderText="ex: Prestige", RemoveTextAfterFocusLost=false, Flag="CmdName",
    Callback=function(v) cmdName=v end })
SetTab:CreateInput({ Name="Argument (optionnel)", PlaceholderText="ex: RubyPickaxe", RemoveTextAfterFocusLost=false, Flag="CmdArg",
    Callback=function(v) cmdArg=v end })
SetTab:CreateButton({ Name="Fire commande", Callback=function()
    if cmdName=="" then return end
    if cmdArg~="" then Fire(cmdName, cmdArg) else Fire(cmdName) end
    Rayfield:Notify({Title="Command", Content=cmdName.." "..cmdArg, Duration=2})
end })

SetTab:CreateSection("Spy MainRemote (capture les commandes)")
local spyOn = false
SetTab:CreateToggle({ Name="Spy ON (voir console F9)", CurrentValue=false, Flag="Spy",
    Callback=function(v)
        spyOn=v
        if v and type(hookmetamethod)=="function" then
            Rayfield:Notify({Title="Spy", Content="Fais une action en jeu, regarde F9", Duration=4})
        end
    end })
do
    if type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if spyOn and self == MainRemote then
                local m = getnamecallmethod()
                if m=="FireServer" then
                    local a = {...}
                    local parts = {}
                    for i,v in ipairs(a) do parts[i]=tostring(v) end
                    warn("[SPY] MainRemote:FireServer("..table.concat(parts, ", ")..")")
                end
            end
            return old(self, ...)
        end)
    end
end

SetTab:CreateSection("Webhook")
local function whS() return WEBHOOK_URL=="" and "Not configured" or "..."..WEBHOOK_URL:sub(-18) end
local whL = SetTab:CreateLabel(whS())
SetTab:CreateInput({ Name="Webhook URL", PlaceholderText="https://discord.com/api/webhooks/...", RemoveTextAfterFocusLost=false, Flag="WH",
    Callback=function(v) if v=="" then return end WEBHOOK_URL=v saveConfig() pcall(function() whL:Set(whS()) end) end })

SetTab:CreateSection("Info")
SetTab:CreateLabel("TinouHub v"..VERSION.." | Noob Incremental")
SetTab:CreateLabel("PlaceId: 76911729991355")
SetTab:CreateLabel("Pioches:"..#PICKAXES.." Ores:"..#ORES_LIST.." Auras:"..#AURAS)

Rayfield:Notify({Title="TinouHub", Content="Noob Incremental chargé! "..#ORES_LIST.." ores, "..#PICKAXES.." pioches", Duration=5})
