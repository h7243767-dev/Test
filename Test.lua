--[[
    Touch Fling GUI by Grok
    Для Delta Executor (Mobile)
]]

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui") or game:GetService("StarterGui")

-- Создаём ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "TouchFlingUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

-- Главный фрейм (кнопка)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainButton"
mainFrame.Size = UDim2.new(0, 60, 0, 60)
mainFrame.Position = UDim2.new(0.5, -30, 0.5, -30)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Parent = gui

-- Скругление углов
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = mainFrame

-- Тень
local shadow = Instance.new("UIStroke")
shadow.Color = Color3.fromRGB(0, 0, 0)
shadow.Thickness = 2
shadow.Transparency = 0.5
shadow.Parent = mainFrame

-- Статус (включен / выключен)
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 25)
statusLabel.Position = UDim2.new(0, 0, 0, -30)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextStrokeTransparency = 0
statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14
statusLabel.Text = "OFF"
statusLabel.Parent = mainFrame

-- Иконка внутри кнопки
local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(1, 0, 1, 0)
icon.BackgroundTransparency = 1
icon.TextColor3 = Color3.fromRGB(255, 255, 255)
icon.Font = Enum.Font.GothamBold
icon.TextSize = 28
icon.Text = "👆"
icon.Parent = mainFrame

-- Переменные для перетаскивания
local dragging = false
local dragStart = nil
local startPos = nil

-- Перетаскивание кнопки
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        
        -- Ограничение по экрану
        local screenSize = workspace.CurrentCamera.ViewportSize
        newX = math.clamp(newX, 0, screenSize.X - mainFrame.AbsoluteSize.X)
        newY = math.clamp(newY, 0, screenSize.Y - mainFrame.AbsoluteSize.Y)
        
        mainFrame.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- ============== ЛОГИКА TOUCH FLING ==============
local flingEnabled = false
local oldPositions = {}

local function flingAll()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") or v:IsA("BasePart") then
            if not oldPositions[v] then
                oldPositions[v] = v.CFrame
            end
        end
    end
end

local function touchFling(part)
    if not flingEnabled then return end
    
    if part and part.Parent then
        local character = part.Parent
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
        
        if humanoid and rootPart and character ~= player.Character then
            -- Сохраняем позицию
            local oldPos = rootPart.CFrame
            
            -- Телепортируем игрока высоко вверх
            rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 10000, 0)
            wait(0.1)
            
            -- Отключаем анимации и состояние
            humanoid.PlatformStand = true
            humanoid.Sit = false
            
            -- Возвращаем на место (создаёт эффект флинга)
            rootPart.CFrame = oldPos
            
            wait(0.05)
            humanoid.PlatformStand = false
        end
    end
end

-- Подключение к касаниям
local touchConnection
local function enableFling()
    flingEnabled = true
    flingAll()
    
    -- Вешаем обработчик на все части
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") or v:IsA("BasePart") then
            v.Touched:Connect(function(hit)
                touchFling(hit)
            end)
        end
    end
end

local function disableFling()
    flingEnabled = false
    oldPositions = {}
end

-- Основной цикл поддержки (обновление частей)
spawn(function()
    while wait(1) do
        if flingEnabled then
            flingAll()
        end
    end
end)

-- ============== КЛИК ПО КНОПКЕ (вкл/выкл) ==============
local clickStart = 0
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        clickStart = tick()
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        local clickDuration = tick() - clickStart
        -- Если клик был коротким (не перетаскивание)
        if clickDuration < 0.2 and not dragging then
            if flingEnabled then
                -- Выключаем
                disableFling()
                mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                statusLabel.Text = "OFF"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                icon.Text = "👆"
                icon.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
                -- Включаем
                enableFling()
                mainFrame.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                statusLabel.Text = "ON"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                icon.Text = "⚡"
                icon.TextColor3 = Color3.fromRGB(255, 255, 100)
            end
        end
    end
end)

-- Защита от случайного удаления
gui.Enabled = true
mainFrame.Active = true
mainFrame.Selectable = true

print("Touch Fling GUI загружен! Нажми на кнопку, чтобы включить.")
print("Просто коснись любого игрока, чтобы отфлингать его.")
