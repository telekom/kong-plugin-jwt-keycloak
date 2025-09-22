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
    it("should log security events and set kong.ctx.shared vars", function()
      local securitylog = require("gateway.securitylog")

      -- Test security_event function
      securitylog.security_event('ua200', 'test event details')

      -- Verify that the ctx.shared vars were set correctly
      assert.equals('ua200', kong.ctx.shared.sec_event_code)
      assert.equals('test event details', kong.ctx.shared.sec_event_details)
    end)
  end)

  describe("collect_gateway_data", function()
    it("should set gateway_consumer to anonymous when jwt is nil", function()
      local securitylog = require("gateway.securitylog")

      -- Test with nil jwt
      securitylog.collect_gateway_data(nil)

      assert.equals("anonymous", kong.ctx.shared.gateway_consumer)
    end)

    it("should set gateway_consumer to anonymous when jwt.claims is nil", function()
      local securitylog = require("gateway.securitylog")

      -- Test with jwt but no claims
      local jwt = {}
      securitylog.collect_gateway_data(jwt)

      assert.equals("anonymous", kong.ctx.shared.gateway_consumer)
    end)

    it("should set gateway_consumer to clientId when available", function()
      local securitylog = require("gateway.securitylog")

      -- Test with jwt containing clientId
      local jwt = {
        claims = {
          clientId = "test-client-123"
        }
      }
      securitylog.collect_gateway_data(jwt)

      assert.equals("test-client-123", kong.ctx.shared.gateway_consumer)
    end)

    it("should set gateway_consumer to anonymous when clientId is not a string", function()
      local securitylog = require("gateway.securitylog")

      -- Test with jwt containing non-string clientId
      local jwt = {
        claims = {
          clientId = 123 -- number instead of string
        }
      }
      securitylog.collect_gateway_data(jwt)

      assert.equals("anonymous", kong.ctx.shared.gateway_consumer)
    end)
  end)
end)
