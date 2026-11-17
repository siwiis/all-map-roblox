--[[
================================================================================
  BimSakSin Hub v3.0 | Universal Halloween Luxury Edition
  Creator     : BimSakSin
  Environment : Roblox Luau (Universal / All-Map & R6/R15 Compatible)
  Features    :
    - Transparent Luxury Halloween UI + 4 Corner 3D Pumpkins + 3D Pumpkin Toggle
    - Universal Adaptive ESP (Team/Enemy/Random, Distance, Health, Transparent
      Avatar Highlight, Custom Font + Adaptive Translucent Font Background)
    - Precision Auto Aimbot Assist + Conditional RGB Weapon Laser (Guns Only)
    - Multi-Style Player Carry (Front, Back, Shoulder, Drag, Overhead, Float)
    - Universal R6 & R15 Dance/Emote Studio (14 Dances + Speed Control)
    - Melee & Knockback Resilience (Anti-Ragdoll, Anti-Knockback, Hitbox Guard)
    - Full Menu Font & Color Customizer with Subtle Adaptive Font Backdrop
    - Anti-AFK & Clean Session Stability Guard
    - Information Tab (Discord & Support/Donation Links)
================================================================================
]]

-- ============================================================================
-- 0. PRE-EXECUTION CLEANUP (Mencegah duplikasi GUI & sisa objek fisika/ESP)
-- ============================================================================
do
    local existingNames = { ["BimSakSinHub_v2"] = true, ["BimSakSinHub_v3"] = true, ["BSS_ESP_Folder"] = true }
    local function cleanupContainer(container)
        if not container then return end
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if existingNames[child.Name] then
                    child:Destroy()
                end
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
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            for _, objName in ipairs({ "BSS_FlyVelocity", "BSS_FlyGyro", "BSS_CarryVelocity" }) do
                local old = root:FindFirstChild(objName)
                if old then old:Destroy() end
            end
        end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end

    local oldLaser = workspace:FindFirstChild("BSS_RGB_AimLaser")
    if oldLaser then oldLaser:Destroy() end
end

-- ============================================================================
-- 1. CORE SERVICES & MODULAR STATE TABLES (Aman dari batas 200 register Luau)
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local Teams = game:GetService("Teams")

local VirtualUser = nil
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local LocalPlayer = Players.LocalPlayer

local App = {
    Name = "BimSakSin Hub v3.0",
    Subtitle = "semoga hari-hari kalian menyenangkan",
    Version = "v3.0 Halloween",
    GuiName = "BimSakSinHub_v3",
    IsOpen = true,
    IsMinimized = false,
    ExpandedWidth = 650,
    ExpandedHeight = 435,
    ActiveTab = "Dashboard",
    StartTime = os.clock(),
    DiscordUrl = "https://discord.gg/YwMCBq22f2",
    DonationUrl = "https://linktr.ee/bimsaksin",
}

local Theme = {
    -- Palet Halloween Mewah & Transparan
    BgPrimary = Color3.fromRGB(13, 11, 19),
    BgSecondary = Color3.fromRGB(20, 16, 30),
    BgCard = Color3.fromRGB(28, 22, 41),
    BgControl = Color3.fromRGB(40, 31, 58),
    Border = Color3.fromRGB(255, 132, 36),
    BorderSubtle = Color3.fromRGB(78, 56, 108),

    TextPrimary = Color3.fromRGB(255, 246, 235),
    TextSecondary = Color3.fromRGB(204, 186, 172),
    TextMuted = Color3.fromRGB(142, 124, 150),

    FontFamily = Enum.Font.GothamSemibold,
    FontBold = Enum.Font.GothamBold,
    FontColorMode = "Auto", -- "Auto" atau Color3 spesifik
    FontBgEnabled = false,
    FontBgColor = Color3.fromRGB(18, 14, 26),
    FontBgTransparency = 0.65,

    Accent = Color3.fromRGB(255, 118, 26),     -- Pumpkin Gold
    AccentDark = Color3.fromRGB(184, 72, 12),
    Crimson = Color3.fromRGB(214, 48, 74),
    Spectral = Color3.fromRGB(155, 89, 245),
    Success = Color3.fromRGB(46, 213, 115),
    Warning = Color3.fromRGB(255, 177, 43),
    Danger = Color3.fromRGB(235, 69, 95),
}

local initialAtmo = Lighting:FindFirstChildOfClass("Atmosphere")

local State = {
    -- Movement & Physics
    WalkSpeed = 16,
    JumpPower = 50,
    OriginalGravity = workspace.Gravity,
    Gravity = workspace.Gravity,
    FlyEnabled = false,
    FlySpeed = 60,
    NoclipEnabled = false,
    InfiniteJumpEnabled = false,

    -- Visuals
    CameraFOV = 70,
    FullbrightEnabled = false,
    NoFogEnabled = false,
    SpectatingPlayer = nil,
    Waypoints = {},

    -- UI Registries
    AccentObjects = {},
    ActiveToggleTracks = {},
    ThemedTexts = {},

    -- Original World Cache
    OriginalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    },
    OriginalAtmosphere = initialAtmo and {
        Instance = initialAtmo,
        Density = initialAtmo.Density,
    } or nil,
}

local Physics = {
    FlyBV = nil,
    FlyBG = nil,
    NoclipCache = {},
}

local ESP = {
    Enabled = false,
    ShowAvatar = true,
    ShowDistance = true,
    ShowHealth = true,
    Mode = "Auto", -- "Auto" | "Enemy" | "Ally" | "Random"
    MaxDistance = 2500,

    -- Warna & Font ESP
    HighlightColor = Color3.fromRGB(255, 118, 26),
    AllyColor = Color3.fromRGB(46, 213, 115),
    EnemyColor = Color3.fromRGB(235, 69, 95),
    DistanceColor = Color3.fromRGB(255, 210, 120),
    HealthColor = Color3.fromRGB(85, 239, 148),
    Font = Enum.Font.GothamBold,
    FontColor = Color3.fromRGB(255, 248, 240),
    FontAutoContrast = true,
    FontBgColor = Color3.fromRGB(16, 12, 24),
    FontBgTransparency = 0.56,

    Folder = nil,
    Entries = {},
    RandomColorMap = {},
}

local Combat = {
    AimbotEnabled = false,
    AimbotMode = "Auto", -- "Auto" (Saat Pegang Senjata/Klik) | "Always" (Selalu Kunci) | "HoldRMB" (Tahan Klik Kanan)
    AimPart = "Head", -- "Head" | "HumanoidRootPart" | "Closest"
    TeamCheck = true,
    FOVRadius = 220,
    ShowFOVCircle = false,
    Smoothness = 0.32,
    MaxRange = 800,
    RGBLaserEnabled = true,
    CurrentTarget = nil,
    LaserPart = nil,
    FOVCircle = nil,

    -- Kebal Pukulan Musuh
    MeleeImmunity = false,
    TouchedPartsCache = {},
}

local Carry = {
    Enabled = false,
    TargetPlayer = nil,
    Style = "Depan", -- "Depan" | "Belakang" | "Pundak" | "Seret" | "Kepala" | "Melayang"
}

local Emotes = {
    Playing = false,
    CurrentDance = nil,
    Speed = 1.0,
    Time = 0,
    OriginalC0 = {},
}

local Protection = {
    AntiAFKEnabled = true,
    SafeExecutionGuard = true,
    IdleEventsHandled = 0,
}

local Connections = {}
local UI = {
    Tabs = {},
    Pages = {},
    TelemetryLabels = {},
    FullbrightToggle = nil,
    NoFogToggle = nil,
    Pumpkins = {},
}

local Utils = {}
local Components = {}

-- ============================================================================
-- 2. UTILITY FUNCTIONS & THEME ENGINE
-- ============================================================================
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
        Color = color or Theme.BorderSubtle,
        Thickness = thickness or 1,
        Transparency = transparency or 0.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

function Utils.GetLuminance(c)
    return (0.299 * c.R) + (0.587 * c.G) + (0.114 * c.B)
end

function Utils.GetContrastTextColor(bgColor)
    if Utils.GetLuminance(bgColor) > 0.56 then
        return Color3.fromRGB(18, 14, 24)
    end
    return Color3.fromRGB(255, 248, 240)
end

function Utils.RegisterAccent(obj, property)
    table.insert(State.AccentObjects, { Object = obj, Property = property })
    obj[property] = Theme.Accent
end

function Utils.RegisterText(label, isBold, defaultColor)
    table.insert(State.ThemedTexts, {
        Label = label,
        IsBold = isBold == true,
        DefaultColor = defaultColor or Theme.TextPrimary,
    })
    label.Font = isBold and Theme.FontBold or Theme.FontFamily
    if Theme.FontColorMode ~= "Auto" then
        label.TextColor3 = Theme.FontColorMode
    elseif Theme.FontBgEnabled then
        label.TextColor3 = Utils.GetContrastTextColor(Theme.FontBgColor)
    else
        label.TextColor3 = defaultColor or Theme.TextPrimary
    end

    if Theme.FontBgEnabled then
        label.BackgroundColor3 = Theme.FontBgColor
        label.BackgroundTransparency = Theme.FontBgTransparency
    end
end

function Utils.ApplyMenuFontAndColors()
    for i = #State.ThemedTexts, 1, -1 do
        local item = State.ThemedTexts[i]
        local lbl = item.Label
        if lbl and lbl.Parent then
            lbl.Font = item.IsBold and Theme.FontBold or Theme.FontFamily

            if Theme.FontBgEnabled then
                lbl.BackgroundColor3 = Theme.FontBgColor
                lbl.BackgroundTransparency = Theme.FontBgTransparency
                if not lbl:FindFirstChildOfClass("UICorner") then
                    Utils.AddCorner(lbl, 4)
                end
            else
                lbl.BackgroundTransparency = 1
            end

            if Theme.FontColorMode ~= "Auto" then
                lbl.TextColor3 = Theme.FontColorMode
            elseif Theme.FontBgEnabled then
                lbl.TextColor3 = Utils.GetContrastTextColor(Theme.FontBgColor)
            else
                lbl.TextColor3 = item.DefaultColor
            end
        else
            table.remove(State.ThemedTexts, i)
        end
    end
end

function Utils.SetAccentColor(newColor, newDark)
    Theme.Accent = newColor
    Theme.AccentDark = newDark or newColor
    Theme.Border = newColor

    for i = #State.AccentObjects, 1, -1 do
        local item = State.AccentObjects[i]
        if item.Object and item.Object.Parent then
            item.Object[item.Property] = newColor
        else
            table.remove(State.AccentObjects, i)
        end
    end

    for track, isActive in pairs(State.ActiveToggleTracks) do
        if track and track.Parent and isActive then
            track.BackgroundColor3 = newColor
        else
            State.ActiveToggleTracks[track] = nil
        end
    end
end

function Utils.GetCharacter(plr)
    local target = plr or LocalPlayer
    local char = target and target.Character
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

-- ============================================================================
-- 3. 3D LIFELIKE HALLOWEEN PUMPKIN LOGO BUILDER (Pure Procedural 3D UI)
-- ============================================================================
function Utils.CreatePumpkin3D(parent, pixelSize, position, anchorPoint, zIndex, isHero)
    local z = zIndex or 20
    local holder = Utils.Create("Frame", {
        Name = "Pumpkin3D",
        Size = UDim2.new(0, pixelSize, 0, pixelSize),
        Position = position or UDim2.new(0, 0, 0, 0),
        AnchorPoint = anchorPoint or Vector2.new(0, 0),
        BackgroundTransparency = 1,
        ZIndex = z,
    }, parent)

    -- Aura cahaya lembut di belakang labu
    local aura = Utils.Create("Frame", {
        Size = UDim2.new(1.16, 0, 1.16, 0),
        Position = UDim2.new(0.5, 0, 0.52, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 115, 20),
        BackgroundTransparency = isHero and 0.68 or 0.78,
        BorderSizePixel = 0,
        ZIndex = z,
    }, holder)
    Utils.AddCorner(aura, math.floor(pixelSize * 0.6))

    -- Tangkai Labu 3D (Stem)
    local stem = Utils.Create("Frame", {
        Size = UDim2.new(0.18, 0, 0.24, 0),
        Position = UDim2.new(0.52, 0, 0.04, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        Rotation = 12,
        BackgroundColor3 = Color3.fromRGB(62, 112, 44),
        BorderSizePixel = 0,
        ZIndex = z + 1,
    }, holder)
    Utils.AddCorner(stem, 4)
    Utils.Create("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 175, 72)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 68, 26)),
        }),
    }, stem)

    -- Helper membuat ruas (rib) labu berlapis 3D
    local function makeRib(wScale, hScale, xScale, rot, cTop, cBot, ribZ)
        local rib = Utils.Create("Frame", {
            Size = UDim2.new(wScale, 0, hScale, 0),
            Position = UDim2.new(xScale, 0, 0.56, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Rotation = rot,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = ribZ,
        }, holder)
        Utils.AddCorner(rib, math.floor(pixelSize * 0.45))
        Utils.Create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, cTop),
                ColorSequenceKeypoint.new(0.55, cTop:Lerp(cBot, 0.35)),
                ColorSequenceKeypoint.new(1, cBot),
            }),
        }, rib)
        if isHero then
            Utils.AddStroke(rib, Color3.fromRGB(70, 24, 4), 1, 0.45)
        end
        return rib
    end

    -- 5 Ruas Labu Bertumpuk (Memberikan efek kedalaman 3D bulat)
    makeRib(0.36, 0.66, 0.21, -10, Color3.fromRGB(196, 74, 12), Color3.fromRGB(102, 32, 4), z + 1)
    makeRib(0.36, 0.66, 0.79, 10, Color3.fromRGB(196, 74, 12), Color3.fromRGB(102, 32, 4), z + 1)
    makeRib(0.40, 0.73, 0.33, -5, Color3.fromRGB(238, 102, 18), Color3.fromRGB(132, 44, 6), z + 2)
    makeRib(0.40, 0.73, 0.67, 5, Color3.fromRGB(238, 102, 18), Color3.fromRGB(132, 44, 6), z + 2)
    makeRib(0.44, 0.78, 0.50, 0, Color3.fromRGB(255, 162, 48), Color3.fromRGB(178, 62, 10), z + 3)

    -- Kilau cahaya 3D di bagian atas labu
    local shine = Utils.Create("Frame", {
        Size = UDim2.new(0.16, 0, 0.12, 0),
        Position = UDim2.new(0.44, 0, 0.27, 0),
        Rotation = -18,
        BackgroundColor3 = Color3.fromRGB(255, 232, 180),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = z + 4,
    }, holder)
    Utils.AddCorner(shine, 8)

    -- Mata Jack-o'-Lantern Menyala (Kiri & Kanan)
    local eyeLeft = Utils.Create("Frame", {
        Size = UDim2.new(0.15, 0, 0.13, 0),
        Position = UDim2.new(0.36, 0, 0.47, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = -14,
        BackgroundColor3 = Color3.fromRGB(255, 224, 92),
        BorderSizePixel = 0,
        ZIndex = z + 5,
    }, holder)
    Utils.AddCorner(eyeLeft, 3)

    local eyeRight = Utils.Create("Frame", {
        Size = UDim2.new(0.15, 0, 0.13, 0),
        Position = UDim2.new(0.64, 0, 0.47, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 14,
        BackgroundColor3 = Color3.fromRGB(255, 224, 92),
        BorderSizePixel = 0,
        ZIndex = z + 5,
    }, holder)
    Utils.AddCorner(eyeRight, 3)

    -- Senyum Jack-o'-Lantern Menyala
    local mouth = Utils.Create("Frame", {
        Size = UDim2.new(0.42, 0, 0.12, 0),
        Position = UDim2.new(0.50, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 200, 64),
        BorderSizePixel = 0,
        ZIndex = z + 5,
    }, holder)
    Utils.AddCorner(mouth, 5)

    if pixelSize >= 32 then
        local tooth = Utils.Create("Frame", {
            Size = UDim2.new(0.22, 0, 0.45, 0),
            Position = UDim2.new(0.35, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(168, 56, 8),
            BorderSizePixel = 0,
            ZIndex = z + 6,
        }, mouth)
        Utils.AddCorner(tooth, 2)
    end

    table.insert(UI.Pumpkins, {
        Holder = holder,
        Aura = aura,
        EyeLeft = eyeLeft,
        EyeRight = eyeRight,
        Mouth = mouth,
        BasePos = position or UDim2.new(0, 0, 0, 0),
        IsHero = isHero == true,
    })

    return holder
end

-- ============================================================================
-- 4. PHYSICS CLEANUP HELPERS
-- ============================================================================
function Physics.CleanupFly()
    if Physics.FlyBV then
        Physics.FlyBV:Destroy()
        Physics.FlyBV = nil
    end
    if Physics.FlyBG then
        Physics.FlyBG:Destroy()
        Physics.FlyBG = nil
    end
    local _, hum, root = Utils.GetCharacter()
    if root then
        local b1 = root:FindFirstChild("BSS_FlyVelocity")
        if b1 then b1:Destroy() end
        local b2 = root:FindFirstChild("BSS_FlyGyro")
        if b2 then b2:Destroy() end
    end
    if hum then
        hum.PlatformStand = false
    end
end

function Physics.RestoreNoclip()
    for part, origCollide in pairs(Physics.NoclipCache) do
        if part and part.Parent and part:IsA("BasePart") then
            part.CanCollide = origCollide
        end
    end
    table.clear(Physics.NoclipCache)
end

-- ============================================================================
-- 5. ROOT SCREENGUI & NOTIFICATION SYSTEM
-- ============================================================================
local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then return coreGui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

do
    UI.ScreenGui = Utils.Create("ScreenGui", {
        Name = App.GuiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, getGuiParent())

    UI.ToastContainer = Utils.Create("Frame", {
        Name = "ToastContainer",
        Size = UDim2.new(0, 300, 1, -24),
        Position = UDim2.new(1, -316, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = 60,
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
        BackgroundTransparency = 0.14,
        BorderSizePixel = 0,
        ZIndex = 61,
    }, UI.ToastContainer)
    Utils.AddCorner(toast, 9)
    Utils.AddStroke(toast, accent, 1.1, 0.25)

    local bar = Utils.Create("Frame", {
        Size = UDim2.new(0, 4, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 62,
    }, toast)
    Utils.AddCorner(bar, 2)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 18, 0, 7),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 62,
    }, toast)

    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 18, 0, 27),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = message,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 62,
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

-- ============================================================================
-- 6. BUILD MAIN WINDOW (HALLOWEEN LUXURY TRANSPARENT + 4 CORNER PUMPKINS)
-- ============================================================================
do
    -- Floating Toggle: Logo Labu Halloween 3D Hidup (Menggantikan teks BS 2.0)
    UI.FloatingToggle = Utils.Create("TextButton", {
        Name = "FloatingPumpkinToggle",
        Size = UDim2.new(0, 56, 0, 56),
        Position = UDim2.new(0, 18, 0.5, -28),
        BackgroundColor3 = Color3.fromRGB(18, 14, 28),
        BackgroundTransparency = 0.25,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 45,
    }, UI.ScreenGui)
    Utils.AddCorner(UI.FloatingToggle, 28)
    local floatStroke = Utils.AddStroke(UI.FloatingToggle, Theme.Accent, 1.6, 0.15)
    Utils.RegisterAccent(floatStroke, "Color")

    Utils.CreatePumpkin3D(
        UI.FloatingToggle,
        44,
        UDim2.new(0.5, 0, 0.5, 0),
        Vector2.new(0.5, 0.5),
        46,
        true
    )

    -- Main Window Container (Transparan & Elegan)
    UI.MainFrame = Utils.Create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 650, 0, 435),
        Position = UDim2.new(0.5, -325, 0.5, -217),
        BackgroundColor3 = Theme.BgPrimary,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 10,
    }, UI.ScreenGui)
    Utils.AddCorner(UI.MainFrame, 14)
    local mainStroke = Utils.AddStroke(UI.MainFrame, Theme.Accent, 1.5, 0.15)
    Utils.RegisterAccent(mainStroke, "Color")

    -- Gradien Kemewahan Halloween di Latar Belakang Panel
    local bgGradient = Utils.Create("UIGradient", {
        Rotation = 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 20, 48)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 13, 24)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 22, 16)),
        }),
    }, UI.MainFrame)
    bgGradient.Name = "HalloweenLuxuryGradient"

    -- 4 Logo Labu Halloween 3D di Setiap Sudut Panel Menu
    Utils.CreatePumpkin3D(UI.MainFrame, 28, UDim2.new(0, -8, 0, -8), Vector2.new(0, 0), 30, false)
    Utils.CreatePumpkin3D(UI.MainFrame, 28, UDim2.new(1, 8, 0, -8), Vector2.new(1, 0), 30, false)
    Utils.CreatePumpkin3D(UI.MainFrame, 28, UDim2.new(0, -8, 1, 8), Vector2.new(0, 1), 30, false)
    Utils.CreatePumpkin3D(UI.MainFrame, 28, UDim2.new(1, 8, 1, 8), Vector2.new(1, 1), 30, false)

    -- Inner Clipping Frame agar isi halaman terpotong rapi di sudut
    UI.InnerClip = Utils.Create("Frame", {
        Name = "InnerClip",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 11,
    }, UI.MainFrame)
    Utils.AddCorner(UI.InnerClip, 14)

    -- Top Header Bar
    UI.Topbar = Utils.Create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundColor3 = Theme.BgSecondary,
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.InnerClip)

    Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, UI.Topbar)

    -- Emblem Labu 3D di Header Kiri
    Utils.CreatePumpkin3D(UI.Topbar, 32, UDim2.new(0, 32, 0.5, 0), Vector2.new(0.5, 0.5), 14, true)

    -- Judul Utama ("BimSakSin Hub v3.0") & Ucapan di bawahnya
    local titleLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -142, 0, 22),
        Position = UDim2.new(0, 54, 0, 6),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = App.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 16,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, UI.Topbar)
    UI.TitleLabel = titleLbl
    Utils.RegisterText(titleLbl, true, Theme.TextPrimary)

    local subLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -142, 0, 16),
        Position = UDim2.new(0, 54, 0, 29),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = App.Subtitle,
        TextColor3 = Color3.fromRGB(255, 198, 128),
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, UI.Topbar)
    UI.SubLabel = subLbl
    Utils.RegisterText(subLbl, false, Color3.fromRGB(255, 198, 128))

    -- Topbar Controls (Minimize & Close)
    local function createTopBtn(text, offsetX, hoverColor)
        local btn = Utils.Create("TextButton", {
            Size = UDim2.new(0, 28, 0, 28),
            Position = UDim2.new(1, offsetX, 0.5, -14),
            BackgroundColor3 = Theme.BgControl,
            BackgroundTransparency = 0.2,
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = Theme.TextPrimary,
            TextSize = 13,
            AutoButtonColor = false,
            ZIndex = 15,
        }, UI.Topbar)
        Utils.AddCorner(btn, 7)
        btn.MouseEnter:Connect(function()
            Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor })
        end)
        btn.MouseLeave:Connect(function()
            Utils.Tween(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.BgControl })
        end)
        return btn
    end

    UI.MinimizeBtn = createTopBtn("—", -76, Theme.Accent)
    UI.CloseBtn = createTopBtn("✕", -42, Theme.Danger)

    -- Left Sidebar (Transparan)
    UI.Sidebar = Utils.Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 166, 1, -54),
        Position = UDim2.new(0, 0, 0, 54),
        BackgroundColor3 = Theme.BgSecondary,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, UI.InnerClip)

    Utils.Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.BorderSubtle,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, UI.Sidebar)

    UI.SidebarScroll = Utils.Create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -46),
        Position = UDim2.new(0, 6, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 13,
    }, UI.Sidebar)

    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, UI.SidebarScroll)

    -- Sidebar Footer Badge
    local footerBox = Utils.Create("Frame", {
        Size = UDim2.new(1, -14, 0, 28),
        Position = UDim2.new(0, 7, 1, -35),
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, UI.Sidebar)
    Utils.AddCorner(footerBox, 7)

    local dot = Utils.Create("Frame", {
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0.5, -4),
        BackgroundColor3 = Theme.Success,
        BorderSizePixel = 0,
        ZIndex = 14,
    }, footerBox)
    Utils.AddCorner(dot, 4)

    local statusLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = "Halloween UI Ready",
        TextColor3 = Theme.TextSecondary,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, footerBox)
    Utils.RegisterText(statusLbl, false, Theme.TextSecondary)

    -- Content Area
    UI.ContentContainer = Utils.Create("Frame", {
        Name = "ContentContainer",
        Size = UDim2.new(1, -166, 1, -54),
        Position = UDim2.new(0, 166, 0, 54),
        BackgroundTransparency = 1,
        ZIndex = 12,
    }, UI.InnerClip)

    -- Subtle Corner Resize Handle (Bisa dikecilkan & dibesarkan bebas tanpa mengubah tema)
    UI.ResizeHandle = Utils.Create("TextButton", {
        Name = "ResizeHandle",
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(1, -18, 1, -18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "◢",
        TextColor3 = Theme.Accent,
        TextTransparency = 0.35,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 24,
    }, UI.InnerClip)
    Utils.RegisterAccent(UI.ResizeHandle, "TextColor3")
end

-- ============================================================================
-- 7. DRAGGING SUPPORT (Mouse & Touch, Single Tracked InputEnded)
-- ============================================================================
do
    local function makeDraggable(dragHandle, targetFrame)
        local dragging = false
        local activeDragInput = nil
        local dragInput = nil
        local dragStart = nil
        local startPos = nil

        Utils.Track(dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                activeDragInput = input
                dragStart = input.Position
                startPos = targetFrame.Position
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

        Utils.Track(UserInputService.InputEnded:Connect(function(input)
            if dragging and (input == activeDragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                activeDragInput = nil
            end
        end))
    end

    makeDraggable(UI.Topbar, UI.MainFrame)
    makeDraggable(UI.FloatingToggle, UI.FloatingToggle)
end

-- ============================================================================
-- 8. REUSABLE UI COMPONENT BUILDERS
-- ============================================================================
function Components.SwitchTab(tabName)
    App.ActiveTab = tabName
    for name, tabData in pairs(UI.Tabs) do
        local isSelected = (name == tabName)
        Utils.Tween(tabData.Button, TweenInfo.new(0.18), {
            BackgroundColor3 = isSelected and Theme.BgControl or Theme.BgSecondary,
            BackgroundTransparency = isSelected and 0.18 or 1,
        })
        tabData.Indicator.Visible = isSelected
    end
    for name, page in pairs(UI.Pages) do
        page.Visible = (name == tabName)
    end
end

function Components.CreateTab(name, iconText, order)
    local btn = Utils.Create("TextButton", {
        Name = name .. "Tab",
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.BgControl,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 14,
    }, UI.SidebarScroll)
    Utils.AddCorner(btn, 7)

    local indicator = Utils.Create("Frame", {
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 4, 0.5, -9),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 15,
    }, btn)
    Utils.AddCorner(indicator, 2)
    Utils.RegisterAccent(indicator, "BackgroundColor3")

    local label = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 13, 0, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = iconText .. "  " .. name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, btn)
    Utils.RegisterText(label, false, Theme.TextPrimary)

    local page = Utils.Create("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, -14, 1, -14),
        Position = UDim2.new(0, 7, 0, 7),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 13,
    }, UI.ContentContainer)

    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    Utils.Create("UIPadding", {
        PaddingRight = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 10),
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
        Font = Theme.FontBold,
        Text = "🎃 " .. string.upper(title),
        TextColor3 = Theme.Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
        ZIndex = 14,
    }, parent)
    Utils.RegisterAccent(lbl, "TextColor3")
    return lbl
end

function Components.AddToggle(parent, title, subtitle, defaultVal, order, callback)
    local enabled = defaultVal == true

    local card = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 14,
    }, parent)
    Utils.AddCorner(card, 9)
    Utils.AddStroke(card, Theme.BorderSubtle, 1, 0.3)

    local tLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 18),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(tLbl, true, Theme.TextPrimary)

    local sLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 14),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(sLbl, false, Theme.TextSecondary)

    local switchTrack = Utils.Create("TextButton", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = enabled and Theme.Accent or Theme.BgControl,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 15,
    }, card)
    Utils.AddCorner(switchTrack, 11)

    if enabled then
        State.ActiveToggleTracks[switchTrack] = true
    end

    local knob = Utils.Create("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 16,
    }, switchTrack)
    Utils.AddCorner(knob, 8)

    local function setState(newState, fireCallback)
        enabled = newState
        State.ActiveToggleTracks[switchTrack] = enabled and true or nil

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
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 14,
    }, parent)
    Utils.AddCorner(card, 9)
    Utils.AddStroke(card, Theme.BorderSubtle, 1, 0.3)

    local tLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(0.65, 0, 0, 18),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(tLbl, true, Theme.TextPrimary)

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
        Font = Theme.FontBold,
        Text = formatVal(currentVal),
        TextColor3 = Theme.Accent,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 15,
    }, card)
    Utils.RegisterAccent(valueLabel, "TextColor3")

    local track = Utils.Create("TextButton", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 38),
        BackgroundColor3 = Theme.BgControl,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 15,
    }, card)
    Utils.AddCorner(track, 4)

    local initRatio = (currentVal - minVal) / math.max(0.0001, (maxVal - minVal))
    local fill = Utils.Create("Frame", {
        Size = UDim2.new(initRatio, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 16,
    }, track)
    Utils.AddCorner(fill, 4)
    Utils.RegisterAccent(fill, "BackgroundColor3")

    local thumb = Utils.Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(initRatio, -7, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 17,
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
        if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
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
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 14,
    }, parent)
    Utils.AddCorner(card, 9)
    Utils.AddStroke(card, Theme.BorderSubtle, 1, 0.3)

    local tLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 18),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(tLbl, true, Theme.TextPrimary)

    local sLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 14),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(sLbl, false, Theme.TextSecondary)

    local actionBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 88, 0, 28),
        Position = UDim2.new(1, -100, 0.5, -14),
        BackgroundColor3 = Theme.Accent,
        Font = Theme.FontBold,
        Text = btnLabel,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 15,
    }, card)
    Utils.AddCorner(actionBtn, 7)
    Utils.RegisterAccent(actionBtn, "BackgroundColor3")

    actionBtn.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)

    return actionBtn
end

function Components.AddChipSelector(parent, title, options, defaultVal, order, callback)
    local selected = defaultVal

    local card = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 14,
    }, parent)
    Utils.AddCorner(card, 9)
    Utils.AddStroke(card, Theme.BorderSubtle, 1, 0.3)

    Utils.Create("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, card)

    Utils.Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)

    local titleLbl = Utils.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = 15,
    }, card)
    Utils.RegisterText(titleLbl, true, Theme.TextPrimary)

    local grid = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        ZIndex = 15,
    }, card)

    Utils.Create("UIGridLayout", {
        CellSize = UDim2.new(0.315, 0, 0, 26),
        CellPadding = UDim2.new(0.025, 0, 0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local chipButtons = {}

    local function refreshChips()
        for val, btn in pairs(chipButtons) do
            local isAct = (val == selected)
            btn.BackgroundColor3 = isAct and Theme.Accent or Theme.BgControl
            btn.BackgroundTransparency = isAct and 0.05 or 0.2
        end
    end

    for idx, opt in ipairs(options) do
        local labelText = type(opt) == "table" and opt.Label or tostring(opt)
        local optVal = type(opt) == "table" and opt.Value or opt
        local previewFont = type(opt) == "table" and opt.Font or nil
        local swatchColor = type(opt) == "table" and opt.Color or nil

        local chip = Utils.Create("TextButton", {
            BackgroundColor3 = (optVal == selected) and Theme.Accent or Theme.BgControl,
            BackgroundTransparency = (optVal == selected) and 0.05 or 0.2,
            Font = previewFont or Theme.FontBold,
            Text = labelText,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 10,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false,
            LayoutOrder = idx,
            ZIndex = 16,
        }, grid)
        Utils.AddCorner(chip, 6)

        if swatchColor then
            local dot = Utils.Create("Frame", {
                Size = UDim2.new(0, 8, 0, 8),
                Position = UDim2.new(0, 6, 0.5, -4),
                BackgroundColor3 = swatchColor,
                BorderSizePixel = 0,
                ZIndex = 17,
            }, chip)
            Utils.AddCorner(dot, 4)
        end

        chipButtons[optVal] = chip

        chip.MouseButton1Click:Connect(function()
            selected = optVal
            refreshChips()
            if callback then
                callback(optVal)
            end
        end)
    end

    return {
        SetSelected = function(v)
            selected = v
            refreshChips()
        end,
        GetSelected = function() return selected end,
    }
end

-- ============================================================================
-- 9. UNIVERSAL ESP ENGINE (Team/Enemy/Random + Distance + Health + Font Sync)
-- ============================================================================
do
    ESP.Folder = Utils.Create("Folder", {
        Name = "BSS_ESP_Folder",
    }, UI.ScreenGui)

    function ESP.GetRandomPlayerColor(plr)
        if not ESP.RandomColorMap[plr.UserId] then
            local hue = ((plr.UserId * 137.508) % 360) / 360
            ESP.RandomColorMap[plr.UserId] = Color3.fromHSV(hue, 0.85, 1)
        end
        return ESP.RandomColorMap[plr.UserId]
    end

    function ESP.ClassifyRelation(plr)
        local hasTeams = (#Teams:GetTeams() > 0) and (LocalPlayer.Team ~= nil) and (plr.Team ~= nil)
        if hasTeams then
            if plr.Team == LocalPlayer.Team then
                return "Ally"
            else
                return "Enemy"
            end
        end
        return "Random"
    end

    function ESP.RemovePlayer(plr)
        local entry = ESP.Entries[plr]
        if entry then
            if entry.Highlight then entry.Highlight:Destroy() end
            if entry.Billboard then entry.Billboard:Destroy() end
            ESP.Entries[plr] = nil
        end
    end

    function ESP.ClearAll()
        for plr, _ in pairs(ESP.Entries) do
            ESP.RemovePlayer(plr)
        end
        if ESP.Folder then
            ESP.Folder:ClearAllChildren()
        end
    end

    function ESP.EnsurePlayer(plr)
        if plr == LocalPlayer then return nil end
        local entry = ESP.Entries[plr]
        if not entry then
            local hl = Utils.Create("Highlight", {
                Name = "HL_" .. plr.Name,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillTransparency = 0.52,
                OutlineTransparency = 0.08,
                Enabled = false,
            }, ESP.Folder)

            local bb = Utils.Create("BillboardGui", {
                Name = "BB_" .. plr.Name,
                Size = UDim2.new(0, 230, 0, 62),
                StudsOffset = Vector3.new(0, 3.3, 0),
                AlwaysOnTop = true,
                MaxDistance = math.huge,
                ResetOnSpawn = false,
                Enabled = false,
            }, ESP.Folder)

            local bgBox = Utils.Create("Frame", {
                Size = UDim2.new(0, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.XY,
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = ESP.FontBgColor,
                BackgroundTransparency = ESP.FontBgTransparency,
                BorderSizePixel = 0,
            }, bb)
            Utils.AddCorner(bgBox, 6)
            Utils.Create("UIPadding", {
                PaddingTop = UDim.new(0, 3),
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
            }, bgBox)
            Utils.Create("UIListLayout", {
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 1),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, bgBox)

            local nameLbl = Utils.Create("TextLabel", {
                Size = UDim2.new(0, 0, 0, 15),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = ESP.Font,
                Text = plr.DisplayName,
                TextColor3 = ESP.FontColor,
                TextStrokeTransparency = 0.45,
                TextSize = 12,
                LayoutOrder = 1,
            }, bgBox)

            local distLbl = Utils.Create("TextLabel", {
                Size = UDim2.new(0, 0, 0, 13),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = ESP.Font,
                Text = "Jarak: 0 m",
                TextColor3 = ESP.DistanceColor,
                TextStrokeTransparency = 0.45,
                TextSize = 11,
                LayoutOrder = 2,
            }, bgBox)

            local hpLbl = Utils.Create("TextLabel", {
                Size = UDim2.new(0, 0, 0, 13),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = ESP.Font,
                Text = "Darah: 100/100",
                TextColor3 = ESP.HealthColor,
                TextStrokeTransparency = 0.45,
                TextSize = 11,
                LayoutOrder = 3,
            }, bgBox)

            entry = {
                Highlight = hl,
                Billboard = bb,
                BgBox = bgBox,
                NameLbl = nameLbl,
                DistLbl = distLbl,
                HpLbl = hpLbl,
            }
            ESP.Entries[plr] = entry
        end
        return entry
    end

    function ESP.UpdateAll()
        if not ESP.Enabled then
            for _, entry in pairs(ESP.Entries) do
                entry.Highlight.Enabled = false
                entry.Billboard.Enabled = false
            end
            return
        end

        local _, _, myRoot = Utils.GetCharacter(LocalPlayer)
        local camPos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local entry = ESP.EnsurePlayer(plr)
                local char, hum, root = Utils.GetCharacter(plr)
                local head = char and (char:FindFirstChild("Head") or root)

                if char and root and head and entry then
                    local rel = ESP.ClassifyRelation(plr)
                    local shouldShow = true

                    if ESP.Mode == "Enemy" and rel == "Ally" then
                        shouldShow = false
                    elseif ESP.Mode == "Ally" and rel ~= "Ally" then
                        shouldShow = false
                    end

                    local originPos = myRoot and myRoot.Position or camPos
                    local distStuds = (root.Position - originPos).Magnitude
                    if distStuds > ESP.MaxDistance then
                        shouldShow = false
                    end

                    if shouldShow then
                        local mainColor = ESP.HighlightColor
                        local tagText = "[PLAYER]"
                        if ESP.Mode == "Random" or rel == "Random" then
                            mainColor = (ESP.Mode == "Random") and ESP.GetRandomPlayerColor(plr) or ESP.HighlightColor
                            tagText = "[PLAYER]"
                        elseif rel == "Ally" then
                            mainColor = ESP.AllyColor
                            tagText = "[TEMAN]"
                        elseif rel == "Enemy" then
                            mainColor = ESP.EnemyColor
                            tagText = "[MUSUH]"
                        end

                        entry.Highlight.Adornee = char
                        entry.Highlight.FillColor = mainColor
                        entry.Highlight.OutlineColor = mainColor:Lerp(Color3.new(1, 1, 1), 0.35)
                        entry.Highlight.FillTransparency = 0.52
                        entry.Highlight.OutlineTransparency = 0.08
                        entry.Highlight.Enabled = ESP.ShowAvatar

                        entry.Billboard.Adornee = head
                        entry.Billboard.Enabled = true

                        entry.BgBox.BackgroundColor3 = ESP.FontBgColor
                        entry.BgBox.BackgroundTransparency = ESP.FontBgTransparency

                        local resolvedNameColor = ESP.FontColor
                        if ESP.FontAutoContrast then
                            resolvedNameColor = Utils.GetContrastTextColor(ESP.FontBgColor):Lerp(mainColor, 0.35)
                        end

                        entry.NameLbl.Font = ESP.Font
                        entry.NameLbl.TextColor3 = resolvedNameColor
                        entry.NameLbl.Text = string.format("%s %s", tagText, plr.DisplayName)

                        entry.DistLbl.Visible = ESP.ShowDistance
                        entry.DistLbl.Font = ESP.Font
                        entry.DistLbl.TextColor3 = ESP.DistanceColor
                        entry.DistLbl.Text = string.format("Jarak: %.0f m", distStuds)

                        if ESP.ShowHealth and hum and hum.MaxHealth > 0 then
                            entry.HpLbl.Visible = true
                            entry.HpLbl.Font = ESP.Font
                            entry.HpLbl.TextColor3 = ESP.HealthColor
                            entry.HpLbl.Text = string.format("Darah: %.0f / %.0f", math.max(0, hum.Health), hum.MaxHealth)
                        else
                            entry.HpLbl.Visible = false
                        end
                    else
                        entry.Highlight.Enabled = false
                        entry.Billboard.Enabled = false
                    end
                elseif entry then
                    entry.Highlight.Enabled = false
                    entry.Billboard.Enabled = false
                end
            end
        end
    end
end

-- ============================================================================
-- 10. AUTO AIMBOT & CONDITIONAL RGB WEAPON LASER ENGINE
-- ============================================================================
do
    Combat.FOVCircle = Utils.Create("Frame", {
        Name = "BSS_AimFOV",
        Size = UDim2.new(0, Combat.FOVRadius * 2, 0, Combat.FOVRadius * 2),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 5,
    }, UI.ScreenGui)
    Utils.AddCorner(Combat.FOVCircle, 999)
    local fovStroke = Utils.AddStroke(Combat.FOVCircle, Theme.Accent, 1.3, 0.35)
    Utils.RegisterAccent(fovStroke, "Color")

    function Combat.GetEquippedRangedWeapon()
        local char = Utils.GetCharacter(LocalPlayer)
        if not char then return nil, false end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return nil, false end

        local nameLower = string.lower(tool.Name)
        local gunKeywords = {
            "gun", "pistol", "rifle", "sniper", "ak", "m4", "m16", "shotgun",
            "smg", "bow", "blaster", "laser", "revolver", "glock", "deagle",
            "uzi", "carbine", "launcher", "crossbow", "mp5", "scar", "awp",
            "tec", "mac", "cannon", "ray", "plasma", "magnum", "beretta"
        }
        for _, kw in ipairs(gunKeywords) do
            if string.find(nameLower, kw, 1, true) then
                return tool, true
            end
        end

        for _, desc in ipairs(tool:GetDescendants()) do
            local dName = string.lower(desc.Name)
            if dName == "muzzle" or dName == "barrel" or dName == "firepoint" or dName == "gunscript" or dName == "ammo" or dName == "bullet" then
                return tool, true
            end
        end

        return tool, false
    end

    function Combat.HideLaser()
        if Combat.LaserPart then
            Combat.LaserPart.Transparency = 1
        end
    end

    function Combat.UpdateLaser(startPos, endPos)
        if not Combat.LaserPart or not Combat.LaserPart.Parent then
            Combat.LaserPart = Utils.Create("Part", {
                Name = "BSS_RGB_AimLaser",
                Anchored = true,
                CanCollide = false,
                CanTouch = false,
                CanQuery = false,
                CastShadow = false,
                Material = Enum.Material.Neon,
                Transparency = 0.15,
                Size = Vector3.new(0.08, 0.08, 1),
            }, workspace)
        end

        local dist = (endPos - startPos).Magnitude
        if dist < 0.2 then
            Combat.LaserPart.Transparency = 1
            return
        end

        local hue = (os.clock() * 0.65) % 1
        Combat.LaserPart.Color = Color3.fromHSV(hue, 1, 1)
        Combat.LaserPart.Transparency = 0.12
        Combat.LaserPart.Size = Vector3.new(0.08, 0.08, dist)
        Combat.LaserPart.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -dist / 2)
    end

    function Combat.FindBestTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil, nil end

        local viewportCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local bestTarget = nil
        local bestAimPart = nil
        local bestScore = Combat.FOVRadius

        local _, _, myRoot = Utils.GetCharacter(LocalPlayer)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local isAlly = (#Teams:GetTeams() > 0 and LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team)
                if not (Combat.TeamCheck and isAlly) then
                    local char, hum, root = Utils.GetCharacter(plr)
                    if char and hum and hum.Health > 0 and root then
                        if not char:FindFirstChildOfClass("ForceField") then
                            local partToAim = root
                            if Combat.AimPart == "Head" then
                                partToAim = char:FindFirstChild("Head") or root
                            elseif Combat.AimPart == "Closest" then
                                local head = char:FindFirstChild("Head")
                                if head then
                                    local hPos = cam:WorldToViewportPoint(head.Position)
                                    local rPos = cam:WorldToViewportPoint(root.Position)
                                    local dH = (Vector2.new(hPos.X, hPos.Y) - viewportCenter).Magnitude
                                    local dR = (Vector2.new(rPos.X, rPos.Y) - viewportCenter).Magnitude
                                    partToAim = (dH < dR) and head or root
                                end
                            end

                            local worldDist = myRoot and (partToAim.Position - myRoot.Position).Magnitude or 0
                            if worldDist <= Combat.MaxRange then
                                local screenPos, onScreen = cam:WorldToViewportPoint(partToAim.Position)
                                if onScreen and screenPos.Z > 0 then
                                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                                    if screenDist <= bestScore then
                                        bestScore = screenDist
                                        bestTarget = plr
                                        bestAimPart = partToAim
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return bestTarget, bestAimPart
    end
end

-- ============================================================================
-- 11. MULTI-STYLE PLAYER CARRY ENGINE
-- ============================================================================
do
    local carryOffsets = {
        Depan = CFrame.new(0, 0.2, -1.75) * CFrame.Angles(0, math.rad(90), math.rad(15)),
        Belakang = CFrame.new(0, 0.7, 1.35) * CFrame.Angles(math.rad(-10), 0, 0),
        Pundak = CFrame.new(1.15, 1.45, -0.15) * CFrame.Angles(math.rad(85), 0, math.rad(90)),
        Seret = CFrame.new(0, -2.15, 2.8) * CFrame.Angles(math.rad(82), math.rad(180), 0),
        Kepala = CFrame.new(0, 3.1, 0),
        Melayang = CFrame.new(2.2, 1.1, -0.5) * CFrame.Angles(0, math.rad(-25), 0),
    }

    function Carry.Stop()
        Carry.Enabled = false
        if Carry.TargetPlayer then
            local _, tHum = Utils.GetCharacter(Carry.TargetPlayer)
            if tHum then
                tHum.PlatformStand = false
            end
        end
    end

    function Carry.Step()
        if not Carry.Enabled or not Carry.TargetPlayer then return end
        local _, _, myRoot = Utils.GetCharacter(LocalPlayer)
        local tChar, tHum, tRoot = Utils.GetCharacter(Carry.TargetPlayer)

        if not myRoot or not tChar or not tRoot or not tHum or tHum.Health <= 0 then
            return
        end

        local offset = carryOffsets[Carry.Style] or carryOffsets.Depan
        tHum.PlatformStand = true
        tRoot.AssemblyLinearVelocity = Vector3.zero
        tRoot.AssemblyAngularVelocity = Vector3.zero
        tRoot.CFrame = myRoot.CFrame * offset
    end
end

-- ============================================================================
-- 12. UNIVERSAL R6 & R15 DANCE / EMOTE ENGINE (14 Dances)
-- ============================================================================
do
    Emotes.Catalog = {
        { Id = "Hakari", Label = "Hakari Groove" },
        { Id = "Griddy", Label = "The Griddy" },
        { Id = "Floss", Label = "Floss Dance" },
        { Id = "TakeTheL", Label = "Take The L" },
        { Id = "OrangeJustice", Label = "Orange Justice" },
        { Id = "Slickback", Label = "Slickback Slide" },
        { Id = "DefaultDance", Label = "Default Dance" },
        { Id = "Hype", Label = "Hype / Shoot" },
        { Id = "Robot", Label = "Robot Dance" },
        { Id = "Breakdance", Label = "Breakdance Spin" },
        { Id = "Helicopter", Label = "Helicopter Spin" },
        { Id = "Gangnam", Label = "Gangnam Ride" },
        { Id = "Dab", Label = "Dab Bounce" },
        { Id = "Wave", Label = "Friendly Wave" },
    }

    function Emotes.CacheJoints(char)
        if not char then return end
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("Motor6D") and not Emotes.OriginalC0[desc] then
                Emotes.OriginalC0[desc] = desc.C0
            end
        end
    end

    function Emotes.Stop()
        Emotes.Playing = false
        Emotes.CurrentDance = nil
        for motor, origC0 in pairs(Emotes.OriginalC0) do
            if motor and motor.Parent then
                motor.C0 = origC0
            end
        end
        table.clear(Emotes.OriginalC0)
    end

    function Emotes.Play(danceId)
        local char = Utils.GetCharacter(LocalPlayer)
        if not char then
            Utils.Notify("Emote", "Karakter belum siap.", Theme.Warning)
            return
        end
        if Emotes.Playing then
            for motor, origC0 in pairs(Emotes.OriginalC0) do
                if motor and motor.Parent then
                    motor.C0 = origC0
                end
            end
        end
        Emotes.CacheJoints(char)
        Emotes.CurrentDance = danceId
        Emotes.Time = 0
        Emotes.Playing = true
        Utils.Notify("Dance Aktif", "Memainkan: " .. danceId .. " (R6 & R15)", Theme.Success)
    end

    local function applyJointAngle(jointNames, cfOffset)
        for _, jName in ipairs(jointNames) do
            for motor, origC0 in pairs(Emotes.OriginalC0) do
                if motor and motor.Parent and motor.Name == jName then
                    motor.C0 = origC0 * cfOffset
                end
            end
        end
    end

    function Emotes.Step(dt)
        if not Emotes.Playing or not Emotes.CurrentDance then return end
        local char, hum = Utils.GetCharacter(LocalPlayer)
        if not char or not hum or hum.Health <= 0 then
            Emotes.Stop()
            return
        end

        Emotes.CacheJoints(char)
        Emotes.Time = Emotes.Time + (dt * Emotes.Speed * 6.0)
        local t = Emotes.Time
        local id = Emotes.CurrentDance

        for motor, origC0 in pairs(Emotes.OriginalC0) do
            if motor and motor.Parent then
                motor.C0 = origC0
            end
        end

        local rootJoints = { "RootJoint", "Root" }
        local waistJoints = { "Waist" }
        local neckJoints = { "Neck" }
        local lShoulder = { "Left Shoulder", "LeftShoulder" }
        local rShoulder = { "Right Shoulder", "RightShoulder" }
        local lElbow = { "LeftElbow" }
        local rElbow = { "RightElbow" }
        local lHip = { "Left Hip", "LeftHip" }
        local rHip = { "Right Hip", "RightHip" }
        local lKnee = { "LeftKnee" }
        local rKnee = { "RightKnee" }

        if id == "Hakari" then
            local bounce = math.abs(math.sin(t * 1.4)) * 0.25
            local sway = math.sin(t * 0.7) * 0.22
            applyJointAngle(rootJoints, CFrame.new(0, -bounce, 0) * CFrame.Angles(0, sway, sway * 0.4))
            applyJointAngle(waistJoints, CFrame.Angles(0.08, sway * 0.8, 0))
            applyJointAngle(neckJoints, CFrame.Angles(-0.1, -sway * 0.6, math.sin(t * 1.4) * 0.15))
            applyJointAngle(lShoulder, CFrame.Angles(math.sin(t * 1.4) * 0.9 + 0.4, 0, -0.35))
            applyJointAngle(rShoulder, CFrame.Angles(-math.sin(t * 1.4) * 0.9 + 0.4, 0, 0.35))
            applyJointAngle(lElbow, CFrame.Angles(0.6, 0, 0))
            applyJointAngle(rElbow, CFrame.Angles(0.6, 0, 0))
            applyJointAngle(lHip, CFrame.Angles(math.max(0, math.sin(t * 1.4)) * 0.5, 0, -0.1))
            applyJointAngle(rHip, CFrame.Angles(math.max(0, -math.sin(t * 1.4)) * 0.5, 0, 0.1))
        elseif id == "Griddy" then
            local step = math.sin(t * 1.5)
            applyJointAngle(rootJoints, CFrame.new(0, -math.abs(step) * 0.2, 0) * CFrame.Angles(0.12, 0, step * 0.12))
            applyJointAngle(lShoulder, CFrame.Angles(step * 1.1 + 0.5, 0, -0.3))
            applyJointAngle(rShoulder, CFrame.Angles(-step * 1.1 + 0.5, 0, 0.3))
            applyJointAngle(lElbow, CFrame.Angles(0.85, 0, 0))
            applyJointAngle(rElbow, CFrame.Angles(0.85, 0, 0))
            applyJointAngle(lHip, CFrame.Angles(math.max(0, step) * 0.75, 0, 0))
            applyJointAngle(rHip, CFrame.Angles(math.max(0, -step) * 0.75, 0, 0))
            applyJointAngle(lKnee, CFrame.Angles(-math.max(0, step) * 0.7, 0, 0))
            applyJointAngle(rKnee, CFrame.Angles(-math.max(0, -step) * 0.7, 0, 0))
        elseif id == "Floss" then
            local swing = math.sin(t * 2.1)
            applyJointAngle(waistJoints, CFrame.Angles(0, swing * 0.35, -swing * 0.25))
            applyJointAngle(lShoulder, CFrame.Angles(swing * 0.65, 0, -0.35 - math.abs(swing) * 0.3))
            applyJointAngle(rShoulder, CFrame.Angles(-swing * 0.65, 0, 0.35 + math.abs(swing) * 0.3))
            applyJointAngle(lHip, CFrame.Angles(0, 0, swing * 0.25))
            applyJointAngle(rHip, CFrame.Angles(0, 0, swing * 0.25))
        elseif id == "TakeTheL" then
            local hop = math.sin(t * 1.5)
            applyJointAngle(rootJoints, CFrame.new(0, math.abs(hop) * 0.25, 0) * CFrame.Angles(0, 0, hop * 0.14))
            applyJointAngle(rShoulder, CFrame.Angles(2.3, 0.2, -0.3))
            applyJointAngle(rElbow, CFrame.Angles(1.2, 0, 0))
            applyJointAngle(lShoulder, CFrame.Angles(-0.2, 0, -0.5))
            applyJointAngle(lHip, CFrame.Angles(math.max(0, hop) * 0.9, 0, -0.15))
            applyJointAngle(rHip, CFrame.Angles(math.max(0, -hop) * 0.9, 0, 0.15))
        elseif id == "OrangeJustice" then
            local beat = math.sin(t * 1.8)
            applyJointAngle(rootJoints, CFrame.new(0, -math.abs(beat) * 0.22, 0) * CFrame.Angles(0.15, beat * 0.2, 0))
            applyJointAngle(lShoulder, CFrame.Angles(1.3 + beat * 0.8, 0.4, -0.6))
            applyJointAngle(rShoulder, CFrame.Angles(1.3 - beat * 0.8, -0.4, 0.6))
            applyJointAngle(lHip, CFrame.Angles(math.max(0, beat) * 0.85, 0, -0.2))
            applyJointAngle(rHip, CFrame.Angles(math.max(0, -beat) * 0.85, 0, 0.2))
        elseif id == "Slickback" then
            local glide = math.sin(t * 1.6)
            applyJointAngle(rootJoints, CFrame.new(glide * 0.45, math.abs(math.cos(t * 1.6)) * 0.18, 0) * CFrame.Angles(0.1, glide * 0.25, 0))
            applyJointAngle(lShoulder, CFrame.Angles(glide * 0.7, 0, -0.25))
            applyJointAngle(rShoulder, CFrame.Angles(-glide * 0.7, 0, 0.25))
            applyJointAngle(lHip, CFrame.Angles(glide * 0.65, 0, 0))
            applyJointAngle(rHip, CFrame.Angles(-glide * 0.65, 0, 0))
        elseif id == "DefaultDance" then
            local phase = t % (math.pi * 4)
            local bounce = math.abs(math.sin(t * 1.4)) * 0.18
            applyJointAngle(rootJoints, CFrame.new(0, -bounce, 0))
            if phase < math.pi * 2 then
                applyJointAngle(lShoulder, CFrame.Angles(1.1, 0.5, -0.4))
                applyJointAngle(rShoulder, CFrame.Angles(1.1, -0.5, 0.4))
            else
                applyJointAngle(lShoulder, CFrame.Angles(0.4, 0, -1.2))
                applyJointAngle(rShoulder, CFrame.Angles(0.4, 0, 1.2))
            end
            applyJointAngle(lHip, CFrame.Angles(math.max(0, math.sin(t * 1.4)) * 0.45, 0, -0.1))
            applyJointAngle(rHip, CFrame.Angles(math.max(0, -math.sin(t * 1.4)) * 0.45, 0, 0.1))
        elseif id == "Hype" then
            local pump = math.sin(t * 1.7)
            applyJointAngle(rootJoints, CFrame.new(0, math.abs(pump) * 0.22, 0) * CFrame.Angles(0.1, 0, pump * 0.15))
            applyJointAngle(rShoulder, CFrame.Angles(1.6 + pump * 0.7, 0, 0.35))
            applyJointAngle(lShoulder, CFrame.Angles(-0.3, 0, -0.5))
            applyJointAngle(lHip, CFrame.Angles(0.8 + pump * 0.3, 0, -0.15))
        elseif id == "Robot" then
            local snap = math.floor(t * 1.6) % 4
            local a1 = (snap == 0 or snap == 1) and 1.4 or 0.2
            local a2 = (snap == 1 or snap == 2) and 1.4 or 0.2
            applyJointAngle(waistJoints, CFrame.Angles(0, (snap - 1.5) * 0.22, 0))
            applyJointAngle(neckJoints, CFrame.Angles(0, -(snap - 1.5) * 0.35, 0))
            applyJointAngle(lShoulder, CFrame.Angles(a1, 0, -0.4))
            applyJointAngle(rShoulder, CFrame.Angles(a2, 0, 0.4))
            applyJointAngle(lElbow, CFrame.Angles(1.2, 0, 0))
            applyJointAngle(rElbow, CFrame.Angles(1.2, 0, 0))
        elseif id == "Breakdance" then
            applyJointAngle(rootJoints, CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(78), t * 1.4, 0))
            applyJointAngle(lShoulder, CFrame.Angles(0.3, 0, -1.3))
            applyJointAngle(rShoulder, CFrame.Angles(0.3, 0, 1.3))
            applyJointAngle(lHip, CFrame.Angles(0.5, 0, -0.65))
            applyJointAngle(rHip, CFrame.Angles(-0.3, 0, 0.65))
        elseif id == "Helicopter" then
            applyJointAngle(rootJoints, CFrame.new(0, math.abs(math.sin(t)) * 0.35, 0) * CFrame.Angles(0, t * 1.8, 0))
            applyJointAngle(lShoulder, CFrame.Angles(0, 0, -1.55))
            applyJointAngle(rShoulder, CFrame.Angles(0, 0, 1.55))
        elseif id == "Gangnam" then
            local bounce = math.abs(math.sin(t * 1.6)) * 0.22
            applyJointAngle(rootJoints, CFrame.new(0, -bounce, 0))
            applyJointAngle(lShoulder, CFrame.Angles(1.15, 0.45, -0.25))
            applyJointAngle(rShoulder, CFrame.Angles(2.1 + math.sin(t * 2.5) * 0.3, 0, 0.35))
            applyJointAngle(lHip, CFrame.Angles(0.25, 0, -0.35))
            applyJointAngle(rHip, CFrame.Angles(0.25, 0, 0.35))
        elseif id == "Dab" then
            local bounce = math.abs(math.sin(t * 1.2)) * 0.16
            applyJointAngle(rootJoints, CFrame.new(0, -bounce, 0) * CFrame.Angles(0, 0.35, 0))
            applyJointAngle(neckJoints, CFrame.Angles(0.45, -0.35, -0.25))
            applyJointAngle(lShoulder, CFrame.Angles(1.5, 0.75, -0.2))
            applyJointAngle(rShoulder, CFrame.Angles(0.4, 0, 2.3))
        elseif id == "Wave" then
            local wave = math.sin(t * 1.6) * 0.55
            applyJointAngle(rShoulder, CFrame.Angles(0.2, 0, 2.4 + wave))
            applyJointAngle(neckJoints, CFrame.Angles(0, 0, wave * 0.25))
        end
    end
end

-- ============================================================================
-- 13. PROTECTION & STABILITY ENGINE (Anti-AFK & Kebal Pukulan Musuh)
-- ============================================================================
do
    -- Anti-AFK (Mencegah disconnect 20 menit diam)
    Utils.Track(LocalPlayer.Idled:Connect(function()
        if Protection.AntiAFKEnabled then
            Protection.IdleEventsHandled = Protection.IdleEventsHandled + 1
            pcall(function()
                if VirtualUser then
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end
            end)
        end
    end))

    -- Kebal Pukulan Musuh (Anti-Knockback, Anti-Ragdoll, & Melee Hitbox Guard)
    function Protection.RestoreEnemyHitboxes()
        for part, origTouch in pairs(Combat.TouchedPartsCache) do
            if part and part.Parent and part:IsA("BasePart") then
                part.CanTouch = origTouch
            end
        end
        table.clear(Combat.TouchedPartsCache)
    end

    function Protection.StepMeleeImmunity()
        if not Combat.MeleeImmunity then return end
        local char, hum, root = Utils.GetCharacter(LocalPlayer)
        if not char or not hum or not root then return end

        local badStates = {
            [Enum.HumanoidStateType.Ragdoll] = true,
            [Enum.HumanoidStateType.FallingDown] = true,
            [Enum.HumanoidStateType.Physics] = true,
        }
        if badStates[hum:GetState()] then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if not State.FlyEnabled and not Carry.Enabled and hum.PlatformStand then
            hum.PlatformStand = false
        end

        if not State.FlyEnabled then
            local vel = root.AssemblyLinearVelocity
            local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
            if horizSpeed > (State.WalkSpeed + 28) then
                root.AssemblyLinearVelocity = Vector3.new(0, math.min(vel.Y, 20), 0)
            end
            root.AssemblyAngularVelocity = Vector3.zero
        end

        if hum.Health > 0 and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local enemyTool = plr.Character:FindFirstChildOfClass("Tool")
                if enemyTool then
                    for _, desc in ipairs(enemyTool:GetDescendants()) do
                        if desc:IsA("BasePart") then
                            if Combat.TouchedPartsCache[desc] == nil then
                                Combat.TouchedPartsCache[desc] = desc.CanTouch
                            end
                            if desc.CanTouch then
                                desc.CanTouch = false
                            end
                        end
                    end
                end
            end
        end
    end
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
        ZIndex = 14,
    }, page)

    Utils.Create("UIGridLayout", {
        CellSize = UDim2.new(0.485, 0, 0, 58),
        CellPadding = UDim2.new(0.03, 0, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local function createStatCard(labelTitle, initialValue, order)
        local box = Utils.Create("Frame", {
            BackgroundColor3 = Theme.BgCard,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 14,
        }, grid)
        Utils.AddCorner(box, 9)
        Utils.AddStroke(box, Theme.BorderSubtle, 1, 0.3)

        local l1 = Utils.Create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 16),
            Position = UDim2.new(0, 10, 0, 8),
            BackgroundTransparency = 1,
            Font = Theme.FontFamily,
            Text = labelTitle,
            TextColor3 = Theme.TextSecondary,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
        }, box)
        Utils.RegisterText(l1, false, Theme.TextSecondary)

        local valLbl = Utils.Create("TextLabel", {
            Size = UDim2.new(1, -16, 0, 22),
            Position = UDim2.new(0, 10, 0, 26),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = initialValue,
            TextColor3 = Theme.TextPrimary,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
        }, box)
        Utils.RegisterText(valLbl, true, Theme.TextPrimary)

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
            Utils.Notify("Tersalin", infoStr, Theme.Success)
        else
            Utils.Notify("Info Server", infoStr, Theme.Accent)
        end
    end)

    Components.AddButton(page, "Respawn Character", "Segarkan kembali status karakter lokal", "Respawn", 5, function()
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.Health = 0
            Utils.Notify("Karakter", "Melakukan respawn karakter...", Theme.Warning)
        end
    end)

    Components.AddButton(page, "Rejoin Current Server", "Hubungkan ulang ke instance PlaceId yang sama", "Rejoin", 6, function()
        Utils.Notify("TeleportService", "Mencoba masuk kembali ke server...", Theme.Accent)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)
end

-- ============================================================================
-- TAB 2: ESP & VISUAL RADAR (Universal Map-Adaptive + Custom Font/Bg Sync)
-- ============================================================================
do
    local page = Components.CreateTab("ESP Radar", "👁", 2)
    Components.AddSectionHeader(page, "ESP Pemain & Transparansi Avatar", 1)

    Components.AddToggle(page, "Aktifkan Universal ESP", "Tampilkan ESP jarak jauh menembus tembok di semua map", false, 2, function(on)
        ESP.Enabled = on
        if not on then
            ESP.ClearAll()
        end
        Utils.Notify("Universal ESP", on and "ESP aktif di seluruh map." or "ESP dimatikan.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddToggle(page, "Avatar Transparan Tembus Tembok", "Sorot tubuh avatar pemain agar terlihat dari jarak sejauh mana pun", true, 3, function(on)
        ESP.ShowAvatar = on
    end)

    Components.AddToggle(page, "Tampilkan Jarak (Meter)", "Tampilkan jarak real-time ke setiap pemain", true, 4, function(on)
        ESP.ShowDistance = on
    end)

    Components.AddToggle(page, "Tampilkan Darah (Menyesuaikan Map)", "Otomatis menampilkan HP jika map menggunakan sistem darah", true, 5, function(on)
        ESP.ShowHealth = on
    end)

    Components.AddChipSelector(page, "Mode Target ESP (Teman / Musuh / Random)", {
        { Label = "Auto Map", Value = "Auto" },
        { Label = "Musuh Saja", Value = "Enemy" },
        { Label = "Teman Saja", Value = "Ally" },
        { Label = "Random Semua", Value = "Random" },
    }, "Auto", 6, function(val)
        ESP.Mode = val
        Utils.Notify("Mode ESP", "Mode target diatur ke: " .. val, Theme.Accent)
    end)

    Components.AddSlider(page, "Jarak Maksimal ESP (Studs)", 200, 10000, 2500, 0, 7, function(val)
        ESP.MaxDistance = val
    end)

    Components.AddSectionHeader(page, "Kustomisasi Warna & Font ESP", 8)

    Components.AddChipSelector(page, "Pilih Gaya Font ESP", {
        { Label = "Gotham Bold", Value = Enum.Font.GothamBold, Font = Enum.Font.GothamBold },
        { Label = "Fredoka One", Value = Enum.Font.FredokaOne, Font = Enum.Font.FredokaOne },
        { Label = "Creepster", Value = Enum.Font.Creepster, Font = Enum.Font.Creepster },
        { Label = "Roboto Mono", Value = Enum.Font.RobotoMono, Font = Enum.Font.RobotoMono },
        { Label = "Bangers", Value = Enum.Font.Bangers, Font = Enum.Font.Bangers },
        { Label = "Merriweather", Value = Enum.Font.Merriweather, Font = Enum.Font.Merriweather },
    }, Enum.Font.GothamBold, 9, function(val)
        ESP.Font = val
    end)

    Components.AddChipSelector(page, "Warna Utama ESP / Highlight", {
        { Label = "Labu Emas", Value = Color3.fromRGB(255, 118, 26), Color = Color3.fromRGB(255, 118, 26) },
        { Label = "Merah Darah", Value = Color3.fromRGB(235, 69, 95), Color = Color3.fromRGB(235, 69, 95) },
        { Label = "Hijau Neon", Value = Color3.fromRGB(46, 213, 115), Color = Color3.fromRGB(46, 213, 115) },
        { Label = "Cyan Spektral", Value = Color3.fromRGB(24, 220, 255), Color = Color3.fromRGB(24, 220, 255) },
        { Label = "Ungu Mistis", Value = Color3.fromRGB(165, 94, 234), Color = Color3.fromRGB(165, 94, 234) },
        { Label = "Putih Terang", Value = Color3.fromRGB(255, 255, 255), Color = Color3.fromRGB(255, 255, 255) },
    }, Color3.fromRGB(255, 118, 26), 10, function(val)
        ESP.HighlightColor = val
    end)

    Components.AddChipSelector(page, "Warna Teks Jarak", {
        { Label = "Kuning Emas", Value = Color3.fromRGB(255, 210, 120), Color = Color3.fromRGB(255, 210, 120) },
        { Label = "Cyan Es", Value = Color3.fromRGB(112, 235, 255), Color = Color3.fromRGB(112, 235, 255) },
        { Label = "Putih Bersih", Value = Color3.fromRGB(250, 250, 255), Color = Color3.fromRGB(250, 250, 255) },
        { Label = "Oranye Labu", Value = Color3.fromRGB(255, 145, 65), Color = Color3.fromRGB(255, 145, 65) },
        { Label = "Pink Neon", Value = Color3.fromRGB(255, 118, 195), Color = Color3.fromRGB(255, 118, 195) },
        { Label = "Hijau Mint", Value = Color3.fromRGB(130, 255, 185), Color = Color3.fromRGB(130, 255, 185) },
    }, Color3.fromRGB(255, 210, 120), 11, function(val)
        ESP.DistanceColor = val
    end)

    Components.AddChipSelector(page, "Warna Teks Darah (HP)", {
        { Label = "Hijau HP", Value = Color3.fromRGB(85, 239, 148), Color = Color3.fromRGB(85, 239, 148) },
        { Label = "Merah Crimson", Value = Color3.fromRGB(255, 88, 108), Color = Color3.fromRGB(255, 88, 108) },
        { Label = "Kuning Amber", Value = Color3.fromRGB(255, 214, 70), Color = Color3.fromRGB(255, 214, 70) },
        { Label = "Putih Salju", Value = Color3.fromRGB(245, 248, 255), Color = Color3.fromRGB(245, 248, 255) },
        { Label = "Biru Elektrik", Value = Color3.fromRGB(95, 185, 255), Color = Color3.fromRGB(95, 185, 255) },
        { Label = "Ungu Violet", Value = Color3.fromRGB(195, 135, 255), Color = Color3.fromRGB(195, 135, 255) },
    }, Color3.fromRGB(85, 239, 148), 12, function(val)
        ESP.HealthColor = val
    end)

    Components.AddChipSelector(page, "Warna Latar Belakang Font (Tipis & Menyesuaikan)", {
        { Label = "Hitam Tipis", Value = Color3.fromRGB(16, 12, 24), Color = Color3.fromRGB(16, 12, 24) },
        { Label = "Ungu Malam", Value = Color3.fromRGB(36, 20, 56), Color = Color3.fromRGB(36, 20, 56) },
        { Label = "Coklat Labu", Value = Color3.fromRGB(48, 24, 12), Color = Color3.fromRGB(48, 24, 12) },
        { Label = "Merah Gelap", Value = Color3.fromRGB(48, 14, 22), Color = Color3.fromRGB(48, 14, 22) },
        { Label = "Putih Kabut", Value = Color3.fromRGB(235, 230, 242), Color = Color3.fromRGB(235, 230, 242) },
        { Label = "Bening Halus", Value = Color3.fromRGB(10, 10, 14), Color = Color3.fromRGB(10, 10, 14) },
    }, Color3.fromRGB(16, 12, 24), 13, function(val)
        ESP.FontBgColor = val
        ESP.FontBgTransparency = (val == Color3.fromRGB(10, 10, 14)) and 0.78 or 0.56
    end)

    Components.AddChipSelector(page, "Warna Font Nama ESP (Auto / Custom)", {
        { Label = "Auto Kontras", Value = "Auto", Color = Color3.fromRGB(255, 195, 110) },
        { Label = "Putih Tulang", Value = Color3.fromRGB(255, 248, 240), Color = Color3.fromRGB(255, 248, 240) },
        { Label = "Emas Labu", Value = Color3.fromRGB(255, 155, 55), Color = Color3.fromRGB(255, 155, 55) },
        { Label = "Merah Terang", Value = Color3.fromRGB(255, 95, 115), Color = Color3.fromRGB(255, 95, 115) },
        { Label = "Hijau Spektral", Value = Color3.fromRGB(95, 245, 155), Color = Color3.fromRGB(95, 245, 155) },
        { Label = "Hitam Pekat", Value = Color3.fromRGB(20, 16, 28), Color = Color3.fromRGB(20, 16, 28) },
    }, "Auto", 14, function(val)
        if val == "Auto" then
            ESP.FontAutoContrast = true
        else
            ESP.FontAutoContrast = false
            ESP.FontColor = val
        end
    end)
end

-- ============================================================================
-- TAB 3: AIMBOT & COMBAT (Aimbot + RGB Gun Laser + Kebal Pukulan)
-- ============================================================================
do
    local page = Components.CreateTab("Combat", "🎯", 3)
    Components.AddSectionHeader(page, "Auto Aimbot Presisi Tinggi", 1)

    Components.AddToggle(page, "Auto Aimbot Tepat Sasaran", "Bidik sasaran akurat otomatis (pukulan & senjata)", false, 2, function(on)
        Combat.AimbotEnabled = on
        if not on then
            Combat.CurrentTarget = nil
            Combat.HideLaser()
        end
        Utils.Notify("Auto Aimbot", on and "Aimbot presisi aktif." or "Aimbot dimatikan.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddToggle(page, "Laser RGB Khusus Senjata Api", "Tampilkan laser RGB hanya saat memegang pistol/senjata (tanpa laser saat memukul)", true, 3, function(on)
        Combat.RGBLaserEnabled = on
        if not on then
            Combat.HideLaser()
        end
    end)

    Components.AddChipSelector(page, "Mode Pemicu Aimbot", {
        { Label = "Auto (Tool/Klik)", Value = "Auto" },
        { Label = "Selalu Kunci", Value = "Always" },
        { Label = "Tahan Klik Kanan", Value = "HoldRMB" },
    }, "Auto", 4, function(val)
        Combat.AimbotMode = val
    end)

    Components.AddChipSelector(page, "Bagian Tubuh Sasaran", {
        { Label = "Kepala (Head)", Value = "Head" },
        { Label = "Badan (Torso)", Value = "HumanoidRootPart" },
        { Label = "Terdekat FOV", Value = "Closest" },
    }, "Head", 5, function(val)
        Combat.AimPart = val
    end)

    Components.AddToggle(page, "Abaikan Teman Satu Tim (Team Check)", "Jangan bidik teman satu tim pada map berbasis tim", true, 6, function(on)
        Combat.TeamCheck = on
    end)

    Components.AddToggle(page, "Tampilkan Lingkaran FOV Bidikan", "Visualisasi area jangkauan deteksi aimbot di layar", false, 7, function(on)
        Combat.ShowFOVCircle = on
        if Combat.FOVCircle then
            Combat.FOVCircle.Visible = on
        end
    end)

    Components.AddSlider(page, "Radius FOV Bidikan", 60, 600, 220, 0, 8, function(val)
        Combat.FOVRadius = val
        if Combat.FOVCircle then
            Combat.FOVCircle.Size = UDim2.new(0, val * 2, 0, val * 2)
        end
    end)

    Components.AddSlider(page, "Tingkat Akurasi / Kunci (1 = Instan)", 0.1, 1.0, 0.35, 2, 9, function(val)
        Combat.Smoothness = val
    end)

    Components.AddSectionHeader(page, "Pertahanan & Kekebalan Pertarungan", 10)

    Components.AddToggle(page, "Kebal Terhadap Pukulan Musuh / Lawan", "Anti-knockback, anti-ragdoll, dan tahan hitbox pukulan melee lawan", false, 11, function(on)
        Combat.MeleeImmunity = on
        if not on then
            Protection.RestoreEnemyHitboxes()
        end
        Utils.Notify("Kebal Pukulan", on and "Mode kebal pukulan & anti-mental aktif!" or "Mode kebal dimatikan.", on and Theme.Success or Theme.TextSecondary)
    end)
end

-- ============================================================================
-- TAB 4: CARRY SYSTEM (Gendong Teman / Team Multi-Gaya)
-- ============================================================================
do
    local page = Components.CreateTab("Carry", "🫂", 4)
    Components.AddSectionHeader(page, "Pengaturan Gaya & Status Carry", 1)

    local carryToggle = Components.AddToggle(page, "Aktifkan Carry Target Terpilih", "Gendong atau bawa teman/player sesuai gaya yang dipilih", false, 2, function(on)
        if on and not Carry.TargetPlayer then
            Utils.Notify("Pilih Pemain", "Pilih teman/player di daftar bawah terlebih dahulu!", Theme.Warning)
            Carry.Enabled = false
            return
        end
        Carry.Enabled = on
        if not on then
            Carry.Stop()
            Utils.Notify("Carry", "Melepaskan target carry.", Theme.TextSecondary)
        else
            Utils.Notify("Carry Aktif", "Meng-carry " .. Carry.TargetPlayer.DisplayName .. " (" .. Carry.Style .. ")", Theme.Success)
        end
    end)

    Components.AddChipSelector(page, "Pilih Gaya Carry Lengkap", {
        { Label = "Carry Depan", Value = "Depan" },
        { Label = "Carry Belakang", Value = "Belakang" },
        { Label = "Carry di Pundak", Value = "Pundak" },
        { Label = "Carry di Seret", Value = "Seret" },
        { Label = "Carry di Kepala", Value = "Kepala" },
        { Label = "Carry Melayang", Value = "Melayang" },
    }, "Depan", 3, function(val)
        Carry.Style = val
        Utils.Notify("Gaya Carry", "Gaya diubah ke: Carry " .. val, Theme.Accent)
    end)

    Components.AddSectionHeader(page, "Pilih Teman / Player untuk Di-Carry", 4)

    local carryListHolder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 5,
        ZIndex = 14,
    }, page)
    Utils.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, carryListHolder)

    local function refreshCarryPlayers()
        for _, child in ipairs(carryListHolder:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local isSelected = (Carry.TargetPlayer == plr)
                local row = Utils.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Theme.BgCard,
                    BackgroundTransparency = 0.25,
                    BorderSizePixel = 0,
                    LayoutOrder = count,
                    ZIndex = 14,
                }, carryListHolder)
                Utils.AddCorner(row, 8)
                Utils.AddStroke(row, isSelected and Theme.Accent or Theme.BorderSubtle, 1, 0.25)

                local nameLbl = Utils.Create("TextLabel", {
                    Size = UDim2.new(1, -110, 1, 0),
                    Position = UDim2.new(0, 12, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Theme.FontFamily,
                    Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 15,
                }, row)
                Utils.RegisterText(nameLbl, false, Theme.TextPrimary)

                local pickBtn = Utils.Create("TextButton", {
                    Size = UDim2.new(0, 86, 0, 26),
                    Position = UDim2.new(1, -96, 0.5, -13),
                    BackgroundColor3 = isSelected and Theme.Success or Theme.Accent,
                    Font = Theme.FontBold,
                    Text = isSelected and "Terpilih ✓" or "Pilih Carry",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 15,
                }, row)
                Utils.AddCorner(pickBtn, 6)

                pickBtn.MouseButton1Click:Connect(function()
                    if Carry.TargetPlayer and Carry.TargetPlayer ~= plr then
                        local _, oldHum = Utils.GetCharacter(Carry.TargetPlayer)
                        if oldHum then oldHum.PlatformStand = false end
                    end
                    Carry.TargetPlayer = plr
                    Carry.Enabled = true
                    carryToggle.SetState(true, false)
                    refreshCarryPlayers()
                    Utils.Notify("Carry Target", "Meng-carry " .. plr.DisplayName .. " (" .. Carry.Style .. ")", Theme.Success)
                end)
            end
        end

        if count == 0 then
            local empty = Utils.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.BgCard,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                ZIndex = 14,
            }, carryListHolder)
            Utils.AddCorner(empty, 8)
            Utils.Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Theme.FontFamily,
                Text = "Belum ada pemain lain di server untuk di-carry.",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                ZIndex = 15,
            }, empty)
        end
    end

    refreshCarryPlayers()
    Utils.Track(Players.PlayerAdded:Connect(refreshCarryPlayers))
    Utils.Track(Players.PlayerRemoving:Connect(function(plr)
        if Carry.TargetPlayer == plr then
            Carry.TargetPlayer = nil
            Carry.Enabled = false
            carryToggle.SetState(false, false)
        end
        task.defer(refreshCarryPlayers)
    end))
end

-- ============================================================================
-- TAB 5: DANCE & EMOTE STUDIO (R6 & R15 Universal)
-- ============================================================================
do
    local page = Components.CreateTab("Dances", "💃", 5)
    Components.AddSectionHeader(page, "Kontrol Dance / Emote (R6 & R15)", 1)

    Components.AddSlider(page, "Kecepatan Gerakan Dance", 0.5, 2.5, 1.0, 1, 2, function(val)
        Emotes.Speed = val
    end)

    Components.AddButton(page, "Hentikan Dance / Reset Pose", "Kembalikan sendi tubuh R6/R15 ke posisi normal", "Stop Dance", 3, function()
        Emotes.Stop()
        Utils.Notify("Emote", "Dance dihentikan & pose dipulihkan.", Theme.TextSecondary)
    end)

    Components.AddSectionHeader(page, "Daftar Lengkap Pilihan Dance", 4)

    local danceGrid = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 5,
        ZIndex = 14,
    }, page)

    Utils.Create("UIGridLayout", {
        CellSize = UDim2.new(0.485, 0, 0, 34),
        CellPadding = UDim2.new(0.03, 0, 0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, danceGrid)

    for idx, d in ipairs(Emotes.Catalog) do
        local btn = Utils.Create("TextButton", {
            BackgroundColor3 = Theme.BgCard,
            BackgroundTransparency = 0.22,
            Font = Theme.FontBold,
            Text = "🎵 " .. d.Label,
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            AutoButtonColor = false,
            LayoutOrder = idx,
            ZIndex = 15,
        }, danceGrid)
        Utils.AddCorner(btn, 8)
        local stroke = Utils.AddStroke(btn, Theme.Accent, 1, 0.45)
        Utils.RegisterAccent(stroke, "Color")
        Utils.RegisterText(btn, true, Theme.TextPrimary)

        btn.MouseButton1Click:Connect(function()
            Emotes.Play(d.Id)
        end)
    end
end

-- ============================================================================
-- TAB 6: MOVEMENT & PHYSICS (QA)
-- ============================================================================
do
    local page = Components.CreateTab("Movement", "⚡", 6)
    Components.AddSectionHeader(page, "Character Locomotion Tuning", 1)

    local wsSlider = Components.AddSlider(page, "WalkSpeed", 16, 250, 16, 0, 2, function(val)
        State.WalkSpeed = val
        local _, hum = Utils.GetCharacter()
        if hum then hum.WalkSpeed = val end
    end)

    local jpSlider = Components.AddSlider(page, "JumpPower", 50, 300, 50, 0, 3, function(val)
        State.JumpPower = val
        local _, hum = Utils.GetCharacter()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end)

    local maxGrav = math.max(300, math.ceil(State.OriginalGravity))
    local gravSlider = Components.AddSlider(page, "Workspace Gravity", 0, maxGrav, State.OriginalGravity, 1, 4, function(val)
        State.Gravity = val
        workspace.Gravity = val
    end)

    local origGravStr = string.format("%.1f", State.OriginalGravity)
    Components.AddButton(page, "Reset Physics Defaults", "Kembalikan WalkSpeed (16), JumpPower (50), Gravity (" .. origGravStr .. ")", "Reset All", 5, function()
        wsSlider.SetValue(16, true)
        jpSlider.SetValue(50, true)
        gravSlider.SetValue(State.OriginalGravity, true)
        Utils.Notify("Fisika Direset", "Nilai pergerakan dikembalikan ke bawaan.", Theme.Success)
    end)

    Components.AddSectionHeader(page, "Inspection & Navigation Modes", 6)

    Components.AddToggle(page, "Free-Flight Inspector (Fly)", "Terbang bebas mengikuti arah kamera (PC & Mobile)", false, 7, function(on)
        State.FlyEnabled = on
        if not on then Physics.CleanupFly() end
        Utils.Notify("Free-Flight", on and "Mode terbang aktif." or "Mode terbang dimatikan.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddSlider(page, "Flight Speed", 20, 250, 60, 0, 8, function(val)
        State.FlySpeed = val
    end)

    Components.AddToggle(page, "Noclip Geometry Inspector", "Tembus objek tanpa merusak kolisi bawaan R6/R15", false, 9, function(on)
        State.NoclipEnabled = on
        if not on then Physics.RestoreNoclip() end
        Utils.Notify("Noclip", on and "Kolisi dinonaktifkan." or "Kolisi dipulihkan.", on and Theme.Warning or Theme.TextSecondary)
    end)

    Components.AddToggle(page, "Infinite Jump", "Lompat tanpa batas di udara", false, 10, function(on)
        State.InfiniteJumpEnabled = on
    end)
end

-- ============================================================================
-- TAB 7: WORLD & WAYPOINTS
-- ============================================================================
do
    local page = Components.CreateTab("World", "⌖", 7)
    Components.AddSectionHeader(page, "Coordinates & Waypoint Manager", 1)

    local posCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 14,
    }, page)
    Utils.AddCorner(posCard, 9)
    Utils.AddStroke(posCard, Theme.BorderSubtle, 1, 0.3)

    UI.TelemetryLabels.Coords = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -112, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = "XYZ: 0.0, 0.0, 0.0",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, posCard)

    local copyPosBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 92, 0, 28),
        Position = UDim2.new(1, -104, 0.5, -14),
        BackgroundColor3 = Theme.BgControl,
        Font = Theme.FontBold,
        Text = "Copy CFrame",
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        AutoButtonColor = false,
        ZIndex = 15,
    }, posCard)
    Utils.AddCorner(copyPosBtn, 6)

    copyPosBtn.MouseButton1Click:Connect(function()
        local _, _, root = Utils.GetCharacter()
        if root then
            local p = root.Position
            local cfStr = string.format("CFrame.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
            if Utils.CopyText(cfStr) then
                Utils.Notify("CFrame Tersalin", cfStr, Theme.Success)
            else
                Utils.Notify("CFrame Saat Ini", cfStr, Theme.Accent)
            end
        end
    end)

    local wpInputCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        LayoutOrder = 3,
        ZIndex = 14,
    }, page)
    Utils.AddCorner(wpInputCard, 9)
    Utils.AddStroke(wpInputCard, Theme.BorderSubtle, 1, 0.3)

    local wpBox = Utils.Create("TextBox", {
        Size = UDim2.new(1, -124, 0, 30),
        Position = UDim2.new(0, 10, 0.5, -15),
        BackgroundColor3 = Theme.BgControl,
        Font = Theme.FontFamily,
        PlaceholderText = "Nama waypoint (mis. Spawn, Atap)...",
        PlaceholderColor3 = Theme.TextMuted,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        ClearTextOnFocus = false,
        ZIndex = 15,
    }, wpInputCard)
    Utils.AddCorner(wpBox, 6)
    Utils.Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, wpBox)

    local saveWpBtn = Utils.Create("TextButton", {
        Size = UDim2.new(0, 96, 0, 30),
        Position = UDim2.new(1, -106, 0.5, -15),
        BackgroundColor3 = Theme.Accent,
        Font = Theme.FontBold,
        Text = "+ Save Point",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        AutoButtonColor = false,
        ZIndex = 15,
    }, wpInputCard)
    Utils.AddCorner(saveWpBtn, 6)
    Utils.RegisterAccent(saveWpBtn, "BackgroundColor3")

    local wpListHolder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        ZIndex = 14,
    }, page)
    Utils.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, wpListHolder)

    local function renderWaypoints()
        for _, child in ipairs(wpListHolder:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        for idx, wp in ipairs(State.Waypoints) do
            local row = Utils.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Theme.BgSecondary,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                LayoutOrder = idx,
                ZIndex = 15,
            }, wpListHolder)
            Utils.AddCorner(row, 7)
            Utils.AddStroke(row, Theme.BorderSubtle, 1, 0.3)

            Utils.Create("TextLabel", {
                Size = UDim2.new(1, -138, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Font = Theme.FontFamily,
                Text = string.format("%s (%.0f, %.0f, %.0f)", wp.Name, wp.CFrame.X, wp.CFrame.Y, wp.CFrame.Z),
                TextColor3 = Theme.TextPrimary,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 16,
            }, row)

            local tpBtn = Utils.Create("TextButton", {
                Size = UDim2.new(0, 68, 0, 24),
                Position = UDim2.new(1, -112, 0.5, -12),
                BackgroundColor3 = Theme.Accent,
                Font = Theme.FontBold,
                Text = "Teleport",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 16,
            }, row)
            Utils.AddCorner(tpBtn, 5)
            Utils.RegisterAccent(tpBtn, "BackgroundColor3")

            local delBtn = Utils.Create("TextButton", {
                Size = UDim2.new(0, 28, 0, 24),
                Position = UDim2.new(1, -38, 0.5, -12),
                BackgroundColor3 = Theme.Danger,
                Font = Theme.FontBold,
                Text = "✕",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 11,
                AutoButtonColor = false,
                ZIndex = 16,
            }, row)
            Utils.AddCorner(delBtn, 5)

            tpBtn.MouseButton1Click:Connect(function()
                local _, _, root = Utils.GetCharacter()
                if root then
                    root.CFrame = wp.CFrame
                    Utils.Notify("Waypoint", "Teleport ke " .. wp.Name, Theme.Success)
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
            Utils.Notify("Error", "Character root tidak ditemukan.", Theme.Danger)
            return
        end
        local name = wpBox.Text ~= "" and wpBox.Text or ("Point #" .. tostring(#State.Waypoints + 1))
        table.insert(State.Waypoints, { Name = name, CFrame = root.CFrame })
        wpBox.Text = ""
        renderWaypoints()
        Utils.Notify("Waypoint Tersimpan", "Menyimpan '" .. name .. "'", Theme.Success)
    end)

    Components.AddSectionHeader(page, "Player Teleport & Spectate", 5)

    local playerListHolder = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 6,
        ZIndex = 14,
    }, page)
    Utils.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, playerListHolder)

    local function refreshPlayerList()
        for _, child in ipairs(playerListHolder:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                count = count + 1
                local row = Utils.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 42),
                    BackgroundColor3 = Theme.BgCard,
                    BackgroundTransparency = 0.25,
                    BorderSizePixel = 0,
                    LayoutOrder = count,
                    ZIndex = 15,
                }, playerListHolder)
                Utils.AddCorner(row, 8)
                Utils.AddStroke(row, Theme.BorderSubtle, 1, 0.3)

                Utils.Create("TextLabel", {
                    Size = UDim2.new(1, -155, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Theme.FontFamily,
                    Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 16,
                }, row)

                local tpBtn = Utils.Create("TextButton", {
                    Size = UDim2.new(0, 64, 0, 24),
                    Position = UDim2.new(1, -138, 0.5, -12),
                    BackgroundColor3 = Theme.Accent,
                    Font = Theme.FontBold,
                    Text = "Goto",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 16,
                }, row)
                Utils.AddCorner(tpBtn, 5)
                Utils.RegisterAccent(tpBtn, "BackgroundColor3")

                local isSpec = (State.SpectatingPlayer == plr)
                local viewBtn = Utils.Create("TextButton", {
                    Size = UDim2.new(0, 60, 0, 24),
                    Position = UDim2.new(1, -68, 0.5, -12),
                    BackgroundColor3 = isSpec and Theme.Warning or Theme.BgControl,
                    Font = Theme.FontBold,
                    Text = isSpec and "Unview" or "View",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 16,
                }, row)
                Utils.AddCorner(viewBtn, 5)

                tpBtn.MouseButton1Click:Connect(function()
                    local _, _, myRoot = Utils.GetCharacter()
                    local targetRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if myRoot and targetRoot then
                        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                        Utils.Notify("Teleport", "Berpindah ke " .. plr.DisplayName, Theme.Success)
                    else
                        Utils.Notify("Tidak Tersedia", "Karakter target belum spawn.", Theme.Warning)
                    end
                end)

                viewBtn.MouseButton1Click:Connect(function()
                    local cam = workspace.CurrentCamera
                    if State.SpectatingPlayer == plr then
                        State.SpectatingPlayer = nil
                        local _, myHum = Utils.GetCharacter()
                        if cam and myHum then cam.CameraSubject = myHum end
                        Utils.Notify("Kamera", "Kamera kembali ke LocalPlayer.", Theme.TextSecondary)
                    else
                        local targetHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                        if cam and targetHum then
                            State.SpectatingPlayer = plr
                            cam.CameraSubject = targetHum
                            Utils.Notify("Spectating", "Melihat " .. plr.DisplayName, Theme.Warning)
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
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                ZIndex = 15,
            }, playerListHolder)
            Utils.AddCorner(empty, 8)
            Utils.Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Theme.FontFamily,
                Text = "Belum ada pemain lain di server ini.",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                ZIndex = 16,
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
-- TAB 8: VISUALS & ENVIRONMENT
-- ============================================================================
do
    local page = Components.CreateTab("Visuals", "☀", 8)
    Components.AddSectionHeader(page, "Camera & Rendering Controls", 1)

    local fovSlider = Components.AddSlider(page, "Camera Field of View (FOV)", 40, 120, 70, 0, 2, function(val)
        State.CameraFOV = val
        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = val
        end
    end)

    UI.FullbrightToggle = Components.AddToggle(page, "Fullbright Studio Lighting", "Hilangkan bayangan gelap dan terangkan pencahayaan", false, 3, function(on)
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
        Utils.Notify("Lighting", on and "Fullbright aktif." or "Pencahayaan asli dipulihkan.", Theme.Accent)
    end)

    UI.NoFogToggle = Components.AddToggle(page, "Clear Atmospheric Fog", "Hapus kabut FogEnd dan Atmosphere Density modern", false, 4, function(on)
        State.NoFogEnabled = on
        local currentAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if on then
            Lighting.FogEnd = 100000
            if currentAtmo then
                if not State.OriginalAtmosphere or State.OriginalAtmosphere.Instance ~= currentAtmo then
                    State.OriginalAtmosphere = { Instance = currentAtmo, Density = currentAtmo.Density }
                end
                currentAtmo.Density = 0
            end
        else
            Lighting.FogEnd = State.OriginalLighting.FogEnd
            if State.OriginalAtmosphere and State.OriginalAtmosphere.Instance and State.OriginalAtmosphere.Instance.Parent then
                State.OriginalAtmosphere.Instance.Density = State.OriginalAtmosphere.Density
            end
        end
    end)

    local todSlider = Components.AddSlider(page, "Client Time of Day (Hour)", 0, 24, math.floor(Lighting.ClockTime), 1, 5, function(val)
        Lighting.ClockTime = val
    end)

    Components.AddButton(page, "Reset Visuals & Camera", "Pulihkan FOV (70), toggle, dan pencahayaan bawaan", "Reset", 6, function()
        fovSlider.SetValue(70, true)
        if UI.FullbrightToggle then UI.FullbrightToggle.SetState(false, true) end
        if UI.NoFogToggle then UI.NoFogToggle.SetState(false, true) end

        local orig = State.OriginalLighting
        Lighting.Brightness = orig.Brightness
        Lighting.ClockTime = orig.ClockTime
        Lighting.FogEnd = orig.FogEnd
        Lighting.FogStart = orig.FogStart
        Lighting.GlobalShadows = orig.GlobalShadows
        Lighting.Ambient = orig.Ambient
        Lighting.OutdoorAmbient = orig.OutdoorAmbient
        todSlider.SetValue(orig.ClockTime, false)

        if State.OriginalAtmosphere and State.OriginalAtmosphere.Instance and State.OriginalAtmosphere.Instance.Parent then
            State.OriginalAtmosphere.Instance.Density = State.OriginalAtmosphere.Density
        end
        Utils.Notify("Visual Direset", "Kamera, toggle, dan pencahayaan dipulihkan.", Theme.Success)
    end)
end

-- ============================================================================
-- TAB 9: SETTINGS, THEME, FONT CUSTOMIZER & ANTI-AFK / SESSION STABILITY
-- ============================================================================
do
    local page = Components.CreateTab("Settings", "⚙", 9)
    Components.AddSectionHeader(page, "Perlindungan Sesi & Stabilitas Script", 1)

    Components.AddToggle(page, "Anti-AFK Otomatis (Semua Map)", "Mencegah disconnect otomatis saat diam lebih dari 20 menit", true, 2, function(on)
        Protection.AntiAFKEnabled = on
        Utils.Notify("Anti-AFK", on and "Anti-AFK aktif." or "Anti-AFK dimatikan.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddToggle(page, "Safe Execution & Error-Free Guard", "Isolasi pcall bersih & manajemen memori otomatis tanpa spam console", true, 3, function(on)
        Protection.SafeExecutionGuard = on
        Utils.Notify("Session Guard", on and "Proteksi stabilitas script aktif." or "Mode standar aktif.", on and Theme.Success or Theme.TextSecondary)
    end)

    Components.AddSectionHeader(page, "Kustomisasi Font & Warna Panel Menu", 4)

    Components.AddChipSelector(page, "Pilih Gaya Font Panel Menu", {
        { Label = "Gotham Modern", Value = "Gotham", Font = Enum.Font.GothamSemibold },
        { Label = "Fredoka Bulat", Value = "Fredoka", Font = Enum.Font.FredokaOne },
        { Label = "Creepster Spooky", Value = "Creepster", Font = Enum.Font.Creepster },
        { Label = "Fondamento Klasik", Value = "Fondamento", Font = Enum.Font.Fondamento },
        { Label = "Bangers Komik", Value = "Bangers", Font = Enum.Font.Bangers },
        { Label = "Roboto Mono", Value = "RobotoMono", Font = Enum.Font.RobotoMono },
        { Label = "Merriweather", Value = "Merriweather", Font = Enum.Font.Merriweather },
        { Label = "Ubuntu Clean", Value = "Ubuntu", Font = Enum.Font.Ubuntu },
        { Label = "Oswald Tegas", Value = "Oswald", Font = Enum.Font.Oswald },
    }, "Gotham", 5, function(val)
        local fontMap = {
            Gotham = { Enum.Font.GothamSemibold, Enum.Font.GothamBold },
            Fredoka = { Enum.Font.FredokaOne, Enum.Font.FredokaOne },
            Creepster = { Enum.Font.Creepster, Enum.Font.Creepster },
            Fondamento = { Enum.Font.Fondamento, Enum.Font.Fondamento },
            Bangers = { Enum.Font.Bangers, Enum.Font.Bangers },
            RobotoMono = { Enum.Font.RobotoMono, Enum.Font.RobotoMono },
            Merriweather = { Enum.Font.Merriweather, Enum.Font.Merriweather },
            Ubuntu = { Enum.Font.Ubuntu, Enum.Font.Ubuntu },
            Oswald = { Enum.Font.Oswald, Enum.Font.Oswald },
        }
        local pair = fontMap[val] or fontMap.Gotham
        Theme.FontFamily = pair[1]
        Theme.FontBold = pair[2]
        Utils.ApplyMenuFontAndColors()
        Utils.Notify("Font Diperbarui", "Menggunakan font: " .. val, Theme.Accent)
    end)

    Components.AddChipSelector(page, "Warna Aksen Tema Panel", {
        { Label = "Pumpkin Gold", Value = Color3.fromRGB(255, 118, 26), Color = Color3.fromRGB(255, 118, 26) },
        { Label = "Blood Crimson", Value = Color3.fromRGB(220, 48, 78), Color = Color3.fromRGB(220, 48, 78) },
        { Label = "Spectral Violet", Value = Color3.fromRGB(155, 89, 245), Color = Color3.fromRGB(155, 89, 245) },
        { Label = "Poison Emerald", Value = Color3.fromRGB(39, 194, 108), Color = Color3.fromRGB(39, 194, 108) },
        { Label = "Cobalt Blue", Value = Color3.fromRGB(79, 124, 255), Color = Color3.fromRGB(79, 124, 255) },
        { Label = "Amber Gold", Value = Color3.fromRGB(243, 168, 24), Color = Color3.fromRGB(243, 168, 24) },
    }, Color3.fromRGB(255, 118, 26), 6, function(val)
        Utils.SetAccentColor(val)
        Utils.Notify("Tema Diperbarui", "Warna aksen panel diperbarui.", val)
    end)

    Components.AddChipSelector(page, "Warna Font Panel Menu", {
        { Label = "Auto Kontras", Value = "Auto", Color = Color3.fromRGB(255, 210, 140) },
        { Label = "Putih Tulang", Value = Color3.fromRGB(255, 246, 235), Color = Color3.fromRGB(255, 246, 235) },
        { Label = "Oranye Labu", Value = Color3.fromRGB(255, 162, 72), Color = Color3.fromRGB(255, 162, 72) },
        { Label = "Ungu Pastel", Value = Color3.fromRGB(218, 178, 255), Color = Color3.fromRGB(218, 178, 255) },
        { Label = "Hijau Mint", Value = Color3.fromRGB(145, 255, 195), Color = Color3.fromRGB(145, 255, 195) },
        { Label = "Hitam Gelap", Value = Color3.fromRGB(22, 18, 30), Color = Color3.fromRGB(22, 18, 30) },
    }, "Auto", 7, function(val)
        Theme.FontColorMode = val
        Utils.ApplyMenuFontAndColors()
    end)

    Components.AddChipSelector(page, "Latar Belakang Font Menu (Tipis & Adaptif)", {
        { Label = "Tanpa Latar", Value = "None", Color = Color3.fromRGB(40, 31, 58) },
        { Label = "Obsidian Tipis", Value = Color3.fromRGB(16, 12, 24), Color = Color3.fromRGB(16, 12, 24) },
        { Label = "Ungu Malam", Value = Color3.fromRGB(36, 22, 58), Color = Color3.fromRGB(36, 22, 58) },
        { Label = "Coklat Labu", Value = Color3.fromRGB(48, 26, 14), Color = Color3.fromRGB(48, 26, 14) },
        { Label = "Merah Gelap", Value = Color3.fromRGB(52, 16, 24), Color = Color3.fromRGB(52, 16, 24) },
        { Label = "Putih Kabut", Value = Color3.fromRGB(238, 232, 245), Color = Color3.fromRGB(238, 232, 245) },
    }, "None", 8, function(val)
        if val == "None" then
            Theme.FontBgEnabled = false
        else
            Theme.FontBgEnabled = true
            Theme.FontBgColor = val
            Theme.FontBgTransparency = 0.68
        end
        Utils.ApplyMenuFontAndColors()
    end)

    Components.AddSectionHeader(page, "Controls & Unload", 9)

    Components.AddButton(page, "Toggle Keybind: RightShift", "Atau ketuk logo labu 3D di layar kapan saja", "Hide UI", 10, function()
        App.IsOpen = false
        UI.MainFrame.Visible = false
    end)

    Components.AddButton(page, "Unload & Clean Up Panel", "Putus semua loop, pulihkan bawaan karakter/map, dan tutup GUI", "Unload", 11, function()
        State.FlyEnabled = false
        State.NoclipEnabled = false
        State.InfiniteJumpEnabled = false
        ESP.Enabled = false
        Combat.AimbotEnabled = false
        Combat.MeleeImmunity = false

        Physics.CleanupFly()
        Physics.RestoreNoclip()
        ESP.ClearAll()
        Combat.HideLaser()
        if Combat.LaserPart then Combat.LaserPart:Destroy() end
        Carry.Stop()
        Emotes.Stop()
        Protection.RestoreEnemyHitboxes()

        local _, hum = Utils.GetCharacter()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
            if workspace.CurrentCamera then
                workspace.CurrentCamera.CameraSubject = hum
                workspace.CurrentCamera.FieldOfView = 70
            end
        end

        workspace.Gravity = State.OriginalGravity

        local orig = State.OriginalLighting
        Lighting.Brightness = orig.Brightness
        Lighting.ClockTime = orig.ClockTime
        Lighting.FogEnd = orig.FogEnd
        Lighting.FogStart = orig.FogStart
        Lighting.GlobalShadows = orig.GlobalShadows
        Lighting.Ambient = orig.Ambient
        Lighting.OutdoorAmbient = orig.OutdoorAmbient

        if State.OriginalAtmosphere and State.OriginalAtmosphere.Instance and State.OriginalAtmosphere.Instance.Parent then
            State.OriginalAtmosphere.Instance.Density = State.OriginalAtmosphere.Density
        end

        for _, conn in ipairs(Connections) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        table.clear(Connections)
        table.clear(State.AccentObjects)
        table.clear(State.ActiveToggleTracks)
        table.clear(State.ThemedTexts)

        if UI.ScreenGui then
            UI.ScreenGui:Destroy()
        end
    end)
end

-- ============================================================================
-- TAB 10: INFORMASI (DISCORD & LINK DONASI / DUKUNGAN DEV)
-- ============================================================================
do
    local page = Components.CreateTab("Informasi", "ⓘ", 10)
    Components.AddSectionHeader(page, "Informasi Pembuat & Dukungan", 1)

    local infoCard = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 74),
        BackgroundColor3 = Theme.BgCard,
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        ZIndex = 14,
    }, page)
    Utils.AddCorner(infoCard, 9)
    local stroke = Utils.AddStroke(infoCard, Theme.Accent, 1.2, 0.25)
    Utils.RegisterAccent(stroke, "Color")

    local h1 = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = "🎃 " .. App.Name .. " — Universal Edition",
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, infoCard)
    Utils.RegisterText(h1, true, Theme.TextPrimary)

    local h2 = Utils.Create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 30),
        BackgroundTransparency = 1,
        Font = Theme.FontFamily,
        Text = "Terima kasih telah menggunakan BimSakSin Hub v3.0! Semoga hari-hari kalian menyenangkan. Dukung perkembangan script dengan bergabung ke Discord atau melalui tautan donasi di bawah.",
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
    }, infoCard)
    Utils.RegisterText(h2, false, Theme.TextSecondary)

    Components.AddSectionHeader(page, "Tautan Resmi Komunitas & Donasi", 3)

    Components.AddButton(page, "Link Donasi / Dukungan Dev", App.DonationUrl, "Salin Link", 4, function()
        if Utils.CopyText(App.DonationUrl) then
            Utils.Notify("Link Donasi Tersalin!", App.DonationUrl, Theme.Success)
        else
            Utils.Notify("Link Donasi", App.DonationUrl, Theme.Accent)
        end
    end)

    Components.AddButton(page, "Link Server Discord Resmi", App.DiscordUrl, "Salin Link", 5, function()
        if Utils.CopyText(App.DiscordUrl) then
            Utils.Notify("Link Discord Tersalin!", App.DiscordUrl, Theme.Success)
        else
            Utils.Notify("Link Discord", App.DiscordUrl, Theme.Accent)
        end
    end)
end

-- ============================================================================
-- 14. RUNTIME LOOPS & EVENT HANDLERS
-- ============================================================================
do
    local function togglePanelVisibility()
        App.IsOpen = not App.IsOpen
        UI.MainFrame.Visible = App.IsOpen
    end

    UI.FloatingToggle.MouseButton1Click:Connect(togglePanelVisibility)
    UI.CloseBtn.MouseButton1Click:Connect(function()
        App.IsOpen = false
        UI.MainFrame.Visible = false
        Utils.Notify("Disembunyikan", "Ketuk logo labu 3D atau tekan RightShift untuk membuka.", Theme.Accent)
    end)

    local function getTitleFittedMinWidth()
        local titleWidth = (UI.TitleLabel and UI.TitleLabel.TextBounds.X > 0) and UI.TitleLabel.TextBounds.X or 172
        -- 54px kiri (emblem labu + jarak) + lebar teks judul "BimSakSin Hub v3.0" + 92px kanan (tombol — & ✕)
        return math.max(278, math.ceil(titleWidth) + 148)
    end

    local function applyResponsiveLayout(panelWidth)
        local sidebarW = (panelWidth < 500) and math.clamp(math.floor(panelWidth * 0.30), 116, 166) or 166
        UI.Sidebar.Size = UDim2.new(0, sidebarW, 1, -54)
        UI.ContentContainer.Size = UDim2.new(1, -sidebarW, 1, -54)
        UI.ContentContainer.Position = UDim2.new(0, sidebarW, 0, 54)
    end

    -- Drag Resize (Kecilkan & Besarkan ukuran panel menu secara halus)
    do
        local resizing = false
        local resizeInput = nil
        local resizeStartPos = nil
        local resizeStartSize = nil

        Utils.Track(UI.ResizeHandle.InputBegan:Connect(function(input)
            if App.IsMinimized then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeInput = input
                resizeStartPos = input.Position
                resizeStartSize = UI.MainFrame.AbsoluteSize
            end
        end))

        Utils.Track(UserInputService.InputChanged:Connect(function(input)
            if resizing and resizeStartPos and resizeStartSize and (input == resizeInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - resizeStartPos
                local vp = (UI.ScreenGui and UI.ScreenGui.AbsoluteSize) or Vector2.new(1280, 720)
                local minW = math.max(320, getTitleFittedMinWidth())
                local maxW = math.max(minW, vp.X - 24)
                local maxH = math.max(220, vp.Y - 24)

                local newW = math.clamp(math.floor(resizeStartSize.X + delta.X + 0.5), minW, maxW)
                local newH = math.clamp(math.floor(resizeStartSize.Y + delta.Y + 0.5), 220, maxH)

                App.ExpandedWidth = newW
                App.ExpandedHeight = newH
                UI.MainFrame.Size = UDim2.new(0, newW, 0, newH)
                applyResponsiveLayout(newW)
            end
        end))

        Utils.Track(UserInputService.InputEnded:Connect(function(input)
            if resizing and (input == resizeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                resizeInput = nil
            end
        end))
    end

    UI.MinimizeBtn.MouseButton1Click:Connect(function()
        if not App.IsMinimized then
            local curSize = UI.MainFrame.AbsoluteSize
            if curSize.X >= 260 and curSize.Y >= 180 then
                App.ExpandedWidth = math.floor(curSize.X + 0.5)
                App.ExpandedHeight = math.floor(curSize.Y + 0.5)
            end
        end

        App.IsMinimized = not App.IsMinimized
        UI.Sidebar.Visible = not App.IsMinimized
        UI.ContentContainer.Visible = not App.IsMinimized
        if UI.ResizeHandle then
            UI.ResizeHandle.Visible = not App.IsMinimized
        end
        UI.MinimizeBtn.Text = App.IsMinimized and "□" or "—"

        local targetWidth = App.IsMinimized and getTitleFittedMinWidth() or App.ExpandedWidth
        local targetHeight = App.IsMinimized and 54 or App.ExpandedHeight
        if not App.IsMinimized then
            applyResponsiveLayout(targetWidth)
        end

        Utils.Tween(UI.MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, targetWidth, 0, targetHeight)
        })
    end)

    Utils.Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            togglePanelVisibility()
        end
    end))

    Utils.Track(UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJumpEnabled then
            local _, hum = Utils.GetCharacter()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    local function onCharacterAdded(char)
        table.clear(Physics.NoclipCache)
        table.clear(Emotes.OriginalC0)
        Emotes.Playing = false
        Physics.CleanupFly()

        local hum = char:WaitForChild("Humanoid", 10)
        if hum then
            if State.WalkSpeed ~= 16 then hum.WalkSpeed = State.WalkSpeed end
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

    Utils.Track(Players.PlayerRemoving:Connect(function(plr)
        ESP.RemovePlayer(plr)
        ESP.RandomColorMap[plr.UserId] = nil
    end))

    -- Stepped Loop: Noclip, Carry Alignment, & Melee Immunity
    Utils.Track(RunService.Stepped:Connect(function()
        pcall(function()
            if State.NoclipEnabled then
                local char = Utils.GetCharacter()
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if Physics.NoclipCache[part] == nil then
                                Physics.NoclipCache[part] = part.CanCollide
                            end
                            if part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end

            if Carry.Enabled then
                Carry.Step()
            end

            if Combat.MeleeImmunity then
                Protection.StepMeleeImmunity()
            end
        end)
    end))

    -- RenderStepped Loop: Fly, Aimbot + RGB Gun Laser, Emotes, & Animasi Labu 3D
    Utils.Track(RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            local tNow = os.clock()

            -- 1. Animasi Hidup pada Logo Labu 3D
            local pulse = (math.sin(tNow * 3.4) + 1) * 0.5
            local eyeGlow = Color3.fromRGB(255, math.floor(195 + pulse * 60), math.floor(55 + pulse * 95))
            for _, pData in ipairs(UI.Pumpkins) do
                if pData.Holder and pData.Holder.Parent then
                    pData.EyeLeft.BackgroundColor3 = eyeGlow
                    pData.EyeRight.BackgroundColor3 = eyeGlow
                    pData.Mouth.BackgroundColor3 = eyeGlow
                    if pData.IsHero then
                        pData.Aura.BackgroundTransparency = 0.62 + (1 - pulse) * 0.18
                        pData.Holder.Rotation = math.sin(tNow * 2.2) * 5.5
                    end
                end
            end

            -- 2. Free-Flight Loop
            local _, hum, root = Utils.GetCharacter()
            local cam = workspace.CurrentCamera

            if State.FlyEnabled and hum and root and cam then
                if not Physics.FlyBV or Physics.FlyBV.Parent ~= root then
                    Physics.CleanupFly()
                    Physics.FlyBV = Utils.Create("BodyVelocity", {
                        Name = "BSS_FlyVelocity",
                        MaxForce = Vector3.new(9e9, 9e9, 9e9),
                        Velocity = Vector3.zero,
                    }, root)
                    Physics.FlyBG = Utils.Create("BodyGyro", {
                        Name = "BSS_FlyGyro",
                        MaxTorque = Vector3.new(9e9, 9e9, 9e9),
                        P = 9e4,
                        D = 500,
                    }, root)
                end

                hum.PlatformStand = true
                Physics.FlyBG.CFrame = cam.CFrame

                local moveDir = Vector3.zero
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

                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end

                if moveDir.Magnitude > 0 then
                    Physics.FlyBV.Velocity = moveDir.Unit * State.FlySpeed
                else
                    Physics.FlyBV.Velocity = Vector3.zero
                end
            else
                if Physics.FlyBV or Physics.FlyBG then
                    Physics.CleanupFly()
                end
            end

            -- 3. Auto Aimbot & Conditional RGB Weapon Laser
            if Combat.AimbotEnabled and cam then
                local tool, isGun = Combat.GetEquippedRangedWeapon()
                local shouldLock = false

                if Combat.AimbotMode == "Always" then
                    shouldLock = true
                elseif Combat.AimbotMode == "HoldRMB" then
                    shouldLock = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                else
                    local isClicking = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                    shouldLock = (tool ~= nil) or isClicking
                end

                if shouldLock then
                    local targetPlr, aimPart = Combat.FindBestTarget()
                    Combat.CurrentTarget = targetPlr
                    if targetPlr and aimPart then
                        local desiredCF = CFrame.lookAt(cam.CFrame.Position, aimPart.Position)
                        cam.CFrame = cam.CFrame:Lerp(desiredCF, math.clamp(Combat.Smoothness, 0.08, 1))

                        if Combat.RGBLaserEnabled and isGun and tool then
                            local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
                            if handle then
                                Combat.UpdateLaser(handle.Position, aimPart.Position)
                            else
                                Combat.HideLaser()
                            end
                        else
                            Combat.HideLaser()
                        end
                    else
                        Combat.HideLaser()
                    end
                else
                    Combat.CurrentTarget = nil
                    Combat.HideLaser()
                end
            else
                Combat.HideLaser()
            end

            -- 4. Universal R6/R15 Dance / Emote Step
            if Emotes.Playing then
                Emotes.Step(dt)
            end
        end)
    end))

    -- Throttled Updater (~6 Hz): Telemetry, Coordinates, & Universal ESP
    local frameCount = 0
    local lastTick = os.clock()

    Utils.Track(RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = os.clock()
        local dt = now - lastTick
        if dt >= 0.16 then
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
                    UI.TelemetryLabels.Coords.Text = "XYZ: Menunggu karakter..."
                end
            end

            pcall(ESP.UpdateAll)
        end
    end))
end

-- Inisialisasi Tab Awal & Notifikasi Selamat Datang
Components.SwitchTab("Dashboard")
Utils.Notify(App.Name, "Semoga hari-hari kalian menyenangkan! 🎃", Theme.Accent)
