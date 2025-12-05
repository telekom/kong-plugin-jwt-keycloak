-- SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

local M = {}

-- Validates a JWT signature using a key selected by kid from the provided
-- public_keys structure.
--
-- Parameters:
--   conf        - plugin configuration (currently unused, reserved for future)
--   jwt         - jwt_parser instance
--   public_keys - table with fields:
--                   keys = { <decoded_key1>, <decoded_key2>, ... }
--                   kids = { "kid1", "kid2", ... }
--
-- Returns:
--   nil on success (signature valid)
--   or { status = <http_status>, message = <error_message> } on failure
function M.validate_signature_with_kid(conf, jwt, public_keys)
  local header = jwt.header or {}
  local header_kid = header.kid

  if not header_kid or header_kid == "" then
    return {
      status = 401,
      message = "Invalid token: kid header missing"
    }
  end

  local kids = public_keys and public_keys.kids or nil
  local keys = public_keys and public_keys.keys or nil

  if not kids or not keys then
    return {
      status = 401,
      message = "Unable to find public key for token kid"
    }
  end

  local key_index = nil
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
