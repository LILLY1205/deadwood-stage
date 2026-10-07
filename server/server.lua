local RSGCore = exports['rsg-core']:GetCoreObject()

local function DebugPrint(message)
    if Config.Debug then
        print('[DEADWOOD-STAGE] ' .. tostring(message))
    end
end

local MissionGroups = {}
local ActiveMissions = {}
local BanditCooldown = 0
local GroupEntities = {}

local function CreateMissionGroup(leader)
    local groupId = #MissionGroups + 1
    MissionGroups[groupId] = {
        leader = leader,
        members = {leader},
        state = Config.States.WAITING,
        wagons = {},
        startTime = nil
    }
    return groupId
end

local function GetPlayerGroup(source)
    for groupId, group in pairs(MissionGroups) do
        for i, member in ipairs(group.members) do
            if member == source then
                return groupId, group
            end
        end
    end
    return nil, nil
end

local function AddPlayerToGroup(groupId, source)
    local group = MissionGroups[groupId]
    if not group then return false end
    if #group.members >= Config.MaxPlayers then return false end
    table.insert(group.members, source)
    return true
end

local function SpawnStagecoach(groupId)
    local group = MissionGroups[groupId]
    if not group then return end

    if GroupEntities[groupId] and GroupEntities[groupId].wagonsSpawned then
        DebugPrint('Stagecoach already spawned for group ' .. groupId .. ', skipping')
        return
    end

    group.wagons = {}
    local spawnPoint = Config.SpawnPoints[1]
    if spawnPoint then
        local wagonData = {
            id = 1,
            position = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z),
            health = 1000,
            npcHealth = 200,
            alive = true,
            heading = spawnPoint.w or 0.0
        }
        table.insert(group.wagons, wagonData)
    end

    if not GroupEntities[groupId] then GroupEntities[groupId] = {} end
    GroupEntities[groupId].wagonsSpawned = true
    GroupEntities[groupId].spawnedBy = group.leader

    DebugPrint('Spawning stagecoach for group ' .. groupId .. ' with ' .. #group.members .. ' members')
    TriggerClientEvent('deadwood-stage:client:spawnStagecoach', group.leader, group.wagons)

    ActiveMissions[groupId] = {
        wagons = group.wagons,
        startTime = os.time(),
        state = 'active'
    }
end

local function CheckStagecoachStatus(groupId)
    local group = MissionGroups[groupId]
    if not group then return 0 end
    for _, wagon in ipairs(group.wagons) do
        if wagon.alive then return 1 end
    end
    return 0
end

local function PayoutRewards(groupId, amount, message)
    local group = MissionGroups[groupId]
    if not group then return end
    for i, member in ipairs(group.members) do
        local Player = RSGCore.Functions.GetPlayer(member)
        if Player then Player.Functions.AddMoney(Config.Currency, amount) end
    end
    for i, member in ipairs(group.members) do
        TriggerClientEvent('deadwood-stage:client:notify', member, {
            title = _('server_mission_reward'),
            description = message,
            type = "success",
            duration = Config.NotificationDuration
        })
    end
end

local function EndMission(groupId, success)
    local group = MissionGroups[groupId]
    if not group then return end

    for i, member in ipairs(group.members) do
        TriggerClientEvent('deadwood-stage:client:cleanup', member)
    end

    if success then
        group.state = Config.States.COMPLETED
    else
        group.state = Config.States.FAILED
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:notify', member, {
                title = _('server_mission_failed'),
                description = _('server_mission_failed_desc'),
                type = "error",
                duration = Config.NotificationDuration
            })
        end
    end

    SetTimeout(30000, function()
        MissionGroups[groupId] = nil
        GroupEntities[groupId] = nil
    end)
end

RegisterNetEvent('deadwood-stage:server:createGroup', function()
    local source = source
    local groupId, _ = GetPlayerGroup(source)
    if groupId then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_group_error'), description = _('error_already_in_group'), type = "error"
        })
        return
    end
    groupId = CreateMissionGroup(source)
    TriggerClientEvent('deadwood-stage:client:groupCreated', source, groupId)
end)

RegisterNetEvent('deadwood-stage:server:joinGroup', function(groupId)
    local source = source
    if not AddPlayerToGroup(groupId, source) then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_group_error'), description = _('error_group_full'), type = "error"
        })
        return
    end
    local group = MissionGroups[groupId]
    for i, member in ipairs(group.members) do
        TriggerClientEvent('deadwood-stage:client:updateGroup', member, group.members)
    end
end)

RegisterNetEvent('deadwood-stage:server:createRouteGPS', function(destination)
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if group then
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:createRouteGPS', member, destination)
        end
        DebugPrint('GPS route sent to all members of group ' .. groupId)
    end
end)

RegisterNetEvent('deadwood-stage:server:triggerBanditAttack', function(attackLocation)
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if not group then
        DebugPrint('Player ' .. source .. ' not in a group, cannot trigger bandit attack')
        return
    end

    if not GroupEntities[groupId] then GroupEntities[groupId] = { triggeredAttacks = {} } end
    if not GroupEntities[groupId].triggeredAttacks then GroupEntities[groupId].triggeredAttacks = {} end

    local attackKey = attackLocation.name or (attackLocation.location.x .. '_' .. attackLocation.location.y)
    if GroupEntities[groupId].triggeredAttacks[attackKey] then
        DebugPrint('Attack at ' .. attackKey .. ' already triggered for group ' .. groupId)
        return
    end

    local currentTime = os.time()
    if BanditCooldown - currentTime > 0 then
        DebugPrint('Bandit cooldown active')
        return
    end

    GroupEntities[groupId].triggeredAttacks[attackKey] = true
    BanditCooldown = currentTime + Config.BanditCooldownTime

    DebugPrint('Bandit attack at ' .. attackLocation.name .. ' - leader spawns, others notified')
    TriggerClientEvent('deadwood-stage:client:spawnBanditsLeader', group.leader, attackLocation)

    for i, member in ipairs(group.members) do
        if member ~= group.leader then
            TriggerClientEvent('deadwood-stage:client:banditAttackNotify', member, attackLocation)
        end
    end
end)

RegisterNetEvent('deadwood-stage:server:startMission', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)

    if not group then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_mission_error'), description = _('error_no_group'), type = "error"
        })
        return
    end

    if group.leader ~= source then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_mission_error'), description = _('error_not_leader'), type = "error"
        })
        return
    end

    if not Config.TestMode and #group.members < Config.MinPlayers then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_mission_error'), description = _('error_min_players', Config.MinPlayers), type = "error"
        })
        return
    end

    if Config.TestMode then
        TriggerClientEvent('deadwood-stage:client:notify', source, {
            title = _('server_test_mode'), description = _('server_test_mode_desc'), type = "inform"
        })
    end

    group.state = Config.States.STARTED
    group.startTime = GetGameTimer()

    SpawnStagecoach(groupId)

    for i, member in ipairs(group.members) do
        TriggerClientEvent('deadwood-stage:client:missionStarted', member, groupId)
        TriggerClientEvent('deadwood-stage:client:notify', member, {
            title = _('mission_title'), description = _('server_stagecoach_rolling'), type = "success"
        })
    end
end)

RegisterNetEvent('deadwood-stage:server:endMission', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)

    if not group then
        DebugPrint('Player ' .. source .. ' not in a group, nothing to end')
        return
    end

    DebugPrint('Player ' .. source .. ' ending mission for group ' .. groupId)

    if group.leader == source then
        for i, member in ipairs(group.members) do
            if member ~= source then
                TriggerClientEvent('deadwood-stage:client:missionEnded', member)
            end
        end
        MissionGroups[groupId] = nil
        GroupEntities[groupId] = nil
        ActiveMissions[groupId] = nil
    else
        for i, member in ipairs(group.members) do
            if member == source then
                table.remove(group.members, i)
                break
            end
        end
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:updateGroup', member, group.members)
        end
    end
end)

RegisterNetEvent('deadwood-stage:server:sendJourneyInstructions', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if not group then return end

    SetTimeout(30000, function()
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:showJourneyInstructions', member)
        end
    end)
end)

RegisterNetEvent('deadwood-stage:server:completeMission', function(survivingPassengers)
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if not group then return end

    DebugPrint('Mission completed with ' .. survivingPassengers .. ' surviving passengers')

    local finalReward = Config.WagonReward + (survivingPassengers * Config.PassengerReward)

    for i, member in ipairs(group.members) do
        local Player = RSGCore.Functions.GetPlayer(member)
        if Player then
            Player.Functions.AddMoney(Config.Currency, finalReward)
            DebugPrint("Paid player " .. member .. " amount: $" .. finalReward)
        end
    end

    for i, member in ipairs(group.members) do
        TriggerClientEvent('deadwood-stage:client:notify', member, {
            title = _('server_mission_completed'),
            description = _('server_mission_completed_desc', finalReward, survivingPassengers),
            type = "success",
            duration = 10000
        })
    end

    group.state = Config.States.COMPLETED

    SetTimeout(30000, function()
        MissionGroups[groupId] = nil
        if ActiveMissions[groupId] then ActiveMissions[groupId] = nil end
        DebugPrint("Cleaned up completed mission group " .. groupId)
    end)
end)

RegisterNetEvent('deadwood-stage:server:stagecoachDestroyed', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if not group then return end

    for _, wagon in ipairs(group.wagons) do
        wagon.alive = false
    end

    local alive = CheckStagecoachStatus(groupId)
    if alive == 0 then
        EndMission(groupId, false)
    end
end)

local DeadPlayers = {}

RegisterNetEvent('deadwood-stage:server:playerDied', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if not group then return end

    if not DeadPlayers[groupId] then DeadPlayers[groupId] = {} end
    DeadPlayers[groupId][source] = true

    DebugPrint('Player ' .. source .. ' died in group ' .. groupId)

    local allDead = true
    for i, member in ipairs(group.members) do
        if not DeadPlayers[groupId][member] then
            allDead = false
            break
        end
    end

    if allDead and #group.members > 0 then
        DebugPrint('All players in group ' .. groupId .. ' are dead - ending mission')
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:notify', member, {
                title = _('all_players_dead_title'), description = _('all_players_dead'), type = 'error', duration = 10000
            })
            TriggerClientEvent('deadwood-stage:client:cleanup', member)
        end
        group.state = Config.States.FAILED
        SetTimeout(15000, function()
            MissionGroups[groupId] = nil
            GroupEntities[groupId] = nil
            ActiveMissions[groupId] = nil
            DeadPlayers[groupId] = nil
        end)
    end
end)

RegisterNetEvent('deadwood-stage:server:playerRespawned', function()
    local source = source
    local groupId, _ = GetPlayerGroup(source)
    if not groupId then return end
    if DeadPlayers[groupId] then DeadPlayers[groupId][source] = nil end
    DebugPrint('Player ' .. source .. ' respawned in group ' .. groupId)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local groupId, group = GetPlayerGroup(source)
    if group then
        for i, member in ipairs(group.members) do
            if member == source then table.remove(group.members, i); break end
        end
        if group.leader == source then
            if #group.members > 0 then
                group.leader = group.members[1]
                TriggerClientEvent('deadwood-stage:client:notify', group.leader, {
                    title = _('server_new_leader'), description = _('server_new_leader_desc'), type = "inform"
                })
            else
                EndMission(groupId, false)
            end
        end
        for i, member in ipairs(group.members) do
            TriggerClientEvent('deadwood-stage:client:updateGroup', member, group.members)
        end
    end
end)
