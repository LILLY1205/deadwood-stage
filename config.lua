Config = {}

-- General Settings
Config.Debug = true
Config.TestMode = false
Config.Locale = 'en'
Config.MenuTitle = "Deadwood Stage Line"
Config.TargetSystem = "rsg-target"
Config.ShowGPS = true
Config.ShowBlips = true

-- Mission Locations (TODO: Set your coordinates)
Config.StartLocation = vector3(-863.46, -1335.94, 43.27)
Config.EndLocation   = vector3(-203.47, 641.85, 112.65)

-- Stagecoach Spawn Point
Config.SpawnPoints = {
    vector4(-877.03, -1351.62, 43.21, 267.82)
}

-- Stagecoach Settings
Config.WagonModel = "stagecoach001x"
Config.WagonCount = 1

-- Driver NPC (random from list)
Config.DriverModels = {
    "a_m_m_bivfancydrivers_01",
    "a_m_m_bynfancydrivers_01",
    "a_m_m_grifancydrivers_01",
    "a_m_m_htlfancydrivers_01",
    "a_m_m_rkrfancydrivers_01"
}

-- Passenger NPCs (random from list)
Config.PassengerModels = {
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01",
    "s_m_m_cktworker_01"
}

Config.PassengerCount = 3
Config.PassengerSeats = {0, 1, 2}  -- Seat indices for passengers
Config.PassengerReward = 500        -- Bonus per surviving passenger

-- Start NPC Settings
Config.StartNPC = {
    model = "mp_u_m_m_lom_train_wagondropoff_01",
    coords = vector4(-868.86, -1329.34, 42.91, 268.94),
    interactionDistance = 3.0
}

-- Group Requirements
Config.MinPlayers = 1
Config.MaxPlayers = 8
Config.NotificationDuration = 5000

-- Rewards
Config.WagonReward = 2000
Config.Currency = "cash"

-- Mission States
Config.States = {
    WAITING       = 0,
    STARTED       = 1,
    AMBUSH_ACTIVE = 2,
    COMPLETED     = 3,
    FAILED        = 4
}

-- Speed Settings
Config.WagonSpeeds = {
    Base     = 2.0,
    Spooked  = 3.5,
    Calm     = 2.0
}

Config.SPEED_SLOW = 2.0
Config.SPEED_MEDIUM = 5.0
Config.SPEED_FAST = 7.0

Config.WagonPanicDistance = 80.0
Config.WagonCalmCheckInterval = 5000

-- Driving behavior flags
Config.DrivingFlags = {
    Standard = 1074528293,
    RoadOnly = 786603,
    Careful  = 443
}

Config.WagonArrivalDistance = 15.0
Config.WagonDestroyDelay = 30000

-- Driver death timer (player has this long to take the reins)
Config.DriverDeathTimer = 60000

-- Blip Configuration
Config.Blips = {
    StartLocation = {
        sprite = 784218150,
        scale = 1.0,
        name = "Deadwood Stage Start",
        shortRange = true
    },
    Destination = {
        sprite = 784218150,
        scale = 1.0,
        name = "Stagecoach Destination",
        shortRange = false
    },
    Stagecoach = {
        sprite = -1580514024,
        scale = 0.5,
        name = "Stagecoach",
        shortRange = true
    }
}

-- Stagecoach Robber Settings
Config.BanditAttackLocations = {
    {
        name = "Robber Pass",
        location = vector3(-1288.14, -617.15, 101.04),
        triggerDistance = 25.0,
        banditCount = 4,
        dismountCount = 2
    },
    {
        name = "Canyon Hold-Up",
        location = vector3(-734.17, -349.64, 41.70),
        triggerDistance = 25.0,
        banditCount = 5,
        dismountCount = 3
    }
}

Config.BanditCooldownTime = 1800

-- Bandit Models and Weapons
Config.BanditModels = {
    "g_m_m_unibanditos_01",
    "g_m_m_uniduster_01",
    "g_m_m_uniduster_02",
    "g_m_m_uniduster_03"
}

Config.BanditWeapons = {
    `WEAPON_RIFLE_BOLTACTION`,
    `WEAPON_REPEATER_CARBINE`,
    `WEAPON_REVOLVER_CATTLEMAN`,
    `WEAPON_SHOTGUN_DOUBLEBARREL`
}

Config.BanditHorses = {
    "A_C_HORSE_MORGAN_BAY",
    "A_C_HORSE_TENNESSEEWALKER_CHESTNUT",
    "A_C_HORSE_KENTUCKYSADDLE_BLACK",
    "A_C_HORSE_AMERICANPAINT_GREYOVERO"
}
