local packageName = "HTTP Extensions"
local type = type

local logger = GPM.Logger( packageName )

local defaultTimeout = CreateConVar("http_timeout", "60", {FCVAR_ARCHIVE}, " - HTTP request default timeout.", 0, 900 ):GetInt()
cvars.AddChangeCallback("http_timeout", function( name, old, new )
    defaultTimeout = tonumber( new )
    logger:info( "Default timeout now is {1}", defaultTimeout )
end, packageName)

--[[-------------------------------------------------------------------------
    I recommend install CHTTP DLL module, Garry's Mod HTTP broken by Rubat
    https://github.com/timschumi/gmod-chttp/releases
---------------------------------------------------------------------------]]

if (SERVER) then
    if pcall( require, "chttp" ) and (CHTTP ~= nil) then
        HTTP = CHTTP
    else
        logger:warn( "I couldn't load CHHTP, you probably didn't download it,\nI highly recommend install CHTTP - dll module, because Garry's Mod HTTP broken by Rubat...\nhttps://github.com/timschumi/gmod-chttp/releases" )
    end
end

--[[-------------------------------------------------------------------------
    string.isURL( `string` str )
---------------------------------------------------------------------------]]

function string.isURL( str )
	return str:match( "^https?://.*" ) ~= nil
end

--[[-------------------------------------------------------------------------
    Alias for string.isURL
---------------------------------------------------------------------------]]

string.IsURL = string.isURL

--[[-------------------------------------------------------------------------
    string.getFileFromURL
---------------------------------------------------------------------------]]

local util_CRC = util.CRC

do

    local empty = ""
    local allowedExtensions = {
        ["json"] = true,
        ["txt"] = true,
        ["jpg"] = true,
        ["png"] = true,
        ["vtf"] = true,
        ["dat"] = true,
        ["vmt"] = true
    }

    local system_IsLinux = system.IsLinux
    function string.getFileFromURL( self, onlyAllowedExtensions, withoutExtension, hashed )
        local url = system_IsLinux() and self:lower() or self
        local ext = url:GetExtensionFromFilename()
        local file = url:GetFileFromFilename()
        local fileName = file:sub( 1, #file - (#ext + 1) )

        if (onlyAllowedExtensions == true) and (allowedExtensions[ext] == nil) then
            fileName = fileName .. "." .. ext
            ext = "dat"
        end

        if (hashed == true) then
            return util_CRC( fileName ) .. ((withoutExtension == true) and "" or "." .. ext)
        end

        return fileName .. ((withoutExtension == true) and "" or "." .. ext)
    end

end

local HTTP = HTTP
local emptyTable = {}

function http.isSuccess( code )
    return ((code > 199) and (code < 300)) or (code == 0)
end

local request = {}
request.__index = request
debug.getregistry().HTTPRequest = request

do
    local string_format = string.format
    function request:__tostring()
        return string_format( "HTTP %s Request [%s] ~ %s", self.Method, self.URL, self["__status"] )
    end
end

function request:changeMethod( method )
    assert( type( method ) == "number", "bad argument #1 (number expected)")
    self.Method = method
    return self
end

function request:setTimeout( int )
    assert( type( int ) == "number", "bad argument #1 (number expected)")
    self.Timeout = int
    return self
end

function request:getTimeout()
    return self.Timeout or defaultTimeout
end

--[[-------------------------------------------------------------------------
    Callbacks
---------------------------------------------------------------------------]]

do
    local table_insert = table.insert
    function request:addCallback( func )
        assert( type( func ) == "function", "bad argument #1 (function expected)")
        return table_insert( self.Callbacks, func )
    end
end

do
    local table_remove = table.remove
    function request:removeCallback( int )
        assert( type( int ) == "number", "bad argument #1 (number expected)")
        table_remove( self.Callbacks, int )
    end
end

--[[-------------------------------------------------------------------------
    Parameters
---------------------------------------------------------------------------]]

function request:addParameter( key, value )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self.Parameters[ key ] = value
    return self
end

function request:removeParameter( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self.Parameters[ key ] = nil
    return self
end

--[[-------------------------------------------------------------------------
    Headers
---------------------------------------------------------------------------]]

function request:addHeader( key, value )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self.Headers[ key ] = value
    return self
end

function request:removeHeader( key )
    assert( type( key ) == "string", "bad argument #1 (string expected)")
    self.Headers[ key ] = nil
    return self
end

function request:setBody( body )
    if type( body ) == "string" then
        self.Body = body
    else
        self.Body = nil
    end

    return self
end

function request:setContentType( str )
    if type( str ) == "string" then
        self.ContentType = body
    else
        self.ContentType = nil
    end

    return self
end

function request:getContentType()
    return self.ContentType or "text/plain; charset=utf-8"
end

function request:onlySuccess( bool )
    self.OnlySuccess = bool == true
    return self
end

HTTP_GET = 0
HTTP_POST = 1
HTTP_HEAD = 2
HTTP_PUT = 3
HTTP_DELETE = 4
HTTP_PATCH = 5
HTTP_OPTIONS = 6

local game_ready_wait = game_ready.wait

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

    function request:run()
        game_ready_wait(function()

            local req = {
                ["url"] = self.URL,
                ["method"] = methods[ self.Method ] or "GET",
                ["parameters"] = self.Parameters,
                ["headers"] = self.Headers,
                ["body"] = self.Body,
                ["type"] = self:getContentType(),
                ["timeout"] = self:getTimeout(),
                ["success"] = function( code, body, headers, ... )
                    if self.OnlySuccess and not http.isSuccess( code ) then
                        return
                    end

                    for num, func in ipairs( self.Callbacks ) do
                        func( code, body, headers, ... )
                    end
                end,
                ["failed"] = function( ... )
                    if self.OnlySuccess then
                        return
                    end

                    for num, func in ipairs( self.Callbacks ) do
                        func( 504, ... )
                    end
                end
            }

            if HTTP( req ) then
                logger:debug( "{1} request to {2} ", req.method, req.url )
            else
                logger:debug( "{1} request failed! ({2})", req.method, req.url )
            end
        end)
    end

end

local timer_Simple = timer.Simple

do
    function http.request( url, callback, method )
        assert( type( url ) == "string", "bad argument #1 (string expected)")

        local new = setmetatable({
            ["URL"] = url,
            ["Headers"] = {},
            ["Callbacks"] = {},
            ["Parameters"] = {},
            ["Method"] = method or HTTP_GET
        }, request)

        new:addCallback( callback )

        timer_Simple(0, function()
            new:run()
        end)

        return new
    end
end

function http.Fetch( url, onSuccess, onFailure, headers, timeout )
    game_ready_wait(function()
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
    game_ready_wait(function()
        HTTP({
            ["url"] = url,
            ["method"] = "POST",
            ["failed"] = onFailure,
            ["success"] = function( code, body, headers )
                if type( onSuccess ) == "function" then
                    onSuccess( body, type(body) == "string" and body:len() or 0, headers, code )
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

    function http.Download( url, onSuccess, onFail, save_path )
        local filename = url:getFileFromURL( true )
        local path = ( save_path ~= nil and ( save_path .. "/" ) or "gpm_http/downloads/" ) .. filename
        logger:info( "File '{1}' is downloading...", filename )

        http.Fetch( url, function( data, size, headers, code )
            if http.isSuccess( code ) then
                if (size == 0) then
                    logger:warn( "File [{1}] size is zero!", filename )
                    return
                end

                local file_class = file.Open( path, "wb", "DATA" )
                if (file_class == nil) then
                    logger:warn( "Downloading failed, file failed to open due to it not existing or being used by another process: 'data/{1}'", path )
                    return
                end

                file_class:Write( data )
                file_class:Close()

                pcall( onSuccess, path, data, headers, size )

                logger:info( "Download completed successfully, file was saved as: 'data/{1}'", path )
                return
            end

            logger:warn( "An error code '{1}' was received while downloading: '{2}'", code, filename )
        end,
        function( err )
            logger:warn( "An error occurred while trying to download {1}:\n{2}'", filename, err )
            if type( onFail ) == "function" then
                onFail( err )
            end
        end, nil, 120 )
    end

    file.Download = http.Download

end

-- https://github.com/Be1zebub/Small-GLua-Things/blob/master/httputils.lua

--[[-------------------------------------------------------------------------
    http.Encode( str )
        encode URI https://en.wikipedia.org/wiki/Percent-encoding
---------------------------------------------------------------------------]]
function http.Encode( str )
	return (str:gsub("[^%w _~%.%-]", function( char )
		return string_format("%%%02X", char:byte())
	end):gsub(" ", "+"))
end

--[[-------------------------------------------------------------------------
    http.Decode( str )
        decode URI https://en.wikipedia.org/wiki/Percent-encoding
---------------------------------------------------------------------------]]
do
    local string_char = string.char
    function http.Decode( str )
        return (str:gsub("+", " "):gsub("%%(%x%x)", function( c )
            return string_char( tonumber( c, 16 ) )
        end))
    end
end

--[[-------------------------------------------------------------------------
    http.ParseQuery( str )
        parse string query, returns assoc query table
---------------------------------------------------------------------------]]
function http.ParseQuery( str )
	local query = {}

	for key, value in str:gmatch("([^&=?]-)=([^&=?]+)") do
		query[ key ] = http.Decode( value )
	end

	return query
end

--[[-------------------------------------------------------------------------
    http.ParseQuery( str )
        format string query from table
---------------------------------------------------------------------------]]
function http.Query( tbl )
	local out

	for key, value in pairs( tbl ) do
		out = (out and (out .."&") or "") .. key .."=".. value
	end

	return "?".. out
end

--[[-------------------------------------------------------------------------
    http.PrepareUpload( content, filename )
        returns headers, prepared content
---------------------------------------------------------------------------]]
local format = "--%s\r\n%s\r\n%s\r\n--%s--\r\n"
function http.PrepareUpload( content, filename )
	local boundary = "fboundary".. math.random( 1, 100 )
	local header_bound = "Content-Disposition: form-data; name=\"file\"; filename=\"".. filename .."\"\r\nContent-Type: application/octet-stream\r\n"
	local data = format:format( boundary, header_bound, content, boundary )

	return {
		{ "Content-Length", #data },
		{ "Content-Type", "multipart/form-data; boundary=" .. boundary }
	}, data
end

--[[ tested on api.vk.com (photos.getWallUploadServer method)
	local image = file.Read("/home/me.jpg")
	local headers, content = http.PrepareUpload(image, "me.jpg")
	local succ, res, result = pcall(http.request, "POST", "https://api.incredible-gmod.ru/upload", headers, content)
	print(result)
	  > https://incredible-gmod.ru/files/cxWJnf6
]]--
