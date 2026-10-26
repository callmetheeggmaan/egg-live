#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\egg_live_fun;
#insert scripts\shared\shared.gsh;
#namespace egg_live_party;

function reset()
{
    self notify("egg_party_new_life");
    self.egg_party_red=false;
}
function ordinary_zombies()
{
    result=[];
    foreach(z in GetAIArray("zombie","targetname"))
        if(IsAlive(z) && !IsDefined(z.egg_warden))result[result.size]=z;
    return result;
}
function charge(points)
{
    self zm_score::minus_to_player_score(Int(Min(Max(0,self.score),points)));
}
function safe_damage(points)
{
    // These challenges never directly down the player or disable normal damage.
    self.health=Int(Max(1,self.health-points));
}
function kills()
{
    if(!IsDefined(self.kills))return 0;
    return self.kills;
}
function add_clip(rounds)
{
    gun=self GetCurrentWeapon();
    if(IsDefined(gun) && gun.clipSize>0)
        self SetWeaponAmmoClip(gun,Int(Min(gun.clipSize,Max(0,self GetWeaponAmmoClip(gun)+rounds))));
}
function apply(action,seconds)
{
    if(action=="one_hit_zombies" || action=="safety_ring")
    {
        targets=ordinary_zombies();affected=0;
        foreach(z in targets)
        {
            if(action=="one_hit_zombies"){z.health=1;affected++;}
            else if(DistanceSquared(z.origin,self.origin)<=256*256)
            {z DoDamage(z.health+1,self.origin,self,self,"none","MOD_TRIGGER_HURT");affected++;}
        }
        if(affected==0)return "no_enemies";
        return "ok";
    }
    if(action=="grenade_refill" || action=="tactical_refill")
    {
        grenade=self zm_utility::get_player_lethal_grenade();count=4;
        if(action=="tactical_refill"){grenade=self zm_utility::get_player_tactical_grenade();count=2;}
        if(!IsDefined(grenade) || !self HasWeapon(grenade))return "unsupported";
        self SetWeaponAmmoClip(grenade,count);return "ok";
    }
    if(action=="magazine_roulette")
    {
        gun=self GetCurrentWeapon();if(!IsDefined(gun) || gun.clipSize<1)return "unsupported";
        self SetWeaponAmmoClip(gun,RandomIntRange(1,gun.clipSize+1));return "ok";
    }
    timed=StrTok("ammo_drip bottomless_clip bounty_hunt kill_heal kill_ammo regeneration clutch_recovery interest_bank hot_potato reload_tax clip_leak points_leak zombie_regen personal_space red_light keep_moving floor_lava standing_tax weapon_jam reverse_toll"," ");
    found=false;foreach(name in timed)if(name==action)found=true;
    if(!found)return "unknown_action";
    guns=self GetWeaponsListPrimaries();
    if(action=="hot_potato" && guns.size<2)return "needs_two_guns";
    self thread run(action,seconds);return "ok";
}
function run(action,seconds)
{
    self egg_live_fun::extend_timer(action,seconds,"party_"+action);
    self notify("egg_party_"+action);self endon("egg_party_"+action);
    self endon("egg_party_new_life");self endon("egg_live_new_spawn");self endon("disconnect");
    tick=0;previous_kills=self kills();previous_pos=self.origin;
    previous_gun=self GetCurrentWeapon();previous_clip=self GetWeaponAmmoClip(previous_gun);
    previous_stock=self GetWeaponAmmoStock(previous_gun);clutch_used=false;
    while(IsDefined(self.egg_fun_until[action]) && GetTime()<self.egg_fun_until[action])
    {
        if(!IsAlive(self) || self laststand::player_is_in_laststand())break;
        gun=self GetCurrentWeapon();clip=self GetWeaponAmmoClip(gun);stock=self GetWeaponAmmoStock(gun);
        new_kills=self kills();gained=Int(Max(0,new_kills-previous_kills));previous_kills=new_kills;
        if(action=="bottomless_clip")self add_clip(gun.clipSize);
        if(action=="ammo_drip" && tick%5==0)self add_clip(1);
        if(action=="clip_leak" && tick%5==0)self add_clip(-1);
        if(action=="bounty_hunt" && gained>0)self zm_score::add_to_player_score(Int(Min(100000,gained*250)),false);
        if(action=="kill_heal" && gained>0)self.health=Int(Min(self.maxhealth,self.health+gained*15));
        if(action=="kill_ammo" && gained>0)self add_clip(gained*3);
        if(action=="clutch_recovery" && !clutch_used && self.health<=self.maxhealth*.25)
        {self.health=Int(Max(self.health,self.maxhealth*.5));clutch_used=true;}
        if(action=="reload_tax" && gun==previous_gun && clip>previous_clip && stock<previous_stock)self charge(250);
        if(action=="hot_potato" && tick%20==0)
        {
            choices=[];foreach(w in self GetWeaponsListPrimaries())if(w!=gun)choices[choices.size]=w;
            if(choices.size>0)self SwitchToWeapon(choices[RandomInt(choices.size)]);
        }
        if(action=="interest_bank" && tick>0 && tick%20==0)self zm_score::add_to_player_score(Int(Min(500,Max(0,self.score)*.1)),false);
        if(action=="weapon_jam" && tick>0 && tick%30==0)self SetWeaponAmmoClip(gun,0);
        if(action=="red_light")self.egg_party_red=Int(tick/30)%2==0;
        if(tick%10==0)
        {
            moved=self.origin-previous_pos;distance=DistanceSquared(self.origin,previous_pos);previous_pos=self.origin;
            if(action=="regeneration")self.health=Int(Min(self.maxhealth,self.health+10));
            if(action=="points_leak")self charge(50);
            if(action=="standing_tax" && self GetStance()=="stand")self charge(25);
            if(action=="keep_moving" && tick>0 && distance<64)self safe_damage(5);
            if(action=="red_light" && tick>0 && self.egg_party_red && distance>64)self safe_damage(5);
            if(action=="floor_lava" && tick>=20 && self IsOnGround())self safe_damage(5);
            if(action=="reverse_toll" && tick>0)
            {
                view=self GetPlayerAngles();forward=AnglesToForward((0,view[1],0));
                if(moved[0]*forward[0]+moved[1]*forward[1]<-10)self charge(50);
            }
            if(action=="zombie_regen" || action=="personal_space")
            {
                close=false;
                foreach(z in ordinary_zombies())
                {
                    range=DistanceSquared(z.origin,self.origin);
                    if(action=="zombie_regen" && range<=384*384)z.health=Int(Min(z.maxhealth,z.health+Max(1,z.maxhealth*.1)));
                    if(range<=128*128)close=true;
                }
                if(action=="personal_space" && close)self charge(25);
            }
        }
        previous_gun=gun;previous_clip=self GetWeaponAmmoClip(gun);previous_stock=self GetWeaponAmmoStock(gun);
        tick++;wait(.1);
    }
    self.egg_fun_until[action]=undefined;self.egg_fun_actions["party_"+action]=undefined;
    if(action=="red_light")self.egg_party_red=false;
}
