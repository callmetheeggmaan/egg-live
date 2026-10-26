#using scripts\shared\callbacks_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\system_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_powerups;
#using scripts\zm\egg_live_fun;
#using scripts\zm\egg_live_party;
#insert scripts\shared\shared.gsh;
#namespace egg_live;
REGISTER_SYSTEM("egg_live", &init, undefined)

function init()
{
    callback::on_spawned(&spawned);
    egg_live_fun::init();
}
function spawned()
{
    if(!self IsHost())return;
    emit("EGGLIVE1|ready|"+GetDvarString("mapname")+"|waiting|"+GetUTC()+"|v4\n");
    self notify("egg_live_new_spawn");
    self SetMoveSpeedScale(1);
    self egg_live_fun::reset();
    self egg_live_party::reset();
    self clear_banner();
    self.egg_live_notices=[];
    self clear_timers();
    self thread timer_worker();
    self thread notification_worker();
    self thread listen();
}
function ready()
{
    if(!IsAlive(self) || self laststand::player_is_in_laststand())return false;
    if(IsDefined(level.intermission) && level.intermission)return false;
    if(IsDefined(level.egg_mode_ready) && !level.egg_mode_ready)return false;
    if(IsDefined(level.egg_gameover_active) && level.egg_gameover_active)return false;
    return true;
}
function listen()
{
    self endon("disconnect");self endon("egg_live_new_spawn");
    level flag::wait_till("initial_blackscreen_passed");
    if(!IsDefined(level.egg_live_seen))level.egg_live_seen=[];
    self IPrintLn("^5Egg LIVE connected ^7- host interaction ready");
    last_beat=0;
    for(;;)
    {
        if(GetTime()-last_beat>2000)
        {
            state="waiting";if(self ready())state="playing";
            emit("EGGLIVE1|ready|"+GetDvarString("mapname")+"|"+state+"|"+GetUTC()+"|v4\n");
            last_beat=GetTime();
        }
        if(GetDvarInt("egg_live_clear")==1)
        {
            SetDvar("egg_live_clear","0");
            self.egg_live_notices=[];self clear_banner();
        }
        packet=GetDvarString("egg_live_command","");
        audio=GetDvarString("egg_live_audio","");
        if(audio!="" && (!IsDefined(self.egg_live_audio_ack)||self.egg_live_audio_ack!=audio))
        {
            self.egg_live_audio_ack=audio;
            volume=Int(Max(0,Min(100,GetDvarInt("egg_live_volume"))));
            mute=0;if(GetDvarInt("egg_live_mute")!=0)mute=1;
            emit("EGGLIVE1|audio|"+audio+"|"+volume+"|"+mute+"\n");
        }
        if(packet!="")
        {
            SetDvar("egg_live_command","");
            parts=StrTok(packet,"|");
            if(parts.size==6 || parts.size==7 || parts.size==9)
            {
                id=parts[0];action=parts[1];amount=Int(parts[2]);seconds=Int(parts[3]);
                // Replay guard survives host respawn. Requests are short-lived UTC packets.
                if(!IsDefined(level.egg_live_seen[id]))
                {
                    level.egg_live_seen[id]=true;
                    status="expired";
                    if(Int(parts[4])>=GetUTC() && Int(parts[4])<=GetUTC()+60)
                    {
                        status="not_playing";
                        if(action=="ping" || self ready())status=self apply_action(action,amount,seconds);
                    }
                    if(status=="ok" && action!="ping")
                    {
                        viewer="Viewer";if(parts.size>=7)viewer=parts[6];
                        gift="Gift";count=1;if(parts.size==9){gift=parts[7];count=Int(Max(1,Int(parts[8])));}
                        self queue_banner(action,viewer,amount,gift,count,seconds);
                    }
                    emit("EGGLIVE1|ack|"+id+"|"+status+"|"+action+"\n");
                }
            }
        }
        wait(.1);
    }
}
function apply_action(action,amount,seconds)
{
    amount=Int(Max(1,Min(100000,amount)));seconds=Int(Max(1,seconds));
    if(action=="ping")return "ok";
    if(action=="points")self zm_score::add_to_player_score(amount,false);
    else if(action=="take_points")self zm_score::minus_to_player_score(Int(Min(self.score,amount)));
    else if(action=="ammo" || action=="empty_ammo")
    {
        foreach(w in self GetWeaponsListPrimaries())
        {
            if(action=="ammo") {self GiveMaxAmmo(w);self SetWeaponAmmoClip(w,w.clipSize);}
            else {self SetWeaponAmmoClip(w,0);self SetWeaponAmmoStock(w,0);}
        }
    }
    else if(action=="heal")self.health=self.maxhealth;
    else if(action=="hurt")self.health=Int(Max(1,self.health-Min(100,amount)));
    else if(action=="down")self DoDamage(self.health+1000,self.origin);
    else if(action=="extra_zombies")
    {
        return self egg_live_fun::queue_near(Int(Min(50,amount)));
    }
    else if(action=="slow")self thread egg_live_fun::timed("slow",seconds);
    else if(action=="spin") {view=self GetPlayerAngles();self SetPlayerAngles((view[0],view[1]+180,view[2]));}
    else if(action=="all_perks")self zm_utility::give_player_all_perks();
    else if(action=="max_ammo" || action=="insta_kill" || action=="double_points" || action=="nuke")
    {
        power=action;if(action=="max_ammo")power="full_ammo";
        if(!IsDefined(level.zombie_powerups[power]))return "unsupported";
        zm_powerups::specific_powerup_drop(power,self.origin,self.team);
    }
    else
    {
        status=self egg_live_fun::apply(action,amount,seconds);
        if(status=="unknown_action")return self egg_live_party::apply(action,seconds);
        return status;
    }
    return "ok";
}
function slow(seconds)
{
    self notify("egg_live_slow_reset");self endon("egg_live_slow_reset");
    self endon("disconnect");self endon("egg_live_new_spawn");
    self SetMoveSpeedScale(.35);
    for(i=0;i<seconds*5;i++) {if(!self ready())break;wait(.2);}
    self SetMoveSpeedScale(1);
}

function clear_banner(cancel=true)
{
    if(cancel)self notify("egg_live_banner_refresh");
    if(IsDefined(self.egg_live_banner))foreach(hud in self.egg_live_banner)if(IsDefined(hud))hud Destroy();
    self.egg_live_banner=undefined;
}
function banner_line(message,y,size,colour,offset,layer)
{
    hud=NewClientHudElem(self);
    hud.horzAlign="center";hud.vertAlign="middle";
    hud.alignX="center";hud.alignY="middle";hud.x=offset;hud.y=y+offset;
    hud.font="objective";hud.fontScale=size;hud.color=colour;
    hud.alpha=1;hud.foreground=true;hud.sort=120+layer;
    hud.hideWhenDead=false;hud.hideWhenInMenu=true;
    hud SetText(message);return hud;
}
// Successful actions are acknowledged immediately. Only their presentation waits.
function queue_banner(action,viewer,amount,gift="Gift",count=1,seconds=0)
{
    if(!self ready())return;
    if(!IsDefined(self.egg_live_notices))self.egg_live_notices=[];
    foreach(item in self.egg_live_notices)
    {
        if(item.action==action && item.viewer==viewer && item.amount==amount && item.gift==gift)
        {
            item.count+=count;item.seconds+=seconds;return;
        }
    }
    item=SpawnStruct();item.action=action;item.viewer=viewer;item.amount=amount;
    item.count=count;item.gift=gift;item.seconds=seconds;item.created=GetTime();
    self.egg_live_notices[self.egg_live_notices.size]=item;
}
function notification_worker()
{
    self endon("disconnect");self endon("egg_live_new_spawn");
    for(;;)
    {
        if(!self ready())
        {
            self.egg_live_notices=[];self clear_banner();wait(.05);continue;
        }
        if(self.egg_live_notices.size==0){wait(.05);continue;}
        item=self.egg_live_notices[0];rest=[];
        for(i=1;i<self.egg_live_notices.size;i++)rest[rest.size]=self.egg_live_notices[i];
        self.egg_live_notices=rest;
        self show_banner(item.action,item.viewer,item.amount,item.count,item.gift,item.seconds);
        emit("EGGLIVE1|notice|shown|"+item.action+"|"+item.viewer+"\n");
        // Poll while showing so down/death, Pause and respawn cannot leave old text.
        for(tick=0;tick<80;tick++)
        {
            if(!self ready() || !IsDefined(self.egg_live_banner))break;
            wait(.05);
        }
        if(IsDefined(self.egg_live_banner))
        {
            foreach(hud in self.egg_live_banner){hud FadeOverTime(.2);hud.alpha=0;}
            wait(.2);
        }
        self clear_banner(false);
    }
}
function notice_sound(action)
{
    if(action=="spawn_near_50" || action=="panic_pack" || action=="chaos_roulette" || action=="bankrupt")return "egg_live_major";
    switch(action)
    {
        case "hot_potato":case "reload_tax":case "clip_leak":case "points_leak":case "zombie_regen":case "personal_space":case "red_light":case "keep_moving":case "floor_lava":case "standing_tax":case "weapon_jam":case "reverse_toll":case "magazine_roulette":return "egg_live_chaos";
        case "take_points":case "empty_ammo":case "hurt":case "down":case "extra_zombies":
        case "slow":case "spin":case "spawn_near_1":case "spawn_near_10":case "empty_clip":
        case "empty_reserve":case "half_ammo":case "one_bullet":case "knife_only":case "snail":
        case "no_sprint":case "no_jump":case "no_ads":case "no_melee":case "prone":case "crouch":
        case "hop":case "shove_back":case "sidestep":case "turn_left":case "turn_right":
        case "look_up":case "look_down":case "dizzy":case "blur":case "heal_zombies":
        case "boost_zombies":case "zombie_fast":case "half_balance":case "glass_cannon":
            return "egg_live_chaos";
    }
    return "egg_live_help";
}
function show_banner(action,viewer,amount,count=1,gift="Gift",seconds=0)
{
    self clear_banner();
    title=effect_title(action);
    if(action=="points" || action=="take_points" || action=="extra_zombies")title=title+"  "+amount;
    if(count>1)title=title+"  x"+count;
    sender="TRIGGERED BY @"+viewer;
    if(viewer=="test_viewer")sender="TEST EVENT  /  Test viewer";
    sender="@"+viewer;sender_size=1.7;
    if(viewer.size>26)sender_size=1.2;if(viewer.size>40)sender_size=1.0;
    // Untrusted gift names arrive as a bounded ASCII token, never HUD codes.
    words=StrTok(gift,"_");gift="";foreach(word in words){if(gift!="")gift=gift+" ";gift=gift+word;}
    detail=gift+" x"+count;if(seconds>0)detail=detail+"   +"+seconds+"s";
    if(title.size>26)title=GetSubStr(title,0,26);
    self.egg_live_banner=[];
    self.egg_live_banner[0]=self banner_line(sender,-68,sender_size,(0.02,0.02,0.05),3,0);
    self.egg_live_banner[1]=self banner_line(sender,-68,sender_size,(0.2,0.95,1),0,2);
    self.egg_live_banner[2]=self banner_line(title,-40,1.9,(0.03,0.02,0.09),4,0);
    self.egg_live_banner[3]=self banner_line(title,-40,1.9,(0.7,0.12,0.9),2,1);
    self.egg_live_banner[4]=self banner_line(title,-40,1.9,(1,0.8,0.22),0,2);
    self.egg_live_banner[5]=self banner_line(detail,-14,1.3,(0.02,0.03,0.08),2,0);
    self.egg_live_banner[6]=self banner_line(detail,-14,1.3,(1,1,1),0,2);
    // Original short cues, played only when this notification reaches the screen.
    volume=70;if(GetDvarString("egg_live_volume","")!="")volume=GetDvarInt("egg_live_volume");
    volume=Int(Max(0,Min(100,volume)));step=Int((volume+5)/10)*10;
    if(GetDvarInt("egg_live_mute")==0 && step>0)
    {
        alias=notice_sound(action)+"_v"+step;
        self PlayLocalSound(alias);emit("EGGLIVE1|sound|"+alias+"\n");
    }
}
function clear_timers()
{
    if(IsDefined(self.egg_live_timers))foreach(hud in self.egg_live_timers)if(IsDefined(hud))hud Destroy();
    if(IsDefined(self.egg_live_bars))foreach(hud in self.egg_live_bars)if(IsDefined(hud))hud Destroy();
    if(IsDefined(self.egg_live_tracks))foreach(hud in self.egg_live_tracks)if(IsDefined(hud))hud Destroy();
    if(IsDefined(self.egg_live_overflow))self.egg_live_overflow Destroy();
    self.egg_live_overflow=undefined;
    self.egg_live_timers=[];self.egg_live_bars=[];self.egg_live_tracks=[];
}
function timer_slot(row)
{
    // Empty/expired timers must not reserve engine HUD slots. Keeping 45 hidden
    // elements starved the map prompts, gift banners and death screen.
    hud=NewClientHudElem(self);hud.horzAlign="right";hud.vertAlign="top";
    hud.alignX="right";hud.alignY="top";hud.x=-18;hud.y=70;
    hud.font="objective";hud.fontScale=1.2;hud.foreground=true;hud.sort=115;
    hud.hideWhenDead=true;hud.hideWhenInMenu=true;hud.alpha=0;
    self.egg_live_timers[row]=hud;
    track=NewClientHudElem(self);track.horzAlign="right";track.vertAlign="top";
    track.alignX="left";track.alignY="top";track.x=-168;track.y=85;
    track SetShader("white",150,3);track.color=(0.04,0.05,0.08);
    track.foreground=true;track.sort=113;track.hideWhenDead=true;track.hideWhenInMenu=true;
    self.egg_live_tracks[row]=track;
    bar=NewClientHudElem(self);bar.horzAlign="right";bar.vertAlign="top";
    bar.alignX="left";bar.alignY="top";bar.x=-168;bar.y=85;bar SetShader("white",150,3);
    bar.foreground=true;bar.sort=114;bar.hideWhenDead=true;bar.hideWhenInMenu=true;
    self.egg_live_bars[row]=bar;
}
function timer_worker()
{
    self endon("disconnect");self endon("egg_live_new_spawn");
    for(;;)
    {
        if(!self ready()){self clear_timers();wait(.1);continue;}
        row=0;extra=0;
        if(IsDefined(self.egg_fun_order))foreach(action in self.egg_fun_order)
        {
            if(!IsDefined(self.egg_fun_until[action]) || self.egg_fun_until[action]<=GetTime())continue;
            // Five visible rows leave room for map HUDs and the gift announcement.
            // Further effects still run; the overflow count makes that explicit.
            if(row>=5){extra++;continue;}
            if(!IsDefined(self.egg_live_timers[row]))self timer_slot(row);
            hud=self.egg_live_timers[row];track=self.egg_live_tracks[row];bar=self.egg_live_bars[row];
            until=self.egg_fun_until[action];remaining=Int((until-GetTime()+999)/1000);
            minutes=Int(remaining/60);secs=remaining%60;prefix="";if(secs<10)prefix="0";
            title=effect_title(action);
            if(action=="red_light"){title="GREEN LIGHT - MOVE";if(self.egg_party_red)title="RED LIGHT - STOP";}
            if(title.size>23)title=GetSubStr(title,0,23);
            hud SetText(title+"  "+minutes+":"+prefix+secs);
            hud.y=70+row*25;hud.color=(1,1,1);hud.alpha=1;
            track.y=hud.y+15;bar.y=track.y;track.alpha=.75;bar.alpha=1;
            bar.color=(.2,.85,1);if(remaining<=5)bar.color=(1,.45,.2);
            span=Max(1,self.egg_fun_span[action]);
            width=Int(Max(1,Min(150,150*(until-GetTime())/span)));
            bar.timer_end=until;bar.timer_width=width;bar SetShader("white",width,3);
            row++;
        }
        slots=self.egg_live_timers.size;
        for(i=row;i<slots;i++)
        {
            if(IsDefined(self.egg_live_timers[i]))self.egg_live_timers[i] Destroy();
            if(IsDefined(self.egg_live_tracks[i]))self.egg_live_tracks[i] Destroy();
            if(IsDefined(self.egg_live_bars[i]))self.egg_live_bars[i] Destroy();
            self.egg_live_timers[i]=undefined;self.egg_live_tracks[i]=undefined;self.egg_live_bars[i]=undefined;
        }
        if(extra>0)
        {
            if(!IsDefined(self.egg_live_overflow))
            {
                h=NewClientHudElem(self);h.horzAlign="right";h.vertAlign="top";
                h.alignX="right";h.x=-18;h.y=200;h.font="objective";h.fontScale=1;
                h.foreground=true;h.sort=115;h.hideWhenDead=true;h.hideWhenInMenu=true;
                self.egg_live_overflow=h;
            }
            self.egg_live_overflow SetText("+"+extra+" more active effects");
        }
        else if(IsDefined(self.egg_live_overflow))
        {
            self.egg_live_overflow Destroy();self.egg_live_overflow=undefined;
        }
        wait(.1);
    }
}
function emit(message)
{
    /#
    PrintLn(message);
    #/
}

function effect_title(action)
{
    switch(action)
    {
        case "ammo_drip":return "AMMO DRIP";
        case "bottomless_clip":return "BOTTOMLESS MAGAZINE";
        case "bounty_hunt":return "BOUNTY HUNT";
        case "kill_heal":return "BLOOD BANK: HEAL ON KILLS";
        case "kill_ammo":return "BULLET BOUNTY: AMMO ON KILLS";
        case "regeneration":return "REGENERATION";
        case "clutch_recovery":return "CLUTCH RECOVERY";
        case "one_hit_zombies":return "ONE-HIT ZOMBIES";
        case "safety_ring":return "RING OF SAFETY";
        case "grenade_refill":return "REFILL LETHAL GRENADES";
        case "tactical_refill":return "REFILL TACTICAL GRENADES";
        case "interest_bank":return "INTEREST BANK";
        case "hot_potato":return "HOT POTATO: WEAPON SHUFFLE";
        case "reload_tax":return "RELOAD TAX";
        case "clip_leak":return "LEAKY MAGAZINE";
        case "points_leak":return "LEAKY WALLET";
        case "zombie_regen":return "ZOMBIE MEDIC AURA";
        case "personal_space":return "PERSONAL-SPACE PENALTY";
        case "red_light":return "RED LIGHT / GREEN LIGHT";
        case "keep_moving":return "KEEP MOVING!";
        case "floor_lava":return "FLOOR IS LAVA";
        case "standing_tax":return "STANDING TAX";
        case "weapon_jam":return "WEAPON JAM";
        case "reverse_toll":return "REVERSE TOLL";
        case "magazine_roulette":return "MAGAZINE ROULETTE";

        case "points":return "GIVE POINTS";
        case "take_points":return "TAKE POINTS";
        case "ammo":return "REFILL AMMUNITION";
        case "empty_ammo":return "EMPTY AMMUNITION";
        case "heal":return "HEAL HOST";
        case "hurt":return "DAMAGE HOST (NON-LETHAL)";
        case "down":return "DOWN HOST";
        case "extra_zombies":return "EXTRA WAVE ZOMBIES";
        case "slow":return "SLOW HOST";
        case "spin":return "TURN HOST AROUND";
        case "max_ammo":return "DROP MAX AMMO";
        case "insta_kill":return "DROP INSTA-KILL";
        case "double_points":return "DROP DOUBLE POINTS";
        case "nuke":return "DROP NUKE";
        case "all_perks":return "GIVE AVAILABLE MAP PERKS";
        case "ping":return "TEST GAME CONNECTION";
        case "spawn_near_1":return "+1 ZOMBIE BESIDE YOU";
        case "spawn_near_10":return "+10 ZOMBIES BESIDE YOU";
        case "spawn_near_50":return "+50 ZOMBIES BESIDE YOU";
        case "refill_clip":return "REFILL CURRENT MAGAZINE";
        case "refill_reserve":return "REFILL RESERVE AMMO";
        case "empty_clip":return "EMPTY CURRENT MAGAZINE";
        case "empty_reserve":return "EMPTY RESERVE AMMO";
        case "half_ammo":return "HALVE YOUR AMMUNITION";
        case "one_bullet":return "LAST BULLET CHALLENGE";
        case "swap_owned":return "SWITCH TO ANOTHER OWNED GUN";
        case "knife_only":return "NO SHOOTING CHALLENGE";
        case "speed_boost":return "SPEED BOOST";
        case "super_speed":return "SUPER SPEED";
        case "snail":return "SNAIL PACE";
        case "no_sprint":return "NO SPRINTING CHALLENGE";
        case "no_jump":return "NO JUMPING CHALLENGE";
        case "no_ads":return "HIP-FIRE CHALLENGE";
        case "no_melee":return "NO MELEE CHALLENGE";
        case "prone":return "HIT THE FLOOR";
        case "crouch":return "DUCK!";
        case "hop":return "SURPRISE HOP";
        case "shove_back":return "PUSH BACKWARDS";
        case "sidestep":return "SIDEWAYS SHOVE";
        case "turn_left":return "LOOK LEFT";
        case "turn_right":return "LOOK RIGHT";
        case "look_up":return "LOOK AT THE CEILING";
        case "look_down":return "LOOK AT YOUR SHOES";
        case "dizzy":return "DIZZY DIRECTIONS";
        case "blur":return "BLURRY VISION";
        case "kill_nearest":return "SAVE ME: KILL NEAREST ZOMBIE";
        case "kill_five":return "CLEAR FIVE ZOMBIES";
        case "kill_half":return "CLEAR HALF THE LIVE ZOMBIES";
        case "weaken_zombies":return "WEAKEN LIVE ZOMBIES";
        case "heal_zombies":return "HEAL LIVE ZOMBIES";
        case "boost_zombies":return "TOUGHER LIVE ZOMBIES";
        case "zombie_slow":return "SLOW LIVE ZOMBIES";
        case "zombie_fast":return "SPEED UP LIVE ZOMBIES";
        case "perk_jugg":return "GIVE JUGGERNOG";
        case "perk_speed":return "GIVE SPEED COLA";
        case "perk_doubletap":return "GIVE DOUBLE TAP";
        case "perk_staminup":return "GIVE STAMIN-UP";
        case "perk_revive":return "GIVE QUICK REVIVE";
        case "perk_mule":return "GIVE MULE KICK";
        case "perk_deadshot":return "GIVE DEADSHOT";
        case "double_balance":return "DOUBLE YOUR POINTS BALANCE";
        case "half_balance":return "HALVE YOUR POINTS BALANCE";
        case "bankrupt":return "BANKRUPT: LOSE ALL POINTS";
        case "points_lottery":return "POINTS LOTTERY";
        case "rescue_pack":return "RESCUE PACKAGE";
        case "panic_pack":return "PANIC PACKAGE";
        case "glass_cannon":return "GLASS CANNON CHALLENGE";
        case "ammo_rain":return "AMMO RAIN";
        case "chaos_roulette":return "CHAOS ROULETTE";
    }
    return "VIEWER INTERACTION";
}
