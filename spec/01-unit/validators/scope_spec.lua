-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local validate_scope = require("kong.plugins.jwt-keycloak.validators.scope").validate_scope

describe("Plugin: jwt-keycloak (scope validator)", function()
  describe("validate_scope", function()
    it("should allow when no scopes are required", function()
      local allowed_scopes = nil
      local jwt_claims = {scope = "profile email"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when empty scopes are required", function()
      local allowed_scopes = {}
      local jwt_claims = {scope = "profile email"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has required scope", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = {scope = "profile email"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has one of multiple required scopes", function()
      local allowed_scopes = {"admin", "profile"}
      local jwt_claims = {scope = "profile email"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has all required scopes", function()
      local allowed_scopes = {"profile", "email"}
      local jwt_claims = {scope = "profile email openid"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should reject when token missing required scope", function()
      local allowed_scopes = {"admin"}
      local jwt_claims = {scope = "profile email"}
      
      local result, err = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required scope", err)
    end)

    it("should reject when token has no scopes but scopes are required", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = {scope = ""}
      
      local result, err = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required scope", err)
    end)

    it("should reject when scope claim is missing", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = {}
      
      local result, err = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required scope claim", err)
    end)

    it("should reject when jwt_claims is nil", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = nil
      
      local result, err = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required scope claim", err)
    end)

    it("should handle single scope correctly", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = {scope = "profile"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should handle scopes with different separators", function()
      local allowed_scopes = {"profile"}
      local jwt_claims = {scope = "openid   profile   email"}
      
      local result = validate_scope(allowed_scopes, jwt_claims)
      
      assert.is_true(result)
    end)
  end)
end)