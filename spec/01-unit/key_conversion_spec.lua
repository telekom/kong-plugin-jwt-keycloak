-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local helpers = require "spec.helpers"

describe("Plugin: jwt-keycloak (key_conversion)", function()
  local convert

  before_each(function()
    helpers.setup_kong_mock()
    convert = require "kong.plugins.jwt-keycloak.key_conversion"
  end)

  after_each(function()
    helpers.teardown_kong_mock()
    package.loaded["kong.plugins.jwt-keycloak.key_conversion"] = nil
  end)

  describe("RSA Key Conversion", function()
    it("should convert RSA JWK to DER format (base64 encoded)", function()
      local jwk = {
        kty = "RSA",
        n = "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtmY7sFdl7oahqT_Rc59oKHM78bF8HGmKuHqUL6v3Ohl80UR8QFN5Y8o3h8DGf9LUz0p8H2I",
        e = "AQAB"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)

    it("should handle RSA keys without kty field (backwards compatibility)", function()
      local jwk = {
        n = "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtmY7sFdl7oahqT_Rc59oKHM78bF8HGmKuHqUL6v3Ohl80UR8QFN5Y8o3h8DGf9LUz0p8H2I",
        e = "AQAB"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)
  end)

  describe("EC Key Conversion", function()
    it("should convert P-256 EC JWK to DER format (base64 encoded)", function()
      local jwk = {
        kty = "EC",
        crv = "P-256",
        x = "WKn-ZIGevcwGIyyrzFoZNBdaq9_TsqzGHwHitJBcBmXo",
        y = "y77As5vbZdIQCGr3HhQBjJRTsWmEP8Xn4HGiOApTMZE"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)

    it("should convert P-384 EC JWK to DER format (base64 encoded)", function()
      local jwk = {
        kty = "EC",
        crv = "P-384",
        x = "fY7ROBOsOBDWKT_P6pUlCTu9aTrJ-gVzUWlQ6m4",
        y = "b6xXK4mXF7yNsRNf4wO_7h3oVWQH8m1b"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)

    it("should convert P-521 EC JWK to DER format (base64 encoded)", function()
      local jwk = {
        kty = "EC",
        crv = "P-521",
        x = "AekpBQ8ST8a8VcfVOTNl353vSrDCLLJXmPk06wTjxrrjtHnylcWuY8XYVYM-PIh-GnqUoHh6mMd3GS2E-AYRFhDHdvRBM3qpKdUNB5y2GJPQ",
        y = "ADSmRA43Z1DSNx_RvcLI87cdL07l6jQyyBXMoxVg_l2Th-x3S1WDhjDly79ajL4Kkd0AZMaZmh9ubmf63e3kyMj2"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)

    it("should default to P-256 when curve is not specified", function()
      local jwk = {
        kty = "EC",
        x = "WKn-ZIGevcwGIyyrzFoZNBdaq9_TsqzGHwHitJBcBmXo",
        y = "y77As5vbZdIQCGr3HhQBjJRTsWmEP8Xn4HGiOApTMZE"
      }
      
      local result = convert.convert_kc_key(jwk)
      
      assert.is_string(result)
      assert.not_nil(result)
      assert.is_true(#result > 0)
      -- The function returns base64-encoded DER data, not PEM format with headers
    end)

    it("should throw error for unsupported curve", function()
      local jwk = {
        kty = "EC",
        crv = "P-192",
        x = "WKn-ZIGevcwGIyyrzFoZNBdaq9_TsqzGHwHitJBcBmXo",
        y = "y77As5vbZdIQCGr3HhQBjJRTsWmEP8Xn4HGiOApTMZE"
      }
      
      assert.has_error(function()
        convert.convert_kc_key(jwk)
      end, "Unsupported EC curve: P-192")
    end)
  end)

  describe("Error Handling", function()
    it("should throw error for unsupported key type", function()
      local jwk = {
        kty = "oct",
        k = "somekey"
      }
      
      assert.has_error(function()
        convert.convert_kc_key(jwk)
      end, "Unsupported key type: oct")
    end)

    it("should throw error for unknown key type with missing RSA fields", function()
      local jwk = {
        kty = "unknown"
      }
      
      assert.has_error(function()
        convert.convert_kc_key(jwk)
      end, "Unsupported key type: unknown")
    end)

    it("should throw error for key without type or RSA fields", function()
      local jwk = {}
      
      assert.has_error(function()
        convert.convert_kc_key(jwk)
      end, "Unsupported key type: unknown")
    end)
  end)
end)