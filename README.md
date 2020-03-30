# openresty-sdk
做直播项目，用openresty提高并发，各种第三方sdk不支持，只好自己实现



--使用方法 用openresty实现阿里短信发送的功能

local args, err = ngx.req.get_uri_args()


local sms = require "aliSendMms"


local s = sms:new()


s:send('13911111111','123456')



--腾讯im的usersig  用openresty实现腾讯im的签名功能


local imUserSig = require "UserSig"


local privateKey = [[-----BEGIN PRIVATE KEY-----

pem文件内容

-----END PRIVATE KEY-----]]

local imObj = imUserSig:new({appid='12345678', privateKey=privateKey})

local sig = imObj:genSign('uid')

ngx.say(sig)
