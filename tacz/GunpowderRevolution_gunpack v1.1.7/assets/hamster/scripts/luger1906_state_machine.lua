local default = require("tacz_default_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK
local MAIN_TRACK = default.MAIN_TRACK

local bolt_caught_states = default.bolt_caught_states

local main_track_states = default.main_track_states
-- main_track_states.idle 是我们要重写的状态。
local idle_state = setmetatable({}, {__index = main_track_states.idle})
-- reload_state、bolt_state 是定义的新状态，用于执行单发装填
local reload_state = {
    need_ammo = 0,
    loaded_ammo = 0,
    emptyload = 0
}

local gun_kick_state = setmetatable({}, {__index = default.gun_kick_state})
local bolt_caught = setmetatable({
    mode = -1
}, {__index = bolt_caught_states.bolt_caught})
local normal = setmetatable({}, {__index = bolt_caught_states.normal})

local function isNoAmmo(context)
    return (not context:hasBulletInBarrel()) and (context:getAmmoCount() <= 0)
end

-- 重写 idle 状态的 transition 函数，将输入 INPUT_RELOAD 重定向到新定义的 reload_state 状态
function idle_state.transition(this, context, input)
    if (input == INPUT_RELOAD) then
        return this.main_track_states.reload
    end
    return main_track_states.idle.transition(this, context, input)
end

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
        local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
            if(context:getAmmoCount() ~= 1) then
                if(context:getAttachment("SCOPE") == "tacz:empty") then
                    context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
                else
                    context:runAnimation("shoot_scope", track, true, PLAY_ONCE_STOP, 0)
                end
            end
    end
    return nil
end

function normal.update(this, context)
    if (context:getAmmoCount() <= 0) then
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

function reload_state.entry(this, context)
    if (isNoAmmo(context)) then
        this.main_track_states.reload.emptyload = 1
        context:runAnimation("reload_start_clip", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    elseif(context:getAmmoCount() == 1) then
        context:runAnimation("reload_start_1round", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    else
        context:runAnimation("reload_start", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    end
    this.main_track_states.reload.need_ammo = context:getMaxAmmoCount() - context:getAmmoCount()
    this.main_track_states.reload.loaded_ammo = 0
    if(context:hasBulletInBarrel())then
        this.main_track_states.reload.loaded_ammo = this.main_track_states.reload.loaded_ammo + 1
    end
end

function reload_state.update(this, context)
    if (this.main_track_states.reload.loaded_ammo > this.main_track_states.reload.need_ammo or not context:hasAmmoToConsume()) then
        context:trigger(this.INPUT_RELOAD_RETREAT)
    else
        local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
        -- 等待 intro 结束，然后循环播放 loop 动画
        if(context:isHolding(track)) then
            if(this.main_track_states.reload.emptyload == 1) then
                if (this.main_track_states.reload.loaded_ammo ~= 5) then
                    context:runAnimation("reload_load_clip", track, false, PLAY_ONCE_HOLD, 0.2)
                end
                this.main_track_states.reload.loaded_ammo = this.main_track_states.reload.loaded_ammo + 5
            else
                context:runAnimation("reload_loop", track, false, PLAY_ONCE_HOLD, 0.2)
                this.main_track_states.reload.loaded_ammo = this.main_track_states.reload.loaded_ammo + 1
            end
        end
    end
end

function reload_state.transition(this, context, input)
    if (input == this.INPUT_RELOAD_RETREAT or input == INPUT_CANCEL_RELOAD) then
        if(this.main_track_states.reload.emptyload == 1) then
            context:runAnimation("reload_end_clip", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
            this.main_track_states.reload.emptyload = 0
        else
            context:runAnimation("reload_end", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
        end
        return this.main_track_states.idle
    end
    return this.main_track_states.idle.transition(this, context, input)
end

local M = setmetatable({
    main_track_states = setmetatable({
        -- 自定义的 idle 状态需要覆盖掉父级状态机的对应状态，新建的 reload 状态也要加进来
        idle = idle_state,
        reload = reload_state
    }, {__index = main_track_states}),
    INPUT_RELOAD_RETREAT = "reload_retreat",
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