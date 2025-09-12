-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0
local errlog = require "ngx.errlog"

local function security_event(event_code, event_details)
    errlog.raw_log(ngx.DEBUG, '[security-event] code=' .. event_code .. ', details=' .. event_details)
    -- Store security event data in Kong context for potential access by other plugins or logging
    kong.ctx.shared.sec_event_code = event_code
    kong.ctx.shared.sec_event_details = event_details
end

local function collect_gateway_data(jwt)
    local gateway_consumer = "anonymous"
    if jwt and jwt.claims then
        local clientId = jwt.claims["clientId"]
        if type(clientId) == "string" then
            gateway_consumer = clientId
        end
    end
    -- Store gateway consumer data in Kong context
    kong.ctx.shared.gateway_consumer = gateway_consumer
end

return {
    security_event = security_event,
    collect_gateway_data = collect_gateway_data
}
