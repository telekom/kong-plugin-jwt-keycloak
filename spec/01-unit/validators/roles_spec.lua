-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local validate_roles = require("kong.plugins.jwt-keycloak.validators.roles")

describe("Plugin: jwt-keycloak (roles validator)", function()
  describe("validate_realm_roles", function()
    it("should allow when no realm roles are required", function()
      local allowed_roles = nil
      local jwt_claims = {realm_access = {roles = {"offline_access"}}}
      
      local result = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when empty realm roles are required", function()
      local allowed_roles = {}
      local jwt_claims = {realm_access = {roles = {"offline_access"}}}
      
      local result = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has required realm role", function()
      local allowed_roles = {"offline_access"}
      local jwt_claims = {realm_access = {roles = {"offline_access", "uma_authorization"}}}
      
      local result = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has one of multiple required realm roles", function()
      local allowed_roles = {"admin", "offline_access"}
      local jwt_claims = {realm_access = {roles = {"offline_access", "uma_authorization"}}}
      
      local result = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should reject when token missing required realm role", function()
      local allowed_roles = {"admin"}
      local jwt_claims = {realm_access = {roles = {"offline_access", "uma_authorization"}}}
      
      local result, err = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required realm role", err)
    end)

    it("should reject when realm_access claim is missing", function()
      local allowed_roles = {"offline_access"}
      local jwt_claims = {}
      
      local result, err = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required realm_access.roles claim", err)
    end)

    it("should reject when realm_access.roles is missing", function()
      local allowed_roles = {"offline_access"}
      local jwt_claims = {realm_access = {}}
      
      local result, err = validate_roles.validate_realm_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required realm_access.roles claim", err)
    end)
  end)

  describe("validate_client_roles", function()
    it("should allow when no client roles are required", function()
      local allowed_roles = nil
      local jwt_claims = {resource_access = {account = {roles = {"manage-account"}}}}
      
      local result = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when empty client roles are required", function()
      local allowed_roles = {}
      local jwt_claims = {resource_access = {account = {roles = {"manage-account"}}}}
      
      local result = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has required client role", function()
      local allowed_roles = {"account:manage-account"}
      local jwt_claims = {
        resource_access = {
          account = {roles = {"manage-account", "view-profile"}}
        }
      }
      
      local result = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has one of multiple required client roles", function()
      local allowed_roles = {"account:admin", "account:manage-account"}
      local jwt_claims = {
        resource_access = {
          account = {roles = {"manage-account", "view-profile"}}
        }
      }
      
      local result = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has role in different client", function()
      local allowed_roles = {"other-client:admin"}
      local jwt_claims = {
        resource_access = {
          account = {roles = {"manage-account"}},
          ["other-client"] = {roles = {"admin", "user"}}
        }
      }
      
      local result = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should reject when token missing required client role", function()
      local allowed_roles = {"account:admin"}
      local jwt_claims = {
        resource_access = {
          account = {roles = {"manage-account", "view-profile"}}
        }
      }
      
      local result, err = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required role", err)
    end)

    it("should reject when resource_access claim is missing", function()
      local allowed_roles = {"account:manage-account"}
      local jwt_claims = {}
      
      local result, err = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required resource_access claim", err)
    end)

    it("should reject when client doesn't exist in resource_access", function()
      local allowed_roles = {"missing-client:admin"}
      local jwt_claims = {
        resource_access = {
          account = {roles = {"manage-account"}}
        }
      }
      
      local result, err = validate_roles.validate_client_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required role", err)
    end)
  end)

  describe("validate_roles", function()
    it("should allow when no roles are required", function()
      local allowed_roles = nil
      local jwt_claims = {azp = "test-client", resource_access = {}}
      
      local result = validate_roles.validate_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should allow when token has required role for current client", function()
      local allowed_roles = {"admin"}
      local jwt_claims = {
        azp = "test-client",
        resource_access = {
          ["test-client"] = {roles = {"admin", "user"}}
        }
      }
      
      local result = validate_roles.validate_roles(allowed_roles, jwt_claims)
      
      assert.is_true(result)
    end)

    it("should reject when azp claim is missing", function()
      local allowed_roles = {"admin"}
      local jwt_claims = {
        resource_access = {
          ["test-client"] = {roles = {"admin"}}
        }
      }
      
      local result, err = validate_roles.validate_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required azp claim", err)
    end)

    it("should reject when token missing required role for current client", function()
      local allowed_roles = {"admin"}
      local jwt_claims = {
        azp = "test-client",
        resource_access = {
          ["test-client"] = {roles = {"user"}},
          ["other-client"] = {roles = {"admin"}}
        }
      }
      
      local result, err = validate_roles.validate_roles(allowed_roles, jwt_claims)
      
      assert.is_false(result)
      assert.equals("Missing required role", err)
    end)
  end)
end)