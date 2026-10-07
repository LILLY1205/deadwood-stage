Locales['en'] = {
    -- Menu / NPC
    ['mission_title'] = 'Deadwood Stage Line',
    ['start_mission'] = 'Start Stagecoach Mission',
    ['route_info'] = 'Route Information',
    ['route_description'] = 'Blackwater -> Valentine',

    -- Group
    ['create_group'] = 'Create Escort Group',
    ['create_group_desc'] = 'Create a new stagecoach escort group (Leader)',
    ['join_group'] = 'Join Escort Group',
    ['join_group_desc'] = 'Join an existing escort group',
    ['leave_group'] = 'Leave Group',
    ['leave_group_desc'] = 'Leave the current escort group',
    ['group_created'] = 'Group Created',
    ['group_created_desc'] = 'Group ID: %s - Share with other players',
    ['group_left'] = 'Group Left',
    ['group_left_desc'] = 'You have left the escort group',

    -- Mission States
    ['mission_started'] = 'Start Mission',
    ['mission_started_desc'] = 'When players have joined, click to start the mission',
    ['mission_ended'] = 'Mission Ended',
    ['mission_ended_desc'] = 'You have ended the stagecoach mission',
    ['mission_ended_leader'] = 'The group leader has ended the mission',

    -- Stagecoach Controls
    ['start_stagecoach'] = 'Start Stagecoach',
    ['speed_up'] = 'Speed Up',
    ['slow_down'] = 'Slow Down',
    ['halt_stagecoach'] = 'Halt',
    ['halt_stagecoach_desc'] = 'Stagecoach stopped',
    ['hold_position'] = 'Hold Position',
    ['stagecoach_moving'] = 'Stagecoach Moving',
    ['stagecoach_moving_desc'] = 'The stagecoach is now rolling! Stay close and guard it!',
    ['stagecoach_speeding_up'] = 'Speeding Up',
    ['stagecoach_slowing_down'] = 'Slowing Down',
    ['stagecoach_halted'] = 'Stagecoach Halted',
    ['stagecoach_halted_desc'] = 'The stagecoach has stopped',
    ['stagecoach_hold'] = 'Hold Position',
    ['stagecoach_hold_desc'] = 'Stagecoach holding position for 10 seconds',
    ['stagecoach_resuming'] = 'Resuming Journey',
    ['stagecoach_resuming_desc'] = 'The stagecoach is moving again',

    -- Stagecoach Robber Attack
    ['robber_attack'] = 'Stagecoach Robbers!',
    ['robber_attack_desc'] = 'Robbers are attacking the stagecoach! Defend the passengers!',
    ['robbers_defeated'] = 'Robbers Defeated!',
    ['robbers_defeated_desc'] = 'All robbers have been eliminated. The stagecoach is safe.',
    ['passenger_lost'] = 'Passenger Lost!',
    ['passenger_lost_desc'] = 'A passenger has been killed!',

    -- Speed / Spook
    ['stagecoach_spooked'] = 'Stagecoach Spooked!',
    ['stagecoach_spooked_desc'] = 'The driver is fleeing from the robbers!',
    ['stagecoach_calmed'] = 'Stagecoach Calmed',
    ['stagecoach_calmed_desc'] = 'The threat has been cleared. Returning to normal pace.',

    -- Hold Position
    ['hold_failed'] = 'Hold Failed',
    ['hold_failed_desc'] = 'No stagecoach available',

    -- Driver Death
    ['driver_dead'] = 'Driver Down!',
    ['driver_dead_desc'] = 'The stagecoach driver has been killed! Take the reins or the mission is lost!',
    ['driver_dead_timer'] = 'Driver is dead! Take the reins! %s seconds remaining!',
    ['driver_dead_expired'] = 'Time is up! The stagecoach has no driver!',
    ['take_reins'] = 'Take the Reins',
    ['take_reins_desc'] = 'Take control of the stagecoach',
    ['reins_taken'] = 'Reins Taken',
    ['reins_taken_desc'] = 'You are now driving the stagecoach! Use the menu to control speed.',
    ['driver_alive'] = 'Driver Alive',
    ['driver_alive_desc'] = 'The driver is still alive!',

    -- Errors
    ['error_no_stagecoach'] = 'Error: No stagecoach spawned',
    ['error_not_leader'] = 'Only the group leader can start the mission',
    ['error_no_group'] = 'You are not in an escort group',
    ['error_already_in_group'] = 'You are already in an escort group',
    ['error_group_full'] = 'Cannot join group (full or does not exist)',
    ['error_min_players'] = 'Need at least %s players to start',
    ['error_mission_active'] = 'Error: Mission already active',

    -- Server Notifications
    ['server_group_error'] = 'Group Error',
    ['server_mission_error'] = 'Mission Error',
    ['server_test_mode'] = 'Test Mode',
    ['server_test_mode_desc'] = 'Mission started in test mode',
    ['server_stagecoach_rolling'] = 'The stagecoach has been dispatched! Approach it to see controls.',
    ['server_mission_reward'] = 'Mission Reward',
    ['server_mission_failed'] = 'Mission Failed',
    ['server_mission_failed_desc'] = 'The stagecoach was lost or all passengers died',
    ['server_mission_completed'] = 'Mission Completed!',
    ['server_mission_completed_desc'] = 'Earned $%s for the stagecoach and %s surviving passengers. Well done!',
    ['server_critical'] = 'Critical Situation',
    ['server_critical_desc'] = 'Only %s passenger(s) remaining!',
    ['server_new_leader'] = 'Group Leadership',
    ['server_new_leader_desc'] = 'You are now the group leader',

    -- Stagecoach Status
    ['stagecoach_status'] = 'Stagecoach Status',
    ['passengers_surviving'] = '%s of %s passengers have survived so far.',
    ['stagecoach_lost'] = 'Stagecoach Lost!',
    ['driver_killed'] = 'The driver has been killed!',
    ['mission_failed_all_lost'] = 'Mission Failed',
    ['all_passengers_dead'] = 'The mission has ended. All passengers are dead or the stagecoach was lost.',
    ['all_players_dead'] = 'All was lost. The passengers did not make it.',
    ['all_players_dead_title'] = 'Mission Failed',
    ['stagecoach_update'] = 'Stagecoach Update',
    ['passengers_remaining'] = '%s of %s passengers remaining. Protect them!',

    -- Mission Completion
    ['mission_complete'] = 'Stagecoach Arrived!',
    ['destination_reached'] = 'The stagecoach has reached the destination safely! Calculating rewards...',
    ['job_completed'] = 'Stagecoach Job Completed',
    ['payment_distributed'] = 'Payment: $%s base + $%s for %s surviving passengers. Well done!',

    -- Journey Instructions
    ['journey_title'] = 'Stagecoach Journey',
    ['journey_desc'] = 'Ride alongside the stagecoach and protect the passengers from robbers. Stay close and keep them safe!',

    -- GPS and Blips
    ['blip_stagecoach_start'] = 'Deadwood Stage Start',
    ['blip_stagecoach'] = 'Stagecoach',
    ['blip_destination'] = 'Destination',
    ['gps_route_set'] = 'GPS route set to destination'
}
