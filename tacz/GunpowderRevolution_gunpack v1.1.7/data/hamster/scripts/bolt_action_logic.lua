local M = {}

function M.shoot(api)
    api:shootOnce(api:isShootingNeedConsumeAmmo())
end

function M.start_bolt(api)
    return true
end

function M.tick_bolt(api)
    local total_bolt_time = api:getScriptParams().bolt_time * 1000
    if (total_bolt_time == nil) then
        return false
    end
    if (api:getBoltTime() < total_bolt_time) then
        return true
    else
        if (api:consumeAmmoFromPlayer(1) == 1 or not api:isReloadingNeedConsumeAmmo()) then
            api:setAmmoInBarrel(true);
        end
        return false
    end
end

return M