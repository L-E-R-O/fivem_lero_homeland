# 🛡️ LERO Homeland Security

> *Your tactical operations companion for FiveM! Deploy with confidence, coordinate with precision.* ✨

[![FiveM](https://img.shields.io/badge/FiveM-Ready-blue?style=flat-square)](https://fivem.net)
[![License](https://img.shields.io/badge/License-Custom-red?style=flat-square)](#)
[![Version](https://img.shields.io/badge/Version-3.0.0-green?style=flat-square)](#)
[![ESX](https://img.shields.io/badge/Framework-ESX-purple?style=flat-square)](https://github.com/esx-framework)

A sleek, powerful tactical operations system for FiveM servers that transforms authorized players into a coordinated homeland security team. Perfect for roleplay servers looking to add military/law enforcement operations! 🚁

## ✨ What Makes It Special?

This isn't just another FiveM script—it's a complete tactical command center! Whether you're coordinating raids, emergency responses, or special operations, LERO Homeland gives your team the tools they need to work together seamlessly.

### 🎯 Core Features

- **🔐 Smart Authorization** - Secure access control using Steam, License, or Discord identifiers
- **📍 Instant Deployment** - Teleport to and from the operational base with a single click
- **🎖️ Auto-Gear System** - Automatically equips tactical outfits and weapons upon deployment
- **🚗 Vehicle Fleet** - Spawn mission-ready vehicles (Nightshark, Insurgent, Akula helicopter)
- **⛈️ Weather Control** - Create atmospheric thunder weather for dramatic operations
- **📡 Team Coordination** - Ping players and broadcast messages to all active agents
- **💾 State Preservation** - Saves and restores your civilian outfit, weapons, and location
- **🎨 Sleek UI** - Beautiful, intuitive control panel with visual feedback

## 📦 Installation

Getting started is a breeze! Just follow these steps:

1. **Download** this repository and place it in your server's `resources` folder
2. **Install Dependencies** - Make sure you have:
   - [es_extended](https://github.com/esx-framework/esx-legacy)
   - [ox_lib](https://github.com/overextended/ox_lib)
   - [ox_inventory](https://github.com/overextended/ox_inventory)
   - [oxmysql](https://github.com/overextended/oxmysql)
3. **Add to server.cfg**:
   ```
   ensure fivem_lero_homeland
   ```
4. **Configure** your authorized users in `config.lua` (see below!)
5. **Restart** your server and you're ready to roll! 🎉

## ⚙️ Configuration

Open `config.lua` and customize to your heart's content:

### 🔑 Authorize Your Team
```lua
Config.AuthorizedIdentifiers = {
    'license:YOUR_LICENSE_HERE',
    'steam:YOUR_STEAM_ID_HERE',
    'discord:YOUR_DISCORD_ID_HERE'
}
```

### 📍 Set Your Base Location
```lua
Config.TeleportLocation = {
    x = -2007.626342,
    y = 3117.283448,
    z = 32.801514,
    heading = 8.503936
}
```

### 🚗 Customize Your Fleet
Add or modify vehicles in the `Config.Vehicles` table—use any GTA V vehicle model!

### 🎖️ Outfit & Loadout
Customize tactical outfits for male/female characters and weapon loadouts to match your server's style.

## 🎮 How to Use

1. **Open Menu** - Authorized players can open the Homeland menu (default: `/homeland` or your custom keybind)
2. **Join Operation** - Click the "Join (Teleport)" button to teleport to base and gear up automatically
3. **Coordinate** - Use the leader controls to start operations, ping teammates, and broadcast messages
4. **Return Safely** - Click the "Return (Teleport)" button when done to return to your original location with your civilian gear

### 👑 Leader Commands
Only the first authorized player to join has access to:
- Start/Stop operations
- Control weather effects
- Ping specific players
- Broadcast messages to the team

## 🤝 Contributing

Found a bug? Have a cool idea? We'd love to hear from you! Feel free to:
- Open an issue to report bugs or suggest features
- Submit a pull request with improvements
- Share your experience using this script!

## 💖 Support & Community

If this script made your server better, consider:
- ⭐ Starring this repository
- 🐛 Reporting bugs you find
- 💡 Suggesting new features
- 📢 Sharing it with other server owners

## 📝 Credits

Created with ❤️ by **LERO**

Special thanks to the FiveM community for their amazing frameworks and continuous support!

---

<div align="center">

**Made for the FiveM community** 🌟

*Transform your server's tactical operations today!*

</div>
