--[[
    Touch Fling для Delta Executor (Mobile)
    Без спина – просто мощный отброс при касании
    Ты не флингуешься, работают только касания о других игроков.
]]

local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") or game:GetService("StarterGui")

-- Создаём ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "TouchFlingUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

-- Главная кнопка
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainButton"
mainFrame.Size = UDim2.new(0, 60, 0, 60)
mainFrame.Position = UDim2.new(0.5, -30, 0.5, -30)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 2
stroke.Transparency = 0.5
stroke.Parent = mainFrame

-- Статус (над кнопкой)
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

-- Иконка
local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(1, 0, 1, 0)
icon.BackgroundTransparency = 1
icon.TextColor3 = Color3.fromRGB(255, 255, 255)
icon.Font = Enum.Font.GothamBold
icon.TextSize = 28
icon.Text = "👆"
icon.Parent = mainFrame

-- ============== ПЕРЕТАСКИВАНИЕ ==============
local dragging = false
local dragStart = nil
local startPos = nil

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
        local screenSize = workspace.CurrentCamera.ViewportSize
        local newX = math.clamp(startPos.X.Offset + delta.X, 0, screenSize.X - mainFrame.AbsoluteSize.X)
        local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, screenSize.Y - mainFrame.AbsoluteSize.Y)
        mainFrame.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- ============== ЛОГИКА ФЛИНГА ==============
local flingEnabled = false

-- Получение персонажа из части
local function getCharacterFromHit(hit)
    if not hit or not hit.Parent then return nil end
    local model = hit.Parent
    if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
        return model
    end
    -- иногда часть глубже
    if model.Parent and model.Parent:IsA("Model") and model.Parent:FindFirstChildOfClass("Humanoid") then
        return model.Parent
    end
    return nil
end

-- Флинг одного персонажа
local function flingCharacter(character)
    if character == player.Character then return end -- себя не трогаем
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not humanoid or not root or root.Anchored then return end
    
    -- Захватываем владение для применения физики
    pcall(function()
        root:SetNetworkOwner(player)
    end)
    
    -- Временно включаем PlatformStand, чтобы сбросить анимации и упростить флинг
    humanoid.PlatformStand = true
    
    -- Резкая скорость вверх и в случайную сторону
    root.AssemblyLinearVelocity = Vector3.new(
        math.random(-3000, 3000),
        math.random(5000, 10000),
        math.random(-3000, 3000)
    )
    
    -- Через 0.2 секунды возвращаем владение и выключаем PlatformStand
    task.wait(0.2)
    pcall(function()
        root:SetNetworkOwner(nil)
        humanoid.PlatformStand = false
    end)
end

-- Подключение событий касания
local connections = {}

local function connectAll()
    -- Подключаемся ко всем существующим частям
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsDescendantOf(player.Character) then
            local conn = part.Touched:Connect(function(hit)
                if not flingEnabled then return end
                local char = getCharacterFromHit(hit)
                if char then
                    flingCharacter(char)
                end
            end)
            table.insert(connections, conn)
        end
    end
    
    -- Следим за новыми объектами
    local descConn = workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") and not desc:IsDescendantOf(player.Character) then
            local conn = desc.Touched:Connect(function(hit)
                if not flingEnabled then return end
                local char = getCharacterFromHit(hit)
                if char then
                    flingCharacter(char)
                end
            end)
            table.insert(connections, conn)
        end
    end)
    table.insert(connections, descConn)
end

local function disconnectAll()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end

-- Вкл/выкл
local function enableFling()
    flingEnabled = true
    connectAll()
end

local function disableFling()
    flingEnabled = false
    disconnectAll()
end

-- ============== КЛИК ПО КНОПКЕ ==============
local clickStart = 0
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        clickStart = tick()
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - clickStart < 0.2 and not dragging then
            if flingEnabled then
                disableFling()
                mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                statusLabel.Text = "OFF"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                icon.Text = "👆"
                icon.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
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

print("Touch Fling готов! Нажми кнопку (сейчас OFF), коснись другого игрока – он улетит.")