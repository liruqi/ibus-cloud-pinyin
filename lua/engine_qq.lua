--[[----------------------------------------------------------------------------
 ibus-cloud-pinyin - cloud pinyin client for ibus
 QQ Web Pinyin Client Script

 Copyright (C) 2010 WU Jun <quark@lihdd.net>

 This file is part of ibus-cloud-pinyin.

 ibus-cloud-pinyin is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 ibus-cloud-pinyin is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with ibus-cloud-pinyin.  If not, see <http://www.gnu.org/licenses/>.
--]]----------------------------------------------------------------------------

-- for run standalone
user_cache_path = user_cache_path or '/tmp'
pinyin = pinyin or arg[1]
response = response or print

http = require 'socket.http'
socket = require 'socket'

http.USERAGENT = "ibus-cloud-pinyin"
uid = math.random(900) + 100
key_file = user_cache_path..'/.tencent-key.'..uid

py = pinyin:gsub("[^a-z ]", ''):gsub(" ", '%%27')


function refresh_key()
	local ret = http.request('http://ime.qq.com/fcgi-bin/getkey?callback=window.QQWebIME.keyback'..uid) or ''
	key = ret:gsub('"key"', ''):match('"(.-)"') or ''
	if #key > 0 then local file = io.open(key_file, 'w') file:write(key) file:close() end
end

http.TIMEOUT, retry = 2, 100

-- get key
local file = io.open(key_file, 'r')
if file then key = file:read("*line") or '' file:close() end
for attempt = 1, retry do
	if (not key) or (#key == 0) then
		http.TIMEOUT = http.TIMEOUT * 1.5 refresh_key()
	else break end
end

function try_convert(tail, tail_len)
	local py_tail = (tail or ''):gsub(' ','%%27')
	tail_len = tail_len or 0
	http.TIMEOUT, retry = 1.2
	while true do
		-- print('requesting, timeout = '..http.TIMEOUT)
		local ret = http.request("http://ime.qq.com/fcgi-bin/getword?key="..key..'&callback=window.QQWebIME.callback'..uid..'&q='..py..py_tail)
		local res = ret and ret:match('%"rs%"%:%[(.-)%]')
		if res then
			local content = res
			local first_word = content:match('"(.-)"')
			if first_word and #first_word > 2 then
				response(first_word:sub(1, #first_word - 3 * tail_len), '\n')
				return true
			else
				-- not a valid return, try another tail
				return 2
			end
		end
		http.TIMEOUT = http.TIMEOUT * 2
		if http.TIMEOUT > 18 then break end
	end
	return 0
end

-- try various tails
local r = try_convert()
if r == true then return end -- success

-- mark key as invalid (delete it)
os.remove(key_file)

-- ibus-cloud-pinyin --
