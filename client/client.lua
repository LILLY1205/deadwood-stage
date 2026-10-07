

local RSGCore = exports['rsg-core']:GetCoreObject()

-- State Variables
local currentGroup = nil
local missionActive = false
local spawnedWagons = {}
local spawnedNPCs = {}
local spawnedBandits = {}
local banditAttackTriggered = false
local wagonTargetsSetup = false
local missionArrived = false
local currentAttackLocation = nil
local currentWagonSpeed = Config.WagonSpeeds.Base
local wagonsSpooked = false
local startBlip = nil
local startNPC = nil
local destinationBlip = nil
local wagonBlips = {}
local triggeredAttacks = {}

-- Deadwood Stage specific
local passengers = {}
local driverDeadTimer = nil
local driverDeadTimerActive = false
local playerIsDriver = false
local driverTargetAdded = false
local currentDriverPed = nil

local function DebugPrint(msg)
    if Config.Debug then print('[DEADWOOD-STAGE] ' .. tostring(msg)) end
end

local function ShowNotification(data)
    local template = nil
    if data.type == 'success' then template = 'SUCCESS'
    elseif data.type == 'error' then template = 'ERROR'
    elseif data.type == 'inform' then template = 'INFO' end
    TriggerEvent('bln_notify:send', {
        title = data.title or '', description = data.description or '',
        icon = data.icon or 'warning', placement = data.placement or 'middle-right',
        duration = data.duration or Config.NotificationDuration
    }, template)
end

local function LoadModel(model)
    local hash = GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local attempts = 0
        while not HasModelLoaded(hash) and attempts < 100 do
            Wait(10); attempts = attempts + 1
        end
        if not HasModelLoaded(hash) then
            DebugPrint('ERROR: Failed to load model: ' .. model); return false
        end
    end
    return hash
end

-- ============================================================
-- NUI Menu Functions
-- ============================================================
local function OpenNUIMenu()
    SendNUIMessage({
        action = 'openStagecoachMenu',
        inGroup = currentGroup ~= nil,
        missionActive = missionActive,
        groupId = currentGroup
    })
    SetNuiFocus(true, true)
end

local function CloseNUIMenu()
    SendNUIMessage({ action = 'closeAll' })
    SetNuiFocus(false, false)
end

RegisterNuiCallback('closeUI', function(_, cb) CloseNUIMenu(); cb('ok') end)

RegisterNuiCallback('createGroup', function(_, cb)
    CloseNUIMenu(); TriggerServerEvent('deadwood-stage:server:createGroup'); cb('ok')
end)

RegisterNuiCallback('joinGroup', function(data, cb)
    CloseNUIMenu()
    local groupId = tonumber(data.groupId)
    if groupId then
        TriggerServerEvent('deadwood-stage:server:joinGroup', groupId)
    else
        ShowNotification({ title = _('error_no_group'), description = _('error_no_group'), type = 'error' })
    end
    cb('ok')
end)

RegisterNuiCallback('startMission', function(_, cb)
    CloseNUIMenu(); TriggerServerEvent('deadwood-stage:server:startMission'); cb('ok')
end)

RegisterNuiCallback('leaveGroup', function(_, cb)
    CloseNUIMenu(); currentGroup = nil; missionActive = false
    CleanupEntities()
    ShowNotification({ title = _('group_left'), description = _('group_left_desc'), type = 'inform' })
    cb('ok')
end)

RegisterNuiCallback('endMission', function(_, cb)
    CloseNUIMenu(); TriggerServerEvent('deadwood-stage:server:endMission')
    CleanupMission()
    ShowNotification({ title = _('mission_ended'), description = _('mission_ended_desc'), type = 'inform' })
    cb('ok')
end)

RegisterNuiCallback('startStagecoach', function(_, cb)
    CloseNUIMenu(); StartStagecoachMovement(); cb('ok')
end)

RegisterNuiCallback('speedUp', function(_, cb)
    CloseNUIMenu(); SpeedUpStagecoach(); cb('ok')
end)

RegisterNuiCallback('slowDown', function(_, cb)
    CloseNUIMenu(); SlowDownStagecoach(); cb('ok')
end)

RegisterNuiCallback('haltStagecoach', function(_, cb)
    CloseNUIMenu(); HaltStagecoach(); cb('ok')
end)

RegisterNuiCallback('holdPosition', function(_, cb)
    CloseNUIMenu(); HoldPosition(); cb('ok')
end)

-- ============================================================
-- Blip Helpers
-- ============================================================
local function CreateBlipAt(coords, blipCfg)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z, 10.0)
    if blip and DoesBlipExist(blip) then
        SetBlipSprite(blip, blipCfg.sprite, 1)
        SetBlipScale(blip, blipCfg.scale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipCfg.name)
        if blipCfg.shortRange then Citizen.InvokeNative(0xD38744167B2FA257, blip, true) end
    else
        DebugPrint('Failed to create blip: ' .. blipCfg.name)
    end
    return blip
end

local function RemoveWagonBlips()
    for _, blip in pairs(wagonBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    wagonBlips = {}
end

local function CreateWagonBlips()
    RemoveWagonBlips()
    if not Config.ShowBlips then return end
    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.npc) then
            local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 0x318C617C, wagonInfo.npc)
            if blip then
                SetBlipSprite(blip, Config.Blips.Stagecoach.sprite, true)
                SetBlipScale(blip, Config.Blips.Stagecoach.scale)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blips.Stagecoach.name)
                wagonBlips[wagonId] = blip
            end
        end
    end
end

-- ============================================================
-- Cleanup Functions
-- ============================================================
local function CleanupEntities()
    for _, wagon in pairs(spawnedWagons) do
        if DoesEntityExist(wagon.entity) then DeleteEntity(wagon.entity) end
    end
    for _, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc) then DeleteEntity(npc) end
    end
    for _, p in pairs(passengers) do
        if DoesEntityExist(p.ped) then DeleteEntity(p.ped) end
    end
    for _, bandit in pairs(spawnedBandits) do
        if DoesEntityExist(bandit.ped) then DeleteEntity(bandit.ped) end
        if DoesEntityExist(bandit.horse) then DeleteEntity(bandit.horse) end
    end
    if destinationBlip and DoesBlipExist(destinationBlip) then
        RemoveBlip(destinationBlip); destinationBlip = nil
    end
    RemoveWagonBlips()
    spawnedWagons = {}; spawnedNPCs = {}; passengers = {}; spawnedBandits = {}
    banditAttackTriggered = false; wagonTargetsSetup = false; wagonsSpooked = false
    driverDeadTimerActive = false; playerIsDriver = false; driverTargetAdded = false; currentDriverPed = nil
    if driverDeadTimer then SetTimeout(driverDeadTimer, function() end); driverDeadTimer = nil end
end

function CleanupMission()
    DebugPrint('Cleaning up mission...')
    if Config.ShowGPS then SetGpsMultiRouteRender(false); ClearGpsMultiRoute() end
    CleanupEntities()
    missionActive = false; currentGroup = nil; missionArrived = false
    banditAttackTriggered = false; wagonTargetsSetup = false
    currentWagonSpeed = Config.WagonSpeeds.Base; wagonsSpooked = false; triggeredAttacks = {}
end

local function CompleteCleanup()
    DebugPrint('Performing complete cleanup...')
    if Config.ShowGPS then SetGpsMultiRouteRender(false); ClearGpsMultiRoute() end
    if startBlip and DoesBlipExist(startBlip) then RemoveBlip(startBlip); startBlip = nil end
    if startNPC and DoesEntityExist(startNPC) then DeleteEntity(startNPC); startNPC = nil end
    CleanupEntities()
    currentGroup = nil; missionActive = false; missionArrived = false
    banditAttackTriggered = false; currentWagonSpeed = Config.WagonSpeeds.Base; wagonsSpooked = false; triggeredAttacks = {}
end

-- ============================================================
-- Stagecoach Spawning
-- ============================================================
local function SpawnPassengers(wagonEntity)
    if not DoesEntityExist(wagonEntity) then return end
    DebugPrint('Spawning ' .. Config.PassengerCount .. ' passengers')

    local coords = GetEntityCoords(wagonEntity)
    local heading = GetEntityHeading(wagonEntity)

    for i = 1, Config.PassengerCount do
        local seat = Config.PassengerSeats[i]
        if seat == nil then break end

        local model = Config.PassengerModels[math.random(1, #Config.PassengerModels)]
        local phash = LoadModel(model)
        if not phash then break end

        local offsetX = coords.x + (math.random(5, 8) * math.cos(math.rad(heading + 90)))
        local offsetY = coords.y + (math.random(5, 8) * math.sin(math.rad(heading + 90)))
        local fg, groundZ = GetGroundZFor_3dCoord(offsetX, offsetY, coords.z + 10.0)
        local spawnZ = fg and groundZ or coords.z
        local passenger = CreatePed(phash, offsetX, offsetY, spawnZ, heading, true, false)

        if DoesEntityExist(passenger) then
            SetEntityAsMissionEntity(passenger, true, true)
            SetPedCanBeTargetted(passenger, true)
            SetEntityCanBeDamaged(passenger, true)
            SetRandomOutfitVariation(passenger, true)

            local seated = SetPedIntoVehicle(passenger, wagonEntity, seat)
            if not seated then
                TaskEnterVehicle(passenger, wagonEntity, 10000, seat, 1.0, 1, 0)
                DebugPrint('Passenger ' .. i .. ' walking to seat ' .. seat)
            else
                DebugPrint('Passenger ' .. i .. ' placed directly in seat ' .. seat)
            end

            table.insert(passengers, {
                ped = passenger,
                seat = seat,
                model = model,
                alive = true,
                entering = not seated
            })
        else
            DebugPrint('ERROR: Failed to create passenger ' .. i)
        end
    end
end

local function SpawnWagon(wagonData)
    DebugPrint('Loading models for stagecoach')
    local modelHash = LoadModel(Config.WagonModel)
    if not modelHash then
        DebugPrint('ERROR: Failed to load coach model!'); return nil
    end

    local foundGround, groundZ = GetGroundZFor_3dCoord(wagonData.position.x, wagonData.position.y, wagonData.position.z + 10.0)
    local spawnZ = foundGround and groundZ or wagonData.position.z
    local spawnHeading = wagonData.heading or 0.0

    local wagon = CreateVehicle(modelHash, wagonData.position.x, wagonData.position.y, spawnZ, spawnHeading, true, false)
    if not DoesEntityExist(wagon) then
        DebugPrint('ERROR: Failed to create stagecoach!'); return nil
    end

    SetEntityAsMissionEntity(wagon, true, true)
    SetVehicleOnGroundProperly(wagon)
    SetEntityHeading(wagon, spawnHeading)
    FreezeEntityPosition(wagon, false)
    DebugPrint('Stagecoach spawned with heading ' .. spawnHeading)

    -- Spawn driver (try each model until one succeeds)
    local dhash
    local driverModel
    local shuffledModels = {}
    for i, m in ipairs(Config.DriverModels) do shuffledModels[i] = m end
    for i = #shuffledModels, 2, -1 do
        local j = math.random(1, i)
        shuffledModels[i], shuffledModels[j] = shuffledModels[j], shuffledModels[i]
    end
    for i, model in ipairs(shuffledModels) do
        dhash = LoadModel(model)
        if dhash then driverModel = model; break end
    end
    if not dhash then
        DebugPrint('ERROR: Failed to load any driver model'); DeleteVehicle(wagon); return nil
    end

    local npcSpawnX = wagonData.position.x + 2.0
    local npcSpawnY = wagonData.position.y
    local npcSpawnZ = spawnZ
    local fg, ngz = GetGroundZFor_3dCoord(npcSpawnX, npcSpawnY, npcSpawnZ + 10.0)
    if fg then npcSpawnZ = ngz end

    local npc = CreatePed(dhash, npcSpawnX, npcSpawnY, npcSpawnZ, 0.0, true, false)
    if not DoesEntityExist(npc) then
        DebugPrint('ERROR: Failed to create driver'); DeleteVehicle(wagon); return nil
    end

    SetEntityAsMissionEntity(npc, true, true)
    SetPedCanBeTargetted(npc, false)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatAttributes(npc, 17, true)
    SetEntityVisible(npc, true); SetEntityAlpha(npc, 255, false)
    SetEntityCanBeDamaged(npc, true)
    SetRandomOutfitVariation(npc, true)
    SetEntityNoCollisionEntity(npc, wagon, false)

    local defenderGroup = GetHashKey('STAGECOACH_DEFENDERS')
    local playerGroup = GetHashKey('PLAYER')
    AddRelationshipGroup('STAGECOACH_DEFENDERS')
    SetPedRelationshipGroupHash(npc, defenderGroup)
    SetRelationshipBetweenGroups(1, defenderGroup, playerGroup)
    SetRelationshipBetweenGroups(1, playerGroup, defenderGroup)

    Wait(500)
    SetPedIntoVehicle(npc, wagon, -1)
    currentDriverPed = npc
    DebugPrint('Driver spawned: ' .. driverModel)

    local wagonInfo = {
        id = wagonData.id, entity = wagon, npc = npc,
        health = wagonData.health, npcHealth = wagonData.npcHealth, alive = true
    }
    spawnedWagons[wagonData.id] = wagonInfo
    spawnedNPCs[#spawnedNPCs + 1] = npc

    -- Spawn passengers (pcall to prevent errors from blocking targets)
    local ok, spawnErr = pcall(SpawnPassengers, wagon)
    if not ok then
        DebugPrint('ERROR in SpawnPassengers: ' .. tostring(spawnErr))
    end

    return wagonInfo
end

-- ============================================================
-- Start NPC & Blip
-- ============================================================
local function CreateStartBlip()
    startBlip = CreateBlipAt(Config.StartLocation, Config.Blips.StartLocation)
end

local function SpawnStartNPC()
    local npcHash = LoadModel(Config.StartNPC.model)
    if not npcHash then DebugPrint('Failed to load start NPC model'); return end

    local x, y, z, heading = Config.StartNPC.coords.x, Config.StartNPC.coords.y, Config.StartNPC.coords.z, Config.StartNPC.coords.w
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 10.0)
    local spawnZ = foundGround and groundZ or z

    startNPC = CreatePed(npcHash, x, y, spawnZ, heading, false, false)
    if DoesEntityExist(startNPC) then
        SetEntityAsMissionEntity(startNPC, true, true)
        FreezeEntityPosition(startNPC, true); SetEntityInvincible(startNPC, true)
        SetBlockingOfNonTemporaryEvents(startNPC, true)
        SetPedCanBeTargetted(startNPC, false); SetEntityCanBeDamaged(startNPC, false)
        SetEntityVisible(startNPC, true); SetEntityAlpha(startNPC, 255, false)
        Citizen.InvokeNative(0x283978A15512B2FE, startNPC, true)
        SetRandomOutfitVariation(startNPC, true)
    else
        DebugPrint('Failed to spawn start NPC')
    end
end

local function SetupMissionStart()
    CreateStartBlip(); SpawnStartNPC(); Wait(1000)
    if startNPC and DoesEntityExist(startNPC) then
        exports['rsg-target']:AddTargetEntity(startNPC, {
            options = {{ type = 'client', event = 'deadwood-stage:client:openMenu', icon = 'fa-solid fa-horse', label = _('start_mission') }},
            distance = Config.StartNPC.interactionDistance
        })
    end
end

-- ============================================================
-- Wagon Target System
-- ============================================================
local function SetupWagonTargets()
    DebugPrint('Setting up wagon targets...')
    local targetOptions = {
        { type = 'client', event = 'deadwood-stage:client:startStagecoachMovement', icon = 'fa-solid fa-play', label = _('start_stagecoach') },
        { type = 'client', event = 'deadwood-stage:client:speedUpStagecoach', icon = 'fa-solid fa-fast-forward', label = _('speed_up') },
        { type = 'client', event = 'deadwood-stage:client:slowDownStagecoach', icon = 'fa-solid fa-backward', label = _('slow_down') },
        { type = 'client', event = 'deadwood-stage:client:haltStagecoach', icon = 'fa-solid fa-stop', label = _('halt_stagecoach') },
        { type = 'client', event = 'deadwood-stage:client:holdPosition', icon = 'fa-solid fa-pause', label = _('hold_position') }
    }
    pcall(function() exports['rsg-target']:RemoveTargetModel(Config.WagonModel) end)
    local success = pcall(function()
        exports['rsg-target']:AddTargetModel(Config.WagonModel, { options = targetOptions, distance = 5.0 })
    end)
    if not success then DebugPrint('ERROR: Failed to setup rsg-target') end
end

local function SetupDriverTarget()
    DebugPrint('Setting up take-reins target...')
    driverTargetAdded = true
    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if DoesEntityExist(wagonInfo.entity) then
            exports['rsg-target']:AddTargetEntity(wagonInfo.entity, {
                options = {{ type = 'client', event = 'deadwood-stage:client:takeReins', icon = 'fa-solid fa-horse', label = _('take_reins') }},
                distance = 3.0
            })
        end
    end
end

-- ============================================================
-- Stagecoach Movement
-- ============================================================
function StartStagecoachMovement()
    local dest = Config.EndLocation
    DebugPrint('StartStagecoachMovement to ' .. dest.x .. ', ' .. dest.y .. ', ' .. dest.z)
    TriggerServerEvent('deadwood-stage:server:createRouteGPS', dest)

    local driver = playerIsDriver and PlayerPedId() or currentDriverPed

    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) and DoesEntityExist(driver) then
            ClearPedTasks(driver); Wait(50)
            TaskVehicleDriveToCoord(driver, wagonInfo.entity, dest.x, dest.y, dest.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
        end
    end

    ShowNotification({ title = _('stagecoach_moving'), description = _('stagecoach_moving_desc'), type = 'success' })
    TriggerServerEvent('deadwood-stage:server:sendJourneyInstructions')
end

function SpeedUpStagecoach()
    if currentWagonSpeed < Config.SPEED_MEDIUM then
        currentWagonSpeed = Config.SPEED_MEDIUM
    elseif currentWagonSpeed < Config.SPEED_FAST then
        currentWagonSpeed = Config.SPEED_FAST
    end
    local speedName = currentWagonSpeed == Config.SPEED_SLOW and 'Slow' or (currentWagonSpeed == Config.SPEED_MEDIUM and 'Medium' or 'Fast')
    local driver = playerIsDriver and PlayerPedId() or currentDriverPed

    for _, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) and DoesEntityExist(driver) then
            ClearPedTasks(driver); Wait(100)
            TaskVehicleDriveToCoord(driver, wagonInfo.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
        end
    end
    ShowNotification({ title = _('stagecoach_speeding_up'), description = 'Speed: ' .. speedName, type = 'inform' })
end

function SlowDownStagecoach()
    if currentWagonSpeed > Config.SPEED_MEDIUM then
        currentWagonSpeed = Config.SPEED_MEDIUM
    elseif currentWagonSpeed > Config.SPEED_SLOW then
        currentWagonSpeed = Config.SPEED_SLOW
    end
    local speedName = currentWagonSpeed == Config.SPEED_SLOW and 'Slow' or (currentWagonSpeed == Config.SPEED_MEDIUM and 'Medium' or 'Fast')
    local driver = playerIsDriver and PlayerPedId() or currentDriverPed

    for _, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) and DoesEntityExist(driver) then
            ClearPedTasks(driver); Wait(100)
            TaskVehicleDriveToCoord(driver, wagonInfo.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
        end
    end
    ShowNotification({ title = _('stagecoach_slowing_down'), description = 'Speed: ' .. speedName, type = 'inform' })
end

function HaltStagecoach()
    local driver = playerIsDriver and PlayerPedId() or nil
    for _, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) then
            if DoesEntityExist(wagonInfo.npc) then ClearPedTasks(wagonInfo.npc) end
            SetVehicleForwardSpeed(wagonInfo.entity, 0.0)
        end
    end
    if playerIsDriver and DoesEntityExist(driver) then
        ClearPedTasks(driver)
        local veh = GetVehiclePedIsIn(driver, false)
        if DoesEntityExist(veh) then SetVehicleForwardSpeed(veh, 0.0) end
    end
    ShowNotification({ title = _('stagecoach_halted'), description = _('stagecoach_halted_desc'), type = 'inform' })
end

-- ============================================================
-- Hold Position (renamed from Regroup)
-- ============================================================
function HoldPosition()
    DebugPrint('Hold Position...')
    local aliveWagon = nil
    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) then
            aliveWagon = wagonInfo; break
        end
    end

    if not aliveWagon then
        ShowNotification({ title = _('hold_failed'), description = _('hold_failed_desc'), type = 'error' }); return
    end

    local driver = playerIsDriver and PlayerPedId() or currentDriverPed
    if DoesEntityExist(driver) then
        ClearPedTasks(driver); SetVehicleForwardSpeed(aliveWagon.entity, 0.0)
    end

    ShowNotification({ title = _('stagecoach_hold'), description = _('stagecoach_hold_desc'), type = 'inform' })

    SetTimeout(10000, function()
        DebugPrint('Resuming after hold')
        if missionActive and not missionArrived then
            local resumeDriver = playerIsDriver and PlayerPedId() or currentDriverPed
            if aliveWagon.alive and DoesEntityExist(aliveWagon.entity) and DoesEntityExist(resumeDriver) then
                ClearPedTasks(resumeDriver); Wait(50)
                TaskVehicleDriveToCoord(resumeDriver, aliveWagon.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
            end
            ShowNotification({ title = _('stagecoach_resuming'), description = _('stagecoach_resuming_desc'), type = 'success' })
        end
    end)
end

-- ============================================================
-- Spook / Calm
-- ============================================================
local function SpookStagecoach()
    if wagonsSpooked then return end
    wagonsSpooked = true
    currentWagonSpeed = Config.WagonSpeeds.Spooked
    DebugPrint('Stagecoach spooked! Speed: ' .. currentWagonSpeed)

    local driver = playerIsDriver and PlayerPedId() or currentDriverPed
    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) and DoesEntityExist(driver) then
            ClearPedTasks(driver); Wait(100)
            TaskVehicleDriveToCoord(driver, wagonInfo.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
        end
    end
    ShowNotification({ title = _('stagecoach_spooked'), description = _('stagecoach_spooked_desc'), type = 'error', duration = 5000 })
end

local function CalmStagecoach()
    if not wagonsSpooked then return end
    wagonsSpooked = false
    currentWagonSpeed = Config.WagonSpeeds.Calm
    DebugPrint('Stagecoach calmed. Speed: ' .. currentWagonSpeed)

    local driver = playerIsDriver and PlayerPedId() or currentDriverPed
    for wagonId, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) and DoesEntityExist(driver) then
            ClearPedTasks(driver); Wait(100)
            TaskVehicleDriveToCoord(driver, wagonInfo.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
        end
    end
    ShowNotification({ title = _('stagecoach_calmed'), description = _('stagecoach_calmed_desc'), type = 'success', duration = 5000 })
end

-- ============================================================
-- Driver Death Handler
-- ============================================================
local function StartDriverDeathTimer()
    if driverDeadTimerActive then return end
    driverDeadTimerActive = true
    DebugPrint('Driver death timer started (' .. Config.DriverDeathTimer .. 'ms)')

    local remaining = math.floor(Config.DriverDeathTimer / 1000)

    driverDeadTimer = SetTimeout(Config.DriverDeathTimer, function()
        if driverDeadTimerActive and missionActive and not playerIsDriver then
            DebugPrint('Driver death timer expired - mission failed')
            ShowNotification({ title = _('driver_dead_expired'), description = _('driver_dead_expired'), type = 'error', duration = 10000 })
            CleanupMission()
            TriggerServerEvent('deadwood-stage:server:endMission')
        end
        driverDeadTimerActive = false
    end)

    CreateThread(function()
        while driverDeadTimerActive and remaining > 0 and missionActive do
            if not playerIsDriver then
                ShowNotification({ title = _('driver_dead'), description = _('driver_dead_timer', remaining), type = 'error', duration = 4000 })
            end
            remaining = remaining - 5
            Wait(5000)
        end
    end)

    if not driverTargetAdded then SetupDriverTarget() end
end

-- ============================================================
-- Robber System (Stagecoach Robbers)
-- ============================================================
local function SpawnBandits(attackLocation, banditCount)
    DebugPrint('Spawning ' .. banditCount .. ' robbers at ' .. (attackLocation.name or 'Unknown'))
    SpookStagecoach()

    local dismountCount = attackLocation.dismountCount or 0

    for i = 1, banditCount do
        local angle = math.random() * 2 * math.pi
        local dist = math.random(20, 40)
        local spawnPos = {
            x = attackLocation.location.x + (dist * math.cos(angle)),
            y = attackLocation.location.y + (dist * math.sin(angle)),
            z = attackLocation.location.z + 2.0
        }
        local banditModel = Config.BanditModels[math.random(1, #Config.BanditModels)]
        local horseModel = Config.BanditHorses[math.random(1, #Config.BanditHorses)]
        local weapon = Config.BanditWeapons[math.random(1, #Config.BanditWeapons)]
        local shouldDismount = i <= dismountCount

        local banditHash = LoadModel(banditModel)
        local horseHash = LoadModel(horseModel)
        if not (banditHash and horseHash) then break end

        local horse = CreatePed(horseHash, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, false)
        if DoesEntityExist(horse) then
            SetEntityAsMissionEntity(horse, true, true)
            Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, 0x20359E53, true, true, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, 0x508B80B9, true, true, true)

            local bandit = CreatePed(banditHash, spawnPos.x + 1, spawnPos.y, spawnPos.z, math.random(0, 360), true, false)
            if DoesEntityExist(bandit) then
                SetEntityAsMissionEntity(bandit, true, true)
                Citizen.InvokeNative(0x283978A15512B2FE, bandit, true)
                SetPedCombatAttributes(bandit, 5, true)
                SetPedCombatAttributes(bandit, 46, true)
                SetPedAccuracy(bandit, 60)

                local playerGroup = GetHashKey('PLAYER')
                local robberGroup = GetHashKey('ROBBER_GROUP')
                AddRelationshipGroup('ROBBER_GROUP')
                SetPedRelationshipGroupHash(bandit, robberGroup)
                SetRelationshipBetweenGroups(5, robberGroup, playerGroup)
                SetRelationshipBetweenGroups(5, playerGroup, robberGroup)

                GiveWeaponToPed(bandit, weapon, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
                SetCurrentPedWeapon(bandit, weapon, true)
                Wait(500)
                Citizen.InvokeNative(0x028F76B6E78246EB, bandit, horse, -1)

                if shouldDismount then
                    local coachEntity = nil
                    for _, w in pairs(spawnedWagons) do
                        if w.alive then coachEntity = w.entity; break end
                    end
                    if DoesEntityExist(coachEntity) then
                        TaskGoToEntity(bandit, coachEntity, -1, 5.0, 2.0, 0, 0)
                        SetTimeout(8000, function()
                            if DoesEntityExist(bandit) and not IsPedDeadOrDying(bandit, true) then
                                if currentDriverPed and DoesEntityExist(currentDriverPed) and not IsPedDeadOrDying(currentDriverPed, true) then
                                    TaskCombatPed(bandit, currentDriverPed)
                                elseif #passengers > 0 then
                                    for _, p in ipairs(passengers) do
                                        if p.alive and DoesEntityExist(p.ped) then
                                            TaskCombatPed(bandit, p.ped); break
                                        end
                                    end
                                else
                                    TaskCombatPed(bandit, PlayerPedId())
                                end
                            end
                        end)
                    end
                else
                    TaskCombatPed(bandit, PlayerPedId())
                    for _, wagonInfo in pairs(spawnedWagons) do
                        if wagonInfo.alive and DoesEntityExist(wagonInfo.npc) then
                            TaskCombatPed(bandit, wagonInfo.npc)
                        end
                    end
                end
                table.insert(spawnedBandits, { ped = bandit, horse = horse })
                DebugPrint('Robber ' .. i .. (shouldDismount and ' (dismount)' or ' (rider)'))
            end
        end
    end

    -- Arm driver
    for _, wagonInfo in pairs(spawnedWagons) do
        if wagonInfo.alive and DoesEntityExist(wagonInfo.npc) then
            local npc = wagonInfo.npc
            GiveWeaponToPed(npc, `WEAPON_REVOLVER_CATTLEMAN`, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
            SetCurrentPedWeapon(npc, `WEAPON_REVOLVER_CATTLEMAN`, true)
            SetPedCombatAttributes(npc, 2, true)
            SetPedCombatAttributes(npc, 3, false)
            SetPedCombatAttributes(npc, 5, true)
            SetPedCombatAttributes(npc, 46, true)
            SetPedCombatAttributes(npc, 1424, true)
            SetPedFleeAttributes(npc, 0, false)
            SetPedConfigFlag(npc, 58, true)
            SetPedConfigFlag(npc, 134, true)
            SetPedConfigFlag(npc, 394, true)

            local defenderGroup = GetHashKey('STAGECOACH_DEFENDERS')
            local robberGroup = GetHashKey('ROBBER_GROUP')
            local playerGroup = GetHashKey('PLAYER')
            AddRelationshipGroup('STAGECOACH_DEFENDERS')
            SetPedRelationshipGroupHash(npc, defenderGroup)
            SetRelationshipBetweenGroups(5, defenderGroup, robberGroup)
            SetRelationshipBetweenGroups(5, robberGroup, defenderGroup)
            SetRelationshipBetweenGroups(1, defenderGroup, playerGroup)
            SetRelationshipBetweenGroups(1, playerGroup, defenderGroup)

            for _, bandit in pairs(spawnedBandits) do
                if DoesEntityExist(bandit.ped) then
                    Citizen.InvokeNative(0x08DA95E8298AE772, npc, bandit.ped, -1, 0)
                end
            end
        end
    end

    ShowNotification({ title = _('robber_attack'), description = _('robber_attack_desc'), type = 'error', duration = 7000 })
end

local function CleanupBandits()
    DebugPrint('Cleaning up robbers...')
    for _, bandit in pairs(spawnedBandits) do
        if DoesEntityExist(bandit.ped) then DeleteEntity(bandit.ped) end
        if DoesEntityExist(bandit.horse) then DeleteEntity(bandit.horse) end
    end
    spawnedBandits = {}; banditAttackTriggered = false
end

-- ============================================================
-- Monitoring Threads
-- ============================================================
CreateThread(function()
    while true do
        Wait(3000)
        if missionActive then
            for wagonId, wagonInfo in pairs(spawnedWagons) do
                if wagonInfo.alive and DoesEntityExist(wagonInfo.npc) and IsPedDeadOrDying(wagonInfo.npc, true) then
                    if wagonInfo.npc == currentDriverPed then
                        local veh = wagonInfo.entity
                        local driverSeatEmpty = true
                        if DoesEntityExist(veh) then
                            local pedInSeat = GetPedInVehicleSeat(veh, -1)
                            if pedInSeat ~= 0 and pedInSeat ~= wagonInfo.npc then
                                driverSeatEmpty = false
                            end
                        end
                        if driverSeatEmpty and not playerIsDriver then
                            StartDriverDeathTimer()
                            ShowNotification({ title = _('driver_dead'), description = _('driver_dead_desc'), type = 'error', duration = 8000 })
                            if DoesEntityExist(wagonInfo.entity) then SetVehicleForwardSpeed(wagonInfo.entity, 0.0) end
                        end
                    end
                    wagonInfo.alive = false
                    if wagonBlips[wagonId] and DoesBlipExist(wagonBlips[wagonId]) then
                        RemoveBlip(wagonBlips[wagonId]); wagonBlips[wagonId] = nil
                    end
                end
            end

            for i, p in ipairs(passengers) do
                if p.alive and DoesEntityExist(p.ped) and IsPedDeadOrDying(p.ped, true) then
                    p.alive = false
                    ShowNotification({ title = _('passenger_lost'), description = _('passenger_lost_desc'), type = 'error', duration = 5000 })
                end
            end

            if banditAttackTriggered and #spawnedBandits > 0 then
                local aliveBandits = 0
                for _, bandit in pairs(spawnedBandits) do
                    if DoesEntityExist(bandit.ped) and not IsPedDeadOrDying(bandit.ped, true) then
                        aliveBandits = aliveBandits + 1
                    end
                end
                if aliveBandits == 0 then
                    DebugPrint('All robbers defeated!')
                    CalmStagecoach()
                    ShowNotification({ title = _('robbers_defeated'), description = _('robbers_defeated_desc'), type = 'success', duration = 5000 })
                    SetTimeout(10000, function() CleanupBandits() end)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if missionActive and not missionArrived then
            local playerPos = GetEntityCoords(PlayerPedId())
            for i, attackLocation in ipairs(Config.BanditAttackLocations) do
                local locationKey = 'attack_' .. i
                if not triggeredAttacks[locationKey] then
                    local dx = playerPos.x - attackLocation.location.x
                    local dy = playerPos.y - attackLocation.location.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < attackLocation.triggerDistance then
                        triggeredAttacks[locationKey] = true
                        TriggerServerEvent('deadwood-stage:server:triggerBanditAttack', attackLocation)
                        break
                    end
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if missionActive and not missionArrived then
            for wagonId, wagonInfo in pairs(spawnedWagons) do
                if wagonInfo.alive and DoesEntityExist(wagonInfo.entity) then
                    local dist = #(GetEntityCoords(wagonInfo.entity) - Config.EndLocation)
                    if dist < Config.WagonArrivalDistance then
                        missionArrived = true
                        DebugPrint('Stagecoach reached destination')
                        local driver = playerIsDriver and PlayerPedId() or currentDriverPed
                        if DoesEntityExist(driver) then
                            ClearPedTasks(driver)
                            SetVehicleForwardSpeed(wagonInfo.entity, 0.0)
                        end
                        TriggerEvent('deadwood-stage:client:startCompletion')
                        break
                    end
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    local wasDead = false
    while true do
        Wait(1000)
        if missionActive then
            local playerPed = PlayerPedId()
            local isDead = IsPedDeadOrDying(playerPed, true)
            if isDead and not wasDead then
                wasDead = true; TriggerServerEvent('deadwood-stage:server:playerDied')
            elseif not isDead and wasDead then
                wasDead = false; TriggerServerEvent('deadwood-stage:server:playerRespawned')
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        if missionActive then
            local alivePassengers = 0
            for _, p in ipairs(passengers) do
                if p.alive then alivePassengers = alivePassengers + 1 end
            end
            if #passengers > 0 then
                ShowNotification({ title = _('stagecoach_status'), description = _('passengers_surviving', alivePassengers, #passengers), type = 'inform', duration = 8000 })
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if missionActive and driverDeadTimerActive then
            for _, wagonInfo in pairs(spawnedWagons) do
                if DoesEntityExist(wagonInfo.entity) then
                    local pedInSeat = GetPedInVehicleSeat(wagonInfo.entity, -1)
                    if pedInSeat == PlayerPedId() and not playerIsDriver then
                        playerIsDriver = true
                        driverDeadTimerActive = false
                        if driverDeadTimer then
                            SetTimeout(driverDeadTimer, function() end)
                            driverDeadTimer = nil
                        end
                        ShowNotification({ title = _('reins_taken'), description = _('reins_taken_desc'), type = 'success', duration = 5000 })
                    end
                end
            end
        end
        if playerIsDriver and missionActive then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            local seat = GetPedInVehicleSeat(veh, -1)
            if seat ~= PlayerPedId() then
                playerIsDriver = false
                for _, wagonInfo in pairs(spawnedWagons) do
                    if DoesEntityExist(wagonInfo.entity) and not DoesEntityExist(currentDriverPed) then
                        StartDriverDeathTimer(); break
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if missionActive then
            local alive, total, changed, wagonLost = 0, 0, false, false
            for wagonId, wagonInfo in pairs(spawnedWagons) do
                total = total + 1
                local wExists = DoesEntityExist(wagonInfo.entity)
                if not wExists then
                    wagonInfo.alive = false; wagonLost = true; changed = true
                    if wagonBlips[wagonId] and DoesBlipExist(wagonBlips[wagonId]) then
                        RemoveBlip(wagonBlips[wagonId]); wagonBlips[wagonId] = nil
                    end
                elseif wagonInfo.alive then
                    local nExists = DoesEntityExist(wagonInfo.npc)
                    local nAlive = nExists and not IsPedDeadOrDying(wagonInfo.npc, true)
                    if not nAlive and not playerIsDriver and not driverDeadTimerActive then
                        StartDriverDeathTimer()
                        ShowNotification({ title = _('stagecoach_lost'), description = _('driver_killed'), type = 'error', duration = 6000 })
                    end
                    if nAlive or playerIsDriver or driverDeadTimerActive then
                        alive = alive + 1
                    end
                end
            end
            if wagonLost then
                ShowNotification({ title = _('mission_failed_all_lost'), description = _('all_passengers_dead'), type = 'error', duration = 10000 })
                TriggerEvent('deadwood-stage:client:missionFailed'); break
            elseif alive == 0 and total > 0 then
                ShowNotification({ title = _('stagecoach_update'), description = _('passengers_remaining', 0, #passengers), type = 'error', duration = 6000 })
            elseif changed and alive > 0 then
                local alivePass = 0
                for i, p in ipairs(passengers) do if p.alive then alivePass = alivePass + 1 end end
                ShowNotification({ title = _('stagecoach_update'), description = _('passengers_remaining', alivePass, #passengers), type = 'error', duration = 6000 })
            end
        end
        Wait(2000)
    end
end)




-- ============================================================
-- Event Handlers
-- ============================================================
RegisterNetEvent('deadwood-stage:client:openMenu', function() OpenNUIMenu() end)

RegisterNetEvent('deadwood-stage:client:createGroup', function()
    TriggerServerEvent('deadwood-stage:server:createGroup')
end)

RegisterNetEvent('deadwood-stage:client:startMission', function()
    TriggerServerEvent('deadwood-stage:server:startMission')
end)

RegisterNetEvent('deadwood-stage:client:leaveGroup', function()
    currentGroup = nil; missionActive = false; CleanupEntities()
    ShowNotification({ title = _('group_left'), description = _('group_left_desc'), type = 'inform' })
end)

RegisterNetEvent('deadwood-stage:client:startStagecoachMovement', function()
    StartStagecoachMovement()
end)

RegisterNetEvent('deadwood-stage:client:speedUpStagecoach', function()
    SpeedUpStagecoach()
end)

RegisterNetEvent('deadwood-stage:client:slowDownStagecoach', function()
    SlowDownStagecoach()
end)

RegisterNetEvent('deadwood-stage:client:haltStagecoach', function()
    HaltStagecoach()
end)

RegisterNetEvent('deadwood-stage:client:holdPosition', function()
    HoldPosition()
end)

RegisterNetEvent('deadwood-stage:client:endMission', function()
    DebugPrint('End mission')
    TriggerServerEvent('deadwood-stage:server:endMission')
    CleanupMission()
    ShowNotification({ title = _('mission_ended'), description = _('mission_ended_desc'), type = 'inform' })
end)

RegisterNetEvent('deadwood-stage:client:missionEnded', function()
    DebugPrint('Mission ended by leader'); CleanupMission()
    ShowNotification({ title = _('mission_ended'), description = _('mission_ended_leader'), type = 'inform' })
end)

RegisterNetEvent('deadwood-stage:client:groupCreated', function(groupId)
    currentGroup = groupId
    ShowNotification({ title = _('group_created'), description = _('group_created_desc', groupId), type = 'success' })
end)

RegisterNetEvent('deadwood-stage:client:updateGroup', function(members) end)

RegisterNetEvent('deadwood-stage:client:missionStarted', function(groupId)
    missionActive = true; currentGroup = groupId
    if destinationBlip and DoesBlipExist(destinationBlip) then RemoveBlip(destinationBlip) end
    destinationBlip = CreateBlipAt(Config.EndLocation, Config.Blips.Destination)
    if Config.ShowGPS then
        StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z)
        SetGpsMultiRouteRender(true)
    else
        SetNewWaypoint(Config.EndLocation.x, Config.EndLocation.y)
    end
end)

RegisterNetEvent('deadwood-stage:client:showJourneyInstructions', function()
    ShowNotification({ title = _('journey_title'), description = _('journey_desc'), type = 'inform', duration = 20000 })
end)

RegisterNetEvent('deadwood-stage:client:spawnStagecoach', function(wagonsData)
    DebugPrint('Received spawn stagecoach event')
    if next(spawnedWagons) ~= nil then
        DebugPrint('Stagecoach already spawned locally, skipping'); return
    end
    CleanupEntities()
    for i, wagonData in ipairs(wagonsData) do SpawnWagon(wagonData) end
    SetTimeout(5000, function()
        local valid = false
        for wagonId, wagonInfo in pairs(spawnedWagons) do
            if DoesEntityExist(wagonInfo.entity) and DoesEntityExist(wagonInfo.npc) then valid = true; break end
        end
        if valid then
            SetupWagonTargets(); CreateWagonBlips()
            DebugPrint('Wagon targets and blips set up')
        else
            DebugPrint('ERROR: No valid stagecoach found!')
        end
    end)
end)

RegisterNetEvent('deadwood-stage:client:spawnBanditsLeader')
AddEventHandler('deadwood-stage:client:spawnBanditsLeader', function(attackLocation)
    DebugPrint('Leader spawning robbers at ' .. (attackLocation.name or 'Unknown'))
    currentAttackLocation = attackLocation
    SpawnBandits(attackLocation, attackLocation.banditCount)
    banditAttackTriggered = true
end)

RegisterNetEvent('deadwood-stage:client:banditAttackNotify')
AddEventHandler('deadwood-stage:client:banditAttackNotify', function(attackLocation)
    DebugPrint('Robber attack notification: ' .. (attackLocation.name or 'Unknown'))
    banditAttackTriggered = true
    SpookStagecoach()
    ShowNotification({ title = _('robber_attack'), description = _('robber_attack_desc'), type = 'error', duration = 7000 })
end)

RegisterNetEvent('deadwood-stage:client:cleanup', function()
    CleanupEntities(); missionActive = false; currentGroup = nil; missionArrived = false
end)

RegisterNetEvent('deadwood-stage:client:notify', function(data) ShowNotification(data) end)

RegisterNetEvent('deadwood-stage:client:createRouteGPS', function(destination)
    if destinationBlip and DoesBlipExist(destinationBlip) then RemoveBlip(destinationBlip) end
    destinationBlip = CreateBlipAt(destination, Config.Blips.Destination)
    if Config.ShowGPS then
        StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(destination.x, destination.y, destination.z)
        SetGpsMultiRouteRender(true)
    else
        SetNewWaypoint(destination.x, destination.y)
    end
end)

-- Take Reins
RegisterNetEvent('deadwood-stage:client:takeReins', function()
    DebugPrint('Player attempting to take reins')
    local driverAlive = currentDriverPed and DoesEntityExist(currentDriverPed) and not IsPedDeadOrDying(currentDriverPed, true)
    if driverAlive then
        ShowNotification({ title = _('driver_alive'), description = _('driver_alive_desc'), type = 'inform' }); return
    end

    for _, wagonInfo in pairs(spawnedWagons) do
        if DoesEntityExist(wagonInfo.entity) then
            local pedInSeat = GetPedInVehicleSeat(wagonInfo.entity, -1)
            if pedInSeat ~= 0 and pedInSeat ~= currentDriverPed then
                ShowNotification({ title = _('reins_taken'), description = 'Someone else is already driving!', type = 'error' }); return
            end
        end
    end

    local playerPed = PlayerPedId()
    for _, wagonInfo in pairs(spawnedWagons) do
        if DoesEntityExist(wagonInfo.entity) then
            ClearPedTasks(playerPed)
            SetPedIntoVehicle(playerPed, wagonInfo.entity, -1)
            playerIsDriver = true
            driverDeadTimerActive = false
            if driverDeadTimer then SetTimeout(driverDeadTimer, function() end); driverDeadTimer = nil end
            if missionActive and not missionArrived then
                Wait(1000)
                TaskVehicleDriveToCoord(playerPed, wagonInfo.entity, Config.EndLocation.x, Config.EndLocation.y, Config.EndLocation.z, currentWagonSpeed, 0, GetHashKey(Config.WagonModel), Config.DrivingFlags.RoadOnly, 1.0, true)
            end
            ShowNotification({ title = _('reins_taken'), description = _('reins_taken_desc'), type = 'success', duration = 5000 })
            break
        end
    end
end)

-- Mission completion
RegisterNetEvent('deadwood-stage:client:startCompletion')
AddEventHandler('deadwood-stage:client:startCompletion', function()
    ShowNotification({ title = _('mission_complete'), description = _('destination_reached'), type = 'success', duration = 8000 })

    SetTimeout(20000, function()
        if missionActive then
            local survivingPassengers = 0
            for _, p in ipairs(passengers) do
                if p.alive and DoesEntityExist(p.ped) and not IsPedDeadOrDying(p.ped, true) then
                    survivingPassengers = survivingPassengers + 1
                end
            end

            local stagecoachAlive = false
            for _, wagonInfo in pairs(spawnedWagons) do
                if wagonInfo.alive then stagecoachAlive = true; break end
            end

            if stagecoachAlive then
                TriggerServerEvent('deadwood-stage:server:completeMission', survivingPassengers)
                ShowNotification({
                    title = _('job_completed'),
                    description = _('payment_distributed', Config.WagonReward, survivingPassengers * Config.PassengerReward, survivingPassengers),
                    type = 'success', duration = 10000
                })
            else
                ShowNotification({ title = _('server_mission_failed'), description = _('server_mission_failed_desc'), type = 'error', duration = 10000 })
            end
            CleanupMission()
        end
    end)
end)

RegisterNetEvent('deadwood-stage:client:missionFailed')
AddEventHandler('deadwood-stage:client:missionFailed', function()
    CleanupMission()
end)

-- ============================================================
-- Lifecycle
-- ============================================================
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(3000); SetupMissionStart()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then CompleteCleanup() end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then CompleteCleanup() end
end)
