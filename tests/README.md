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
  - Creates realm and client
  - Generates client secret
  - Configures signing keys

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

#### 2. `test_ec_algorithms.sh`
EC (Elliptic Curve) algorithm support:
- ES256 token validation
- Algorithm mismatch rejection
- Verifies tokens signed with EC algorithms work correctly

#### 3. `test_multiple_algorithms.sh` (NEW)
Multiple algorithm configuration:
- **Test 1**: Token acceptance when algorithm is in allowed list
  - Configures plugin with `[RS256, RS384, ES256, ES384]`
  - Verifies ES256 token is accepted
- **Test 2**: Token rejection when algorithm is NOT in allowed list
  - Configures plugin with `[RS256, RS384, RS512]` (no ES256)
  - Verifies ES256 token is rejected (401)
- **Test 3**: Single algorithm configuration (backward compatibility)
  - Uses old-style single value: `config.algorithm=ES256`
  - Verifies backward compatibility is maintained
- **Test 4**: Default algorithm behavior
  - No algorithm specified (defaults to RS256)
  - Verifies ES256 token is rejected

#### 4. `test_error_conditions.sh`
Error handling scenarios:
- Malformed tokens
- Expired tokens
- Invalid signatures
- Missing required claims

#### 5. `test_roles_scopes.sh`
Authorization validation:
- Scope-based authorization
- Realm role validation
- Client role validation
- Resource access validation

#### 6. `test_security_logging.sh`
Security event logging:
- Authentication events
- Authorization failures
- Security event formatting

## Test Environment Variables

Set in `_env.sh`:
- `KONG_ADMIN_URL`: Kong Admin API endpoint
- `KONG_PROXY_URL`: Kong Proxy endpoint
- `KC_URL`: Keycloak server URL
- `KC_CLIENT_ID`: Test client ID
- `KC_CLIENT_SECRET`: Generated client secret
- `KC_SIGNING_KEY_ALGORITHM`: Default signing algorithm (ES256)
- `KC_REALM`: Keycloak realm name

## Adding New Tests

1. Create a new test file: `test_<feature>.sh`
2. Source `_env.sh` for helper functions
3. Add test execution to `run_tests.sh`
4. Make the script executable: `chmod +x test_<feature>.sh`
5. Document the test in this README

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
  --data "config.algorithm[]=RS256" \
  --data "config.algorithm[]=ES256" \
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
- Check algorithm matches between Keycloak and plugin config
- Inspect token: `echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq .`
