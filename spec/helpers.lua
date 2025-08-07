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
  }
}

-- Mock ngx global with base64 functions
local mock_ngx = {
  encode_base64 = function(s)
    -- Simple base64 encoding for tests (this is a minimal implementation)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = ''
    local bytes = {s:byte(1, -1)}
    
    for i = 1, #bytes, 3 do
      local b1, b2, b3 = bytes[i], bytes[i+1], bytes[i+2]
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
      local a, b, c, d = s:byte(i, i+3)
      local n = (lookup[a] or 0) * 262144 + (lookup[b] or 0) * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
      result = result .. string.char(math.floor(n / 65536) % 256)
      if c then result = result .. string.char(math.floor(n / 256) % 256) end
      if d then result = result .. string.char(n % 256) end
    end
    
    return result
  end
}

-- Mock functions for testing
function helpers.setup_kong_mock()
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
    -- Simple JSON decoder for tests
    if data == '{"test": "data"}' then
      return {test = "data"}
    end
    return nil, "parse error"
  end
}

-- Mock socket modules
local mock_http = {
  request = function(options)
    return "result", 200
  end
}

local mock_https = {
  request = function(options)
    return "result", 200
  end
}

local mock_ltn12 = {
  sink = {
    table = function(chunks)
      return function(data)
        table.insert(chunks, data)
      end
    end
  }
}

-- Mock url parser
local mock_url = {
  parse = function(url)
    local scheme = url:match("^([^:]+):")
    local port = scheme == "https" and 443 or 80
    return {
      scheme = scheme,
      port = port
    }
  end
}

function helpers.setup_socket_mocks()
  package.loaded["socket.http"] = mock_http
  package.loaded["ssl.https"] = mock_https
  package.loaded["ltn12"] = mock_ltn12
  package.loaded["socket.url"] = mock_url
  package.loaded["cjson.safe"] = mock_cjson_safe
end

function helpers.teardown_socket_mocks()
  package.loaded["socket.http"] = nil
  package.loaded["ssl.https"] = nil
  package.loaded["ltn12"] = nil
  package.loaded["socket.url"] = nil
  package.loaded["cjson.safe"] = nil
end

return helpers