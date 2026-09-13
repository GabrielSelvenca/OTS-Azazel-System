local Version = {
    Major = 0,
    Minor = 1,
    Patch = 0,
    Channel = "alpha",
    Build = 6,
}

local RELEASE_CHANNEL = "release"

function Version.ToString(): string
    local core = string.format("%d.%d.%d", Version.Major, Version.Minor, Version.Patch)
    if Version.Channel == RELEASE_CHANNEL then
        return core
    end
    return string.format("%s-%s.%d", core, Version.Channel, Version.Build)
end

function Version.Tag(): string
    return "v" .. Version.ToString()
end

function Version.IsStable(): boolean
    return Version.Channel == RELEASE_CHANNEL or Version.Channel == "hotfix"
end

return Version
