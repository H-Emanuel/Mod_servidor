local M = {}

function M.shoot(api)
    api:shootOnce(api:isShootingNeedConsumeAmmo())
    if (api:hasAmmoToConsume()) then
        api:setAmmoInBarrel(api:consumeAmmoFromPlayer(1) == 1 or not api:isReloadingNeedConsumeAmmo())
    end
end

return M