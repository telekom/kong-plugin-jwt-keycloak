<!--
SPDX-FileCopyrightText: 2025 Deutsche Telekom AG

SPDX-License-Identifier: Apache-2.0
-->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kong-plugin-jwt-keycloak is a plugin for Kong API Gateway that validates JWT tokens issued by Keycloak. It allows Kong to authenticate and authorize requests using Keycloak's JWT tokens, supporting role-based access control through token claims.

Key features:
- Validates JWT tokens issued by Keycloak
- Supports rotating public keys
- Authorization based on token claims (scope, realm_access, resource_access)
- Matches Keycloak users/clients to Kong consumers
- Supports RSA (RS256, RS384, RS512) and EC (ES256, ES384, ES512) signature algorithms

## Development Environment

The project uses Docker containers for development and testing. The development environment includes:
- Kong API Gateway
- Postgres database for Kong
- Keycloak server for authentication
- Test utilities

The repository includes a reference to the original Kong source code:
- `.original-kong/`: Contains the original Kong 3.9.1 repository for reference

## Architecture

The plugin follows Kong's plugin architecture:
- `handler.lua`: Main entry point that handles request processing
  - Extends the official Kong JWT plugin with Keycloak-specific validation
  - Implements token signature validation using Keycloak public keys
  - Performs role, scope, and claim validation
  - Manages consumer matching and authentication
- `schema.lua`: Defines configuration schema for the plugin
  - Defines all configurable parameters for the plugin
  - Sets default values and validation rules
- `keycloak_keys.lua`: Retrieves and manages Keycloak public keys
  - Fetches public keys from Keycloak's well-known endpoints
  - Manages key caching and updates
- `key_conversion.lua`: Converts Keycloak JWK format to PEM format
  - Supports both RSA and EC (Elliptic Curve) key formats
  - Handles different EC curves (P-256, P-384, P-521)
- `validators/`: Directory containing validation logic for claims, roles, scopes
  - `issuers.lua`: Validates the token issuer against allowed issuers
  - `roles.lua`: Validates realm roles and client roles
  - `scope.lua`: Validates token scopes

## Common Commands

### Building the Plugin

```bash
# Build the plugin and create a Docker image
make build KONG_VERSION=3.4.0 PLUGIN_VERSION=1.3.0-1

# Build using LuaRocks
luarocks make
```

### Running the Plugin

```bash
# Start all services (Kong, Postgres, Keycloak)
make all

# Start only Kong and its database
make start

# Start only Keycloak
make keycloak-start
```

### Testing

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration

# Test with multiple Kong versions
make test-all
```

### Debugging

```bash
# View Kong proxy logs
make kong-logs

# View Kong error logs (proxy)
make kong-logs-proxy-err 

# View Kong error logs (admin)
make kong-logs-admin-err

# View Keycloak logs
make keycloak-logs
```

## Development Workflow

1. Clone the repository
2. Start the development environment: `make all` 
3. Make changes to the plugin code
4. Run tests to verify changes: `make test`
5. Build the plugin: `make build`

## Testing with Docker Compose

The repository includes Docker Compose setup for easier testing:

```bash
# Start all services with Docker Compose
docker-compose up -d

# Run the tests
docker-compose up tests
```

## Version Compatibility

The plugin supports these version combinations:
- Kong: 2.8.1 and higher (3.0.0, 3.1.0, 3.2.2, 3.3.0, 3.4.0, 3.9.1)
- Postgres: 12.x and higher
- Keycloak: 9.0.3 (RHSSO-7.4), 15.0.2 (RHSSO-7.5), and 26.2.0

## Algorithm Support

The plugin automatically validates JWT tokens with the following signature algorithms:
- **RSA algorithms**: RS256, RS384, RS512
- **EC algorithms**: ES256, ES384, ES512

The algorithm is validated from the JWT's `alg` header field. The plugin no longer uses the `config.algorithm` parameter (deprecated), and instead validates that the token's algorithm is one of the supported algorithms listed above.