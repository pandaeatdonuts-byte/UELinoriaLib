local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    OpenedDropdowns = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;

    -- Animation timings (seconds). Set any to 0 for instant behavior.
    Anim = {
        Toggle = 0.18;
        Slider = 0.45;
        SliderDrag = 0.22;
        Dropdown = 0.18;
        Tab = 0.28;
        Button = 0.14;
        ColorPicker = 0.2;
        Hover = 0.14;
        Depbox = 0.22;
        Notify = 0.34;
        Pop = 0.32;
        DragBlurSize = 10;
        MenuBlurSize = 10;
        DragAlpha = 0.12;

        -- How far dragging trails the cursor, as a time constant in seconds.
        -- Higher is looser; 0 pins the frame to the cursor exactly.
        DragSmoothing = 0.055;
    };

    DragBlur = nil;
    MenuOpen = false;
};

Library._ActiveTweens = setmetatable({}, { __mode = 'k' });

function Library:Tween(Instance, Properties, Duration, Style, Direction)
    Duration = Duration or 0.15;
    Style = Style or Enum.EasingStyle.Quart;
    Direction = Direction or Enum.EasingDirection.Out;

    local Active = Library._ActiveTweens[Instance];
    if Active then
        for Prop, Tween in next, Active do
            if Properties[Prop] ~= nil then
                Tween:Cancel();
                Active[Prop] = nil;
            end;
        end;
    else
        Active = {};
        Library._ActiveTweens[Instance] = Active;
    end;

    if Duration <= 0 then
        for Prop, Value in next, Properties do
            Instance[Prop] = Value;
        end;
        return nil;
    end;

    local Info = TweenInfo.new(Duration, Style, Direction);
    local Tween = TweenService:Create(Instance, Info, Properties);
    for Prop in next, Properties do
        Active[Prop] = Tween;
    end;
    Tween:Play();
    return Tween;
end;

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

Library.CornerRadius = 12;

-- Corner radii in pixels, kept in one place so the whole menu rounds together
-- instead of drifting between hardcoded values at each call site. UICorner clamps
-- to half the shorter side, so anything at or past half a control's height simply
-- renders as a full pill rather than overflowing.
Library.Radius = {
    -- Thin bars: dividers and the sliding tab accents. Deliberately larger than
    -- any bar is tall, because UICorner clamps to half the shorter side, so this
    -- always lands on a true stadium instead of a barely-rounded rectangle.
    Pill = 8;
    Small = 8;      -- inner fills, hue bar, colour swatches
    Control = 10;   -- toggles, sliders, textboxes, dropdowns, tooltips
    Panel = 14;     -- window, groupboxes, colour picker, watermark
};

function Library:AddCorner(Parent, Radius)
    local Corner = Parent:FindFirstChildOfClass('UICorner');
    if Corner then
        Corner.CornerRadius = UDim.new(0, Radius or Library.CornerRadius);
        return Corner;
    end;

    return Library:Create('UICorner', {
        CornerRadius = UDim.new(0, Radius or Library.CornerRadius);
        Parent = Parent;
    });
end;

function Library:AddShadow(Parent, Radius)
    local Existing = Parent:FindFirstChild('WindowBackdrop');
    if Existing then
        return Existing;
    end;

    local Shadow = Library:Create('ImageLabel', {
        Name = 'WindowBackdrop';
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0.5, 2);
        Size = UDim2.new(1, 12, 1, 12);
        Image = 'rbxassetid://6014261993';
        ImageColor3 = Color3.new(0, 0, 0);
        ImageTransparency = 0.58;
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(49, 49, 450, 450);
        ZIndex = math.max((Parent.ZIndex or 1) - 1, 0);
        Parent = Parent;
    });

    return Shadow;
end;

-- Top accent that curves with the rounded corners (rim + cover).
function Library:AddAccentBar(Parent, Radius, ZIndex)
    Radius = Radius or Library.CornerRadius;
    ZIndex = ZIndex or 2;
    local Thickness = 2;

    local Old = Parent:FindFirstChild('AccentRim');
    if Old then
        Old:Destroy();
    end;
    local OldHolder = Parent:FindFirstChild('AccentHolder');
    if OldHolder then
        OldHolder:Destroy();
    end;

    local BgKey = 'BackgroundColor';
    local ParentReg = Library.RegistryMap[Parent];
    if ParentReg and ParentReg.Properties and ParentReg.Properties.BackgroundColor3 then
        BgKey = ParentReg.Properties.BackgroundColor3;
    elseif Parent.BackgroundColor3 == Library.MainColor then
        BgKey = 'MainColor';
    end;

    local Rim = Library:Create('Frame', {
        Name = 'AccentRim';
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.fromScale(1, 1);
        Active = false;
        ZIndex = ZIndex;
        Parent = Parent;
    });

    pcall(function()
        Rim.Interactable = false;
    end);

    Library:AddCorner(Rim, Radius);

    Library:AddToRegistry(Rim, {
        BackgroundColor3 = 'AccentColor';
    });

    local Cover = Library:Create('Frame', {
        Name = 'AccentCover';
        BackgroundColor3 = Library[BgKey] or Parent.BackgroundColor3;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, Thickness);
        Size = UDim2.new(1, 0, 1, -Thickness);
        Active = false;
        ZIndex = ZIndex;
        Parent = Rim;
    });

    pcall(function()
        Cover.Interactable = false;
    end);

    Library:AddCorner(Cover, Radius);

    Library:AddToRegistry(Cover, {
        BackgroundColor3 = BgKey;
    });

    return Rim;
end;

-- Rounded shell + outline. Soft feather stroke kept subtle.
function Library:ApplyRound(Parent, Radius, StrokeColorKey, WithShadow)
    Radius = Radius or Library.CornerRadius;
    Parent.BorderSizePixel = 0;

    Library:AddCorner(Parent, Radius);

    local Junk = Parent:FindFirstChild('DropShadow');
    if Junk then
        Junk:Destroy();
    end;

    local Soft = Parent:FindFirstChild('RoundSoft');
    if Soft then
        Soft:Destroy();
    end;

    if StrokeColorKey == false then
        local Old = Parent:FindFirstChild('RoundStroke');
        if Old then
            Old:Destroy();
        end;
        return nil;
    end;

    local ColorName = StrokeColorKey or 'OutlineColor';
    local Stroke = Parent:FindFirstChild('RoundStroke');

    if not Stroke then
        Stroke = Library:Create('UIStroke', {
            Name = 'RoundStroke';
            Color = Library[ColorName] or Library.OutlineColor;
            Thickness = 1;
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
            LineJoinMode = Enum.LineJoinMode.Round;
            Parent = Parent;
        });
    else
        Stroke.Color = Library[ColorName] or Library.OutlineColor;
        Stroke.Thickness = 1;
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Stroke.LineJoinMode = Enum.LineJoinMode.Round;
    end;

    Library:AddToRegistry(Stroke, {
        Color = ColorName;
    });

    return Stroke;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:EnsureDragBlur()
    if Library.DragBlur and Library.DragBlur.Parent then
        return Library.DragBlur;
    end;

    local Blur = Instance.new('BlurEffect');
    Blur.Name = 'LinoriaMenuBlur';
    Blur.Size = 0;
    Blur.Enabled = false;
    pcall(function()
        Blur.Parent = game:GetService('Lighting');
    end);

    Library.DragBlur = Blur;
    return Blur;
end;

function Library:SetMenuBlur(Enabled)
    local Blur = Library:EnsureDragBlur();
    local Size = Library.Anim.MenuBlurSize or Library.Anim.DragBlurSize or 16;

    if Enabled then
        Blur.Enabled = true;
        Library:Tween(Blur, { Size = Size }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
    else
        local Tween = Library:Tween(Blur, { Size = 0 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
        if Tween then
            Tween.Completed:Connect(function()
                if not Library.MenuOpen and Blur.Size < 0.5 then
                    Blur.Enabled = false;
                end;
            end);
        elseif not Library.MenuOpen then
            Blur.Enabled = false;
        end;
    end;
end;

-- Slight transparency while dragging.
function Library:SetDragVisual(Instance, Enabled)
    local Ghost = 0.28;

    if Instance:IsA('CanvasGroup') then
        Library:Tween(Instance, {
            GroupTransparency = Enabled and Ghost or 0;
        }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
    else
        Library:Tween(Instance, {
            BackgroundTransparency = Enabled and (Ghost * 0.45) or 0;
        }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
    end;
end;

-- Drag using a hit target. Grab offset is from the frame top-left so anchor point cannot desync the cursor.
function Library:MakeDraggable(Instance, Cutoff, GhostWhileDrag, Handle)
    local Hit = Handle or Instance;
    Hit.Active = true;
    Instance.Active = true;

    -- The coast-to-a-stop tween from the previous drag, if it is still running.
    local SettleTween;

    Hit.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return;
        end;

        if not Instance.Visible or not Instance.Parent then
            return;
        end;

        if Cutoff then
            local RelY = Input.Position.Y - Instance.AbsolutePosition.Y;
            if RelY > Cutoff then
                return;
            end;
        end;

        -- Grabbing again mid-coast would leave the tween writing Position on the
        -- same frames as the drag does, so stop it before reading the start point.
        if SettleTween then
            SettleTween:Cancel();
            SettleTween = nil;
        end;

        local StartPos = Instance.Position;
        local DragStart = Input.Position;
        local Dragging = true;
        local MoveConn;
        local EndConn;
        local StepConn;

        -- Where the cursor says the frame should be. The frame eases toward this
        -- rather than snapping to it, so dragging trails slightly behind.
        local Target = StartPos;

        if GhostWhileDrag then
            Library:SetDragVisual(Instance, true);
        end;

        MoveConn = InputService.InputChanged:Connect(function(Change)
            if not Dragging or Change.UserInputType ~= Enum.UserInputType.MouseMovement then
                return;
            end;

            local Delta = Change.Position - DragStart;
            Target = UDim2.new(
                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
            );

            if Library.Anim.DragSmoothing <= 0 then
                Instance.Position = Target;
            end;
        end);

        if Library.Anim.DragSmoothing > 0 then
            StepConn = RenderStepped:Connect(function(Delta)
                if not Dragging then
                    return;
                end;

                -- Exponential ease, so the trail feels the same at any framerate
                -- instead of getting snappier as FPS rises.
                local Alpha = 1 - math.exp(-Delta / Library.Anim.DragSmoothing);

                Instance.Position = Instance.Position:Lerp(Target, math.clamp(Alpha, 0, 1));
            end);
        end;

        local function StopDrag()
            if not Dragging then
                return;
            end;

            Dragging = false;

            if MoveConn then
                MoveConn:Disconnect();
                MoveConn = nil;
            end;

            if EndConn then
                EndConn:Disconnect();
                EndConn = nil;
            end;

            if StepConn then
                StepConn:Disconnect();
                StepConn = nil;

                -- Let it coast the last few pixels instead of snapping on release.
                SettleTween = Library:Tween(Instance, { Position = Target }, Library.Anim.DragSmoothing * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            end;

            if GhostWhileDrag then
                Library:SetDragVisual(Instance, false);
            end;
        end;

        EndConn = InputService.InputEnded:Connect(function(Ended)
            if Ended.UserInputType == Enum.UserInputType.MouseButton1 then
                StopDrag();
            end;
        end);
    end);
end;

function Library:MakeResizable(Instance, MinSize, MaxSize)
    MinSize = MinSize or Vector2.new(420, 320);
    MaxSize = MaxSize or Vector2.new(1200, 900);

    local Grip = Library:Create('TextButton', {
        Name = 'ResizeGrip';
        Text = '';
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(16, 16);
        Position = UDim2.new(1, -6, 1, -6);
        AnchorPoint = Vector2.new(1, 1);
        ZIndex = 50;
        Parent = Instance;
    });

    -- Three soft rounded dots along the corner diagonal (matches rounded chrome).
    local GripDots = {};
    local DotLayout = {
        { X = 10, Y = 10 },
        { X = 6, Y = 10 },
        { X = 10, Y = 6 },
    };

    for _, Offset in next, DotLayout do
        local Dot = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(Offset.X, Offset.Y);
            Size = UDim2.fromOffset(4, 4);
            ZIndex = 51;
            Parent = Grip;
        });

        Library:AddCorner(Dot, 2);
        Library:AddToRegistry(Dot, {
            BackgroundColor3 = 'OutlineColor';
        });

        table.insert(GripDots, Dot);
    end;

    Grip.MouseEnter:Connect(function()
        for _, Dot in next, GripDots do
            Library:Tween(Dot, { BackgroundColor3 = Library.AccentColor }, Library.Anim.Hover);
            local Reg = Library.RegistryMap[Dot];
            if Reg then
                Reg.Properties.BackgroundColor3 = 'AccentColor';
            end;
        end;
    end);

    Grip.MouseLeave:Connect(function()
        for _, Dot in next, GripDots do
            Library:Tween(Dot, { BackgroundColor3 = Library.OutlineColor }, Library.Anim.Hover);
            local Reg = Library.RegistryMap[Dot];
            if Reg then
                Reg.Properties.BackgroundColor3 = 'OutlineColor';
            end;
        end;
    end);

    Grip.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return;
        end;

        local StartSize = Instance.Size;
        local DragStart = Input.Position;
        local ChangedConn;
        local EndedConn;

        ChangedConn = InputService.InputChanged:Connect(function(Change)
            if Change.UserInputType ~= Enum.UserInputType.MouseMovement then
                return;
            end;

            local Delta = Change.Position - DragStart;
            local NewW = math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X);
            local NewH = math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y);

            Instance.Size = UDim2.new(StartSize.X.Scale, NewW, StartSize.Y.Scale, NewH);
        end);

        local function StopResize()
            if ChangedConn then
                ChangedConn:Disconnect();
                ChangedConn = nil;
            end;

            if EndedConn then
                EndedConn:Disconnect();
                EndedConn = nil;
            end;
        end;

        EndedConn = InputService.InputEnded:Connect(function(Ended)
            if Ended.UserInputType == Enum.UserInputType.MouseButton1 then
                StopResize();
            end;
        end);
    end);

    return Grip;
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    Library:ApplyRound(Tooltip, Library.Radius.Control, 'OutlineColor');

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Library:GetMouse().X + 15, Library:GetMouse().Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Library:GetMouse().X + 15, Library:GetMouse().Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

-- Recolour a rounded element's outline. ApplyRound draws outlines with a UIStroke
-- rather than BorderColor3, so this also keeps the theme registry in step, or a
-- later theme change would snap the stroke back to its build-time colour.
function Library:SetStrokeColor(Stroke, ColorIdx)
    if not Stroke then
        return;
    end;

    Library:Tween(Stroke, { Color = Library[ColorIdx] or ColorIdx }, Library.Anim.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

    local StrokeReg = Library.RegistryMap[Stroke];

    if StrokeReg and StrokeReg.Properties.Color then
        StrokeReg.Properties.Color = ColorIdx;
    end;
end;

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    local function ApplyProps(Props)
        local Reg = Library.RegistryMap[Instance];
        local Stroke = Instance:FindFirstChildOfClass('UIStroke');
        local Goals = {};

        for Property, ColorIdx in next, Props do
            local Color = Library[ColorIdx] or ColorIdx;

            if Property == 'BorderColor3' and Stroke then
                Library:SetStrokeColor(Stroke, ColorIdx);
            else
                Goals[Property] = Color;

                if Reg and Reg.Properties[Property] then
                    Reg.Properties[Property] = ColorIdx;
                end;
            end;
        end;

        if next(Goals) then
            Library:Tween(Instance, Goals, Library.Anim.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
        end;
    end;

    HighlightInstance.MouseEnter:Connect(function()
        if Instance:GetAttribute('Pressed') then
            return;
        end;
        ApplyProps(Properties);
    end)

    HighlightInstance.MouseLeave:Connect(function()
        if Instance:GetAttribute('Pressed') then
            return;
        end;
        ApplyProps(PropertiesDefault);
    end)
end;

function Library:GetMouse()
    return Vector2.new(Mouse.X, Mouse.Y);
end;

-- Dropdown lists live on the ScreenGui rather than inside the window, so nothing
-- closes them implicitly. Anything that hides or replaces the window has to.
-- Pass Instant when whatever is closing them is about to disappear anyway, so a
-- shell does not linger on screen after the window behind it has gone.
function Library:CloseAllDropdowns(Except, Instant)
    for Dropdown in next, Library.OpenedDropdowns do
        if Dropdown ~= Except then
            Dropdown:CloseDropdown(Instant);
        end;
    end;
end;

function Library:MouseIsOverOpenedFrame()
    local MousePos = Library:GetMouse();

    for Frame, _ in next, Library.OpenedFrames do
        if Frame.Parent and Frame.Visible then
            local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

            if MousePos.X >= AbsPos.X and MousePos.X <= AbsPos.X + AbsSize.X
                and MousePos.Y >= AbsPos.Y and MousePos.Y <= AbsPos.Y + AbsSize.Y then
                return true;
            end;
        end;
    end;

    return false;
end;

function Library:IsMouseOverFrame(Frame)
    if not Frame or not Frame.Parent then
        return false;
    end;

    local MousePos = Library:GetMouse();
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    return MousePos.X >= AbsPos.X and MousePos.X <= AbsPos.X + AbsSize.X
        and MousePos.Y >= AbsPos.Y and MousePos.Y <= AbsPos.Y + AbsSize.Y;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Data = Library.RegistryMap[Instance];

    -- ApplyRound can run more than once over the same element, which used to file
    -- a second entry for the same stroke. Only the newest was ever reachable
    -- through RegistryMap, so the older one lingered and kept getting themed.
    if Data then
        for Property, ColorIdx in next, Properties do
            Data.Properties[Property] = ColorIdx;
        end;
    else
        local Idx = #Library.Registry + 1;

        Data = {
            Instance = Instance;
            Properties = Properties;
            Idx = Idx;
        };

        Library.Registry[Idx] = Data;
        Library.RegistryMap[Instance] = Data;
    end;

    if IsHud and not Data.HudIdx then
        local HudIdx = #Library.HudRegistry + 1;

        Data.HudIdx = HudIdx;
        Library.HudRegistry[HudIdx] = Data;
    end;
end;

-- Order in the registry does not matter, so drop an entry by moving the last one
-- into its slot. Idx and HudIdx track where each entry currently lives.
local function SwapRemoveEntry(List, Data, Field)
    local Idx = Data[Field];

    if not Idx then
        return;
    end;

    if List[Idx] ~= Data then
        -- Should not happen, but never leave a dead instance behind: fall back to
        -- the exhaustive scan rather than silently keeping it.
        for Scan = #List, 1, -1 do
            if List[Scan] == Data then
                Idx = Scan;
                break;
            end;
        end;

        if List[Idx] ~= Data then
            Data[Field] = nil;
            return;
        end;
    end;

    local Last = #List;
    local Moved = List[Last];

    List[Idx] = Moved;
    List[Last] = nil;

    if Moved and Moved ~= Data then
        Moved[Field] = Idx;
    end;

    Data[Field] = nil;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        -- This runs from DescendantRemoving, so it fires once per destroyed
        -- instance. Scanning the whole registry each time meant rebuilding one
        -- long dropdown walked thousands of entries per item.
        SwapRemoveEntry(Library.Registry, Data, 'Idx');
        SwapRemoveEntry(Library.HudRegistry, Data, 'HudIdx');

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    Library.MenuOpen = false;

    Library:CloseAllDropdowns(nil, true);
    table.clear(Library.OpenedDropdowns);
    table.clear(Library.OpenedFrames);

    if Library.DragBlur then
        pcall(function()
            Library.DragBlur.Enabled = false;
            Library.DragBlur.Size = 0;
            Library.DragBlur:Destroy();
        end);
        Library.DragBlur = nil;
    end;

    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

     -- Call our unload callback, maybe to undo some hooks etc
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

-- One dispatcher for every dropdown rather than a global input connection per
-- dropdown. Only open dropdowns are in the table, and opening one closes the
-- rest, so these loops run over at most a single entry.
Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return;
    end;

    if not next(Library.OpenedDropdowns) then
        return;
    end;

    local MousePos = Library:GetMouse();

    for Dropdown in next, Library.OpenedDropdowns do
        -- While open the list panel spans its own trigger, so one rect covers
        -- both and this stays correct when the list opens upwards.
        if not Dropdown:PointInside(MousePos) then
            Dropdown:CloseDropdown();
        end;
    end;
end))

Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return;
    end;

    for Dropdown in next, Library.OpenedDropdowns do
        Dropdown:UpdateHover();
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        Library:ApplyRound(DisplayFrame, Library.Radius.Small, false, false);

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        Library:AddCorner(CheckerFrame, Library.Radius.Small);

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(234, Info.Transparency and 275 or 257);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        Library:ApplyRound(PickerFrameOuter, Library.Radius.Panel, 'OutlineColor');
        Library:AddShadow(PickerFrameOuter, Library.Radius.Panel);

        Library:AddToRegistry(PickerFrameOuter, {
            BackgroundColor3 = 'MainColor';
        });

        Library:AddAccentBar(PickerFrameOuter, Library.Radius.Panel, 16);

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, -16, 0, 14);
            Position = UDim2.fromOffset(10, 8);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title;
            TextWrapped = false;
            ZIndex = 18;
            Parent = PickerFrameOuter;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Position = UDim2.new(0, 8, 0, 28);
            Size = UDim2.new(0, 196, 0, 196);
            ZIndex = 18;
            Parent = PickerFrameOuter;
        });

        Library:ApplyRound(SatVibMapOuter, Library.Radius.Control, 'OutlineColor');

        Library:AddToRegistry(SatVibMapOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 19;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapOuter;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 21;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 22;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Position = UDim2.new(0, 212, 0, 28);
            Size = UDim2.new(0, 14, 0, 196);
            ZIndex = 18;
            Parent = PickerFrameOuter;
        });

        Library:ApplyRound(HueSelectorOuter, Library.Radius.Small, 'OutlineColor');

        Library:AddToRegistry(HueSelectorOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 19;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 4, 0, 2);
            ZIndex = 20;
            Parent = HueSelectorInner;
        });

        Library:Create('UIStroke', {
            Color = Library.OutlineColor;
            Thickness = 1;
            Parent = HueCursor;
        });

        local function CreatePickerField(Position, Size)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderSizePixel = 0;
                Position = Position;
                Size = Size;
                ZIndex = 18;
                Parent = PickerFrameOuter;
            });

            Library:ApplyRound(Outer, Library.Radius.Control, 'OutlineColor');

            Library:AddToRegistry(Outer, {
                BackgroundColor3 = 'MainColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'OutlineColor' }
            );

            local Inner = Library:Create('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = Outer;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            return Outer, Inner;
        end;

        local HueBoxOuter, HueBoxInner = CreatePickerField(
            UDim2.fromOffset(8, 232),
            UDim2.new(0.5, -12, 0, 22)
        );

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -8, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxOuter, RgbBoxInner = CreatePickerField(
            UDim2.new(0.5, 4, 0, 232),
            UDim2.new(0.5, -12, 0, 22)
        );

        local RgbBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -8, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'RGB color',
            Text = '255, 255, 255',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = RgbBoxInner;
        });

        Library:ApplyTextStroke(RgbBox);

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel = 0;
                ClipsDescendants = true;
                Position = UDim2.fromOffset(8, 258);
                Size = UDim2.new(1, -16, 0, 16);
                ZIndex = 18;
                Parent = PickerFrameOuter;
            });

            Library:ApplyRound(TransparencyBoxOuter, Library.Radius.Control, 'OutlineColor');

            Library:AddToRegistry(TransparencyBoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderSizePixel = 0;
                Size = UDim2.new(0, 2, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });

            Library:Create('UIStroke', {
                Color = Library.OutlineColor;
                Thickness = 1;
                Parent = TransparencyCursor;
            });
        end;

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderSizePixel = 0;
                ZIndex = 14;
                Visible = false;
                Parent = ScreenGui;
            });

            Library:ApplyRound(ContextMenu.Container, Library.Radius.Control, 'OutlineColor');

            Library:AddToRegistry(ContextMenu.Container, {
                BackgroundColor3 = 'MainColor';
            });

            Library:AddAccentBar(ContextMenu.Container, Library.Radius.Control, 15);

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 16;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
                Library.OpenedFrames[self.Container] = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
                Library.OpenedFrames[self.Container] = nil
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = true;
                    Size = UDim2.new(1, 0, 0, 16);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 17;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(HueBoxOuter, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(RgbBoxOuter, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Frame:SetAttribute('Closing', false);
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter:SetAttribute('Closing', false);
            PickerFrameOuter:SetAttribute('HideToken', (PickerFrameOuter:GetAttribute('HideToken') or 0) + 1);
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;

            local Scale = PickerFrameOuter:FindFirstChildOfClass('UIScale');
            if not Scale then
                Scale = Library:Create('UIScale', {
                    Scale = 0.92;
                    Parent = PickerFrameOuter;
                });
            else
                Scale.Scale = 0.92;
            end;

            Library:Tween(Scale, { Scale = 1 }, Library.Anim.ColorPicker, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
        end;

        function ColorPicker:Hide()
            local Scale = PickerFrameOuter:FindFirstChildOfClass('UIScale');
            local Token = (PickerFrameOuter:GetAttribute('HideToken') or 0) + 1;
            PickerFrameOuter:SetAttribute('HideToken', Token);
            PickerFrameOuter:SetAttribute('Closing', true);

            if Scale then
                Library:Tween(Scale, { Scale = 0.92 }, Library.Anim.ColorPicker * 0.75);
            end;

            task.delay(Library.Anim.ColorPicker * 0.75, function()
                if PickerFrameOuter:GetAttribute('HideToken') == Token and PickerFrameOuter:GetAttribute('Closing') then
                    PickerFrameOuter.Visible = false;
                    PickerFrameOuter:SetAttribute('Closing', false);
                    Library.OpenedFrames[PickerFrameOuter] = nil;
                end;
            end);
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        Library:ApplyRound(PickOuter, Library.Radius.Control, 'OutlineColor');

        local PickInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeSelectOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.fromOffset(60, (#Modes * 15) + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        Library:ApplyRound(ModeSelectOuter, Library.Radius.Small, 'OutlineColor');

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = true;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
                Library.OpenedFrames[ModeSelectOuter] = nil;
            end;

            function ModeButton:Deselect()
                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' or not KeyPicker.Value then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    local KeyCode = Enum.KeyCode[Key];
                    return KeyCode and InputService:IsKeyDown(KeyCode) or false;
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            local ModeButton = ModeButtons[Mode] or ModeButtons[KeyPicker.Mode] or ModeButtons['Toggle'] or ModeButtons[Modes[1]];
            if ModeButton then
                ModeButton:Select();
            else
                KeyPicker.Mode = Mode or KeyPicker.Mode or 'Toggle';
            end;
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;
        local PickConnection;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if Picking then
                    return;
                end;

                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                if PickConnection then
                    PickConnection:Disconnect();
                    PickConnection = nil;
                end;

                PickConnection = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    else
                        return;
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    if PickConnection then
                        PickConnection:Disconnect();
                        PickConnection = nil;
                    end;
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
                Library.OpenedFrames[ModeSelectOuter] = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard and Key then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if ModeSelectOuter.Visible and not Library:IsMouseOverFrame(ModeSelectOuter) and not Library:IsMouseOverFrame(PickOuter) then
                    ModeSelectOuter.Visible = false;
                    Library.OpenedFrames[ModeSelectOuter] = nil;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderSizePixel = 0;
                ClipsDescendants = true;
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            Library:ApplyRound(Outer, Library.Radius.Control, 'OutlineColor');

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, -8, 1, 0);
                Position = UDim2.fromOffset(4, 0);
                TextSize = 14;
                Text = Button.Text;
                TextTruncate = Enum.TextTruncate.AtEnd;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Outer;
            });

            Library:AddToRegistry(Outer, {
                BackgroundColor3 = 'MainColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor', BackgroundColor3 = 'BackgroundColor' },
                { BorderColor3 = 'OutlineColor', BackgroundColor3 = 'MainColor' }
            );

            local function AccentPressColor()
                return Library.MainColor:Lerp(Library.AccentColor, 0.38);
            end;

            Outer.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Outer:SetAttribute('Pressed', true);
                    Library:Tween(Outer, { BackgroundColor3 = AccentPressColor() }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
                end;
            end);

            Outer.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Outer:SetAttribute('Pressed', false);
                    local Hovering = Library:IsMouseOverFrame(Outer);

                    Library:Tween(Outer, {
                        BackgroundColor3 = Hovering and Library.BackgroundColor or Library.MainColor;
                    }, Library.Anim.Button, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

                    if Library.RegistryMap[Outer] then
                        Library.RegistryMap[Outer].Properties.BackgroundColor3 = Hovering and 'BackgroundColor' or 'MainColor';
                    end;
                end;
            end);

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            -- Scale-relative sizing avoids AbsoluteSize race that made side buttons overlap text.
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 4, 0, 0)
            SubButton.Outer.Size = UDim2.new(1, 0, 1, 0)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerLine = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -8, 0, 2);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddCorner(DividerLine, Library.Radius.Pill);

        Library:AddToRegistry(DividerLine, {
            BackgroundColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:ApplyRound(TextBoxOuter, Library.Radius.Control, 'OutlineColor');

        local TextBoxInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxOuter, {
            BackgroundColor3 = 'MainColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'OutlineColor' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        local ToggleStroke = Library:ApplyRound(ToggleOuter, Library.Radius.Control, 'OutlineColor');

        Library:AddToRegistry(ToggleOuter, {
            BackgroundColor3 = 'MainColor';
        });

        local ToggleInner = ToggleOuter;

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 200, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'OutlineColor' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            Library:Tween(ToggleOuter, {
                BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            }, Library.Anim.Toggle, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

            if ToggleStroke then
                Library:Tween(ToggleStroke, {
                    Color = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;
                }, Library.Anim.Toggle);

                Library.RegistryMap[ToggleStroke].Properties.Color = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
            end;

            Library.RegistryMap[ToggleOuter].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:ApplyRound(SliderOuter, Library.Radius.Control, 'OutlineColor');

        Library:AddToRegistry(SliderOuter, {
            BackgroundColor3 = 'MainColor';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddCorner(SliderInner, Library.Radius.Small);

        local function SyncMaxSize()
            local Width = math.max(SliderInner.AbsoluteSize.X, 1);
            if Width ~= Slider.MaxSize then
                Slider.MaxSize = Width;
            end;
        end;

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddCorner(Fill, Library.Radius.Small);

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 0, 0);
            Visible = false;
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'OutlineColor' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
        end;

        function Slider:Display(Mode)
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            local Goal = UDim2.new(0, X, 1, 0);

            if Mode == true then
                Fill.Size = Goal;
            elseif Mode == 'drag' then
                Library:Tween(Fill, { Size = Goal }, Library.Anim.SliderDrag, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
            else
                Library:Tween(Fill, { Size = Goal }, Library.Anim.Slider, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
            end;
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SyncMaxSize();
        SliderInner:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
            SyncMaxSize();
            Slider:Display(true);
        end);

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                SyncMaxSize();
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display('drag');

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Slider:Display();
                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Text = '';
            AutoButtonColor = false;
            Parent = Container;
        });

        local DropdownStroke = Library:ApplyRound(DropdownOuter, Library.Radius.Control, 'OutlineColor');

        Library:AddToRegistry(DropdownOuter, {
            BackgroundColor3 = 'MainColor';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownOuter;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -20, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'OutlineColor' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;
        local DROPDOWN_RADIUS = Library.Radius.Control;

        -- Item rows are square and full width. Butted straight against the far
        -- edge they sit inside the shell's corner arc, and their fill eats into
        -- the outline there, which shows up as chipped corners on the accent.
        -- This margin keeps the rows clear of the curve.
        local LIST_INSET = 4;

        local DropdownListHeight = MAX_DROPDOWN_ITEMS * 20 + LIST_INSET;
        local Scrolling;
        local Seam;

        -- The list is parented to the ScreenGui, not the window, so under Global
        -- ZIndexBehavior it competes with every control it floats over (groupbox
        -- contents run 5-10). It has to sit above all of that, and the trigger has
        -- to sit above the list, because while open the panel spans the trigger
        -- and supplies the fill and outline for both.
        local LIST_Z = 24;
        local TRIGGER_Z_OPEN = 28;
        local TriggerZ = {
            [DropdownOuter] = DropdownOuter.ZIndex;
            [DropdownInner] = DropdownInner.ZIndex;
            [ItemList] = ItemList.ZIndex;
            [DropdownArrow] = DropdownArrow.ZIndex;
        };

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            ZIndex = LIST_Z;
            Visible = false;
            Parent = ScreenGui;
        });

        local ListStroke = Library:ApplyRound(ListOuter, DROPDOWN_RADIUS, 'OutlineColor');
        Library:AddToRegistry(ListOuter, {
            BackgroundColor3 = 'MainColor';
        });

        -- Whether the cursor is over the open shell. The trigger's own OnHighlight
        -- cannot answer this: its stroke is hidden while open, and the shell it
        -- would have to track is a different instance that the trigger overlaps.
        local Hovered = false;

        -- Logical open state. Distinct from ListOuter.Visible, which stays true
        -- through the closing animation; a click landing in that window has to
        -- reopen rather than close again.
        local Open = false;

        local function SetTriggerRaised(Raised)
            for Inst, Base in next, TriggerZ do
                Inst.ZIndex = Raised and (TRIGGER_Z_OPEN + (Base - 5)) or Base;
            end;

            -- While open the list panel is drawn behind the trigger and spans it,
            -- so the trigger drops its own fill and outline. Its label and arrow
            -- keep drawing on top and the two read as a single rounded shape.
            DropdownOuter.BackgroundTransparency = Raised and 1 or 0;

            if DropdownStroke then
                DropdownStroke.Transparency = Raised and 1 or 0;
            end;

            if not Raised then
                Hovered = false;
                Library:SetStrokeColor(ListStroke, 'OutlineColor');
            end;
        end;

        -- true when the list had to open upwards because it would not fit below.
        local Flipped = false;

        local function TriggerHeight()
            local H = math.floor(DropdownOuter.AbsoluteSize.Y + 0.5);

            return H > 0 and H or DropdownOuter.Size.Y.Offset;
        end;

        -- 0 while shut, 1 while fully open. The shell is always drawn at the
        -- trigger's size plus this much of the list, so animating it slides the
        -- panel out from behind the trigger and the clip reveals the rows.
        local Openness = 0;

        -- Rounded, so the growing edge lands on whole pixels rather than shimmering
        -- along a fractional boundary.
        local function GrownHeight()
            return math.floor((DropdownListHeight * Openness) + 0.5);
        end;

        local function RecalculateListPosition()
            local X = math.floor(DropdownOuter.AbsolutePosition.X + 0.5);
            local Top = math.floor(DropdownOuter.AbsolutePosition.Y + 0.5);

            local Viewport = ScreenGui.AbsoluteSize;

            -- The panel wraps the trigger rather than sitting under it, so its top
            -- edge is the trigger's top edge (or the list's, when flipped up).
            local Y = Flipped and (Top - GrownHeight()) or Top;

            -- Keep the panel on screen horizontally as well; a groupbox near the
            -- right edge would otherwise push it off. Width comes from the trigger
            -- rather than ListOuter.AbsoluteSize, which lags a layout pass behind
            -- when this runs straight after a resize.
            local Width = math.floor(DropdownOuter.AbsoluteSize.X + 0.5);

            if Viewport.X > 0 then
                X = math.clamp(X, 0, math.max(0, Viewport.X - Width));
            end;

            ListOuter.Position = UDim2.fromOffset(X, Y);
        end;

        -- Decide whether there is room below the trigger before positioning.
        local function RecalculateListDirection()
            local Viewport = ScreenGui.AbsoluteSize;

            if Viewport.Y <= 0 then
                Flipped = false;
                return;
            end;

            local Top = DropdownOuter.AbsolutePosition.Y;
            local Bottom = Top + DropdownOuter.AbsoluteSize.Y;

            local FitsBelow = (Bottom + DropdownListHeight) <= Viewport.Y;
            local FitsAbove = (Top - DropdownListHeight) >= 0;

            Flipped = (not FitsBelow) and FitsAbove;
        end;

        local function RecalculateListSize(YSize)
            if YSize then
                DropdownListHeight = YSize;
            end;

            local Head = TriggerHeight();

            -- One rounded shell around trigger + items, so there is a single
            -- outline and no seam between two stacked boxes.
            ListOuter.Size = UDim2.fromOffset(
                math.floor(DropdownOuter.AbsoluteSize.X + 0.5),
                GrownHeight() + Head
            );

            if Scrolling then
                -- Anchored to the trigger's edge, with a fixed offset height, so
                -- the rows hold still while the shell grows past them instead of
                -- stretching with it. The inset always lands on the end away from
                -- the trigger, which is the end with the rounded corners.
                local Items = math.max(DropdownListHeight - LIST_INSET, 0);

                Scrolling.Size = UDim2.new(1, 0, 0, Items);
                Scrolling.Position = Flipped
                    and UDim2.new(0, 0, 1, -(Head + Items))
                    or UDim2.new(0, 0, 0, Head);
            end;

            if Seam then
                Seam.Position = Flipped
                    and UDim2.new(0, 4, 1, -(Head + 2))
                    or UDim2.new(0, 4, 0, Head - 2);
            end;

            RecalculateListPosition();
        end;

        local OpenAnim;

        local function StopOpenAnim()
            if OpenAnim then
                OpenAnim:Disconnect();
                OpenAnim = nil;
            end;
        end;

        -- Openness is a plain number rather than an instance property, so it is
        -- stepped by hand instead of going through TweenService. Reopening
        -- mid-close picks up from wherever it got to.
        local function AnimateOpenness(Goal, Duration, OnDone)
            StopOpenAnim();

            if not Duration or Duration <= 0 then
                Openness = Goal;
                RecalculateListSize();

                if OnDone then
                    OnDone();
                end;

                return;
            end;

            local Start = Openness;
            local Elapsed = 0;

            OpenAnim = RenderStepped:Connect(function(Delta)
                -- Unloading destroys the ScreenGui; do not keep stepping geometry
                -- on instances that no longer exist.
                if not ListOuter.Parent then
                    StopOpenAnim();
                    return;
                end;

                Elapsed = Elapsed + Delta;

                local T = math.clamp(Elapsed / Duration, 0, 1);
                local Eased = 1 - ((1 - T) * (1 - T)); -- quad out, as elsewhere

                Openness = Start + ((Goal - Start) * Eased);
                RecalculateListSize();

                if T >= 1 then
                    StopOpenAnim();

                    if OnDone then
                        OnDone();
                    end;
                end;
            end);
        end;

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);
        DropdownOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
            RecalculateListSize();
        end);

        -- Groupbox columns scroll. The list is not a descendant of that column, so
        -- it is never clipped and would trail the trigger right out of the window.
        local ScrollHost = DropdownOuter:FindFirstAncestorWhichIsA('ScrollingFrame');

        if ScrollHost then
            ScrollHost:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
                if Open then
                    Dropdown:CloseDropdown(true);
                end;
            end);
        end;

        local ListInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = LIST_Z;
            Parent = ListOuter;
        });

        Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = LIST_Z;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        -- Trigger and items now share one shell, so mark where one ends and the
        -- other begins with the same pill divider the groupboxes use.
        Seam = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 4, 0, 18);
            Size = UDim2.new(1, -8, 0, 2);
            ZIndex = LIST_Z + 3;
            Parent = ListInner;
        });

        Library:AddCorner(Seam, Library.Radius.Pill);

        Library:AddToRegistry(Seam, {
            BackgroundColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        RecalculateListSize();

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        local function GetActiveCount()
            local Active = Dropdown:GetActiveValues();
            if Info.Multi then
                return #Active;
            end;
            return Active;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('TextButton', {
                    BackgroundColor3 = Library.MainColor;
                    BorderSizePixel = 0;
                    Size = UDim2.new(1, 0, 0, 20);
                    ZIndex = LIST_Z + 1;
                    Text = '';
                    AutoButtonColor = false;
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -10, 1, 0);
                    Position = UDim2.new(0, 8, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = LIST_Z + 2;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BackgroundColor3 = 'BackgroundColor' },
                    { BackgroundColor3 = 'MainColor' }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                Button.MouseButton1Click:Connect(function()
                    local Try = not Selected;

                    if GetActiveCount() == 1 and (not Try) and (not Info.AllowNull) then
                        return;
                    end;

                    if Info.Multi then
                        Selected = Try;

                        if Selected then
                            Dropdown.Value[Value] = true;
                        else
                            Dropdown.Value[Value] = nil;
                        end;
                    else
                        Selected = Try;

                        if Selected then
                            Dropdown.Value = Value;
                        else
                            Dropdown.Value = nil;
                        end;

                        for _, OtherButton in next, Buttons do
                            OtherButton:UpdateButton();
                        end;

                        Dropdown:CloseDropdown();
                    end;

                    Table:UpdateButton();
                    Dropdown:Display();

                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                    Library:AttemptSave();
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, Count * 20);

            -- Height of the shell's list half: the visible rows plus the margin
            -- that keeps them out of the rounded corners.
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + LIST_INSET;

            -- The height just changed, so whether it still fits below may have too.
            DropdownListHeight = Y;

            if Open then
                RecalculateListDirection();
            end;

            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        -- The shell spans the trigger and the items, so its rect is the whole
        -- control. Used for both the hover accent and the click-outside test.
        function Dropdown:PointInside(Pos)
            if not Open then
                return false;
            end;

            local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

            return Pos.X >= AbsPos.X and Pos.X <= AbsPos.X + AbsSize.X
                and Pos.Y >= AbsPos.Y and Pos.Y <= AbsPos.Y + AbsSize.Y;
        end;

        function Dropdown:UpdateHover()
            local Over = Dropdown:PointInside(Library:GetMouse());

            if Over ~= Hovered then
                Hovered = Over;
                Library:SetStrokeColor(ListStroke, Over and 'AccentColor' or 'OutlineColor');
            end;
        end;

        function Dropdown:OpenDropdown()
            -- Two lists open at once would overlap each other on the popup layer.
            Library:CloseAllDropdowns(Dropdown);

            Open = true;
            ListOuter.Visible = true;

            -- Direction is chosen from the full height, before the shell has
            -- grown into it, or a list would start downwards and then not fit.
            RecalculateListDirection();
            SetTriggerRaised(true);

            Library.OpenedFrames[ListOuter] = true;
            Library.OpenedDropdowns[Dropdown] = true;

            Library:Tween(DropdownArrow, { Rotation = 180 }, Library.Anim.Dropdown, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            AnimateOpenness(1, Library.Anim.Dropdown);

            -- The cursor is already on the trigger, and no mouse movement is
            -- coming to tell us that, so seed the hover state here.
            Dropdown:UpdateHover();
        end;

        function Dropdown:CloseDropdown(Instant)
            Open = false;

            Library.OpenedFrames[ListOuter] = nil;
            Library.OpenedDropdowns[Dropdown] = nil;

            -- Drop the accent now so it fades out alongside the slide.
            Hovered = false;
            Library:SetStrokeColor(ListStroke, 'OutlineColor');

            Library:Tween(DropdownArrow, { Rotation = 0 }, Instant and 0 or Library.Anim.Dropdown, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

            AnimateOpenness(0, Instant and 0 or Library.Anim.Dropdown, function()
                -- The shell covers the trigger for the whole slide, so the trigger
                -- only takes its own fill and outline back once it is gone.
                ListOuter.Visible = false;
                Flipped = false;
                SetTriggerRaised(false);
                RecalculateListSize();
            end);
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return;
            end;

            if Open then
                -- Our own list is registered as an opened frame and overlaps the
                -- trigger's bottom edge, so MouseIsOverOpenedFrame would blank out
                -- that band. A click that reaches the trigger always toggles.
                Dropdown:CloseDropdown();
            elseif not Library:MouseIsOverOpenedFrame() then
                Dropdown:OpenDropdown();
            end;
        end);

        -- Closing on an outside click is handled by the shared dispatcher next to
        -- Library:CloseAllDropdowns, which calls Dropdown:PointInside.

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        -- Clips so the contents are revealed by the height animation rather than
        -- spilling past the collapsing holder.
        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        -- Pinned to the content height instead of the holder's, so the children
        -- keep their layout while the holder slides shut around them.
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        local Expanded = false;
        local Initialized = false;
        local SizeTween;

        local function ContentHeight()
            return Layout.AbsoluteContentSize.Y;
        end;

        local function SetHeight(Duration)
            local Goal = UDim2.new(1, 0, 0, Expanded and ContentHeight() or 0);

            if SizeTween then
                SizeTween:Cancel();
                SizeTween = nil;
            end;

            if Expanded then
                Holder.Visible = true;
            end;

            if not Duration or Duration <= 0 then
                Holder.Size = Goal;
                Holder.Visible = Expanded;
                Groupbox:Resize();
                return;
            end;

            SizeTween = Library:Tween(Holder, { Size = Goal }, Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

            if not Expanded and SizeTween then
                SizeTween.Completed:Connect(function()
                    -- Guard against a re-open landing before the collapse finishes.
                    if not Expanded then
                        Holder.Visible = false;
                    end;
                end);
            end;
        end;

        function Depbox:Resize()
            Frame.Size = UDim2.new(1, 0, 0, ContentHeight());

            -- Content changed rather than the toggle, so track it without
            -- animating; the open and close animation comes from Update.
            SetHeight(0);
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        -- The groupbox sums its children's heights, so it has to re-measure on
        -- every frame of the slide, not just at the ends of it.
        Holder:GetPropertyChangedSignal('Size'):Connect(function()
            Groupbox:Resize();
        end);

        function Depbox:Update()
            local ShouldShow = true;

            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    ShouldShow = false;
                    break;
                end;
            end;

            if Initialized and ShouldShow == Expanded then
                return;
            end;

            Expanded = ShouldShow;

            -- The first pass runs while the menu is still being built, so settle
            -- straight into place instead of animating open on load.
            SetHeight(Initialized and Library.Anim.Depbox or 0);
            Initialized = true;
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    -- Held off the screen edge so the panels' shadows and rounded corners have
    -- somewhere to sit.
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 12, 0, 44);
        Size = UDim2.new(0, 400, 0, 300);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 6);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 100, 0, 8);
        Size = UDim2.new(0, 213, 0, 28);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    Library:ApplyRound(WatermarkOuter, Library.Radius.Panel, 'OutlineColor');

    Library:AddToRegistry(WatermarkOuter, {
        BackgroundColor3 = 'BackgroundColor';
    });

    Library:AddAccentBar(WatermarkOuter, Library.Radius.Panel, 201);

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -12, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = WatermarkOuter;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;

    local WatermarkDrag = Library:Create('TextButton', {
        Name = 'DragHit';
        Text = '';
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.fromScale(1, 1);
        ZIndex = 204;
        Parent = WatermarkOuter;
    });

    WatermarkLabel.ZIndex = 203;
    Library:MakeDraggable(Library.Watermark, nil, false, WatermarkDrag);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:ApplyRound(KeybindOuter, Library.Radius.Panel, 'OutlineColor');

    Library:AddToRegistry(KeybindOuter, {
        BackgroundColor3 = 'MainColor';
    }, true);

    Library:AddAccentBar(KeybindOuter, Library.Radius.Panel, 101);

    local KeybindInner = KeybindOuter;

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 103;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;

    local KeybindDrag = Library:Create('TextButton', {
        Name = 'DragHit';
        Text = '';
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 20);
        ZIndex = 120;
        Parent = KeybindOuter;
    });

    Library:MakeDraggable(KeybindOuter, nil, false, KeybindDrag);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, math.max(X + 20, 80), 0, 28);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    local Width = XSize + 28;
    local Height = math.max(YSize + 14, 30);

    -- The list layout owns the holder's slot, so the panel animates inside it
    -- rather than fighting the layout for its own position.
    local Holder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, Width, 0, 0);
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -(Width + 40), 0, 0);
        Size = UDim2.new(0, Width, 0, Height);
        ZIndex = 100;
        Parent = Holder;
    });

    Library:ApplyRound(NotifyOuter, Library.Radius.Panel, 'OutlineColor');
    Library:AddShadow(NotifyOuter, Library.Radius.Panel);

    -- Registered before the accent bar, which reads the parent's registry entry
    -- to work out what colour to cover itself with.
    Library:AddToRegistry(NotifyOuter, {
        BackgroundColor3 = 'BackgroundColor';
    }, true);

    Library:AddAccentBar(NotifyOuter, Library.Radius.Panel, 101);

    Library:CreateLabel({
        Position = UDim2.new(0, 12, 0, 1);
        Size = UDim2.new(1, -24, 1, -1);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = NotifyOuter;
    }, true);

    local Slide = Library.Anim.Notify;

    -- Holder grows so the stack below settles down into place, while the panel
    -- slides in over it from off the left edge.
    Library:Tween(Holder, { Size = UDim2.new(0, Width, 0, Height) }, Slide * 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
    Library:Tween(NotifyOuter, { Position = UDim2.new(0, 0, 0, 0) }, Slide, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);

    task.delay(Time or 5, function()
        if not Holder.Parent then
            return;
        end;

        Library:Tween(NotifyOuter, { Position = UDim2.new(0, -(Width + 40), 0, 0) }, Slide * 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In);

        task.wait(Slide * 0.55);

        if not Holder.Parent then
            return;
        end;

        Library:Tween(Holder, { Size = UDim2.new(0, Width, 0, 0) }, Slide * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In);

        task.wait(Slide * 0.75);

        Holder:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        ClipsDescendants = true;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:ApplyRound(Outer, Library.Radius.Panel, 'OutlineColor');
    Library:AddShadow(Outer, Library.Radius.Panel);
    Library:AddToRegistry(Outer, {
        BackgroundColor3 = 'MainColor';
    });

    local Inner = Library:Create('Frame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = Outer;
    });

    local TitleDrag = Library:Create('TextButton', {
        Name = 'TitleDrag';
        Text = '';
        AutoButtonColor = false;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 25);
        ZIndex = 50;
        Parent = Inner;
    });

    Library:MakeDraggable(Outer, nil, true, TitleDrag);

    if Config.Resizable ~= false then
        local MinSize = typeof(Config.MinSize) == 'Vector2' and Config.MinSize or Vector2.new(420, 320);
        local MaxSize = typeof(Config.MaxSize) == 'Vector2' and Config.MaxSize or Vector2.new(1200, 900);
        Library:MakeResizable(Outer, MinSize, MaxSize);
    end;

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 10, 0, 0);
        Size = UDim2.new(0.55, 0, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        TextTruncate = Enum.TextTruncate.AtEnd;
        ZIndex = 41;
        Parent = Inner;
    });

    local StatusLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(1, 0);
        Position = UDim2.new(1, -10, 0, 0);
        Size = UDim2.new(0.42, 0, 0, 25);
        Text = Config.Status or '';
        TextColor3 = Library.AccentColor;
        TextXAlignment = Enum.TextXAlignment.Right;
        TextTruncate = Enum.TextTruncate.AtEnd;
        ZIndex = 41;
        Parent = Inner;
    });

    Library:AddToRegistry(StatusLabel, {
        TextColor3 = 'AccentColor';
    });

    local function LayoutTitleBar()
        local Total = math.max(Outer.AbsoluteSize.X, 200);
        local StatusWidth = select(1, Library:GetTextBounds(StatusLabel.Text, Library.Font, 16));
        local TitleWidth = select(1, Library:GetTextBounds(WindowLabel.Text, Library.Font, 16));
        local Gap = 16;
        local SidePad = 10;

        StatusWidth = math.min(StatusWidth + 4, math.floor(Total * 0.5));
        local TitleMax = Total - StatusWidth - Gap - SidePad * 2;
        TitleWidth = math.min(TitleWidth + 4, math.max(TitleMax, 40));

        WindowLabel.Position = UDim2.new(0, SidePad, 0, 0);
        WindowLabel.Size = UDim2.new(0, TitleWidth, 0, 25);
        StatusLabel.Position = UDim2.new(1, -SidePad, 0, 0);
        StatusLabel.Size = UDim2.new(0, StatusWidth, 0, 25);
    end;

    StatusLabel:GetPropertyChangedSignal('Text'):Connect(LayoutTitleBar);
    Outer:GetPropertyChangedSignal('AbsoluteSize'):Connect(LayoutTitleBar);
    WindowLabel:GetPropertyChangedSignal('Text'):Connect(LayoutTitleBar);
    task.defer(LayoutTitleBar);

    if not Config.Status then
        task.spawn(function()
            local Success, Info = pcall(function()
                return game:GetService('MarketplaceService'):GetProductInfo(game.PlaceId);
            end);

            if Success and Info and Info.Name then
                StatusLabel.Text = Info.Name;
            else
                StatusLabel.Text = game.Name or 'Unknown';
            end;

            LayoutTitleBar();
        end);
    else
        LayoutTitleBar();
    end;

    local TabBarOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 0, 29);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:ApplyRound(TabBarOuter, Library.Radius.Control, 'OutlineColor');

    Library:AddToRegistry(TabBarOuter, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabBarInner = Library:Create('Frame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = TabBarOuter;
    });

    Library:AddToRegistry(TabBarInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 4, 0, 4);
        Size = UDim2.new(1, -8, 1, -8);
        ZIndex = 1;
        Parent = TabBarInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    -- Shared sliding pill under the active main tab (bottom edge). Three pixels
    -- rather than two so the rounded ends are actually visible.
    local TabSlider = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        AnchorPoint = Vector2.new(0, 1);
        Position = UDim2.new(0, 4, 1, -2);
        Size = UDim2.new(0, 0, 0, 3);
        Visible = false;
        ZIndex = 5;
        Parent = TabBarInner;
    });

    Library:AddCorner(TabSlider, Library.Radius.Pill);
    Library:AddToRegistry(TabSlider, {
        BackgroundColor3 = 'AccentColor';
    });

    local function MoveTabSlider(Button, Instant)
        if not Button then
            return;
        end;

        local RelX = Button.AbsolutePosition.X - TabBarInner.AbsolutePosition.X;
        local Width = math.max(Button.AbsoluteSize.X - 10, 8);
        local GoalPos = UDim2.new(0, RelX + 5, 1, -2);
        local GoalSize = UDim2.new(0, Width, 0, 3);

        TabSlider.Visible = true;

        if Instant then
            TabSlider.Position = GoalPos;
            TabSlider.Size = GoalSize;
        else
            Library:Tween(TabSlider, {
                Position = GoalPos;
                Size = GoalSize;
            }, Library.Anim.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
        end;
    end;

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 58);
        Size = UDim2.new(1, -16, 1, -66);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:ApplyRound(MainSectionOuter, Library.Radius.Control, 'OutlineColor');

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 1, -16);
        ClipsDescendants = true;
        ZIndex = 2;
        Parent = MainSectionInner;
    });

    Library:ApplyRound(TabContainer, Library.Radius.Control, 'OutlineColor');

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
    });

    Window.ActiveTabIndex = 0;
    local NextTabIndex = 0;

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:SetStatus(Text)
        StatusLabel.Text = Text or '';
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        NextTabIndex = NextTabIndex + 1;
        Tab.Index = NextTabIndex;

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Text = Name;
            TextTransparency = 0.35;
            ZIndex = 1;
            Parent = TabButton;
        });

        Library:AddToRegistry(TabButtonLabel, {
            TextColor3 = 'FontColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 1, -16);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 1, -16);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        Tab.TabButton = TabButton;
        Tab.TabButtonLabel = TabButtonLabel;

        function Tab:ShowTab()
            -- A list left open on the outgoing tab would float over the new one.
            Library:CloseAllDropdowns(nil, true);

            for _, OtherTab in next, Window.Tabs do
                OtherTab:HideTab();
            end;

            Library:Tween(TabButtonLabel, { TextTransparency = 0 }, Library.Anim.Tab * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            MoveTabSlider(TabButton, not TabSlider.Visible);
            Window.ActiveTabIndex = Tab.Index;
            TabFrame.Visible = true;
            TabFrame.Position = UDim2.new(0, 0, 0, 0);

            if Window.UpdateFadeCache then
                Window:UpdateFadeCache(TabButtonLabel, 'TextTransparency', 0);
            end;
        end;

        function Tab:HideTab()
            Library:Tween(TabButtonLabel, { TextTransparency = 0.35 }, Library.Anim.Tab * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            TabFrame.Visible = false;
            TabFrame.Position = UDim2.new(0, 0, 0, 0);

            if Window.UpdateFadeCache then
                Window:UpdateFadeCache(TabButtonLabel, 'TextTransparency', 0.35);
            end;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:ApplyRound(BoxOuter, Library.Radius.Panel, 'OutlineColor');
            Library:AddShadow(BoxOuter, Library.Radius.Panel);

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:AddAccentBar(BoxOuter, Library.Radius.Panel, 2);

            -- Held clear of the rounded corner: at Radius.Panel the arc is still
            -- ~5px inside the box at this height, so the old 4px inset put the
            -- first glyph underneath the outline.
            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, -14, 0, 18);
                Position = UDim2.new(0, 10, 0, 3);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                -- The tail has to clear the bottom corner arc, not just the flat
                -- edge, or the last row's corners cross the outline.
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 10);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:ApplyRound(BoxOuter, Library.Radius.Panel, 'OutlineColor');
            Library:AddShadow(BoxOuter, Library.Radius.Panel);
            BoxOuter.ClipsDescendants = true;

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            Library:AddAccentBar(BoxOuter, Library.Radius.Panel, 3);

            -- Nested tabs: accent bar on top of the active tab. Inset far enough
            -- that the outer buttons clear the panel's rounded corners.
            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 8, 0, 4);
                Size = UDim2.new(1, -16, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            -- Shared top accent that slides between nested tabs. Three pixels
            -- rather than two so the rounded ends are actually visible.
            local NestedSlider = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Position = UDim2.new(0, 6, 0, 1);
                Size = UDim2.new(0, 0, 0, 3);
                Visible = false;
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddCorner(NestedSlider, Library.Radius.Pill);
            Library:AddToRegistry(NestedSlider, {
                BackgroundColor3 = 'AccentColor';
            });

            local function MoveNestedSlider(Button, Instant)
                if not Button then
                    return;
                end;

                local RelX = Button.AbsolutePosition.X - BoxInner.AbsolutePosition.X;
                local Width = math.max(Button.AbsoluteSize.X - 12, 8);
                local GoalPos = UDim2.new(0, RelX + 6, 0, 1);
                local GoalSize = UDim2.new(0, Width, 0, 3);

                NestedSlider.Visible = true;

                if Instant then
                    NestedSlider.Position = GoalPos;
                    NestedSlider.Size = GoalSize;
                else
                    Library:Tween(NestedSlider, {
                        Position = GoalPos;
                        Size = GoalSize;
                    }, Library.Anim.Tab, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
                end;
            end;

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderSizePixel = 0;
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddCorner(Button, Library.Radius.Control);

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 22);
                    Size = UDim2.new(1, -4, 1, -22);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    Library:CloseAllDropdowns(nil, true);

                    for _, OtherTab in next, Tabbox.Tabs do
                        OtherTab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;
                    MoveNestedSlider(Button, not NestedSlider.Visible);

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, OtherTab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, TabButton in next, TabboxButtons:GetChildren() do
                        if not TabButton:IsA('UIListLayout') then
                            TabButton.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    -- Container starts at 22 here, so the tail is measured from
                    -- there to leave the same clearance as a plain groupbox.
                    BoxOuter.Size = UDim2.new(1, 0, 0, 22 + Size + 10);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                local TabCount = 0;
                for _ in next, Tabbox.Tabs do
                    TabCount = TabCount + 1;
                end;

                if TabCount == 1 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        Window.Tabs[Name] = Tab;

        -- Always select the first window tab (child count is unreliable with strokes/corners).
        if Tab.Index == 1 then
            task.defer(function()
                Tab:ShowTab();
            end);
        end;

        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local Toggled = false;
    local Fading = false;
    local TransparencyCache = {};

    function Window:UpdateFadeCache(Instance, Property, Value)
        local Cache = TransparencyCache[Instance];
        if Cache then
            Cache[Property] = Value;
        end;
    end;

    local function RefreshActiveTab()
        if Window.ActiveTabIndex <= 0 then
            return;
        end;

        for _, Tab in next, Window.Tabs do
            if Tab.Index == Window.ActiveTabIndex then
                Tab:ShowTab();
                return;
            end;
        end;
    end;

    local function ShouldSkipFade(Desc)
        local Name = Desc.Name;
        return Name == 'WindowBackdrop' or Name == 'TitleDrag' or Name == 'DragHit' or Name == 'ResizeGrip';
    end;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);

        -- Dropdown lists are siblings of the window, so the fade below never
        -- reaches them; without this they hang on screen after the menu closes.
        Library:CloseAllDropdowns(nil, true);

        ModalElement.Modal = Toggled;
        Library.MenuOpen = Toggled;

        if Toggled then
            Outer.Visible = true;
            Library:SetMenuBlur(true);
        else
            Library:SetMenuBlur(false);
        end;

        local function FadeProp(Inst, Prop)
            if ShouldSkipFade(Inst) then
                return;
            end;

            local Cache = TransparencyCache[Inst];
            if not Cache then
                Cache = {};
                TransparencyCache[Inst] = Cache;
            end;

            if Cache[Prop] == nil then
                Cache[Prop] = Inst[Prop];
            end;

            if Cache[Prop] == 1 then
                return;
            end;

            TweenService:Create(Inst, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), {
                [Prop] = Toggled and Cache[Prop] or 1;
            }):Play();
        end;

        FadeProp(Outer, 'BackgroundTransparency');

        for _, Desc in next, Outer:GetDescendants() do
            if ShouldSkipFade(Desc) then
                continue;
            end;

            if Desc:IsA('ImageLabel') then
                FadeProp(Desc, 'ImageTransparency');
                FadeProp(Desc, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') or Desc:IsA('TextButton') then
                FadeProp(Desc, 'TextTransparency');
                FadeProp(Desc, 'BackgroundTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                FadeProp(Desc, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                FadeProp(Desc, 'Transparency');
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;
        Fading = false;

        if Toggled then
            RefreshActiveTab();
        end;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library