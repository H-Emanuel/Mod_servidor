-- 脚本的位置是 "{命名空间}:{路径}"，那么 require 的格式为 "{命名空间}_{路径}"
-- 注意！require 取得的内容不应该被修改，应仅调用
local default = require("tacz_manual_action_state_machine")
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local MAIN_TRACK = default.MAIN_TRACK
local main_track_states = default.main_track_states
local bolt_caught_states = default.bolt_caught_states

local idle_state = setmetatable({}, {__index = main_track_states.idle})
local normal_states = setmetatable({}, {__index = bolt_caught_states.normal})
local caught_states = setmetatable({}, {__index = bolt_caught_states.bolt_caught})
local reload_state = {
    retreat = "reload_retreat",
    need_ammo = 0,
    loaded_ammo = 0,
    emptyload = 0
}

function normal_states.update(this, context)
    if (not context:hasBulletInBarrel()) then
        context:trigger(this.INPUT_BOLT_CAUGHT)
    end
end

function caught_states.update(this, context)
    if (context:hasBulletInBarrel()) then
        context:trigger(this.INPUT_BOLT_NORMAL)
    end
end

function idle_state.transition(this, context, input)
    if (input == INPUT_RELOAD) then
        return reload_state
    end
    return main_track_states.idle.transition(this, context, input)
end

function reload_state.entry(this, context)
    local state = this.main_track_states.reload
    local isNoAmmo = not context:hasBulletInBarrel()
    if (isNoAmmo) then
        reload_state.emptyload = 1
        context:runAnimation("reload_start", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    else
        context:runAnimation("reload_start", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
    end
    state.need_ammo = context:getMaxAmmoCount() - context:getAmmoCount()
    state.loaded_ammo = 0
end

function reload_state.update(this, context)
    local state = this.main_track_states.reload
    if (state.loaded_ammo > state.need_ammo or not context:hasAmmoToConsume()) then
        context:trigger(this.INPUT_RELOAD_RETREAT)
    else
        local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
        if (context:isHolding(track)) then
            if(context:getMagExtentLevel() == 1 and state.loaded_ammo + 5 <= state.need_ammo) then
                context:runAnimation("reload_tube", track, false, PLAY_ONCE_HOLD, 0.2)
                state.loaded_ammo = state.loaded_ammo + 5
            else
                context:runAnimation("reload_loop", track, false, PLAY_ONCE_HOLD, 0.2)
                state.loaded_ammo = state.loaded_ammo + 1
            end
        end
    end
end
-- 如果 loop 循环结束或者换弹被打断，退出到 idle 状态。否则由 idle 的 transition 函数决定下一个状态。
function reload_state.transition(this, context, input)
    if (input == this.INPUT_RELOAD_RETREAT or input == INPUT_CANCEL_RELOAD) then
        if(reload_state.emptyload == 1) then
            context:runAnimation("reload_end_empty", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
            reload_state.emptyload = 0
        else
            context:runAnimation("reload_end", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
        end
        return this.main_track_states.idle
    end
    return this.main_track_states.idle.transition(this, context, input)
end
-- 用元表的方式继承默认状态机的属性
local M = setmetatable({
    main_track_states = setmetatable({
        idle = idle_state,
        reload = reload_state
    }, {__index = main_track_states}),
    bolt_caught_states = setmetatable({
        bolt_caught = caught_states,
        normal = normal_states
    }, {__index = bolt_caught_states}),
    INPUT_RELOAD_RETREAT = "reload_retreat",
}, {__index = default})
-- 先调用父级状态机的初始化函数，然后进行自己的初始化
function M:initialize(context)
    default.initialize(self, context)
    self.main_track_states.reload.need_ammo = 0
    self.main_track_states.reload.loaded_ammo = 0
    self.main_track_states.reload.emptyload = 0
end
-- 导出状态机
return M