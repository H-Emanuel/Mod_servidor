local M = {}

function M.shoot(api)
    api:shootOnce(api:isShootingNeedConsumeAmmo())
    local param = api:getScriptParams()
    local cache = api:getCachedScriptData()
    if (cache == nil) then
        cache = {
            accel = 0
         }
    end
    local accel_count = 20
    local last_shoot_timestamp = api:getLastShootTimestamp()
    local current_timestamp = api:getCurrentTimestamp()
    local shoot_interval = api:getShootInterval()
    local final_adjust = 0
    local rate = (param.rpm_rate)-1
    if (current_timestamp - last_shoot_timestamp) >= (2*shoot_interval + 50) then
        cache.accel = 0
    else
        local accel = cache.accel
        cache.accel = math.min(accel + 1,accel_count)
    end
    if (api:getAimingProgress()>0.5) then
        rate = rate
    else
        rate = rate*(cache.accel/accel_count)
    end
    if not (rate<=0) then
        final_adjust = (1/(rate+1))-1
    end
    api:adjustShootInterval(shoot_interval*final_adjust)
    api:cacheScriptData(cache)
end

return M