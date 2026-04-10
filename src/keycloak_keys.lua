-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local http = require "resty.http"
local cjson_safe = require "cjson.safe"
local convert = require "kong.plugins.jwt-keycloak.key_conversion"

local DEFAULT_TIMEOUT = 10000 -- 10 seconds (connect, send, read)

local function get_request(request_url)
    local httpc, err = http.new()
    if not httpc then
        return nil, 'Failed to create HTTP client: ' .. (err or 'unknown')
    end

    httpc:set_timeouts(DEFAULT_TIMEOUT, DEFAULT_TIMEOUT, DEFAULT_TIMEOUT)

    local res, req_err = httpc:request_uri(request_url, {
        method = "GET",
        ssl_verify = false,
    })

    if not res then
        return nil, 'Failed calling url ' .. request_url .. ': ' .. (req_err or 'unknown')
    end

    if res.status ~= 200 then
        return nil, 'Failed calling url ' .. request_url .. ' response status ' .. res.status
    end

    local body, decode_err = cjson_safe.decode(res.body)
    if not body then
        return nil, 'Failed to parse json response'
    end

    return body, nil
end

local function get_wellknown_endpoint(well_known_template, issuer)
    return string.format(well_known_template, issuer)
end

local function get_issuer_keys(well_known_endpoint)
    local res, err = get_request(well_known_endpoint)
    if err then
        return nil, nil, err
    end

    local jwks, jwks_err = get_request(res["jwks_uri"])
    if jwks_err then
        return nil, nil, jwks_err
    end

    local keys = {}
    local kids = {}
    local key_metadata = {}
    for i, key in ipairs(jwks["keys"]) do
        keys[i] = string.gsub(
            convert.convert_kc_key(key),
            "[\r\n]+", ""
        )
        kids[i] = key.kid
        -- Store metadata for fallback key selection when kid is absent
        key_metadata[i] = {
            alg = key.alg,
            use = key.use,
            kty = key.kty
        }
    end

    -- Return keys, kids, and key_metadata aligned by index.
    -- Third return value is error (nil on success).
    -- Fourth return value is key_metadata array.
    return keys, kids, nil, key_metadata
end

return {
    get_request = get_request,
    get_issuer_keys = get_issuer_keys,
    get_wellknown_endpoint = get_wellknown_endpoint,
}
