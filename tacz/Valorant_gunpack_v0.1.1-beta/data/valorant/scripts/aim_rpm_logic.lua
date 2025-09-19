local M = {}

function M.shoot(api)
    api:shootOnce(api:isShootingNeedConsumeAmmo())
    local param = api:getScriptParams()
    local rpm_rate = 1
        if (api:getAimingProgress()>0) then
            if not (param.rpm_rate<=0) then
                rpm_rate = 1/param.rpm_rate
            end
        end
    local intv = api:getShootInterval()
    api:adjustShootInterval(intv*(rpm_rate-1))
end

return M