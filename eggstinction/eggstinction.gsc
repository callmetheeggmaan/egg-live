// Eggstinction gameplay. See verification.json for current checks and limits.
// Built against the stock BO3 Mod Tools APIs inspected during setup.
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\spawner_shared;
#using scripts\codescripts\struct;
#using scripts\shared\flag_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_zonemgr;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_ai_dogs;
#using scripts\zm\egg_bgb_machine;
#using scripts\zm\_zm_bgb;
#namespace eggstinction;
#precache("fx", "electric/fx_elec_sparks_directional_orange");
#precache("model", "egg_bulkhead");
#precache("model", "egg_hatchery_beast");

#precache("model", "tag_origin");
#precache("weapon", "eggmin_cannon");

function init()
{
    level.egg_mode = "easy";
    level.egg_mode_ready = false;
    level.egg_health_scale = 0.75;
    level.egg_count_scale = 1.25;
    level.egg_start_points = 1500;
    level.egg_door_scale = 0.75;
    level.egg_gate_open = [];
    for (i = 0; i < 5; i++) level.egg_gate_open[i] = false;
    level.egg_escape_started = false;
    level.egg_admin_used = false;
    level.egg_run_started = 0;
    level.egg_run_reported = false;
    level.egg_warden_round = -1;
    level.egg_dog_locations=[];
    for (room=0;room<6;room++)
    {
        for (side=-1;side<=1;side+=2) for (edge=-1;edge<=1;edge+=2)
        {
            location=struct::spawn();
            location.origin=(room*1536+448*side,500*edge,0);
            location.angles=(0,0,0);
            location.egg_room=room;
            level.egg_dog_locations[level.egg_dog_locations.size]=location;
        }
    }
    if (IsDefined(level.dog_spawners))
        foreach (dog_spawner in level.dog_spawners) dog_spawner spawner::add_spawn_function(&dog_balance);
    level.egg_original_round_spawn = &zm::round_spawning;
    if (IsDefined(level.round_spawn_func)) level.egg_original_round_spawn = level.round_spawn_func;
    level.round_spawn_func = &round_spawning;
    level.egg_original_round_wait = &zm::round_wait;
    if (IsDefined(level.round_wait_func)) level.egg_original_round_wait=level.round_wait_func;
    level.round_wait_func=&round_waiting;
    // A pending first wave must not look like a completed empty round.
    level.zombie_total=1;
    level.egg_original_count_hook = undefined;
    if (IsDefined(level.zombie_total_set_func)) level.egg_original_count_hook = level.zombie_total_set_func;
    level.zombie_total_set_func = &round_count;
    level.func_get_zombie_spawn_delay=&spawn_delay;
    level.zombie_vars["zombie_between_round_time"]=5;
    level.egg_reward_models=[];
    level.egg_original_box_spawned=undefined;
    if (IsDefined(level.func_magicbox_weapon_spawned)) level.egg_original_box_spawned=level.func_magicbox_weapon_spawned;
    level.func_magicbox_weapon_spawned=&track_box_reward;
    zm_spawner::add_custom_zombie_spawn_logic(&zombie_spawned);
    zm_spawner::register_zombie_damage_callback(&zombie_damage);
    callback::on_spawned(&player_spawned);
    level.egg_gameover_active=false;
    level.egg_restart_pending=false;
    level.egg_original_end_screen=undefined;
    if (IsDefined(level.custom_end_screen)) level.egg_original_end_screen=level.custom_end_screen;
    level.custom_end_screen=&game_over_options;
    level thread setup_interactions();
    // Difficulty is an explicit start button; exploring setup never locks it.
    level thread box_collisions();
    foreach (door in GetEntArray("script_brushmodel","classname")) if (IsDefined(door.targetname) && GetSubStr(door.targetname,0,9)=="egg_gate_") door Solid();
    level.egg_previous_area_check=undefined;
    if(IsDefined(level.player_out_of_playable_area_monitor_callback))level.egg_previous_area_check=level.player_out_of_playable_area_monitor_callback;
    level.player_out_of_playable_area_monitor_callback=&door_area_safety;
    level thread perk_spare_change();
}

function round_spawning()
{
    while (!level.egg_mode_ready) wait(0.05);
    level [[level.egg_original_round_spawn]]();
}

function round_waiting()
{
    while (!level.egg_mode_ready) wait(0.05);
    level [[level.egg_original_round_wait]]();
}

function round_count()
{
    if (IsDefined(level.egg_original_count_hook)) level [[level.egg_original_count_hook]]();
    minimum=10;
    if (level.egg_mode=="medium") minimum=12;
    if (level.egg_mode=="hard") minimum=14;
    level.zombie_total = Int(Max(minimum, Int(level.zombie_total * level.egg_count_scale)));
}

function spawn_delay(round)
{
    factor=0.35;
    if (level.egg_mode=="medium") factor=0.27;
    if (level.egg_mode=="hard") factor=0.2;
    return Max(0.12,zm::get_zombie_spawn_delay(round)*factor);
}

function remaining_enemies()
{
    if (!level.egg_mode_ready || level.intermission) return 0;
    count=Int(Max(0,level.zombie_total));
    foreach (enemy in zombie_utility::get_round_enemy_array())
        if (IsAlive(enemy)) count++;
    return count;
}

function round_counter()
{
    self endon("disconnect"); self endon("egg_new_life");
    hud=NewClientHudElem(self);
    hud.horzAlign="center"; hud.alignX="center"; hud.x=0; hud.y=22;
    hud.fontScale=1.45; hud.color=(1,1,1); hud.alpha=1;
    hud.hideWhenDead=true; hud.hideWhenInMenu=true;
    self.egg_counter_hud=hud;
    previous="";
    while (IsAlive(self))
    {
        label="^3SETUP HUB ^7- choose difficulty to start";
        hud.alpha=1;
        if (level.intermission || level.egg_gameover_active) hud.alpha=0;
        if (level.egg_mode_ready) label="^3ROUND "+level.round_number+"   ^7ZOMBIES LEFT: ^5"+remaining_enemies();
        if (label!=previous) {hud SetText(label); previous=label;}
        wait(0.15);
    }
    hud Destroy();
}

function zombie_spawned()
{
    if (!level.egg_mode_ready) return;
    self.maxhealth = Int(Max(1, Int(self.maxhealth * level.egg_health_scale)));
    self.health = self.maxhealth;
    walk_until = 1;
    sprint_from = 30;
    if (level.egg_mode == "medium") { sprint_from = 12; }
    if (level.egg_mode == "hard") { sprint_from = 6; }
    speed = "walk";
    if (level.round_number >= walk_until) speed = "run";
    if (level.round_number >= sprint_from) speed = "sprint";
    self zombie_utility::set_zombie_run_cycle(speed);
    if (level.round_number>=7 && (level.round_number-7)%5==0 && level.egg_warden_round!=level.round_number)
    {
        level.egg_warden_round=level.round_number;
        self.egg_warden=true;
        self.maxhealth=Int(self.maxhealth*6);
        self.health=self.maxhealth;
        self thread replace_with_beast();
    }
}

function dog_schedule()
{
    old_spawn=undefined;
    old_wait=undefined;
    while (true)
    {
        level waittill("between_round_over");
        if (level.round_number%5==0)
        {
            old_spawn=level.round_spawn_func;
            old_wait=level.round_wait_func;
            level.sndMusicSpecialRound=true;
            zm_ai_dogs::dog_round_start();
            level.round_spawn_func=&zm_ai_dogs::dog_round_spawning;
            level.round_wait_func=&zm_ai_dogs::dog_round_wait_func;
        }
        else if (level flag::get("dog_round"))
        {
            zm_ai_dogs::dog_round_stop();
            level.round_spawn_func=old_spawn;
            level.round_wait_func=old_wait;
            level.dog_round_count++;
        }
    }
}

function dog_spawn_point(spawners,player)
{
    if (!IsDefined(player)) return level.egg_dog_locations[0];
    unlocked=0;
    for (i=0;i<5;i++)
    {
        if (!level.egg_gate_open[i]) break;
        unlocked=i+1;
    }
    candidates=[];
    fallback=level.egg_dog_locations[0];
    farthest=-1;
    foreach (location in level.egg_dog_locations)
    {
        if (location.egg_room>unlocked) continue;
        distance=DistanceSquared(location.origin,player.origin);
        if (distance>farthest && distance<1000*1000) { fallback=location; farthest=distance; }
        if (distance>400*400 && distance<1000*1000)
        {
            if (IsDefined(level.egg_last_dog_location) && level.egg_last_dog_location==location) continue;
            candidates[candidates.size]=location;
        }
    }
    selected=fallback;
    if (candidates.size>0) selected=candidates[RandomInt(candidates.size)];
    level.egg_last_dog_location=selected;
    return selected;
}

function dog_balance()
{
    self.maxhealth=Int(Max(1,level.dog_health*level.egg_health_scale));
    self.health=self.maxhealth;
}

function warden_presentation()
{
    IPrintLn("^3THE GUARDIAN HAS AWAKENED ^7- THE HATCHERY BEAST!");
    foreach (player in GetPlayers()) player PlayLocalSound("egg_guardian_arrival");
    huds=[];
    foreach (player in GetPlayers())
    {
        title=NewClientHudElem(player);
        title.horzAlign="center"; title.alignX="center"; title.y=72;
        title.fontScale=1.4; title.color=(1,0.75,0.2); title.alpha=1;
        title SetText("THE GUARDIAN - HATCHERY BEAST");
        huds[huds.size]=title;
        bar=NewClientHudElem(player);
        bar.horzAlign="center"; bar.alignX="center"; bar.y=93;
        bar.color=(1,0.65,0.1); bar.alpha=0.9;
        bar SetShader("white",260,6);
        huds[huds.size]=bar;
    }
    ticks=0;
    while (IsAlive(self) && !level.intermission && !level.egg_gameover_active)
    {
        if (ticks%12==0) foreach (player in GetPlayers()) player PlayLocalSound("egg_guardian_heartbeat");
        for (i=1;i<huds.size;i+=2)
            huds[i] SetShader("white",Int(Max(1,260*self.health/self.maxhealth)),6);
        ticks++;
        wait(0.2);
    }
    foreach (hud in huds) if (IsDefined(hud)) hud Destroy();
    if (!level.intermission && !level.egg_gameover_active) IPrintLn("^3Hatchery Beast defeated!");
}


function replace_with_beast()
{
    wait(0.2);
    if (!IsAlive(self) || level.dog_spawners.size==0) return;
    origin=self.origin;health=self.maxhealth;
    beast=zombie_utility::spawn_zombie(level.dog_spawners[0]);
    if (!IsDefined(beast)) return;
    beast.egg_warden=true;
    beast.maxhealth=health;beast.health=health;
    beast SetModel("egg_hatchery_beast");
    beast.favoriteenemy=zm_ai_dogs::get_favorite_enemy();
    spot=SpawnStruct();spot.origin=origin;spot.angles=self.angles;
    spot thread zm_ai_dogs::dog_spawn_fx(beast,spot);
    beast thread warden_presentation();
    // A native dog takes this actor's existing wave slot. No pending count change.
    self DoDamage(self.health+1,self.origin,undefined,undefined,"none","MOD_TRIGGER_HURT");
}

function spark_pulse(origin)
{
    if(!IsDefined(level.egg_spark_count)) level.egg_spark_count=0;
    level.egg_spark_count++;
    effect=SpawnFX("electric/fx_elec_sparks_directional_orange",origin);
    TriggerFX(effect);
    wait(0.45);
    if(IsDefined(effect)) effect Delete();
    level.egg_spark_count--;
}

function upgrade_celebration(tier,origin)
{
    self endon("disconnect");self endon("death");self endon("egg_new_life");
    self PlayLocalSound("egg_upgrade");
    for(i=0;i<3;i++)
    {
        level thread spark_pulse(origin+(0,0,22+i*20));
        wait(0.12);
    }
    self IPrintLnBold("^3"+upgrade_name(tier)+" ACTIVATED");
    banner=NewClientHudElem(self);banner.horzAlign="center";banner.alignX="center";
    banner.y=140;banner.fontScale=1.7;banner.color=(0.2,0.9,1);banner.alpha=1;
    banner.hideWhenDead=true;banner.hideWhenInMenu=true;
    self.egg_upgrade_banner=banner;
    banner SetText(upgrade_name(tier)+" | "+upgrade_description(tier));
    wait(3);banner FadeOverTime(0.5);banner.alpha=0;wait(0.5);banner Destroy();
}

function selection_timeout()
{
    while (GetPlayers().size == 0) wait(0.25);
    wait(60);
    if (!level.egg_mode_ready) choose_mode("easy");
}

function choose_mode(mode)
{
    // Native player/round initialization must finish before releasing spawning.
    level flag::wait_till("initial_blackscreen_passed");
    if (level.egg_mode_ready) return;
    level.egg_mode = mode;
    switch (mode)
    {
        case "medium":
            level.egg_health_scale = 1;
            level.egg_count_scale = 1.4;
            level.egg_start_points = 750;
            level.egg_door_scale = 1;
            break;
        case "hard":
            level.egg_health_scale = 1.35;
            level.egg_count_scale = 1.65;
            level.egg_start_points = 500;
            level.egg_door_scale = 1;
            break;
    }
    level.egg_mode_ready = true;
    level.egg_run_started = GetTime();
    record_run("start");
    IPrintLn("^3Difficulty: ^7" + mode);
    level notify("egg_mode_selected");
    level thread close_selection();
}

function close_selection()
{
    wait(0.1);
    terminals=GetEntArray("egg_difficulty", "targetname");
    foreach (terminal in terminals)
    {
        state="Locked - this match is " + level.egg_mode;
        if (terminal.script_string==level.egg_mode) state="Selected: " + level.egg_mode;
        terminal set_hint(state);
    }
}

function player_spawned()
{
    self notify("egg_new_life");
    self thread life();
    if (IsDefined(level.egg_selftest_mode) && self IsHost()) self thread smoke_test();
}

function life()
{
    self endon("disconnect");
    self endon("death");
    self endon("egg_new_life");
    self.egg_admin_active = false;
    self.egg_tier = 0;
    self.egg_gum_round=-1;
    if(IsDefined(self.egg_upgrade_banner)) self.egg_upgrade_banner Destroy();
    self clientfield::set_to_player("egg_upgrade_tier",0);
    self.egg_proc_after = 0;
    self.egg_bonus_hits=0;
    self.egg_next_custom_use=0;
    level.perk_purchase_limit = 8;
    if (IsDefined(self.egg_status_hud)) self.egg_status_hud Destroy();
    if (IsDefined(self.egg_counter_hud)) self.egg_counter_hud Destroy();
    if (IsDefined(self.egg_use_hud)) self.egg_use_hud Destroy();
    if (IsDefined(self.egg_crosshair_hud)) self.egg_crosshair_hud Destroy();
    self.egg_crosshair=0;
    self clientfield::set_to_player("egg_reticle_mode",0);
    self.egg_door_safe_origin=self.origin;
    self.egg_gate_recoveries=0;
    self thread door_boundary_guard();
    self thread crosshair_display();
    self thread round_counter();
    self thread use_controls();
    self thread admin_ammo();
    self thread upgrade_death_reset();
    if (!level.egg_mode_ready) self IPrintLn("Setup hub: choose a loadout, then a difficulty.");
    while (!level.egg_mode_ready) wait(0.05);
    while (!IsDefined(self.score)) wait(0.05);
    if (!IsDefined(self.egg_first_spawn_done))
    {
        self.egg_first_spawn_done = true;
        // Add the mode bonus to the native starting balance. Preserve points
        // found under perks, and points spent on purchases during setup.
        if (level.round_number <= 1 && level.egg_start_points>500)
            self zm_score::add_to_player_score(level.egg_start_points - 500, false);
    }
}

function upgrade_death_reset()
{
    self endon("disconnect");self endon("egg_new_life");
    self waittill("death");
    self clientfield::set_to_player("egg_upgrade_tier",0);
    if(IsDefined(self.egg_upgrade_banner)) self.egg_upgrade_banner Destroy();
}

function set_hint(message)
{
    self.egg_hint=message;
    self SetHintString("");
}

function accept_use(player)
{
    if (IsDefined(player.egg_next_custom_use) && GetTime()<player.egg_next_custom_use) return false;
    player.egg_next_custom_use=GetTime()+300;
    return true;
}

function use_controls()
{
    self endon("disconnect"); self endon("death"); self endon("egg_new_life");
    // Also drive consoles from a fresh Use press while looking at them. This
    // keeps small decorative models from blocking the native trigger ray.
    held=false;
    hud=NewClientHudElem(self);
    hud.horzAlign="center"; hud.vertAlign="bottom";
    hud.alignX="center"; hud.alignY="bottom"; hud.y=-100;
    hud.fontScale=1.35; hud.color=(1,1,1); hud.alpha=0;
    hud.hideWhenDead=true; hud.hideWhenInMenu=true;
    self.egg_use_hud=hud;
    while (true)
    {
        down=self UseButtonPressed();
        nearest=undefined; best=190*190;
        foreach (name in StrTok("egg_difficulty|egg_gate_use|egg_upgrade_use|egg_admin_use|egg_crosshair_use","|"))
        {
            foreach (terminal in GetEntArray(name,"targetname"))
            {
                distance=DistanceSquared(self.origin,terminal.origin);
                direction=VectorNormalize(terminal.origin-self GetEye());
                if (distance<best && VectorDot(AnglesToForward(self GetPlayerAngles()),direction)>0.45)
                {nearest=terminal;best=distance;}
            }
        }
        hud.alpha=0;
        if (IsDefined(nearest) && IsDefined(nearest.egg_hint))
        {hud SetText(nearest.egg_hint);hud.alpha=1;}
        if (down && !held && IsDefined(nearest)) nearest notify("trigger",self);
        held=down;
        wait(0.05);
    }
}

function setup_interactions()
{
    // Map brush triggers use these exact targetnames. Stock perks/box/PAP keep
    // their own engine interactions and are not replaced by this module.
    terminals = GetEntArray("egg_difficulty", "targetname");
    foreach (terminal in terminals) terminal thread difficulty_terminal();
    gates = GetEntArray("egg_gate_use", "targetname");
    foreach (gate in gates) gate thread gate_terminal();
    upgrades = GetEntArray("egg_upgrade_use", "targetname");
    foreach (upgrade in upgrades) upgrade thread upgrade_terminal();
    lockers = GetEntArray("egg_admin_use", "targetname");
    foreach (locker in lockers) locker thread admin_terminal();
    foreach (terminal in GetEntArray("egg_crosshair_use","targetname")) terminal thread crosshair_terminal();
}

function difficulty_terminal()
{
    self SetCursorHint("HINT_NOICON");
    self set_hint("[{+activate}] Choose " + self.script_string + " (host)");
    while (!level.egg_mode_ready)
    {
        self waittill("trigger", player);
        if (!IsDefined(player) || !IsPlayer(player) || !player IsHost()) continue;
        if (!accept_use(player)) continue;
        if (level.egg_mode_ready) return;
        choose_mode(self.script_string);
    }
}

function door_cost(index)
{
    return Int(Max(250, Int(((2000 + 2000 * index) * level.egg_door_scale + 25) / 50) * 50));
}

function destination(index)
{
    switch (index)
    {
        case 0: return "SHELLWORKS";
        case 1: return "HATCHERY";
        case 2: return "YOLK REACTOR";
        case 3: return "UPGRADE LAB";
        case 4: return "GOLDEN VAULT";
    }
    return "NEXT ROOM";
}

function gate_terminal()
{
    index = self.script_int;
    self SetCursorHint("HINT_NOICON");
    while (!level.egg_mode_ready) wait(0.05);
    cost = door_cost(index);
    self set_hint("[{+activate}] OPEN " + destination(index) + " [" + cost + "] - opens both lanes");
    while (!level.egg_gate_open[index])
    {
        self waittill("trigger", player);
        if (!IsDefined(player) || !IsPlayer(player) || !IsAlive(player)) continue;
        if (!accept_use(player)) continue;
        if (level.egg_gate_open[index]) return;
        if (index > 0 && !level.egg_gate_open[index - 1]) continue;
        if (!IsDefined(player.score) || player.score < cost)
        {
            player IPrintLnBold("You need " + cost + " points");
            continue;
        }
        // No yield between the availability check, lock and charge.
        level.egg_gate_open[index] = true;
        player zm_score::minus_to_player_score(cost);
        player PlaySound("egg_purchase");
        zone_names=StrTok("nest_zone|shellworks_zone|hatchery_zone|reactor_zone|kitchen_zone|vault_zone","|");
        zm_zonemgr::enable_zone(zone_names[index+1]);
        level flag::set("egg_open_" + index);
        doors = GetEntArray("egg_gate_" + index, "targetname");
        foreach (door in doors)
        {
            door.egg_gate_index=index;
            door thread open_bulkhead();
        }
        level flag::set("egg_open_" + index);
        IPrintLn(destination(index) + " OPEN - both lanes clear");
        level thread close_gate_prompts(index);
    }
}

function open_bulkhead()
{
    // The caulk collision mover stays solid until the opening animation ends.
    visuals=GetEntArray("egg_gate_visual_"+self.egg_gate_index,"targetname");
    foreach (visual in visuals) if (DistanceSquared(visual.origin,self.origin)<4)
    {
        visual PlaySound("egg_bulkhead");
        visual MoveZ(272,0.9,0.15,0.2);
        self.egg_visual=visual;
    }
    wait(0.95);
    self ConnectPaths();
    if (IsDefined(self.egg_visual)) self.egg_visual Delete();
    self Delete();
}

// Closed doors must not let the player enter a disabled zone. This fallback
// returns a rare clipping/teleport breach to safe ground instead of Sam-killing
// the player. Damage and stock out-of-bounds checks elsewhere remain enabled.
function locked_boundary()
{
    for(i=0;i<5;i++)if(!level.egg_gate_open[i])return 768+i*1536-24;
    return 100000;
}
function recover_locked_boundary()
{
    if(!IsAlive(self))return false;
    limit=locked_boundary();pos=self.origin;
    if(pos[0]<=limit || pos[0]>8448 || Abs(pos[1])>752 || pos[2]<-32 || pos[2]>320)return false;
    safe=self.egg_door_safe_origin;
    if(!IsDefined(safe) || safe[0]>limit-24)safe=(limit-40,384,16);
    self SetOrigin(safe);self SetVelocity((0,0,0));self.egg_gate_recoveries++;self.egg_door_recovered_at=GetTime();
    if(!IsDefined(self.egg_door_hint_after) || GetTime()>self.egg_door_hint_after)
    {
        self.egg_door_hint_after=GetTime()+1500;
        self IPrintLnBold("^3Door locked ^7- buy the door to enter");
    }
    return true;
}
function door_boundary_guard()
{
    self endon("disconnect");self endon("death");self endon("egg_new_life");
    for(;;)
    {
        self recover_locked_boundary();pos=self.origin;
        if(pos[0]<=locked_boundary()-24 && pos[0]>=-720 && Abs(pos[1])<720 && pos[2]>=0 && pos[2]<120)
            self.egg_door_safe_origin=pos;
        wait(.05);
    }
}
function door_area_safety()
{
    if(self recover_locked_boundary())return false;
    // The guard may have restored the player after the stock check sampled
    // their position. Reject that stale lethal decision only on safe ground.
    if(IsDefined(self.egg_door_recovered_at) && GetTime()-self.egg_door_recovered_at<1000 && self zm::in_enabled_playable_area())return false;
    if(IsDefined(level.egg_previous_area_check))return self [[level.egg_previous_area_check]]();
    return true;
}

function perk_spare_change()
{
    wait(2);
    machines=struct::get_array("zm_perk_machine","targetname");
    foreach (machine in machines) machine.egg_change_claimed=false;
    while (true)
    {
        foreach (machine in machines)
        {
            if (machine.egg_change_claimed) continue;
            foreach (player in GetPlayers())
            {
                if (!IsAlive(player) || player GetStance()!="prone") continue;
                if (DistanceSquared(player.origin,machine.origin)>115*115) continue;
                machine.egg_change_claimed=true;
                player zm_score::add_to_player_score(100,false);
                player PlaySound("egg_purchase");
                player IPrintLn("^3Spare change! ^7+100");
                break;
            }
        }
        wait(0.15);
    }
}

function close_gate_prompts(index)
{
    wait(0.05);
    triggers=GetEntArray("egg_gate_use", "targetname");
    foreach (trigger in triggers)
    {
        if (trigger.script_int == index) trigger Delete();
    }
}

function box_collisions()
{
    clips = GetEntArray("egg_box_collision", "targetname");
    foreach (clip in clips)
    {
        // A clip-only brush mover has no drawable surfaces. Hide its fallback
        // render model explicitly; visibility is independent of Solid().
        clip Hide();
        clip NotSolid();
    }
    while (!IsDefined(level.chests)) wait(0.1);
    foreach (clip in clips) clip thread box_collision_think();
}

function box_collision_think()
{
    chest = undefined;
    foreach (candidate in level.chests)
    {
        if (candidate.script_noteworthy == self.script_string) { chest = candidate; break; }
    }
    if (!IsDefined(chest)) return;
    self.egg_solid = false;
    idle_ticks=0;
    while (true)
    {
        active = IsDefined(chest.hidden) && !chest.hidden;
        // The stock pre-streaming proxy is never the offered reward.
        if (IsDefined(chest.locked_model)) chest.locked_model Hide();
        if (IsDefined(chest.pandora_light)) chest.pandora_light Hide();
        if (active != self.egg_solid)
        {
            self.egg_solid = active;
            if (active) { self Solid(); self DisconnectPaths(); }
            else { self NotSolid(); self ConnectPaths(); }
        }
        // A reward belongs above an OPEN chest. Clean up orphaned reward models
        // only after the stock close animation and use interaction have ended.
        idle=true;
        if (IsDefined(chest._box_open)) idle=!chest._box_open;
        if (idle && !IsDefined(chest.chest_user)) idle_ticks++;
        else idle_ticks=0;
        if (idle_ticks>=15 && IsDefined(chest.zbarrier))
        {
            if (IsDefined(chest.zbarrier.weapon_model)) chest.zbarrier.weapon_model Delete();
            if (IsDefined(chest.zbarrier.weapon_model_dw)) chest.zbarrier.weapon_model_dw Delete();
            chest.zbarrier HideZBarrierPiece(3);
            chest.zbarrier HideZBarrierPiece(4);
            kept=[];
            foreach (record in level.egg_reward_models)
            {
                if (!IsDefined(record.model)) continue;
                if (record.barrier==chest.zbarrier) record.model Delete();
                else kept[kept.size]=record;
            }
            level.egg_reward_models=kept;
            // Also catch an unreferenced build-kit proxy left by the stock
            // streaming code. Player weapons are not script_model entities.
            foreach (model in GetEntArray("script_model","classname"))
            {
                if (DistanceSquared(model.origin,chest.origin)>150*150) continue;
                name=model.model;
                if (IsDefined(name) && name.size>=4 && GetSubStr(name,0,4)=="wpn_") model Hide();
            }
        }
        wait(0.1);
    }
}

function track_box_reward(weapon)
{
    if (IsDefined(level.egg_original_box_spawned)) self thread [[level.egg_original_box_spawned]](weapon);
    wait(0.3);
    if (!IsDefined(self)) return;
    if (IsDefined(self.weapon_model))
    {
        record=SpawnStruct(); record.barrier=self; record.model=self.weapon_model;
        level.egg_reward_models[level.egg_reward_models.size]=record;
    }
    if (IsDefined(self.weapon_model_dw))
    {
        record=SpawnStruct(); record.barrier=self; record.model=self.weapon_model_dw;
        level.egg_reward_models[level.egg_reward_models.size]=record;
    }
}

function upgrade_name(tier)
{
    switch (tier)
    {
        case 1: return "Shellcracker";
        case 2: return "Yolk Storm";
        case 3: return "Golden Hatch";
    }
    return "Egg Upgrade";
}

function upgrade_cost(tier)
{
    switch (tier)
    {
        case 1: return 2500;
        case 2: return 7500;
        case 3: return 15000;
    }
    return 0;
}

function upgrade_description(tier)
{
    if (tier==1) return "1.5x bullet damage + nearby shell burst";
    if (tier==2) return "2.5x bullet damage + stronger chain burst";
    return "5x bullet damage + golden chain burst";
}

function upgrade_terminal()
{
    tier = self.script_int;
    cost = upgrade_cost(tier);
    self SetCursorHint("HINT_NOICON");
    self set_hint("[{+activate}] " + upgrade_name(tier) + " [" + cost + "] - " + upgrade_description(tier));
    while (true)
    {
        self waittill("trigger", player);
        if (!IsDefined(player) || !IsPlayer(player) || !IsAlive(player)) continue;
        if (!accept_use(player)) continue;
        if (!IsDefined(player.egg_tier)) continue;
        if (player.egg_tier != tier - 1)
        {
            if (player.egg_tier>=tier) player IPrintLnBold("Already owned this life - no points charged");
            else player IPrintLnBold("Buy the previous egg upgrade first");
            continue;
        }
        if (!IsDefined(player.score) || player.score < cost)
        {
            player IPrintLnBold("You need " + cost + " points");
            continue;
        }
        player.egg_tier = tier;
        player zm_score::minus_to_player_score(cost);
        player clientfield::set_to_player("egg_upgrade_tier",tier);
        player thread upgrade_celebration(tier,self.origin);

    }
}

function admin_terminal()
{
    self SetCursorHint("HINT_NOICON");
    self set_hint("[{+activate}] Setup: Eggmin Cannon on/off (host, before starting)");
    while (true)
    {
        self waittill("trigger", player);
        if (!IsDefined(player) || !IsPlayer(player) || !IsAlive(player) || !player IsHost()) continue;
        if (!accept_use(player)) continue;
        if (!IsDefined(player.egg_admin_active)) continue;
        if (level.egg_mode_ready)
        { player IPrintLnBold("Setup locked - restart to change your loadout"); continue; }
        player.egg_admin_active = !player.egg_admin_active;
        if (player.egg_admin_active)
        {
            level.egg_admin_used = true;
            // Own automatic weapon: 150-round magazine, rapid fire and PAP camo.
            player.egg_admin_weapon = GetWeapon("eggmin_cannon");
            if (!player HasWeapon(player.egg_admin_weapon))
                player GiveWeapon(player.egg_admin_weapon,player CalcWeaponOptions(zm_weapons::get_pack_a_punch_camo_index(undefined),0,0));
            player GiveMaxAmmo(player.egg_admin_weapon);
            player SetWeaponAmmoClip(player.egg_admin_weapon,player.egg_admin_weapon.clipSize);
            player SwitchToWeapon(player.egg_admin_weapon);
            player IPrintLnBold("^3EGGMIN CANNON ON ^7- rapid fire / unlimited ammo");
        }
        else player IPrintLnBold("Eggmin Cannon OFF");
    }
}

function crosshair_terminal()
{
    self SetCursorHint("HINT_NOICON");
    self set_hint("[{+activate}] Setup: crosshair (default / cyan dot / gold cross)");
    while (true)
    {
        self waittill("trigger",player);
        if (!IsDefined(player) || !IsPlayer(player)) continue;
        if (!accept_use(player)) continue;
        if (level.egg_mode_ready) { player IPrintLnBold("Reticle locked until restart"); continue; }
        player.egg_crosshair=(player.egg_crosshair+1)%3;
        player clientfield::set_to_player("egg_reticle_mode",player.egg_crosshair);
        player PlaySound("egg_purchase");
        if (player.egg_crosshair==0) player IPrintLn("Default crosshair selected");
        if (player.egg_crosshair==1) player IPrintLn("^5CYAN DOT selected");
        if (player.egg_crosshair==2) player IPrintLn("^3GOLD CROSS selected");
    }
}

function crosshair_display()
{
    self endon("disconnect");
    self endon("egg_new_life");
    hud=NewClientHudElem(self);
    hud.horzAlign="center"; hud.vertAlign="middle";
    hud.alignX="center"; hud.alignY="middle";
    hud.fontScale=1.2; hud.alpha=0;
    self.egg_crosshair_hud=hud;
    hud.hideWhenDead=true; hud.hideWhenInMenu=true;
    while (IsAlive(self))
    {
        hud.alpha=0;
        if (self.egg_crosshair>0 && self PlayerADS()<0.2)
        {
            hud.alpha=0.9;
            if (self.egg_crosshair==1) { hud.color=(0.2,0.9,1); hud SetText("."); }
            else { hud.color=(1,0.8,0.2); hud SetText("+"); }
        }
        wait(0.1);
    }
    hud Destroy();
}

function admin_ammo()
{
    self endon("disconnect");
    self endon("death");
    self endon("egg_new_life");
    while (true)
    {
        if (self IsHost() && IsDefined(self.egg_admin_active) && self.egg_admin_active && IsDefined(self.egg_admin_weapon))
        {
            weapon = self.egg_admin_weapon;
            foreach (held_weapon in self GetWeaponsList(true))
            {
                if (held_weapon.rootweapon!=weapon.rootweapon) continue;
                self SetWeaponAmmoClip(held_weapon, held_weapon.clipSize);
                self SetWeaponAmmoStock(held_weapon, 120);
            }
        }
        wait(0.1);
    }
}

function zombie_damage(mod, hit_location, hit_origin, player, amount, weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel)
{
    // Include shotguns, energy weapons and their impacts. A second scripted
    // hit uses a distinct MOD so it cannot recursively multiply itself.
    if (mod=="MOD_TRIGGER_HURT" || mod=="MOD_MELEE" || mod=="MOD_FALLING" || mod=="MOD_SUICIDE") return false;
    if (!IsDefined(player) || !IsPlayer(player) || !IsDefined(weapon)) return false;
    player.egg_last_damage_mod=mod;
    player.egg_last_damage_weapon=weapon.name;
    if (player IsHost() && IsDefined(player.egg_admin_active) && player.egg_admin_active && IsDefined(player.egg_admin_weapon) && weapon.rootweapon == player.egg_admin_weapon.rootweapon)
    {
        self thread admin_hit(player, weapon);
        return false;
    }
    if (!IsDefined(player.egg_tier) || player.egg_tier < 1) return false;
    tier = player.egg_tier;
    player.egg_bonus_hits++;
    multiplier = 1.5;
    if (tier == 2) multiplier = 2.5;
    if (tier == 3) multiplier = 5;
    self thread bonus_hit(player, weapon, Int(amount * (multiplier - 1)));
    if (GetTime() < player.egg_proc_after) return false;
    player.egg_proc_after = GetTime() + 1000;
    self thread shell_burst(player, weapon, tier);
    return false;
}

function bonus_hit(player, weapon, amount)
{
    self endon("death");
    wait(0.01);
    if (IsDefined(player) && IsAlive(self) && amount > 0)
        self DoDamage(amount, player.origin, player, player, "none", "MOD_TRIGGER_HURT", 0, weapon);
}

function admin_hit(player, weapon)
{
    centre = self.origin;
    level thread spark_pulse(centre+(0,0,40));
    if (IsDefined(self.health) && IsAlive(self)) self thread bonus_hit(player, weapon, self.health + 1);
    enemies = GetAIArray("zombie", "targetname");
    foreach (enemy in enemies)
    {
        if (enemy == self || !IsAlive(enemy) || DistanceSquared(enemy.origin, centre) > 256 * 256) continue;
        if (!BulletTracePassed(centre + (0,0,40), enemy.origin + (0,0,40), false, self, enemy)) continue;
        enemy thread bonus_hit(player, weapon, enemy.health + 1);
    }
}

function shell_burst(player, weapon, tier)
{
    centre = self.origin;
    level thread spark_pulse(centre+(0,0,40));
    self PlaySound("egg_shellburst");

    max_targets = 3;
    damage = 100;
    radius = 192;
    if (tier >= 2) { damage = 600; radius = 256; }
    if (tier >= 3) { damage = 1800; max_targets = 5; }
    count = 0;
    enemies = GetAIArray("zombie", "targetname");
    foreach (enemy in enemies)
    {
        if (enemy == self || !IsAlive(enemy) || DistanceSquared(enemy.origin, centre) > radius * radius) continue;
        if (!BulletTracePassed(centre + (0,0,40), enemy.origin + (0,0,40), false, self, enemy)) continue;
        enemy thread bonus_hit(player, weapon, damage);
        count++;
        if (count >= max_targets) break;
    }
}

function game_over_options()
{
    if (!level.egg_run_reported && level.egg_mode_ready)
    {
        record_run("end");
        level.egg_run_reported=true;
    }
    if (IsDefined(level.egg_original_end_screen)) level [[level.egg_original_end_screen]]();
    level.egg_gameover_active=true;
    host=undefined;
    players=GetPlayers();
    foreach (player in players) if (player IsHost()) host=player;
    if (!IsDefined(host)) return;
    huds=[];
    foreach (player in players)
    {
        player.egg_crosshair=0;
        player clientfield::set_to_player("egg_upgrade_tier",0);
        player clientfield::set_to_player("egg_reticle_mode",0);
        panel=NewClientHudElem(player);
        panel.horzAlign="center"; panel.vertAlign="middle";
        panel.alignX="center"; panel.alignY="middle";
        panel.y=70; panel.color=(0.025,0.035,0.05); panel.alpha=0.88;
        panel.foreground=true; panel.sort=98; panel.hideWhenDead=false;
        panel SetShader("white",420,150);
        huds[huds.size]=panel;
        huds[huds.size]=end_screen_line(player,"THE SHELL HAS CRACKED",8,(1,0.75,0.2),1.6);
        huds[huds.size]=end_screen_line(player,"Round "+level.round_number+"  |  "+level.egg_mode,34,(1,1,1),1.2);
        message="Host chooses restart or lobby";
        if (player==host) message="[{+activate}] RESTART IN 3 SECONDS";
        hud=end_screen_line(player,message,66,(0.2,0.9,1),1.3);
        player.egg_restart_hud=hud;huds[huds.size]=hud;
        if (player==host)
        {
            huds[huds.size]=end_screen_line(player,"[{+reload}] INSTANT RESTART",94,(0.4,1,0.4),1.3);
            huds[huds.size]=end_screen_line(player,"[{+melee}] RETURN TO LOBBY",122,(0.85,0.85,0.85),1.2);
        }
    }
    // Ignore a held action from the final moments of play; require a fresh press.
    wait(0.25);
    ready=false;
    for (tick=0; tick<6000; tick++)
    {
        if (!IsDefined(host)) break;
        use=host UseButtonPressed();
        reload=host ReloadButtonPressed();
        melee=host MeleeButtonPressed();
        if (!use && !reload && !melee) ready=true;
        if (ready && use) request_restart(host,false);
        if (ready && reload) request_restart(host,true);
        if (ready && melee) break;
        wait(0.05);
    }
    foreach (hud in huds) if (IsDefined(hud)) hud Destroy();
    level.zombie_vars["zombie_intermission_time"]=0;
    level.egg_gameover_active=false;
}

function end_screen_line(player,message,y,colour,size)
{
    hud=NewClientHudElem(player);
    hud.horzAlign="center";hud.vertAlign="middle";
    hud.alignX="center";hud.alignY="middle";hud.y=y;
    hud.color=colour;hud.fontScale=size;hud.alpha=1;
    hud.foreground=true;hud.sort=100;
    hud.hideWhenDead=false;hud.hideWhenInMenu=false;
    hud SetText(message);
    return hud;
}

function record_run(event)
{
    // Local match log only. The optional companion uploads the signed-in host's
    // result; this map never contacts a website or publishes player data itself.
    host=undefined;
    foreach (player in GetPlayers()) if (player IsHost()) host=player;
    if (!IsDefined(host)) return;
    elapsed=0;
    if (level.egg_run_started>0) elapsed=Int(Max(0,(GetTime()-level.egg_run_started)/1000));
    assisted=0;
    if (level.egg_admin_used || IsDefined(level.egg_selftest_mode)) assisted=1;
    host_id=host GetXUID(true);
    ClientPrint(host,"EGGSTAT1|"+event+"|"+level.egg_mode+"|"+level.round_number+"|"+elapsed+"|"+assisted+"|"+GetPlayers().size+"|"+host_id);
}

function request_restart(host,instant)
{
    if (!IsDefined(host) || !host IsHost() || !level.egg_gameover_active || level.egg_restart_pending) return false;
    level.egg_restart_pending=true;
    if (IsDefined(level.egg_selftest_mode) && level.egg_selftest_mode == "restart")
        IPrintLn("EGGRESTART REQUEST instant="+instant);
    if (!instant)
    {
        for (seconds=3; seconds>0; seconds--)
        {
            foreach (player in GetPlayers())
                if (IsDefined(player.egg_restart_hud)) player.egg_restart_hud SetText("RESTARTING IN "+seconds+" - fresh setup next run");
            wait(1);
        }
    }
    Map_Restart(false);
    wait(666);
    return true;
}

// Explicit development-only integration check. Normal launches leave this off.
function smoke_check(name, passed)
{
    if (passed) test_log("EGGTEST PASS: " + name);
    else test_log("EGGTEST FAIL: " + name);
}

function test_log(message)
{
    // Keep message construction outside the dev block: BO3 omits literal
    // strings declared inside disabled developer string tables.
    /#
    PrintLn(message);
    #/
}

function smoke_test()
{
    self endon("disconnect");
    self EnableInvulnerability();
    wait(5);
    level flag::wait_till("initial_blackscreen_passed");
    wait(2);
    if (level.egg_selftest_mode=="gums") {self native_gum_test();return;}
    if (level.egg_selftest_mode=="polish") {self polish_test();return;}
    if (level.egg_selftest_mode=="boxfix")
    {
        self box_fix_test();
        return;
    }
    if (level.egg_selftest_mode=="idle")
    {
        self SetOrigin((-320,-400,24));self SetPlayerAngles((5,270,0));
        foreach (ent in GetEntArray())
        {
            if (!IsDefined(ent.origin) || DistanceSquared(ent.origin,(-320,-690,50))>200*200) continue;
            description="EGGIDLE ENTITY at "+ent.origin;
            if (IsDefined(ent.classname)) description=description+" class="+ent.classname;
            if (IsDefined(ent.model)) description=description+" model="+ent.model;
            test_log(description);
        }
        wait(10);
        foreach (chest in level.chests)
        {
            count=chest.zbarrier GetNumZBarrierPieces();
            test_log("EGGIDLE native pieces="+count);
            chest.zbarrier SetWeapon(level.weaponNone);
            for (piece=3;piece<count;piece++) chest.zbarrier HideZBarrierPiece(piece);
        }
        IPrintLn("EGGIDLE native display cleared - inspect now");
        return;
    }
    if (level.egg_selftest_mode=="box")
    {
        choose_mode("easy");
        self final_targeted_test();
        self room_review();
        return;
    }
    if (level.egg_selftest_mode=="review")
    {
        self review_test();
        return;
    }
    if (level.egg_selftest_mode=="repair")
    {
        self repair_test();
        return;
    }
    if (level.egg_selftest_mode=="special")
    {
        wait(2);
        weapon_sound_audit();
        map_sound_audit();
        choose_mode("easy");
        self thread audit_protection();
        saw_dog=false; saw_warden=false; saw_six=false;
        for (tick=0;tick<1800;tick++)
        {
            foreach (dog in GetEntArray("zombie_dog","targetname"))
            {
                if (!saw_dog)
                {
                    smoke_check("native dog AI spawns on round five",level.round_number==5 && level flag::get("dog_round"));
                    saw_dog=true;
                }
            }
            if (level.round_number==6 && !saw_six)
            {
                // Round number changes during the intermission; the stock dog
                // tracker restores the spawn function at between_round_over.
                for (transition=0;transition<100;transition++)
                {
                    if (!level flag::get("dog_round")) break;
                    wait(0.2);
                }
                smoke_check("round six restores normal zombies",!level flag::get("dog_round"));
                saw_six=true;
            }
            foreach (enemy in GetAIArray())
            {
                if (IsDefined(enemy.egg_warden) && !saw_warden)
                {
                    smoke_check("Egg Warden appears on round seven",level.round_number==7 && enemy.maxhealth>1000);
                    saw_warden=true;
                    wait(3);
                }
                if (IsAlive(enemy)) enemy DoDamage(enemy.health+1,self.origin,self,self,"none","MOD_TRIGGER_HURT",0,GetWeapon("pistol_burst"));
            }
            if (level.round_number>=8) break;
            wait(0.25);
        }
        smoke_check("dog round observed",saw_dog);
        smoke_check("Egg Warden observed",saw_warden);
        IPrintLn("EGGSPECIAL COMPLETE");
        // The visual tour visits later rooms; unlock them first so the native
        // zone protection does not eliminate a player teleported past a gate.
        for (i=0;i<5;i++)
        {
            level.egg_gate_open[i]=true;
            foreach (door in GetEntArray("egg_gate_"+i,"targetname")) { door ConnectPaths(); door Delete(); }
            level flag::set("egg_open_"+i);
        }
        wait(1);
        self audit_view("Shellcracker console",(3072,-350,24),(-5,270,0));
        self audit_view("Setup hub",(80,-330,24),(-5,270,0));
        self audit_view("Factory machinery",(1536,-250,24),(-5,300,0));
        return;
    }
    if (level.egg_selftest_mode == "restart")
    {
        wait(5);
        stage=GetDvarInt("egg_restart_probe");
        if (stage > 0)
        {
            smoke_check("restart resets round", level.round_number == 1);
            smoke_check("restart closes doors", !level.egg_gate_open[0]);
            smoke_check("restart clears upgrades and admin gun", self.egg_tier == 0 && !self.egg_admin_active);
            smoke_check("restart restores default crosshair",self.egg_crosshair==0);
            smoke_check("restart offers difficulty again", !level.egg_mode_ready);
            IPrintLn("EGGRESTART FRESH stage="+stage);
        }
        if (stage >= 2)
        {
            self SetOrigin((-320,-400,24));
            self SetPlayerAngles((5,270,0));
            foreach (ent in GetEntArray())
            {
                if (!IsDefined(ent.origin) || DistanceSquared(ent.origin,(-320,-690,50))>200*200) continue;
                description="EGGIDLE ENTITY at "+ent.origin;
                if (IsDefined(ent.classname)) description=description+" class="+ent.classname;
                if (IsDefined(ent.model)) description=description+" model="+ent.model;
                test_log(description);
            }
            IPrintLn("EGGRESTART COMPLETE");
            return;
        }
        if (stage == 0)
        {
            map_sound_audit();
            foreach (chest in level.chests)
            {
                hit=PlayerPhysicsTrace(chest.origin+(-100,0,32),chest.origin+(100,0,32));
                active=IsDefined(chest.hidden) && !chest.hidden;
                blocked=DistanceSquared(hit,chest.origin+(100,0,32))>1;
                smoke_check("hidden box clip collision "+chest.script_noteworthy,blocked==active);
            }
            self SetOrigin((-320,-400,24));
            self SetPlayerAngles((5,270,0));
            IPrintLn("EGGPHOTO idle spawn box before round start");
            wait(20);
            self SetOrigin((-320,0,24));
            self SetPlayerAngles((-5,180,0));
            IPrintLn("EGGPHOTO hologram choices");
            wait(10);
        }
        if (stage==0)
        {
            smoke_check("setup stays on round one before starting",level.round_number==1);
            self zm_score::add_to_player_score(100,false);
        }
        choose_mode("medium");
        if (stage == 0)
        {
            IPrintLn("EGGPHOTO hologram selected");
            wait(10);
            smoke_check("difficulty bonus preserves points earned in setup",self.score==850);
        }
        else wait(1);
        if (stage == 0)
        {
            for (i=0; i<5; i++)
            {
                level.egg_gate_open[i]=true;
                doors=GetEntArray("egg_gate_"+i, "targetname");
                foreach (door in doors) { door ConnectPaths(); door Delete(); }
                level flag::set("egg_open_"+i);
            }
            wait(1);
            test_box=undefined;
            foreach (chest in level.chests)
                if (IsDefined(chest.hidden) && !chest.hidden) { test_box=chest; break; }
            if (IsDefined(test_box))
            {
                level.CustomRandomWeaponWeights=&box_garand_test_weights;
                self zm_score::add_to_player_score(5000,false);
                self SetOrigin(test_box.origin+(0,110,24));
                test_box notify("trigger",self);
                wait(8);
                smoke_check("box reward survives the idle cleanup guard while offered",IsDefined(test_box.grab_weapon) && IsDefined(test_box.zbarrier.weapon_model));
                wait(25);
                smoke_check("timed-out box closes",!test_box._box_open);
                smoke_check("closed box has no floating reward",!IsDefined(test_box.zbarrier.weapon_model));
                test_box notify("trigger",self);
                wait(8);
                self.egg_box_captured=false;
                self thread capture_box_collection();
                wait(0.1);
                for (attempt=0;attempt<6;attempt++)
                {
                    if (self.egg_box_captured) break;
                    test_box notify("trigger",self);
                    wait(0.5);
                }
                for (attempt=0;attempt<30;attempt++)
                {
                    if (self HasWeapon(GetWeapon("ar_garand"),true)) break;
                    wait(0.1);
                }
                smoke_check("Garand reward collected through native box",self HasWeapon(GetWeapon("ar_garand"),true));
                foreach (held in self GetWeaponsList(true)) test_log("EGGINVENTORY "+held.name);
                self notify("egg_box_capture_end");
                level.CustomRandomWeaponWeights=undefined;
                wait(8);
                smoke_check("collected box closes",!test_box._box_open);
                smoke_check("collected box leaves no floating reward",!IsDefined(test_box.zbarrier.weapon_model));
            }
        }
        self.egg_tier=3;
        self.egg_admin_active=true;
        self.egg_crosshair=2;
        self clientfield::set_to_player("egg_reticle_mode",2);
        wait(2);
        SetDvar("egg_restart_probe",stage+1);
        self DisableInvulnerability();
        wait(0.25);
        self.health=1;
        // Use the stock Zombies elimination path; ordinary Suicide is denied
        // by this gametype's canPlayerSuicide callback.
        self.lives=0;
        self.bleedout_time=0;
        self DoDamage(self.health+1000,self.origin);
        IPrintLn("EGGRESTART READY stage="+stage);
        return;
    }
    if (level.egg_selftest_mode == "audit")
    {
        self.ignoreme=true;
        wait(5);
        choose_mode("easy");
        // Open the inspected zones before teleporting into them.
        for (i=0; i<5; i++)
        {
            level.egg_gate_open[i]=true;
            doors=GetEntArray("egg_gate_"+i, "targetname");
            foreach (door in doors) { door ConnectPaths(); door Delete(); }
            level flag::set("egg_open_"+i);
        }
        self thread audit_protection();
        power=GetEnt("use_elec_switch", "targetname");
        if (IsDefined(power)) power notify("trigger", self);
        while (true)
        {
            self audit_view("Pack a Punch",(6144,-400,24),(-5,270,0));
            self audit_view("Quick Revive",(-400,450,24),(-5,90,0));
            self audit_view("Juggernog and Double Tap",(1536,350,24),(-5,90,0));
            self audit_view("Stamin Up",(2816,450,24),(-5,90,0));
            self audit_view("Speed Cola",(4352,450,24),(-5,90,0));
            self audit_view("Mule Kick and Deadshot",(6144,350,24),(-5,90,0));
            self audit_view("Spawn wall mystery box",(-320,-400,24),(-5,270,0));
            self audit_view("Room lettering",(1536,-160,24),(-20,270,0));
            self audit_view("Pack a Punch",(6144,-400,24),(-5,270,0));
            self audit_view("Power switch",(4864,-400,24),(-5,270,0));
        }
    }
    IPrintLn("EGGTEST BEGIN");
    weapon_sound_audit();
    map_sound_audit();
    wait(0.5);
    mode = level.egg_selftest_mode;
    if (mode != "medium" && mode != "hard") mode = "easy";
    setup_lockers=GetEntArray("egg_admin_use","targetname");
    setup_reticles=GetEntArray("egg_crosshair_use","targetname");
    setup_lockers[0] notify("trigger",self);
    wait(0.2);
    smoke_check("setup hub enables admin before starting",self.egg_admin_active);
    setup_lockers[0] notify("trigger",self);
    wait(0.2);
    setup_reticles[0] notify("trigger",self);
    wait(0.2);
    smoke_check("setup hub selects cyan reticle",self.egg_crosshair==1);
    terminals = GetEntArray("egg_difficulty", "targetname");
    foreach (terminal in terminals)
    {
        if (terminal.script_string == mode) { terminal notify("trigger", self); break; }
    }
    wait(2);
    smoke_check("difficulty selected " + mode, level.egg_mode_ready && level.egg_mode == mode);
    saved_test_mode=level.egg_selftest_mode;
    level.egg_selftest_mode=undefined;
    setup_lockers[0] notify("trigger",self);
    setup_reticles[0] notify("trigger",self);
    wait(0.2);
    smoke_check("admin setup locks when match starts",!self.egg_admin_active);
    smoke_check("reticle setup locks when match starts",self.egg_crosshair==1);
    level.egg_selftest_mode=saved_test_mode;
    smoke_check("starting points", self.score == level.egg_start_points);
    smoke_check("six initialized zones", GetArrayKeys(level.zones).size == 6);
    smoke_check("seven perk placements", struct::get_array("zm_perk_machine", "targetname").size == 7);
    smoke_check("three mystery boxes", IsDefined(level.chests) && level.chests.size == 3);
    foreach (chest in level.chests)
    {
        hit = PlayerPhysicsTrace(chest.origin + (-100,0,32), chest.origin + (100,0,32));
        active = IsDefined(chest.hidden) && !chest.hidden;
        blocked = DistanceSquared(hit, chest.origin + (100,0,32)) > 1;
        smoke_check("box collision " + chest.script_noteworthy, blocked == active);
    }
    self zm_score::add_to_player_score(100000, false);
    for (i = 0; i < 5; i++)
    {
        x=768+1536*i;
        before_trace=PlayerPhysicsTrace((x-100,384,48),(x+100,384,48));
        smoke_check("gate " + i + " blocks before purchase", DistanceSquared(before_trace,(x+100,384,48)) > 1);
        gates = GetEntArray("egg_gate_use", "targetname");
        foreach (gate in gates)
        {
            if (gate.script_int == i) { gate notify("trigger", self); break; }
        }
        wait(1.1);
        smoke_check("gate " + i + " opens both lanes", level.egg_gate_open[i] && GetEntArray("egg_gate_" + i, "targetname").size == 0);
        after_trace=PlayerPhysicsTrace((x-100,384,48),(x+100,384,48));
        smoke_check("gate " + i + " passage is clear", DistanceSquared(after_trace,(x+100,384,48)) < 1);
    }
    upgrades = GetEntArray("egg_upgrade_use", "targetname");
    for (attempt=0;attempt<30;attempt++)
    {
        if (GetAIArray("zombie","targetname").size>0) break;
        wait(1);
    }
    wait(5);
    for (tier = 1; tier <= 3; tier++)
    {
        before_score=self.score;
        foreach (upgrade in upgrades)
        {
            if (upgrade.script_int == tier) { upgrade notify("trigger", self); break; }
        }
        wait(0.2);
        smoke_check("upgrade " + tier, self.egg_tier == tier);
        smoke_check("upgrade "+tier+" charges exact price",self.score==before_score-upgrade_cost(tier));
        foreach (upgrade in upgrades)
            if (upgrade.script_int==tier) { upgrade notify("trigger",self); break; }
        wait(0.1);
        smoke_check("upgrade "+tier+" cannot charge twice",self.score==before_score-upgrade_cost(tier));
        enemies=GetAIArray("zombie","targetname");
        if (enemies.size>0)
        {
            target=enemies[0]; target.health=10000;
            self.egg_proc_after=0;
            target DoDamage(20,self.origin,self,self,"torso_upper","MOD_PISTOL_BULLET",0,GetWeapon("pistol_burst"));
            wait(0.2);
            expected=30;
            if (tier==2) expected=50;
            if (tier==3) expected=100;
            smoke_check("upgrade "+tier+" actual body bullet bonus",!IsDefined(target) || !IsAlive(target) || target.health<=10000-expected);
            smoke_check("upgrade "+tier+" body hit triggers burst",self.egg_proc_after>GetTime());
        }
        else smoke_check("upgrade "+tier+" actual body bullet bonus",false);
    }
    lockers = GetEntArray("egg_admin_use", "targetname");
    if (lockers.size > 0) lockers[0] notify("trigger", self);
    wait(1);
    smoke_check("host admin gun enabled", self.egg_admin_active && self HasWeapon(GetWeapon("eggmin_cannon"),true));
    smoke_check("admin ammunition", self GetWeaponAmmoClip(GetWeapon("eggmin_cannon")) > 0);
    // Round-one presentation can delay the first riser. Poll actual AI, bounded.
    for (attempt=0; attempt<30; attempt++)
    {
        if (GetAIArray("zombie", "targetname").size > 0) break;
        wait(1);
    }
    enemies = GetAIArray("zombie", "targetname");
    smoke_check("zombies spawn", enemies.size > 0);
    if (enemies.size > 0)
    {
        target = enemies[0];
        wait(5); // Allow the riser animation to finish before measuring navigation.
        self SetOrigin((1536,384,24)); // Require pursuit through the opened doors.
        moved=false;
        for (attempt=0; attempt<5; attempt++)
        {
            before = target.origin;
            wait(2);
            if (IsDefined(target) && DistanceSquared(target.origin, before) > 4) { moved=true; break; }
        }
        smoke_check("zombie navigation moves AI", moved);
        if (IsDefined(target) && IsAlive(target))
        {
            target DoDamage(1, self.origin, self, self, "torso_upper", "MOD_PISTOL_BULLET", 0, GetWeapon("eggmin_cannon"));
            wait(0.5);
            smoke_check("admin shot kills zombie", !IsDefined(target) || !IsAlive(target));
        }
    }
    if (lockers.size > 0) lockers[0] notify("trigger", self);
    wait(0.2);
    smoke_check("host admin gun disabled", !self.egg_admin_active);
    enemies=GetAIArray("zombie", "targetname");
    if (enemies.size > 0)
    {
        target=enemies[0];
        before_health=target.health;
        target DoDamage(4, self.origin, self, self, "torso_upper", "MOD_PISTOL_BULLET", 0, GetWeapon("pistol_burst"));
        wait(0.3);
        smoke_check("Golden Hatch increases bullet damage", !IsDefined(target) || !IsAlive(target) || target.health <= before_health-20);
    }
    // Exercise the stock interaction threads, not alternate give-weapon/perk code.
    power = GetEnt("use_elec_switch", "targetname");
    if (IsDefined(power)) power notify("trigger", self);
    wait(3);
    smoke_check("power switch", level flag::get("power_on"));
    machines = GetEntArray("zombie_vending", "targetname");
    foreach (machine in machines)
    {
        self SetOrigin(machine.origin + (0,-85,0));
        self SetStance("stand");
        wait(0.3);
        before_score=self.score;
        self SetStance("prone");
        wait(0.6);
        smoke_check("perk prone bonus "+machine.script_noteworthy,self.score==before_score+100);
        wait(0.4);
        smoke_check("perk prone bonus cannot repeat "+machine.script_noteworthy,self.score==before_score+100);
        self SetStance("stand");
        self SetOrigin(machine.origin + (0,-96,24));
        machine notify("trigger", self);
        wait(4);
        smoke_check("perk purchase " + machine.script_noteworthy, self HasPerk(machine.script_noteworthy));
    }
    self SetOrigin((1400,-600,24));
    wait(0.5);
    active_box = undefined;
    foreach (chest in level.chests)
    {
        if (IsDefined(chest.hidden) && !chest.hidden) { active_box=chest; break; }
    }
    if (IsDefined(active_box))
    {
        self SetOrigin(active_box.origin + (0,110,24));
        active_box notify("trigger", self);
        wait(8);
        smoke_check("mystery box rolls a weapon", IsDefined(active_box.grab_weapon));
        if (IsDefined(active_box.grab_weapon))
        {
            reward = active_box.zbarrier.weapon;
            IPrintLn("EGGTEST BOX REWARD " + reward.name);
            self.egg_box_captured=false;
            self thread capture_box_collection();
            wait(0.25); // Let the stock box finish registering its pickup trigger.
            for (attempt=0; attempt<6; attempt++)
            {
                if (self.egg_box_captured) break;
                active_box notify("trigger", self);
                wait(0.5);
            }
            for (attempt=0;attempt<30;attempt++)
            {
                if (self has_weapon_named(reward.name)) break;
                wait(0.1);
            }
            smoke_check("mystery box pickup accepted", self.egg_box_captured);
            smoke_check("mystery box weapon collected", self has_weapon_named(reward.name));
            self notify("egg_box_capture_end");
        }
    }
    pap = zm_pap_util::get_triggers();
    smoke_check("Pack-a-Punch machine initialized", pap.size == 1);
    if (pap.size > 0)
    {
        self GiveWeapon(GetWeapon("pistol_burst"));
        self SwitchToWeapon(GetWeapon("pistol_burst"));
        self SetOrigin(pap[0].origin + (0,100,24));
        wait(1);
        pap[0] notify("trigger", self);
        wait(7);
        smoke_check("Pack-a-Punch processes weapon", IsDefined(pap[0].upgrade_weapon));
        if (IsDefined(pap[0].upgrade_weapon))
        {
            upgraded=pap[0].upgrade_weapon;
            pap[0] notify("trigger", self);
            wait(1);
            smoke_check("Pack-a-Punch upgraded weapon collected", self HasWeapon(upgraded));
        }
    }
    self SetOrigin((-320,-144,24));
    test_weapon = self GetCurrentWeapon();
    self SetWeaponAmmoStock(test_weapon, 0);
    pickup = zm_powerups::specific_powerup_drop("full_ammo", self.origin, self.team);
    wait(2);
    smoke_check("Max Ammo drop collected", self GetWeaponAmmoStock(test_weapon) > 0);
    pickup = zm_powerups::specific_powerup_drop("insta_kill", self.origin, self.team);
    wait(1);
    smoke_check("Insta-Kill pickup", level.zombie_vars[self.team]["zombie_insta_kill"] == 1);
    pickup = zm_powerups::specific_powerup_drop("double_points", self.origin, self.team);
    wait(1);
    smoke_check("Double Points pickup", level.zombie_vars[self.team]["zombie_point_scalar"] == 2);
    IPrintLn("EGGTEST AI COUNT " + GetAIArray().size + " / zombie count " + GetAIArray("zombie", "targetname").size + " / round " + level.round_number);
    IPrintLn("EGGTEST COMPLETE " + mode);
    enemies=GetAIArray("zombie","targetname");
    if (enemies.size>0)
    {
        target=enemies[0];
        level.round_number=7;
        level.egg_warden_round=-1;
        target zombie_spawned();
        self SetOrigin((-200,-240,24));
        self SetPlayerAngles(VectorToAngles((target.origin+(0,0,55))-(self.origin+(0,0,60))));
        IPrintLn("EGGPHOTO Egg Warden health bar");
        wait(15);
    }
    // A test build stays safe for the visual audit; ordinary builds never enter here.
    self SetOrigin((1280,450,24));
    self SetPlayerAngles((-5,90,0));
    IPrintLn("EGGTEST VISUAL perk front");
    wait(20);
    self SetOrigin((1536,-160,24));
    self SetPlayerAngles((-20,270,0));
    IPrintLn("EGGTEST VISUAL room sign");
    wait(20);
    self SetOrigin((-500,-384,24));
    self SetPlayerAngles((-4,18,0));
    IPrintLn("EGGTEST VISUAL nest and gates");
    wait(20);
    self SetOrigin((-320,0,24));
    self SetPlayerAngles((-5,180,0));
    IPrintLn("EGGTEST VISUAL hologram selectors");
    record_run("end");
}

function has_weapon_named(name)
{
    return self HasWeapon(GetWeapon(name),true);
}

function box_garand_test_weights(keys)
{
    result=[];
    result[0]=GetWeapon("ar_garand");
    return result;
}

function capture_box_collection()
{
    self endon("disconnect");
    self endon("egg_box_capture_end");
    self waittill("user_grabbed_weapon");
    self.egg_box_captured=true;
}

function audit_view(label, position, angles)
{
    self SetOrigin(position);
    self SetPlayerAngles(angles);
    IPrintLn("EGGPHOTO " + label);
    wait(15);
}

function audit_protection()
{
    self endon("disconnect");
    self endon("egg_restart_stop_protection");
    while (true)
    {
        self EnableInvulnerability();
        self.health=100000;
        wait(0.1);
    }
}

function audit_clear_ai()
{
    self endon("disconnect");
    while (true)
    {
        level.zombie_total=0;
        enemies=GetAIArray("zombie", "targetname");
        foreach (enemy in enemies)
            if (IsAlive(enemy)) enemy DoDamage(enemy.health+1, self.origin, self, self, "none", "MOD_TRIGGER_HURT", 0, GetWeapon("pistol_burst"));
        wait(0.5);
    }
}
