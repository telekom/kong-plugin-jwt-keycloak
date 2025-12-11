-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local M = {}

-- Helper function to determine if a key matches the JWT header algorithm
-- Supports both RSA (RS256, RS384, RS512, PS256, PS384, PS512) and EC (ES256, ES384, ES512) algorithms
local function key_matches_algorithm(key_metadata, jwt_alg)
  if not key_metadata then
    return false
  end

  -- If key specifies use and it's not "sig", skip it
  if key_metadata.use and key_metadata.use ~= "sig" then
    return false
  end

  -- If key has alg specified, it must match JWT alg
  if key_metadata.alg then
    return key_metadata.alg == jwt_alg
  end

  -- Check kty matches algorithm family
  if jwt_alg then
    local jwt_kty_derived = jwt_alg:sub(1, 2)
    if jwt_kty_derived == "RS" or jwt_kty_derived == "PS" then
      -- RSA algorithms
      if key_metadata.kty and key_metadata.kty == "RSA" then
        return true
      end
    elseif jwt_kty_derived == "ES" then
      -- ECDSA algorithms
      if key_metadata.kty and key_metadata.kty == "EC" then
        return true
      end
    end
  end

  -- If we get here, the key neither matches the algorithm family nor has a matching alg field, so reject it
  return false
end

-- Validates a JWT signature using a key selected by kid from the provided
-- public_keys structure. If kid is absent, attempts to find a single unambiguous
-- matching key based on JWT algorithm and key metadata.
--
-- Parameters:
--   conf        - plugin configuration (currently unused, reserved for future)
--   jwt         - jwt_parser instance
--   public_keys - table with fields:
--                   keys = { <decoded_key1>, <decoded_key2>, ... }
--                   kids = { "kid1", "kid2", ... }
--                   key_metadata = { {alg=..., use=..., kty=...}, ... }
--
-- Returns:
--   nil on success (signature valid)
--   or { status = <http_status>, message = <error_message> } on failure
function M.validate_signature_with_kid(conf, jwt, public_keys)
  local header = jwt.header or {}
  local header_kid = header.kid
  local header_alg = header.alg

  local kids = public_keys and public_keys.kids or nil
  local keys = public_keys and public_keys.keys or nil
  local key_metadata = public_keys and public_keys.key_metadata or nil

  if not keys or #keys == 0 then
    return {
      status = 401,
      message = "No public keys available"
    }
  end

  local key_index = nil

  -- If kid is present, use it for direct lookup
  if header_kid and header_kid ~= "" then
    if not kids then
      return {
        status = 401,
        message = "Unable to find public key for token kid"
      }
    end

    for i, kid in ipairs(kids) do
      if kid == header_kid then
        key_index = i
        break
      end
    end

    if not key_index then
      return {
        status = 401,
        message = "Unable to find public key for token kid"
      }
    end
  else
    -- kid is absent: try to find a single unambiguous matching key
    local matching_indices = {}

    for i = 1, #keys do
      local metadata = key_metadata and key_metadata[i] or nil
      if key_matches_algorithm(metadata, header_alg) then
        table.insert(matching_indices, i)
      end
    end

    if #matching_indices == 0 then
      return {
        status = 401,
        message = "No matching public key found for token algorithm"
      }
    elseif #matching_indices > 1 then
      return {
        status = 401,
        message = "kid header required: multiple keys match token algorithm"
      }
    else
      key_index = matching_indices[1]
    end
  end

  -- Verify signature with the selected key
  local key = keys[key_index]
  if key and jwt.verify_signature then
    if jwt:verify_signature(key) then
      return nil
    end
  end

  return {
    status = 401,
    message = "Invalid token signature"
  }
end

return M
