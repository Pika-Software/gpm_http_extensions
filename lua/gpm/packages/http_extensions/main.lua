local packageName = PKG_NAME

--[[-------------------------------------------------------------------------
    I recommend install CHTTP DLL module, Garry's Mod HTTP broken by Rubat
    https://github.com/timschumi/gmod-chttp/releases
---------------------------------------------------------------------------]]

if pcall( require, "chttp" ) and (CHTTP ~= nil) then
	HTTP = CHTTP
else
    console.log( "I couldn't download CHHTP, you probably didn't download it,\n I highly recommend install CHTTP - dll module, because Garry's Mod HTTP broken by Rubat...\nhttps://github.com/timschumi/gmod-chttp/releases" ):setTag( packageName )
end

GET = 0
POST = 1
HEAD = 2
PUT = 3
DELETE = 4
PATCH = 5
OPTIONS = 6

local type = type
local HTTP = HTTP
local emptyTable = {}
local defaultTimeout = 60

function http.isSuccess( code )
    return ((code > 199) and (code < 300)) or (code == 0)
end

local request = {}
request["__index"] = request
debug.getregistry().HTTPRequest = request

do
    local string_format = string.format
    function request:__tostring()
        return string_format( "HTTP %s Request [%s] ~ %s", self["__method"], self["__url"], self["__status"] )
    end
end

function request:changeMethod( method )
    assert( type( method ) == "number", "bad argument #1 (number expected)")
    self["__method"] = method
end

function request:setTimeout( int )
    assert( type( int ) == "number", "bad argument #1 (number expected)")
    self["__timeout"] = int
end

function request:getTimeout()
    return self["__timeout"] or defaultTimeout
end

--[[-------------------------------------------------------------------------
    Callbacks
---------------------------------------------------------------------------]]

do
    local table_insert = table.insert
    function request:addCallback( func )
        assert( type( func ) == "function", "bad argument #1 (function expected)")
        return table_insert( self["__callbacks"], func )
    end
end

do
    local table_remove = table.remove
    function request:removeCallback( int )
        assert( type( int ) == "number", "bad argument #1 (number expected)")
        table_remove( self["__callbacks"], int )
    end
end

--[[-------------------------------------------------------------------------
    Parameters
---------------------------------------------------------------------------]]

function request:addParameter( key, value )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__parameters"][key] = value
end

function request:removeParameter( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__parameters"][key] = nil
end

--[[-------------------------------------------------------------------------
    Headers
---------------------------------------------------------------------------]]

function request:addHeader( key, value )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__headers"][key] = value
end

function request:removeHeader( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__headers"][key] = nil
end

function request:setBody( body )
    if type( body ) == "string" then
        self["__body"] = body
    else
        self["__body"] = nil
    end
end

function request:setContentType( str )
    if type( str ) == "string" then
        self["__contentType"] = body
    else
        self["__contentType"] = nil
    end
end

function request:getContentType()
    return self["__contentType"] or "text/plain; charset=utf-8"
end

function request:onlySuccess( bool )
    self["__onlySuccess"] = (bool == true) and true or false
end

do
    local methods = {
        [0] = "GET",
        [1] = "POST",
        [2] = "HEAD",
        [3] = "PUT",
        [4] = "DELETE",
        [5] = "PATCH",
        [6] = "OPTIONS"
    }

    local blue_color = Color( "#80A6FF" )

    function request:run()
        if game_ready.isReady() then
            local method = methods[ self["__method"] ]
            console.devLog( blue_color, method, console.getColor(), ' request to "', blue_color, self["__url"], '"' ):setTag( packageName )
            return pcall( HTTP, {
                ["url"] = self["__url"],
                ["method"] = method or "GET",
                ["parameters"] = self["__parameters"],
                ["headers"] = self["__headers"],
                ["body"] = self["__body"],
                ["type"] = self:getContentType(),
                ["timeout"] = self:getTimeout(),
                ["success"] = function( code, body, headers, ... )
                    if self["__onlySuccess"] and not http.isSuccess( code ) then
                        return
                    end

                    for num, func in ipairs( self["__callbacks"] ) do
                        func( code, body, headers, ... )
                    end
                end,
                ["failed"] = function( ... )
                    if self["__onlySuccess"] then
                        return
                    end

                    for num, func in ipairs( self["__callbacks"] ) do
                        func( 504, ... )
                    end
                end
            })
        else
            game_ready.wait( self["run"], self )
        end
    end
end

do
    local timer_Simple = timer.Simple
    function http.request( url, callback, method )
        assert( type( url ) == "string", "bad argument #1 (string expected)")

        local new = setmetatable({
            ["__url"] = url,
            ["__headers"] = {},
            ["__callbacks"] = {},
            ["__parameters"] = {},
            ["__method"] = method or 0
        }, request)

        new:addCallback( callback )

        timer_Simple(0, function()
            new:run()
        end)

        return new
    end
end

function http.Fetch( url, onSuccess, onFailure, headers, timeout )
    if game_ready.isReady() then
        return HTTP({
            ["url"] = url,
            ["method"] = "GET",
            ["failed"] = onFailure,
            ["success"] = onSuccess,
            ["timeout"] = timeout or defaultTimeout,
            ["headers"] = headers or emptyTable
        })
    else
        game_ready.wait( http.Fetch, url, onSuccess, onFailure, headers, timeout )
    end
end

function http.Post( url, parameters, onSuccess, onFailure, headers, timeout )
    if game_ready.isReady() then
        return HTTP({
            ["url"] = url,
            ["body"] = body,
            ["method"] = "POST",
            ["failed"] = onFailure,
            ["success"] = onSuccess,
            ["timeout"] = timeout or defaultTimeout,
            ["parameters"] = parameters,
            ["headers"] = headers or emptyTable
        })
    else
        game_ready.wait( http.Post, url, parameters, onSuccess, onFailure, headers, timeout )
    end
end