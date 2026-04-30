-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local validate_issuer = require("kong.plugins.jwt-keycloak.validators.issuers").validate_issuer
local is_issuer_blocked = require("kong.plugins.jwt-keycloak.validators.issuers").is_issuer_blocked

describe("Plugin: jwt-keycloak (issuers validator)", function()
  describe("validate_issuer", function()
    it("should allow exact match issuer", function()
      local allowed_issuers = {"https://keycloak.example.com/auth/realms/test"}
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}
      
      local result = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should not treat allowed_iss entries as Lua patterns", function()
      -- Changed in 1.8.1: allowed_iss entries are matched by exact string equality only.
      -- Previously, entries were treated as Lua patterns via string.match, which allowed
      -- unescaped dots to act as wildcards and unanchored substring attacks.
      -- A Lua-pattern-shaped entry must not match a plain URL via pattern semantics.
      local allowed_issuers = {"https://keycloak%.example%.com/auth/realms/test"}
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}

      local result, err = validate_issuer(allowed_issuers, jwt_claims)

      assert.is_nil(result)
      assert.equals("Token issuer not allowed", err)
    end)

    it("should allow multiple issuers", function()
      local allowed_issuers = {
        "https://keycloak1.example.com/auth/realms/test",
        "https://keycloak2.example.com/auth/realms/test"
      }
      local jwt_claims = {iss = "https://keycloak2.example.com/auth/realms/test"}
      
      local result = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should reject non-matching issuer", function()
      local allowed_issuers = {"https://keycloak.example.com/auth/realms/test"}
      local jwt_claims = {iss = "https://malicious.example.com/auth/realms/test"}
      
      local result, err = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_nil(result)
      assert.equals("Token issuer not allowed", err)
    end)

    it("should reject when iss claim is missing", function()
      local allowed_issuers = {"https://keycloak.example.com/auth/realms/test"}
      local jwt_claims = {}
      
      local result, err = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_nil(result)
      assert.equals("Missing issuer claim", err)
    end)

    it("should reject when allowed issuers is empty", function()
      local allowed_issuers = {}
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}
      
      local result, err = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_nil(result)
      assert.equals("Allowed issuers is empty", err)
    end)

    it("should reject when allowed issuers is nil", function()
      local allowed_issuers = nil
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}
      
      local result, err = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_nil(result)
      assert.equals("Allowed issuers is empty", err)
    end)
  end)

  describe("is_issuer_blocked", function()
    it("should not block when blocked_issuers is nil", function()
      local result = is_issuer_blocked(nil, "https://keycloak.example.com/auth/realms/test")

      assert.is_false(result)
    end)

    it("should not block when iss is nil", function()
      local blocked_issuers = {"https://compromised.example.com/auth/realms/default"}

      local result = is_issuer_blocked(blocked_issuers, nil)

      assert.is_false(result)
    end)

    it("should not block when blocked list is empty", function()
      local blocked_issuers = {}

      local result = is_issuer_blocked(blocked_issuers, "https://keycloak.example.com/auth/realms/test")

      assert.is_false(result)
    end)

    it("should block on exact match", function()
      local blocked_issuers = {"https://compromised.example.com/auth/realms/default"}

      local result = is_issuer_blocked(blocked_issuers, "https://compromised.example.com/auth/realms/default")

      assert.is_true(result)
    end)

    it("should not block when iss does not match any entry", function()
      local blocked_issuers = {"https://compromised.example.com/auth/realms/default"}

      local result = is_issuer_blocked(blocked_issuers, "https://legitimate.example.com/auth/realms/default")

      assert.is_false(result)
    end)

    it("should block when iss matches a non-first entry", function()
      local blocked_issuers = {
        "https://other-compromised.example.com/auth/realms/default",
        "https://compromised.example.com/auth/realms/default",
      }

      local result = is_issuer_blocked(blocked_issuers, "https://compromised.example.com/auth/realms/default")

      assert.is_true(result)
    end)
  end)
end)

