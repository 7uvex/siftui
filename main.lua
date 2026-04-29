--[[
=====================================================================
    SIFT UI LIBRARY
    Version: 1.2.0
    Pure-black theme with midnight/purplish-blue accents.
    
    Loader:
        local Sift = loadstring(game:HttpGet("YOUR_RAW_URL/Sift.lua"))()
=====================================================================
]]

local Sift = {}
Sift.__index = Sift
Sift.Version = "1.2.0"
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
local StarterGui       = game:GetService("StarterGui")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================================
-- PLATFORM DETECTION + SCALE
-- 
-- Mobile detection: TouchEnabled but no Mouse → phone/tablet.
-- We expose a single SCALE multiplier; every size/position offset
-- gets multiplied by it through the helpers below. Desktop is 1.0
-- so existing layouts are untouched.
-- =====================================================================
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
Sift.IsMobile = IS_MOBILE
Sift.Scale = IS_MOBILE and 0.72 or 1.0

local function S(n)  -- scale a number (offset)
    return math.floor(n * Sift.Scale + 0.5)
end

local function SUDim2(xs, xo, ys, yo)
    return UDim2.new(xs, S(xo), ys, S(yo))
end

-- =====================================================================
-- THEME (mostly pure black, midnight/purplish-blue accents)
-- =====================================================================
Sift.Theme = {
    -- All blacks unified to one tone (no grey/black mix)
    Background      = Color3.fromRGB(5, 6, 9),        -- everywhere
    Surface         = Color3.fromRGB(5, 6, 9),        -- titlebar/sidebar (same as bg)
    SurfaceLight    = Color3.fromRGB(10, 11, 16),     -- element cards (subtle lift)
    SurfaceHover    = Color3.fromRGB(16, 18, 26),
    Border          = Color3.fromRGB(20, 22, 34),

    -- Midnight/purplish blue
    Accent          = Color3.fromRGB(80, 90, 220),    -- primary midnight blue
    AccentHover     = Color3.fromRGB(110, 120, 240),
    AccentDim       = Color3.fromRGB(50, 55, 150),
    AccentGlow      = Color3.fromRGB(140, 150, 255),  -- bright fluorescent edge

    -- Text — bolder/brighter white
    TextPrimary     = Color3.fromRGB(250, 252, 255),
    TextSecondary   = Color3.fromRGB(200, 205, 220),
    TextMuted       = Color3.fromRGB(120, 130, 155),
    TextOnAccent    = Color3.fromRGB(255, 255, 255),

    -- Status — all use the accent blue family per request
    Success         = Color3.fromRGB(80, 90, 220),
    Warning         = Color3.fromRGB(110, 120, 240),
    Error           = Color3.fromRGB(140, 150, 255),

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
        CornerRadius = UDim.new(0, S(radius or 8))
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
    p = S(p or 8)
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
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 10, 18)),
            ColorSequenceKeypoint.new(1, Sift.Theme.Background),
        }),
        Rotation = 45,
    })

    local container = new("Frame", {
        Parent = overlay,
        Size = SUDim2(0, 360, 0, 220),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    })

    local logoFrame = new("Frame", {
        Parent = container,
        Size = SUDim2(0, 64, 0, 64),
        Position = UDim2.new(0.5, 0, 0, S(10)),
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
        TextSize = S(38),
    })

    new("TextLabel", {
        Parent = container,
        Size = SUDim2(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, S(86)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(22),
    })
    new("TextLabel", {
        Parent = container,
        Size = SUDim2(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, S(116)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = subtitle,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(13),
    })

    local barBg = new("Frame", {
        Parent = container,
        Size = SUDim2(0, 280, 0, 6),
        Position = UDim2.new(0.5, 0, 0, S(156)),
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
        Size = SUDim2(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, S(172)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontMedium,
        Text = "0%",
        TextColor3 = Sift.Theme.AccentGlow,
        TextSize = S(13),
    })

    local pulseConn
    pulseConn = RunService.RenderStepped:Connect(function()
        if not logoFrame.Parent then
            pulseConn:Disconnect()
            return
        end
        local s = 1 + math.sin(tick() * 2) * 0.04
        logoFrame.Size = UDim2.new(0, S(64) * s, 0, S(64) * s)
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
-- KEY SYSTEM
-- 
-- Adapted from the user's loader. Uses Sift's theme. Calling
-- Sift:ShowKeySystem{Workers,...} runs the verification flow and
-- invokes opts.OnSuccess() when the key is accepted, or runs
-- opts.OnFailure if the user closes the window.
-- =====================================================================
local function _normalizeKey(key)
    key = tostring(key or "")
    key = key:gsub("%s+", "")
    key = key:upper()
    return key
end

local function _isStrictAlnumKey(key)
    if not key:match("^SK%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$") then return false end
    local parts = {}
    for part in key:gmatch("[^%-]+") do table.insert(parts, part) end
    if #parts ~= 5 or parts[1] ~= "SK" then return false end
    for i = 2, 5 do
        if not parts[i]:match("^[A-Z0-9]+$") then return false end
    end
    return true
end

local function _getRequestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local function _postJSON(url, bodyTable)
    local req = _getRequestFunction()
    if not req then return false, "no_request_function" end
    local ok, result = pcall(function()
        return req({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(bodyTable)
        })
    end)
    if not ok or not result then return false, "request_failed" end
    local body = result.Body or result.body
    local status = result.StatusCode or result.Status or result.status_code or 0
    if type(body) ~= "string" or body == "" then return false, "empty_response" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 then return false, "invalid_json_response" end
    return true, { status = tonumber(status) or 0, data = data }
end

local function _formatTimeRemaining(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", math.max(1, m))
end

function Sift:ShowKeySystem(opts)
    opts = opts or {}
    local CONFIG = {
        KeyLink                = opts.KeyLink                or "",
        WorkerBaseURL          = opts.WorkerBaseURL          or "",
        LocalCacheFile         = opts.LocalCacheFile         or "sift_redeemed_keys.json",
        ClientIdFile           = opts.ClientIdFile           or "sift_client_id.txt",
        SessionDurationSeconds = opts.SessionDurationSeconds or 6 * 60 * 60,
    }
    local onSuccess = opts.OnSuccess or function() end
    local onFailure = opts.OnFailure or function() end

    -- ===== client id =====
    local function getClientId()
        if isfile and readfile and writefile then
            if isfile(CONFIG.ClientIdFile) then
                local ok, data = pcall(readfile, CONFIG.ClientIdFile)
                if ok and type(data) == "string" and #data > 0 then return data end
            end
            local id = HttpService:GenerateGUID(false)
            pcall(writefile, CONFIG.ClientIdFile, id)
            return id
        end
        return HttpService:GenerateGUID(false)
    end
    local CLIENT_ID = getClientId()

    -- ===== cache =====
    local function loadCache()
        if not (isfile and readfile and isfile(CONFIG.LocalCacheFile)) then return {} end
        local ok, raw = pcall(readfile, CONFIG.LocalCacheFile)
        if not ok or type(raw) ~= "string" or raw == "" then return {} end
        local ok2, dec = pcall(function() return HttpService:JSONDecode(raw) end)
        if not (ok2 and type(dec) == "table") then return {} end
        local now = os.time()
        for _, bucket in pairs(dec) do
            if type(bucket) == "table" then
                for k, v in pairs(bucket) do
                    if v == true then
                        bucket[k] = { firstRedeemedAt = now, expiresAt = now, legacy = true }
                    end
                end
            end
        end
        return dec
    end
    local function saveCache(c)
        if writefile then
            pcall(function() writefile(CONFIG.LocalCacheFile, HttpService:JSONEncode(c)) end)
        end
    end
    local cache = loadCache()
    local function getBucket()
        local uid = tostring(LocalPlayer.UserId)
        cache[uid] = cache[uid] or {}
        return cache[uid]
    end
    local function checkSession(key)
        local entry = getBucket()[key]
        if type(entry) ~= "table" then return false end
        local exp = tonumber(entry.expiresAt)
        if not exp then return false end
        local now = os.time()
        if now < exp then return true, exp, exp - now end
        return false, exp, 0
    end
    local function markRedeemed(key)
        local b = getBucket()
        if type(b[key]) == "table" and checkSession(key) then return end
        local now = os.time()
        b[key] = { firstRedeemedAt = now, expiresAt = now + CONFIG.SessionDurationSeconds }
        saveCache(cache)
    end

    -- ===== auto-resume =====
    do
        for k, v in pairs(getBucket()) do
            if type(v) == "table" and not v.legacy and checkSession(k) then
                onSuccess(k)
                return
            end
        end
    end

    -- ===== UI =====
    local gui = new("ScreenGui", {
        Name = "SiftKeySystem",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 5000,
    })
    safeParent(gui)

    local main = new("Frame", {
        Parent = gui,
        Size = SUDim2(0, 380, 0, 260),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })
    corner(main, 12)
    local mainStroke = new("UIStroke", {
        Parent = main,
        Color = Sift.Theme.Accent,
        Thickness = 1.5,
        Transparency = 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    new("UIGradient", {
        Parent = mainStroke,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.Accent),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentGlow),
        }),
        Rotation = 45,
    })

    -- Logo strip
    local logoStrip = new("Frame", {
        Parent = main,
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0, S(14), 0, S(14)),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(logoStrip, 8)
    new("UIGradient", {
        Parent = logoStrip,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    new("TextLabel", {
        Parent = logoStrip,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = S(20),
    })

    new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -70, 0, 22),
        Position = UDim2.new(0, S(60), 0, S(16)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "Sift Verification",
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(16),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -70, 0, 16),
        Position = UDim2.new(0, S(60), 0, S(36)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "Enter your access key to continue",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local input = new("TextBox", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 38),
        Position = UDim2.new(0, S(14), 0, S(72)),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.Font,
        PlaceholderText = "SK-XXXX-XXXX-XXXX-XXXX",
        Text = "",
        TextColor3 = Sift.Theme.TextPrimary,
        PlaceholderColor3 = Sift.Theme.TextMuted,
        TextSize = S(13),
        ClearTextOnFocus = false,
    })
    corner(input, 6)
    local inputStroke = stroke(input, Sift.Theme.Border, 1, 0.3)
    padding(input, 10)
    input.Focused:Connect(function()
        tween(inputStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Accent, Transparency = 0})
    end)
    input.FocusLost:Connect(function()
        tween(inputStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Border, Transparency = 0.3})
    end)

    local status = new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 18),
        Position = UDim2.new(0, S(14), 0, S(118)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })

    local btnRow = new("Frame", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 38),
        Position = UDim2.new(0, S(14), 1, -S(56)),
        BackgroundTransparency = 1,
    })

    local function makeKBtn(text, color, x)
        local b = new("TextButton", {
            Parent = btnRow,
            Size = UDim2.new(0.48, 0, 1, 0),
            Position = UDim2.new(x, 0, 0, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Font = Sift.Theme.FontBold,
            Text = text,
            TextColor3 = Sift.Theme.TextOnAccent,
            TextSize = S(13),
            AutoButtonColor = false,
        })
        corner(b, 6)
        return b
    end
    local getKeyBtn   = makeKBtn("Get Key",   Sift.Theme.SurfaceLight, 0)
    local continueBtn = makeKBtn("Continue",  Sift.Theme.Accent,       0.52)

    makeDraggable(main)

    local function setStatus(text, isError)
        status.Text = text or ""
        status.TextColor3 = isError and Sift.Theme.Error or Sift.Theme.AccentGlow
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        if CONFIG.KeyLink ~= "" then
            pcall(function()
                if setclipboard then setclipboard(CONFIG.KeyLink)
                elseif toclipboard then toclipboard(CONFIG.KeyLink) end
            end)
            setStatus("Link copied. Open it, get your key, paste it here.", false)
        else
            setStatus("No key link configured.", true)
        end
    end)

    local validating = false
    local function validate(keyRaw)
        if validating then return end
        local key = _normalizeKey(keyRaw)
        if key == "" then setStatus("Please enter your key.", true) return end
        if not _isStrictAlnumKey(key) then setStatus("Invalid key format.", true) return end

        if checkSession(key) then
            setStatus("Session active. Loading...", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        if CONFIG.WorkerBaseURL == "" then
            -- no worker → local format check only
            markRedeemed(key)
            setStatus("Access granted (local).", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        validating = true
        continueBtn.Text = "Checking..."
        setStatus("Validating key...", false)

        local ok, response = _postJSON(CONFIG.WorkerBaseURL .. "/validate", {
            key = key,
            userId = LocalPlayer.UserId,
            clientId = CLIENT_ID,
        })
        validating = false
        continueBtn.Text = "Continue"

        if not ok or not response then
            -- backup: accept locally
            markRedeemed(key)
            setStatus("Access granted (backup).", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        local data = response.data or {}
        local err  = tostring(data.error or "")
        if response.status == 200 and data.ok and data.valid then
            markRedeemed(key)
            setStatus("Access granted.", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        if err == "already_redeemed" then
            if tostring(data.redeemedBy) == tostring(LocalPlayer.UserId) then
                markRedeemed(key)
                setStatus("Resuming session.", false)
                task.wait(0.3)
                gui:Destroy()
                onSuccess(key)
                return
            end
            setStatus("Key already used on a different account.", true)
        elseif err == "expired" then setStatus("This key expired. Get a new one.", true)
        elseif err == "unknown_key" then setStatus("That key does not exist.", true)
        elseif err == "invalid_format" then setStatus("Invalid key format.", true)
        else setStatus("Could not verify key.", true) end
    end

    continueBtn.MouseButton1Click:Connect(function() validate(input.Text) end)
    input.FocusLost:Connect(function(enter)
        input.Text = _normalizeKey(input.Text)
        if enter then validate(input.Text) end
    end)
end

-- =====================================================================
-- NOTIFICATION (top-left, blue-only colors)
-- =====================================================================
function Sift:Notify(opts)
    opts = opts or {}
    local title    = opts.Title    or "Notification"
    local content  = opts.Content  or ""
    local duration = opts.Duration or 3
    -- All Type variants now use the same blue family per the new theme.
    local accent   = Sift.Theme.Accent

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
            Size = UDim2.new(0, S(260), 1, -S(40)),
            Position = UDim2.new(0, S(16), 0, S(16)),
            AnchorPoint = Vector2.new(0, 0),
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent = Sift._notifyHolder,
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, S(6)),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    end

    local notif = new("Frame", {
        Parent = Sift._notifyHolder,
        Size = UDim2.new(1, 0, 0, S(56)),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(notif, 8)
    local notifStroke = stroke(notif, Sift.Theme.Accent, 1, 0.5)

    local stripe = new("Frame", {
        Parent = notif,
        Size = UDim2.new(0, S(3), 1, -S(14)),
        Position = UDim2.new(0, S(7), 0, S(7)),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(stripe, 2)

    local titleLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -S(24), 0, S(16)),
        Position = UDim2.new(0, S(18), 0, S(8)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
    })
    local contentLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -S(24), 0, S(28)),
        Position = UDim2.new(0, S(18), 0, S(24)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = content,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTransparency = 1,
    })

    notif.Position = UDim2.new(0, -S(260), 0, 0)
    tween(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0})
    tween(stripe, TweenInfo.new(0.25), {BackgroundTransparency = 0})
    tween(titleLbl, TweenInfo.new(0.25), {TextTransparency = 0})
    tween(contentLbl, TweenInfo.new(0.25), {TextTransparency = 0.15})
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
    local toggleKey   = opts.ToggleKey   or Enum.KeyCode.RightShift
    local userSize    = opts.Size        or UDim2.new(0, 580, 0, 400)

    -- Apply mobile scale to window size
    local sizeX = math.floor(userSize.X.Offset * Sift.Scale + 0.5)
    local sizeY = math.floor(userSize.Y.Offset * Sift.Scale + 0.5)
    local size = UDim2.new(0, sizeX, 0, sizeY)

    local gui = new("ScreenGui", {
        Name = "Sift_" .. HttpService:GenerateGUID(false):sub(1, 8),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    safeParent(gui)

    -- =========== MAIN CONTAINER ===========
    -- Single frame, single UICorner, single UIStroke = ONE border line.
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

    -- ONE fluorescent border (no double stroke)
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

    -- Note: removed the separate glowOuter frame so the border appears
    -- as a single line. The fluorescent gradient stroke alone gives the
    -- glow without doubling up.

    -- =========== TITLE BAR ===========
    -- Same color as body so the visible UI is one unified black.
    local titleBar = new("Frame", {
        Parent = main,
        Size = UDim2.new(1, -2, 0, S(38)),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })
    corner(titleBar, 11)
    new("Frame", {
        Parent = titleBar,
        Size = UDim2.new(1, 0, 0, S(12)),
        Position = UDim2.new(0, 0, 1, -S(12)),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 1,
    })

    local miniLogo = new("Frame", {
        Parent = titleBar,
        Size = SUDim2(0, 22, 0, 22),
        Position = UDim2.new(0, S(12), 0.5, 0),
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
        TextSize = S(14),
        ZIndex = 3,
    })

    -- Title with outline (UIStroke around text) matching the UI accent
    local titleLbl = new("TextLabel", {
        Parent = titleBar,
        Size = SUDim2(0, 200, 1, 0),
        Position = UDim2.new(0, S(42), 0, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(14),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    })
    new("UIStroke", {
        Parent = titleLbl,
        Color = Sift.Theme.Accent,
        Thickness = 1,
        Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
    })

    if subtitle ~= "" then
        new("TextLabel", {
            Parent = titleBar,
            Size = SUDim2(0, 250, 1, 0),
            Position = UDim2.new(0, S(42) + titleLbl.TextBounds.X + S(8), 0, 0),
            BackgroundTransparency = 1,
            Font = Sift.Theme.Font,
            Text = subtitle,
            TextColor3 = Sift.Theme.TextMuted,
            TextSize = S(12),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
    end

    -- ========= MIN BUTTON =========
    local minBtn = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 26, 0, 26),
        Position = UDim2.new(1, -S(42), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.FontBold,
        Text = "—",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(14),
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

    -- ========= CLOSE BUTTON (real X) =========
    local closeBtn = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 26, 0, 26),
        Position = UDim2.new(1, -S(10), 0.5, 0),
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
            Size = UDim2.new(0, S(12), 0, 1.5),
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
        tween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
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
        Size = UDim2.new(1, -2, 1, -S(39)),
        Position = UDim2.new(0, 1, 0, S(38)),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    })

    local sidebar = new("Frame", {
        Parent = body,
        Size = SUDim2(0, 140, 1, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })

    local tabList = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 1, -S(64)),
        BackgroundTransparency = 1,
    })
    new("UIListLayout", {
        Parent = tabList,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, S(4)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    padding(tabList, 8)

    -- ============ PROFILE AREA (bottom-left) ============
    local profileFrame = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 0, S(56)),
        Position = UDim2.new(0, 0, 1, -S(56)),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    new("Frame", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(16), 0, 1),
        Position = UDim2.new(0, S(8), 0, 0),
        BackgroundColor3 = Sift.Theme.Border,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
    })

    local avatar = new("ImageLabel", {
        Parent = profileFrame,
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0, S(10), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Image = getPlayerThumb(LocalPlayer.UserId),
    })
    corner(avatar, 18)
    stroke(avatar, Sift.Theme.Accent, 1, 0.3)

    local nameLbl = new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(80), 0, S(14)),
        Position = UDim2.new(0, S(52), 0.5, -S(10)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = LocalPlayer.DisplayName or LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local handleLbl = new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(80), 0, S(12)),
        Position = UDim2.new(0, S(52), 0.5, S(4)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "@" .. LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextMuted,
        TextSize = S(10),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Hide-user toggle (eye icon)
    local hideUserBtn = new("TextButton", {
        Parent = profileFrame,
        Size = SUDim2(0, 20, 0, 20),
        Position = UDim2.new(1, -S(10), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.FontBold,
        Text = "👁",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        AutoButtonColor = false,
    })
    corner(hideUserBtn, 4)

    local userHidden = false
    hideUserBtn.MouseButton1Click:Connect(function()
        userHidden = not userHidden
        if userHidden then
            tween(nameLbl, TweenInfo.new(0.2), {TextTransparency = 1})
            tween(handleLbl, TweenInfo.new(0.2), {TextTransparency = 1})
            tween(hideUserBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent, TextColor3 = Sift.Theme.TextOnAccent})
        else
            tween(nameLbl, TweenInfo.new(0.2), {TextTransparency = 0})
            tween(handleLbl, TweenInfo.new(0.2), {TextTransparency = 0})
            tween(hideUserBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight, TextColor3 = Sift.Theme.TextSecondary})
        end
    end)

    -- Content host
    local content = new("Frame", {
        Parent = body,
        Size = UDim2.new(1, -S(140), 1, 0),
        Position = UDim2.new(0, S(140), 0, 0),
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
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0.5, 0, 0, S(12)),
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
        TextSize = S(20),
    })

    makeDraggable(main, titleBar)

    -- ===================================================================
    -- OPEN / CLOSE ANIMATION
    -- 
    -- Animates main scale + transparency. Sets a "_animating" flag so
    -- repeated toggles can't stack tweens.
    -- ===================================================================
    local visible = true
    local animating = false
    local TWEEN_TIME = 0.22
    local TI_OUT = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local TI_IN  = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    -- Add a UIScale we can tween
    local mainScale = new("UIScale", { Parent = main, Scale = 1 })

    local function animateOpen()
        if animating then return end
        animating = true
        main.Visible = true
        mainScale.Scale = 0.85
        main.BackgroundTransparency = 1
        for _, d in ipairs(main:GetDescendants()) do
            if d:IsA("Frame") or d:IsA("ScrollingFrame") then
                d.BackgroundTransparency = math.clamp(d.BackgroundTransparency, 0, 1)
            end
        end
        tween(mainScale, TI_OUT, {Scale = 1})
        tween(main, TI_OUT, {BackgroundTransparency = 0})
        task.delay(TWEEN_TIME, function() animating = false end)
    end

    local function animateClose(onDone)
        if animating then return end
        animating = true
        tween(mainScale, TI_IN, {Scale = 0.85})
        tween(main, TI_IN, {BackgroundTransparency = 1})
        task.delay(TWEEN_TIME, function()
            main.Visible = false
            animating = false
            if onDone then onDone() end
        end)
    end

    -- ========= WINDOW OBJECT =========
    local Window = {
        _gui = gui,
        _minimizedGui = minimizedGui,
        _main = main,
        _sidebar = sidebar,
        _content = content,
        _tabs = {},
        _activeTab = nil,
        _toggleKey = toggleKey,
    }

    function Window:Toggle()
        if animating then return end
        if visible then
            visible = false
            animateClose(function()
                pill.Visible = true
            end)
        else
            visible = true
            pill.Visible = false
            animateOpen()
        end
    end

    function Window:Destroy()
        animateClose(function()
            self._gui:Destroy()
            self._minimizedGui:Destroy()
        end)
    end

    closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)
    minBtn.MouseButton1Click:Connect(function() Window:Toggle() end)
    pill.MouseButton1Click:Connect(function() Window:Toggle() end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then Window:Toggle() end
    end)

    -- Play opening animation on creation
    animateOpen()

    -- =====================================================================
    -- TAB
    -- =====================================================================
    function Window:CreateTab(tabOpts)
        tabOpts = tabOpts or {}
        local tabName = tabOpts.Name or tabOpts.Title or "Tab"

        local btn = new("TextButton", {
            Parent = tabList,
            Size = UDim2.new(1, 0, 0, S(32)),
            BackgroundColor3 = Sift.Theme.SurfaceLight,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Sift.Theme.FontMedium,
            Text = "  " .. tabName,
            TextColor3 = Sift.Theme.TextSecondary,
            TextSize = S(13),
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        corner(btn, 6)
        padding(btn, 8)

        local indicator = new("Frame", {
            Parent = btn,
            Size = SUDim2(0, 3, 0, 16),
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
            Padding = UDim.new(0, S(8)),
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
                Size = UDim2.new(1, 0, 0, S(height or 36)),
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
                Size = UDim2.new(1, 0, 0, S(24)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = name,
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end

        function Tab:AddLabel(text)
            local lbl = new("TextLabel", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, S(18)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = text,
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = S(12),
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
                Size = UDim2.new(1, 0, 0, S(50)),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            corner(f, 6)
            stroke(f, Sift.Theme.Border, 1, 0.5)
            padding(f, 10)
            new("UIListLayout", { Parent = f, Padding = UDim.new(0, S(4)) })
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, 0, 0, S(18)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = opts.Title or "Title",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
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
                TextSize = S(12),
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
                TextSize = S(13),
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
                Size = UDim2.new(1, -S(56), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Toggle",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local switch = new("Frame", {
                Parent = f,
                Size = SUDim2(0, 36, 0, 18),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
            })
            corner(switch, 9)
            stroke(switch, Sift.Theme.Border, 1, 0.4)

            local knob = new("Frame", {
                Parent = switch,
                Size = SUDim2(0, 14, 0, 14),
                Position = UDim2.new(0, S(2), 0.5, 0),
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
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(1, -S(16), 0.5, 0), BackgroundColor3 = Sift.Theme.TextOnAccent})
                else
                    tween(switch, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Background})
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(0, S(2), 0.5, 0), BackgroundColor3 = Sift.Theme.TextSecondary})
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
                Size = UDim2.new(1, -S(60), 0, S(18)),
                Position = UDim2.new(0, S(12), 0, S(6)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Slider",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local valueLbl = new("TextLabel", {
                Parent = f,
                Size = SUDim2(0, 50, 0, 18),
                Position = UDim2.new(1, -S(12), 0, S(6)),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = tostring(default),
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local barBg = new("Frame", {
                Parent = f,
                Size = UDim2.new(1, -S(24), 0, S(6)),
                Position = UDim2.new(0, S(12), 0, S(32)),
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
                Size = SUDim2(0, 12, 0, 12),
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
                if round == 0 then value = math.floor(value + 0.5)
                else local m = 10 ^ round; value = math.floor(value * m + 0.5) / m end
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

        function Tab:AddDropdown(opts)
            opts = opts or {}
            local items   = opts.Options or opts.Items or {}
            local default = opts.Default
            local multi   = opts.Multi or false
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.5, -S(12), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Dropdown",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local valueBtn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(0.5, -S(12), 0, S(24)),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                Text = "  Select...",
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
            })
            corner(valueBtn, 4)
            stroke(valueBtn, Sift.Theme.Accent, 1, 0.5)

            local arrow = new("TextLabel", {
                Parent = valueBtn,
                Size = UDim2.new(0, S(12), 1, 0),
                Position = UDim2.new(1, -S(8), 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = "▼",
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(9),
            })

            local popup = new("Frame", {
                Parent = gui,
                Size = UDim2.new(0, 100, 0, 0),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
                ClipsDescendants = true,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            new("UIListLayout", { Parent = popup, Padding = UDim.new(0, S(2)) })
            padding(popup, 4)

            local selected = multi and {} or nil
            local optionBtns, api = {}, {}
            local open = false

            local function refreshDisplay()
                if multi then
                    local count = 0
                    for _ in pairs(selected) do count = count + 1 end
                    if count == 0 then valueBtn.Text = "  None"
                    elseif count == 1 then for k in pairs(selected) do valueBtn.Text = "  " .. k end
                    else valueBtn.Text = "  " .. count .. " selected" end
                else
                    valueBtn.Text = "  " .. (selected or "Select...")
                end
            end

            local function rebuild()
                for _, b in ipairs(optionBtns) do b:Destroy() end
                optionBtns = {}
                for _, item in ipairs(items) do
                    local optBtn = new("TextButton", {
                        Parent = popup,
                        Size = UDim2.new(1, 0, 0, S(24)),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Font = Sift.Theme.Font,
                        Text = "  " .. tostring(item),
                        TextColor3 = Sift.Theme.TextSecondary,
                        TextSize = S(12),
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
                            if selected[item] then selected[item] = nil else selected[item] = true end
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
                local p, s = valueBtn.AbsolutePosition, valueBtn.AbsoluteSize
                local h = math.min(#items * S(26) + S(8), S(130))
                popup.Size = UDim2.new(0, s.X, 0, h)
                popup.Position = UDim2.new(0, p.X, 0, p.Y + s.Y + 4)
            end
            function api:Open() open = true rebuild() reposition() popup.Visible = true arrow.Text = "▲" end
            function api:Close() open = false popup.Visible = false arrow.Text = "▼" end
            function api:Set(v)
                if multi then
                    selected = {}
                    if type(v) == "table" then for _, k in ipairs(v) do selected[k] = true end end
                else selected = v end
                refreshDisplay()
                if flag then Sift.Flags[flag] = selected end
                if opts.Callback then pcall(opts.Callback, selected) end
            end
            function api:Get() return selected end
            function api:Refresh(n) items = n or items if open then rebuild() reposition() end end

            valueBtn.MouseButton1Click:Connect(function()
                if open then api:Close() else api:Open() end
            end)
            UserInputService.InputBegan:Connect(function(input)
                if open and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                    local mp = UserInputService:GetMouseLocation()
                    local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                    local p2, s2 = valueBtn.AbsolutePosition, valueBtn.AbsoluteSize
                    local inP = mp.X >= p1.X and mp.X <= p1.X + s1.X and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                    local inB = mp.X >= p2.X and mp.X <= p2.X + s2.X and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                    if not inP and not inB then api:Close() end
                end
            end)
            main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() if open then reposition() end end)

            rebuild()
            if default then api:Set(default) else refreshDisplay() end
            if flag then Sift.Flags[flag] = selected end
            return api
        end

        function Tab:AddInput(opts)
            opts = opts or {}
            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.4, -S(12), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Input",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local box = new("TextBox", {
                Parent = f,
                Size = UDim2.new(0.6, -S(12), 0, S(24)),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                PlaceholderText = opts.Placeholder or "",
                Text = opts.Default or "",
                TextColor3 = Sift.Theme.TextPrimary,
                PlaceholderColor3 = Sift.Theme.TextMuted,
                TextSize = S(12),
                ClearTextOnFocus = false,
            })
            corner(box, 4)
            local boxStroke = stroke(box, Sift.Theme.Border, 1, 0.4)
            padding(box, 6)
            box.Focused:Connect(function() tween(boxStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Accent, Transparency = 0}) end)
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
                Size = UDim2.new(1, -S(100), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Keybind",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local btn = new("TextButton", {
                Parent = f,
                Size = SUDim2(0, 80, 0, 24),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.FontMedium,
                Text = default.Name or "None",
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(12),
                AutoButtonColor = false,
            })
            corner(btn, 4)
            stroke(btn, Sift.Theme.Accent, 1, 0.5)

            local current, listening, api = default, false, {}
            local function setKey(k)
                current = k
                btn.Text = k.Name
                if flag then Sift.Flags[flag] = current end
            end
            function api:Set(k) setKey(k) end
            function api:Get() return current end
            btn.MouseButton1Click:Connect(function() listening = true btn.Text = "..." end)
            UserInputService.InputBegan:Connect(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    setKey(input.KeyCode); listening = false
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
            local default = opts.Default or Color3.fromRGB(80, 90, 220)
            local flag    = opts.Flag

            local f = elementContainer(36)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -S(56), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Color",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local swatch = new("TextButton", {
                Parent = f,
                Size = SUDim2(0, 28, 0, 20),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = default,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            })
            corner(swatch, 4)
            stroke(swatch, Sift.Theme.Accent, 1, 0.3)

            local color, api = default, {}

            local popup = new("Frame", {
                Parent = gui,
                Size = SUDim2(0, 180, 0, 96),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            padding(popup, 8)
            new("UIListLayout", { Parent = popup, Padding = UDim.new(0, S(6)) })

            local function makeChan(label, init)
                local row = new("Frame", { Parent = popup, Size = UDim2.new(1, 0, 0, S(18)), BackgroundTransparency = 1, ZIndex = 51 })
                new("TextLabel", { Parent = row, Size = SUDim2(0, 14, 1, 0), BackgroundTransparency = 1, Font = Sift.Theme.FontBold, Text = label, TextColor3 = Sift.Theme.Accent, TextSize = S(11), ZIndex = 52 })
                local box = new("TextBox", {
                    Parent = row, Size = UDim2.new(1, -S(22), 1, 0), Position = UDim2.new(0, S(18), 0, 0),
                    BackgroundColor3 = Sift.Theme.Background, BorderSizePixel = 0,
                    Font = Sift.Theme.Font, Text = tostring(init), TextColor3 = Sift.Theme.TextPrimary, TextSize = S(11), ZIndex = 52,
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
            r.FocusLost:Connect(commit); g.FocusLost:Connect(commit); b.FocusLost:Connect(commit)

            local function reposition()
                local p, s = swatch.AbsolutePosition, swatch.AbsoluteSize
                popup.Position = UDim2.new(0, p.X + s.X - S(180), 0, p.Y + s.Y + 4)
            end
            swatch.MouseButton1Click:Connect(function()
                if popup.Visible then popup.Visible = false
                else reposition(); popup.Visible = true end
            end)
            UserInputService.InputBegan:Connect(function(input)
                if popup.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                    local mp = UserInputService:GetMouseLocation()
                    local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                    local p2, s2 = swatch.AbsolutePosition, swatch.AbsoluteSize
                    local inP = mp.X >= p1.X and mp.X <= p1.X + s1.X and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                    local inB = mp.X >= p2.X and mp.X <= p2.X + s2.X and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                    if not inP and not inB then popup.Visible = false end
                end
            end)
            function api:Set(c)
                color = c; swatch.BackgroundColor3 = c
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
