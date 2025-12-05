-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local helpers = require "spec.helpers"

describe("Plugin: jwt-keycloak (signature validator)", function()
  local signature_validator

  before_each(function()
    helpers.setup_kong_mock()
    signature_validator = require "kong.plugins.jwt-keycloak.validators.signature"
  end)

  after_each(function()
    helpers.teardown_kong_mock()
    package.loaded["kong.plugins.jwt-keycloak.validators.signature"] = nil
  end)

  it("should reject when kid is missing", function()
    local jwt = {
      header = { alg = "RS256" },
    }

    local public_keys = {
      keys = { "key1" },
      kids = { "kid1" },
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("Invalid token: kid header missing", err.message)
  end)

  it("should reject when kids table is missing", function()
    local jwt = {
      header = { alg = "RS256", kid = "kid1" },
    }

    local public_keys = {
      keys = { "key1" },
      -- kids missing
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("Unable to find public key for token kid", err.message)
  end)

  it("should reject when kid is not found in public keys", function()
    local jwt = {
      header = { alg = "RS256", kid = "kidX" },
    }

    local public_keys = {
      keys = { "key1", "key2" },
      kids = { "kid1", "kid2" },
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("Unable to find public key for token kid", err.message)
  end)

  it("should accept when signature verifies with kid-matched key", function()
    local call_count = 0
    local used_keys = {}

    local jwt = {
      header = { alg = "RS256", kid = "kid2" },
      verify_signature = function(self, key)
        call_count = call_count + 1
        table.insert(used_keys, key)
        return key == "KEY_FOR_KID2"
      end
    }

    local public_keys = {
      keys = { "KEY_FOR_KID1", "KEY_FOR_KID2" },
      kids = { "kid1", "kid2" },
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
    assert.equals(1, call_count)
    assert.same({ "KEY_FOR_KID2" }, used_keys)
  end)

  it("should reject when signature does not verify with kid-matched key", function()
    local jwt = {
      header = { alg = "RS256", kid = "kid2" },
      verify_signature = function(self, key)
        return false
      end
    }

    local public_keys = {
      keys = { "KEY_FOR_KID1", "KEY_FOR_KID2" },
      kids = { "kid1", "kid2" },
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("Invalid token signature", err.message)
  end)
end)
