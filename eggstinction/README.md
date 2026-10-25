# Eggstinction repair source

This folder records the gameplay and geometry-generator changes shipped with the 25 October 2026 Workshop map. It is not a standalone complete Mod Tools project; it needs the project's generated map, model/texture/sound assets, other scripts and official BO3 Mod Tools to rebuild. The generic Egg LIVE receiver alone does not install this map or change doors on stock maps.

The full locally tested map is distributed separately through [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3826769399). Door audit: all 66 native checks passed, including normal damage, unpaid physical collision, jumping, forced breach recovery and purchased passage both ways. R instant restart and F countdown restart were verified in-game. See docs/DOOR-REPAIR-REPORT.json and docs/HUD-REPAIR-REPORT.json for limits.
