local default = require("tacz_default_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE

local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local MAIN_TRACK = default.MAIN_TRACK
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK
local bolt_caught_states = default.bolt_caught_states
local main_track_states = default.main_track_states

local normal_states = setmetatable({}, {__index = bolt_caught_states.normal})
local caught_states = setmetatable({}, {__index = bolt_caught_states.bolt_caught})

local gun_kick_state = setmetatable({}, {__index = default.gun_kick_state})

local idle_state = setmetatable({
    empty = -1
}, {__index = main_track_states.idle})

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
        local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
        local last_shoot_timestamp = context:getLastShootTimestamp()
        local current_timestamp = context:getCurrentTimestamp()
        local shoot_interval = context:getShootInterval()
        if (current_timestamp - last_shoot_timestamp < shoot_interval + 100) then
            context:runAnimation("shoot_auto", track, true, PLAY_ONCE_STOP, 0)
        else
            context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
        end
    end
    return nil
end

local function isNoAmmo(context)
    return (context:getAmmoCount() <= 0)
end

function normal_states.entry(this, context)
    context:runAnimation("bullet_state", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), false, PLAY_ONCE_STOP, 0)
    return this.bolt_caught_states.normal
end


function normal_states.update(this, context)
    if (isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_CAUGHT)
    end
    context:setAnimationProgress(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), 1 - context:getAmmoCount()/context:getMaxAmmoCount(), false)
end

function caught_states.update(this, context)
    if (not isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_NORMAL)
    end
end

local M = setmetatable({
    bolt_caught_states = setmetatable({
        bolt_caught = caught_states,
        normal = normal_states
    }, {__index = bolt_caught_states}),
    gun_kick_state = gun_kick_state
}, {__index = default})

function M:initialize(context)
    default.initialize(self, context)
end

return M