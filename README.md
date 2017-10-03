# What is Warden?
Warden is an API wrapper for the [Black Box Proxy Block](http://proxy.mind-media.com/block/) that allows servers to automatically prevent clients with identified proxy IPs from joining.

# How does Warden work?
Warden uses the IPHub API to send the IP address of the joining player and verify that it is not a proxy. If it is, it automatically kicks the player. That's it!

# How do I add Warden to my server?
There are two mains ways of doing this. One, the easiest, is to add this workshop item to your server. Second, however, is to download Warden from our [GitHub Repo](https://github.com/Silhouhat/Warden) and insert the "warden" folder into your garrysmod/addons folder. The latter method will allow you to configure options such as kick messages, cache timers, and more in the warden/lua/autorun/server/sv_warden.lua file.

# Setting up Warden
As of v2.0, no setup is necessary! If you'd like to edit some configuration variables, you can find the configuration in sv_warden.lua.

# Links & Information
* [Workshop Page](http://steamcommunity.com/sharedfiles/filedetails/?id=1134625427)
* [Black Box Proxy Block](http://proxy.mind-media.com/block/)
