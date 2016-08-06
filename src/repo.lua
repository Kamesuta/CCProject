Reference = {
  localRepo = 'repo/',
  localSystem = '.repo/',
  remoteDB = '.repo/remote.json',
  localDB = '.repo/local.json',
  dev_key = '8eb670559bf070612041dc14d0502248',
  user_key = 'd7f12b0137d6ba187cef85295ca646b7',
}

Util = {
  join = function(tbl, sep)
    local ret = ''
    for _,v in ipairs(tbl) do
      local seg = tostring(v)
      if ret == nil then
        ret = seg
      else
        ret = ret..sep..seg
      end
    end
    return ret
  end,
  split = function(str, sep)
    local sep, fields = sep or ':', {}
    local pattern = string.format('([^%s]+)', sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
  end,
  merge = function(first, second)
    for _, v in ipairs(second) do
      table.insert(first, v)
    end

    return first
  end,
  extend = function(...)
    local arguments = {...}
    local options, src, clone
    local target = arguments[ 1 ] or {}
    local i = 2
    local length = #arguments
    local deep = false
    -- Handle a deep copy situation
    if type(target)=='boolean' then
      deep = target
      -- Skip the boolean and the target
      target = arguments[ i ] or {}
      i = i+1
    end
    -- Handle case when target is a string or something (possible in deep copy)
    if type(target)~='table' then
      target = {}
    end
    for j=i, length do
      -- Only deal with non-null/undefined values
      options = arguments[ j ]
      if options~=nil then
        -- Extend the base object
        for name, copy in pairs(options) do
          src = target[ name ]
          -- Prevent never-ending loop
          if target~=copy then
            -- Recurse if we're merging plain objects or arrays
            if deep and copy and type(copy)=='table' then
              clone = src or {}
              -- Never move original objects, clone them
              target[ name ] = Util.extend( deep, clone, copy )
            -- Don't bring in undefined values
            elseif copy~=nil then
              target[ name ] = copy
            end
          end
        end
      end
    end
    -- Return the modified object
    return target
  end,
}

Repo = {}
Code = {}
Code.new = function(code)
  local obj = {
    code = code,
  }
  return setmetatable(obj, {__index = Code})
end
Code.fromString = function(this, code)
  if not this.code then
    this.code = code
  end
  return this
end
Code.fromGet = function(this, url, ...)
  if not this.code then
    local data = Util.join({...}, '&')
    local response = http.get(url..data)
    if response then
      this.code = response.readAll()
      response.close()
    end
  end
  return this
end
Code.fromPost = function(this, url, ...)
  if not this.code then
    local data = Util.join({...}, '&')
    local response = http.post(url, data)
    if response then
      this.code = response.readAll()
      response.close()
    end
  end
  return this
end
Code.fromFile = function(this, path)
  if not this.code then
    if fs.exists(path) then
      local file = fs.open(path, 'r')
      this.code = file.readAll()
      file.close()
      this.from = path
    end
    this:bind(path)
  end
  return this
end
Code.bind = function(this, path)
  this.file = path
  return this
end
Code.delete = function(this)
  if this.file then
    fs.delete(this.file)
  end
  return this
end
Code.getBind = function(this)
  return this.file
end
Code.reset = function(this)
  this.code = nil
  this.from = nil
  return this
end
Code.exists = function(this)
  return this.code~=nil
end
Code.save = function(this, path)
  if this.code then
    local p = path or this.file
    if p~=this.from then
      if p then
        local file = fs.open(p, 'w')
        file.write(this.code)
        file.close()
      end
    end
  end
  return this
end
Code.loadcode = function(this, name)
  if this.code then
    return loadstring(this.code, name or this.file or 'code')
  end
end
Code.execute = function(this, ...)
  if this.code then
    return this:loadcode()(...)
  end
end
Code.invoke = function(this, ...)
  if this.code then
    local func = this:loadcode()
    setfenv(func, getfenv())
    return func(...)
  end
end
Code.api = function(this, ...)
  if this.code then
    local tEnv = {}
    setmetatable( tEnv, { __index = _G } )
    local fnAPI, err = this:loadcode()
    if fnAPI then
      setfenv( fnAPI, tEnv )
      fnAPI(...)

      local tAPI = {}
      for k,v in pairs( tEnv ) do
        tAPI[k] =  v
      end

      return tAPI
    end
  end
end
Code.get = function(this)
  return this.code
end

Lib = {
  XML = Code.new():fromFile(Reference.localSystem..'xml.lua'):fromGet('http://pastebin.com/raw/cFDg20XW'):save():execute(),
  JSON = Code.new():fromFile(Reference.localSystem..'json.lua'):fromGet('http://pastebin.com/raw/4YncwwC6'):save():execute(),
}

Pastebin = {}
Pastebin.new = function()
  local obj = {}
  obj.dbinit = {
    id = DataBase.PRIMARY_KEY,
    'title',
    name = DataBase.UNIQUE_KEY,
    'version',
  }
  obj.localrepocode = Code.new():fromFile(Reference.localDB)
  obj.localrepo = IODataBase.new():init(obj.dbinit):fromCode(obj.localrepocode)
  obj.remoterepocode = Code.new():fromFile(Reference.remoteDB)
  obj.remoterepo = IODataBase.new():init(obj.dbinit):fromCode(obj.remoterepocode)
  return setmetatable(obj, {__index = Pastebin})
end
Pastebin.update = function(this, ...)
  local updates = {this.remoterepo:get(...)}
  for _,updatel in ipairs(updates) do
    for update,entry in pairs(updatel) do
      Code.new():fromGet('http://pastebin.com/raw/'..entry.id):save(entry.name)
    end
  end
  return this
end
Pastebin.fetch = function(this)
  this.remoterepo:clear()
  local remoteRepoCode = Code.new():fromPost(
    'http://pastebin.com/api/api_post.php',
    'api_option=list',
    'api_dev_key='..Reference.dev_key,
    'api_user_key='..Reference.user_key
  )
  if remoteRepoCode:exists() then
    local remoteRepoData = Lib.XML.Parser.new():ParseXmlText(remoteRepoCode:get())
    for _,v in ipairs(remoteRepoData.paste) do
      local id = v.paste_key:value()
      local title = v.paste_title:value()
      local name = title:match('^.-#(.-)#.-$')
      local version = title:match('^.-@(.-)@.-$')
      this.remoterepo:put{
        id = id,
        title = title,
        name = name,
        version = version,
      }
    end
    this.remoterepo:save(this.remoterepocode)
  end
  return this
end
Pastebin.add = function(this, ...)
  this.localrepo:put(this.remoterepo:get(...))
  this.localrepo:save(this.localrepocode)
  return this
end
Pastebin.merge = function(this)
  local remoteentries = this.remoterepo:get{}
  local localentries = this.localrepo:get{}
  for i,localentry in pairs(localentries) do
    local remoteentry = remoteentries[i]
    if remoteentry.version~=localentry.version then
      Code.new():fromGet('http://pastebin.com/raw/'..localentry.id):save(Reference.localRepo..localentry.name)
      localrepo:put(remoteentry)
    else
      Code.new():fromFile(Reference.localRepo..localentry.name):fromGet('http://pastebin.com/raw/'..localentry.id):save()
    end
  end
  this.localrepo:save(this.localrepocode)
  return this
end
-- TODO
--Pastebin.rm = function(this, ...)
--  local rms = {this.localrepo:get(...)}
--  for _,rml in ipairs(rms) do
--    for rm,entry in pairs(rml) do
--      Code.new():bind(entry.name):delete()
--    end
--  end
--  this.localrepo:rm(unpack(rms))
--  this.localrepo:save(this.localrepocode)
--  return this
--end

DataBase = {}
DataBase.new = function()
  local obj = {}
  return setmetatable(obj, {__index = DataBase})
end
DataBase.fromData = function(this, db)
  if not this.db then
    this.db = db
  end
  return this
end
DataBase.init = function(this, init)
  if not this.db then
    this.db = {
      init = init,
      meta = {},
      data = {
        index = {},
        obj = {},
      },
    }
    for _1,_2 in pairs(init) do
      local col, limit
      if type(_1)=='number' then
        col = _2
      else
        col = _1
        limit = _2
      end
      this.db.data.obj[col] = {}
      if limit==DataBase.PRIMARY_KEY then
        if this.db.data.primary==nil then
          this.db.data.primary = col
          this.db.data.xedni = {}
        end
        this.db.meta[col] = DataBase.DEFAULT
      else
        this.db.meta[col] = limit or DataBase.DEFAULT
      end
    end
  end
  return this
end
DataBase.clear = function(this)
  local init = this.db.init
  this:init(init)
  return this
end
DataBase._rowspace = function(this, put)
  local row
  if this.db.data.primary then
    row = this.db.data.xedni[put[this.db.data.primary]]
  end
  row = row or #this.db.data.index+1
  return row
end
DataBase._insertable = function(this, put, row)
  local check = true
  for _col,_dbcol in pairs(this.db.data.obj) do
    if not this.db.meta[_col](_dbcol, row, put[_col]) then
      check = false
    end
    if not check then
      break
    end
  end
  return check
end
DataBase.insert = function(this, puts)
  if this.db then
    if puts then
      for _,put in ipairs(puts) do
        if not this.db.data.primary or put[this.db.data.primary]~=nil then
          local row = this:_rowspace(put)
          if this:_insertable(put, row) then
            for _col,_value in pairs(put) do
              this.db.data.obj[_col][row] = _value
            end
            if this.db.data.primary then
              this.db.data.index[row] = put[this.db.data.primary]
              this.db.data.xedni[put[this.db.data.primary]] = row
            else
              this.db.data.index[row] = row
            end
          end
        end
      end
    end
  end
  return this
end
DataBase._checkrow = function(this, search, row)
  local checks = false
  for _,get in ipairs(search) do
    local check = true
    for _col,_value in pairs(get) do
      if this.db.data.obj[_col] and this.db.data.obj[_col][row]~=_value then
        check = false
        break
      end
    end
    if check then
      checks = true
      break
    end
  end
  return checks
end
DataBase._search = function(this, search)
  if not (search and #search>0) then
    search = {{}}
  end
  local pendrows
  if this.db.data.primary then
    pendrows = {}
    for _,_get in ipairs(search) do
      if _get[this.db.data.primary]~=nil then
        table.insert(pendrows, this.db.data.xedni[_get[this.db.data.primary]])
      else
        pendrows = nil
        break
      end
    end
  end
  local rows = {}
  if pendrows then
    for _,_row in ipairs(pendrows) do
      if this:_checkrow(search, _row) then
        table.insert(rows, _row)
      end
    end
  else
    for _row,_ in pairs(this.db.data.index) do
      if this:_checkrow(search, _row) then
        table.insert(rows, _row)
      end
    end
  end
  return rows
end
DataBase.update = function(this, changes)
  if this.db then
    for _target,_change in pairs(changes) do
      local rows = this:_search(_target)
      for _,_row in ipairs(rows) do
        if this:_insertable(_change, _row) then
          for _col,_value in pairs(_change) do
            this.db.data.obj[_col][_row] = _value
          end
          if this.db.data.primary and _change[this.db.data.primary]~=nil then
            this.db.data.xedni[this.db.data.index[_row]] = nil
            this.db.data.index[_row] = _change[this.db.data.primary]
            this.db.data.xedni[_change[this.db.data.primary]] = _row
          end
        end
      end
    end
  end
  return this
end
DataBase.get = function(this, gets)
  if this.db then
    local rows = this:_search(gets)
    local row2 = {}
    for _,_row in ipairs(rows) do
      local row3 = {}
      for _col,_dbcol in pairs(this.db.data.obj) do
        row3[_col] = _dbcol[_row]
      end
      table.insert(row2, row3)
    end
    return row2
  end
end
DataBase.rm = function(this, rms)
  if this.db then
    local rows = this:_search(rms)
    for _,_row in ipairs(rows) do
      for _col,_ in pairs(this.db.data.obj) do
        this.db.data.obj[_col][_row] = nil
      end
      if this.db.data.primary then
        this.db.data.xedni[this.db.data.index[_row]] = nil
      end
      this.db.data.index[_row] = nil
    end
  end
  return this
end
DataBase.copy = function(this, from, deep)
  Util.extend(not not deep, this.db, from.db)
end
DataBase.link = function(this, from)
  this.db = from.db
end
DataBase.PRIMARY_KEY = {}
DataBase.DEFAULT = function(dbcol, row, value)
  return true
end
DataBase.UNIQUE_KEY = function(dbcol, row, value)
  for _row,_dbrow in pairs(dbcol) do
    if value==_dbrow then
      if row~=_row then
        return false
      end
    end
  end
  return true
end
DataBase.NOT_NULL = function(dbcol, row, value)
  return value~=nil
end

IODataBase = {}
setmetatable(IODataBase, {__index = DataBase})
IODataBase.new = function()
  local obj = DataBase.new()
  return setmetatable(obj, {__index = IODataBase})
end
IODataBase.fromCode = function(this, code)
  if code:exists() then
    Util.extend(this.db.data, Lib.JSON:decode(code:get()))
  end
  return this
end
IODataBase.save = function(this, code)
  if this.db then
    if code:getBind() then
      code:reset():fromString(Lib.JSON:encode(this.db.data)):save()
    end
  end
  return this
end
