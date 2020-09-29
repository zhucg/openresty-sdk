接口：
敏感词检查
https://mp.weixin.qq.com/cgi-bin/announce?token=976729357&action=getannouncement&key=11522142966rk3L2&version=1&lang=zh_CN&platform=2
获取access_token
https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/access-token/auth.getAccessToken.html

公共的access_token缓存在nginx的共享内存中：
lua_shared_dict ocache 10m;
因为access_token有访问次数限制，所以如果其他业务也需要这个值，需要从缓存中获取，而不是重新获取


package.path = '/usr/local/openresty/lualib/?.lua;/usr/local/openresty/html/?.lua;'

function get_from_cache(key)
    local cache_ngx = ngx.shared.ocache
    local value = cache_ngx:get(key)
    return value
end

function set_to_cache(key, value, exptime)
    if not exptime then
        exptime = 0
    end

    local cache_ngx = ngx.shared.ocache
    local succ, err, forcible = cache_ngx:set(key, value, exptime)
    return succ
end


local args, err = ngx.req.get_uri_args()

local appid = ''
local secret= ''
--使用nginx的共享内存，在配置文件中定义的名字ocache
local cache_ngx = ngx.shared.ocache

local http = require "resty.http"
local json = require("cjson")


local token = get_from_cache("token")
local httpc = http.new()
if not token then
    local wxres, err = httpc:request_uri("https://api.weixin.qq.com/cgi-bin/token", {
        method = "GET",
        query = {
            appid      = appid,
            secret     = secret,
            grant_type = "client_credential"
        },
        headers = {["Content-Type"] = "application/x-www-form-urlencoded" },
        ssl_verify = false,
    })

    if 200 ~= wxres.status then
            ngx.log(ngx.ERR,"bad request_uri: ", err)
            ngx.exit(wxres.status)
    end
    local t = json.decode(wxres.body)
    set_to_cache("token", t.access_token, t.expires_in)
    token = t.access_token

end
    local wxres, err = httpc:request_uri("https://api.weixin.qq.com/wxa/msg_sec_check?access_token="..token, {
        method = "POST",
        body = '{"content":"'..args.content..'"}',
        headers = {["Content-Type"] = "application/json" },
        ssl_verify = false,
    })
    if 200 ~= wxres.status then
        ngx.log(ngx.ERR,"bad request_uri: ", err)
        ngx.exit(wxres.status)
    end
    local t = json.decode(wxres.body)

    if t.errcode ~= 0 then
        ngx.say([[{"errcode": 87014,"errmsg": "risky content"}]])
        --ngx.say(wxres.body)
        --ngx.exit(403)
    else

        local wxres, err = httpc:request_uri("https://api.game8808.cn/video/", {
        --local wxres, err = httpc:request_uri("https://wechat.api.game8808.cn/", {
            method = "GET",
            query = args,
            headers = {["Content-Type"] = "application/x-www-form-urlencoded" },
            ssl_verify = false,
        })
        ngx.say(wxres.body)
    end


daemon on;
master_process on;
worker_processes auto;
worker_cpu_affinity auto;
error_log logs/error.log info;
pid logs/nginx.pid;
#pcre_jit on;
#
events {
    accept_mutex off;
}

http {
    server_tokens off;
    lua_package_path "$prefix/lua/?.lua;$prefix/lua/vendor/?.lua;;";
    lua_code_cache on;

    include       mime.types;
    charset utf-8;
    default_type  application/octet-stream;

    lua_shared_dict ocache 10m;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for" '
                      '"$request_body"';

    access_log  logs/access.log  main;
    server {
        listen 443 ssl;
        server_name  wechat.api.game8808.cn;
        
        ssl_certificate      /usr/local/openresty/nginx/ssl/fullchain.cer;
        ssl_certificate_key  /usr/local/openresty/nginx/ssl/wechat.api.game8808.cn.key;
        
        root html;

        charset utf-8;
        default_type 'text/plain';
        #access_log  logs/host.access.log  main;
        resolver 114.114.114.114;

        location / {
            root   html;
            index  index.html index.htm;
        }

        location /checkmsg {
            content_by_lua_file html/checkmsg.lua;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

    }

}

