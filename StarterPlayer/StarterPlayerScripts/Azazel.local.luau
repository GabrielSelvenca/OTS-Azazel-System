local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Version = require(package:WaitForChild("Version"))
local Settings = require(package:WaitForChild("Config"):WaitForChild("Settings"))
local controllersFolder = package:WaitForChild("Client"):WaitForChild("Controllers")

local started, total = 0, 0
for _, module in controllersFolder:GetChildren() do
    if not module:IsA("ModuleScript") then
        continue
    end
    total += 1
    task.spawn(function()
        local ok, err = pcall(function()
            local controller = require(module)
            if type(controller) == "table" and type(controller.Start) == "function" then
                controller.Start()
            end
        end)
        if ok then
            started += 1
        else
            warn(`[Azazel] Controller {module.Name} failed to start: {err}`)
        end
    end)
end

task.defer(function()
    if Settings.Debug.PrintBoot then
        print(`[Azazel] client {Version.ToString()} {started}/{total} controllers started`)
    end
end)
