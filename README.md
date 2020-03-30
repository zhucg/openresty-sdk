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




openresty安装openssl扩展

opm get fffonion/lua-resty-openssl

安装完成会在site/lualib/resty目录下生成扩展需要的文件

安装完成需要修改pkey.lua第15行文件，修改为
require "resty.openssl.include.x509_vfy"


让lua支持zlib压缩

https://github.com/brimworks/lua-zlib

下载 https://github.com/brimworks/lua-zlib/archive/master.zip
解压缩 unzip master.zip
进到解压目录执行以下编译命令

cmake -DLUA_INCLUDE_DIR=/usr/local/openresty/luajit/include/luajit-2.1 -DLUA_LIBRARIES=/usr/local/openresty/luajit/lib -DUSE_LUAJIT=ON -DUSE_LUA=OFF
make && make install

编译后，将zlib.so复制到/opt/openresty/lualib/

local zlib = require "zlib"
local test_string = 'abcdefg'
local deflated = zlib.deflate()(test_string, "finish")
--ngx.say(tostring(deflated))
local stream = zlib.inflate()
local r=stream(deflated);
ngx.say(r)
