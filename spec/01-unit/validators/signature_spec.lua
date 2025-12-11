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

  it("should accept when kid is missing but single matching key exists", function()
    local jwt = {
      header = { alg = "RS256" },
      verify_signature = function(self, key)
        return key == "KEY_FOR_RS256"
      end
    }

    local public_keys = {
      keys = { "KEY_FOR_RS256" },
      kids = { "kid1" },
      key_metadata = { { alg = "RS256", use = "sig" } }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
  end)

  it("should reject when kid is missing and multiple keys match algorithm", function()
    local jwt = {
      header = { alg = "RS256" },
    }

    local public_keys = {
      keys = { "key1", "key2" },
      kids = { "kid1", "kid2" },
      key_metadata = {
        { alg = "RS256", use = "sig", kty = "RSA" },
        { alg = "RS256", use = "sig", kty = "RSA" }
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("kid header required: multiple keys match token algorithm", err.message)
  end)

  it("should reject when kid is missing and no key matches algorithm", function()
    local jwt = {
      header = { alg = "RS256" },
    }

    local public_keys = {
      keys = { "key1" },
      kids = { "kid1" },
      key_metadata = { { alg = "ES256", use = "sig", kty = "EC" } }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("No matching public key found for token algorithm", err.message)
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

  it("should reject when kid is not found in public keys and no match by alg is found", function()
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

  it("should match key by kty when kid is missing (EC key)", function()
    local jwt = {
      header = { alg = "ES256" },
      verify_signature = function(self, key)
        return key == "EC_KEY"
      end
    }

    local public_keys = {
      keys = { "RSA_KEY", "EC_KEY" },
      kids = { "kid1", "kid2" },
      key_metadata = {
        { kty = "RSA" },
        { kty = "EC" }
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
  end)

  it("should filter out keys with use=enc when kid is missing", function()
    local jwt = {
      header = { alg = "RS256" },
      verify_signature = function(self, key)
        return key == "SIG_KEY"
      end
    }

    local public_keys = {
      keys = { "ENC_KEY", "SIG_KEY" },
      kids = { "kid1", "kid2" },
      key_metadata = {
        { alg = "RS256", use = "enc", kty = "RSA" },
        { alg = "RS256", use = "sig", kty = "RSA" }
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
  end)

  it("should match when metadata has no alg but kty matches", function()
    local jwt = {
      header = { alg = "RS256" },
      verify_signature = function(self, key)
        return key == "RSA_KEY"
      end
    }

    local public_keys = {
      keys = { "RSA_KEY" },
      kids = { "kid1" },
      key_metadata = {
        { kty = "RSA" }  -- no alg specified
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
  end)

  it("should reject when signature fails with auto-matched key", function()
    local jwt = {
      header = { alg = "RS256" },
      verify_signature = function(self, key)
        return false  -- signature verification fails
      end
    }

    local public_keys = {
      keys = { "KEY_FOR_RS256" },
      kids = { "kid1" },
      key_metadata = {
        { alg = "RS256", use = "sig", kty = "RSA" }
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("Invalid token signature", err.message)
  end)

  it("should work when key_metadata is nil (backward compatibility)", function()
    local jwt = {
      header = { alg = "RS256" },
    }

    local public_keys = {
      keys = { "key1", "key2" },
      kids = { "kid1", "kid2" },
      key_metadata = nil
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("No matching public key found for token algorithm", err.message)
  end)

  it("should reject when no public keys available", function()
    local jwt = {
      header = { alg = "RS256" },
    }

    local public_keys = {
      keys = {},
      kids = {},
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_table(err)
    assert.equals(401, err.status)
    assert.equals("No public keys available", err.message)
  end)

  it("should support PS256 (RSA-PSS) algorithm matching", function()
    local jwt = {
      header = { alg = "PS256" },
      verify_signature = function(self, key)
        return key == "RSA_PSS_KEY"
      end
    }

    local public_keys = {
      keys = { "RSA_PSS_KEY" },
      kids = { "kid1" },
      key_metadata = {
        { kty = "RSA" }
      }
    }

    local err = signature_validator.validate_signature_with_kid({}, jwt, public_keys)

    assert.is_nil(err)
  end)

end)
