--[[-------------------------------------------------------------------------
	WARDEN v1.0.0

	by: Silhouhat (http://steamcommunity.com/id/Silhouhat/)
---------------------------------------------------------------------------]]

WARDEN = WARDEN or {}
WARDEN.Config = WARDEN.Config or {}

WARDEN.API_KEY = WARDEN.API_KEY or false
WARDEN.CACHE = WARDEN.CACHE or {}

-------------------
-- Configuration --
-------------------

-- Logs various events in the console..
WARDEN.Config.Log = true

-- Used for debugging, you probably don't need this set to true..
WARDEN.Config.Debug = false

-- How long before we should clear the cache, in seconds.
WARDEN.Config.CacheTimer = 86400

-- How long should we wait before retrying someone's IP verification after a throttling message, in seconds.
WARDEN.Config.RetryTimer = 10

-- IP Addresses that we don't bother to check.
WARDEN.Config.NoCheck = {
	"loopback",
	"localhost",
	"127.0.0.1"
}

-- Groups & clients that are trusted enough to not check.
-- Careful, if a malicious person gets access to a client or group on this list
-- it can spell more trouble if they are using a proxy.
WARDEN.Config.Exceptions = {
	Groups = {
		"superadmin",
		"admin",
	},

	SteamIDs = {
		--"STEAM_0:1:56142649",
		--"STEAM_0:0:28681590",
	},
}

-- The kick messages to be displayed.
WARDEN.Config.KickMessages = {
	["Invalid IP"] = "Unable to verify IP address.",
	["Proxy IP"] = "Unable to validate IP address.",
}

---------------------
-- Local Functions --
---------------------

--[[-------------------------------------------------------------------------
	WARDEN_LOG( message, type )
		Just a pretty and branded print()

	ARGUMENTS:
		[string] message
			The message you would like to log to the console.

		[int] type
			The type of the message.

			0 = Information
			1 = Warning
			2 = Log
			3 = Debug
---------------------------------------------------------------------------]]
local function WARDEN_Log( type, msg )
	local textcolor, prefix = Color( 255, 255, 255 ), ""

	if type == 1 then
		textcolor, prefix = Color( 255, 100, 100 ), "ERROR: "
	end

	if type == 2 then
		if not WARDEN.Config.Log then return end

		textcolor, prefix = Color( 255, 255, 100 ), "LOG: "
	end

	if type == 3 then
		if not WARDEN.Config.Debug then return end

		textcolor, prefix = Color( 255, 125, 50 ), "DEBUG: "
	end

	MsgC( Color( 255, 255, 255 ), "[", Color( 51, 126, 254 ), "WARDEN", Color( 255, 255, 255 ), "] ", textcolor, prefix, msg, "\n" )
end

--[[-------------------------------------------------------------------------
	WARDEN_VerifyAPIKey( api_key )
		Verifies the API key given via 8.8.8.8 (Google's IP).
		The outcome is logged and if successful, the api key is set to be used.

	ARGUMENTS:
		[string] api_key
			The API key you want to verify and use if successful.
---------------------------------------------------------------------------]]
local function WARDEN_VerifyAPIKey( api_key )
	http.Fetch( "http://v2.api.iphub.info/ip/8.8.8.8",
		function( info )
			info = util.JSONToTable( info )
			local success = (info.block and info.block == 1) or false

			if success then
				WARDEN.API_KEY = api_key
				file.Write( "warden/apikey.txt", api_key )
				WARDEN_Log( 0, "API key successfully verified! Warden setup is complete." )
			else
				WARDEN_Log( 1, "API key verification failed! Warden will not be able to function correctly without the API key.")
				WARDEN_Log( 0, "For more information on how to set up the API key, use \"warden_help\"")
			end
		end,

		function()
			WARDEN_Log( 1, "API key verification failed! Warden will not be able to function correctly without the API key.")
			WARDEN_Log( 0, "For more information on how to set up the API key, use \"warden_help\"")
		end,

		{ ["X-Key"] = api_key }
	)
end

----------------------
-- Global Functions --
----------------------

--[[-------------------------------------------------------------------------
	WARDEN.CheckIP( ip, function )
		Checks the IP address via the iphub.info API.

	ARGUMENTS:
		[string] ip
			The IP to check.

		[function] function( block, info )
			The function to run

		[boolean] useCache = true
			Whether or not you would like to attempt to use the cache.

			ARGUMENTS:
				[string] ip
					IP address.

				[int/bool] block
					The block returned from the IP check. False if connection failed.

					POSSIBLE VALUES:
						-3 = Other error
						-2 = Request throttled
						-1 = Invalid IP
						0 = Safe, residential IP.
						1 = Unsafe, proxy IP.
						2 = Residential or proxy IP. (may flag innocent people.)

				[table] info
					The full table of information returned from the IP check.
					nil if the connection failed or retrieved from cache.
---------------------------------------------------------------------------]]
function WARDEN.CheckIP( ip, func, useCache )
	-- Prevent the server host from getting kicked.
	if table.HasValue( WARDEN.Config.NoCheck, ip ) then
		WARDEN_Log( 2, "Preventing the check of the IP address \""..ip.."\" because it is in the no-check list.")
		return
	end

	-- P2P servers don't work with IP addresses.
	if string.find( ip, "p2p" ) then
		WARDEN_Log( 1, "Warden does not work on P2P servers!" )
		return
	end

	useCache = useCache or true

	if useCache and table.HasValue( table.GetKeys( WARDEN.CACHE ), ip ) then
		WARDEN_Log( 3, "Using cache to get the block value for IP \""..ip.."\".")
		func( WARDEN.CACHE[ip], "CACHE" )
		return
	end

	http.Fetch( "http://v2.api.iphub.info/ip/"..ip, 
		function( info )
			info = util.JSONToTable( info )

			local block = 
				info.code and (
					(info.code == "InvalidArgument" and -1) or
					(info.code == "RequestThrottled" and -2) or
					-3
				) or info.block
			
			func( block, info )
		
			-- Add result to cache if the request wasn't throttled or an unknown error wasn't thrown.
			if block >= -1 then
				WARDEN.CACHE[ip] = block
			end
		end,

		function()
			func( false, nil )
		end,

		{ ["X-Key"] = WARDEN.API_KEY }
	)
end

--[[-------------------------------------------------------------------------
	WARDEN.SetupCache()
		Sets up a new instance of the cache table.

		Also clears any existing cache and starts a timer to clear
		the cache after a set amount of time set in the config.
---------------------------------------------------------------------------]]
function WARDEN.SetupCache()
	WARDEN_Log( 2, "Clearing cache..." )
	table.Empty( WARDEN.CACHE )

	-- We use this and timer.Create() instead of just timer.Simple() in order to not have multiple timers running at once.
	if timer.Exists( "WARDEN_CacheTimer" ) then
		timer.Remove( "WARDEN_CacheTimer" )
	end

	-- Clear the cache after a set period of time.
	timer.Create( "WARDEN_CacheTimer", WARDEN.Config.CacheTimer, 1, function()
		WARDEN.SetupCache()
	end )

	WARDEN_Log( 2, "Cache cleared." )
end

-----------
-- Hooks --
-----------

-- Initialize the files, cache, API key, etc.
local function WARDEN_Initialize()
	WARDEN_Log( 2, "Starting initialization sequence." )

	if file.Exists( "warden", "DATA" ) then
		if file.Exists( "warden/apikey.txt", "DATA" ) then
			WARDEN_Log( 2, "API key found. Verifying..." )
			WARDEN_VerifyAPIKey( file.Read( "warden/apikey.txt" ) )
		else
			WARDEN_Log( 1, "No API key found. Please enter your API with the \"warden_setapikey\" command." )
		end

		WARDEN.SetupCache()
	else
		file.CreateDir( "warden" )
		WARDEN_Log( 0, "Initial setup complete. Please set your API key with the \"warden_setapikey\" command." )
	end
end
hook.Add( "Initialize", "WARDEN_Initialize", WARDEN_Initialize )

-- Prevent people from joining w/ an untrusted IP address.
local function WARDEN_PlayerInitialSpawn( ply )
	if table.HasValue( WARDEN.Config.Exceptions.Groups, ply:GetUserGroup() ) or table.HasValue( WARDEN.Config.Exceptions.SteamIDs, ply:SteamID() ) then
		WARDEN_Log( 2, "Ignoring verifying the IP of "..ply:Nick().." as their SteamID or usergroup is in the exceptions list.")
		WARDEN_Log( 3, "SteamID: "..ply:SteamID().." | Usergroup: "..ply:GetUserGroup() )
		return
	end

	WARDEN.CheckIP( ply:IPAddress(), function( block )
		if !block or block == -3 then
			WARDEN_Log( 1, "Failed to connect to IPHub API to check the IP address of"..ply:Nick().."!" )
			return
		end

		if block == -2 then
			WARDEN_Log( 1, "Too many requests to the IPHub API to check the IP address of "..ply:Nick()..". Retrying in "..WARDEN.Config.RetryTimer.." seconds." )
			timer.Simple( WARDEN.Config.RetryTimer, function()
				WARDEN_PlayerInitialSpawn( ply )
			end )

			return
		end

		-- This really shouldn't happen, but we're going to put it here anyway as a fallback.
		if block == -1 then
			WARDEN_Log( 1, "The IP address of "..ply:Nick().." is invalid!" )
			WARDEN_Log( 3, "IP Address: "..ply:IPAddress() )
			ply:Kick( WARDEN.Config.KickMessages["Invalid IP"] )
			return
		end

		if block == 1 then
			WARDEN_Log( 2, "The IP address of "..ply:Nick().." was marked as a proxy. Kicking player..." )
			ply:Kick( WARDEN.Config.KickMessages["Proxy IP"] )
			return
		end
	end )
end
hook.Add( "PlayerInitialSpawn", "WARDEN_PlayerInitialSpawn", WARDEN_PlayerInitialSpawn)

-----------------
-- Concommands --
-----------------

-- Displays help on how to setup Warden.
concommand.Add( "warden_help", function()
	WARDEN_Log( 0, "To get your API key and activate Warden, follow these steps:")
	WARDEN_Log( 0, "Step 1) Go to http://iphub.info/ and create a free account." )
	WARDEN_Log( 0, "Step 2) Click the link in your e-mail to verify your account.")
	WARDEN_Log( 0, "Step 3) Go to the pricing page and select \"Get it for free\", then click \"Claim your free key\"")
	WARDEN_Log( 0, "Step 4) Retrieve your API key from either your e-mail or the \"account\" -> \"subscription #xxx\" page.")
	WARDEN_Log( 0, "Step 5) Enter you API key with the \"warden_setapikey [api key]\" console command.")
	WARDEN_Log( 0, "That's all! Thank you for downloading Warden!")
end )

-- The command used to set the API key to be used.
concommand.Add( "warden_setapikey", function( ply, cmd, args ) 
	if not args or table.Count( args ) != 1 then
		WARDEN_Log( 1, "Invalid syntax! Use \"warden_setapikey [apikey]\"" )
		return
	end

	WARDEN_Log( 0, "API key registered. Verifying..." )
	WARDEN_VerifyAPIKey( args[1] )
end )

-- Debug concommands.
if WARDEN.Config.Debug then
	-- Checks the IP you input outright via WARDEN.CheckIP().
	concommand.Add( "warden_checkip", function( ply, cmd, args )
		if not args or table.Count( args ) != 1 then
			WARDEN_Log( 1, "Invalid arguments! Use \"warden_checkip [ip address]\"")
			return
		end

		WARDEN.CheckIP( args[1], function( block, info )
			if block == -3 then
				WARDEN_Log( 1, info.message )
				return
			end

			if block == -2 then
				WARDEN_Log( 1, "Request limit exceeded for this timeframe. Please slow down or wait." )
				return
			end

			if block == -1 then
				WARDEN_Log( 1, args[1].." is not a valid IP address." )
				return
			end

			WARDEN_Log( 0, args[1].." is"..(block != 1 and " NOT" or "").." a proxy IP." )
		end )
	end )
end
