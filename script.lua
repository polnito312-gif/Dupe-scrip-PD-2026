-- Project Delta - Visual Item Filler
-- Choose item + amount → fills empty vicinity slots (client-side only)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
-- ============================================================
local FIREBASE_URL = "https://key-sistem-a774a-default-rtdb.firebaseio.com/keys.json"

local cached_keys = nil

local function fetch_keys()
    if cached_keys then return cached_keys end

    local list = {}
    local ok, body = pcall(function()
        return game:HttpGet(FIREBASE_URL, true)
    end)

    if ok and body and #body > 0 then
        local parsed, keys = pcall(function()
            return game:GetService("HttpService"):JSONDecode(body)
        end)
        if parsed and type(keys) == "table" then
            for k, v in pairs(keys) do
                if v == true or v == "true" then
                    table.insert(list, k)
                end
            end
        end
    end

    cached_keys = list
    return list
end

local function is_valid_key(key)
    if not key or key == "" then return false end
    key = key:gsub("%s+", "")
    local keys = fetch_keys()
    for _, k in ipairs(keys) do
        if key == k then return true end
    end
    return false
end

-- ============================================================
-- CONFIG / STATE
-- ============================================================
local State = {
    ItemName   = "Rubles",
    AmountText = "99999999",
    Icon       = "rbxassetid://8451212111",
    Color      = Color3.fromRGB(255, 255, 255),
}

local FALLBACK_ITEMS = {
    "Rubles", "Gold50g", "GoldWatch", "GoldenTicket",
    "M4", "AKM", "AKMN", "SVD", "Mosin", "SKS", "PPSH41",
    "MK23", "MP443", "TT33", "IZh12",
    "PSO1", "HoloSight", "ACOG", "T1Sight", "PBS1",
    "Bandage", "WoundDressing", "RepairKit", "FlareGun",
    "6B23", "6B5", "ZSh", "Altyn", "Smersh", "Tortilla", "Kulon"
}

local MAX_SLOTS = 300
local LOOP_DELAY = 0.7

-- ============================================================
-- HELPERS
-- ============================================================
local function get_items_list()
    local list = {}
    local seen = {}

    local itemsList = game:GetService("ReplicatedStorage"):FindFirstChild("ItemsList")
    if itemsList then
        for _, child in ipairs(itemsList:GetChildren()) do
            if not seen[child.Name] then
                seen[child.Name] = true
                table.insert(list, child.Name)
            end
        end
    end

    for _, name in ipairs(FALLBACK_ITEMS) do
        if not seen[name] then
            seen[name] = true
            table.insert(list, name)
        end
    end

    table.sort(list)
    return list
end

local function get_item_icon(itemName)
    local itemsList = game:GetService("ReplicatedStorage"):FindFirstChild("ItemsList")
    if itemsList then
        local item = itemsList:FindFirstChild(itemName)
        if item then
            local props = item:FindFirstChild("ItemProperties")
            if props then
                local icon = props:FindFirstChild("ItemIcon")
                if icon and icon:IsA("ImageLabel") and icon.Image ~= "" then
                    return icon.Image
                end
            end
        end
    end
    return "rbxassetid://8451212111"
end

local function get_vicinity_frame()
    local mainGui = PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end

    local backpack = nil
    local mainFrame = mainGui:FindFirstChild("MainFrame")
    if mainFrame then
        backpack = mainFrame:FindFirstChild("BackpackFrame")
    end
    if not backpack then
        backpack = mainGui:FindFirstChild("BackpackFrame")
    end
    if not backpack then return nil end

    local ok, result = pcall(function()
        return backpack.Loot.Inventory.ScrollingFrame.Container.Frame
    end)
    if ok and result then return result end

    ok, result = pcall(function()
        return backpack.Loot.Inventory.ScrollingFrame.Container
    end)
    if ok and result then return result end

    return nil
end

local function is_slot_empty(slot)
    local itemVal = slot:FindFirstChild("Item")
    if itemVal and itemVal:IsA("ObjectValue") and itemVal.Value ~= nil then
        return false
    end
    local itemName = slot:FindFirstChild("ItemName")
    if itemName and itemName.Text ~= "" and itemName.Visible then
        return false
    end
    return true
end

local function apply_look(slot)
    local itemName = slot:FindFirstChild("ItemName")
    local image    = slot:FindFirstChild("ImageLabel")
    local preImage = slot:FindFirstChild("PreImageLabel")
    local hotKey   = slot:FindFirstChild("HotKey")
    local dura     = slot:FindFirstChild("Durability")
    local fastLoot = slot:FindFirstChild("FastLootIcon")

    if itemName then
        itemName.Text = State.ItemName
        itemName.TextColor3 = State.Color
        itemName.Visible = true
    end

    local amountNum = tonumber(State.AmountText) or 1
    -- 0 = hide number | 1 or more = show the number
    local showStack = amountNum >= 1

    local quantityNames = {
        "Amount", "Stack", "Quantity", "Count", "Qty",
        "ItemAmount", "StackSize", "AmountLabel", "StackLabel",
        "Number", "Value"
    }
    for _, name in ipairs(quantityNames) do
        local obj = slot:FindFirstChild(name)
        if obj and (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
            if showStack then
                obj.Text = State.AmountText
                obj.Visible = true
            else
                obj.Text = ""
                obj.Visible = false
            end
        end
    end

    for _, desc in ipairs(slot:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextBox")) and desc ~= itemName then
            local t = tostring(desc.Text or "")
            if t == "1" or t == "0" or tonumber(t) then
                if showStack then
                    desc.Text = State.AmountText
                    desc.Visible = true
                else
                    desc.Text = ""
                    desc.Visible = false
                end
            end
        end
    end

    if image then
        image.Image = State.Icon
        image.ImageTransparency = 0
        image.Visible = true
    end
    if preImage then preImage.Visible = false end
    if hotKey then hotKey.Visible = false end
    if dura then dura.Visible = false end
    if fastLoot then fastLoot.ImageTransparency = 1 end
end

local function fill_empty_slots()
    local container = get_vicinity_frame()
    if not container then return 0 end

    local filled = 0
    for i = 1, MAX_SLOTS do
        local slot = container:FindFirstChild("Container" .. i)
        if slot and is_slot_empty(slot) then
            pcall(apply_look, slot)
            filled = filled + 1
        end
    end
    return filled
end

-- ============================================================
-- UI
-- ============================================================
local function create_ui()
    local core = game:GetService("CoreGui")
    local old = core:FindFirstChild("PDItemFiller")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PDItemFiller"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = core

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 280, 0, 320)
    Main.Position = UDim2.new(0.03, 0, 0.18, 0)
    Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = Main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 190, 0)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = Main

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 38)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Main
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = TitleBar
    local fix = Instance.new("Frame")
    fix.Size = UDim2.new(1, 0, 0, 12)
    fix.Position = UDim2.new(0, 0, 1, -12)
    fix.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    fix.BorderSizePixel = 0
    fix.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "∞  Item Filler"
    Title.TextColor3 = Color3.fromRGB(255, 190, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 28, 0, 28)
    Close.Position = UDim2.new(1, -34, 0, 5)
    Close.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    Close.Text = "×"
    Close.TextColor3 = Color3.fromRGB(200, 200, 210)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 16
    Close.Parent = TitleBar
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent = Close
    Close.MouseButton1Click:Connect(function() gui:Destroy() end)

    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.Size = UDim2.new(1, -20, 0, 18)
    Status.Position = UDim2.new(0, 10, 0, 46)
    Status.BackgroundTransparency = 1
    Status.Text = "Select item + amount"
    Status.TextColor3 = Color3.fromRGB(160, 160, 175)
    Status.Font = Enum.Font.Gotham
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Main

    local ItemLabel = Instance.new("TextLabel")
    ItemLabel.Size = UDim2.new(1, -20, 0, 14)
    ItemLabel.Position = UDim2.new(0, 10, 0, 72)
    ItemLabel.BackgroundTransparency = 1
    ItemLabel.Text = "ITEM"
    ItemLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
    ItemLabel.Font = Enum.Font.GothamBold
    ItemLabel.TextSize = 11
    ItemLabel.TextXAlignment = Enum.TextXAlignment.Left
    ItemLabel.Parent = Main

    local ItemBtn = Instance.new("TextButton")
    ItemBtn.Size = UDim2.new(1, -20, 0, 34)
    ItemBtn.Position = UDim2.new(0, 10, 0, 90)
    ItemBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    ItemBtn.Text = "  " .. State.ItemName
    ItemBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    ItemBtn.Font = Enum.Font.GothamSemibold
    ItemBtn.TextSize = 13
    ItemBtn.TextXAlignment = Enum.TextXAlignment.Left
    ItemBtn.Parent = Main
    local ibc = Instance.new("UICorner")
    ibc.CornerRadius = UDim.new(0, 8)
    ibc.Parent = ItemBtn

    local AmountLabel = Instance.new("TextLabel")
    AmountLabel.Size = UDim2.new(1, -20, 0, 14)
    AmountLabel.Position = UDim2.new(0, 10, 0, 134)
    AmountLabel.BackgroundTransparency = 1
    AmountLabel.Text = "AMOUNT"
    AmountLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
    AmountLabel.Font = Enum.Font.GothamBold
    AmountLabel.TextSize = 11
    AmountLabel.TextXAlignment = Enum.TextXAlignment.Left
    AmountLabel.Parent = Main

    local AmountBox = Instance.new("TextBox")
    AmountBox.Size = UDim2.new(1, -20, 0, 34)
    AmountBox.Position = UDim2.new(0, 10, 0, 152)
    AmountBox.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    AmountBox.Text = State.AmountText
    AmountBox.PlaceholderText = "99999999"
    AmountBox.TextColor3 = Color3.fromRGB(255, 190, 0)
    AmountBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 115)
    AmountBox.Font = Enum.Font.GothamSemibold
    AmountBox.TextSize = 14
    AmountBox.ClearTextOnFocus = false
    AmountBox.Parent = Main
    local abc = Instance.new("UICorner")
    abc.CornerRadius = UDim.new(0, 8)
    abc.Parent = AmountBox

    AmountBox.FocusLost:Connect(function()
        local t = AmountBox.Text:gsub("[^0-9]", "")
        if t == "" then t = "1" end
        State.AmountText = t
        AmountBox.Text = t
    end)

    local FillBtn = Instance.new("TextButton")
    FillBtn.Size = UDim2.new(1, -20, 0, 40)
    FillBtn.Position = UDim2.new(0, 10, 0, 200)
    FillBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 20)
    FillBtn.Text = "Fill EmptySlots"
    FillBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    FillBtn.Font = Enum.Font.GothamBold
    FillBtn.TextSize = 14
    FillBtn.Parent = Main
    local fbc = Instance.new("UICorner")
    fbc.CornerRadius = UDim.new(0, 8)
    fbc.Parent = FillBtn

    FillBtn.MouseButton1Click:Connect(function()
        State.AmountText = AmountBox.Text:gsub("[^0-9]", "")
        if State.AmountText == "" then State.AmountText = "1" end
        State.Icon = get_item_icon(State.ItemName)
        State.Color = Color3.fromRGB(255, 255, 255)
        local n = fill_empty_slots()
        Status.Text = "Filled " .. n .. " slots with " .. State.ItemName
        Status.TextColor3 = Color3.fromRGB(80, 220, 120)
    end)

    local Note = Instance.new("TextLabel")
    Note.Size = UDim2.new(1, -20, 0, 16)
    Note.Position = UDim2.new(0, 10, 0, 250)
    Note.BackgroundTransparency = 1
    Note.Text = "Open vicinity / loot panel to see changes"
    Note.TextColor3 = Color3.fromRGB(120, 120, 135)
    Note.Font = Enum.Font.Gotham
    Note.TextSize = 11
    Note.Parent = Main

    local DropFrame = Instance.new("Frame")
    DropFrame.Size = UDim2.new(0, 260, 0, 220)
    DropFrame.Position = UDim2.new(0, 10, 0, 128)
    DropFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    DropFrame.BorderSizePixel = 0
    DropFrame.Visible = false
    DropFrame.ZIndex = 20
    DropFrame.Parent = Main
    local dfc = Instance.new("UICorner")
    dfc.CornerRadius = UDim.new(0, 8)
    dfc.Parent = DropFrame
    local dfs = Instance.new("UIStroke")
    dfs.Color = Color3.fromRGB(60, 60, 75)
    dfs.Thickness = 1
    dfs.Parent = DropFrame

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -12, 0, 28)
    SearchBox.Position = UDim2.new(0, 6, 0, 6)
    SearchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    SearchBox.PlaceholderText = "Search..."
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(230, 230, 240)
    SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 115)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 12
    SearchBox.ClearTextOnFocus = false
    SearchBox.ZIndex = 21
    SearchBox.Parent = DropFrame
    local sbc = Instance.new("UICorner")
    sbc.CornerRadius = UDim.new(0, 6)
    sbc.Parent = SearchBox

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -12, 1, -42)
    Scroll.Position = UDim2.new(0, 6, 0, 38)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 4
    Scroll.ZIndex = 21
    Scroll.Parent = DropFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = Scroll

    local allItems = get_items_list()

    local function rebuild_list(filter)
        for _, child in ipairs(Scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local count = 0
        filter = (filter or ""):lower()
        for _, name in ipairs(allItems) do
            if filter == "" or name:lower():find(filter, 1, true) then
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 28)
                btn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
                btn.BackgroundTransparency = 0.3
                btn.Text = "  " .. name
                btn.TextColor3 = Color3.fromRGB(220, 220, 230)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.ZIndex = 22
                btn.Parent = Scroll
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 5)
                bc.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    State.ItemName = name
                    State.Icon = get_item_icon(name)
                    State.Color = Color3.fromRGB(255, 255, 255)
                    ItemBtn.Text = "  " .. name
                    DropFrame.Visible = false
                    Status.Text = "Selected: " .. name
                    Status.TextColor3 = Color3.fromRGB(180, 180, 190)
                end)
                count = count + 1
            end
        end
        Scroll.CanvasSize = UDim2.new(0, 0, 0, count * 30)
    end

    rebuild_list("")

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        rebuild_list(SearchBox.Text)
    end)

    ItemBtn.MouseButton1Click:Connect(function()
        DropFrame.Visible = not DropFrame.Visible
        if DropFrame.Visible then
            SearchBox.Text = ""
            rebuild_list("")
            SearchBox:CaptureFocus()
        end
    end)

    task.spawn(function()
        while gui and gui.Parent do
            task.wait(LOOP_DELAY)
            if get_vicinity_frame() then
                fill_empty_slots()
            end
        end
    end)

    return gui, Status
end

-- ============================================================
-- KEY UI
-- ============================================================
local function show_key_ui()
    local core = game:GetService("CoreGui")
    local old = core:FindFirstChild("PDKeySystem")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PDKeySystem"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = core

    local dim = Instance.new("Frame")
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.45
    dim.BorderSizePixel = 0
    dim.Parent = gui

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 340, 0, 200)
    box.Position = UDim2.new(0.5, -170, 0.5, -100)
    box.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    box.BorderSizePixel = 0
    box.Parent = gui

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 12)
    bc.Parent = box

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 190, 0)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = box

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "∞  Item Filler  ·  Key Required"
    title.TextColor3 = Color3.fromRGB(255, 190, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = box

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -24, 0, 18)
    sub.Position = UDim2.new(0, 12, 0, 42)
    sub.BackgroundTransparency = 1
    sub.Text = "Enter a valid key to continue"
    sub.TextColor3 = Color3.fromRGB(140, 140, 155)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = box

    local inputBg = Instance.new("Frame")
    inputBg.Size = UDim2.new(1, -24, 0, 36)
    inputBg.Position = UDim2.new(0, 12, 0, 72)
    inputBg.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    inputBg.BorderSizePixel = 0
    inputBg.Parent = box
    local ibc = Instance.new("UICorner")
    ibc.CornerRadius = UDim.new(0, 8)
    ibc.Parent = inputBg

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -16, 1, 0)
    keyBox.Position = UDim2.new(0, 8, 0, 0)
    keyBox.BackgroundTransparency = 1
    keyBox.Text = ""
    keyBox.PlaceholderText = "KEY..."
    keyBox.TextColor3 = Color3.fromRGB(230, 230, 240)
    keyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    keyBox.Font = Enum.Font.GothamSemibold
    keyBox.TextSize = 14
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = inputBg

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -24, 0, 18)
    status.Position = UDim2.new(0, 12, 0, 116)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(220, 80, 80)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = box

    local verifyBtn = Instance.new("TextButton")
    verifyBtn.Size = UDim2.new(1, -24, 0, 38)
    verifyBtn.Position = UDim2.new(0, 12, 0, 142)
    verifyBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 20)
    verifyBtn.Text = "VERIFY KEY"
    verifyBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    verifyBtn.Font = Enum.Font.GothamBold
    verifyBtn.TextSize = 14
    verifyBtn.Parent = box
    local vbc = Instance.new("UICorner")
    vbc.CornerRadius = UDim.new(0, 8)
    vbc.Parent = verifyBtn

    local function try_key()
        local key = keyBox.Text
        if not key or key:gsub("%s+", "") == "" then
            status.Text = "Enter a key"
            status.TextColor3 = Color3.fromRGB(220, 80, 80)
            return
        end

        status.Text = "Checking online..."
        status.TextColor3 = Color3.fromRGB(180, 180, 100)
        task.wait(0.15)

        cached_keys = nil
        if is_valid_key(key) then
            status.Text = "Key accepted"
            status.TextColor3 = Color3.fromRGB(80, 220, 120)
            task.wait(0.35)
            gui:Destroy()
            State.Icon = get_item_icon(State.ItemName)
            create_ui()
            print("[Item Filler] Key accepted — loaded")
        else
            status.Text = "Invalid key"
            status.TextColor3 = Color3.fromRGB(220, 80, 80)
            keyBox.Text = ""
        end
    end

    verifyBtn.MouseButton1Click:Connect(try_key)
    keyBox.FocusLost:Connect(function(enter)
        if enter then try_key() end
    end)

    keyBox:CaptureFocus()
end

-- ============================================================
-- INIT
-- ============================================================
show_key_ui()
print("[Item Filler] Waiting for key...")
