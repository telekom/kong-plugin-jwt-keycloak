-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

-- Helper functions and mocks for unit tests

local helpers = {}

-- Mock kong global
local mock_kong = {
  log = {
    debug = function(...) end,
    err = function(...) end,
    info = function(...) end,
    warn = function(...) end
  },
  -- ctx.shared is used by gateway/securitylog.lua
  ctx = {
    shared = {}
  }
}

-- Mock ngx global with base64 functions and security logging support
local mock_ngx = {
  encode_base64 = function(s)
    -- Simple base64 encoding for tests (this is a minimal implementation)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = ''
    local bytes = { s:byte(1, -1) }

    for i = 1, #bytes, 3 do
      local b1, b2, b3 = bytes[i], bytes[i + 1], bytes[i + 2]
      local n = (b1 or 0) * 65536 + (b2 or 0) * 256 + (b3 or 0)
      result = result .. chars:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
      result = result .. chars:sub((math.floor(n / 4096) % 64) + 1, (math.floor(n / 4096) % 64) + 1)
      result = result .. (b2 and chars:sub((math.floor(n / 64) % 64) + 1, (math.floor(n / 64) % 64) + 1) or '=')
      result = result .. (b3 and chars:sub((n % 64) + 1, (n % 64) + 1) or '=')
    end

    return result
  end,

  decode_base64 = function(s)
    -- Simple base64 decoding for tests
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local lookup = {}
    for i = 1, #chars do
      lookup[chars:byte(i)] = i - 1
    end

    s = s:gsub('=+$', '')
    local result = ''

    for i = 1, #s, 4 do
      local a, b, c, d = s:byte(i, i + 3)
      local n = (lookup[a] or 0) * 262144 + (lookup[b] or 0) * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
      result = result .. string.char(math.floor(n / 65536) % 256)
      if c then result = result .. string.char(math.floor(n / 256) % 256) end
      if d then result = result .. string.char(n % 256) end
    end

    return result
  end,

  -- Mock ngx.var for security logging
  var = {},

  -- Mock ngx.DEBUG constant
  DEBUG = 7
}

-- Mock functions for testing
function helpers.setup_kong_mock()
  -- reset ctx.shared for each test to ensure isolation
  mock_kong.ctx = { shared = {} }
  _G.kong = mock_kong
  _G.ngx = mock_ngx
end

function helpers.teardown_kong_mock()
  _G.kong = nil
  _G.ngx = nil
end

-- Mock cjson.safe
local mock_cjson_safe = {
  decode = function(data)
    -- Minimal JSON decoder for tests, tailored to the structures we use
    -- Well-known configuration with jwks_uri
    if data:find('"jwks_uri"') then
      local jwks_uri = data:match('"jwks_uri"%s*:%s*"([^"]+)"')
      return { jwks_uri = jwks_uri }, nil
    end

    -- JWKS document with keys and kids
    if data:find('"keys"') then
      -- For tests, return 2 RSA keys with kids kid1 and kid2
      return {
        keys = {
          {
            kid = "kid1",
            kty = "RSA",
            n =
            "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtmY7sFdl7oahqT_Rc59oKHM78bF8HGmKuHqUL6v3Ohl80UR8QFN5Y8o3h8DGf9LUz0p8H2I",
            e = "AQAB"
          },
          {
            kid = "kid2",
            kty = "RSA",
            n =
            "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtmY7sFdl7oahqT_Rc59oKHM78bF8HGmKuHqUL6v3Ohl80UR8QFN5Y8o3h8DGf9LUz0p8H2I",
            e = "AQAB"
          }
        }
      }, nil
    end

    -- Generic test payload
    if data == '{"test": "data"}' then
      return { test = "data" }, nil
    end

    return nil, "parse error"
  end
}

-- Mock resty.http module
local mock_resty_http_instance = {
  set_timeouts = function(self, connect, send, read) end,
  request_uri = function(self, request_url, opts)
    local body
    if request_url and request_url:find("openid%-configuration") then
      body = '{"jwks_uri": "https://keycloak.example.com/auth/realms/test/jwks"}'
    elseif request_url and request_url:find("jwks") then
      body = '{"keys": []}' -- actual keys are provided by mock_cjson_safe.decode
    else
      body = '{"test": "data"}'
    end
    return { status = 200, body = body }, nil
  end
}

local mock_resty_http = {
  new = function()
    return mock_resty_http_instance, nil
  end
}

-- Mock errlog for security logging
local mock_errlog = {
  raw_log = function(level, message)
    -- Mock implementation - in tests, we can capture these calls
    -- print("SECURITY LOG [" .. level .. "]: " .. message)
  end
}

function helpers.setup_socket_mocks()
  package.loaded["resty.http"] = mock_resty_http
  package.loaded["cjson.safe"] = mock_cjson_safe
  package.loaded["ngx.errlog"] = mock_errlog
end

function helpers.teardown_socket_mocks()
  package.loaded["resty.http"] = nil
  package.loaded["cjson.safe"] = nil
  package.loaded["ngx.errlog"] = nil
end

return helpers
