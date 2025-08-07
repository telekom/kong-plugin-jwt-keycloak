-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local helpers = require "spec.helpers"

describe("Plugin: jwt-keycloak (keycloak_keys)", function()
  local keycloak_keys

  setup(function()
    helpers.setup_kong_mock()
    helpers.setup_socket_mocks()
    keycloak_keys = require "kong.plugins.jwt-keycloak.keycloak_keys"
  end)

  teardown(function()
    helpers.teardown_kong_mock()
    helpers.teardown_socket_mocks()
    package.loaded["kong.plugins.jwt-keycloak.keycloak_keys"] = nil
  end)
  describe("get_wellknown_endpoint", function()
    it("should format well-known endpoint with default template", function()
      local template = "%s/.well-known/openid-configuration"
      local issuer = "https://keycloak.example.com/auth/realms/test"
      
      local endpoint = keycloak_keys.get_wellknown_endpoint(template, issuer)
      
      assert.equals("https://keycloak.example.com/auth/realms/test/.well-known/openid-configuration", endpoint)
    end)

    it("should format well-known endpoint with custom template", function()
      local template = "%s/protocol/openid-connect/certs"
      local issuer = "https://keycloak.example.com/auth/realms/test"
      
      local endpoint = keycloak_keys.get_wellknown_endpoint(template, issuer)
      
      assert.equals("https://keycloak.example.com/auth/realms/test/protocol/openid-connect/certs", endpoint)
    end)

    it("should handle issuer with trailing slash", function()
      local template = "%s/.well-known/openid-configuration"
      local issuer = "https://keycloak.example.com/auth/realms/test/"
      
      local endpoint = keycloak_keys.get_wellknown_endpoint(template, issuer)
      
      assert.equals("https://keycloak.example.com/auth/realms/test//.well-known/openid-configuration", endpoint)
    end)
  end)

  -- Note: get_request function tests require complex HTTP mocking
  -- These are better tested in integration tests
  describe("get_request", function()
    it("should exist as a function", function()
      assert.is_function(keycloak_keys.get_request)
    end)
  end)
end)