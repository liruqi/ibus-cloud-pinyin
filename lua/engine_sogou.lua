--[[----------------------------------------------------------------------------
 ibus-cloud-pinyin - cloud pinyin client for ibus
 Sogou Web Pinyin Client Script

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
url = require 'socket.url'

http.USERAGENT = "ibus-cloud-pinyin"
key_file = user_cache_path..'/.sogou-key'

py = pinyin:gsub("[^a-z]", '')

function refresh_key()
	local ret = http.request('http://web.pinyin.sogou.com/web_ime/patch.php') or ''
	key = ret:match('"(.-)"') or ''
	if #key > 0 then local file = io.open(key_file, 'w') file:write(key) file:close() end
end

start_time = os.time()
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
	local py_tail = (tail or ''):gsub(' ','')
	tail_len = tail_len or 0
	http.TIMEOUT, retry = 1.2
	while true do
		-- print('requesting, timeout = '..http.TIMEOUT)
		local ret = http.request('http://web.pinyin.sogou.com/api/py?key='..key..'&query='..py..py_tail)
		local res = ret and ret:match('ime_callback%("(.-)"')
		if res then
			local content = url.unescape(res)
			local first_word = content:match('(.-)：')
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
for _, v in pairs{{'', 0}, {'ne', 1}, {'a', 1}, {'le', 1}, {'ma', 1}, {'zhe', 1}, {'na', 1}, {'zhe yang de', 3}, {'zhen de ma', 3}, {'ting hao de', 3}, {'shui xiang xin', 3}, {'zhe shi zhen de ma', 5}, {'na shi bu ke neng de', 6}, {'ni zhi dao ma', 4}, {'ni bu zhi dao', 4}, {'bie wang le a', 4}} do
	local r = try_convert(v[1], v[2])
	if r == 0 then break end -- timeout, network problem
	if r == true then return end -- success
	-- if r == 2, just go on retrying...
end

-- mark key as invalid (delete it)
os.remove(key_file)

-- ibus-cloud-pinyin --
