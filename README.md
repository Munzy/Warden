# What is Warden?
Warden is an API wrapper for [IPHub](https://iphub.info/) that allows servers to automatically prevent clients with identified proxy IPs from joining.

# How does Warden work?
Warden uses the IPHub API to send the IP address of the joining player and verify that it is not a proxy. If it is, it automatically kicks the player. That's it!

# How do I add Warden to my server?
There are two mains ways of doing this. One, the easiest, is to add this workshop item to your server. Second, however, is to download Warden from our [GitHub Repo](https://github.com/Silhouhat/Warden) and insert the "warden" folder into your garrysmod/addons folder. The latter method will allow you to configure options such as kick messages, cache timers, and more in the warden/lua/autorun/server/sv_warden.lua file.

# Setting up Warden
Once installed, the setup for warden is extremely easy. Follow the following steps using your server console:
* Step 1) Go to http://iphub.info/ and create a free account.
* Step 2) Click the link in your e-mail to verify your account.
* Step 3) Go to the pricing page and select "Get it for free", then click "Claim your free key"
* Step 4) Retrieve your API key from either your e-mail or the "account" -> "subscription #xxx" page.
* Step 5) Enter you API key with the "warden_setapikey [api key]" console command.
That's all!

# Links & Information
* [Workshop Page](http://steamcommunity.com/sharedfiles/filedetails/?id=1134625427)
* [IPHub.info](https://iphub.info/)
