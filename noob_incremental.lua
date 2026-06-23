local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")
local UIS        = game:GetService("UserInputService")
local RunS       = game:GetService("RunService")
local TPS        = game:GetService("TeleportService")

local VERSION   = "1.4.1"
local SAVE_FILE = "tinouhub_noob_config.json"

-- ════════════════════════ Session ═══════════════════════════════════════════
-- À chaque (re)lancement, l'ancienne instance est invalidée: toutes ses boucles
-- (auto-mine, auto-exchange, anti-afk) s'arrêtent net via active().
local _env = (type(getgenv) == "function") and getgenv() or _G
local SESSION = {}
_env.TINOUHUB_SESSION = SESSION
local function active() return _env.TINOUHUB_SESSION == SESSION end

-- ════════════════════════ Discord (webhook) ═════════════════════════════════
local WEBHOOK, DISCORD_ON = "", false
local function httpRequest(opts)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) ~= "function" then return nil end
    return (select(2, pcall(req, opts)))
end
local function discordLog(title, desc, color)
    if not DISCORD_ON or WEBHOOK == "" then return end
    task.spawn(function()
        pcall(function()
            local body = HS:JSONEncode({
                username = "TinouHub",
                embeds = {{ title = title, description = desc, color = color or 5814783,
                    footer = { text = "TinouHub v"..VERSION.." • "..player.Name } }}
            })
            httpRequest({ Url = WEBHOOK, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
    end)
end

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

-- Dossier des ores du jeu: Workspace.__GAME_CONTENT.Ores (source de vérité)
local function findOreFolder()
    local f
    pcall(function()
        local gc = workspace:FindFirstChild("__GAME_CONTENT")
        f = gc and gc:FindFirstChild("Ores")
    end)
    return f
end
local ORE_FALLBACK = {"Aetherite","Celestium","Coal","Cobalt","Copper","Gold","Infinity",
    "Iron","Palladium","Platinum","Ruby","Silver","Titanium","Uranium","Voidsteel"}
local function liveOreNames()
    local f, out = findOreFolder(), {}
    if f then for _, c in ipairs(f:GetChildren()) do if c:IsA("Model") then table.insert(out, c.Name) end end end
    if #out == 0 then for _, n in ipairs(ORE_FALLBACK) do table.insert(out, n) end end
    table.sort(out)
    return out
end
local ORES_LIST = liveOreNames()

-- ════════════════════════ Config ════════════════════════════════════════════
local MINE_RATE = 0.35
local AUTO_MINE, AUTO_EXCH, ANTI_AFK = false, false, true
local AUTO_PICK, AUTO_AWAKEN = false, false
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
-- nudge physique du perso: se réplique comme un vrai déplacement => bat les
-- systèmes AFK custom qui surveillent le mouvement (pas seulement l'input)
local function jitterMove()
    local h = (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
    if not h then return false end
    return (pcall(function()
        local cf = h.CFrame
        h.CFrame = cf * CFrame.new(0, 0.4, 0)
        task.wait(0.12)
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then h.CFrame = cf end
    end))
end
-- désactive le script AFK CLIENT du jeu (PlayerScripts...ClientLauncher.AFKScript)
local KILL_GAME_AFK = true
local function killGameAFK()
    if not KILL_GAME_AFK then return end
    pcall(function()
        local ps = player:FindFirstChild("PlayerScripts")
        if not ps then return end
        local afk = ps:FindFirstChild("AFKScript", true)
        if afk then afk.Disabled = true afk:Destroy() end
    end)
end
killGameAFK()
task.delay(3, killGameAFK)  -- au cas où il se charge un peu après

player.Idled:Connect(function()
    if not active() or not ANTI_AFK then return end
    pulseInput()
    pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while active() do task.wait(40)
        if active() and ANTI_AFK then
            pulseInput()
            -- bouge seulement si l'auto-mine ne le fait pas déjà
            if not AUTO_MINE then jitterMove() end
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

local oreFolder = findOreFolder()
local function scanOres()
    local found = {}
    -- priorité au dossier Ores du jeu; on prend chaque Model enfant
    if oreFolder then
        for _, m in ipairs(oreFolder:GetChildren()) do
            if m:IsA("Model") and orePart(m) then table.insert(found, m) end
        end
        if #found > 0 then return found end
    end
    -- fallback: scan global par nom si le dossier n'est pas trouvé
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and oreNameSet[m.Name] and orePart(m) then
            if not oreFolder and m.Parent then oreFolder = m.Parent end
            table.insert(found, m)
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
    ConfigurationSaving={Enabled=true, FolderName="TinouHub", FileName="NoobIncremental"},
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
    oreFolder=findOreFolder()
    pcall(function() oreDropdown:Refresh(oreNamesPresent()) end)
    Rayfield:Notify({Title="Mine", Content="Ores rescannés ("..#oreNamesPresent().." types)", Duration=2})
end })
MineTab:CreateButton({ Name="🐛 Debug ores (copie les noms)", Callback=function()
    local h = hrp()
    local origin = h and h.Position or Vector3.new()
    local seen, lines = {}, {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") then
            local p = orePart(m)
            if p then
                local d = (p.Position - origin).Magnitude
                if d <= 600 then
                    local key = m.Name
                    if not seen[key] then
                        seen[key] = true
                        local hum = m:FindFirstChildOfClass("Humanoid")
                        table.insert(lines, string.format("%-22s | %s | %s | %dst",
                            m.Name, m:GetFullName(), hum and "HP="..tostring(hum.Health) or "noHum", math.floor(d)))
                    end
                end
            end
        end
    end
    table.sort(lines)
    local dump = "ORE DEBUG ("..#lines.." modèles uniques <600st):\n"..table.concat(lines,"\n")
    print(dump)
    pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Debug", Content=#lines.." modèles trouvés — copié + console (F9)", Duration=5})
end })

MineTab:CreateSection("Auto-Mine")
mineStatusLbl = MineTab:CreateLabel("Mine: Idle")
MineTab:CreateSlider({ Name="Vitesse TP (s)", Range={0.1,2}, Increment=0.05, CurrentValue=MINE_RATE, Flag="MineRate",
    Callback=function(v) MINE_RATE=v saveConfig() end })
MineTab:CreateToggle({ Name="Auto-Mine (reste sur l'ore jusqu'à le casser)", CurrentValue=false, Flag="AutoMine",
    Callback=function(v)
        AUTO_MINE=v
        discordLog(v and "⛏️ Auto-Mine ON" or "⏹️ Auto-Mine OFF", "Total cassés: **"..totalMined.."**", v and 3066993 or 15158332)
        if v then task.spawn(function()
            while AUTO_MINE and active() do
                local ore = nearestAliveOre()
                if ore then
                    -- reste sur CET ore tant qu'il est vivant et existe
                    while AUTO_MINE and active() and ore.Parent and isOreAlive(ore) do
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
MineTab:CreateToggle({ Name="Auto-Craft + Equip pioche (3s)", CurrentValue=false, Flag="AutoPick",
    Callback=function(v) AUTO_PICK=v if v then task.spawn(function()
        while active() and AUTO_PICK do Fire("CraftPickaxe", selectedPickaxe) task.wait(0.2) Fire("EquipPickaxe", selectedPickaxe) task.wait(3) end
    end) end end })
MineTab:CreateToggle({ Name="Auto-Awaken Tier (3s)", CurrentValue=false, Flag="AutoAwaken",
    Callback=function(v) AUTO_AWAKEN=v if v then task.spawn(function() while active() and AUTO_AWAKEN do Fire("AwakenTier") task.wait(3) end end) end end })

MineTab:CreateSection("Exchange minéraux")
MineTab:CreateButton({ Name="Exchange ALL", Callback=function() Fire("ExchangeAllMinerals") Rayfield:Notify({Title="Exchange",Content="Tout échangé",Duration=2}) end })
MineTab:CreateToggle({ Name="Auto-Exchange (5s)", CurrentValue=false, Flag="AutoExch",
    Callback=function(v) AUTO_EXCH=v if v then task.spawn(function() while AUTO_EXCH and active() do Fire("ExchangeAllMinerals") task.wait(5) end end) end end })

-- ═══════════════════ PLAYER ═════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("Player", "user")
local function humanoid() local c=player.Character return c and c:FindFirstChildOfClass("Humanoid") end

PlayerTab:CreateSection("Mouvement")
local WALK_SPEED, JUMP_POWER = 16, 50
PlayerTab:CreateSlider({ Name="WalkSpeed", Range={16,200}, Increment=2, CurrentValue=16, Flag="WalkSpd",
    Callback=function(v) WALK_SPEED=v local h=humanoid() if h then h.WalkSpeed=v end end })
PlayerTab:CreateSlider({ Name="JumpPower", Range={50,300}, Increment=5, CurrentValue=50, Flag="JumpPwr",
    Callback=function(v) JUMP_POWER=v local h=humanoid() if h then h.UseJumpPower=true h.JumpPower=v end end })
-- réapplique vitesse/saut à chaque respawn
player.CharacterAdded:Connect(function()
    task.wait(0.5)
    local h=humanoid()
    if h then if WALK_SPEED~=16 then h.WalkSpeed=WALK_SPEED end if JUMP_POWER~=50 then h.UseJumpPower=true h.JumpPower=JUMP_POWER end end
end)

local INF_JUMP=false
PlayerTab:CreateToggle({ Name="Saut infini", CurrentValue=false, Flag="InfJump", Callback=function(v) INF_JUMP=v end })
UIS.JumpRequest:Connect(function()
    if active() and INF_JUMP then local h=humanoid() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

local NOCLIP=false
PlayerTab:CreateToggle({ Name="Noclip (traverse les murs)", CurrentValue=false, Flag="Noclip", Callback=function(v) NOCLIP=v end })
RunS.Stepped:Connect(function()
    if not active() or not NOCLIP then return end
    local c=player.Character
    if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end end
end)

PlayerTab:CreateSection("Téléport")
PlayerTab:CreateButton({ Name="↺ Reset perso (respawn)", Callback=function()
    local h=humanoid() if h then h.Health=0 end
end })

-- ═══════════════════ SETTINGS ═══════════════════════════════════════════════
local SetTab = Window:CreateTab("Settings", "settings")
SetTab:CreateSection("Serveur")
SetTab:CreateButton({ Name="🔁 Rejoin (même serveur)", Callback=function()
    pcall(function() TPS:Teleport(game.PlaceId, player) end)
end })
SetTab:CreateButton({ Name="🔀 Server hop (nouveau serveur)", Callback=function()
    pcall(function() TPS:Teleport(game.PlaceId) end)
end })
SetTab:CreateButton({ Name="🔄 Reload script", Callback=function()
    -- coupe TOUT (auto-mine, auto-exchange, anti-afk) avant de recharger
    AUTO_MINE, AUTO_EXCH, ANTI_AFK = false, false, false
    AUTO_PICK, AUTO_AWAKEN = false, false
    _env.TINOUHUB_SESSION = nil
    pcall(function() Rayfield:Destroy() end)
    task.wait(0.3)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ImTinou/sword/main/noob_incremental.lua?v="..tostring(os.time())))()
end })
SetTab:CreateToggle({ Name="Anti-AFK (input + mouvement)", CurrentValue=ANTI_AFK, Flag="AFK", Callback=function(v) ANTI_AFK=v saveConfig() end })
SetTab:CreateToggle({ Name="Désactiver l'AFK du jeu (AFKScript)", CurrentValue=true, Flag="KillAFK",
    Callback=function(v) KILL_GAME_AFK=v if v then killGameAFK() end end })

SetTab:CreateSection("Debug système du jeu")
local function argToStr(a)
    local t = typeof(a)
    if t=="Instance" then return "Instance "..a.ClassName.." -> "..a:GetFullName()
    elseif t=="table" then local n=0 for _ in pairs(a) do n=n+1 end return "table("..n.." clés)"
    else return t.." "..tostring(a) end
end
-- Spy universel: logge TOUS les FireServer du client pendant une fenêtre de temps
_env.TINOUHUB_SPYLOG = _env.TINOUHUB_SPYLOG or {}        -- lignes capturées (dédup)
_env.TINOUHUB_SPYUNTIL = _env.TINOUHUB_SPYUNTIL or 0     -- fenêtre active jusqu'à
local function installUniversalSpy()
    if _env.TINOUHUB_SPY_INSTALLED then return true end
    local sample = nil
    for _, d in ipairs(RS:GetDescendants()) do if d:IsA("RemoteEvent") then sample=d break end end
    if not sample then return false end
    local ok = pcall(function()
        local old
        old = hookfunction(sample.FireServer, newcclosure(function(self, ...)
            if os.clock() < _env.TINOUHUB_SPYUNTIL then
                local name = (typeof(self)=="Instance") and self.Name or tostring(self)
                local parts = {}
                for i=1,select("#",...) do parts[i]=argToStr((select(i,...))) end
                local line = name.."("..table.concat(parts,", ")..")"
                if not _env.TINOUHUB_SPYLOG[line] then
                    _env.TINOUHUB_SPYLOG[line] = true
                    print("[SPY] "..line)
                end
            end
            return old(self, ...)
        end))
        _env.TINOUHUB_SPY_INSTALLED = true
    end)
    return ok
end
SetTab:CreateButton({ Name="🕵️ Spy TOUS remotes (8s — mine pendant!)", Callback=function()
    if not installUniversalSpy() then
        Rayfield:Notify({Title="Spy", Content="hookfunction non supporté par Delta?", Duration=6}) return
    end
    _env.TINOUHUB_SPYLOG = {}                 -- reset dédup pour cette session
    _env.TINOUHUB_SPYUNTIL = os.clock() + 8
    Rayfield:Notify({Title="Spy", Content="MINE MAINTENANT (8s) — résultats en console F9", Duration=8})
    task.delay(8.2, function()
        local keys = {}
        for k in pairs(_env.TINOUHUB_SPYLOG) do table.insert(keys, k) end
        table.sort(keys)
        local dump = "=== REMOTES ENVOYÉS PENDANT LE MINAGE ("..#keys..") ===\n"..table.concat(keys, "\n")
        print(dump) pcall(function() setclipboard(dump) end)
        Rayfield:Notify({Title="Spy", Content=#keys.." remotes capturés — copié + F9", Duration=6})
    end)
end })
SetTab:CreateButton({ Name="📡 Dump remotes + scripts AFK", Callback=function()
    local lines = {}
    -- 1) tous les remotes (events/functions) du jeu
    table.insert(lines, "=== REMOTES ===")
    for _, svc in ipairs({RS, workspace, game:GetService("Players")}) do
        pcall(function()
            for _, d in ipairs(svc:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") then
                    table.insert(lines, d.ClassName.." | "..d:GetFullName())
                end
            end
        end)
    end
    -- 2) scripts/modules dont le nom évoque l'AFK/idle/kick/mine
    table.insert(lines, "")
    table.insert(lines, "=== SCRIPTS (afk/idle/kick/mine) ===")
    for _, d in ipairs(game:GetDescendants()) do
        if (d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Script")) then
            local n = string.lower(d.Name)
            if n:find("afk") or n:find("idle") or n:find("kick") or n:find("mine") or n:find("antiafk") then
                table.insert(lines, d.ClassName.." | "..d:GetFullName())
            end
        end
    end
    local dump = table.concat(lines, "\n")
    print(dump)
    pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Debug", Content=#lines.." lignes — copié + console (F9)", Duration=5})
end })

SetTab:CreateSection("Exploration (sonde le jeu)")
-- sérialiseur lisible (tables/instances/fonctions), profondeur limitée
local function serialize(v, depth, seen)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then return "<"..v.ClassName..":"..v.Name..">"
    elseif t == "table" then
        if depth > 3 then return "{...}" end
        seen = seen or {}
        if seen[v] then return "<cycle>" end
        seen[v] = true
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 50 then table.insert(parts, "...") break end
            table.insert(parts, tostring(k).." = "..serialize(val, depth+1, seen))
        end
        return "{ "..table.concat(parts, ", ").." }"
    elseif t == "function" then return "<function>"
    elseif t == "string" then return '"'..v..'"'
    else return tostring(v) end
end
local function publish(title, body)
    local dump = "=== "..title.." ===\n"..body
    print(dump) pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Explore", Content=title.." — copié + F9", Duration=5})
end
-- invoque une RemoteFunction et dump le résultat (ex: tes données joueur)
SetTab:CreateButton({ Name="🔍 Dump mes données (GetPlayerData)", Callback=function()
    local rf = RS:FindFirstChild("GetPlayerData", true) or RS:FindFirstChild("GetMyData", true)
    if not rf then Rayfield:Notify({Title="Explore",Content="GetPlayerData introuvable",Duration=4}) return end
    local ok, res = pcall(function() return rf:InvokeServer() end)
    publish("GetPlayerData", ok and serialize(res) or ("erreur: "..tostring(res)))
end })
-- require un module du jeu et dump son contenu
SetTab:CreateButton({ Name="📦 Dump module Minerals", Callback=function()
    local mod = loadModule(SMF, "Minerals")
    publish("Module Minerals", mod and serialize(mod) or "module introuvable / non-requireable")
end })
-- spy ciblé MainRemote: capture les commandes quand tu fais une action (8s)
SetTab:CreateButton({ Name="🕵️ Spy MainRemote (8s — fais une action!)", Callback=function()
    if not installUniversalSpy() then
        Rayfield:Notify({Title="Spy", Content="hookfunction non supporté?", Duration=5}) return
    end
    _env.TINOUHUB_SPYLOG = {}
    _env.TINOUHUB_SPYUNTIL = os.clock() + 8
    Rayfield:Notify({Title="Spy", Content="FAIS UNE ACTION (achat/prestige/exchange) — 8s", Duration=8})
    task.delay(8.2, function()
        local keys = {}
        for k in pairs(_env.TINOUHUB_SPYLOG) do table.insert(keys, k) end
        table.sort(keys)
        publish("ACTIONS CAPTURÉES ("..#keys..")", table.concat(keys, "\n"))
    end)
end })

SetTab:CreateSection("Logs Discord")
SetTab:CreateInput({ Name="Webhook URL", CurrentValue=WEBHOOK, PlaceholderText="https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost=false, Flag="Webhook", Callback=function(t) WEBHOOK = t or "" end })
SetTab:CreateToggle({ Name="Activer les logs Discord", CurrentValue=false, Flag="DiscordOn",
    Callback=function(v) DISCORD_ON=v if v then discordLog("✅ Logs activés", "Sur **"..player.Name.."**", 5763719) end end })
SetTab:CreateButton({ Name="📨 Test webhook", Callback=function()
    if WEBHOOK=="" then Rayfield:Notify({Title="Discord",Content="Mets d'abord l'URL du webhook",Duration=4}) return end
    local saved=DISCORD_ON DISCORD_ON=true
    discordLog("📨 Test webhook", "Si tu lis ça, le webhook marche ✅", 16776960)
    DISCORD_ON=saved
    Rayfield:Notify({Title="Discord",Content="Test envoyé (check ton salon)",Duration=3})
end })

SetTab:CreateSection("Info")
SetTab:CreateLabel("TinouHub v"..VERSION.." | Noob Incremental")
SetTab:CreateLabel("Ores:"..#ORES_LIST.." Pioches:"..#PICKAXES)

-- recharge les valeurs sauvées (sliders, toggles, dropdowns, webhook...)
pcall(function() Rayfield:LoadConfiguration() end)
task.delay(1, function() discordLog("🟢 Script lancé", "**"..player.Name.."** a chargé TinouHub", 5763719) end)

Rayfield:Notify({Title="TinouHub", Content="Mining v"..VERSION.." chargé!", Duration=4})
