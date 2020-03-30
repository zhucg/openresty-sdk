local appid = 'appid'
local secret = 'appscret'

local args, err = ngx.req.get_uri_args()

local helper = require "helper"
local http = require "resty.http"

local urldecode = helper.decodeURI
local decode_base64 = ngx.decode_base64
local decrypt = helper.decrypt


local code = args.code;

local iv = urldecode(args.iv);
local encryptedData = urldecode(args.encryptedData);

local httpc = http.new()
local wxres, err = httpc:request_uri("https://api.weixin.qq.com/sns/jscode2session", {
    method = "GET",
    query = 'appid='..appid..'&secret='..secret..'&js_code='..code..'&grant_type=authorization_code',
    headers = {["Content-Type"] = "application/x-www-form-urlencoded" },
    ssl_verify = false,
})

if 200 ~= wxres.status then
    ngx.log(ngx.ERR,"bad request_uri: ", err)
    ngx.exit(wxres.status)
end

local json = require("cjson")
local t = json.decode(wxres.body)
if t.errcode then
    ngx.log(ngx.ERR,"Json parsing error: ",wxres.body)
    ngx.exit(403)
end

local session_key = t.session_key
local openid = t.openid

local aesKey=decode_base64(session_key);
local aesIV=decode_base64(iv);
local aesCipher=decode_base64(encryptedData);
local result=decrypt(aesCipher,aesKey,aesIV)

local userinfo = json.decode(helper.trim(result))

ngx.say(userinfo.phoneNumber)
helper.print_r(userinfo)
