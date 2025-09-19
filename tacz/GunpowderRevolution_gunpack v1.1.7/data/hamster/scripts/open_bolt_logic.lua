local M = {}

function M.shoot(api)
    api:shootOnce(api:isShootingNeedConsumeAmmo())
    if (api:hasAmmoToConsume()) then
        api:putAmmoInMagazine(api:isReloadingNeedConsumeAmmo() and api:consumeAmmoFromPlayer(1) or 1)
    end
end

return M