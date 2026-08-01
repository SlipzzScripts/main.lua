--[[
	AIMBOT FFA CLIENT
	Place inside StarterPlayer > StarterPlayerScripts

	Includes:
	- Right Shift menu
	- Aim lock
	- Target-part selection
	- Aim FOV and smoothness
	- Box ESP
	- Skeleton ESP
	- Name, health, distance and equipped-tool ESP
	- Player selector
	- Teleport behind selected player
	- Teleport keybind
	- WalkSpeed
	- Fly
	- Noclip
	- Hitbox cube visualiser
	- SW2/BulletFactory silent-aim target adapter

	Important:
	This is designed for mechanics intentionally available inside your own game.
]]

--// SERVICES

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--// PLAYER

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// CLEAN OLD COPY

local oldGui = PlayerGui:FindFirstChild("AimbotFFA")
if oldGui then
	oldGui:Destroy()
end

--// CONFIGURATION

local Config = {
	MenuOpen = true,

	AimEnabled = false,
	AimHold = true,
	AimKey = Enum.UserInputType.MouseButton2,
	AimSmoothness = 0.18,
	AimFOV = 180,
	AimMaxDistance = 1500,
	AimWallCheck = true,
	AimTargetPart = "Head",

	SilentAim = false,
	SilentAimFOV = 220,
	SilentAimMaxDistance = 1500,
	SilentAimWallCheck = true,

	ESPEnabled = false,
	BoxESP = true,
	SkeletonESP = false,
	NameESP = true,
	HealthESP = true,
	DistanceESP = true,
	ToolESP = true,
	ESPMaxDistance = 2000,
	ESPTextSize = 9,

GUIAccentColor = Color3.fromRGB(45, 130, 255),
ESPColor = Color3.fromRGB(80, 155, 255),
SkeletonColor = Color3.fromRGB(110, 175, 255),
HitboxColor = Color3.fromRGB(75, 145, 255),

	HitboxVisualiser = false,
	HitboxTargetPart = "HumanoidRootPart",
	HitboxSize = 6,
	HitboxTransparency = 0.7,

	SelectedPlayer = nil,
	TeleportBehindDistance = 4,
	TeleportBind = Enum.KeyCode.T,

	WalkSpeedEnabled = false,
	WalkSpeed = 16,

	FlyEnabled = false,
	FlySpeed = 80,

	Noclip = false,
}

local ACCESS_KEY = "Slipzz123"

local ColorPresets = {
	Blue = Color3.fromRGB(45, 130, 255),
	Cyan = Color3.fromRGB(55, 220, 255),
	Red = Color3.fromRGB(255, 75, 75),
	Green = Color3.fromRGB(75, 235, 130),
	Purple = Color3.fromRGB(180, 80, 255),
	Pink = Color3.fromRGB(255, 90, 190),
	Yellow = Color3.fromRGB(255, 220, 70),
	Orange = Color3.fromRGB(255, 145, 55),
	White = Color3.fromRGB(255, 255, 255),
}

local ColorNames = {
	"Blue",
	"Cyan",
	"Red",
	"Green",
	"Purple",
	"Pink",
	"Yellow",
	"Orange",
	"White",
}

--// OPTIONAL SW2 BULLET MODULE

local BulletFactory

pcall(function()
	local components = ReplicatedStorage:WaitForChild("Components", 5)
	if components then
		local bulletModule = components:FindFirstChild("BulletFactory")
		if bulletModule and bulletModule:IsA("ModuleScript") then
			BulletFactory = require(bulletModule)
		end
	end
end)

--// UTILITY

local function getCharacter(player)
	local character = player and player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end

	return character, humanoid, root
end

local function getTargetPart(character, partName)
	if not character then
		return nil
	end

	if partName == "Torso" then
		return character:FindFirstChild("UpperTorso")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("HumanoidRootPart")
	end

	if partName == "Legs" then
		return character:FindFirstChild("LeftUpperLeg")
			or character:FindFirstChild("Left Leg")
			or character:FindFirstChild("RightUpperLeg")
			or character:FindFirstChild("Right Leg")
			or character:FindFirstChild("HumanoidRootPart")
	end

	return character:FindFirstChild(partName)
		or character:FindFirstChild("HumanoidRootPart")
end

local function isVisible(targetPart, targetCharacter)
	if not targetPart then
		return false
	end

	local origin = Camera.CFrame.Position
	local direction = targetPart.Position - origin

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local filter = {}

	if LocalPlayer.Character then
		table.insert(filter, LocalPlayer.Character)
	end

	rayParams.FilterDescendantsInstances = filter
	rayParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, rayParams)

	if not result then
		return true
	end

	return result.Instance:IsDescendantOf(targetCharacter)
end

local function getMousePosition()
	return UserInputService:GetMouseLocation()
end

local function getClosestTarget(fov, maxDistance, wallCheck, partName)
	local mousePosition = getMousePosition()

	local closestPlayer
	local closestPart
	local closestScreenDistance = fov

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character, humanoid, root = getCharacter(player)

			if character and humanoid and root then
				local worldDistance = (
					Camera.CFrame.Position - root.Position
				).Magnitude

				if worldDistance <= maxDistance then
					local targetPart = getTargetPart(character, partName)

					if targetPart then
						local screenPosition, onScreen =
							Camera:WorldToViewportPoint(targetPart.Position)

						if onScreen and screenPosition.Z > 0 then
							local screenPoint = Vector2.new(
								screenPosition.X,
								screenPosition.Y
							)

							local screenDistance = (
								screenPoint - mousePosition
							).Magnitude

							if screenDistance < closestScreenDistance then
								if not wallCheck
									or isVisible(targetPart, character)
								then
									closestScreenDistance = screenDistance
									closestPlayer = player
									closestPart = targetPart
								end
							end
						end
					end
				end
			end
		end
	end

	return closestPlayer, closestPart
end

--// GUI HELPERS

local function create(className, properties)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	return object
end

local ScreenGui = create("ScreenGui", {
	Name = "Slipzz",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

local KeyBackdrop = create("Frame", {
	Name = "KeyBackdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 7, 13),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Parent = ScreenGui,
})

local KeyFrame = create("Frame", {
	Name = "KeyFrame",
	Size = UDim2.fromOffset(430, 265),
	Position = UDim2.new(0.5, -215, 0.5, -132),
	BackgroundColor3 = Color3.fromRGB(12, 16, 25),
	BorderSizePixel = 0,
	Parent = ScreenGui,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 16),
	Parent = KeyFrame,
})

create("UIStroke", {
	Color = Config.GUIAccentColor,
	Thickness = 1.5,
	Transparency = 0.08,
	Parent = KeyFrame,
})

create("TextLabel", {
	Size = UDim2.new(1, -40, 0, 42),
	Position = UDim2.fromOffset(20, 18),
	BackgroundTransparency = 1,
	Text = "SLIPZZ",
	TextColor3 = Color3.fromRGB(245, 248, 255),
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = KeyFrame,
})

create("TextLabel", {
	Size = UDim2.new(1, -40, 0, 24),
	Position = UDim2.fromOffset(20, 58),
	BackgroundTransparency = 1,
	Text = "Slipzz ACCESS",
	TextColor3 = Config.GUIAccentColor,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = KeyFrame,
})

local KeyBox = create("TextBox", {
	Size = UDim2.new(1, -40, 0, 46),
	Position = UDim2.fromOffset(20, 108),
	BackgroundColor3 = Color3.fromRGB(22, 28, 41),
	BorderSizePixel = 0,
	PlaceholderText = "Enter access key",
	PlaceholderColor3 = Color3.fromRGB(110, 120, 140),
	Text = "",
	TextColor3 = Color3.fromRGB(240, 244, 255),
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	ClearTextOnFocus = false,
	Parent = KeyFrame,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 9),
	Parent = KeyBox,
})

local KeyStatus = create("TextLabel", {
	Size = UDim2.new(1, -40, 0, 22),
	Position = UDim2.fromOffset(20, 162),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 85, 85),
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = KeyFrame,
})

local UnlockButton = create("TextButton", {
	Size = UDim2.new(1, -40, 0, 43),
	Position = UDim2.fromOffset(20, 198),
	BackgroundColor3 = Config.GUIAccentColor,
	BorderSizePixel = 0,
	Text = "UNLOCK PANEL",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	Parent = KeyFrame,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 9),
	Parent = UnlockButton,
})

local Main = create("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(690, 470),
	Position = UDim2.new(0.5, -345, 0.5, -235),
	BackgroundColor3 = Color3.fromRGB(11, 15, 23),
	BorderSizePixel = 0,
	Visible = false,
	Parent = ScreenGui,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 12),
	Parent = Main,
})

local MainStroke = create("UIStroke", {
	Color = Config.GUIAccentColor,
	Thickness = 1.5,
	Transparency = 0.12,
	Parent = Main,
})

local Header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = Color3.fromRGB(19, 23, 33),
	BorderSizePixel = 0,
	Parent = Main,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 12),
	Parent = Header,
})

create("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = Header.BackgroundColor3,
	BorderSizePixel = 0,
	Parent = Header,
})

create("TextLabel", {
	Size = UDim2.new(1, -30, 1, 0),
	Position = UDim2.fromOffset(18, 0),
	BackgroundTransparency = 1,
	Text = "SLIPZZ  •  Slipzz",
	TextColor3 = Color3.fromRGB(240, 245, 255),
	Font = Enum.Font.GothamBlack,
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Header,
})

local AccessUnlocked = false

local function tryUnlock()
	if KeyBox.Text == ACCESS_KEY then
		AccessUnlocked = true
		KeyStatus.Text = "Access granted"
		KeyStatus.TextColor3 = Color3.fromRGB(85, 255, 145)
		task.wait(0.15)
		KeyBackdrop.Visible = false
		KeyFrame.Visible = false
		Main.Visible = true
	else
		KeyStatus.Text = "Incorrect key"
		KeyStatus.TextColor3 = Color3.fromRGB(255, 85, 85)
		KeyBox.Text = ""
	end
end

UnlockButton.MouseButton1Click:Connect(tryUnlock)

KeyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		tryUnlock()
	end
end)

local TabBar = create("Frame", {
	Size = UDim2.new(0, 145, 1, -62),
	Position = UDim2.fromOffset(10, 58),
	BackgroundColor3 = Color3.fromRGB(18, 22, 31),
	BorderSizePixel = 0,
	Parent = Main,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 9),
	Parent = TabBar,
})

local Pages = create("Frame", {
	Size = UDim2.new(1, -175, 1, -72),
	Position = UDim2.fromOffset(165, 62),
	BackgroundTransparency = 1,
	Parent = Main,
})

local TabLayout = create("UIListLayout", {
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = TabBar,
})

create("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	Parent = TabBar,
})

local pageObjects = {}
local tabButtons = {}

local function createPage(name)
	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(60, 135, 255),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Pages,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})

	create("UIPadding", {
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
		Parent = page,
	})

	pageObjects[name] = page
	return page
end

local function openPage(name)
	for pageName, page in pairs(pageObjects) do
		page.Visible = pageName == name
	end

	for buttonName, button in pairs(tabButtons) do
		button.BackgroundColor3 = buttonName == name
				and Color3.fromRGB(42, 105, 210)
			or Color3.fromRGB(25, 30, 42)
	end
end

local function createTab(name)
	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Color3.fromRGB(25, 30, 42),
		BorderSizePixel = 0,
		Text = name,
		TextColor3 = Color3.fromRGB(225, 232, 245),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		AutoButtonColor = false,
		Parent = TabBar,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = button,
	})

	button.MouseButton1Click:Connect(function()
		openPage(name)
	end)

	tabButtons[name] = button
end

local function createSection(parent, title)
	local section = create("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(20, 25, 36),
		BorderSizePixel = 0,
		Parent = parent,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 9),
		Parent = section,
	})

	create("UIStroke", {
		Color = Color3.fromRGB(40, 48, 67),
		Thickness = 1,
		Transparency = 0.35,
		Parent = section,
	})

	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 35),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Color3.fromRGB(120, 175, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = section,
	})

	local content = create("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.fromOffset(10, 39),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = section,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	create("UIPadding", {
		PaddingBottom = UDim.new(0, 10),
		Parent = content,
	})

	return content
end

local function createToggle(parent, text, default, callback)
	local row = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(26, 31, 44),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = row,
	})

	create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(225, 230, 240),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local indicator = create("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -48, 0.5, -10),
		BackgroundColor3 = default
				and Color3.fromRGB(45, 125, 255)
			or Color3.fromRGB(52, 58, 72),
		BorderSizePixel = 0,
		Parent = row,
	})

	create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = indicator,
	})

	local dot = create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = default
				and UDim2.fromOffset(20, 2)
			or UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(245, 248, 255),
		BorderSizePixel = 0,
		Parent = indicator,
	})

	create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = dot,
	})

	local enabled = default

	row.MouseButton1Click:Connect(function()
		enabled = not enabled

		TweenService:Create(
			indicator,
			TweenInfo.new(0.15),
			{
				BackgroundColor3 = enabled
						and Color3.fromRGB(45, 125, 255)
					or Color3.fromRGB(52, 58, 72),
			}
		):Play()

		TweenService:Create(
			dot,
			TweenInfo.new(0.15),
			{
				Position = enabled
						and UDim2.fromOffset(20, 2)
					or UDim2.fromOffset(2, 2),
			}
		):Play()

		callback(enabled)
	end)

	return row
end

local function createSlider(
	parent,
	text,
	minimum,
	maximum,
	default,
	callback
)
	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 53),
		BackgroundColor3 = Color3.fromRGB(26, 31, 44),
		BorderSizePixel = 0,
		Parent = parent,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = holder,
	})

	local title = create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 27),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = text .. ": " .. tostring(default),
		TextColor3 = Color3.fromRGB(225, 230, 240),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local bar = create("Frame", {
		Size = UDim2.new(1, -20, 0, 7),
		Position = UDim2.fromOffset(10, 35),
		BackgroundColor3 = Color3.fromRGB(48, 54, 69),
		BorderSizePixel = 0,
		Parent = holder,
	})

	create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = bar,
	})

	local percentage = math.clamp(
		(default - minimum) / (maximum - minimum),
		0,
		1
	)

	local fill = create("Frame", {
		Size = UDim2.fromScale(percentage, 1),
		BackgroundColor3 = Color3.fromRGB(45, 125, 255),
		BorderSizePixel = 0,
		Parent = bar,
	})

	create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = fill,
	})

	local dragging = false

	local function update(inputPosition)
		local percent = math.clamp(
			(inputPosition.X - bar.AbsolutePosition.X)
				/ bar.AbsoluteSize.X,
			0,
			1
		)

		local value = minimum + ((maximum - minimum) * percent)
		value = math.floor(value * 100 + 0.5) / 100

		fill.Size = UDim2.fromScale(percent, 1)
		title.Text = text .. ": " .. tostring(value)

		callback(value)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			update(input.Position)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging
			and (
				input.UserInputType
					== Enum.UserInputType.MouseMovement
				or input.UserInputType
					== Enum.UserInputType.Touch
			)
		then
			update(input.Position)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	return holder
end

local function createDropdown(
	parent,
	text,
	options,
	default,
	callback
)
	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(26, 31, 44),
		BorderSizePixel = 0,
		Parent = parent,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = holder,
	})

	create("TextLabel", {
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(225, 230, 240),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local index = table.find(options, default) or 1

	local button = create("TextButton", {
		Size = UDim2.new(0.48, -10, 0, 26),
		Position = UDim2.new(0.52, 0, 0.5, -13),
		BackgroundColor3 = Color3.fromRGB(36, 43, 59),
		BorderSizePixel = 0,
		Text = options[index],
		TextColor3 = Color3.fromRGB(180, 210, 255),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Parent = holder,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 6),
		Parent = button,
	})

	button.MouseButton1Click:Connect(function()
		index += 1

		if index > #options then
			index = 1
		end

		button.Text = options[index]
		callback(options[index])
	end)

	return holder
end

local function createColorDropdown(parent, text, defaultName, callback)
	return createDropdown(
		parent,
		text,
		ColorNames,
		defaultName,
		function(name)
			callback(ColorPresets[name])
		end
	)
end

local function createButton(parent, text, callback)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 35),
		BackgroundColor3 = Color3.fromRGB(38, 91, 178),
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Color3.fromRGB(245, 248, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		AutoButtonColor = true,
		Parent = parent,
	})

	create("UICorner", {
		CornerRadius = UDim.new(0, 7),
		Parent = button,
	})

	button.MouseButton1Click:Connect(callback)

	return button
end

--// PAGES

local AimPage = createPage("Aim")
local VisualPage = createPage("Visuals")
local PlayerPage = createPage("Player")
local TeleportPage = createPage("Teleport")

createTab("Aim")
createTab("Visuals")
createTab("Player")
createTab("Teleport")

--// AIM PAGE

local aimSection = createSection(AimPage, "Aim Assist")

createToggle(
	aimSection,
	"Aim Assist",
	Config.AimEnabled,
	function(value)
		Config.AimEnabled = value
	end
)

createToggle(
	aimSection,
	"Wall Check",
	Config.AimWallCheck,
	function(value)
		Config.AimWallCheck = value
	end
)

createDropdown(
	aimSection,
	"Target Part",
	{"Head", "Torso", "HumanoidRootPart", "Legs"},
	Config.AimTargetPart,
	function(value)
		Config.AimTargetPart = value
	end
)

createSlider(
	aimSection,
	"Aim FOV",
	30,
	600,
	Config.AimFOV,
	function(value)
		Config.AimFOV = value
	end
)

createSlider(
	aimSection,
	"Smoothness",
	0.01,
	1,
	Config.AimSmoothness,
	function(value)
		Config.AimSmoothness = value
	end
)

createSlider(
	aimSection,
	"Maximum Distance",
	100,
	5000,
	Config.AimMaxDistance,
	function(value)
		Config.AimMaxDistance = value
	end
)

local silentSection = createSection(AimPage, "Silent Aim")

createToggle(
	silentSection,
	"Silent Aim",
	Config.SilentAim,
	function(value)
		Config.SilentAim = value
	end
)

createToggle(
	silentSection,
	"Silent Wall Check",
	Config.SilentAimWallCheck,
	function(value)
		Config.SilentAimWallCheck = value
	end
)

createSlider(
	silentSection,
	"Silent FOV",
	30,
	600,
	Config.SilentAimFOV,
	function(value)
		Config.SilentAimFOV = value
	end
)

--// VISUAL PAGE

local espSection = createSection(VisualPage, "ESP")

createToggle(
	espSection,
	"Master ESP",
	Config.ESPEnabled,
	function(value)
		Config.ESPEnabled = value
	end
)

createToggle(
	espSection,
	"Box ESP",
	Config.BoxESP,
	function(value)
		Config.BoxESP = value
	end
)

createToggle(
	espSection,
	"Skeleton ESP",
	Config.SkeletonESP,
	function(value)
		Config.SkeletonESP = value
	end
)

createToggle(
	espSection,
	"Player Name",
	Config.NameESP,
	function(value)
		Config.NameESP = value
	end
)

createToggle(
	espSection,
	"Health",
	Config.HealthESP,
	function(value)
		Config.HealthESP = value
	end
)

createToggle(
	espSection,
	"Distance",
	Config.DistanceESP,
	function(value)
		Config.DistanceESP = value
	end
)

createToggle(
	espSection,
	"Equipped Tool",
	Config.ToolESP,
	function(value)
		Config.ToolESP = value
	end
)

createSlider(
	espSection,
	"ESP Distance",
	100,
	5000,
	Config.ESPMaxDistance,
	function(value)
		Config.ESPMaxDistance = value
	end
)

local hitboxSection = createSection(VisualPage, "Hitbox Visualiser")

createToggle(
	hitboxSection,
	"Show Hitbox Cubes",
	Config.HitboxVisualiser,
	function(value)
		Config.HitboxVisualiser = value
	end
)

createDropdown(
	hitboxSection,
	"Hitbox Part",
	{"Head", "Torso", "HumanoidRootPart", "Legs"},
	Config.HitboxTargetPart,
	function(value)
		Config.HitboxTargetPart = value
	end
)

createSlider(
	hitboxSection,
	"Cube Size",
	1,
	20,
	Config.HitboxSize,
	function(value)
		Config.HitboxSize = value
	end
)

local colourSection = createSection(VisualPage, "Colours")

createColorDropdown(colourSection, "GUI Accent", "Blue", function(value)
	Config.GUIAccentColor = value
	MainStroke.Color = value
end)

createColorDropdown(colourSection, "ESP Colour", "Blue", function(value)
	Config.ESPColor = value
end)

createColorDropdown(colourSection, "Skeleton Colour", "Blue", function(value)
	Config.SkeletonColor = value
end)

createColorDropdown(colourSection, "Hitbox Colour", "Blue", function(value)
	Config.HitboxColor = value
end)

createSlider(
	colourSection,
	"ESP Text Size",
	7,
	14,
	Config.ESPTextSize,
	function(value)
		Config.ESPTextSize = math.floor(value)
	end
)

--// PLAYER PAGE

local movementSection = createSection(PlayerPage, "Movement")

createToggle(
	movementSection,
	"Custom WalkSpeed",
	Config.WalkSpeedEnabled,
	function(value)
		Config.WalkSpeedEnabled = value
		local _, humanoid = getCharacter(LocalPlayer)
		if humanoid and not Config.FlyEnabled then
			humanoid.WalkSpeed = value and Config.WalkSpeed or 16
		end
	end
)

createSlider(
	movementSection,
	"WalkSpeed",
	4,
	70,
	Config.WalkSpeed,
	function(value)
		Config.WalkSpeed = value
		local _, humanoid = getCharacter(LocalPlayer)
		if humanoid and Config.WalkSpeedEnabled and not Config.FlyEnabled then
			humanoid.WalkSpeed = value
		end
	end
)

createToggle(
	movementSection,
	"Fly",
	Config.FlyEnabled,
	function(value)
		Config.FlyEnabled = value
	end
)

createSlider(
	movementSection,
	"Fly Speed",
	10,
	300,
	Config.FlySpeed,
	function(value)
		Config.FlySpeed = value
	end
)

createToggle(
	movementSection,
	"Noclip",
	Config.Noclip,
	function(value)
		Config.Noclip = value
	end
)

--// TELEPORT PAGE

local teleportSection = createSection(
	TeleportPage,
	"Player Teleport"
)

local selectorHolder = create("Frame", {
	Size = UDim2.new(1, 0, 0, 38),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(26, 31, 44),
	BorderSizePixel = 0,
	Parent = teleportSection,
})

create("UICorner", {
	CornerRadius = UDim.new(0, 7),
	Parent = selectorHolder,
})

local playerButton = create("TextButton", {
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundTransparency = 1,
	Text = "Select Player ▼",
	TextColor3 = Color3.fromRGB(225, 232, 245),
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	Parent = selectorHolder,
})

local playerList = create("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	Position = UDim2.fromOffset(0, 42),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Visible = false,
	Parent = selectorHolder,
})

create("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = playerList,
})

local function refreshPlayerList()
	for _, child in ipairs(playerList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local playerCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			playerCount += 1

			local option = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 31),
				BackgroundColor3 = Color3.fromRGB(34, 41, 57),
				BorderSizePixel = 0,
				Text = player.DisplayName .. "  (@" .. player.Name .. ")",
				TextColor3 = Color3.fromRGB(220, 230, 245),
				Font = Enum.Font.Gotham,
				TextSize = 10,
				Parent = playerList,
			})

			create("UICorner", {
				CornerRadius = UDim.new(0, 6),
				Parent = option,
			})

			option.MouseButton1Click:Connect(function()
				Config.SelectedPlayer = player
				playerButton.Text = "Selected: " .. player.DisplayName .. " ▼"
				playerList.Visible = false
			end)
		end
	end

	if playerCount == 0 then
		local empty = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 31),
			BackgroundColor3 = Color3.fromRGB(34, 41, 57),
			BorderSizePixel = 0,
			Text = "No other players",
			TextColor3 = Color3.fromRGB(125, 135, 155),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			AutoButtonColor = false,
			Parent = playerList,
		})

		create("UICorner", {
			CornerRadius = UDim.new(0, 6),
			Parent = empty,
		})
	end
end

playerButton.MouseButton1Click:Connect(function()
	refreshPlayerList()
	playerList.Visible = not playerList.Visible
end)

local function teleportBehindSelected()
	local selected = Config.SelectedPlayer

	if not selected then
		return
	end

	local character, _, root = getCharacter(LocalPlayer)
	local targetCharacter, _, targetRoot = getCharacter(selected)

	if not character or not root or not targetCharacter or not targetRoot then
		return
	end

	local destination =
		targetRoot.CFrame
		* CFrame.new(0, 0, Config.TeleportBehindDistance)

	character:PivotTo(
		CFrame.lookAt(
			destination.Position,
			targetRoot.Position
		)
	)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

createButton(
	teleportSection,
	"Teleport Behind Selected",
	teleportBehindSelected
)

createSlider(
	teleportSection,
	"Behind Distance",
	2,
	20,
	Config.TeleportBehindDistance,
	function(value)
		Config.TeleportBehindDistance = value
	end
)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = Color3.fromRGB(26, 31, 44),
	BorderSizePixel = 0,
	Text = "Teleport bind: T",
	TextColor3 = Color3.fromRGB(180, 210, 255),
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	Parent = teleportSection,
})

refreshPlayerList()

Players.PlayerAdded:Connect(refreshPlayerList)

Players.PlayerRemoving:Connect(function(player)
	if Config.SelectedPlayer == player then
		Config.SelectedPlayer = nil
		playerButton.Text = "Select Player ▼"
	end
	refreshPlayerList()
end)

--// DRAGGING

do
	local dragging = false
	local dragStart
	local startPosition

	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = Main.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging
			and (
				input.UserInputType
					== Enum.UserInputType.MouseMovement
				or input.UserInputType
					== Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart

			Main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
end

openPage("Aim")

--// FOV CIRCLES

local AimFOVCircle = create("Frame", {
	Name = "AimFOV",
	Size = UDim2.fromOffset(
		Config.AimFOV * 2,
		Config.AimFOV * 2
	),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = true,
	Parent = ScreenGui,
})

create("UICorner", {
	CornerRadius = UDim.new(1, 0),
	Parent = AimFOVCircle,
})

create("UIStroke", {
	Color = Color3.fromRGB(75, 150, 255),
	Thickness = 1,
	Transparency = 0.2,
	Parent = AimFOVCircle,
})

local SilentFOVCircle = create("Frame", {
	Name = "SilentFOV",
	Size = UDim2.fromOffset(
		Config.SilentAimFOV * 2,
		Config.SilentAimFOV * 2
	),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = ScreenGui,
})

create("UICorner", {
	CornerRadius = UDim.new(1, 0),
	Parent = SilentFOVCircle,
})

create("UIStroke", {
	Color = Color3.fromRGB(185, 80, 255),
	Thickness = 1,
	Transparency = 0.2,
	Parent = SilentFOVCircle,
})

--// ESP STORAGE

local ESPObjects = {}
local HitboxObjects = {}

local skeletonConnections = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"RightLowerLeg", "RightFoot"},
}

local function createESP(player)
	if player == LocalPlayer then
		return
	end

	local folder = create("Folder", {
		Name = tostring(player.UserId),
		Parent = ScreenGui,
	})

	local box = create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = folder,
	})

	create("UIStroke", {
		Name = "Stroke",
		Color = Config.ESPColor,
		Thickness = 1.3,
		Parent = box,
	})

	local info = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		TextColor3 = Config.ESPColor,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.GothamMedium,
		TextSize = Config.ESPTextSize,
		Text = "",
		Visible = false,
		Parent = folder,
	})

	local skeletonLines = {}

	for index = 1, #skeletonConnections do
		local line = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Config.SkeletonColor,
			BorderSizePixel = 0,
			Visible = false,
			Parent = folder,
		})

		skeletonLines[index] = line
	end

	ESPObjects[player] = {
		Folder = folder,
		Box = box,
		Info = info,
		Skeleton = skeletonLines,
	}
end

local function removeESP(player)
	local object = ESPObjects[player]

	if object and object.Folder then
		object.Folder:Destroy()
	end

	ESPObjects[player] = nil

	local hitbox = HitboxObjects[player]

	if hitbox then
		hitbox:Destroy()
	end

	HitboxObjects[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
	createESP(player)
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

local function drawLine(line, pointA, pointB, visible)
	line.Visible = visible

	if not visible then
		return
	end

	local difference = pointB - pointA
	local midpoint = (pointA + pointB) / 2

	line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
	line.Size = UDim2.fromOffset(difference.Magnitude, 1.5)
	line.Rotation = math.deg(
		math.atan2(difference.Y, difference.X)
	)
end

local function hideESP(objects)
	objects.Box.Visible = false
	objects.Info.Visible = false

	for _, line in ipairs(objects.Skeleton) do
		line.Visible = false
	end
end

local function updateESP()
	for player, objects in pairs(ESPObjects) do
		local character, humanoid, root = getCharacter(player)

		if not Config.ESPEnabled
			or not character
			or not humanoid
			or not root
		then
			hideESP(objects)
			continue
		end

		local distance = (
			Camera.CFrame.Position - root.Position
		).Magnitude

		if distance > Config.ESPMaxDistance then
			hideESP(objects)
			continue
		end

		local boundingCFrame, boundingSize =
			character:GetBoundingBox()

		local centreScreen, centreVisible =
			Camera:WorldToViewportPoint(
				boundingCFrame.Position
			)

		if not centreVisible or centreScreen.Z <= 0 then
			hideESP(objects)
			continue
		end

		local topWorld =
			boundingCFrame.Position
			+ Vector3.new(0, boundingSize.Y / 2, 0)

		local bottomWorld =
			boundingCFrame.Position
			- Vector3.new(0, boundingSize.Y / 2, 0)

		local topScreen =
			Camera:WorldToViewportPoint(topWorld)

		local bottomScreen =
			Camera:WorldToViewportPoint(bottomWorld)

		local height =
			math.max(
				math.abs(bottomScreen.Y - topScreen.Y),
				2
			)

		local width = height * 0.55

		objects.Box.Position = UDim2.fromOffset(
			centreScreen.X - width / 2,
			topScreen.Y
		)

		objects.Box.Size = UDim2.fromOffset(width, height)
		objects.Box.Visible = Config.BoxESP

		local stroke = objects.Box:FindFirstChild("Stroke")
		if stroke then
			stroke.Color = Config.ESPColor
		end

		local textParts = {}

		if Config.NameESP then
			table.insert(textParts, player.DisplayName)
		end

		if Config.HealthESP then
			table.insert(
				textParts,
				tostring(math.floor(humanoid.Health))
					.. " HP"
			)
		end

		if Config.DistanceESP then
			table.insert(
				textParts,
				tostring(math.floor(distance))
					.. " studs"
			)
		end

		if Config.ToolESP then
			local tool = character:FindFirstChildOfClass("Tool")

			if tool then
				table.insert(textParts, tool.Name)
			end
		end

		objects.Info.Text = table.concat(textParts, " | ")
		objects.Info.TextColor3 = Config.ESPColor
		objects.Info.TextSize = Config.ESPTextSize
		objects.Info.Position = UDim2.fromOffset(
			centreScreen.X,
			topScreen.Y - 3
		)
		objects.Info.Size = UDim2.fromOffset(
			math.max(width + 90, 150),
			14
		)
		objects.Info.Visible = #textParts > 0

		for index, connection in ipairs(skeletonConnections) do
			local partA = character:FindFirstChild(connection[1])
			local partB = character:FindFirstChild(connection[2])
			local line = objects.Skeleton[index]

			line.BackgroundColor3 = Config.SkeletonColor

			if Config.SkeletonESP and partA and partB then
				local screenA, visibleA =
					Camera:WorldToViewportPoint(partA.Position)

				local screenB, visibleB =
					Camera:WorldToViewportPoint(partB.Position)

				drawLine(
					line,
					Vector2.new(screenA.X, screenA.Y),
					Vector2.new(screenB.X, screenB.Y),
					visibleA
						and visibleB
						and screenA.Z > 0
						and screenB.Z > 0
				)
			else
				line.Visible = false
			end
		end
	end
end

--// HITBOX CUBE VISUALISER

local function updateHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			local targetPart = character
				and getTargetPart(
					character,
					Config.HitboxTargetPart
				)

			local box = HitboxObjects[player]

			if Config.HitboxVisualiser and targetPart then
				if not box then
					box = create("BoxHandleAdornment", {
						Name = "HitboxCube",
						AlwaysOnTop = false,
						ZIndex = 1,
						Color3 = Config.HitboxColor,
						Transparency = Config.HitboxTransparency,
						Parent = Workspace,
					})

					HitboxObjects[player] = box
				end

				box.Adornee = targetPart
				box.Color3 = Config.HitboxColor
				box.Transparency = Config.HitboxTransparency
				box.Size = Vector3.new(
					Config.HitboxSize,
					Config.HitboxSize,
					Config.HitboxSize
				)
				box.Visible = true
			elseif box then
				box.Visible = false
			end
		end
	end
end

--// AIM

local aiming = false

UserInputService.InputBegan:Connect(function(input, processed)
	if not AccessUnlocked then
		return
	end

if input.KeyCode == Enum.KeyCode.RightShift then
	ScreenGui.Enabled = true

	if ScreenGui.Parent ~= PlayerGui then
		ScreenGui.Parent = PlayerGui
	end

	Config.MenuOpen = not Config.MenuOpen
	Main.Visible = Config.MenuOpen
	return
end

	if processed then
		return
	end

	if input.UserInputType == Config.AimKey then
		aiming = true
	end

	if input.KeyCode == Config.TeleportBind then
		teleportBehindSelected()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Config.AimKey then
		aiming = false
	end
end)

local function updateAim()
	if not Config.AimEnabled or not aiming then
		return
	end

	local _, targetPart = getClosestTarget(
		Config.AimFOV,
		Config.AimMaxDistance,
		Config.AimWallCheck,
		Config.AimTargetPart
	)

	if not targetPart then
		return
	end

	local desiredCFrame = CFrame.lookAt(
		Camera.CFrame.Position,
		targetPart.Position
	)

	Camera.CFrame = Camera.CFrame:Lerp(
		desiredCFrame,
		math.clamp(Config.AimSmoothness, 0.01, 1)
	)
end

--// SILENT AIM ADAPTER

local SilentAimAdapter = {}

function SilentAimAdapter.GetTarget()
	if not Config.SilentAim then
		return nil
	end

	local player, part = getClosestTarget(
		Config.SilentAimFOV,
		Config.SilentAimMaxDistance,
		Config.SilentAimWallCheck,
		Config.AimTargetPart
	)

	return player, part
end

function SilentAimAdapter.GetDirection(origin, originalDirection)
	local _, targetPart = SilentAimAdapter.GetTarget()

	if not targetPart then
		return originalDirection
	end

	return (
		targetPart.Position - origin
	).Unit * originalDirection.Magnitude
end

-- This exposes the target adapter so your gun LocalScript can use it.
-- Example:
--
-- local adapter = _G.Zone6ixSilentAim
-- direction = adapter.GetDirection(origin, direction)

_G.Zone6ixSilentAim = SilentAimAdapter

-- Attempt common SW2/BulletFactory adapter names.
-- This will only work if your BulletFactory exposes one of these callbacks.

if BulletFactory then
	pcall(function()
		if type(BulletFactory.SetDirectionModifier) == "function" then
			BulletFactory.SetDirectionModifier(function(origin, direction)
				return SilentAimAdapter.GetDirection(
					origin,
					direction
				)
			end)
		elseif type(BulletFactory.DirectionModifier) ~= "nil" then
			BulletFactory.DirectionModifier =
				function(origin, direction)
					return SilentAimAdapter.GetDirection(
						origin,
						direction
					)
				end
		elseif type(BulletFactory.GetAimDirection) ~= "nil" then
			local original = BulletFactory.GetAimDirection

			BulletFactory.GetAimDirection =
				function(...)
					local direction = original(...)

					if typeof(direction) ~= "Vector3" then
						return direction
					end

					return SilentAimAdapter.GetDirection(
						Camera.CFrame.Position,
						direction
					)
				end
		end
	end)
end

--// FLY

local flyVelocity
local flyGyro

local function stopFly()
	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end

	if flyGyro then
		flyGyro:Destroy()
		flyGyro = nil
	end

	local _, humanoid = getCharacter(LocalPlayer)
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
end

local function updateFly()
	local character, humanoid, root = getCharacter(LocalPlayer)

	if not character or not humanoid or not root then
		stopFly()
		return
	end

	if not Config.FlyEnabled then
		stopFly()
		return
	end

	if not flyVelocity then
		flyVelocity = create("BodyVelocity", {
			Name = "Zone6ixFlyVelocity",
			MaxForce = Vector3.new(
				math.huge,
				math.huge,
				math.huge
			),
			Velocity = Vector3.zero,
			Parent = root,
		})
	end

	if not flyGyro then
		flyGyro = create("BodyGyro", {
			Name = "Zone6ixFlyGyro",
			MaxTorque = Vector3.new(
				math.huge,
				math.huge,
				math.huge
			),
			P = 90000,
			CFrame = root.CFrame,
			Parent = root,
		})
	end

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	local direction = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		direction += Camera.CFrame.LookVector
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		direction -= Camera.CFrame.LookVector
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		direction -= Camera.CFrame.RightVector
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		direction += Camera.CFrame.RightVector
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		direction += Vector3.yAxis
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		direction -= Vector3.yAxis
	end

	if direction.Magnitude > 0 then
		direction = direction.Unit
	end

	flyVelocity.Velocity = direction * Config.FlySpeed
	flyGyro.CFrame = Camera.CFrame
end

--// MOVEMENT

local originalCollision = {}
local lastAppliedWalkSpeed = nil

local function updateMovement()
	local character, humanoid = getCharacter(LocalPlayer)

	if not character or not humanoid then
		return
	end

	local desiredSpeed =
		Config.WalkSpeedEnabled
		and Config.WalkSpeed
		or 16

	if not Config.FlyEnabled
		and lastAppliedWalkSpeed ~= desiredSpeed
	then
		humanoid.WalkSpeed = desiredSpeed
		lastAppliedWalkSpeed = desiredSpeed
	end

	if not Config.FlyEnabled then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if originalCollision[descendant] == nil then
				originalCollision[descendant] =
					descendant.CanCollide
			end

			if Config.Noclip then
				descendant.CanCollide = false
			elseif originalCollision[descendant] ~= nil then
				descendant.CanCollide =
					originalCollision[descendant]
			end
		end
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	stopFly()
	table.clear(originalCollision)
	lastAppliedWalkSpeed = nil
	aiming = false

	task.wait(1)

	-- Restore the existing GUI after respawning
	ScreenGui.Enabled = true

	if ScreenGui.Parent ~= PlayerGui then
		ScreenGui.Parent = PlayerGui
	end

	-- Keep it closed after dying, but allow Right Shift to reopen it
	Config.MenuOpen = false
	Main.Visible = false
end)

--// MAIN LOOPS

RunService.RenderStepped:Connect(function()
	local mousePosition = getMousePosition()

	AimFOVCircle.Position = UDim2.fromOffset(
		mousePosition.X,
		mousePosition.Y
	)

	AimFOVCircle.Size = UDim2.fromOffset(
		Config.AimFOV * 2,
		Config.AimFOV * 2
	)

	AimFOVCircle.Visible = Config.AimEnabled

	SilentFOVCircle.Position = UDim2.fromOffset(
		mousePosition.X,
		mousePosition.Y
	)

	SilentFOVCircle.Size = UDim2.fromOffset(
		Config.SilentAimFOV * 2,
		Config.SilentAimFOV * 2
	)

	SilentFOVCircle.Visible = Config.SilentAim

	updateAim()
	updateESP()
	updateHitboxes()
	updateFly()
end)

RunService.Heartbeat:Connect(function()
	updateMovement()
end)

print("[ZONE6IX] Aimbot FFA client loaded")
print("[ZONE6IX] Right Shift opens/closes the menu")
print("[ZONE6IX] Teleport key is T")
print(
	"[ZONE6IX] Silent adapter available at _G.Zone6ixSilentAim"
)
