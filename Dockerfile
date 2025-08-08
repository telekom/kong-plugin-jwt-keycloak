# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

## Build plugin
ARG KONG_VERSION=3.9.1

FROM docker.io/kong:${KONG_VERSION} AS builder

# Root needed to install dependencies
USER root

# Starting from kong 3.2 they move from alpine to debian .. so conditional install logic is needed
ARG DISTO_ADDONS="zip unzip"
RUN if [ -x "$(command -v apk)" ]; then apk add --no-cache $DISTO_ADDONS; \
    elif [ -x "$(command -v apt-get)" ]; then apt-get update && apt-get install -y $DISTO_ADDONS; \
    fi
WORKDIR /tmp

COPY ./*.rockspec /tmp
COPY ./LICENSES/Apache-2.0.txt /tmp/LICENSE
COPY ./src /tmp/src
ARG PLUGIN_VERSION
RUN luarocks make && luarocks pack kong-plugin-jwt-keycloak ${PLUGIN_VERSION}

## Create Image
FROM docker.io/kong:${KONG_VERSION}

ENV KONG_PLUGINS="bundled,jwt-keycloak"

COPY --from=builder /tmp/*.rock /tmp/

# Root needed for installing plugin
USER root

ARG FIX_DEPENDENCIES="gcc musl-dev"
RUN if [ -x "$(command -v apk)" ]; then apk add --no-cache $FIX_DEPENDENCIES; \
    elif [ -x "$(command -v apt-get)" ]; then apt-get update && apt-get install -y $FIX_DEPENDENCIES; \
    fi; \
    # --only-server fix based on https://support.konghq.com/support/s/article/LuaRocks-Error-main-function-has-more-than-65536-constants
    luarocks --only-server https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/daab2726276e3282dc347b89a42a5107c3500567 \
    install luaossl OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong; \
    if [ -x "$(command -v apk)" ]; then apk del $FIX_DEPENDENCIES; \
    elif [ -x "$(command -v apt-get)" ]; then apt-get remove --purge -y $FIX_DEPENDENCIES; \
    fi

ARG PLUGIN_VERSION=1.4.0-1
RUN luarocks install /tmp/kong-plugin-jwt-keycloak-${PLUGIN_VERSION}.all.rock

USER kong
