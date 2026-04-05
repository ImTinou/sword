local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local player  = game:GetService("Players").LocalPlayer
local remote  = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
local TweenService = game:GetService("TweenService")

local SCAN_RATE = 0.5
local MATCH_ALL = true
local scanning  = false

local enchantList = {
    "Any","Fortune","Sharpness","Protection","Haste","Swiftness",
    "Critical","Resistance","Healing","Looting","Attraction",
    "Stealth","Ancient","Desperation","Insight","Thorns","Knockback"
}

local slots = {"Any","Any","Any"}

local function getSwordEnchants(sword)
    local ok, children = pcall(function()
        return sword.Main.Gui.ItemInfo.Enchants:GetChildren()
    end)
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

local function flyPickup(sword)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ok, swordCF = pcall(function() return sword.Main.CFrame end)
    if not ok then return end

    local origin = hrp.CFrame

    -- Monte au dessus de la sword
    hrp.CFrame = swordCF * CFrame.new(0, 15, 0)
    task.wait(0.1)

    -- Descend vers la sword
    local tween = TweenService:Create(hrp, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
        CFrame = swordCF * CFrame.new(0, 2, 0)
    })
    tween:Play()
    tween.Completed:Wait()

    -- Pickup
    remote:FireServer("Set Hotbar", sword.Name, "Hotbar", 1)
    task.wait(0.1)

    -- Retour origine
    hrp.CFrame = origin
end

local function startScan(statusLabel)
    scanning = true
    task.spawn(function()
        while scanning do
            local found = 0
            for _, sword in pairs(workspace.Swords:GetChildren()) do
                if not scanning then break end
                if swordMatches(sword) then
                    flyPickup(sword)
                    found = found + 1
                end
            end
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = "Scan done - picked: " .. found
            end
            task.wait(SCAN_RATE)
        end
        if statusLabel and statusLabel.Parent then
            statusLabel.Text = "Stopped."
        end
    end)
end

-- GUI

local Window = Rayfield:CreateWindow({
    Name            = "Sword Enchant Picker",
    LoadingTitle    = "Enchant Picker",
    LoadingSubtitle = "Sword Factory X",
    ConfigurationSaving = { Enabled = false },
    KeySystem       = false,
})

local Tab = Window:CreateTab("Enchants", "shield")

Tab:CreateSection("Enchant Filters")

Tab:CreateDropdown({
    Name            = "Slot 1",
    Options         = enchantList,
    CurrentOption   = "Any",
    MultipleOptions = false,
    Callback        = function(opt) slots[1] = opt end,
})

Tab:CreateDropdown({
    Name            = "Slot 2",
    Options         = enchantList,
    CurrentOption   = "Any",
    MultipleOptions = false,
    Callback        = function(opt) slots[2] = opt end,
})

Tab:CreateDropdown({
    Name            = "Slot 3",
    Options         = enchantList,
    CurrentOption   = "Any",
    MultipleOptions = false,
    Callback        = function(opt) slots[3] = opt end,
})

Tab:CreateSection("Options")

Tab:CreateToggle({
    Name         = "Match all 3 enchants",
    CurrentValue = true,
    Callback     = function(val) MATCH_ALL = val end,
})

Tab:CreateSlider({
    Name         = "Scan Rate (s)",
    Range        = {0.1, 3},
    Increment    = 0.1,
    CurrentValue = 0.5,
    Callback     = function(val) SCAN_RATE = val end,
})

Tab:CreateSection("Control")

local statusElement = Tab:CreateLabel("Status: Ready")

Tab:CreateButton({
    Name     = "Start Auto-Pickup",
    Callback = function()
        if not scanning then
            startScan(statusElement)
            Rayfield:Notify({Title="Enchant Picker", Content="Scan started!", Duration=2})
        end
    end,
})

Tab:CreateButton({
    Name     = "Stop Auto-Pickup",
    Callback = function()
        scanning = false
        Rayfield:Notify({Title="Enchant Picker", Content="Scan stopped.", Duration=2})
    end,
})
