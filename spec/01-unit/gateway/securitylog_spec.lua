-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local helpers = require "spec.helpers"

describe("Plugin: jwt-keycloak (security logging)", function()
  
  before_each(function()
    helpers.setup_kong_mock()
    helpers.setup_socket_mocks()
  end)
  
  after_each(function()
    helpers.teardown_kong_mock()
    helpers.teardown_socket_mocks()
  end)

  describe("security_event", function()
    it("should log security events and set ngx vars", function()
      local securitylog = require("kong.plugins.jwt-keycloak.gateway.securitylog")
      
      -- Mock ngx.var to capture the set values
      local captured_vars = {}
      ngx.var = setmetatable({}, {
        __newindex = function(t, k, v)
          captured_vars[k] = v
        end
      })
      
      -- Test security_event function
      securitylog.security_event('ua200', 'test event details')
      
      -- Verify that the ngx vars were set correctly
      assert.equals('ua200', captured_vars.sec_event_code)
      assert.equals('test event details', captured_vars.sec_event_details)
    end)
  end)

  describe("collect_gateway_data", function()
    it("should set gateway_consumer to anonymous when jwt is nil", function()
      local securitylog = require("kong.plugins.jwt-keycloak.gateway.securitylog")
      
      -- Mock ngx.var to capture the set values
      local captured_vars = {}
      ngx.var = setmetatable({}, {
        __newindex = function(t, k, v)
          captured_vars[k] = v
        end
      })
      
      -- Test with nil jwt
      securitylog.collect_gateway_data(nil)
      
      assert.equals("anonymous", captured_vars.gateway_consumer)
    end)

    it("should set gateway_consumer to anonymous when jwt.claims is nil", function()
      local securitylog = require("kong.plugins.jwt-keycloak.gateway.securitylog")
      
      local captured_vars = {}
      ngx.var = setmetatable({}, {
        __newindex = function(t, k, v)
          captured_vars[k] = v
        end
      })
      
      -- Test with jwt but no claims
      local jwt = {}
      securitylog.collect_gateway_data(jwt)
      
      assert.equals("anonymous", captured_vars.gateway_consumer)
    end)

    it("should set gateway_consumer to clientId when available", function()
      local securitylog = require("kong.plugins.jwt-keycloak.gateway.securitylog")
      
      local captured_vars = {}
      ngx.var = setmetatable({}, {
        __newindex = function(t, k, v)
          captured_vars[k] = v
        end
      })
      
      -- Test with jwt containing clientId
      local jwt = {
        claims = {
          clientId = "test-client-123"
        }
      }
      securitylog.collect_gateway_data(jwt)
      
      assert.equals("test-client-123", captured_vars.gateway_consumer)
    end)

    it("should set gateway_consumer to anonymous when clientId is not a string", function()
      local securitylog = require("kong.plugins.jwt-keycloak.gateway.securitylog")
      
      local captured_vars = {}
      ngx.var = setmetatable({}, {
        __newindex = function(t, k, v)
          captured_vars[k] = v
        end
      })
      
      -- Test with jwt containing non-string clientId
      local jwt = {
        claims = {
          clientId = 123  -- number instead of string
        }
      }
      securitylog.collect_gateway_data(jwt)
      
      assert.equals("anonymous", captured_vars.gateway_consumer)
    end)
  end)
end)