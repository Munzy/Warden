--[[-------------------------------------------------------------------------
	WARDEN v2.0.0

	by: Silhouhat (http://steamcommunity.com/id/Silhouhat/)
---------------------------------------------------------------------------]]

WARDEN = WARDEN or {}
WARDEN.Config = WARDEN.Config or {}

WARDEN.API_KEY = WARDEN.API_KEY or false
WARDEN.CACHE = WARDEN.CACHE or {}

-------------------
-- Configuration --
-------------------

-- Logs various events in the console.
WARDEN.Config.Log = true

-- Used for debugging, you probably don't need this set to true.
WARDEN.Config.Debug = false

-- How long before we should clear the cache, in seconds.
WARDEN.Config.CacheTimer = 86400

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
	["Invalid IP"] = "Unable to verify IP address",
	["Proxy IP"] = "Unable to validate IP address",
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

----------------------
-- Global Functions --
----------------------

--[[-------------------------------------------------------------------------
	WARDEN.CheckIP( ip, function )
		Checks the IP address to see if it is a proxy.

	ARGUMENTS:
		[string] ip
			The IP to check.

		[function] callback( proxyInfo )
			The callback to run when the IP verification is finished.

			PARAMETERS:
				[string/bool] proxyInfo
						The return value from the IP check. False if connection failed.

						POSSIBLE VALUES:
							Y = Marked as proxy
							N = Not marked as proxy
							E = Error connecting to the site.

		[boolean] useCache = true
			Whether or not you would like to attempt to use the cache.
---------------------------------------------------------------------------]]
function WARDEN.CheckIP( ip, callback, useCache )
	-- If the port is included, we throw it out.
	if string.find( ip, ":" ) then
		ip = string.Explode( ":", ip )[1]
	end

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
		WARDEN_Log( 3, "Using cache to get the verification for \""..ip.."\".")
		callback( WARDEN.CACHE[ip], "CACHE" )
		return
	end

	http.Fetch( "https://blackbox.ipinfo.app/lookup/"..ip,
		function( info )
			callback( info )

			-- Add result to cache
			WARDEN.CACHE[ip] = info
		end,

		function()
			callback( "E" )
		end
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

-- Prevent people from joining w/ an untrusted IP address.
local function WARDEN_PlayerInitialSpawn( ply )
	if table.HasValue( WARDEN.Config.Exceptions.Groups, ply:GetUserGroup() ) or table.HasValue( WARDEN.Config.Exceptions.SteamIDs, ply:SteamID() ) then
		WARDEN_Log( 2, "Ignoring verifying the IP of "..ply:Nick().." as their SteamID or usergroup is in the exceptions list.")
		WARDEN_Log( 3, "SteamID: "..ply:SteamID().." | Usergroup: "..ply:GetUserGroup() )
		return
	end

	WARDEN_Log( 2, "Verifying the IP address of "..ply:Nick().."..." )
	WARDEN.CheckIP( ply:IPAddress(), function( isProxy )
		if isProxy == "Y" then
			WARDEN_Log( 2, "The IP address of "..ply:Nick().." was marked as a proxy. Kicking player..." )
			ply:Kick( WARDEN.Config.KickMessages["Proxy IP"] )
		elseif isProxy == "N" then
			WARDEN_Log( 2, "The IP address of "..ply:Nick().." is clean." )
		elseif isProxy == "E" then
			WARDEN_Log( 1, "Could not connect to the API to check the IP address of "..ply:Nick().."!" )
		end
	end )
end
hook.Add( "PlayerInitialSpawn", "WARDEN_PlayerInitialSpawn", WARDEN_PlayerInitialSpawn)

-----------------
-- Concommands --
-----------------

-- Debug concommands.
if WARDEN.Config.Debug then
	-- Checks the IP you input outright via WARDEN.CheckIP().
	concommand.Add( "warden_checkip", function( ply, cmd, args )
		if not args or table.Count( args ) != 1 then
			WARDEN_Log( 1, "Invalid arguments! Use \"warden_checkip [ip address]\"")
			return
		end

		WARDEN.CheckIP( args[1], function( isProxy )
			if isProxy == "E" then
				WARDEN_Log( 1, "Could not connect to the API site." )
				return
			end

			WARDEN_Log( 0, args[1].." is"..((isProxy == "N") and " NOT" or "").." a proxy IP address." )
		end )
	end )
end
