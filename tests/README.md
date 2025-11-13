<!--
SPDX-FileCopyrightText: 2025 Deutsche Telekom AG

SPDX-License-Identifier: Apache-2.0
-->

# Test Suite Documentation

## Overview
This directory contains integration tests for the kong-plugin-jwt-keycloak plugin. Tests are executed in Docker containers with a full Kong + Keycloak environment.

## Running Tests
```bash
# Start all services
docker compose up -d

# Run the complete test suite
docker compose up tests
```

## Test Files

### Core Test Scripts
- **`_env.sh`**: Environment setup and helper functions
  - Sets up environment variables (Kong URL, Keycloak URL, etc.)
  - Provides `wait_for_kong()` and `wait_for_keycloak()` functions
  - Includes `retry_test_after_plugin_change()` helper for testing with retries

- **`run_tests.sh`**: Main test orchestrator
  - Runs all test phases in sequence
  - Exits on first failure

- **`run_unit_tests.sh`**: Lua unit test runner
  - Executes busted unit tests from `spec/` directory

### Setup Scripts
- **`configure_keycloak.sh`**: Keycloak configuration
Sets up Keycloak for testing:
- Creates test realm with configured signing algorithm
- Creates test client with OAuth2 client credentials flow
- Configures client with ES256 signature algorithm by default

- **`configure_jwt_plugin.sh`**: Kong plugin configuration
  - Creates Kong service and route
  - Configures jwt-keycloak plugin
  - Sets up Kong consumer

### Test Suites

#### 1. `test_jwt_keycloak_plugin.sh`
Basic JWT validation functionality:
- Valid token acceptance
- Invalid token rejection
- Consumer matching

#### 2. `test_algorithms.sh`
Algorithm validation and security tests:
- **ES256 token validation** (Elliptic Curve)
  - Validates plugin accepts ES256 tokens from Keycloak
- **'none' algorithm rejection** (Security)
  - Creates unsigned token with `"alg":"none"`
  - Validates plugin rejects with 401
  - Protects against "none algorithm attack"
- **Unsupported algorithm rejection** (Security)
  - Creates token with `"alg":"HS256"`
  - Validates plugin rejects with 401
  - Ensures only supported algorithms are accepted

**Note:** The plugin automatically validates tokens against all supported algorithms:
- RSA: RS256, RS384, RS512
- EC: ES256, ES384, ES512

The `config.algorithm` parameter is deprecated and no longer used. RSA algorithm support is verified through the schema validation and the security tests demonstrate that the plugin correctly validates the algorithm header.

#### 3. `test_error_conditions.sh`
Error handling scenarios:
- Missing token (401)
- Invalid token format (401)
- Expired tokens (401)
- Wrong issuer (401/403)
- OPTIONS preflight requests

#### 4. `test_roles_scopes.sh`
Authorization validation:
- Scope-based authorization
  - Valid scope acceptance (200)
  - Invalid scope rejection (403)
- Realm role validation
  - Valid realm role acceptance (200)
  - Invalid realm role rejection (403)
- Client role validation
  - Valid client role acceptance (200)
  - Invalid client role rejection (403)

#### 5. `test_security_logging.sh`
Security event logging:
- Authentication failure events
- Wrong issuer security events
- Security event code validation (ua200, ua201, ua220, ua222)

## Test Environment Variables
Set in `_env.sh`:
- `KONG_ADMIN_URL`: Kong Admin API endpoint (http://kong:8001)
- `KONG_PROXY_URL`: Kong Proxy endpoint (http://kong:8000)
- `KC_URL`: Keycloak server URL (http://kc:8080)
- `KC_CLIENT_ID`: Test client ID (test-user)
- `KC_CLIENT_SECRET`: Generated client secret (random)
- `KC_SIGNING_KEY_ALGORITHM`: Default signing algorithm (ES256)
- `KC_REALM`: Keycloak realm name (default)

## Helper Functions

### `retry_test_after_plugin_change(description, expected_status, curl_command)`
Retries a test up to 3 times with delays to allow Kong to apply plugin changes.

**Example:**
```bash
if ! retry_test_after_plugin_change "Valid token test" "200" \
  "curl -s -w \"%{http_code}\" -X GET $KONG_PROXY_URL/example/get -H \"Authorization: Bearer $TOKEN\" -o /dev/null"; then
  exit 1
fi
```

**Parameters:**
- `description`: Human-readable test description
- `expected_status`: Expected HTTP status code(s), can be multiple like "200|201"
- `curl_command`: The curl command to execute

## Test Patterns

### Plugin Reconfiguration Pattern
When testing different plugin configurations:

```bash
# Delete existing plugin
curl -s -X DELETE $KONG_ADMIN_URL/plugins/$(curl -s $KONG_ADMIN_URL/plugins | jq -r '.data[] | select(.name=="jwt-keycloak") | .id') > /dev/null

# Create new plugin configuration
curl -s -X POST $KONG_ADMIN_URL/plugins \
  --data "name=jwt-keycloak" \
  --data "config.allowed_iss=$KC_URL/auth/realms/$KC_REALM" \
  --data "config.scope[]=email" \
  --data "route.id=$(curl -s $KONG_ADMIN_URL/routes/example-route | jq -r '.id')"

# Test with retry helper
if ! retry_test_after_plugin_change "Test description" "200" "curl command"; then
  exit 1
fi
```

### Token Retrieval Pattern
```bash
TOKEN_ENDPOINT="$KC_URL/auth/realms/$KC_REALM/protocol/openid-connect/token"

ACCESS_TOKEN=$(curl -s -X POST $TOKEN_ENDPOINT \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$KC_CLIENT_ID" \
  -d "client_secret=$KC_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Failed to obtain access token"
  exit 1
fi
```

### Creating Test Tokens with Specific Algorithms

#### Unsigned Token (none algorithm)
```bash
# Header: {"alg":"none","typ":"JWT"}
NONE_HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
NONE_PAYLOAD=$(echo -n '{"iss":"http://keycloak/realm","sub":"test","exp":9999999999}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
NONE_TOKEN="${NONE_HEADER}.${NONE_PAYLOAD}."
```

#### Unsupported Algorithm Token (HS256)
```bash
# Header: {"alg":"HS256","typ":"JWT"}
HS256_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
HS256_PAYLOAD=$(echo -n '{"iss":"http://keycloak/realm","sub":"test","exp":9999999999}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
HS256_SIGNATURE=$(echo -n "dummy_signature" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
HS256_TOKEN="${HS256_HEADER}.${HS256_PAYLOAD}.${HS256_SIGNATURE}"
```

## Adding New Tests
1. Create a new test file: `test_<feature>.sh`
2. Source `_env.sh` for helper functions
3. Add test execution to `run_tests.sh`
4. Make the script executable: `chmod +x test_<feature>.sh`
5. Document the test in this README

**Example test structure:**
```bash
#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Source environment helpers
if [ -f ./_env.sh ]; then
    . ./_env.sh
fi

echo "🧪 Testing [feature name]..."

# Your test logic here

echo "✅ All [feature] tests passed"
```

## Troubleshooting

### Tests Fail Intermittently
- Kong may take time to apply plugin changes
- Use `retry_test_after_plugin_change()` helper
- Increase retry count or wait time in `_env.sh`

### Services Not Ready
- Increase timeout in `wait_for_kong()` or `wait_for_keycloak()`
- Check service logs: `docker compose logs kong` or `docker compose logs kc`

### Token Validation Fails
- Verify Keycloak configuration in `configure_keycloak.sh`
- Check that token's algorithm is supported (RS256/384/512 or ES256/384/512)
- Inspect token: `echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq .`
- Verify token's `alg` header matches a supported algorithm

### Algorithm-Related Issues
- The plugin automatically validates against all supported algorithms
- `config.algorithm` parameter is deprecated and ignored
- Supported algorithms: RS256, RS384, RS512, ES256, ES384, ES512
- Any other algorithm (including 'none', HS256, etc.) will be rejected with 401
