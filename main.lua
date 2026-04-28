--[[
=====================================================================
    SIFT UI LIBRARY
    Version: 1.1.0
    Mostly-black theme with fluorescent blue accents.
    
    Loader:
        local Sift = loadstring(game:HttpGet("YOUR_RAW_URL/Sift.lua"))()
=====================================================================
]]

local Sift = {}
Sift.__index = Sift
Sift.Version = "1.1.0"
Sift.Flags = {}
Sift.Windows = {}

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================================
-- THEME (mostly black, fluorescent blue accents)
-- =====================================================================
Sift.Theme = {
    -- mostly very dark black backgrounds
    Background      = Color3.fromRGB(6, 7, 10),       -- darkest body
    Surface         = Color3.fromRGB(10, 12, 16),     -- titlebar / sidebar
    SurfaceLight    = Color3.fromRGB(16, 19, 25),     -- element cards
    SurfaceHover    = Color3.fromRGB(22, 26, 34),
    Border          = Color3.fromRGB(22, 28, 40),     -- subtle inner borders

    -- blue accents (used sparingly: sliders, toggles, buttons, dropdowns)
    Accent          = Color3.fromRGB(45, 140, 255),
    AccentHover     = Color3.fromRGB(75, 165, 255),
    AccentDim       = Color3.fromRGB(30, 95, 175),
    AccentGlow      = Color3.fromRGB(120, 200, 255),  -- fluorescent edge

    -- text
    TextPrimary     = Color3.fromRGB(235, 240, 250),
    TextSecondary   = Color3.fromRGB(150, 160, 180),
    TextMuted       = Color3.fromRGB(85, 95, 115),
    TextOnAccent    = Color3.fromRGB(255, 255, 255),

    -- status
    Success         = Color3.fromRGB(80, 220, 140),
    Warning         = Color3.fromRGB(255, 195, 80),
    Error           = Color3.fromRGB(255, 95, 110),

    -- typography
    Font            = Enum.Font.Gotham,
    FontBold        = Enum.Font.GothamBold,
    FontMedium      = Enum.Font.GothamMedium,
}

-- =====================================================================
-- INTERNAL HELPERS
-- =====================================================================
local function safeParent(gui)
    local ok = pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
        elseif gethui then
            gui.Parent = gethui()
        else
            gui.Parent = CoreGui
        end
    end)
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8)
    })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Parent = parent,
        Color = color or Sift.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function padding(parent, p)
    p = p or 8
    return new("UIPadding", {
        Parent = parent,
        PaddingTop = UDim.new(0, p),
        PaddingBottom = UDim.new(0, p),
        PaddingLeft = UDim.new(0, p),
        PaddingRight = UDim.new(0, p),
    })
end

local function tween(obj, info, props)
    local t = TweenService:Create(obj, info or TweenInfo.new(0.2), props)
    t:Play()
    return t
end

local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    local dragging, dragStart, startPos = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging
        and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Returns a Roblox content URL for the player's avatar headshot.
local function getPlayerThumb(userId)
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    if ok then return content end
    return "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

-- =====================================================================
-- LOADING SCREEN
-- =====================================================================
function Sift:ShowLoading(opts)
    opts = opts or {}
    local title    = opts.Title    or "Sift"
    local subtitle = opts.Subtitle or "Loading..."
    local duration = opts.Duration or 2.5
    local onDone   = opts.OnDone

    local gui = new("ScreenGui", {
        Name = "SiftLoading",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })
    safeParent(gui)

    local overlay = new("Frame", {
        Parent = gui,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })

    new("UIGradient", {
        Parent = overlay,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.Background),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 14, 22)),
            ColorSequenceKeypoint.new(1, Sift.Theme.Background),
        }),
        Rotation = 45,
    })

    local container = new("Frame", {
        Parent = overlay,
        Size = UDim2.new(0, 360, 0, 220),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    })

    local logoFrame = new("Frame", {
        Parent = container,
        Size = UDim2.new(0, 64, 0, 64),
        Position = UDim2.new(0.5, 0, 0, 10),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(logoFrame, 14)
    new("UIGradient", {
        Parent = logoFrame,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    stroke(logoFrame, Sift.Theme.AccentGlow, 1, 0.4)
    new("TextLabel", {
        Parent = logoFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = 38,
    })

    new("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 86),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = 22,
    })
    new("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 116),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = subtitle,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = 13,
    })

    local barBg = new("Frame", {
        Parent = container,
        Size = UDim2.new(0, 280, 0, 6),
        Position = UDim2.new(0.5, 0, 0, 156),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
    })
    corner(barBg, 3)
    stroke(barBg, Sift.Theme.Border, 1, 0.5)

    local barFill = new("Frame", {
        Parent = barBg,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(barFill, 3)
    new("UIGradient", {
        Parent = barFill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentDim),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.Accent),
        }),
    })

    local percent = new("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 172),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontMedium,
        Text = "0%",
        TextColor3 = Sift.Theme.AccentGlow,
        TextSize = 13,
    })

    local pulseConn
    pulseConn = RunService.RenderStepped:Connect(function()
        if not logoFrame.Parent then
            pulseConn:Disconnect()
            return
        end
        local s = 1 + math.sin(tick() * 2) * 0.04
        logoFrame.Size = UDim2.new(0, 64 * s, 0, 64 * s)
    end)

    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)
        local eased = 1 - (1 - alpha) ^ 3
        barFill.Size = UDim2.new(eased, 0, 1, 0)
        percent.Text = string.format("%d%%", math.floor(eased * 100))
        if alpha >= 1 then
            conn:Disconnect()
            task.wait(0.25)
            tween(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 1})
            for _, c in ipairs(container:GetDescendants()) do
                if c:IsA("TextLabel") then
                    tween(c, TweenInfo.new(0.4), {TextTransparency = 1})
                elseif c:IsA("Frame") then
                    tween(c, TweenInfo.new(0.4), {BackgroundTransparency = 1})
                elseif c:IsA("UIStroke") then
                    tween(c, TweenInfo.new(0.4), {Transparency = 1})
                end
            end
            task.wait(0.45)
            if pulseConn then pulseConn:Disconnect() end
            gui:Destroy()
            if onDone then onDone() end
        end
    end)

    return gui
end

-- =====================================================================
-- NOTIFICATION (top-left, smaller, themed to match UI)
-- =====================================================================
function Sift:Notify(opts)
    opts = opts or {}
    local title    = opts.Title    or "Notification"
    local content  = opts.Content  or ""
    local duration = opts.Duration or 3   -- 1s shorter than before
    local typ      = opts.Type     or "info"

    local accent = Sift.Theme.Accent
    if typ == "success" then accent = Sift.Theme.Success
    elseif typ == "warning" then accent = Sift.Theme.Warning
    elseif typ == "error"   then accent = Sift.Theme.Error end

    if not Sift._notifyGui or not Sift._notifyGui.Parent then
        Sift._notifyGui = new("ScreenGui", {
            Name = "SiftNotifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 10000,
        })
        safeParent(Sift._notifyGui)

        Sift._notifyHolder = new("Frame", {
            Parent = Sift._notifyGui,
            Size = UDim2.new(0, 260, 1, -40),
            Position = UDim2.new(0, 16, 0, 16),     -- TOP-LEFT
            AnchorPoint = Vector2.new(0, 0),
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent = Sift._notifyHolder,
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    end

    local notif = new("Frame", {
        Parent = Sift._notifyHolder,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Sift.Theme.Surface,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(notif, 8)
    local notifStroke = stroke(notif, Sift.Theme.AccentDim, 1, 0.5)

    local stripe = new("Frame", {
        Parent = notif,
        Size = UDim2.new(0, 3, 1, -14),
        Position = UDim2.new(0, 7, 0, 7),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(stripe, 2)

    local titleLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 18, 0, 8),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
    })

    local contentLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -24, 0, 28),
        Position = UDim2.new(0, 18, 0, 24),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = content,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTransparency = 1,
    })

    notif.Position = UDim2.new(0, -260, 0, 0)
    tween(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0})
    tween(stripe, TweenInfo.new(0.25), {BackgroundTransparency = 0})
    tween(titleLbl, TweenInfo.new(0.25), {TextTransparency = 0})
    tween(contentLbl, TweenInfo.new(0.25), {TextTransparency = 0.2})
    tween(notifStroke, TweenInfo.new(0.25), {Transparency = 0.3})

    task.delay(duration, function()
        tween(notif, TweenInfo.new(0.25), {BackgroundTransparency = 1})
        tween(stripe, TweenInfo.new(0.25), {BackgroundTransparency = 1})
        tween(titleLbl, TweenInfo.new(0.25), {TextTransparency = 1})
        tween(contentLbl, TweenInfo.new(0.25), {TextTransparency = 1})
        tween(notifStroke, TweenInfo.new(0.25), {Transparency = 1})
        task.wait(0.3)
        notif:Destroy()
    end)
end

-- =====================================================================
-- WINDOW
-- =====================================================================
function Sift:CreateWindow(opts)
    opts = opts or {}
    local title       = opts.Title       or "Sift"
    local subtitle    = opts.Subtitle    or ""
    local size        = opts.Size        or UDim2.new(0, 580, 0, 400)
    local toggleKey   = opts.ToggleKey   or Enum.KeyCode.RightShift

    local gui = new("ScreenGui", {
        Name = "Sift_" .. HttpService:GenerateGUID(false):sub(1, 8),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    safeParent(gui)

    -- =========== MAIN CONTAINER (rounded all sides) ===========
    local main = new("Frame", {
        Parent = gui,
        Size = size,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })
    corner(main, 12)

    -- Fluorescent blue border
    local mainStroke = new("UIStroke", {
        Parent = main,
        Color = Sift.Theme.Accent,
        Thickness = 1.5,
        Transparency = 0.15,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    new("UIGradient", {
        Parent = mainStroke,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.Accent),
            ColorSequenceKeypoint.new(1,   Sift.Theme.AccentGlow),
        }),
        Rotation = 45,
    })

    -- Outer glow
    local glowOuter = new("Frame", {
        Parent = gui,
        Size = UDim2.new(0, size.X.Offset + 8, 0, size.Y.Offset + 8),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 0,
    })
    corner(glowOuter, 14)
    new("UIStroke", {
        Parent = glowOuter,
        Color = Sift.Theme.Accent,
        Thickness = 3,
        Transparency = 0.75,
    })
    main:GetPropertyChangedSignal("Position"):Connect(function()
        glowOuter.Position = main.Position
    end)
    main:GetPropertyChangedSignal("Size"):Connect(function()
        glowOuter.Size = UDim2.new(0, main.Size.X.Offset + 8, 0, main.Size.Y.Offset + 8)
    end)

    -- =========== TITLE BAR ===========
    local titleBar = new("Frame", {
        Parent = main,
        Size = UDim2.new(1, -2, 0, 38),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = Sift.Theme.Surface,
        BorderSizePixel = 0,
    })
    corner(titleBar, 11)
    new("Frame", {
        Parent = titleBar,
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Sift.Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 1,
    })

    local miniLogo = new("Frame", {
        Parent = titleBar,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    corner(miniLogo, 5)
    new("UIGradient", {
        Parent = miniLogo,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    new("TextLabel", {
        Parent = miniLogo,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = 14,
        ZIndex = 3,
    })

    local titleLbl = new("TextLabel", {
        Parent = titleBar,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 42, 0, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    })

    if subtitle ~= "" then
        new("TextLabel", {
            Parent = titleBar,
            Size = UDim2.new(0, 250, 1, 0),
            Position = UDim2.new(0, 42 + titleLbl.TextBounds.X + 8, 0, 0),
            BackgroundTransparency = 1,
            Font = Sift.Theme.Font,
            Text = subtitle,
            TextColor3 = Sift.Theme.TextMuted,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
    end

    -- ========= MIN BUTTON =========
    local minBtn = new("TextButton", {
        Parent = titleBar,
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -42, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.FontBold,
        Text = "—",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = 14,
        AutoButtonColor = false,
        ZIndex = 2,
    })
    corner(minBtn, 6)
    minBtn.MouseEnter:Connect(function()
        tween(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent, TextColor3 = Sift.Theme.TextOnAccent})
    end)
    minBtn.MouseLeave:Connect(function()
        tween(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight, TextColor3 = Sift.Theme.TextSecondary})
    end)

    -- ========= CLOSE BUTTON (real X built from two rotated bars) =========
    local closeBtn = new("TextButton", {
        Parent = titleBar,
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    })
    corner(closeBtn, 6)

    local function makeXBar(rotation)
        local bar = new("Frame", {
            Parent = closeBtn,
            Size = UDim2.new(0, 12, 0, 1.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextSecondary,
            BorderSizePixel = 0,
            Rotation = rotation,
            ZIndex = 3,
        })
        corner(bar, 1)
        return bar
    end
    local xBar1 = makeXBar(45)
    local xBar2 = makeXBar(-45)

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Error})
        tween(xBar1, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
        tween(xBar2, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
        tween(xBar1, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextSecondary})
        tween(xBar2, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextSecondary})
    end)

    -- ========= BODY =========
    local body = new("Frame", {
        Parent = main,
        Size = UDim2.new(1, -2, 1, -39),
        Position = UDim2.new(0, 1, 0, 38),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    })

    -- Sidebar
    local sidebar = new("Frame", {
        Parent = body,
        Size = UDim2.new(0, 140, 1, 0),
        BackgroundColor3 = Sift.Theme.Surface,
        BorderSizePixel = 0,
    })

    -- Tab list
    local tabList = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 1, -64),
        BackgroundTransparency = 1,
    })
    new("UIListLayout", {
        Parent = tabList,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    padding(tabList, 8)

    -- Profile area
    local profileFrame = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 0, 56),
        Position = UDim2.new(0, 0, 1, -56),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })
    new("Frame", {
        Parent = profileFrame,
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundColor3 = Sift.Theme.Border,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
    })

    local avatar = new("ImageLabel", {
        Parent = profileFrame,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(0, 10, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Image = getPlayerThumb(LocalPlayer.UserId),
    })
    corner(avatar, 18)
    stroke(avatar, Sift.Theme.Accent, 1, 0.3)

    new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -56, 0, 14),
        Position = UDim2.new(0, 52, 0.5, -10),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = LocalPlayer.DisplayName or LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -56, 0, 12),
        Position = UDim2.new(0, 52, 0.5, 4),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "@" .. LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextMuted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Content host
    local content = new("Frame", {
        Parent = body,
        Size = UDim2.new(1, -140, 1, 0),
        Position = UDim2.new(0, 140, 0, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })

    -- =========== MINIMIZED PILL ===========
    local minimizedGui = new("ScreenGui", {
        Name = "Sift_Minimized",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 99,
    })
    safeParent(minimizedGui)

    local pill = new("TextButton", {
        Parent = minimizedGui,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(0.5, 0, 0, 12),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
    })
    corner(pill, 8)
    new("UIGradient", {
        Parent = pill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    stroke(pill, Sift.Theme.AccentGlow, 1, 0.3)
    new("TextLabel", {
        Parent = pill,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = 20,
    })

    makeDraggable(main, titleBar)

    -- ========= WINDOW OBJECT =========
    local Window = {
        _gui = gui,
        _minimizedGui = minimizedGui,
        _glowOuter = glowOuter,
        _main = main,
        _sidebar = sidebar,
        _content = content,
        _tabs = {},
        _activeTab = nil,
        _visible = true,
        _toggleKey = toggleKey,
    }

    function Window:Toggle()
        self._visible = not self._visible
        self._main.Visible = self._visible
        self._glowOuter.Visible = self._visible
        pill.Visible = not self._visible
    end

    function Window:Destroy()
        self._gui:Destroy()
        self._minimizedGui:Destroy()
    end

    closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)
    minBtn.MouseButton1Click:Connect(function() Window:Toggle() end)
    pill.MouseButton1Click:Connect(function() Window:Toggle() end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then Window:Toggle() end
    end)

    -- =====================================================================
    -- TAB
    -- =====================================================================
    function Window:CreateTab(tabOpts)
        tabOpts = tabOpts or {}
        local tabName = tabOpts.Name or tabOpts.Title or "Tab"

        local btn = new("TextButton", {
            Parent = tabList,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Sift.Theme.SurfaceLight,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Sift.Theme.FontMedium,
            Text = "  " .. tabName,
            TextColor3 = Sift.Theme.TextSecondary,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        corner(btn, 6)
        padding(btn, 8)

        local indicator = new("Frame", {
            Parent = btn,
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Sift.Theme.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        })
        corner(indicator, 2)

        local page = new("ScrollingFrame", {
            Parent = self._content,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Sift.Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ClipsDescendants = false,
        })
        padding(page, 12)
        new("UIListLayout", {
            Parent = page,
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local Tab = { _btn = btn, _page = page, _indicator = indicator, _name = tabName }

        local function setActive(active)
            if active then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0, BackgroundColor3 = Sift.Theme.SurfaceLight})
                tween(btn, TweenInfo.new(0.15), {TextColor3 = Sift.Theme.TextPrimary})
                tween(indicator, TweenInfo.new(0.15), {BackgroundTransparency = 0})
                page.Visible = true
            else
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                tween(btn, TweenInfo.new(0.15), {TextColor3 = Sift.Theme.TextSecondary})
                tween(indicator, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                page.Visible = false
            end
        end
        Tab._setActive = setActive

        btn.MouseEnter:Connect(function()
            if Window._activeTab ~= Tab then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5, BackgroundColor3 = Sift.Theme.SurfaceLight})
            end
        end)
        btn.MouseLeave:Connect(function()
            if Window._activeTab ~= Tab then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1})
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if Window._activeTab then Window._activeTab._setActive(false) end
            Window._activeTab = Tab
            setActive(true)
        end)
        if not Window._activeTab then
            Window._activeTab = Tab
            setActive(true)
        end
        table.insert(self._tabs, Tab)

        -- ===================== ELEMENTS =====================
        local function elementContainer(height)
            local f = new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, height or 36),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                ClipsDescendants = false,
            })
            corner(f, 6)
            stroke(f, Sift.Theme.Border, 1, 0.5)
            return f
        end

        function Tab:AddSection(name)
            return new("TextLabel", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = name,
                TextColor3 = Sift.Theme.Accent,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end

        function Tab:AddLabel(text)
            local lbl = new("TextLabel", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = text,
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            })
            local api = {}
            function api:Set(t) lbl.Text = t end
            return api
        end

        function Tab:AddParagraph(opts)
            opts = opts or {}
            local f = new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            corner(f, 6)
            stroke(f, Sift.Theme.Border, 1, 0.5)
            padding(f, 10)
            new("UIListLayout", { Parent = f, Padding = UDim.new(0, 4) })
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = opts.Title or "Title",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = opts.Content or "",
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
            })
            return f
        end

        function Tab:AddButton(opts)
            opts = opts or {}
            local f = elementContainer(36)
            local btn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Button",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                AutoButtonColor = false,
            })
            btn.MouseEnter:Connect(function()
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.AccentDim})
            end)
            btn.MouseLeave:Connect(function()
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
            end)
            btn.MouseButton1Click:Connect(function()
                tween(f, TweenInfo.new(0.08), {BackgroundColor3 = Sift.Theme.Accent})
                task.wait(0.08)
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.AccentDim})
                if opts.Callback then pcall(opts.Callback) end
            end)
            return btn
        end

        function Tab:AddToggle(opts)
            opts = opts or {}
            local default = opts.Default or false
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -56, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Toggle",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local switch = new("Frame", {
                Parent = f,
                Size = UDim2.new(0, 36, 0, 18),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
            })
            corner(switch, 9)
            stroke(switch, Sift.Theme.Border, 1, 0.4)

            local knob = new("Frame", {
                Parent = switch,
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 2, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Sift.Theme.TextSecondary,
                BorderSizePixel = 0,
            })
            corner(knob, 7)

            local clickArea = new("TextButton", {
                Parent = f,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
            })

            local state = default
            local api = {}
            local function render()
                if state then
                    tween(switch, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(1, -16, 0.5, 0), BackgroundColor3 = Sift.Theme.TextOnAccent})
                else
                    tween(switch, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Background})
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Sift.Theme.TextSecondary})
                end
            end
            function api:Set(v)
                state = v and true or false
                if flag then Sift.Flags[flag] = state end
                render()
                if opts.Callback then pcall(opts.Callback, state) end
            end
            function api:Get() return state end
            clickArea.MouseButton1Click:Connect(function() api:Set(not state) end)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            if flag then Sift.Flags[flag] = state end
            render()
            return api
        end

        function Tab:AddSlider(opts)
            opts = opts or {}
            local min     = opts.Min or 0
            local max     = opts.Max or 100
            local default = math.clamp(opts.Default or min, min, max)
            local round   = opts.Round or 0
            local flag    = opts.Flag

            local f = elementContainer(54)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -60, 0, 18),
                Position = UDim2.new(0, 12, 0, 6),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Slider",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local valueLbl = new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0, 50, 0, 18),
                Position = UDim2.new(1, -12, 0, 6),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = tostring(default),
                TextColor3 = Sift.Theme.Accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local barBg = new("Frame", {
                Parent = f,
                Size = UDim2.new(1, -24, 0, 6),
                Position = UDim2.new(0, 12, 0, 32),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
            })
            corner(barBg, 3)
            stroke(barBg, Sift.Theme.Border, 1, 0.5)

            local fill = new("Frame", {
                Parent = barBg,
                Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Sift.Theme.Accent,
                BorderSizePixel = 0,
            })
            corner(fill, 3)

            local knob = new("Frame", {
                Parent = barBg,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Sift.Theme.AccentGlow,
                BorderSizePixel = 0,
            })
            corner(knob, 6)

            local function format(v)
                if round == 0 then return tostring(math.floor(v)) end
                return string.format("%." .. round .. "f", v)
            end

            local value = default
            local api = {}
            local function setFromAlpha(alpha)
                alpha = math.clamp(alpha, 0, 1)
                value = min + (max - min) * alpha
                if round == 0 then
                    value = math.floor(value + 0.5)
                else
                    local mult = 10 ^ round
                    value = math.floor(value * mult + 0.5) / mult
                end
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLbl.Text = format(value)
                if flag then Sift.Flags[flag] = value end
                if opts.Callback then pcall(opts.Callback, value) end
            end
            function api:Set(v)
                local alpha = (math.clamp(v, min, max) - min) / (max - min)
                setFromAlpha(alpha)
            end
            function api:Get() return value end

            local dragging = false
            local function update(input)
                local pos = input.Position.X - barBg.AbsolutePosition.X
                setFromAlpha(pos / barBg.AbsoluteSize.X)
            end
            barBg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    update(input)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging
                and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            if flag then Sift.Flags[flag] = value end
            return api
        end

        -- ============== DROPDOWN (popup hosted at top of window gui) ==============
        function Tab:AddDropdown(opts)
            opts = opts or {}
            local items   = opts.Options or opts.Items or {}
            local default = opts.Default
            local multi   = opts.Multi or false
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.5, -12, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Dropdown",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local valueBtn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(0.5, -12, 0, 24),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                Text = "  Select...",
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
            })
            corner(valueBtn, 4)
            stroke(valueBtn, Sift.Theme.Accent, 1, 0.5)

            local arrow = new("TextLabel", {
                Parent = valueBtn,
                Size = UDim2.new(0, 12, 1, 0),
                Position = UDim2.new(1, -8, 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = "▼",
                TextColor3 = Sift.Theme.Accent,
                TextSize = 9,
            })

            -- popup at top of window gui so it overlaps everything else
            local popup = new("Frame", {
                Parent = gui,
                Size = UDim2.new(0, 100, 0, 0),
                BackgroundColor3 = Sift.Theme.Surface,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
                ClipsDescendants = true,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            new("UIListLayout", { Parent = popup, Padding = UDim.new(0, 2) })
            padding(popup, 4)

            local selected = multi and {} or nil
            local optionBtns = {}
            local api = {}
            local open = false

            local function refreshDisplay()
                if multi then
                    local count = 0
                    for _ in pairs(selected) do count = count + 1 end
                    if count == 0 then valueBtn.Text = "  None"
                    elseif count == 1 then
                        for k in pairs(selected) do valueBtn.Text = "  " .. k end
                    else valueBtn.Text = "  " .. count .. " selected" end
                else
                    valueBtn.Text = "  " .. (selected or "Select...")
                end
            end

            local function rebuildOptions()
                for _, b in ipairs(optionBtns) do b:Destroy() end
                optionBtns = {}
                for _, item in ipairs(items) do
                    local optBtn = new("TextButton", {
                        Parent = popup,
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundColor3 = Sift.Theme.SurfaceLight,
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Font = Sift.Theme.Font,
                        Text = "  " .. tostring(item),
                        TextColor3 = Sift.Theme.TextSecondary,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 51,
                        AutoButtonColor = false,
                    })
                    corner(optBtn, 4)
                    optBtn.MouseEnter:Connect(function()
                        tween(optBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0, BackgroundColor3 = Sift.Theme.AccentDim, TextColor3 = Sift.Theme.TextPrimary})
                    end)
                    optBtn.MouseLeave:Connect(function()
                        tween(optBtn, TweenInfo.new(0.1), {BackgroundTransparency = 1, TextColor3 = Sift.Theme.TextSecondary})
                    end)
                    optBtn.MouseButton1Click:Connect(function()
                        if multi then
                            if selected[item] then selected[item] = nil
                            else selected[item] = true end
                            refreshDisplay()
                            if flag then Sift.Flags[flag] = selected end
                            if opts.Callback then pcall(opts.Callback, selected) end
                        else
                            selected = item
                            refreshDisplay()
                            if flag then Sift.Flags[flag] = selected end
                            if opts.Callback then pcall(opts.Callback, selected) end
                            api:Close()
                        end
                    end)
                    table.insert(optionBtns, optBtn)
                end
            end

            local function reposition()
                local btnPos = valueBtn.AbsolutePosition
                local btnSize = valueBtn.AbsoluteSize
                local popupHeight = math.min(#items * 26 + 8, 130)
                popup.Size = UDim2.new(0, btnSize.X, 0, popupHeight)
                popup.Position = UDim2.new(0, btnPos.X, 0, btnPos.Y + btnSize.Y + 4)
            end

            function api:Open()
                open = true
                rebuildOptions()
                reposition()
                popup.Visible = true
                arrow.Text = "▲"
            end
            function api:Close()
                open = false
                popup.Visible = false
                arrow.Text = "▼"
            end
            function api:Set(v)
                if multi then
                    selected = {}
                    if type(v) == "table" then for _, k in ipairs(v) do selected[k] = true end end
                else
                    selected = v
                end
                refreshDisplay()
                if flag then Sift.Flags[flag] = selected end
                if opts.Callback then pcall(opts.Callback, selected) end
            end
            function api:Get() return selected end
            function api:Refresh(newItems)
                items = newItems or items
                if open then rebuildOptions() reposition() end
            end

            valueBtn.MouseButton1Click:Connect(function()
                if open then api:Close() else api:Open() end
            end)

            UserInputService.InputBegan:Connect(function(input)
                if open
                and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                    local mp = UserInputService:GetMouseLocation()
                    local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                    local p2, s2 = valueBtn.AbsolutePosition, valueBtn.AbsoluteSize
                    local inPopup = mp.X >= p1.X and mp.X <= p1.X + s1.X
                                and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                    local inBtn   = mp.X >= p2.X and mp.X <= p2.X + s2.X
                                and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                    if not inPopup and not inBtn then api:Close() end
                end
            end)

            main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                if open then reposition() end
            end)

            rebuildOptions()
            if default then api:Set(default) else refreshDisplay() end
            if flag then Sift.Flags[flag] = selected end
            return api
        end

        function Tab:AddInput(opts)
            opts = opts or {}
            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.4, -12, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Input",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local box = new("TextBox", {
                Parent = f,
                Size = UDim2.new(0.6, -12, 0, 24),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                PlaceholderText = opts.Placeholder or "",
                Text = opts.Default or "",
                TextColor3 = Sift.Theme.TextPrimary,
                PlaceholderColor3 = Sift.Theme.TextMuted,
                TextSize = 12,
                ClearTextOnFocus = false,
            })
            corner(box, 4)
            local boxStroke = stroke(box, Sift.Theme.Border, 1, 0.4)
            padding(box, 6)

            box.Focused:Connect(function()
                tween(boxStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Accent, Transparency = 0})
            end)
            box.FocusLost:Connect(function(enter)
                tween(boxStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Border, Transparency = 0.4})
                if opts.Callback then pcall(opts.Callback, box.Text, enter) end
                if opts.Flag then Sift.Flags[opts.Flag] = box.Text end
            end)

            local api = {}
            function api:Set(v) box.Text = tostring(v) end
            function api:Get() return box.Text end
            if opts.Flag then Sift.Flags[opts.Flag] = box.Text end
            return api
        end

        function Tab:AddKeybind(opts)
            opts = opts or {}
            local default = opts.Default or Enum.KeyCode.Unknown
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Keybind",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local btn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(0, 80, 0, 24),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.FontMedium,
                Text = default.Name or "None",
                TextColor3 = Sift.Theme.Accent,
                TextSize = 12,
                AutoButtonColor = false,
            })
            corner(btn, 4)
            stroke(btn, Sift.Theme.Accent, 1, 0.5)

            local current = default
            local listening = false
            local api = {}
            local function setKey(k)
                current = k
                btn.Text = k.Name
                if flag then Sift.Flags[flag] = current end
            end
            function api:Set(k) setKey(k) end
            function api:Get() return current end
            btn.MouseButton1Click:Connect(function()
                listening = true
                btn.Text = "..."
            end)
            UserInputService.InputBegan:Connect(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    setKey(input.KeyCode)
                    listening = false
                elseif not processed and not listening
                and input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode == current then
                    if opts.Callback then pcall(opts.Callback, current) end
                end
            end)
            if flag then Sift.Flags[flag] = current end
            return api
        end

        function Tab:AddColorPicker(opts)
            opts = opts or {}
            local default = opts.Default or Color3.fromRGB(45, 140, 255)
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -56, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Color",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local swatch = new("TextButton", {
                Parent = f,
                Size = UDim2.new(0, 28, 0, 20),
                Position = UDim2.new(1, -12, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = default,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            })
            corner(swatch, 4)
            stroke(swatch, Sift.Theme.Accent, 1, 0.3)

            local color = default
            local api = {}

            local popup = new("Frame", {
                Parent = gui,
                Size = UDim2.new(0, 180, 0, 96),
                BackgroundColor3 = Sift.Theme.Surface,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            padding(popup, 8)
            new("UIListLayout", { Parent = popup, Padding = UDim.new(0, 6) })

            local function makeChan(label, init)
                local row = new("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    ZIndex = 51,
                })
                new("TextLabel", {
                    Parent = row,
                    Size = UDim2.new(0, 14, 1, 0),
                    BackgroundTransparency = 1,
                    Font = Sift.Theme.FontBold,
                    Text = label,
                    TextColor3 = Sift.Theme.Accent,
                    TextSize = 11,
                    ZIndex = 52,
                })
                local box = new("TextBox", {
                    Parent = row,
                    Size = UDim2.new(1, -22, 1, 0),
                    Position = UDim2.new(0, 18, 0, 0),
                    BackgroundColor3 = Sift.Theme.Background,
                    BorderSizePixel = 0,
                    Font = Sift.Theme.Font,
                    Text = tostring(init),
                    TextColor3 = Sift.Theme.TextPrimary,
                    TextSize = 11,
                    ZIndex = 52,
                })
                corner(box, 3)
                stroke(box, Sift.Theme.Border, 1, 0.4)
                return box
            end
            local r = makeChan("R", math.floor(default.R * 255))
            local g = makeChan("G", math.floor(default.G * 255))
            local b = makeChan("B", math.floor(default.B * 255))

            local function commit()
                local rv = math.clamp(tonumber(r.Text) or 0, 0, 255)
                local gv = math.clamp(tonumber(g.Text) or 0, 0, 255)
                local bv = math.clamp(tonumber(b.Text) or 0, 0, 255)
                color = Color3.fromRGB(rv, gv, bv)
                swatch.BackgroundColor3 = color
                if flag then Sift.Flags[flag] = color end
                if opts.Callback then pcall(opts.Callback, color) end
            end
            r.FocusLost:Connect(commit)
            g.FocusLost:Connect(commit)
            b.FocusLost:Connect(commit)

            local function reposition()
                local p, s = swatch.AbsolutePosition, swatch.AbsoluteSize
                popup.Position = UDim2.new(0, p.X + s.X - 180, 0, p.Y + s.Y + 4)
            end

            swatch.MouseButton1Click:Connect(function()
                if popup.Visible then
                    popup.Visible = false
                else
                    reposition()
                    popup.Visible = true
                end
            end)

            UserInputService.InputBegan:Connect(function(input)
                if popup.Visible
                and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                    local mp = UserInputService:GetMouseLocation()
                    local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                    local p2, s2 = swatch.AbsolutePosition, swatch.AbsoluteSize
                    local inPopup = mp.X >= p1.X and mp.X <= p1.X + s1.X
                                and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                    local inBtn   = mp.X >= p2.X and mp.X <= p2.X + s2.X
                                and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                    if not inPopup and not inBtn then popup.Visible = false end
                end
            end)

            function api:Set(c)
                color = c
                swatch.BackgroundColor3 = c
                r.Text = tostring(math.floor(c.R * 255))
                g.Text = tostring(math.floor(c.G * 255))
                b.Text = tostring(math.floor(c.B * 255))
                if flag then Sift.Flags[flag] = c end
            end
            function api:Get() return color end
            if flag then Sift.Flags[flag] = color end
            return api
        end

        function Tab:AddDivider()
            return new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Sift.Theme.Border,
                BorderSizePixel = 0,
                BackgroundTransparency = 0.4,
            })
        end

        return Tab
    end

    table.insert(Sift.Windows, Window)
    return Window
end

return Sift
