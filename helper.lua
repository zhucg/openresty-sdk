local _M = {}
--query_db
local mysql = require "resty.mysql"
--encryptOpenid
local aes = require "resty.aes"
--makeToken
local md5 = ngx.md5
local redis = require "redis_iresty"

--print_r
local print = ngx.print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next


local db_spec = {
    host = "127.0.0.1",
    port = "3306",
    database = "Ta",
    user = "",
    password = "",
    max_packet_size = 1024 * 1024
}

function _M.query_db(query)
    local db, err = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "failed to instantiate mysql: ", err)
        return
    end

    db:set_timeout(1000) -- 1 sec

    print("sql query: ", query)

    local ok, err, errno, sqlstate

    for i = 1, 3 do
        ok, err, errno, sqlstate = db:connect(db_spec)
        if not ok then
            ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
            ngx.sleep(0.1)
        else
            break
        end
    end

    if not ok then
        ngx.log(ngx.ERR, "fatal response due to query failures")
        return ngx.exit(500)
    end

    --db:query("set names utf8mb4")

    -- the caller should ensure that the query has no side effects
    local res
    for i = 1, 2 do
        res, err, errno, sqlstate = db:query(query)
        if not res then
            ngx.log(ngx.ERR,"bad result: ", err, ": ", errno, ": ", sqlstate, ".")

            ngx.sleep(0.1)

            ok, err, errno, sqlstate = db:connect(db_spec)
            if not ok then
                ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
                break
            end
        else
            break
        end
    end

    if not res then
        ngx.log(ngx.ERR, "fatal response due to query failures")
        return ngx.exit(500)
    end

    local ok, err = db:set_keepalive(10000, 5)
    if not ok then
        ngx.log(ngx.ERR, "failed to keep alive: ", err)
    end

    return res
end


--获取文件名
function _M.getFileName(str)
    local idx = str:match(".+()%.%w+$")
    if(idx) then
        return str:sub(1, idx-1)
    else
        return str
    end
end

--获取扩展名
function _M.getExtension(str)
    return str:match(".+%.(%w+)$")
end

--解码
function _M.decodeURI(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

--加码
function _M.encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

-- 字符串 split 分割
function _M.split(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end
-- 支持字符串前后 trim
function _M.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
-- 判断目录是否已经存在
function _M.file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end
-- 16进制字符串转2进制
function _M.hex2bin( hexstr )
    local str = ""
    for i = 1, string.len(hexstr) - 1, 2 do
        local doublebytestr = string.sub(hexstr, i, i+1);
        local n = tonumber(doublebytestr, 16);
        if 0 == n then
            str = str .. '\00'
        else
            str = str .. string.format("%c", n)
        end
    end
    return str
end

function _M.to_hex(str)
    return ({str:gsub(".", function(c) return string.format("%02X", c:byte(1)) end)})[1]
end

function _M.encryptOpenid(openid)
    local aes_128_cbc_with_iv = assert(aes:new("GxNl8RnSim40GiDi",nil, aes.cipher(128,"cbc"), {iv='tgfpKDglpReJWrV1'}))
    return _M.to_hex(aes_128_cbc_with_iv:encrypt(openid))
end

function _M.decryptOpenid(token)
    if not _M.isHex(token) then
        return nil
    end
    local aes_128_cbc_with_iv = assert(aes:new("GxNl8RnSim40GiDi",nil, aes.cipher(128,"cbc"), {iv='tgfpKDglpReJWrV1'}))
    return aes_128_cbc_with_iv:decrypt(_M.hex2bin(token))
end

function _M.encrypt(str,aesKey,iv)
    local aes_128_cbc_with_iv = assert(aes:new(aesKey,nil, aes.cipher(128,"cbc"), {iv=iv}))
    return _M.to_hex(aes_128_cbc_with_iv:encrypt(str))
end

function _M.decrypt(str,aesKey,iv)
    if not _M.isHex(token) then
        return nil
    end
    local aes_128_cbc_with_iv = assert(aes:new(aesKey,nil, aes.cipher(128,"cbc"), {iv=iv}))
    return aes_128_cbc_with_iv:decrypt(_M.hex2bin(str))
end

function _M.isHex(str)
    local mm = {}
    local ctx = {pos = 1}
    ngx.re.match(str, [=[[0-9a-fA-F]+]=],"jo",ctx,mm)
    return mm and mm[0]==str
end
-- 按照key对table进行排序
function _M.tableSort(target_table)
    local key_table = {}
    local result = {}
    --取出所有的键
    for key,_ in pairs(target_table) do
        table.insert(key_table,key)
    end
    --    --对所有键进行排序
    table.sort(key_table)

    for _,key in pairs(key_table) do
        result[key] = target_table[key]
    end
    return result
end



function _M.print_r(root)
    local cache = {  [root] = "." }
    local function _dump(t,space,name)
        local temp = {}
        for k,v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
            else
                tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
            end
        end
        return tconcat(temp,"\n"..space)
    end
    print(_dump(root, "",""))
end
--验证用户手机号
function _M.checkIsMobile(str)
    local m = ngx.re.match(str,"[1][3,4,5,6,7,8][0-9]{9}")
        if m then
            return m[0]==str
        else
            return false
        end
end
--生成token
function _M.makeToken(mobile)
    local red = redis:new()
    local uniqidTable, err = red:time()
    if not uniqidTable then
        ngx.log(ngx.ERR,"bad uniqidTable: ", err)
        return nil
    end
    return md5(uniqidTable[1]..uniqidTable[2]..mobile)
end
return _M
