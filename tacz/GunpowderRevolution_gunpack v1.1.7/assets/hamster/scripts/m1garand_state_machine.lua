local default = require("tacz_default_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK

local bolt_caught_states = default.bolt_caught_states

local gun_kick_state = setmetatable({}, {__index = default.gun_kick_state})
local bolt_caught = setmetatable({
    mode = -1
}, {__index = bolt_caught_states.bolt_caught})
local normal = setmetatable({}, {__index = bolt_caught_states.normal})

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
               local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
                   if(context:getAmmoCount() ~= 0) then
                       context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
                   end
           end
    return nil
end

function normal.update(this, context)
    if (not context:hasBulletInBarrel()) then
        context:trigger(this.INPUT_BOLT_CAUGHT)
    end
end

function normal.entry(this, context)
    this.bolt_caught_states.normal.update(this, context)
end

function normal.transition(this, context, input)
    if (input == this.INPUT_BOLT_CAUGHT) then
        return this.bolt_caught_states.bolt_caught
    end
end

function bolt_caught.entry(this, context)
    context:runAnimation("static_bolt_caught", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), true, PLAY_ONCE_HOLD, 0)
    if (bolt_caught.mode == 1) then
        context:setAnimationProgress(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), 1, false)
    else
        bolt_caught.mode = 1
    end
end

function bolt_caught.update(this, context)
    if (context:getAmmoCount() > 0) then
        context:trigger(default.INPUT_BOLT_NORMAL)
    end
end

function bolt_caught.transition(this, context, input)
    if (input == default.INPUT_BOLT_NORMAL) then
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK))
        bolt_caught.mode = -1
        return this.bolt_caught_states.normal
    end
end

local M = setmetatable({
    bolt_caught_states = setmetatable({
        normal = normal,
        bolt_caught = bolt_caught,
    }, {__index = bolt_caught_states}),
    gun_kick_state = gun_kick_state
}, {__index = default})

function M:initialize(context)
    default.initialize(self, context)
end

return M