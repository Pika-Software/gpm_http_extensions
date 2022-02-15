local packageName = PKG and PKG["name"]
local type = type

--[[-------------------------------------------------------------------------
    string.isURL
---------------------------------------------------------------------------]]

function string.isURL( str )
	return str:match( "^https?://.*" )
end

--[[-------------------------------------------------------------------------
    I recommend install CHTTP DLL module, Garry's Mod HTTP broken by Rubat
    https://github.com/timschumi/gmod-chttp/releases
---------------------------------------------------------------------------]]

local log = console.log

if SERVER then
    if pcall( require, "chttp" ) and (CHTTP ~= nil) then
        HTTP = CHTTP
    else
        log( "I couldn't download CHHTP, you probably didn't download it,\n I highly recommend install CHTTP - dll module, because Garry's Mod HTTP broken by Rubat...\nhttps://github.com/timschumi/gmod-chttp/releases" ):setTag( packageName )
    end
end

--[[-------------------------------------------------------------------------
    string.getFileFromURL
---------------------------------------------------------------------------]]

local util_CRC = util.CRC

do

    local empty = ""
    local allowedExtensions = {
        ["txt"] = true,
        ["jpg"] = true,
        ["png"] = true,
        ["vtf"] = true,
        ["dat"] = true,
        ["json"] = true,
        ["vmt"] = true
    }

    function string.getFileFromURL( self, hash, onlyAllowedExtensions )
        local ext = self:GetExtensionFromFilename()
        local file = self:GetFileFromFilename()
        local fileName = file:sub( 1, #file - (#ext + 1) )

        if (onlyAllowedExtensions == true) and (allowedExtensions[ext] == nil) then
            fileName = fileName .. "." .. ext
            ext = "dat"
        end

        if (hash == true) then
            return util_CRC( fileName ) .. "." .. ext
        end

        return fileName .. "." .. ext
    end

end

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
    return self
end

function request:setTimeout( int )
    assert( type( int ) == "number", "bad argument #1 (number expected)")
    self["__timeout"] = int
    return self
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
    return self
end

function request:removeParameter( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__parameters"][key] = nil
    return self
end

--[[-------------------------------------------------------------------------
    Headers
---------------------------------------------------------------------------]]

function request:addHeader( key, value )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__headers"][key] = value
    return self
end

function request:removeHeader( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self["__headers"][key] = nil
    return self
end

function request:setBody( body )
    if type( body ) == "string" then
        self["__body"] = body
    else
        self["__body"] = nil
    end

    return self
end

function request:setContentType( str )
    if type( str ) == "string" then
        self["__contentType"] = body
    else
        self["__contentType"] = nil
    end

    return self
end

function request:getContentType()
    return self["__contentType"] or "text/plain; charset=utf-8"
end

function request:onlySuccess( bool )
    self["__onlySuccess"] = (bool == true) and true or false
    return self
end

HTTP_GET = 0
HTTP_POST = 1
HTTP_HEAD = 2
HTTP_PUT = 3
HTTP_DELETE = 4
HTTP_PATCH = 5
HTTP_OPTIONS = 6

local game_ready_run = game_ready.run

do
    local methods = {
        [HTTP_GET] = "GET",
        [HTTP_POST] = "POST",
        [HTTP_HEAD] = "HEAD",
        [HTTP_PUT] = "PUT",
        [HTTP_DELETE] = "DELETE",
        [HTTP_PATCH] = "PATCH",
        [HTTP_OPTIONS] = "OPTIONS"
    }

    local blue_color = Color( "#80A6FF" )

    function request:run()
        game_ready_run(function()
            local method = methods[ self["__method"] ]
            if (HTTP({
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
            }) == true) then
                console.devLog( blue_color, method, console.getColor(), ' request to "', blue_color, self["__url"], '"' ):setTag( packageName )
            else
                console.devLog( blue_color, method, console.getColor(), ' request failed! ("', blue_color, self["__url"], '")' ):setTag( packageName )
            end
        end)
    end
end

local timer_Simple = timer.Simple

do
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
    game_ready_run(function()
        HTTP({
            ["url"] = url,
            ["method"] = "GET",
            ["failed"] = onFailure,
            ["success"] = function( code, body, headers )
                if type( onSuccess ) == "function" then
                    onSuccess( body, body:len(), headers, code )
                end
            end,
            ["timeout"] = timeout or defaultTimeout,
            ["headers"] = headers or emptyTable
        })
    end)
end

function http.Post( url, parameters, onSuccess, onFailure, headers, timeout )
    game_ready_run(function()
        HTTP({
            ["url"] = url,
            ["body"] = body,
            ["method"] = "POST",
            ["failed"] = onFailure,
            ["success"] = function( code, body, headers )
                if type( onSuccess ) == "function" then
                    onSuccess( body, body:len(), headers, code )
                end
            end,
            ["timeout"] = timeout or defaultTimeout,
            ["parameters"] = parameters,
            ["headers"] = headers or emptyTable
        })
    end)
end

--[[-------------------------------------------------------------------------
    http.Download( url, path )
---------------------------------------------------------------------------]]

do
    local file_IsDir = file.IsDir
    local file_CreateDir = file.CreateDir

    if not file_IsDir( "gpm_http", "DATA" ) then
        file_CreateDir( "gpm_http", "DATA" )
    end

    if not file_IsDir( "gpm_http/downloads", "DATA" ) then
        file_CreateDir( "gpm_http/downloads", "DATA" )
    end
end

do

    local file_Write = file.Write

    function http.Download( url, callback, path, onFail )
        game_ready_run(function()
            local filename = url:getFileFromURL( false, true )
            local fullPath = ( type( path ) == "string" and (path .. "/") or "gpm_http/downloads/" ) .. filename
            log( "Started download: '", filename, "'" ):setTag( packageName )

            http.Fetch( url, function( data, size, headers, code )
                if http.isSuccess( code ) then
                    file_Write( fullPath, data )

                    log( "Download completed successfully, file was saved as: 'data/", fullPath, "'" ):setTag( packageName )
                    if type( callback ) == "function" then
                        timer_Simple(0, function()
                            callback( fullPath )
                        end)
                    end
                else
                    log( "An error code '", code, "' was received while downloading: '", filename, "'" ):setTag( packageName )
                end
            end,
            function( err )
                log( "Error '", err, "' was received while downloading '", filename, "'" ):setTag( packageName )
                if type( onFail ) == "function" then
                    onFail( err )
                end
            end, nil, 120 )
        end)
    end
end