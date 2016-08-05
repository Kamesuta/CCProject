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
DataBase.put = function(this, puts)
  if this.db then
    if puts then
      for _,put in ipairs(puts) do
        local check = true
        if not this.db.data.primary or put[this.db.data.primary]~=nil then
          local row
          if this.db.data.primary then
            row = this.db.data.xedni[put[this.db.data.primary]]
          end
          row = row or #this.db.data.index+1

          for _col,_dbcol in pairs(this.db.data.obj) do
            if not this.db.meta[_col](_dbcol, row, put[_col]) then
              check = false
            end
            if not check then
              break
            end
          end

          if check then
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
DataBase._search = function(this, search)
  if not (search and #search>0) then
    search = {{}}
  end
  local pendrows
  local onlyprimary = false
  if this.db.data.primary then
    pendrows = {}
    onlyprimary = true
    for _,_get in ipairs(search) do
      if _get[this.db.data.primary]~=nil then
        table.insert(pendrows, this.db.data.xedni[_get[this.db.data.primary]])
      else
        onlyprimary = false
        break
      end
    end
  end
  if not onlyprimary then
    pendrows = {}
    for _row,_ in pairs(this.db.data.index) do
      table.insert(pendrows, _row)
    end
  end

  local rows = {}
  for _,_row in ipairs(pendrows) do
    local checks = false
    for _,get in ipairs(search) do
      local check = true
      for _col,_value in pairs(get) do
        if this.db.data.obj[_col] and this.db.data.obj[_col][_row]~=_value then
          check = false
          break
        end
      end
      if check then
        checks = true
        break
      end
    end
    if checks then
      table.insert(rows, _row)
    end
  end
  return rows
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

db = DataBase.new()
db:init{a=DataBase.PRIMARY_KEY, "b","c"}
db:put{{a="x",b="y",c="z"},{a="xx",b="yy",c="zz"}}
db:put{{a="x",b="y",c="z"},{a="xx",b="yy",c="zz"}}
db:rm{{a="x"},{b="yy"}}
a=db:get()
print(a)