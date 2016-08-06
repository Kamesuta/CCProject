textutils = {}
function textutils.slowWrite( sText, nRate )
    nRate = nRate or 20
    if nRate < 0 then
        error( "Rate must be positive", 2 )
    end
    local nSleep = 1 / nRate

    sText = tostring( sText )
    local x,y = term.getCursorPos(x,y)
    local len = string.len( sText )

    for n=1,len do
        term.setCursorPos( x, y )
        sleep( nSleep )
        local nLines = write( string.sub( sText, 1, n ) )
        local newX, newY = term.getCursorPos()
        y = newY - nLines
    end
end

function textutils.slowPrint( sText, nRate )
    textutils.slowWrite( sText, nRate)
    print()
end

function textutils.formatTime( nTime, bTwentyFourHour )
    local sTOD = nil
    if not bTwentyFourHour then
        if nTime >= 12 then
            sTOD = "PM"
        else
            sTOD = "AM"
        end
        if nTime >= 13 then
            nTime = nTime - 12
        end
    end

    local nHour = math.floor(nTime)
    local nMinute = math.floor((nTime - nHour)*60)
    if sTOD then
        return string.format( "%d:%02d %s", nHour, nMinute, sTOD )
    else
        return string.format( "%d:%02d", nHour, nMinute )
    end
end

local function makePagedScroll( _term, _nFreeLines )
    local nativeScroll = _term.scroll
    local nFreeLines = _nFreeLines or 0
    return function( _n )
        for n=1,_n do
            nativeScroll( 1 )

            if nFreeLines <= 0 then
                local w,h = _term.getSize()
                _term.setCursorPos( 1, h )
                _term.write( "Press any key to continue" )
                os.pullEvent( "key" )
                _term.clearLine()
                _term.setCursorPos( 1, h )
            else
                nFreeLines = nFreeLines - 1
            end
        end
    end
end

function textutils.pagedPrint( _sText, _nFreeLines )
    -- Setup a redirector
    local oldTerm = term.current()
    local newTerm = {}
    for k,v in pairs( oldTerm ) do
        newTerm[k] = v
    end
    newTerm.scroll = makePagedScroll( oldTerm, _nFreeLines )
    term.redirect( newTerm )

    -- Print the text
    local result
    local ok, err = pcall( function()
        result = print( _sText )
    end )

    -- Removed the redirector
    term.redirect( oldTerm )

    -- Propogate errors
    if not ok then
        error( err, 0 )
    end
    return result
end

local function tabulateCommon( bPaged, ... )
    local tAll = { ... }

    local w,h = term.getSize()
    local nMaxLen = w / 8
    for n, t in ipairs( tAll ) do
        if type(t) == "table" then
            for n, sItem in pairs(t) do
                nMaxLen = math.max( string.len( sItem ) + 1, nMaxLen )
            end
        end
    end
    local nCols = math.floor( w / nMaxLen )
    local nLines = 0
    local function newLine()
        if bPaged and nLines >= (h-3) then
            textutils.pagedPrint()
        else
            print()
        end
        nLines = nLines + 1
    end

    local function drawCols( _t )
        local nCol = 1
        for n, s in ipairs( _t ) do
            if nCol > nCols then
                nCol = 1
                newLine()
            end

            local cx, cy = term.getCursorPos()
            cx = 1 + ((nCol - 1) * nMaxLen)
            term.setCursorPos( cx, cy )
            term.write( s )

            nCol = nCol + 1
        end
        print()
    end
    for n, t in ipairs( tAll ) do
        if type(t) == "table" then
            if #t > 0 then
                drawCols( t )
            end
        elseif type(t) == "number" then
            term.setTextColor( t )
        end
    end
end

function textutils.tabulate( ... )
    tabulateCommon( false, ... )
end

function textutils.pagedTabulate( ... )
    tabulateCommon( true, ... )
end

local function serializeImpl( t, tTracking, sIndent )
    local sType = type(t)
    if sType == "table" then
        if tTracking[t] ~= nil then
            error( "Cannot serialize table with recursive entries", 0 )
        end
        tTracking[t] = true

        if next(t) == nil then
            -- Empty tables are simple
            return "{}"
        else
            -- Other tables take more work
            local sResult = "{\n"
            local sSubIndent = sIndent .. "  "
            local tSeen = {}
            for k,v in ipairs(t) do
                tSeen[k] = true
                sResult = sResult .. sSubIndent .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
            end
            for k,v in pairs(t) do
                if not tSeen[k] then
                    local sEntry
                    if type(k) == "string" and string.match( k, "^[%a_][%a%d_]*$" ) then
                        sEntry = k .. " = " .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
                    else
                        sEntry = "[ " .. serializeImpl( k, tTracking, sSubIndent ) .. " ] = " .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
                    end
                    sResult = sResult .. sSubIndent .. sEntry
                end
            end
            sResult = sResult .. sIndent .. "}"
            return sResult
        end

    elseif sType == "string" then
        return string.format( "%q", t )

    elseif sType == "number" or sType == "boolean" or sType == "nil" then
        return tostring(t)

    else
        error( "Cannot serialize type "..sType, 0 )

    end
end

function textutils.serialize( t )
    local tTracking = {}
    return serializeImpl( t, tTracking, "" )
end

function textutils.unserialize( s )
    local func = loadstring( "return "..s, "unserialize" )
    if func then
        setfenv( func, {} )
        local ok, result = pcall( func )
        if ok then
            return result
        end
    end
    return nil
end

function textutils.urlEncode( str )
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w ])", function(c)
            return string.format("%%%02X", string.byte(c))
        end )
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- GB versions
textutils.serialise = textutils.serialize
textutils.unserialise = textutils.unserialize
