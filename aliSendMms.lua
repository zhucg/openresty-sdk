local http = require "resty.http"
local cjson = require "cjson"
local helper = require "helper"

local encodeURI = helper.encodeURI
local appKey = '--'
local secretKey = '--'
local templateCode = '--'
local dayu_sign = [[****]]

local _M = {}

local mt = {__index = _M} 

function _M.new(self)
    return setmetatable({}, mt)
end


function _M.speciaUrlEncode(self,str)
    return self:gsub(self:gsub(self:gsub(self:gsub(encodeURI(str), "+", "%20"),"*", "%2A"),'%7E','~'),"%5F","_")
end

function _M.gsub(self,str,p,r)
    local newStr, n, err = ngx.re.gsub(str, p, r,"i")
    if newStr then
        return newStr
    else
        return str
    end
end

function _M.send(self, phoneNumber, code)
    local timeStr = ngx.utctime()
    local timeStr = string.sub(timeStr, 1, 10)..[[T]].. string.sub(timeStr, 12, -1)..[[Z]]


    local params = {
        SignatureMethod = "HMAC-SHA1",
        SignatureNonce = ngx.time()..math.random(10000,99999),
        SignatureVersion = "1.0",
        AccessKeyId = appKey,
        Timestamp = timeStr,
        Format = "JSON",
        RegionId = "cn-hangzhou",
        Action = "SendSms",
        Version = "2017-05-25",
        PhoneNumbers = phoneNumber,
        SignName = dayu_sign,
        TemplateCode = templateCode,
        TemplateParam = [[{"code":"]]..code..[["}]],
    }
    local query = self:_tableSortToStr(params)


    local key = self:_sign(self:speciaUrlEncode(query))
    params['Signature'] = self:speciaUrlEncode(key)

    local headers = {["Content-Type"] = "application/json;charset=utf-8"}

    local url = "http://dysmsapi.aliyuncs.com/"
    local res, err = self:_send_http_request(url, 'Signature='..params['Signature']..'&'..query)
    if 200 ~= res.status then
        ngx.say("出错啦")
        ngx.log(ngx.ERR, res.status, err)
        return false
    end
    ngx.say(res.body)
end

function _M._sign(self, str)
    local key = ngx.encode_base64(ngx.hmac_sha1(secretKey .. '&', [[GET&%2F&]]..str))
    return key
end

function _M._send_http_request(self, url, body)
    local httpc = http.new()

    local res, err = httpc:request_uri(url, {
        method = "GET",
        query = body,
        headers = {["Content-Type"] = "application/json;charset=utf-8" },
        ssl_verify = false,
    })
    httpc:set_keepalive(30000, 10)
    return res, err
end

-- 按照key对table进行排序
function _M._tableSortToStr(self,target_table)
    local key_table = {}
    local str = ''
    --取出所有的键
    for key,_ in pairs(target_table) do
        table.insert(key_table,key)
    end
    --对所有键进行排序
    table.sort(key_table)

    for _,key in pairs(key_table) do
        str = str .. self:speciaUrlEncode(key) .. '=' .. self:speciaUrlEncode(target_table[key]) .. '&'
    end
    str = string.sub(str, 0, -2)
    return str
end



return _M
