--[[
    Touch Fling GUI (Spin‑Fling) для Delta Executor – исправлено
    Флингует только других игроков, локальный игрок в безопасности.
]]

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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

-- ============== ЛОГИКА TOUCH FLING (SPIN) ==============
local flingEnabled = false
local lastFling = {}  -- чтобы не флингать одного и того же игрока слишком часто

-- Функция получения персонажа из части (с проверкой на модель)
local function getCharacterFromHit(hit)
    if not hit or not hit.Parent then return nil end
    local model = hit.Parent
    -- Проверяем, является ли родитель моделью с Humanoid
    if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
        return model
    end
    -- Иногда часть может быть внутри вложенной папки, пробуем прародителя
    if model.Parent and model.Parent:IsA("Model") and model.Parent:FindFirstChildOfClass("Humanoid") then
        return model.Parent
    end
    return nil
end

-- Функция Spin‑Fling для конкретного персонажа
local function spinFling(character)
    if not flingEnabled then return end
    if character == player.Character then return end  -- себя не флингуем
    
    -- Защита от повторного флинга (кулдаун 0.5 сек на персонажа)
    if lastFling[character] and tick() - lastFling[character] < 0.5 then
        return
    end
    lastFling[character] = tick()
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    
    if humanoid and rootPart then
        if rootPart.Anchored then return end
        
        -- Захватываем сетевое владение, чтобы физика сработала на всех
        pcall(function()
            rootPart:SetNetworkOwner(player)
        end)
        
        -- Угловая скорость (раскрутка)
        rootPart.AssemblyAngularVelocity = Vector3.new(
            math.random(-10000, 10000),
            math.random(50000, 100000),  -- основная ось вращения
            math.random(-10000, 10000)
        )
        
        -- Линейная скорость (подброс + улёт)
        rootPart.AssemblyLinearVelocity = Vector3.new(
            math.random(-1500, 1500),
            math.random(3000, 8000),     -- подбрасываем вверх
            math.random(-1500, 1500)
        )
        
        -- Через паузу возвращаем владение серверу
        task.wait(0.2)
        pcall(function()
            rootPart:SetNetworkOwner(nil)
        end)
    end
end

-- Обработчик касания
local function onPartTouched(hit)
    if not flingEnabled then return end
    
    local character = getCharacterFromHit(hit)
    if character and character ~= player.Character then
        spinFling(character)
    end
end

-- Подключаем события ко всем существующим частям и будем отслеживать новые
local connectionActive = false
local connections = {}

local function connectTouchedEvents()
    if connectionActive then return end
    connectionActive = true
    
    -- Подключаемся к существующим
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(player.Character) then
            -- Игнорируем части своего персонажа, чтобы не триггериться на себя
            local conn = v.Touched:Connect(onPartTouched)
            table.insert(connections, conn)
        end
    end
    
    -- Отслеживаем новые объекты
    local newPartConn
    newPartConn = workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") and not desc:IsDescendantOf(player.Character) then
            local conn = desc.Touched:Connect(onPartTouched)
            table.insert(connections, conn)
        end
    end)
    table.insert(connections, newPartConn)
end

local function disconnectTouchedEvents()
    connectionActive = false
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end

-- Включение / выключение режима
local function enableFling()
    flingEnabled = true
    connectTouchedEvents()
end

local function disableFling()
    flingEnabled = false
    disconnectTouchedEvents()
end

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

-- Защита
gui.Enabled = true
mainFrame.Active = true
mainFrame.Selectable = true

print("Touch Fling (исправлено) – только другие игроки! Прикоснись, чтобы флингануть.")