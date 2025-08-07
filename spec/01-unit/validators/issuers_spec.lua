-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local validate_issuer = require("kong.plugins.jwt-keycloak.validators.issuers").validate_issuer

describe("Plugin: jwt-keycloak (issuers validator)", function()
  describe("validate_issuer", function()
    it("should allow exact match issuer", function()
      local allowed_issuers = {"https://keycloak.example.com/auth/realms/test"}
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}
      
      local result = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow pattern match issuer", function()
      local allowed_issuers = {"https://keycloak%.example%.com/auth/realms/.*"}
      local jwt_claims = {iss = "https://keycloak.example.com/auth/realms/test"}
      
      local result = validate_issuer(allowed_issuers, jwt_claims)
      
      assert.is_true(result)
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
end)