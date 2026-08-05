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
ScreenGui.IgnoreGuiInset = true;
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
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;

    -- Animation timings (seconds). Set any to 0 for instant behavior.
    Anim = {
        Toggle = 0.18;
        Slider = 0.45;
        SliderDrag = 0.22;
        Dropdown = 0.28;
        Tab = 0.28;
        Button = 0.14;
        ColorPicker = 0.2;
        Hover = 0.14;
        Pop = 0.32;
        DragBlurSize = 10;
        MenuBlurSize = 10;
        DragAlpha = 0.12;
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

    local Dragging = false;
    local RelGrab = Vector2.zero;
    local DragSize = Vector2.zero;
    local DragAnchor = Vector2.zero;
    local MoveConn;
    local EndConn;

    local function SetTopLeft(TopLeft)
        Instance.Position = UDim2.fromOffset(
            TopLeft.X + DragSize.X * DragAnchor.X,
            TopLeft.Y + DragSize.Y * DragAnchor.Y
        );
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

        if GhostWhileDrag then
            Library:SetDragVisual(Instance, false);
        end;
    end;

    Hit.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return;
        end;

        if not Instance.Visible or not Instance.Parent then
            return;
        end;

        local MousePos = InputService:GetMouseLocation();
        local AbsPos = Instance.AbsolutePosition;
        local RelY = MousePos.Y - AbsPos.Y;

        if Cutoff and RelY > Cutoff then
            return;
        end;

        DragSize = Instance.AbsoluteSize;
        DragAnchor = Instance.AnchorPoint;

        -- Snap to pixel offsets before tracking so scale/anchor combos do not jump.
        SetTopLeft(AbsPos);

        RelGrab = MousePos - AbsPos;
        Dragging = true;

        if GhostWhileDrag then
            Library:SetDragVisual(Instance, true);
        end;

        MoveConn = InputService.InputChanged:Connect(function(Change)
            if not Dragging then
                return;
            end;

            if Change.UserInputType == Enum.UserInputType.MouseMovement then
                SetTopLeft(InputService:GetMouseLocation() - RelGrab);
            end;
        end);

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
        Size = UDim2.fromOffset(18, 18);
        Position = UDim2.new(1, -2, 1, -2);
        AnchorPoint = Vector2.new(1, 1);
        ZIndex = 50;
        Parent = Instance;
    });

    local GripIcon = Library:CreateLabel({
        BackgroundTransparency = 1;
        Size = UDim2.fromOffset(16, 16);
        Position = UDim2.new(1, 0, 1, 0);
        AnchorPoint = Vector2.new(1, 1);
        Text = '◢';
        TextSize = 14;
        TextColor3 = Library.OutlineColor;
        TextXAlignment = Enum.TextXAlignment.Right;
        TextYAlignment = Enum.TextYAlignment.Bottom;
        ZIndex = 51;
        Parent = Grip;
    });

    Library:AddToRegistry(GripIcon, {
        TextColor3 = 'OutlineColor';
    });

    Library:OnHighlight(Grip, GripIcon,
        { TextColor3 = 'AccentColor' },
        { TextColor3 = 'OutlineColor' }
    );

    Grip.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return;
        end;

        local AbsPos = Instance.AbsolutePosition;
        local AbsSize = Instance.AbsoluteSize;
        local Anchor = Instance.AnchorPoint;
        Instance.Position = UDim2.fromOffset(
            AbsPos.X + AbsSize.X * Anchor.X,
            AbsPos.Y + AbsSize.Y * Anchor.Y
        );

        local StartMouse = InputService:GetMouseLocation();
        local StartSize = Vector2.new(Instance.AbsoluteSize.X, Instance.AbsoluteSize.Y);
        local StartPos = Vector2.new(Instance.Position.X.Offset, Instance.Position.Y.Offset);

        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local Pos = InputService:GetMouseLocation();
            local Delta = Pos - StartMouse;
            local NewSize = Vector2.new(
                math.clamp(StartSize.X + Delta.X, MinSize.X, MaxSize.X),
                math.clamp(StartSize.Y + Delta.Y, MinSize.Y, MaxSize.Y)
            );

            Instance.Size = UDim2.fromOffset(NewSize.X, NewSize.Y);
            Instance.Position = UDim2.fromOffset(
                StartPos.X + (NewSize.X - StartSize.X) * Anchor.X,
                StartPos.Y + (NewSize.Y - StartSize.Y) * Anchor.Y
            );

            RenderStepped:Wait();
        end;
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

    Library:ApplyRound(Tooltip, 8, 'OutlineColor');

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

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    local function ApplyProps(Props)
        local Reg = Library.RegistryMap[Instance];
        local Stroke = Instance:FindFirstChildOfClass('UIStroke');
        local Goals = {};

        for Property, ColorIdx in next, Props do
            local Color = Library[ColorIdx] or ColorIdx;

            if Property == 'BorderColor3' and Stroke then
                Library:Tween(Stroke, { Color = Color }, Library.Anim.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

                local StrokeReg = Library.RegistryMap[Stroke];
                if StrokeReg and StrokeReg.Properties.Color then
                    StrokeReg.Properties.Color = ColorIdx;
                end;
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

-- ScreenGui.IgnoreGuiInset = true, so AbsolutePosition is in full-screen space.
-- PlayerMouse.X/Y are inset-relative and will miss hit tests / open menus.
function Library:GetMouse()
    return InputService:GetMouseLocation();
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
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

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

        Library:ApplyRound(DisplayFrame, 7, false, false);

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        Library:AddCorner(CheckerFrame, 6);

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        Library:ApplyRound(PickerFrameOuter, 7, 'OutlineColor');

        Library:AddToRegistry(PickerFrameOuter, {
            BackgroundColor3 = 'BackgroundColor';
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        Library:ApplyRound(PickerFrameInner, 6, false);

        local Highlight = Library:AddAccentBar(PickerFrameInner, 7, 17);

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
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

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

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
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
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
                PaddingLeft = UDim.new(0, 4),
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
                BorderColor3 = 'OutlineColor';
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
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
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

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
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
                    local MouseX = math.clamp(Library:GetMouse().X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Library:GetMouse().Y, MinY, MaxY);

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
                    local MouseY = math.clamp(Library:GetMouse().Y, MinY, MaxY);

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
                        local MouseX = math.clamp(Library:GetMouse().X, MinX, MaxX);

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

                if Library:GetMouse().X < AbsPos.X or Library:GetMouse().X > AbsPos.X + AbsSize.X
                    or Library:GetMouse().Y < (AbsPos.Y - 20 - 1) or Library:GetMouse().Y > AbsPos.Y + AbsSize.Y then

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

        Library:ApplyRound(PickOuter, 8, 'OutlineColor');

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

        Library:ApplyRound(ModeSelectOuter, 6, 'OutlineColor');

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

            Library:ApplyRound(Outer, 9, 'OutlineColor');

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
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
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

        Library:ApplyRound(TextBoxOuter, 9, 'OutlineColor');

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

        local ToggleStroke = Library:ApplyRound(ToggleOuter, 8, 'OutlineColor');

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

        Library:ApplyRound(SliderOuter, 9, 'OutlineColor');

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

        Library:AddCorner(SliderInner, 6);

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

        Library:AddCorner(Fill, 6);

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
                local mPos = Library:GetMouse().X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Library:GetMouse().X;
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

        Library:ApplyRound(DropdownOuter, 9, 'OutlineColor');

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

        local IgnoreClick = false;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            ClipsDescendants = true;
            ZIndex = 500;
            Visible = false;
            Parent = ScreenGui;
        });

        Library:ApplyRound(ListOuter, 9, 'OutlineColor');
        Library:AddToRegistry(ListOuter, {
            BackgroundColor3 = 'MainColor';
        });

        local DropdownListHeight = MAX_DROPDOWN_ITEMS * 20 + 2;
        local OpenUp = false;

        local function RecalculateListPosition()
            local X = DropdownOuter.AbsolutePosition.X;
            local Y = DropdownOuter.AbsolutePosition.Y;
            local W = DropdownOuter.AbsoluteSize.X;
            local H = DropdownOuter.AbsoluteSize.Y;
            local ListH = ListOuter.Size.Y.Offset;

            if OpenUp then
                ListOuter.Position = UDim2.fromOffset(X, Y - ListH);
            else
                ListOuter.Position = UDim2.fromOffset(X, Y + H);
            end;
        end;

        local function RecalculateListSize(YSize)
            DropdownListHeight = YSize or (MAX_DROPDOWN_ITEMS * 20 + 2);
            if ListOuter.Visible and not ListOuter:GetAttribute('Closing') then
                ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, DropdownListHeight);
            elseif not ListOuter.Visible then
                ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, 0);
            end;
            RecalculateListPosition();
        end;

        RecalculateListSize();

        ListOuter:GetPropertyChangedSignal('Size'):Connect(RecalculateListPosition);
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);
        DropdownOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
            RecalculateListSize(DropdownListHeight);
        end);

        local ListInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

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
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Text = '';
                    AutoButtonColor = false;
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                if Count > 1 then
                    local Separator = Library:Create('Frame', {
                        BackgroundColor3 = Library.OutlineColor;
                        BorderSizePixel = 0;
                        Position = UDim2.new(0, 8, 0, 0);
                        Size = UDim2.new(1, -16, 0, 1);
                        ZIndex = 24;
                        Parent = Button;
                    });

                    Library:AddCorner(Separator, 1);

                    Library:AddToRegistry(Separator, {
                        BackgroundColor3 = 'OutlineColor';
                    });
                end;

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BackgroundColor3 = 'BackgroundColor', ZIndex = 24 },
                    { BackgroundColor3 = 'MainColor', ZIndex = 23 }
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

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter:SetAttribute('Closing', false);
            ListOuter:SetAttribute('CloseToken', (ListOuter:GetAttribute('CloseToken') or 0) + 1);
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;

            local W = DropdownOuter.AbsoluteSize.X;
            local Screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080);
            local DropY = DropdownOuter.AbsolutePosition.Y + DropdownOuter.AbsoluteSize.Y + DropdownListHeight;
            OpenUp = DropY > Screen.Y - 8;

            ListOuter.Size = UDim2.fromOffset(W, 0);
            RecalculateListPosition();

            Library:Tween(ListOuter, {
                Size = UDim2.fromOffset(W, DropdownListHeight);
            }, Library.Anim.Dropdown, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);

            Library:Tween(DropdownArrow, { Rotation = OpenUp and 0 or 180 }, Library.Anim.Dropdown, Enum.EasingStyle.Back, Enum.EasingDirection.Out);

            IgnoreClick = true;
            task.defer(function()
                RecalculateListPosition();
                IgnoreClick = false;
            end);
        end;

        function Dropdown:CloseDropdown()
            if not ListOuter.Visible and not ListOuter:GetAttribute('Closing') then
                return;
            end;

            ListOuter:SetAttribute('Closing', true);

            local Token = (ListOuter:GetAttribute('CloseToken') or 0) + 1;
            ListOuter:SetAttribute('CloseToken', Token);

            local W = DropdownOuter.AbsoluteSize.X;

            Library:Tween(ListOuter, {
                Size = UDim2.fromOffset(W, 0);
            }, Library.Anim.Dropdown * 0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.In);

            Library:Tween(DropdownArrow, { Rotation = 0 }, Library.Anim.Dropdown);

            task.delay(Library.Anim.Dropdown * 0.85, function()
                if ListOuter:GetAttribute('CloseToken') == Token and ListOuter:GetAttribute('Closing') then
                    ListOuter.Visible = false;
                    ListOuter:SetAttribute('Closing', false);
                    Library.OpenedFrames[ListOuter] = nil;
                end;
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

        DropdownOuter.MouseButton1Click:Connect(function()
            if Library:MouseIsOverOpenedFrame() and not Library:IsMouseOverFrame(ListOuter) then
                return;
            end;

            if ListOuter.Visible then
                Dropdown:CloseDropdown();
            else
                Dropdown:OpenDropdown();
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return;
            end;

            if IgnoreClick or not ListOuter.Visible then
                return;
            end;

            if Library:IsMouseOverFrame(ListOuter) or Library:IsMouseOverFrame(DropdownOuter) then
                return;
            end;

            Dropdown:CloseDropdown();
        end));

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

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

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

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
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
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
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

    Library:ApplyRound(WatermarkOuter, 10, 'OutlineColor');

    Library:AddToRegistry(WatermarkOuter, {
        BackgroundColor3 = 'BackgroundColor';
    });

    Library:AddAccentBar(WatermarkOuter, 10, 201);

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

    Library:ApplyRound(KeybindOuter, 10, 'OutlineColor');

    Library:AddToRegistry(KeybindOuter, {
        BackgroundColor3 = 'MainColor';
    }, true);

    Library:AddAccentBar(KeybindOuter, 10, 101);

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

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    Library:ApplyRound(NotifyOuter, 9, 'OutlineColor');

    local NotifyInner = Library:Create('Frame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyOuter, {
        BackgroundColor3 = 'MainColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
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

    Library:ApplyRound(Outer, 10, 'OutlineColor');
    Library:AddShadow(Outer, 10);
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

    Library:ApplyRound(TabBarOuter, 9, 'OutlineColor');

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

    -- Shared sliding pill under the active main tab (bottom edge).
    local TabSlider = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        AnchorPoint = Vector2.new(0, 1);
        Position = UDim2.new(0, 4, 1, -2);
        Size = UDim2.new(0, 0, 0, 2);
        Visible = false;
        ZIndex = 5;
        Parent = TabBarInner;
    });

    Library:AddCorner(TabSlider, 2);
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
        local GoalSize = UDim2.new(0, Width, 0, 2);

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

    Library:ApplyRound(MainSectionOuter, 9, 'OutlineColor');

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

    Library:ApplyRound(TabContainer, 9, 'OutlineColor');

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

        function Tab:ShowTab()
            for _, OtherTab in next, Window.Tabs do
                OtherTab:HideTab();
            end;

            Library:Tween(TabButtonLabel, { TextTransparency = 0 }, Library.Anim.Tab * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            MoveTabSlider(TabButton, not TabSlider.Visible);
            Window.ActiveTabIndex = Tab.Index;
            TabFrame.Visible = true;
            TabFrame.Position = UDim2.new(0, 0, 0, 0);
        end;

        function Tab:HideTab()
            Library:Tween(TabButtonLabel, { TextTransparency = 0.35 }, Library.Anim.Tab * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
            TabFrame.Visible = false;
            TabFrame.Position = UDim2.new(0, 0, 0, 0);
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

            Library:ApplyRound(BoxOuter, 10, 'OutlineColor');
            Library:AddShadow(BoxOuter, 10);

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

            local Highlight = Library:AddAccentBar(BoxOuter, 10, 2);

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
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

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
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

            Library:ApplyRound(BoxOuter, 10, 'OutlineColor');
            Library:AddShadow(BoxOuter, 10);
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

            Library:AddAccentBar(BoxOuter, 10, 3);

            -- Nested tabs: accent bar on top of the active tab.
            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 2);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            -- Shared top accent that slides between nested tabs.
            local NestedSlider = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Position = UDim2.new(0, 6, 0, 1);
                Size = UDim2.new(0, 0, 0, 2);
                Visible = false;
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddCorner(NestedSlider, 2);
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
                local GoalSize = UDim2.new(0, Width, 0, 2);

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

                Library:AddCorner(Button, 8);

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

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
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