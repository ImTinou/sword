local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player     = game:GetService("Players").LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local HS         = game:GetService("HttpService")
local VU         = game:GetService("VirtualUser")
local UIS        = game:GetService("UserInputService")
local RunS       = game:GetService("RunService")
local TPS        = game:GetService("TeleportService")

local VERSION   = "1.9.0"
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
local function discordLog(title, desc, color, force)
    if (not DISCORD_ON and not force) or WEBHOOK == "" then return end
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
local MINE_PAUSED = false  -- mis à true par l'auto-rune le temps d'ouvrir
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

-- parse un nombre avec suffixe d'idle game ("1.2M", "77.9k", "3.4Qa"...)
-- suffixes idle du jeu (k,M,B,T,Qd,Qn,Sx,Sp,Oc,No,De,UDe,DDe,...,Vt,UVt,...)
local UNITS = {}
do
    local base = {"k","m","b","t","qd","qn","sx","sp","oc","no"}     -- 1e3 .. 1e30
    for i, s in ipairs(base) do UNITS[s] = 10 ^ (3 * i) end
    UNITS["qa"] = 1e15  -- alias (certains jeux écrivent Qa au lieu de Qd)
    UNITS["de"] = 1e33
    local pre = {"u","d","t","qd","qn","sx","sp","oc","no"}          -- *De: 1e36 .. 1e60
    for i, p in ipairs(pre) do UNITS[p.."de"] = 10 ^ (33 + 3 * i) end
    UNITS["vt"] = 1e63
    for i, p in ipairs(pre) do UNITS[p.."vt"] = 10 ^ (63 + 3 * i) end -- *Vt: 1e66 ..
end
local function parseBig(s)
    if not s then return nil end
    s = tostring(s):gsub(",", "")
    local direct = tonumber(s)           -- gère "1.42e22", "1500", "10"...
    if direct then return direct end
    local num, suf = s:match("([%-%d%.]+)%s*(%a*)")
    local n = tonumber(num)
    if not n then return nil end
    if suf and suf ~= "" then local mult = UNITS[suf:lower()] if mult then n = n * mult end end
    return n
end
-- vie de l'ore lue dans le TextLabel "Health" ("cur / max") -> cur, max, texte brut
local function oreHealth(m)
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "Health" and d.Text and d.Text ~= "" then
            local a, b = d.Text:match("([%d%.,%a%-]+)%s*/%s*([%d%.,%a%-]+)")
            if a then return parseBig(a), parseBig(b), d.Text end
            return nil, nil, d.Text
        end
    end
    return nil
end
local function isOreAlive(m)
    local cur = oreHealth(m)
    if cur ~= nil then return cur > 0 end
    -- fallback: textes "Respawn"/0 ou Humanoid
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
-- dégâts de la pioche (GetPlayerData.CURRENCIES.PickaxeDamage), caché 20s
local _dmgCache, _dmgAt = nil, -999
local function pickaxeDamage()
    if _dmgCache and (os.clock() - _dmgAt) < 20 then return _dmgCache end
    pcall(function()
        local rf = RS:FindFirstChild("GetPlayerData", true)
        local d = rf and rf:InvokeServer()
        local pd = type(d)=="table" and d.CURRENCIES and d.CURRENCIES.PickaxeDamage
        local v = pd and (pd.TotalMultiplier or pd.NaturalMultiplier)
        local n = v and parseBig(v)
        if n and n > 0 then _dmgCache, _dmgAt = n, os.clock() end
    end)
    return _dmgCache
end
-- rentabilité d'un ore = récompense * dégâts / HP_max (= récompense par coup)
local AUTO_FOCUS = false
local MAX_HITS = 10   -- plafond de coups pour casser (évite Infinity & co)
-- choisit l'ore cible: plus grosse HP cassable en <= MAX_HITS si AUTO_FOCUS, sinon le plus proche
local function pickTarget()
    local list = aliveSelectedOres()
    if #list == 0 then return nil end
    if AUTO_FOCUS then
        local dmg = pickaxeDamage() or 1
        local best, bestHP = nil, -1
        for _, m in ipairs(list) do
            local _, mx = oreHealth(m)
            if mx and mx > 0 and (mx / dmg) <= MAX_HITS and mx > bestHP then
                best, bestHP = m, mx
            end
        end
        if best then return best end
        -- aucun sous le plafond: prend le plus FACILE (plus petite HP) pour pas rester bloqué
        local easy, eHP = nil, math.huge
        for _, m in ipairs(list) do
            local _, mx = oreHealth(m)
            if mx and mx > 0 and mx < eHP then easy, eHP = m, mx end
        end
        if easy then return easy end
    end
    local h = hrp()
    if not h then return list[1] end
    local best, bd = nil, math.huge
    for _, m in ipairs(list) do
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
              if MINE_PAUSED then
                pcall(function() mineStatusLbl:Set("Minage en pause (rune)") end)
                task.wait(0.3)
              else
                local ore = pickTarget()
                if ore then
                    -- reste sur CET ore tant qu'il est vivant et existe
                    while AUTO_MINE and active() and not MINE_PAUSED and ore.Parent and isOreAlive(ore) do
                        local h, p = hrp(), orePart(ore)
                        if h and p then h.CFrame = p.CFrame + Vector3.new(0,4,0) end
                        pcall(function()
                            local cur, mx, raw = oreHealth(ore)
                            local hp = raw and (" | HP "..raw..((cur and mx and mx>0) and (" ("..math.floor(cur/mx*100).."%)") or "")) or ""
                            mineStatusLbl:Set("Mining "..ore.Name..hp.." | cassés: "..totalMined)
                        end)
                        task.wait(MINE_RATE)
                    end
                    totalMined = totalMined + 1
                else
                    pcall(function() mineStatusLbl:Set("Aucun ore vivant (rescanne?)") end)
                    task.wait(MINE_RATE)
                end
              end
            end
            pcall(function() mineStatusLbl:Set("Mine: Stopped") end)
        end) end
    end })
MineTab:CreateToggle({ Name="🎯 Auto-focus (plus grosse HP cassable)", CurrentValue=false, Flag="AutoFocus",
    Callback=function(v) AUTO_FOCUS=v end })
MineTab:CreateSlider({ Name="Coups max pour casser (anti-Infinity)", Range={1,200}, Increment=1, CurrentValue=10, Flag="MaxHits",
    Callback=function(v) MAX_HITS=v end })
MineTab:CreateButton({ Name="📊 Analyse ores (HP / coups)", Callback=function()
    local dmg = pickaxeDamage() or 1
    local best = {}  -- dédup par nom: garde la plus grosse HP vue
    for _, m in ipairs(scanOres()) do
        local _, mx, raw = oreHealth(m)
        if mx and (not best[m.Name] or mx > best[m.Name].mx) then
            best[m.Name] = { name=m.Name, mx=mx, raw=raw, hits=(dmg>0 and mx/dmg or nil) }
        end
    end
    local rows = {}
    for _, r in pairs(best) do table.insert(rows, r) end
    table.sort(rows, function(a,b) return a.mx > b.mx end)  -- plus de HP = mieux
    local L = { "Dégâts pioche/coup: "..string.format("%.3g", dmg).."  |  plafond: "..MAX_HITS.." coups", "" }
    for _, r in ipairs(rows) do
        local hitsStr = r.hits and (r.hits<1 and "<1" or string.format("%.1f", r.hits)) or "?"
        local ok = (r.hits and r.hits <= MAX_HITS) and "✅" or "❌ trop dur"
        table.insert(L, string.format("%-12s HP:%-12s coups:%-8s %s", r.name, r.raw or "?", hitsStr, ok))
    end
    local dump = "=== ANALYSE ORES (triés par HP) ===\n"..table.concat(L, "\n")
    print(dump) pcall(function() setclipboard(dump) end)
    -- meilleur faisable = plus grosse HP avec coups <= plafond
    local pick
    for _, r in ipairs(rows) do if r.hits and r.hits <= MAX_HITS then pick = r break end end
    Rayfield:Notify({Title="Analyse", Content=(pick and ("Focus: "..pick.name.." ("..string.format("%.1f",pick.hits).." coups)") or "rien sous le plafond").." — copié", Duration=6})
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

-- ═══════════════════ RUNE ═══════════════════════════════════════════════════
local RuneTab = Window:CreateTab("Rune", "gem")

-- dossier des runes: Workspace.__GAME_CONTENT.RuneZones
local function runeFolder()
    local gc = workspace:FindFirstChild("__GAME_CONTENT")
    return gc and gc:FindFirstChild("RuneZones")
end
local function runeZoneNames()
    local f, out = runeFolder(), {}
    if f then for _, c in ipairs(f:GetChildren()) do table.insert(out, c.Name) end end
    if #out == 0 then out = {"Deepcore", "Snowy"} end
    table.sort(out)
    return out
end
local selectedRune = (runeZoneNames())[1] or "Deepcore"
-- cible de TP: spot marqué (prioritaire) sinon DÉTECTION AUTO du pad de la rune
local function runeTarget()
    if _env.TINOUHUB_RUNESPOT then return _env.TINOUHUB_RUNESPOT end
    local f = runeFolder()
    local z = f and f:FindFirstChild(selectedRune)
    if not z then return nil end
    -- centre horizontal de la zone, puis raycast vers le bas pour trouver le pad
    local ok, cf, size = pcall(function()
        if z:IsA("Model") then return z:GetBoundingBox() end
        local p = orePart(z); return p and p.CFrame, p and p.Size
    end)
    if ok and cf then
        local c = cf.Position
        local origin = Vector3.new(c.X, c.Y + (size and size.Y or 50), c.Z)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { player.Character }
        local res = workspace:Raycast(origin, Vector3.new(0, -(size and size.Y*2 or 200), 0), rp)
        if res then return CFrame.new(res.Position + Vector3.new(0, 3, 0)) end
        return CFrame.new(c)  -- fallback: centre brut
    end
    local p = orePart(z)
    return p and (p.CFrame + Vector3.new(0, 3, 0))
end
-- lecture d'une devise (GetPlayerData.CURRENCIES[name].Amount[1]), caché 2s
local _ccyCache, _ccyAt = {}, -999
local function currencyAmount(name)
    if os.clock() - _ccyAt > 2 then
        pcall(function()
            local rf = RS:FindFirstChild("GetPlayerData", true)
            local d = rf and rf:InvokeServer()
            if type(d) == "table" and d.CURRENCIES then _ccyCache = d.CURRENCIES _ccyAt = os.clock() end
        end)
    end
    local c = _ccyCache[name]
    return c and c.Amount and parseBig(c.Amount[1])
end
-- potions de rune: activer/pause via le remote du jeu (TogglePotionPause)
-- l'état est lisible sur le label HUD.Boosts.<nom>.Boost ("Paused" = en pause)
local POTION_NAMES = {"2x Rune Luck", "2x Rune Speed", "2x Rune Bulk"}
local function potionLabel(name)
    local pg = player:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    local boosts = hud and hud:FindFirstChild("Boosts")
    local b = boosts and boosts:FindFirstChild(name)
    local t = b and b:FindFirstChild("Boost", true)
    return t and t.Text
end
-- met les 3 potions dans l'état voulu (activate=true => reprises, false => en pause)
local function setPotions(activate)
    local n = 0
    for _, name in ipairs(POTION_NAMES) do
        local txt = potionLabel(name)
        if txt and txt ~= "" then
            local paused = (txt == "Paused")
            -- toggle seulement si l'état actuel ≠ état voulu (TogglePotionPause bascule)
            if (activate and paused) or ((not activate) and (not paused)) then
                Fire("TogglePotionPause", name)
                n = n + 1
                task.wait(0.2)  -- > cooldown anti-spam
            end
        end
    end
    return n
end

local AUTO_RUNE, RUNE_THRESHOLD, RUNE_CCY, POTIONS_ON = false, 0, "Gem", false
RuneTab:CreateSection("Spot de la rune")
local runeStatusLbl = RuneTab:CreateLabel("Rune: Idle")
RuneTab:CreateDropdown({ Name="Zone rune", Options=runeZoneNames(), CurrentOption=selectedRune, Flag="RuneZone",
    Callback=function(o) selectedRune = type(o)=="table" and o[1] or o end })
RuneTab:CreateButton({ Name="📍 Marquer le spot (mets-toi sur la rune)", Callback=function()
    local h = hrp()
    if h then _env.TINOUHUB_RUNESPOT = h.CFrame
        Rayfield:Notify({Title="Rune", Content="Spot marqué ✅", Duration=3})
    else Rayfield:Notify({Title="Rune", Content="Pas de perso", Duration=3}) end
end })
RuneTab:CreateButton({ Name="🧹 Oublier le spot marqué", Callback=function()
    _env.TINOUHUB_RUNESPOT = nil
    Rayfield:Notify({Title="Rune", Content="Spot oublié (utilise la zone)", Duration=3})
end })

RuneTab:CreateSection("Auto-Rune")
RuneTab:CreateInput({ Name="Seuil de Gems (ex: 10Qn)", CurrentValue="", PlaceholderText="10Qn",
    RemoveTextAfterFocusLost=false, Flag="RuneThresh",
    Callback=function(t) RUNE_THRESHOLD = parseBig(t) or 0 end })
RuneTab:CreateInput({ Name="Devise à surveiller (def: Gem)", CurrentValue="Gem", PlaceholderText="Gem",
    RemoveTextAfterFocusLost=false, Flag="RuneCcy",
    Callback=function(t) if t and t~="" then RUNE_CCY = t end end })
RuneTab:CreateToggle({ Name="Activer les potions pendant l'ouverture", CurrentValue=false, Flag="RunePotions",
    Callback=function(v) POTIONS_ON = v end })
RuneTab:CreateButton({ Name="🧪 Test: activer les potions", Callback=function()
    local n = setPotions(true)
    Rayfield:Notify({Title="Potions", Content=n.." potion(s) reprise(s) — vérifie en bas", Duration=4})
end })
RuneTab:CreateButton({ Name="⏸️ Test: mettre les potions en pause", Callback=function()
    local n = setPotions(false)
    Rayfield:Notify({Title="Potions", Content=n.." potion(s) en pause", Duration=4})
end })
RuneTab:CreateToggle({ Name="🔮 Auto-Rune (ouvre quand Gems ≥ seuil)", CurrentValue=false, Flag="AutoRune",
    Callback=function(v)
        AUTO_RUNE = v
        if v then task.spawn(function()
            while AUTO_RUNE and active() do
                local tgt = runeTarget()
                local g = currencyAmount(RUNE_CCY)
                if RUNE_THRESHOLD <= 0 then
                    pcall(function() runeStatusLbl:Set("Mets un seuil de Gems") end) task.wait(2)
                elseif not tgt then
                    pcall(function() runeStatusLbl:Set("Marque le spot rune") end) task.wait(2)
                elseif g and g >= RUNE_THRESHOLD then
                    -- 1) pause le minage  2) active les potions  3) ENSUITE on TP
                    MINE_PAUSED = true
                    if POTIONS_ON then
                        pcall(function() runeStatusLbl:Set("Activation potions…") end)
                        setPotions(true)
                        task.wait(0.6)
                    end
                    discordLog("🔮 Auto-Rune: ouverture", "Gems: **"..tostring(g).."** ≥ seuil", 10181046)
                    while AUTO_RUNE and active() do
                        g = currencyAmount(RUNE_CCY)
                        if not g or g < RUNE_THRESHOLD then break end
                        local h = hrp() if h then h.CFrame = tgt end
                        pcall(function() runeStatusLbl:Set("Ouverture… "..RUNE_CCY..": "..tostring(g)) end)
                        task.wait(0.4)
                    end
                    if POTIONS_ON then setPotions(false) end  -- remet les potions en pause
                    MINE_PAUSED = false                       -- reprend le minage
                    discordLog("🔮 Auto-Rune: stop", "Gems sous le seuil", 15105570)
                    pcall(function() runeStatusLbl:Set("Pause (gems < seuil)") end)
                else
                    pcall(function() runeStatusLbl:Set("Attente | "..RUNE_CCY..": "..tostring(g or "?").." / "..RUNE_THRESHOLD) end)
                    task.wait(2)
                end
            end
            pcall(function() runeStatusLbl:Set("Rune: Stopped") end)
        end) end
    end })

RuneTab:CreateSection("Outils (si besoin de régler)")
RuneTab:CreateButton({ Name="💎 Dump devises (trouver le bon Gem)", Callback=function()
    local rf = RS:FindFirstChild("GetPlayerData", true)
    local ok, d = pcall(function() return rf and rf:InvokeServer() end)
    local L = {}
    if ok and type(d)=="table" and d.CURRENCIES then
        for name, c in pairs(d.CURRENCIES) do
            local a = c.Amount and c.Amount[1]
            table.insert(L, name.." = "..tostring(a))
        end
        table.sort(L)
    end
    local dump = "=== DEVISES (Amount[1]) ===\n"..table.concat(L, "\n")
    print(dump) pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Rune", Content=#L.." devises — copié + F9", Duration=5})
end })
RuneTab:CreateButton({ Name="🧪 Dump boutons potions (PlayerGui)", Callback=function()
    local L, pg = {}, player:FindFirstChild("PlayerGui")
    if pg then for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") then
            local n = string.lower(d.Name)
            if n:find("potion") or n:find("luck") or n:find("bulk") or n:find("speed") then
                table.insert(L, d.ClassName.." | vis="..tostring(d.Visible).." | "..d:GetFullName())
            end
        end
    end end
    local dump = "=== BOUTONS POTIONS ("..#L..") ===\n"..table.concat(L, "\n")
    print(dump) pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Rune", Content=#L.." boutons — copié + F9", Duration=5})
end })

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

SetTab:CreateSection("Capture remotes (auto-spy)")
local function argToStr(a)
    local t = typeof(a)
    if t=="Instance" then return "Instance "..a.ClassName.." -> "..a:GetFullName()
    elseif t=="table" then local n=0 for _ in pairs(a) do n=n+1 end return "table("..n.." clés)"
    else return t.." "..tostring(a) end
end
-- Spy universel: logge TOUS les FireServer du client.
-- Mode AUTO (fond): capture en continu chaque nouvelle commande -> console + presse-papier + Discord.
-- Mode fenêtre: capture pendant N secondes (boutons manuels).
_env.TINOUHUB_SPYLOG = _env.TINOUHUB_SPYLOG or {}        -- dédup (signatures déjà vues)
_env.TINOUHUB_ALL = _env.TINOUHUB_ALL or {}             -- liste ordonnée de tout ce qui a été capturé
_env.TINOUHUB_SPYUNTIL = _env.TINOUHUB_SPYUNTIL or 0    -- fenêtre manuelle active jusqu'à
if _env.TINOUHUB_AUTOSPY == nil then _env.TINOUHUB_AUTOSPY = true end
local function recordSpy(line)
    if _env.TINOUHUB_SPYLOG[line] then return end
    _env.TINOUHUB_SPYLOG[line] = true
    table.insert(_env.TINOUHUB_ALL, line)
    print("[SPY] "..line)
    -- presse-papier = liste complète accumulée (toujours prête à coller)
    pcall(function() setclipboard("=== REMOTES CAPTURÉS ("..#_env.TINOUHUB_ALL..") ===\n"..table.concat(_env.TINOUHUB_ALL, "\n")) end)
    -- Discord: 1 message par nouvelle commande (dédup => pas de spam)
    if _env.TINOUHUB_AUTOSPY then
        pcall(function() discordLog("📡 Nouveau remote capturé", "```"..string.sub(line,1,1800).."```", 3447003) end)
    end
end
local function installUniversalSpy()
    if _env.TINOUHUB_SPY_INSTALLED then return true end
    local sample = nil
    for _, d in ipairs(RS:GetDescendants()) do if d:IsA("RemoteEvent") then sample=d break end end
    if not sample then return false end
    local ok = pcall(function()
        local old
        old = hookfunction(sample.FireServer, newcclosure(function(self, ...)
            if active() and (_env.TINOUHUB_AUTOSPY or os.clock() < _env.TINOUHUB_SPYUNTIL) then
                local name = (typeof(self)=="Instance") and self.Name or tostring(self)
                local parts = {}
                for i=1,select("#",...) do parts[i]=argToStr((select(i,...))) end
                recordSpy(name.."("..table.concat(parts,", ")..")")
            end
            return old(self, ...)
        end))
        _env.TINOUHUB_SPY_INSTALLED = true
    end)
    return ok
end
SetTab:CreateToggle({ Name="🛰️ Auto-Spy remotes (fond + presse-papier + Discord)", CurrentValue=true, Flag="AutoSpy",
    Callback=function(v) _env.TINOUHUB_AUTOSPY=v if v then installUniversalSpy() end end })
SetTab:CreateButton({ Name="📤 Exporter tout (presse-papier + F9)", Callback=function()
    local dump = "=== REMOTES CAPTURÉS ("..#_env.TINOUHUB_ALL..") ===\n"..table.concat(_env.TINOUHUB_ALL, "\n")
    print(dump) pcall(function() setclipboard(dump) end)
    Rayfield:Notify({Title="Spy", Content=#_env.TINOUHUB_ALL.." remotes — copié + F9", Duration=5})
end })
SetTab:CreateButton({ Name="🗑️ Reset capture", Callback=function()
    _env.TINOUHUB_SPYLOG = {} _env.TINOUHUB_ALL = {}
    Rayfield:Notify({Title="Spy", Content="Capture remise à zéro", Duration=3})
end })

-- ════════════════════ Stats périodiques (Discord) ═══════════════════════════
local STATS_ON = false
local startTime = os.time()
local function fmtNum(v)
    local n = tonumber(v)
    if not n or n ~= n then return tostring(v) end
    if math.abs(n) >= 1e6 then return string.format("%.2e", n) end
    return string.format("%d", math.floor(n))
end
local function buildStatsLines()
    local rf = RS:FindFirstChild("GetPlayerData", true)
    if not rf then return nil end
    local ok, d = pcall(function() return rf:InvokeServer() end)
    if not ok or type(d) ~= "table" then return nil end
    local cur, sv = d.CURRENCIES or {}, d.SIMPLE_VALUES or {}
    local function amt(name) local c = cur[name] return c and c.Amount and c.Amount[1] end
    local prev = _env.TINOUHUB_LASTSTATS or {}
    local now = {}
    local function line(label, key, val)
        local n = tonumber(val)
        now[key] = n
        local delta = ""
        if n and prev[key] then local dv = n - prev[key]
            if dv ~= 0 then delta = "  ("..(dv>0 and "+" or "")..fmtNum(dv)..")" end end
        return "**"..label.."**: "..fmtNum(val)..delta
    end
    local L = {}
    for _, p in ipairs({{"Gems","Gem"},{"Coins","Coin"},{"Wood","Wood"},{"Water","Water"},{"Blaze","Blaze"}}) do
        local a = amt(p[2]); if a then table.insert(L, line(p[1], p[2], a)) end
    end
    if sv.TotalOreBreak then table.insert(L, line("Ores cassés (total)", "ore", sv.TotalOreBreak)) end
    if sv.TotalCapsuleOpened then table.insert(L, line("Capsules ouvertes", "caps", sv.TotalCapsuleOpened)) end
    table.insert(L, "**Session minée (script)**: "..tostring(totalMined))
    table.insert(L, "**Uptime**: "..math.floor((os.time()-startTime)/60).."min")
    _env.TINOUHUB_LASTSTATS = now
    return table.concat(L, "\n")
end
local function sendStats()
    local body = buildStatsLines()
    if not body then return false end
    discordLog("📊 Stats — "..player.Name, body, 15844367, true)  -- force=true
    return true
end
task.spawn(function()
    while active() do
        task.wait(300)  -- 5 min
        if active() and STATS_ON and WEBHOOK ~= "" then pcall(sendStats) end
    end
end)

SetTab:CreateSection("Logs Discord")
SetTab:CreateInput({ Name="Webhook URL", CurrentValue=WEBHOOK, PlaceholderText="https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost=false, Flag="Webhook", Callback=function(t) WEBHOOK = t or "" end })
SetTab:CreateToggle({ Name="📊 Stats auto (toutes les 5 min)", CurrentValue=false, Flag="StatsAuto",
    Callback=function(v) STATS_ON=v
        if v then if WEBHOOK=="" then Rayfield:Notify({Title="Stats",Content="Configure le webhook d'abord",Duration=4})
            else pcall(sendStats) end end end })
SetTab:CreateButton({ Name="📊 Envoyer stats maintenant", Callback=function()
    if WEBHOOK=="" then Rayfield:Notify({Title="Stats",Content="Webhook requis (mets l'URL au-dessus)",Duration=4}) return end
    local ok = pcall(sendStats)
    Rayfield:Notify({Title="Stats", Content=ok and "Stats envoyées (check Discord)" or "GetPlayerData a échoué", Duration=4})
end })
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
-- auto-spy en fond dès le lancement (capture les remotes tout seul)
if _env.TINOUHUB_AUTOSPY then installUniversalSpy() end
task.delay(1, function() discordLog("🟢 Script lancé", "**"..player.Name.."** a chargé TinouHub", 5763719) end)

Rayfield:Notify({Title="TinouHub", Content="Mining v"..VERSION.." chargé!", Duration=4})
