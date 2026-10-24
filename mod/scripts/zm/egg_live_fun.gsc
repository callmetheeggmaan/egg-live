#using scripts\shared\ai\zombie_utility;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_spawner;
#insert scripts\shared\shared.gsh;
#namespace egg_live_fun;

function init()
{
    level.egg_live_near=0;
    zm_spawner::add_custom_zombie_spawn_logic(&new_zombie);
}
function new_zombie()
{
    if(!IsDefined(level.egg_live_near) || level.egg_live_near<=0)return;
    host=undefined;foreach(p in GetPlayers())if(p IsHost())host=p;
    if(!IsDefined(host) || !IsAlive(host))return;
    level.egg_live_near--;
    self.egg_live_near_marked=GetTime();
    self thread move_near(host);
}
function move_near(host)
{
    self endon("death");wait(.15);
    if(!IsDefined(host) || !IsAlive(host) || !IsAlive(self))return;
    pos=undefined;
    for(attempt=0;attempt<50;attempt++){pos=host nearby_position();if(IsDefined(pos))break;wait(.2);}
    if(!IsDefined(pos)){self.egg_live_near_done=true;return;}
    self ForceTeleport(pos,VectorToAngles(host.origin-pos));
    if(!IsDefined(level.egg_live_near_delivered))level.egg_live_near_delivered=0;
    level.egg_live_near_delivered++;self.egg_live_near_done=true;
}
function nearby_position()
{
    start=RandomInt(16);
    for(i=0;i<48;i++)
    {
        direction=AnglesToForward((0,((i+start)%16)*22.5,0));
        pos=GetClosestPointOnNavMesh(self.origin+direction*(128+Int(i/16)*64),48,24);
        if(!IsDefined(pos) || DistanceSquared(pos,self.origin)<9216 || Abs(pos[2]-self.origin[2])>48)continue;
        trace=BulletTrace(self.origin+(0,0,45),pos+(0,0,45),false,self);
        if(trace["fraction"]<.99)continue;
        clear=true;
        foreach(p in GetPlayers())if(DistanceSquared(p.origin,pos)<6400)clear=false;
        foreach(z in GetAIArray("zombie","targetname"))if(IsAlive(z)&&DistanceSquared(z.origin,pos)<2304)clear=false;
        if(clear)return pos;
    }
    return undefined;
}
function queue_near(count)
{
    if(!IsDefined(level.zombie_total) || !IsDefined(level.zombie_spawners) || level.zombie_spawners.size==0)return "unsupported";
    if(IsDefined(level.is_dog_round) && level.is_dog_round)return "dog_round";
    if(!IsDefined(level.egg_live_near))level.egg_live_near=0;
    if(level.egg_live_near+count>500)return "spawn_queue_full";
    zombie_utility::clear_all_corpses();
    level.egg_live_near+=count;level.zombie_total+=count;
    if(!IsDefined(level.egg_live_burst_running) || !level.egg_live_burst_running)
    {
        level.egg_live_burst_running=true;
        self thread spawn_burst();
    }
    return "ok";
}
function spawn_burst()
{
    // Use the map's native actor factory immediately, without its round-delay
    // timer. The normal spawn callback still consumes every nearby ticket once.
    while(level.egg_live_near>0)
    {
        if(!IsAlive(self) || self laststand::player_is_in_laststand())break;
        if(GetFreeActorCount()<1 || zombie_utility::get_current_actor_count()>=level.zombie_actor_limit){zombie_utility::clear_all_corpses();wait(.05);continue;}
        if(zombie_utility::get_current_zombie_count()>=level.zombie_ai_limit){wait(.05);continue;}
        pos=self nearby_position();if(!IsDefined(pos)){wait(.05);continue;}
        spot=SpawnStruct();spot.origin=pos;spot.angles=VectorToAngles(self.origin-pos);spot.script_noteworthy="spawn_location";
        spawner=level.zombie_spawners[RandomInt(level.zombie_spawners.size)];
        actor=zombie_utility::spawn_zombie(spawner,spawner.targetname,spot);
        if(IsDefined(actor))
        {
            level.zombie_total=Int(Max(0,level.zombie_total-1));
            actor thread zombie_utility::round_spawn_failsafe();
        }
        wait(.05);
    }
    level.egg_live_burst_running=false;
}
function apply(action,amount,seconds)
{
    if(action=="spawn_near_1")return self queue_near(1);
    if(action=="spawn_near_10")return self queue_near(10);
    if(action=="spawn_near_50")return self queue_near(50);
    weapon=self GetCurrentWeapon();
    if(action=="refill_clip")self SetWeaponAmmoClip(weapon,weapon.clipSize);
    else if(action=="refill_reserve") {clip=self GetWeaponAmmoClip(weapon);self GiveMaxAmmo(weapon);self SetWeaponAmmoClip(weapon,clip);}
    else if(action=="empty_clip")self SetWeaponAmmoClip(weapon,0);
    else if(action=="empty_reserve")self SetWeaponAmmoStock(weapon,0);
    else if(action=="half_ammo") {self SetWeaponAmmoClip(weapon,Int(self GetWeaponAmmoClip(weapon)/2));self SetWeaponAmmoStock(weapon,Int(self GetWeaponAmmoStock(weapon)/2));}
    else if(action=="one_bullet") {self SetWeaponAmmoClip(weapon,1);self SetWeaponAmmoStock(weapon,0);}
    else if(action=="swap_owned")
    {
        guns=self GetWeaponsListPrimaries();if(guns.size<2)return "needs_two_guns";
        foreach(gun in guns)if(gun!=weapon){self SwitchToWeapon(gun);break;}
    }
    else if(action=="knife_only" || action=="no_sprint" || action=="no_jump" || action=="no_ads" || action=="no_melee" || action=="speed_boost" || action=="super_speed" || action=="snail" || action=="blur" || action=="dizzy" || action=="ammo_rain")self thread timed(action,seconds);
    else if(action=="prone")self SetStance("prone");
    else if(action=="crouch")self SetStance("crouch");
    else if(action=="hop") {self SetOrigin(self.origin+(0,0,1));self SetVelocity((0,0,230));}
    else if(action=="shove_back") {v=self GetPlayerAngles();self SetVelocity(AnglesToForward((0,v[1],0))*-180+(0,0,80));}
    else if(action=="sidestep") {v=self GetPlayerAngles();self SetVelocity(AnglesToRight((0,v[1],0))*180+(0,0,60));}
    else if(action=="turn_left" || action=="turn_right" || action=="look_up" || action=="look_down")
    {
        v=self GetPlayerAngles();if(action=="turn_left")v=(v[0],v[1]+90,0);if(action=="turn_right")v=(v[0],v[1]-90,0);if(action=="look_up")v=(-65,v[1],0);if(action=="look_down")v=(65,v[1],0);self SetPlayerAngles(v);
    }
    else if(action=="kill_nearest" || action=="kill_five" || action=="kill_half" || action=="weaken_zombies" || action=="heal_zombies" || action=="boost_zombies" || action=="zombie_slow" || action=="zombie_fast")return self enemies(action,seconds);
    else if(action.size>=5 && GetSubStr(action,0,5)=="perk_")return self perk(action);
    else if(action=="double_balance")self zm_score::add_to_player_score(Int(Min(100000,self.score)),false);
    else if(action=="half_balance")self zm_score::minus_to_player_score(Int(self.score/2));
    else if(action=="bankrupt")self zm_score::minus_to_player_score(self.score);
    else if(action=="points_lottery")self zm_score::add_to_player_score(RandomIntRange(1,101)*100,false);
    else if(action=="rescue_pack") {self.health=self.maxhealth;self GiveMaxAmmo(weapon);self SetWeaponAmmoClip(weapon,weapon.clipSize);self zm_score::add_to_player_score(1000,false);}
    else if(action=="panic_pack") {v=self GetPlayerAngles();self SetPlayerAngles((v[0],v[1]+180,0));self thread timed("no_ads",seconds);return self queue_near(10);}
    else if(action=="glass_cannon") {self GiveMaxAmmo(weapon);self thread timed("glass_cannon",seconds);self thread timed("speed_boost",seconds);}
    else if(action=="chaos_roulette")
    {
        choices=StrTok("one_bullet no_ads no_sprint dizzy snail points_lottery rescue_pack turn_left"," ");return self apply(choices[RandomInt(choices.size)],1,seconds);
    }
    else return "unknown_action";
    return "ok";
}
function perk(action)
{
    perk="";
    switch(action){case "perk_jugg":perk="specialty_armorvest";break;case "perk_speed":perk="specialty_fastreload";break;case "perk_doubletap":perk="specialty_doubletap2";break;case "perk_staminup":perk="specialty_staminup";break;case "perk_revive":perk="specialty_quickrevive";break;case "perk_mule":perk="specialty_additionalprimaryweapon";break;case "perk_deadshot":perk="specialty_deadshot";break;}
    if(perk=="")return "unknown_action";
    if(!IsDefined(level._custom_perks[perk]))return "unsupported";
    if(self HasPerk(perk))return "already_owned";
    self zm_perks::give_perk(perk,false);return "ok";
}
function enemies(action,seconds)
{
    enemies=[];foreach(z in GetAIArray("zombie","targetname"))if(IsAlive(z)&&!IsDefined(z.egg_warden))enemies[enemies.size]=z;
    if(enemies.size==0)return "no_enemies";
    limit=enemies.size;if(action=="kill_nearest")limit=1;if(action=="kill_five")limit=Min(5,limit);if(action=="kill_half")limit=Int((limit+1)/2);
    if(action=="kill_nearest") {nearest=enemies[0];foreach(z in enemies)if(DistanceSquared(z.origin,self.origin)<DistanceSquared(nearest.origin,self.origin))nearest=z;enemies[0]=nearest;}
    if(action=="zombie_slow" || action=="zombie_fast")self extend_timer(action,seconds,"enemy_speed");
    for(i=0;i<limit;i++)
    {
        z=enemies[i];
        if(action=="kill_nearest" || action=="kill_five" || action=="kill_half")z DoDamage(z.health+1,self.origin,self,self,"none","MOD_TRIGGER_HURT");
        else if(action=="weaken_zombies")z.health=Int(Max(1,Int(z.health/2)));
        else if(action=="heal_zombies")z.health=z.maxhealth;
        else if(action=="boost_zombies") {z.maxhealth=Int(Min(1000000,z.maxhealth*2));z.health=z.maxhealth;}
        else {scale=.4;if(action=="zombie_fast")scale=1.6;z thread enemy_speed(scale,seconds);}
    }
    return "ok";
}
function enemy_speed(scale,seconds)
{
    if(!IsDefined(self.egg_fun_enemy_scale) || self.egg_fun_enemy_scale!=scale)self.egg_fun_enemy_until=GetTime();
    self.egg_fun_enemy_scale=scale;
    self.egg_fun_enemy_until=Min(GetTime()+3600000,Max(GetTime(),self.egg_fun_enemy_until)+seconds*1000);
    self notify("egg_fun_speed");self endon("egg_fun_speed");self endon("death");
    if(IsDefined(self.zombie_move_speed_override) && !IsDefined(self.egg_fun_base_speed))return;
    if(!IsDefined(self.egg_fun_base_speed))self.egg_fun_base_speed=self.zombie_move_speed;
    self.zombie_move_speed_override=undefined;
    self.zombie_move_speed_restore=self.egg_fun_base_speed;
    speed="walk";if(scale>1)speed="sprint";
    self zombie_utility::set_zombie_run_cycle_override_value(speed);
    while(GetTime()<self.egg_fun_enemy_until)wait(.1);
    self.egg_fun_enemy_scale=undefined;
    self zombie_utility::set_zombie_run_cycle_restore_from_override();self.egg_fun_base_speed=undefined;
}
function extend_timer(action,seconds,group)
{
    if(!IsDefined(self.egg_fun_until))self.egg_fun_until=[];
    if(!IsDefined(self.egg_fun_actions))self.egg_fun_actions=[];
    if(!IsDefined(self.egg_fun_order))self.egg_fun_order=[];
    previous=self.egg_fun_actions[group];
    if(IsDefined(previous) && previous!=action)self.egg_fun_until[previous]=undefined;
    if(!IsDefined(self.egg_fun_until[action]) || self.egg_fun_until[action]<=GetTime())
    {
        order=[];
        foreach(entry in self.egg_fun_order)if(entry!=action && IsDefined(self.egg_fun_until[entry]) && self.egg_fun_until[entry]>GetTime())order[order.size]=entry;
        order[order.size]=action;self.egg_fun_order=order;
    }
    self.egg_fun_actions[group]=action;
    until=GetTime();if(IsDefined(self.egg_fun_until[action]))until=Max(until,self.egg_fun_until[action]);
    self.egg_fun_until[action]=Min(GetTime()+3600000,until+seconds*1000);
    if(!IsDefined(self.egg_fun_span))self.egg_fun_span=[];
    self.egg_fun_span[action]=self.egg_fun_until[action]-GetTime();
    /# PrintLn("EGGLIVE1|timer|"+action+"|"+Int((self.egg_fun_until[action]-GetTime()+999)/1000)); #/
}
function timed(action,seconds)
{
    group=action;if(action=="speed_boost" || action=="super_speed" || action=="snail" || action=="slow")group="move_speed";
    self extend_timer(action,seconds,group);
    self notify("egg_fun_"+group);self endon("egg_fun_"+group);self endon("disconnect");self endon("egg_live_new_spawn");
    if(group=="move_speed") {if(!IsDefined(self.egg_fun_move_base))self.egg_fun_move_base=self GetMoveSpeedScale();scale=1.4;if(action=="super_speed")scale=1.8;if(action=="snail")scale=.2;if(action=="slow")scale=.35;self SetMoveSpeedScale(scale);}
    if(action=="glass_cannon"){if(!IsDefined(self.egg_fun_health_base))self.egg_fun_health_base=self.health;self.health=2;}
    if(action=="knife_only")self DisableWeapons();
    if(action=="no_sprint")
    {
        if(!IsDefined(self.egg_fun_sprint_saved)){self.egg_fun_sprint_base=self._allow_sprint;self.egg_fun_sprint_saved=true;}
        self._allow_sprint=false;
        self AllowSprint(false);
    }
    if(action=="no_jump")self AllowJump(false);
    if(action=="no_ads")self AllowAds(false);
    if(action=="no_melee")self AllowMelee(false);
    if(action=="blur")self SetBlur(6,.2);
    i=0;
    while(GetTime()<self.egg_fun_until[action])
    {
        if(!IsAlive(self) || self laststand::player_is_in_laststand())break;
        if(action=="no_sprint")self AllowSprint(false);
        if(action=="glass_cannon")self.health=Int(Min(self.health,2));
        if(i%5==0 && action=="ammo_rain"){gun=self GetCurrentWeapon();self GiveMaxAmmo(gun);self SetWeaponAmmoClip(gun,gun.clipSize);}
        if(i%5==0 && action=="dizzy"){v=self GetPlayerAngles();self SetPlayerAngles((v[0],v[1]+RandomIntRange(-90,91),0));}
        i++;wait(.2);
    }
    self.egg_fun_until[action]=undefined;self.egg_fun_actions[group]=undefined;
    if(group=="move_speed"){self SetMoveSpeedScale(self.egg_fun_move_base);self.egg_fun_move_base=undefined;}
    if(action=="glass_cannon"){if(IsAlive(self) && !self laststand::player_is_in_laststand())self.health=Int(Min(self.egg_fun_health_base,self.maxhealth));self.egg_fun_health_base=undefined;}
    if(action=="knife_only")self EnableWeapons();
    if(action=="no_sprint")self restore_sprint();
    if(action=="no_jump")self AllowJump(true);
    if(action=="no_ads")self AllowAds(true);
    if(action=="no_melee")self AllowMelee(true);
    if(action=="blur")self SetBlur(0,.2);
}
function reset()
{
    self.egg_fun_until=[];self.egg_fun_actions=[];self.egg_fun_order=[];self.egg_fun_span=[];
    self AllowAds(true);self AllowJump(true);self AllowSprint(true);self AllowMelee(true);self EnableWeapons();
    self SetDepthOfField(0,0,512,4000,4,0);self.egg_fun_move_base=undefined;self.egg_fun_health_base=undefined;
    self SetBlur(0,0);
    if(IsDefined(self.egg_fun_sprint_saved))self restore_sprint();
}
function restore_sprint()
{
    self._allow_sprint=self.egg_fun_sprint_base;
    allowed=true;if(IsDefined(self._allow_sprint))allowed=self._allow_sprint;
    self AllowSprint(allowed);
    self.egg_fun_sprint_base=undefined;self.egg_fun_sprint_saved=undefined;
}
