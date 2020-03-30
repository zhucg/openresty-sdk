
local _M = {
    json = require "cjson",
    zlib = require "zlib",
    pkey = require "resty.openssl.pkey",
    digest = require "resty.openssl.digest"
}

local mt = { __index = _M }

function _M.new(self,opts)
    opts = opts or {}
    local appid = opts.appid
    local privateKey = opts.privateKey
    return setmetatable({
        appid = appid,
        privateKey = privateKey
    }, mt)
end


function _M.genSign(self, uid)
    local uid = uid
    local timestr = ngx.time()
    local pk, err = self.pkey.new(self.privateKey, {
        format = "PEM", -- choice of "PEM", "DER" or "*" for auto detect
        type = "pr", -- choice of "p"r for privatekey, "pu" for public key and "*" for auto detect
    })
    if not pk then
        ngx.say(err)
        ngx.exit(200)
    end

    local digest, err = self.digest.new("SHA256")
    local signStr = "TLS.appid_at_3rd:0\nTLS.account_type:0\nTLS.identifier:"..uid.."\nTLS.sdk_appid:"..self.appid.."\nTLS.time:"..timestr.."\nTLS.expire_after:31536000\n"
    digest:update(signStr)
    local signature, err = pk:sign(digest)
    local gzstr = ngx.encode_base64(signature)
    local jsonTable = {
        ['TLS.account_type'] = '0',
        ['TLS.identifier'] = tostring(uid),
        ['TLS.appid_at_3rd'] = '0',
        ['TLS.sdk_appid'] = self.appid,
        ['TLS.expire_after'] = '31536000',
        ['TLS.version'] = '201512300000',
        ['TLS.time'] = tostring(timestr),
        ['TLS.sig'] = gzstr
    }

    function gsub(str,p,r)
        local newStr, n, err = ngx.re.gsub(str, p, r,"i")
        if newStr then
            return newStr
        else
            return str
        end
    end
    function speciaEncode(str)
        return gsub(gsub(gsub(ngx.encode_base64(str), [[\+]], [[*]]),[[/]], [[-]]),[[=]],[[_]])
    end


    local jsonText = self.json.encode(jsonTable)

    local deflated = self.zlib.deflate(6)(jsonText, "finish")

    return speciaEncode(deflated)
end

return _M
