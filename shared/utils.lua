Utils = {}

function Utils.GetDistance(pos1, pos2)
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

function Utils.GetDistance2D(pos1, pos2)
    return math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)
end

function Utils.IsWithinArea(position, centerPoint, radius)
    return Utils.GetDistance(position, centerPoint) <= radius
end

function Utils.GetRandomPositionAroundPoint(centerPoint, minRadius, maxRadius)
    local angle = math.random() * 2 * math.pi
    local distance = math.random(minRadius, maxRadius)
    return vector3(
        centerPoint.x + (distance * math.cos(angle)),
        centerPoint.y + (distance * math.sin(angle)),
        centerPoint.z
    )
end

function Utils.FormatTime(milliseconds)
    local totalSeconds = math.floor(milliseconds / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

function Utils.GetCircleFormation(centerPoint, radius, count, startAngle)
    local positions = {}
    local angleStep = 360 / count
    startAngle = startAngle or 0
    for i = 1, count do
        local angle = math.rad(startAngle + (angleStep * (i - 1)))
        local position = vector3(
            centerPoint.x + (radius * math.cos(angle)),
            centerPoint.y + (radius * math.sin(angle)),
            centerPoint.z
        )
        table.insert(positions, position)
    end
    return positions
end

function Utils.IsEntityAlive(entity)
    return DoesEntityExist(entity) and not IsEntityDead(entity)
end

function Utils.GetGroundZ(x, y, z)
    local retval, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
    if retval then return groundZ else return z end
end

function Utils.GetHeadingBetweenPoints(pos1, pos2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    local heading = math.atan2(dy, dx) * 180 / math.pi
    return (heading + 360) % 360
end

function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.Round(number, decimals)
    local power = 10^(decimals or 0)
    return math.floor(number * power + 0.5) / power
end

function Utils.GetRandomFromTable(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

function Utils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function Utils.DeepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Utils.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function Utils.DebugPrint(message, ...)
    if Config and Config.Debug then
        print(string.format("[DEADWOOD-STAGE] " .. message, ...))
    end
end

function Utils.SafeDeleteEntity(entity)
    if DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
    end
end

function Utils.SafeRemoveBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

function Utils.SetupNetworkEntity(entity, setAsMission)
    if not DoesEntityExist(entity) then return false end
    SetEntityAsMissionEntity(entity, setAsMission or true, true)
    SetEntityLoadCollisionFlag(entity, true)
    if NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        return true
    end
    return false
end

function Utils.GetWagonHealthPercentage(wagon)
    if not DoesEntityExist(wagon) then return 0 end
    local currentHealth = GetEntityHealth(wagon)
    local maxHealth = GetEntityMaxHealth(wagon)
    if maxHealth <= 0 then return 0 end
    return math.floor((currentHealth / maxHealth) * 100)
end

return Utils
