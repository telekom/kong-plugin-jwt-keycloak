-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local function validate_issuer(allowed_issuers, jwt_claims)
    if allowed_issuers == nil or table.getn(allowed_issuers) == 0 then
        return nil, "Allowed issuers is empty"
    end
    if jwt_claims.iss == nil then
        return nil, "Missing issuer claim"
    end
    for _, curr_iss in pairs(allowed_issuers) do
        if curr_iss == jwt_claims.iss then
            return true
        end
    end
    return nil, "Token issuer not allowed"
end

-- Checks whether a token's iss claim matches any entry in the blocked_issuers list.
-- Uses exact match only — unlike allowed_issuers, entries are not treated as Lua
-- patterns. This is an emergency measure — JWT_KEYCLOAK_BLOCKED_ISSUERS can be set
-- to plain URLs without knowledge of Lua pattern syntax, and exact match avoids silent over-blocking from
-- unescaped magic characters (e.g. dots) in URLs.
-- Returns false for a nil iss or nil/empty blocked_issuers — a missing issuer claim
-- is not treated as blocked; it will be rejected downstream by validate_issuer.
local function is_issuer_blocked(blocked_issuers, iss)
    if not blocked_issuers or iss == nil then return false end
    for _, blocked in ipairs(blocked_issuers) do
        if blocked == iss then
            return true
        end
    end
    return false
end

return {
    validate_issuer = validate_issuer,
    is_issuer_blocked = is_issuer_blocked,
}
