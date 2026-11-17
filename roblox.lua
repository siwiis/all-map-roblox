--[[
================================================================================
  BimSakSin Hub 2.0 | Interactive Developer & QA Inspector Panel
  Environment : Roblox Luau (Universal / All-Map Compatible)
  Features    : Real-Time Telemetry, Movement & Physics QA, Waypoint & Camera
                Navigation, Environment Lighting Controls, Multi-Theme UI
================================================================================
]]

-- Prevent duplicate instances if re-executed
do
    local existingName = "BimSakSinHub_v2"
    local function cleanupContainer(container)
        if not container then return end
        pcall(function()
            local old = container:FindFirstChild(existingName)
            if old then
                old:Destroy()
            end
        end)
    end

    if typeof(gethui) == "function" then
        cleanupContainer(gethui())
    end
    cleanupContainer(game:GetService("CoreGui"))
    local lp = game:GetService("Players").LocalPlayer
    if lp then
        cleanupContainer(lp:FindFirstChild("PlayerGui"))
    end
end

-- Core Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Modular Application Tables (Prevents hitting Luau's 200 local register limit)
local App = {
    Name = "BimSakSin Hub 2.0",
    Subtitle = "Developer & QA Inspector Suite",
    Version = "v2.0.0",
    GuiName = "BimSakSinHub_v2",
    IsOpen = true,
    IsMinimized = false,
    ActiveTab = "Dashboard",
    StartTime = os.clock(),
}

local Theme = {
    BgPrimary = Color3.fromRGB(14, 16, 22),
    BgSecondary = Color3.fromRGB(20, 23, 32),
    BgCard = Color3.fromRGB(26, 30, 42),
    BgControl = Color3.fromRGB(34, 39, 54),
    Border = Color3.fromRGB(48, 55, 76),
    TextPrimary = Color3.fromRGB(242, 245, 255),
    TextSecondary = Color3.fromRGB(154, 164, 190),
    TextMuted = Color3.fromRGB(102, 112, 138),
    Accent = Color3.fromRGB(79, 124, 255),
    AccentDark = Color3.fromRGB(48, 82, 185),
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(241, 196, 15),
    Danger = Color3.fromRGB(235, 87, 87),
}

local State = {
    WalkSpeed = 16,
    JumpPower = 50,
    Gravity = workspace.Gravity,
    FlyEnabled = false,
    FlySpeed = 60,
    NoclipEnabled = false,
    InfiniteJumpEnabled = false,
    CameraFOV = 70,
    FullbrightEnabled = false,
    NoFogEnabled = false,
    SpectatingPlayer = nil,
    Waypoints = {},
    AccentObjects = {},
    OriginalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    },
}

local Connections = {}
local UI = {
    Tabs = {},
    Pages = {},
    TelemetryLabels = {},
}

-- Utility Functions
local Utils = {}

function Utils.Track(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

function Utils.Tween(obj, info, props)
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    return tween
end

function Utils.Create(className, props, parent)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

function Utils.AddCorner(parent, radius)
    return Utils.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, parent)
end

function Utils.AddStroke(parent, color, thickness, transparency)
    return Utils.Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

function Utils.RegisterAccent(obj, property)
    table.insert(State.AccentObjects, { Object = obj, Property = property })
    obj[property] = Theme.Accent
end

function Utils.SetAccentColor(newColor, newDark)
    Theme.Accent = newColor
    Theme.AccentDark = newDark or newColor
    for _, item in ipairs(State.AccentObjects) do
        if item.Object and item.Object.Parent then
            item.Object[item.Property] = newColor
        end
    end
end

function Utils.GetCharacter()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

function Utils.CopyText(text)
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, tostring(text))
    elseif typeof(toclipboard) == "function" then
        ok = pcall(toclipboard, tostring(text))
    end
    return ok
end

-- Resolve Safe GUI Parent
local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then
        return coreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Build Root ScreenGui & Notification System
do
    UI.ScreenGui = Utils.Create("ScreenGui", {
        Name = App.GuiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, getGuiParent())

    UI.ToastContainer = Utils.Create("Frame", {
        Name = "ToastContainer",
        Size = UDim2.new(0, 290, 1, -24),
        Position = UDim2.new(1, -306, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = 50,
    }, UI.ScreenGui)

    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, UI.ToastContainer)
end

function Utils.Notify(title, message, color)
    if not UI.ToastContainer or not UI.ToastContainer.Parent then return end
    local accent = color or Theme.Accent

    local toast = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.BgSecondary,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 51,
    }, UI.ToastContainer)
    Utils.AddCorner(toast, 8)
    Utils.AddStroke(toast, Theme.Border, 1)

    local bar = Utils.Create("Frame", {
        Size = UDim2.new(0, 4, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 52,
    }, toast)
    Utils.AddCorner(bar, 2)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 18, 0, 7),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 52,
    }, toast)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 18, 0, 27),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = message,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 52,
    }, toast)

    task.delay(3.2, function()
        if toast and toast.Parent then
            Utils.Tween(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1
            })
            task.wait(0.26)
            if toast and toast.Parent then
                toast:Destroy()
            end
        end
    end)
end

-- Build Main Window, Topbar, Sidebar, and Floating Mobile Toggle
do
    -- Floating Toggle Pill (Ideal for Mobile / Touch & Quick Access)
    UI.FloatingToggle = Utils.Create("TextButton", {
        Name = "FloatingToggle",
        Size = UDim2.new(0, 86, 0, 34),
        Position = UDim2.new(0, 16, 0.5, -17),
        BackgroundColor3 = Theme.BgSecondary,
        Font = Enum.Font.GothamBold,
        Text = "BS 2.0",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        AutoButtonColor = false,
        ZIndex = 40,
    }, UI.ScreenGui)
    Utils.AddCorner(UI.FloatingToggle, 17)
    local floatStroke = Utils.AddStroke(UI.FloatingToggle, Theme.Accent, 1.5)
    Utils.RegisterAccent(floatStroke, "Color")

    -- Main Window Container
    UI.MainFrame = Utils.Create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 620, 0, 410),
        Position = UDim2.new(0.5, -310, 0.5, -205),
        BackgroundColor3 = Theme.BgPrimary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 10,
    }, UI.ScreenGui)
    Utils.AddCorner(UI.MainFrame, 12)
    Utils.AddStroke(UI.MainFrame, Theme.Border, 1.2)

    -- Top Header Bar
    UI.Topbar = Utils.Create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgSecondary,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, UI.MainFrame)
    Utils.AddCorner(UI.Topbar, 12)

    -- Mask bottom corners of Topbar
    Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.BgSecondary,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, UI.Topbar)

    -- Divider line under Topbar
    Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.Topbar)

    -- Brand Accent Badge
    local brandBadge = Utils.Create("Frame", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 14, 0.5, -14),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.Topbar)
    Utils.AddCorner(brandBadge, 7)
    Utils.RegisterAccent(brandBadge, "BackgroundColor3")

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        Text = "BS",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        ZIndex = 13,
    }, brandBadge)

    -- Panel Title ("BimSakSin Hub 2.0")
    Utils.Create("TextLabel", {
        Size = UDim2.new(0, 260, 0, 20),
        Position = UDim2.new(0, 50, 0, 6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = App.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, UI.Topbar)

    Utils.Create("TextLabel", {
        Size = UDim2.new(0, 260, 0, 14),
        Position = UDim2.new(0, 50, 0, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = App.Subtitle .. " • " .. App.Version,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, UI.Topbar)

    -- Topbar Window Controls (Minimize & Close)
    local function createTopBtn(text, offsetX, hoverColor)
        local btn = Utils.Create("TextButton", {
            Size = UDim2.new(0, 28, 0, 28),
            Position = UDim2.new(1, offsetX, 0.5, -14),
            BackgroundColor3 = Theme.BgControl,
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = Theme.TextPrimary,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 13,
        }, UI.Topbar)
        Utils.AddCorner(btn, 6)
        btn.MouseEnter:Connect(function()
            Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor })
        end)
        btn.MouseLeave:Connect(function()
            Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.BgControl })
        end)
        return btn
    end

    UI.MinimizeBtn = createTopBtn("—", -72, Theme.Accent)
    UI.CloseBtn = createTopBtn("✕", -38, Theme.Danger)

    -- Left Navigation Sidebar
    UI.Sidebar = Utils.Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 162, 1, -48),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = Theme.BgSecondary,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, UI.MainFrame)

    Utils.Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.Sidebar)

    UI.SidebarList = Utils.Create("Frame", {
        Size = UDim2.new(1, -16, 1, -46),
        Position = UDim2.new(0, 8, 0, 10),
        BackgroundTransparency = 1,
        ZIndex = 12,
    }, UI.Sidebar)

    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, UI.SidebarList)

    -- Sidebar Footer Status
    local footerBox = Utils.Create("Frame", {
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 1, -36),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.Sidebar)
    Utils.AddCorner(footerBox, 6)

    local dot = Utils.Create("Frame", {
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0.5, -4),
        BackgroundColor3 = Theme.Success,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, footerBox)
    Utils.AddCorner(dot, 4)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = "Session Active",
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, footerBox)

    -- Right Content Area
    UI.ContentContainer = Utils.Create("Frame", {
        Name = "ContentContainer",
        Size = UDim2.new(1, -162, 1, -48),
        Position = UDim2.new(0, 162, 0, 48),
        BackgroundTransparency = 1,
        ZIndex = 11,
    }, UI.MainFrame)
end

-- Dragging Support (Supports Both Mouse & Touchscreens)
do
    local function makeDraggable(dragHandle, targetFrame)
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil

        Utils.Track(dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = targetFrame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end))

        Utils.Track(dragHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end))

        Utils.Track(UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging and dragStart and startPos then
                local delta = input.Position - dragStart
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end))
    end

    makeDraggable(UI.Topbar, UI.MainFrame)
    makeDraggable(UI.FloatingToggle, UI.FloatingToggle)
end

-- Reusable UI Component Builders
local Components = {}

function Components.SwitchTab(tabName)
    App.ActiveTab = tabName
    for name, tabData in pairs(UI.Tabs) do
        local isSelected = (name == tabName)
        Utils.Tween(tabData.Button, TweenInfo.new(0.18), {
            BackgroundColor3 = isSelected and Theme.BgControl or Theme.BgSecondary,
            BackgroundTransparency = isSelected and 0 or 1,
        })
        tabData.Label.TextColor3 = isSelected and Theme.TextPrimary or Theme.TextSecondary
        tabData.Indicator.Visible = isSelected
    end
    for name, page in pairs(UI.Pages) do
        page.Visible = (name == tabName)
    end
end

function Components.CreateTab(name, iconText, order)
    local btn = Utils.Create("TextButton", {
        Name = name .. "Tab",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.BgControl,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 13,
    }, UI.SidebarList)
    Utils.AddCorner(btn, 7)

    local indicator = Utils.Create("Frame", {
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 4, 0.5, -9),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 14,
    }, btn)
    Utils.AddCorner(indicator, 2)
    Utils.RegisterAccent(indicator, "BackgroundColor3")

    local label = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -18, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = iconText .. "  " .. name,
        TextColor3 = Theme.TextSecondary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, btn)

    local page = Utils.Create("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 12,
    }, UI.ContentContainer)

    local layout = Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    Utils.Create("UIPadding", {
        PaddingRight = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
    }, page)

    btn.MouseButton1Click:Connect(function()
        Components.SwitchTab(name)
    end)

    UI.Tabs[name] = {
        Button = btn,
        Label = label,
        Indicator = indicator,
    }
    UI.Pages[name] = page
    return page
end

function Components.AddSectionHeader(parent, title, order)
    local lbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = string.upper(title),
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
        ZIndex = 13,
    }, parent)
    return lbl
end

function Components.AddToggle(parent, title, subtitle, defaultVal, order, callback)
    local enabled = defaultVal == true

    local card = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 13,
    }, parent)
    Utils.AddCorner(card, 8)
    Utils.AddStroke(card, Theme.Border, 1)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 18),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, card)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 14),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, card)

    local switchTrack = Utils.Create("TextButton", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = enabled and Theme.Accent or Theme.BgControl,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
    }, card)
    Utils.AddCorner(switchTrack, 11)

    local knob = Utils.Create("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 15,
    }, switchTrack)
    Utils.AddCorner(knob, 8)

    local function setState(newState, fireCallback)
        enabled = newState
        Utils.Tween(switchTrack, TweenInfo.new(0.18), {
            BackgroundColor3 = enabled and Theme.Accent or Theme.BgControl
        })
        Utils.Tween(knob, TweenInfo.new(0.18), {
            Position = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        })
        if fireCallback and callback then
            callback(enabled)
        end
    end

    switchTrack.MouseButton1Click:Connect(function()
        setState(not enabled, true)
    end)

    return {
        SetState = setState,
        GetState = function() return enabled end,
    }
end

function Components.AddSlider(parent, title, minVal, maxVal, defaultVal, decimals, order, callback)
    local currentVal = math.clamp(defaultVal, minVal, maxVal)
    local precision = decimals or 0

    local card = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 13,
    }, parent)
    Utils.AddCorner(card, 8)
    Utils.AddStroke(card, Theme.Border, 1)

    Utils.Create("TextLabel", {
        Size = UDim2.new(0.65, 0, 0, 18),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, card)

    local function formatVal(v)
        if precision <= 0 then
            return tostring(math.floor(v + 0.5))
        end
        return string.format("%." .. tostring(precision) .. "f", v)
    end

    local valueLabel = Utils.Create("TextLabel", {
        Size = UDim2.new(0.3, -12, 0, 18),
        Position = UDim2.new(0.7, 0, 0, 8),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = formatVal(currentVal),
        TextColor3 = Theme.Accent,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 14,
    }, card)
    Utils.RegisterAccent(valueLabel, "TextColor3")

    local track = Utils.Create("TextButton", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 38),
        BackgroundColor3 = Theme.BgControl,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
    }, card)
    Utils.AddCorner(track, 4)

    local initRatio = (currentVal - minVal) / math.max(0.0001, (maxVal - minVal))
    local fill = Utils.Create("Frame", {
        Size = UDim2.new(initRatio, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 15,
    }, track)
    Utils.AddCorner(fill, 4)
    Utils.RegisterAccent(fill, "BackgroundColor3")

    local thumb = Utils.Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(initRatio, -7, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 16,
    }, track)
    Utils.AddCorner(thumb, 7)

    local sliding = false

    local function setValue(val, fireCallback)
        currentVal = math.clamp(val, minVal, maxVal)
        if precision <= 0 then
            currentVal = math.floor(currentVal + 0.5)
        else
            local mult = 10 ^ precision
            currentVal = math.floor(currentVal * mult + 0.5) / mult
        end
        local ratio = (currentVal - minVal) / math.max(0.0001, (maxVal - minVal))
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, -7, 0.5, -7)
        valueLabel.Text = formatVal(currentVal)
        if fireCallback and callback then
            callback(currentVal)
        end
    end

    local function updateFromInput(inputPos)
        local trackWidth = track.AbsoluteSize.X
        if trackWidth <= 0 then return end
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / trackWidth, 0, 1)
        local rawVal = minVal + (maxVal - minVal) * relX
        setValue(rawVal, true)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position)
        end
    end)

    Utils.Track(UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position)
        end
    end))

    Utils.Track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end))

    return {
        SetValue = setValue,
        GetValue = function() return currentVal end,
    }
end

function Components.AddButton(parent, title, subtitle, btnLabel, order, callback)
    local card = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 13,
    }, parent)
    Utils.AddCorner(card, 8)
    Utils.AddStroke(card, Theme.Border, 1)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 18),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, card)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 14),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, card)

    local actionBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 86, 0, 28),
        Position = UDim2.new(1, -98, 0.5, -14),
        BackgroundColor3 = Theme.Accent,
        Font = Enum.Font.GothamBold,
        Text = btnLabel,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 14,
    }, card)
    Utils.AddCorner(actionBtn, 6)
    Utils.RegisterAccent(actionBtn, "BackgroundColor3")

    actionBtn.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)

    return actionBtn
end

-- ============================================================================
-- TAB 1: DASHBOARD & TELEMETRY
-- ============================================================================
do
    local page = Components.CreateTab("Dashboard", "◈", 1)
    Components.AddSectionHeader(page, "Live Client Telemetry", 1)

    local grid = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 124),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        ZIndex = 13,
    }, page)

    Utils.Create("UIGridLayout", {
        CellSize = UDim2.new(0.485, 0, 0, 58),
        CellPadding = UDim2.new(0.03, 0, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local function createStatCard(labelTitle, initialValue, order)
        local box = Utils.Create("Frame", {
            BackgroundColor3 = Theme.BgCard,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 13,
        }, grid)
        Utils.AddCorner(box, 8)
        Utils.AddStroke(box, Theme.Border, 1)

        Utils.Create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 16),
            Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = labelTitle,
            TextColor3 = Theme.TextSecondary,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 14,
        }, box)

        local valLbl = Utils.Create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 22),
            Position = UDim2.new(0, 10, 0, 26),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = initialValue,
            TextColor3 = Theme.TextPrimary,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 14,
        }, box)

        return valLbl
    end

    UI.TelemetryLabels.FPS = createStatCard("Frame Rate (FPS)", "60 FPS", 1)
    UI.TelemetryLabels.Ping = createStatCard("Network Latency", "-- ms", 2)
    UI.TelemetryLabels.Memory = createStatCard("Client Memory", "-- MB", 3)
    UI.TelemetryLabels.Players = createStatCard("Active Players", tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers), 4)

    Components.AddSectionHeader(page, "Server & Session Utilities", 3)

    Components.AddButton(page, "Copy Place & Job ID", "PlaceId: " .. tostring(game.PlaceId), "Copy ID", 4, function()
        local infoStr = string.format("PlaceId: %s | JobId: %s", tostring(game.PlaceId), tostring(game.JobId))
        if Utils.CopyText(infoStr) then
            Utils.Notify("Copied to Clipboard", infoStr, Theme.Success)
        else
            Utils.Notify("Server Info", infoStr, Theme.Accent)
        end
    end)

    Components.AddButton(page, "Respawn Character", "Safely refresh local character state", "Respawn", 5, function()
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.Health = 0
            Utils.Notify("Character", "Respawning character...", Theme.Warning)
        end
    end)

    Components.AddButton(page, "Rejoin Current Server", "Reconnect to the same PlaceId instance", "Rejoin", 6, function()
        Utils.Notify("TeleportService", "Attempting to rejoin server...", Theme.Accent)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)
end

-- ============================================================================
-- TAB 2: MOVEMENT & PHYSICS (QA)
-- ============================================================================
do
    local page = Components.CreateTab("Movement", "⚡", 2)
    Components.AddSectionHeader(page, "Character Locomotion Tuning", 1)

    local wsSlider = Components.AddSlider(page, "WalkSpeed", 16, 250, 16, 0, 2, function(val)
        State.WalkSpeed = val
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.WalkSpeed = val
        end
    end)

    local jpSlider = Components.AddSlider(page, "JumpPower", 50, 300, 50, 0, 3, function(val)
        State.JumpPower = val
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end)

    local gravSlider = Components.AddSlider(page, "Workspace Gravity", 0, 300, math.floor(workspace.Gravity + 0.5), 0, 4, function(val)
        State.Gravity = val
        workspace.Gravity = val
    end)

    Components.AddButton(page, "Reset Physics Defaults", "Restore WalkSpeed (16), JumpPower (50), Gravity (196)", "Reset All", 5, function()
        wsSlider.SetValue(16, true)
        jpSlider.SetValue(50, true)
        gravSlider.SetValue(196, true)
        Utils.Notify("Physics Reset", "All movement values restored to default.", Theme.Success)
    end)

    Components.AddSectionHeader(page, "Inspection & Navigation Modes", 6)

    Components.AddToggle(page, "Free-Flight Inspector (Fly)", "Camera-directed flight (Works on PC & Mobile)", false, 7, function(on)
        State.FlyEnabled = on
        Utils.Notify("Free-Flight", on and "Flight mode enabled." or "Flight mode disabled.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddSlider(page, "Flight Speed", 20, 250, 60, 0, 8, function(val)
        State.FlySpeed = val
    end)

    Components.AddToggle(page, "Noclip Geometry Inspector", "Disable character part collisions to inspect map interiors", false, 9, function(on)
        State.NoclipEnabled = on
        if not on then
            local char = Utils.GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
        Utils.Notify("Noclip", on and "Collision disabled." or "Collision restored.", on and Theme.Warning or Theme.TextSecondary)
    end)

    Components.AddToggle(page, "Infinite Jump", "Allow mid-air jump triggers for vertical map testing", false, 10, function(on)
        State.InfiniteJumpEnabled = on
    end)
end

-- ============================================================================
-- TAB 3: WORLD & WAYPOINTS
-- ============================================================================
do
    local page = Components.CreateTab("World", "⌖", 3)
    Components.AddSectionHeader(page, "Coordinates & Waypoint Manager", 1)

    -- Live Coordinate Card
    local posCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 13,
    }, page)
    Utils.AddCorner(posCard, 8)
    Utils.AddStroke(posCard, Theme.Border, 1)

    UI.TelemetryLabels.Coords = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -112, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = "XYZ: 0.0, 0.0, 0.0",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, posCard)

    local copyPosBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 92, 0, 28),
        Position = UDim2.new(1, -104, 0.5, -14),
        BackgroundColor3 = Theme.BgControl,
        Font = Enum.Font.GothamBold,
        Text = "Copy CFrame",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 14,
    }, posCard)
    Utils.AddCorner(copyPosBtn, 6)

    copyPosBtn.MouseButton1Click:Connect(function()
        local _, _, root = Utils.GetCharacter()
        if root then
            local p = root.Position
            local cfStr = string.format("CFrame.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
            if Utils.CopyText(cfStr) then
                Utils.Notify("Copied CFrame", cfStr, Theme.Success)
            else
                Utils.Notify("Current CFrame", cfStr, Theme.Accent)
            end
        end
    end)

    -- Add Waypoint Input Row
    local wpInputCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        ZIndex = 13,
    }, page)
    Utils.AddCorner(wpInputCard, 8)
    Utils.AddStroke(wpInputCard, Theme.Border, 1)

    local wpBox = Utils.Create("TextBox", {
        Size = UDim2.new(1, -124, 0, 30),
        Position = UDim2.new(0, 10, 0.5, -15),
        BackgroundColor3 = Theme.BgControl,
        Font = Enum.Font.Gotham,
        PlaceholderText = "Waypoint name (e.g. Spawn, Roof)...",
        PlaceholderColor3 = Theme.TextMuted,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        ClearTextOnFocus = false,
        ZIndex = 14,
    }, wpInputCard)
    Utils.AddCorner(wpBox, 6)
    Utils.Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, wpBox)

    local saveWpBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 96, 0, 30),
        Position = UDim2.new(1, -106, 0.5, -15),
        BackgroundColor3 = Theme.Accent,
        Font = Enum.Font.GothamBold,
        Text = "+ Save Point",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 14,
    }, wpInputCard)
    Utils.AddCorner(saveWpBtn, 6)
    Utils.RegisterAccent(saveWpBtn, "BackgroundColor3")

    local wpListHolder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        ZIndex = 13,
    }, page)
    Utils.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, wpListHolder)

    local function renderWaypoints()
        for _, child in ipairs(wpListHolder:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        for idx, wp in ipairs(State.Waypoints) do
            local row = Utils.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Theme.BgSecondary,
                BorderSizePixel = 0,
                LayoutOrder = idx,
                ZIndex = 14,
            }, wpListHolder)
            Utils.AddCorner(row, 7)
            Utils.AddStroke(row, Theme.Border, 1)

            Utils.Create("TextLabel", {
                Size = UDim2.new(1, -138, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamMedium,
                Text = string.format("%s (%.0f, %.0f, %.0f)", wp.Name, wp.CFrame.X, wp.CFrame.Y, wp.CFrame.Z),
                TextColor3 = Theme.TextPrimary,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 15,
            }, row)

            local tpBtn = Utils.Create("TextButton", {
                Size = UDim2.new(0, 68, 0, 24),
                Position = UDim2.new(1, -112, 0.5, -12),
                BackgroundColor3 = Theme.Accent,
                Font = Enum.Font.GothamBold,
                Text = "Teleport",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 15,
            }, row)
            Utils.AddCorner(tpBtn, 5)

            local delBtn = Utils.Create("TextButton", {
                Size = UDim2.new(0, 28, 0, 24),
                Position = UDim2.new(1, -38, 0.5, -12),
                BackgroundColor3 = Theme.Danger,
                Font = Enum.Font.GothamBold,
                Text = "✕",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 15,
            }, row)
            Utils.AddCorner(delBtn, 5)

            tpBtn.MouseButton1Click:Connect(function()
                local _, _, root = Utils.GetCharacter()
                if root then
                    root.CFrame = wp.CFrame
                    Utils.Notify("Waypoint", "Teleported to " .. wp.Name, Theme.Success)
                end
            end)

            delBtn.MouseButton1Click:Connect(function()
                table.remove(State.Waypoints, idx)
                renderWaypoints()
            end)
        end
    end

    saveWpBtn.MouseButton1Click:Connect(function()
        local _, _, root = Utils.GetCharacter()
        if not root then
            Utils.Notify("Error", "Character root not found.", Theme.Danger)
            return
        end
        local name = wpBox.Text ~= "" and wpBox.Text or ("Point #" .. tostring(#State.Waypoints + 1))
        table.insert(State.Waypoints, {
            Name = name,
            CFrame = root.CFrame,
        })
        wpBox.Text = ""
        renderWaypoints()
        Utils.Notify("Waypoint Saved", "Saved '" .. name .. "'", Theme.Success)
    end)

    Components.AddSectionHeader(page, "Player Inspector & Teleport", 5)

    local playerListHolder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 6,
        ZIndex = 13,
    }, page)
    Utils.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, playerListHolder)

    local function refreshPlayerList()
        for _, child in ipairs(playerListHolder:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local row = Utils.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Theme.BgCard,
                    BorderSizePixel = 0,
                    LayoutOrder = count,
                    ZIndex = 14,
                }, playerListHolder)
                Utils.AddCorner(row, 7)
                Utils.AddStroke(row, Theme.Border, 1)

                Utils.Create("TextLabel", {
                    Size = UDim2.new(1, -155, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 15,
                }, row)

                local tpBtn = Utils.Create("TextButton", {
                    Size = UDim2.new(0, 64, 0, 24),
                    Position = UDim2.new(1, -138, 0.5, -12),
                    BackgroundColor3 = Theme.Accent,
                    Font = Enum.Font.GothamBold,
                    Text = "Goto",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 15,
                }, row)
                Utils.AddCorner(tpBtn, 5)

                local isSpec = (State.SpectatingPlayer == plr)
                local viewBtn = Utils.Create("TextButton", {
                    Size = UDim2.new(0, 60, 0, 24),
                    Position = UDim2.new(1, -68, 0.5, -12),
                    BackgroundColor3 = isSpec and Theme.Warning or Theme.BgControl,
                    Font = Enum.Font.GothamBold,
                    Text = isSpec and "Unview" or "View",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 15,
                }, row)
                Utils.AddCorner(viewBtn, 5)

                tpBtn.MouseButton1Click:Connect(function()
                    local _, _, myRoot = Utils.GetCharacter()
                    local targetRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if myRoot and targetRoot then
                        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                        Utils.Notify("Teleport", "Moved to " .. plr.DisplayName, Theme.Success)
                    else
                        Utils.Notify("Unavailable", "Target character is not spawned.", Theme.Warning)
                    end
                end)

                viewBtn.MouseButton1Click:Connect(function()
                    local cam = workspace.CurrentCamera
                    if State.SpectatingPlayer == plr then
                        State.SpectatingPlayer = nil
                        local _, myHum = Utils.GetCharacter()
                        if cam and myHum then
                            cam.CameraSubject = myHum
                        end
                        Utils.Notify("Camera", "Restored camera to LocalPlayer.", Theme.TextSecondary)
                    else
                        local targetHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                        if cam and targetHum then
                            State.SpectatingPlayer = plr
                            cam.CameraSubject = targetHum
                            Utils.Notify("Spectating", "Viewing " .. plr.DisplayName, Theme.Warning)
                        end
                    end
                    refreshPlayerList()
                end)
            end
        end

        if count == 0 then
            local empty = Utils.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.BgCard,
                BorderSizePixel = 0,
                ZIndex = 14,
            }, playerListHolder)
            Utils.AddCorner(empty, 7)
            Utils.Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = "No other players currently in this server.",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                ZIndex = 15,
            }, empty)
        end
    end

    refreshPlayerList()
    Utils.Track(Players.PlayerAdded:Connect(refreshPlayerList))
    Utils.Track(Players.PlayerRemoving:Connect(function(plr)
        if State.SpectatingPlayer == plr then
            State.SpectatingPlayer = nil
            local _, myHum = Utils.GetCharacter()
            if workspace.CurrentCamera and myHum then
                workspace.CurrentCamera.CameraSubject = myHum
            end
        end
        task.defer(refreshPlayerList)
    end))
end

-- ============================================================================
-- TAB 4: VISUALS & ENVIRONMENT
-- ============================================================================
do
    local page = Components.CreateTab("Visuals", "☀", 4)
    Components.AddSectionHeader(page, "Camera & Rendering Controls", 1)

    local fovSlider = Components.AddSlider(page, "Camera Field of View (FOV)", 40, 120, 70, 0, 2, function(val)
        State.CameraFOV = val
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = val
        end
    end)

    Components.AddToggle(page, "Fullbright Studio Lighting", "Override dark shadows and boost ambient visibility", false, 3, function(on)
        State.FullbrightEnabled = on
        if on then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        else
            local orig = State.OriginalLighting
            Lighting.Brightness = orig.Brightness
            Lighting.ClockTime = orig.ClockTime
            Lighting.GlobalShadows = orig.GlobalShadows
            Lighting.Ambient = orig.Ambient
            Lighting.OutdoorAmbient = orig.OutdoorAmbient
        end
        Utils.Notify("Lighting", on and "Fullbright enabled." or "Original lighting restored.", Theme.Accent)
    end)

    Components.AddToggle(page, "Clear Atmospheric Fog", "Set FogEnd distance to maximum for clear map view", false, 4, function(on)
        State.NoFogEnabled = on
        if on then
            Lighting.FogEnd = 100000
        else
            Lighting.FogEnd = State.OriginalLighting.FogEnd
        end
    end)

    Components.AddSlider(page, "Client Time of Day (Hour)", 0, 24, math.floor(Lighting.ClockTime), 1, 5, function(val)
        Lighting.ClockTime = val
    end)

    Components.AddButton(page, "Reset Visuals & Camera", "Restore FOV (70) and default Lighting", "Reset", 6, function()
        fovSlider.SetValue(70, true)
        local orig = State.OriginalLighting
        Lighting.Brightness = orig.Brightness
        Lighting.ClockTime = orig.ClockTime
        Lighting.FogEnd = orig.FogEnd
        Lighting.GlobalShadows = orig.GlobalShadows
        Lighting.Ambient = orig.Ambient
        Lighting.OutdoorAmbient = orig.OutdoorAmbient
        Utils.Notify("Visuals Reset", "Camera and Lighting restored.", Theme.Success)
    end)
end

-- ============================================================================
-- TAB 5: SETTINGS & THEME
-- ============================================================================
do
    local page = Components.CreateTab("Settings", "⚙", 5)
    Components.AddSectionHeader(page, "Interface Accent Theme", 1)

    local themeCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = Theme.BgCard,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 13,
    }, page)
    Utils.AddCorner(themeCard, 8)
    Utils.AddStroke(themeCard, Theme.Border, 1)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = "Select Hub Accent Palette",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, themeCard)

    local paletteRow = Utils.Create("Frame", {
        Size = UDim2.new(1, -24, 0, 28),
        Position = UDim2.new(0, 12, 0, 32),
        BackgroundTransparency = 1,
        ZIndex = 14,
    }, themeCard)
    Utils.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
    }, paletteRow)

    local palettes = {
        { Name = "Cobalt Blue", Color = Color3.fromRGB(79, 124, 255) },
        { Name = "Emerald", Color = Color3.fromRGB(39, 174, 96) },
        { Name = "Royal Violet", Color = Color3.fromRGB(155, 89, 182) },
        { Name = "Crimson", Color = Color3.fromRGB(231, 76, 60) },
        { Name = "Amber Gold", Color = Color3.fromRGB(243, 156, 18) },
    }

    for _, pal in ipairs(palettes) do
        local swatch = Utils.Create("TextButton", {
            Size = UDim2.new(0, 74, 0, 26),
            BackgroundColor3 = pal.Color,
            Font = Enum.Font.GothamBold,
            Text = pal.Name,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 10,
            AutoButtonColor = false,
            ZIndex = 15,
        }, paletteRow)
        Utils.AddCorner(swatch, 6)

        swatch.MouseButton1Click:Connect(function()
            Utils.SetAccentColor(pal.Color)
            Utils.Notify("Theme Updated", "Applied " .. pal.Name .. " accent.", pal.Color)
        end)
    end

    Components.AddSectionHeader(page, "Controls & Unload", 3)

    Components.AddButton(page, "Toggle Keybind: RightShift", "Or tap the floating 'BS 2.0' pill anytime", "Hide UI", 4, function()
        App.IsOpen = false
        UI.MainFrame.Visible = false
    end)

    Components.AddButton(page, "Unload & Clean Up Panel", "Disconnect all loops, restore defaults, and close GUI", "Unload", 5, function()
        -- Restore character and world defaults
        State.FlyEnabled = false
        State.NoclipEnabled = false
        State.InfiniteJumpEnabled = false

        local char, hum = Utils.GetCharacter()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
            if workspace.CurrentCamera then
                workspace.CurrentCamera.CameraSubject = hum
                workspace.CurrentCamera.FieldOfView = 70
            end
        end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end

        workspace.Gravity = 196.2
        local orig = State.OriginalLighting
        Lighting.Brightness = orig.Brightness
        Lighting.ClockTime = orig.ClockTime
        Lighting.FogEnd = orig.FogEnd
        Lighting.GlobalShadows = orig.GlobalShadows
        Lighting.Ambient = orig.Ambient
        Lighting.OutdoorAmbient = orig.OutdoorAmbient

        for _, conn in ipairs(Connections) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        table.clear(Connections)

        if UI.ScreenGui then
            UI.ScreenGui:Destroy()
        end
    end)
end

-- ============================================================================
-- RUNTIME LOOPS & EVENT HANDLERS
-- ============================================================================
do
    -- Window Visibility & Minimize Handlers
    local function togglePanelVisibility()
        App.IsOpen = not App.IsOpen
        UI.MainFrame.Visible = App.IsOpen
    end

    UI.FloatingToggle.MouseButton1Click:Connect(togglePanelVisibility)
    UI.CloseBtn.MouseButton1Click:Connect(function()
        App.IsOpen = false
        UI.MainFrame.Visible = false
        Utils.Notify("Minimized to Pill", "Tap 'BS 2.0' or press RightShift to reopen.", Theme.Accent)
    end)

    UI.MinimizeBtn.MouseButton1Click:Connect(function()
        App.IsMinimized = not App.IsMinimized
        UI.Sidebar.Visible = not App.IsMinimized
        UI.ContentContainer.Visible = not App.IsMinimized
        Utils.Tween(UI.MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = App.IsMinimized and UDim2.new(0, 620, 0, 48) or UDim2.new(0, 620, 0, 410)
        })
    end)

    Utils.Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            togglePanelVisibility()
        end
    end))

    -- Infinite Jump Handler
    Utils.Track(UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJumpEnabled then
            local _, hum = Utils.GetCharacter()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    -- Re-apply WalkSpeed & JumpPower on Character Respawn
    local function onCharacterAdded(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if hum then
            if State.WalkSpeed ~= 16 then
                hum.WalkSpeed = State.WalkSpeed
            end
            if State.JumpPower ~= 50 then
                hum.UseJumpPower = true
                hum.JumpPower = State.JumpPower
            end
        end
    end

    if LocalPlayer.Character then
        task.spawn(onCharacterAdded, LocalPlayer.Character)
    end
    Utils.Track(LocalPlayer.CharacterAdded:Connect(onCharacterAdded))

    -- Noclip Stepped Loop
    Utils.Track(RunService.Stepped:Connect(function()
        if State.NoclipEnabled then
            local char = Utils.GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end))

    -- Smooth Cross-Platform Free-Flight Loop (Supports PC Keyboard + Mobile Thumbstick)
    local flyBV = nil
    local flyBG = nil

    local function cleanupFly()
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.PlatformStand = false
        end
    end

    Utils.Track(RunService.RenderStepped:Connect(function()
        local _, hum, root = Utils.GetCharacter()
        local cam = workspace.CurrentCamera

        if State.FlyEnabled and hum and root and cam then
            if not flyBV or flyBV.Parent ~= root then
                cleanupFly()
                flyBV = Utils.Create("BodyVelocity", {
                    Name = "BSS_FlyVelocity",
                    MaxForce = Vector3.new(9e9, 9e9, 9e9),
                    Velocity = Vector3.zero,
                }, root)
                flyBG = Utils.Create("BodyGyro", {
                    Name = "BSS_FlyGyro",
                    MaxTorque = Vector3.new(9e9, 9e9, 9e9),
                    P = 9e4,
                    D = 500,
                }, root)
            end

            hum.PlatformStand = true
            flyBG.CFrame = cam.CFrame

            local moveDir = Vector3.zero
            -- Mobile / Controller MoveDirection support
            if hum.MoveDirection.Magnitude > 0 then
                local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
                if flatLook.Magnitude > 0.01 then
                    flatLook = flatLook.Unit
                    local forwardAmount = hum.MoveDirection:Dot(flatLook)
                    local rightAmount = hum.MoveDirection:Dot(cam.CFrame.RightVector)
                    moveDir = (cam.CFrame.LookVector * forwardAmount) + (cam.CFrame.RightVector * rightAmount)
                else
                    moveDir = hum.MoveDirection
                end
            end

            -- Vertical Ascend / Descend on Keyboard
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            if moveDir.Magnitude > 0 then
                flyBV.Velocity = moveDir.Unit * State.FlySpeed
            else
                flyBV.Velocity = Vector3.zero
            end
        else
            if flyBV or flyBG then
                cleanupFly()
            end
        end
    end))

    -- Telemetry & Coordinate Updater (Throttled to ~4 Hz for optimal FPS)
    local frameCount = 0
    local lastTick = os.clock()

    Utils.Track(RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = os.clock()
        local dt = now - lastTick
        if dt >= 0.25 then
            local fps = math.floor((frameCount / dt) + 0.5)
            frameCount = 0
            lastTick = now

            if UI.TelemetryLabels.FPS then
                UI.TelemetryLabels.FPS.Text = tostring(fps) .. " FPS"
            end

            local pingOk, pingVal = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            if UI.TelemetryLabels.Ping then
                UI.TelemetryLabels.Ping.Text = pingOk and (tostring(math.floor(pingVal + 0.5)) .. " ms") or "N/A"
            end

            local memOk, memVal = pcall(function()
                return Stats:GetTotalMemoryUsageMb()
            end)
            if UI.TelemetryLabels.Memory then
                UI.TelemetryLabels.Memory.Text = memOk and (string.format("%.1f MB", memVal)) or "N/A"
            end

            if UI.TelemetryLabels.Players then
                UI.TelemetryLabels.Players.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
            end

            local _, _, root = Utils.GetCharacter()
            if UI.TelemetryLabels.Coords then
                if root then
                    local p = root.Position
                    UI.TelemetryLabels.Coords.Text = string.format("XYZ: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
                else
                    UI.TelemetryLabels.Coords.Text = "XYZ: Waiting for character..."
                end
            end
        end
    end))
end

-- Initialize Default Tab & Welcome Notification
Components.SwitchTab("Dashboard")
Utils.Notify(App.Name, "Developer & QA panel loaded successfully.", Theme.Success)
