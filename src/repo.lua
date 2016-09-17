if type(getfenv(0).N)~='table' then
  local N = {}

  N.Reference = {
    localRepo = 'bnn/',
    localSystem = '.bnn/',
    remoteDB = '.bnn/remote.json',
    localDB = '.bnn/local.json',
    dev_key = '8eb670559bf070612041dc14d0502248',
    user_key = 'c244f544f85e867092d55a7b9d468d8f',
  }

  N.Util = {
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
    end
  }

  N.extend = function(...)
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
              target[ name ] = N.extend( deep, clone, copy )
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
  end

  N.Code = {}
  N.Code.new = function(code)
    local obj = {
      code = code,
    }
    return setmetatable(obj, {__index = N.Code})
  end
  N.Code.fromString = function(this, code)
    if not this.code then
      this.code = code
    end
    return this
  end
  N.Code.fromGet = function(this, url, ...)
    if not this.code then
      local data = N.Util.join({...}, '&')
      local response = http.get(url..data)
      if response then
        this.code = response.readAll()
        response.close()
      end
    end
    return this
  end
  N.Code.fromPost = function(this, url, data)
    if not this.code then
      local data1 = {}
      for _1,_2 in pairs(data) do
        local col, limit
        if type(_1)=='number' then
          table.insert(data1, _2)
        else
          table.insert(data1, _1..'='.._2)
        end
      end
      local data = N.Util.join(data1, '&')
      local response = http.post(url, data)
      if response then
        this.code = response.readAll()
        response.close()
      end
    end
    return this
  end
  N.Code.fromFile = function(this, path)
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
  N.Code.bind = function(this, path)
    this.file = path
    return this
  end
  N.Code.delete = function(this)
    if this.file then
      fs.delete(this.file)
    end
    return this
  end
  N.Code.getBind = function(this)
    return this.file
  end
  N.Code.reset = function(this)
    this.code = nil
    this.from = nil
    return this
  end
  N.Code.exists = function(this)
    return this.code~=nil
  end
  N.Code.save = function(this, path)
    if this.code then
      local p = path or this.file
      if p~=this.from then
        if p then
          local dir,name = p:match('^(.*/)(.-)$')
          if not fs.exists(dir) then
            fs.makeDir(dir)
          end
          if fs.isDir(dir) and #name>0 then
            local file = fs.open(p, 'w')
            file.write(this.code)
            file.close()
          else
            error('non-directory file exsists', 2)
          end
        end
      end
    end
    return this
  end
  N.Code.loadcode = function(this, name)
    if this.code then
      return loadstring(this.code, name or this.file or 'code')
    end
  end
  N.Code.execute = function(this, ...)
    if this.code then
      return this:loadcode()(...)
    end
  end
  N.Code.invoke = function(this, ...)
    if this.code then
      local func = this:loadcode()
      setfenv(func, getfenv())
      return func(...)
    end
  end
  N.Code.api = function(this, ...)
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
  N.Code.get = function(this)
    return this.code
  end

  N.Lib = {
    XML = N.Code.new():fromFile(N.Reference.localSystem..'xml.lua'):fromGet('http://pastebin.com/raw/cFDg20XW'):save():execute(),
    JSON = N.Code.new():fromFile(N.Reference.localSystem..'json.lua'):fromGet('http://pastebin.com/raw/4YncwwC6'):save():execute(),
  }

  N.Pastebin = {}
  N.Pastebin.new = function()
    local obj = {}
    obj.dbinit = {
      id = N.DataBase.PRIMARY_KEY,
      'title',
      name = N.DataBase.UNIQUE_KEY,
      'version',
    }
    obj.localrepocode = N.Code.new():fromFile(N.Reference.localDB)
    obj.localrepo = N.IODataBase.new():init(obj.dbinit):fromCode(obj.localrepocode)
    obj.remoterepocode = N.Code.new():fromFile(N.Reference.remoteDB)
    obj.remoterepo = N.IODataBase.new():init(obj.dbinit):fromCode(obj.remoterepocode)
    return setmetatable(obj, {__index = N.Pastebin})
  end
  N.Pastebin.fetch = function(this)
    this.remoterepo:clear()
    local remoteRepoCode = N.Code.new():fromPost(
      'http://pastebin.com/api/api_post.php',
      {
        api_option = 'list',
        api_dev_key = N.Reference.dev_key,
        api_user_key = N.Reference.user_key,
        api_results_limit = 1000,
      }
    )
    if remoteRepoCode:exists() then
      local remoteRepoData = N.Lib.XML.Parser.new():ParseXmlText(remoteRepoCode:get())
      for _,v in ipairs(remoteRepoData.paste) do
        local id = v.paste_key:value()
        local title = v.paste_title:value()
        local name = title:match('^.-#(.-)#.-$')
        local version = title:match('^.-@(.-)@.-$')
        this.remoterepo:insert{{
          id = id,
          title = title,
          name = name,
          version = version,
        }}
      end
      this.remoterepo:save(this.remoterepocode)
    end
    return this
  end
  N.Pastebin.exists = function(this, filter)
    return this.localrepo:exists(filter)
  end
  N.Pastebin.info = function(this, filter)
    return this.localrepo:get(filter)
  end
  N.Pastebin.code = function(this, filter)
    this:add(filter)
    this:merge(filter)
    local codes = {}
    local entries = this.localrepo:get(filter)
    for _,entry in ipairs(entries) do
      codes[entry.name] = N.Code.new():fromFile(N.Reference.localRepo..entry.name)
    end
    return codes
  end
  N.Pastebin.add = function(this, filter)
    if not this.localrepo:exists(filter) then
      this.localrepo:insert(this.remoterepo:get(filter))
      this.localrepo:save(this.localrepocode)
    end
    return this
  end
  N.Pastebin.rm = function(this, filter)
    local rms = this.remoterepo:get(filter)
    for rm,entry in pairs(rms) do
      N.Code.new():bind(N.Reference.localRepo..entry.name):delete()
    end
    this.localrepo:rm(rms)
    this.localrepo:save(this.localrepocode)
    return this
  end
  N.Pastebin.merge = function(this, filter)
    local remoteentries = this.remoterepo:get()
    local localentries = this.localrepo:get(filter)
    for i,localentry in pairs(localentries) do
      local remoteentry = remoteentries[i]
      if remoteentry.version~=localentry.version then
        N.Code.new():fromGet('http://pastebin.com/raw/'..localentry.id):save(N.Reference.localRepo..localentry.name)
        this.localrepo:insert{remoteentry}
        this.localrepo:save(this.localrepocode)
      else
        N.Code.new():fromFile(N.Reference.localRepo..localentry.name):fromGet('http://pastebin.com/raw/'..localentry.id):save()
      end
    end
    return this
  end
  N.Pastebin.pull = function(this, filter)
    this:fetch()
    this:get(filter)
    return this
  end
  N.Pastebin.get = function(this, filter)
    this:add(filter)
    this:merge(filter)
    return this
  end

  N.DataBase = {}
  N.DataBase.new = function()
    local obj = {}
    return setmetatable(obj, {__index = N.DataBase})
  end
  N.DataBase.fromData = function(this, db)
    if not this.db then
      this.db = db
    end
    return this
  end
  N.DataBase.init = function(this, init)
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
        if limit==N.DataBase.PRIMARY_KEY then
          if this.db.data.primary==nil then
            this.db.data.primary = col
            this.db.data.xedni = {}
          end
          this.db.meta[col] = N.DataBase.DEFAULT
        else
          this.db.meta[col] = limit or N.DataBase.DEFAULT
        end
      end
    end
    return this
  end
  N.DataBase.clear = function(this)
    local init = this.db.init
    this:init(init)
    return this
  end
  N.DataBase._rowspace = function(this, put)
    local row
    if this.db.data.primary then
      row = this.db.data.xedni[put[this.db.data.primary]]
    end
    row = row or #this.db.data.index+1
    return row
  end
  N.DataBase._insertable = function(this, put, row)
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
  N.DataBase.insert = function(this, puts)
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
  N.DataBase._checkrow = function(this, search, row)
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
  N.DataBase._search = function(this, search)
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
  N.DataBase.update = function(this, changes)
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
  N.DataBase.get = function(this, gets)
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
  N.DataBase.exists = function(this, filter)
    if this.db then
      return #this:get(filter)>0
    end
    return false
  end
  N.DataBase.rm = function(this, rms)
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
  N.DataBase.copy = function(this, from, deep)
    N.extend(deep==true, this.db, from.db)
  end
  N.DataBase.link = function(this, from)
    this.db = from.db
  end
  N.DataBase.PRIMARY_KEY = {}
  N.DataBase.DEFAULT = function(dbcol, row, value)
    return true
  end
  N.DataBase.UNIQUE_KEY = function(dbcol, row, value)
    for _row,_dbrow in pairs(dbcol) do
      if value==_dbrow then
        if row~=_row then
          return false
        end
      end
    end
    return true
  end
  N.DataBase.NOT_NULL = function(dbcol, row, value)
    return value~=nil
  end

  N.IODataBase = {}
  setmetatable(N.IODataBase, {__index = N.DataBase})
  N.IODataBase.new = function()
    local obj = N.DataBase.new()
    return setmetatable(obj, {__index = N.IODataBase})
  end
  N.IODataBase.fromCode = function(this, code)
    if code:exists() then
      N.extend(this.db.data, N.Lib.JSON:decode(code:get()))
    end
    return this
  end
  N.IODataBase.save = function(this, code)
    if this.db then
      if code:getBind() then
        code:reset():fromString(N.Lib.JSON:encode(this.db.data)):save()
      end
    end
    return this
  end

  N.repo = N.Pastebin.new():fetch()
  N.apps = {}
  N.import = function(filter)
    if type(filter)=='string' then
      filter = {{name = filter}}
    end
    local codes = N.repo:code(filter)
    for name,code in pairs(codes) do
      N.apps[name] = code:api()
    end
    return N
  end

  setmetatable(N, {__index = N.apps})
  getfenv(0).N = N
end

local args = {...}
if #args>0 then
  if args[1] == '-fetch' then
    N.repo:fetch()
  elseif args[1] == '-merge' then
    N.repo:merge()
  elseif args[1] == '-add' then
    if args[2] then
      N.repo:add{{name = args[2]}}
    end
  elseif args[1] == '-get' then
    if args[2] then
      N.repo:get{{name = args[2]}}
    end
  elseif args[1] == '-pull' then
    if args[2] then
      N.repo:pull{{name = args[2]}}
    end
  elseif args[1] == '-run' then
    if args[2] then
      local codes = N.repo:code{{name = args[2]}}
      local runargs = N.Util.merge({}, args)
      table.remove(runargs,1)
      table.remove(runargs,1)
      for name,code in pairs(codes) do
        code:invoke(runargs)
      end
    end
  end
end