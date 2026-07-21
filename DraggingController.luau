-- Moonlord_A , moonlord_a (Roblox, Discord)
-- This is script that enables dragging items smoothly on clients, high ping players should have smoother experience
-- There are serveral parts in workspace that can be used to test scripts functionality , some have artificial delays and some will be rejected on purpose 
-- PC Only, dragging & rotating

--- CONFIGURATIONS ---
local DRAGGABLE_OBJECT_TAG = "Dragable"
local DRAGGEDBY_ATTRIBUTE = "DraggedBy"

local DRAGGING_RANGE = 15
local REJECTED_DRAG_TWEEN_TIME = 0.2
local DRAGGED_OBJECT_COLLISIONGROUP = "DraggedObject"

local ROTATION_SPEED = 2
local ROTATION_ENABLED_KEY = Enum.KeyCode.LeftShift

local ROTATION_KEYS = {
--  [Key] = {isHorizontal, direction}
	[Enum.KeyCode.A] = {true, -1},
	[Enum.KeyCode.D] = {true, 1},
	[Enum.KeyCode.W] = {false, -1},
	[Enum.KeyCode.S] = {false, 1},
}

--- SERVICES ---
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunSerice = game:GetService("RunService")
local Players = game:GetService("Players")

--- VARIABLES ---
local DragEvent = ReplicatedStorage:WaitForChild("DragEvent")
local AlignPosition = ReplicatedStorage:WaitForChild("AlignPosition")
local AlignOrientation = ReplicatedStorage:WaitForChild("AlignOrientation")
local Highlight = ReplicatedStorage:WaitForChild("Highlight")
local Player = Players.LocalPlayer
local UserId = Player.UserId
local Camera = workspace.CurrentCamera

--- DYNAMIC VARIABLES ---
local CurrentDraggedObject = nil
local CurrentAlignPosition = AlignPosition:Clone()
local CurrentAlignOrientation = AlignOrientation:Clone()
local CurrentHighlight = Highlight:Clone()
local CurrentAttachment = Instance.new("Attachment")
local CurrentDraggedObjectOffset = 0

--- FUNCTIONS ---
local function SetObjectCollisionGroup(Object: Instance, CollisionGroup: string)
	-- If object is base part then sets its collison group
	if Object:IsA("BasePart") then
		Object.CollisionGroup = CollisionGroup
	end
	
	for _, descendant in Object:GetDescendants() do
		-- If descendant is base part then sets its collison group
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CollisionGroup
		end
	end
end

local function GetWantedRotation(CurrentRotation: CFrame, deltaTime: number)
	-- If user is holding LEFT SHIFT key
	if UserInputService:IsKeyDown(ROTATION_ENABLED_KEY) then
		local RotationX, RotationY = 0, 0
		
		-- Loop through all rotation keys and apply rotation if key is pressed down
		for KeyCode, KeyData in ROTATION_KEYS do
			if UserInputService:IsKeyDown(KeyCode) then
				local isHorizontal = KeyData[1]
				local direction = KeyData[2]
				
				-- Add rotation to X or Y axis based isHorizontal
				if isHorizontal then
					RotationY += direction
				else
					RotationX += direction
				end
			end
		end
		
		-- Calculate rotation angles for this frame
		RotationX = RotationX * ROTATION_SPEED * deltaTime
		RotationY = RotationY * ROTATION_SPEED * deltaTime

		-- If it needs to rotate 
		if RotationX ~= 0 or RotationY ~= 0 then
			
			-- Vertical rotation
			local RotationYCFrame = CFrame.Angles(0, RotationY, 0)
			
			-- Horizontal rotation relative to camera
			local CameraCFrame = Camera.CFrame
			local CameraRightVector = CameraCFrame.RightVector
			
			local RotationXCFrame = CFrame.fromAxisAngle(CameraRightVector, RotationX)

			
			CurrentRotation = RotationXCFrame * RotationYCFrame * CurrentRotation
		end
	end
	
	return CurrentRotation
end

local function ClearDrag()
	-- If player is dragging something, then send singal to server that player stopped dragging
	if CurrentDraggedObject then
		DragEvent:FireServer("Stop")
		SetObjectCollisionGroup(CurrentDraggedObject, "Default")
	end
	
	-- Reset all variables, parents
	CurrentDraggedObject = nil
	CurrentAlignPosition.Parent = nil
	CurrentAlignOrientation.Parent = nil
	CurrentHighlight.Parent = nil
	CurrentAttachment.Parent = nil
	CurrentDraggedObjectOffset = 0
end

local function OnRenderStepped(deltaTime: number)
	-- Validate if player is still alive
	local Character = Player.Character
	if not Character then 
		ClearDrag()
		return 
	end
	
	local Humanoid = Character:FindFirstChild("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	-- If player is missing these components, then we can't drag anything
	if not Humanoid or Humanoid.Health <= 0 or not RootPart then 
		ClearDrag()
		return 
	end
	
	-- Create raycast params for later, to not include player in raycast result
	local RaycastParams = RaycastParams.new()
	RaycastParams:AddToFilter(Character)
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	-- If user is dragging something
	if CurrentDraggedObject then
		-- If user is holding rotation key then character should not move
		if UserInputService:IsKeyDown(ROTATION_ENABLED_KEY) then
			Humanoid.WalkSpeed = 0
		else
			Humanoid.WalkSpeed = 16
		end
		
		-- Calculate mouse position 
		local MouseLocation = UserInputService:GetMouseLocation()
		local MouseRay = workspace.CurrentCamera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
		local WantedPosition = MouseRay.Origin + MouseRay.Direction * CurrentDraggedObjectOffset

		-- Calculate wanted rotation based on user input
		local CurrentRotation = CurrentAlignOrientation.CFrame.Rotation
		local WantedRotation = GetWantedRotation(CurrentRotation, deltaTime)

		-- Update position and Orentation
		CurrentAlignPosition.Position = WantedPosition
		CurrentAlignOrientation.CFrame = WantedRotation
		
		-- If player is still not owner of the object then predict
		local OwnerId = CurrentDraggedObject:GetAttribute(DRAGGEDBY_ATTRIBUTE)
		local MainPart = CurrentAttachment.Parent
		if not OwnerId then
			-- Anchor it so we can move it localy
			if not MainPart.Anchored then
				MainPart.Anchored = true
			end
	
			local WantedCFrame = CFrame.new(WantedPosition) * WantedRotation
			local CurrentCFrame = CurrentDraggedObject:GetPivot()
			
			-- Lerp it so it isnt instant moving
			CurrentDraggedObject:PivotTo(CurrentCFrame:Lerp(WantedCFrame, deltaTime * 10))
		else
			if MainPart.Anchored then
				MainPart.Anchored = false
			end
		end
		
		-- Else server will fire rejection if somebody starts owning it
		return
	end
	
	-- Make player able to move
	Humanoid.WalkSpeed = 16
	
	-- Detect whenever we are hovering over dragable part
	local MouseLocation = UserInputService:GetMouseLocation()
	local MouseRay = workspace.CurrentCamera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
	
	local RaycastResult = workspace:Raycast(MouseRay.Origin, MouseRay.Direction * 100, RaycastParams)

	-- If we are hovering over part
	if RaycastResult then
		local HoveringItem = RaycastResult.Instance
		
		-- Check if is within range
		local Distance = (RootPart.Position - RaycastResult.Position).Magnitude
		if Distance > DRAGGING_RANGE then
			ClearDrag()
			return
		end
		
		-- If item is dragable
		if not HoveringItem:HasTag(DRAGGABLE_OBJECT_TAG) then
			-- If item is child of dragable model
			if not HoveringItem.Parent:HasTag(DRAGGABLE_OBJECT_TAG) then
				ClearDrag()
				return
			end
			
			-- If model has primarypart
			if not HoveringItem.Parent.PrimaryPart then
				warn("DraggingController | Dragable model has no primarypart")
				ClearDrag()
				return
			end
			
			HoveringItem = HoveringItem.Parent
		end
		
		-- If item is already dragged
		if HoveringItem:GetAttribute(DRAGGEDBY_ATTRIBUTE) then
			ClearDrag()
			return
		end
		
		-- Set highlight parent to dragable item
		CurrentHighlight.Parent = HoveringItem
		return
	end
		
	ClearDrag()
end

local function OnInputBegin(input: InputObject, gameProcessedEvent: boolean)
	-- If it is already processed
	if gameProcessedEvent or CurrentDraggedObject then
		return
	end
	
	-- If input is left mouse
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- if highlight parent meets requirements
		if CurrentHighlight.Parent 
			and CurrentHighlight.Parent:HasTag(DRAGGABLE_OBJECT_TAG) 
			and not CurrentHighlight.Parent:GetAttribute(DRAGGEDBY_ATTRIBUTE)  then
			-- Send request to server and start dragging on client
			DragEvent:FireServer(CurrentHighlight.Parent)
			SetObjectCollisionGroup(CurrentHighlight.Parent, DRAGGED_OBJECT_COLLISIONGROUP)
	
			-- Get real part
			local MainPart = CurrentHighlight.Parent
			if MainPart:IsA("Model") then
				MainPart = MainPart.PrimaryPart
			end

			-- Calculate offset from mouse
			local MouseLocation = UserInputService:GetMouseLocation()
			local MouseRay = workspace.CurrentCamera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
			CurrentDraggedObjectOffset = (MainPart.Position - MouseRay.Origin).Magnitude 

			-- Set Align objects
			CurrentAlignPosition.Position = MainPart.Position
			CurrentAlignOrientation.CFrame = MainPart.CFrame

			-- Set final parents
			CurrentAttachment.Parent = MainPart
			CurrentAlignOrientation.Parent = MainPart
			CurrentAlignPosition.Parent = MainPart
			CurrentDraggedObject = CurrentHighlight.Parent
		end
	end
end

local function OnInputEnded(input: InputObject, gameProcessedEvent: boolean)
	-- If it is already processed
	if gameProcessedEvent or not CurrentDraggedObject then
		return
	end
	
	-- If input is left mouse
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		ClearDrag()
		return
	end
end

local function OnDragEventRejected(MainPart: BasePart, OriginalCFrame: CFrame)
	-- If user is still holding that item
	if MainPart == CurrentAttachment.Parent then
		ClearDrag()
	end
	
	-- Anchor it so tween dosent fight physics
	MainPart.Anchored = true
	
	-- Create tween it to original position by server
	local Tween = TweenService:Create(MainPart, TweenInfo.new(REJECTED_DRAG_TWEEN_TIME), {
		CFrame = OriginalCFrame
	})
	
	-- Add red highlight for visuals
	local RedHighlight = Highlight:Clone()
	RedHighlight.FillColor = Color3.fromRGB(255, 0, 0)
	RedHighlight.OutlineColor = Color3.fromRGB(255, 0, 0)
	RedHighlight.Parent = MainPart
	
	-- Destroy highlight after tween
	Tween.Completed:Once(function()
		RedHighlight:Destroy()
		MainPart.Anchored = false
	end)
	
	-- Play tween
	Tween:Play()
end

--- INIT ---
CurrentAlignOrientation.Attachment0 = CurrentAttachment
CurrentAlignPosition.Attachment0 = CurrentAttachment

RunSerice.RenderStepped:Connect(OnRenderStepped)
UserInputService.InputBegan:Connect(OnInputBegin)
UserInputService.InputEnded:Connect(OnInputEnded)
DragEvent.OnClientEvent:Connect(OnDragEventRejected)
