-- SPDX-FileCopyrightText: 2025 2025 Deutsche Telekom AG
--
-- SPDX-License-Identifier: Apache-2.0

-- Taken from https://github.com/zmartzone/lua-resty-openidc/blob/master/lib/resty/openidc.lua
-- Extended with ECDSA support

local string = string
local b64 = ngx.encode_base64
local unb64 = ngx.decode_base64

local function encode_length(length)
    if length < 0x80 then
        return string.char(length)
    elseif length < 0x100 then
        return string.char(0x81, length)
    elseif length < 0x10000 then
        return string.char(0x82, math.floor(length / 0x100), length % 0x100)
    end
    error("Can't encode lengths over 65535")
end

local function encode_bit_string(array)
    local s = "\0" .. array -- first octet holds the number of unused bits
    return "\3" .. encode_length(#s) .. s
end

local function encode_sequence(array, of)
    local encoded_array = array
    if of then
        encoded_array = {}
        for i = 1, #array do
            encoded_array[i] = of(array[i])
        end
    end
    encoded_array = table.concat(encoded_array)
    return string.char(0x30) .. encode_length(#encoded_array) .. encoded_array
end

local function der2pem(data, _)
    local encoded = b64(data)
    local pem = ""
    
    -- Wrap at 64 characters
    while #encoded > 64 do
        pem = pem .. encoded:sub(1, 64) .. "\n"
        encoded = encoded:sub(65)
    end
    
    -- Add remaining data
    if #encoded > 0 then
        pem = pem .. encoded .. "\n"
    end

    return pem
end

local function encode_binary_integer(bytes)
    if bytes:byte(1) > 127 then
        -- We currently only use this for unsigned integers,
        -- however since the high bit is set here, it would look
        -- like a negative signed int, so prefix with zeroes
        bytes = "\0" .. bytes
    end
    return "\2" .. encode_length(#bytes) .. bytes
end

local function encode_sequence_of_integer(array)
    return encode_sequence(array, encode_binary_integer)
end

local function openidc_base64_url_decode(input)
    local reminder = #input % 4
    if reminder > 0 then
        local padlen = 4 - reminder
        input = input .. string.rep('=', padlen)
    end
    input = input:gsub('-', '+'):gsub('_', '/')
    return unb64(input)
end

local function openidc_pem_from_rsa_n_and_e(n, e)

    kong.log.debug("Converting RSA key to PEM format")
    kong.log.debug("n: ", n)
    kong.log.debug("e: ", e)

    local der_key = {
        openidc_base64_url_decode(n), openidc_base64_url_decode(e)
    }

    local encoded_key = encode_sequence_of_integer(der_key)
    local der = encode_sequence({
        encode_sequence({
        "\6\9\42\134\72\134\247\13\1\1\1" -- OID :rsaEncryption
        .. "\5\0" -- ASN.1 NULL of length 0
        }),
        encode_bit_string(encoded_key)
    })
    
    local pem = der2pem(der, "PUBLIC KEY")
    kong.log.debug("PEM format: ", pem)
    return pem
end

-- OIDs for EC curve types
local ec_curve_oids = {
    ["P-256"] = "\6\8\42\134\72\206\61\3\1\7", -- prime256v1 (nistp256, secp256r1)
    ["P-384"] = "\6\5\43\129\4\0\34",          -- secp384r1
    ["P-521"] = "\6\5\43\129\4\0\35",          -- secp521r1
}

-- Function to convert an EC key from JWK format to PEM
local function openidc_pem_from_ec(x, y, crv)
    kong.log.debug("Converting EC key to PEM format")
    kong.log.debug("x: ", x)
    kong.log.debug("y: ", y)
    kong.log.debug("crv: ", crv)
    -- Default to P-256 if curve not specified
    local curve = crv or "P-256"
    local curve_oid = ec_curve_oids[curve]
    
    if not curve_oid then
        error("Unsupported EC curve: " .. curve)
    end
    
    -- Decode the x and y coordinates
    local x_bin = openidc_base64_url_decode(x)
    local y_bin = openidc_base64_url_decode(y)
    
    -- Uncompressed point format is "04 || x || y"
    local point = "\4" .. x_bin .. y_bin
    
    -- Create the EC public key in DER format
    local der = encode_sequence({
        encode_sequence({
            "\6\7\42\134\72\206\61\2\1", -- OID: ecPublicKey
            curve_oid                     -- OID: specific curve
        }),
        encode_bit_string(point)
    })

    -- Convert to PEM
    local pem = der2pem(der, "PUBLIC KEY")
    kong.log.debug("PEM format: ", pem)
    return pem
end

-- Main conversion function that handles different key types
local function convert_kc_key(key)
    -- Determine the key type
    if key.kty == "RSA" then
        return openidc_pem_from_rsa_n_and_e(key.n, key.e)
    elseif key.kty == "EC" then
        return openidc_pem_from_ec(key.x, key.y, key.crv)
    else
        -- If kty is nil, default to RSA for backward compatibility
        if key.n and key.e then
            return openidc_pem_from_rsa_n_and_e(key.n, key.e)
        end
        
        error("Unsupported key type: " .. (key.kty or "unknown"))
    end
end

return {
    convert_kc_key = convert_kc_key
}