local ReplicatedStorage = game:GetService("ReplicatedStorage")

local package = ReplicatedStorage:WaitForChild("Azazel")
local Version = require(package:WaitForChild("Version"))
local Settings = require(package:WaitForChild("Config"):WaitForChild("Settings"))
local controllersFolder = package:WaitForChild("Client"):WaitForChild("Controllers")

local modules = {}
for _, module in controllersFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        table.insert(modules, module)
    end
end

local started, finished = 0, 0
for _, module in modules do
    task.spawn(function()
        local ok, err = pcall(function()
            require(module).Start()
        end)
        if ok then
            started += 1
        else
            warn(`[Azazel] Controller {module.Name} failed to start: {err}`)
        end
        finished += 1
        if finished == #modules and Settings.Debug.PrintBoot then
            print(`[Azazel] client {Version.ToString()} {started}/{#modules} controllers started`)
        end
    end)
end
