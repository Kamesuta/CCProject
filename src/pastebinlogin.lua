if not fs.exists'N' then shell.run('pastebin','run','BUMK9sYW','-init') end dofile'N'

local args = {...}
if (#args <= 0) then
  error("Arg1:ID Arg2:Pass")
end
local res = N.Code.new():fromPost(
  'http://pastebin.com/api/api_login.php',
  {
    api_dev_key = N.Reference.dev_key,
    api_user_name = args[1],
    api_user_password = args[2],
  }
)
print(res:get())