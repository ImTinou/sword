local player  = game:GetService("Players").LocalPlayer
local remote  = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
local uis     = game:GetService("UserInputService")

local SCAN_RATE = 0.3
local MATCH_ALL = true
local enchantList = {"Any","Fortune","Sharpness","Protection","Haste","Swiftness","Critical","Resistance","Healing","Looting","Attraction","Stealth","Ancient","Desperation","Insight","Thorns","Knockback"}
local slots = {"Any","Any","Any"}
local scanning = false

local function getSwordEnchants(sword)
    local ok, children = pcall(function() return sword.Main.Gui.ItemInfo.Enchants:GetChildren() end)
    if not ok then return {} end
    local result = {}
    for _, e in pairs(children) do
        if e:IsA("TextLabel") then
            local name = e.Text:match("^(%a+)")
            if name then table.insert(result, name) end
        end
    end
    return result
end

local function countIn(t, v)
    local n = 0
    for _, x in pairs(t) do if x == v then n = n + 1 end end
    return n
end

local function swordMatches(sword)
    local enchants = getSwordEnchants(sword)
    if #enchants == 0 then return false end
    if MATCH_ALL then
        local needed = {}
        for _, s in pairs(slots) do
            if s ~= "Any" then needed[s] = (needed[s] or 0) + 1 end
        end
        for e, c in pairs(needed) do
            if countIn(enchants, e) < c then return false end
        end
        return true
    else
        for _, s in pairs(slots) do
            if s == "Any" then return true end
            for _, e in pairs(enchants) do
                if e == s then return true end
            end
        end
        return false
    end
end

if player.PlayerGui:FindFirstChild("EP") then player.PlayerGui.EP:Destroy() end

local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "EP"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local BG   = Color3.fromRGB(18,18,22)
local BG2  = Color3.fromRGB(28,28,34)
local BG3  = Color3.fromRGB(40,40,50)
local ACC  = Color3.fromRGB(99,102,241)
local TXT  = Color3.fromRGB(230,230,240)
local TXT2 = Color3.fromRGB(140,140,160)

local win = Instance.new("Frame", gui)
win.Size = UDim2.new(0,320,0,310)
win.Position = UDim2.new(0.5,-160,0.5,-155)
win.BackgroundColor3 = BG
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
local wc = Instance.new("UICorner", win)
wc.CornerRadius = UDim.new(0,10)

local bar = Instance.new("Frame", win)
bar.Size = UDim2.new(1,0,0,42)
bar.BackgroundColor3 = BG2
bar.BorderSizePixel = 0
local bc = Instance.new("UICorner", bar)
bc.CornerRadius = UDim.new(0,10)
local bfix = Instance.new("Frame", bar)
bfix.Size = UDim2.new(1,0,0,10)
bfix.Position = UDim2.new(0,0,1,-10)
bfix.BackgroundColor3 = BG2
bfix.BorderSizePixel = 0

local dot = Instance.new("Frame", bar)
dot.Size = UDim2.new(0,8,0,8)
dot.Position = UDim2.new(0,14,0.5,-4)
dot.BackgroundColor3 = ACC
dot.BorderSizePixel = 0
local dc = Instance.new("UICorner", dot)
dc.CornerRadius = UDim.new(0,4)

local title = Instance.new("TextLabel", bar)
title.Text = "Sword Enchant Picker"
title.TextSize = 14
title.TextColor3 = TXT
title.Font = Enum.Font.GothamBold
title.BackgroundTransparency = 1
title.Position = UDim2.new(0,28,0,12)
title.Size = UDim2.new(1,0,0,20)
title.TextXAlignment = Enum.TextXAlignment.Left

local sec = Instance.new("TextLabel", win)
sec.Text = "ENCHANT FILTERS"
sec.TextSize = 10
sec.TextColor3 = TXT2
sec.Font = Enum.Font.GothamBold
sec.BackgroundTransparency = 1
sec.Position = UDim2.new(0,10,0,52)
sec.Size = UDim2.new(1,0,0,18)
sec.TextXAlignment = Enum.TextXAlignment.Left

local statusLbl = Instance.new("TextLabel", win)
statusLbl.Text = "Ready."
statusLbl.TextSize = 11
statusLbl.TextColor3 = TXT2
statusLbl.Font = Enum.Font.Gotham
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(0,10,0,248)
statusLbl.Size = UDim2.new(1,0,0,18)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function makeSep(yPos)
    local s = Instance.new("Frame", win)
    s.Size = UDim2.new(1,-20,0,1)
    s.Position = UDim2.new(0,10,0,yPos)
    s.BackgroundColor3 = BG3
    s.BorderSizePixel = 0
end

makeSep(48)
makeSep(210)

local startBtn = Instance.new("TextButton", win)
startBtn.Size = UDim2.new(0.48,-15,0,32)
startBtn.Position = UDim2.new(0,10,0,268)
startBtn.BackgroundColor3 = Color3.fromRGB(34,197,94)
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 13
startBtn.Text = "Start"
startBtn.BorderSizePixel = 0
local sc = Instance.new("UICorner", startBtn)
sc.CornerRadius = UDim.new(0,8)

local stopBtn = Instance.new("TextButton", win)
stopBtn.Size = UDim2.new(0.48,-5,0,32)
stopBtn.Position = UDim2.new(0.5,5,0,268)
stopBtn.BackgroundColor3 = Color3.fromRGB(239,68,68)
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 13
stopBtn.Text = "Stop"
stopBtn.BorderSizePixel = 0
local stc = Instance.new("UICorner", stopBtn)
stc.CornerRadius = UDim.new(0,8)

local toggleBG = Instance.new("TextButton", win)
toggleBG.Size = UDim2.new(0,44,0,22)
toggleBG.Position = UDim2.new(1,-54,0,218)
toggleBG.BackgroundColor3 = ACC
toggleBG.BorderSizePixel = 0
toggleBG.Text = ""
local tgc = Instance.new("UICorner", toggleBG)
tgc.CornerRadius = UDim.new(0,11)

local toggleDot = Instance.new("Frame", toggleBG)
toggleDot.Size = UDim2.new(0,16,0,16)
toggleDot.Position = UDim2.new(1,-19,0.5,-8)
toggleDot.BackgroundColor3 = Color3.new(1,1,1)
toggleDot.BorderSizePixel = 0
local tdc = Instance.new("UICorner", toggleDot)
tdc.CornerRadius = UDim.new(0,8)

local tglbl = Instance.new("TextLabel", win)
tglbl.Text = "Match all 3 enchants"
tglbl.TextSize = 12
tglbl.TextColor3 = TXT
tglbl.Font = Enum.Font.Gotham
tglbl.BackgroundTransparency = 1
tglbl.Position = UDim2.new(0,10,0,220)
tglbl.Size = UDim2.new(0.7,0,0,22)
tglbl.TextXAlignment = Enum.TextXAlignment.Left

toggleBG.MouseButton1Click:Connect(function()
    MATCH_ALL = not MATCH_ALL
    if MATCH_ALL then
        toggleBG.BackgroundColor3 = ACC
        toggleDot.Position = UDim2.new(1,-19,0.5,-8)
    else
        toggleBG.BackgroundColor3 = BG3
        toggleDot.Position = UDim2.new(0,3,0.5,-8)
    end
end)

local function makeDropRow(yPos, slotIdx)
    local lbl = Instance.new("TextLabel", win)
    lbl.Text = "Slot " .. slotIdx
    lbl.TextSize = 11
    lbl.TextColor3 = TXT2
    lbl.Font = Enum.Font.Gotham
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0,10,0,yPos+8)
    lbl.Size = UDim2.new(0.4,0,0,20)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", win)
    btn.Size = UDim2.new(0.56,0,0,28)
    btn.Position = UDim2.new(0.42,0,0,yPos+4)
    btn.BackgroundColor3 = BG3
    btn.TextColor3 = TXT
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Text = "Any"
    btn.BorderSizePixel = 0
    local bc2 = Instance.new("UICorner", btn)
    bc2.CornerRadius = UDim.new(0,6)

    local dropList = Instance.new("Frame", gui)
    dropList.Size = UDim2.new(0,160,0,#enchantList*26)
    dropList.BackgroundColor3 = BG2
    dropList.BorderSizePixel = 0
    dropList.Visible = false
    dropList.ZIndex = 20
    local dlc = Instance.new("UICorner", dropList)
    dlc.CornerRadius = UDim.new(0,6)

    local layout = Instance.new("UIListLayout", dropList)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    for i, ename in ipairs(enchantList) do
        local item = Instance.new("TextButton", dropList)
        item.Size = UDim2.new(1,0,0,26)
        item.BackgroundTransparency = 1
        item.TextColor3 = TXT
        item.Font = Enum.Font.Gotham
        item.TextSize = 12
        item.Text = ename
        item.ZIndex = 21
        item.LayoutOrder = i
        item.MouseButton1Click:Connect(function()
            slots[slotIdx] = ename
            btn.Text = ename
            dropList.Visible = false
        end)
    end

    btn.MouseButton1Click:Connect(function()
        if dropList.Visible then
            dropList.Visible = false
            return
        end
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        dropList.Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+2)
        dropList.Visible = true
    end)

    uis.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            task.wait()
            if dropList.Visible then
                local mp = uis:GetMouseLocation()
                local lp = dropList.AbsolutePosition
                local ls = dropList.AbsoluteSize
                if not (mp.X>=lp.X and mp.X<=lp.X+ls.X and mp.Y>=lp.Y and mp.Y<=lp.Y+ls.Y) then
                    dropList.Visible = false
                end
            end
        end
    end)
end

makeDropRow(72, 1)
makeDropRow(114, 2)
makeDropRow(156, 3)

startBtn.MouseButton1Click:Connect(function()
    if scanning then return end
    scanning = true
    task.spawn(function()
        while scanning do
            local found = 0
            for _, sword in pairs(workspace.Swords:GetChildren()) do
                if swordMatches(sword) then
                    remote:FireServer("Set Hotbar", sword.Name, "Hotbar", 1)
                    found = found + 1
                    task.wait(0.05)
                end
            end
            statusLbl.Text = "Scanning... picked: " .. found
            task.wait(SCAN_RATE)
        end
        statusLbl.Text = "Stopped."
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    scanning = false
end)
