"""Prepare Eggstinction under build/. Reads installed templates; no game writes."""
from pathlib import Path
import importlib.util
import re
import shutil
import json
import csv
import argparse
import egg_art
import build_audio
import build_models
import build_admin_weapon

parser=argparse.ArgumentParser()
parser.add_argument('--test',choices=('easy','medium','hard','audit','restart','special','repair','review','box','idle','boxfix','polish','gums'))
parser.add_argument('--records', action='store_true', help='Include optional companion match-event logging')
args=parser.parse_args()

ROOT=Path(__file__).resolve().parents[1]
TOOLS=Path(r'E:\steam\steamapps\common\Call of Duty Black Ops III 455130')
TEMPLATE=TOOLS/'rex/templates/ZM Mod Level'
BUILD=ROOT/'build'
NAME='zm_eggstinction'
spec=importlib.util.spec_from_file_location('egg_layout',ROOT/'source/build_layout.py')
g=importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
g.geometry(); g.placements()
world_brushes=list(g.BRUSHES)
entities=[]; prefabs=set(); box_clip_centres=[]

def emit(label,kv,brushes=(),layer='Eggstinction/Gameplay'):
    index=len(entities)+1
    lines=[f'// entity {index}','{',f'guid "{g.guid("playable/"+label)}"',f'layer "{layer}"']
    lines += [f'"{k}" "{v}"' for k,v in kv.items()]
    for i,brush in enumerate(brushes): lines += [f'// brush {i}',brush]
    lines.append('}')
    entities.append('\n'.join(lines))

def block(label,lo,hi,texture):
    g.box(label,lo,hi)
    return g.BRUSHES[-1][1].replace(g.MATERIAL+' ',texture+' ').replace('contents detail;\n','')

def prefab(label,file,origin,angle=0):
    assert (TOOLS/'map_source'/file).is_file(), file
    prefabs.add(file)
    emit(label,{'classname':'misc_prefab','model':file,'origin':g.point(origin),'angles':f'0 {angle} 0'})

def trigger(label,target,origin,**kv):
    x,y,z=origin
    brush=block(label,(x-88,y-88,0),(x+88,y+88,144),'trigger')
    emit(label,{'classname':'trigger_use','targetname':target,'origin':g.point((x,y,72)),**kv},[brush])

def parse_kv_entities(source):
    depth=0; result=[]; current={}
    for line in source.splitlines():
        s=line.strip()
        if s=='{': depth+=1
        if depth==1:
            match=re.match(r'^"([^\"]+)"\s+"([^\"]*)"$',s)
            if match: current[match[1]]=match[2]
        if s=='}':
            if depth==1: result.append(current); current={}
            depth-=1
    return result

for label,lo,hi in (
    ('sky_bottom',(-1280,-1280,-288),(8960,1280,-256)),
    ('sky_top',(-1280,-1280,1536),(8960,1280,1568)),
    ('sky_south',(-1280,-1312,-288),(8960,-1280,1568)),
    ('sky_north',(-1280,1280,-288),(8960,1312,1568)),
    ('sky_west',(-1312,-1312,-288),(-1280,1312,1568)),
    ('sky_east',(8960,-1312,-288),(8992,1312,1568))):
    world_brushes.append((label,block(label,lo,hi,'sky')))

template_map=(TEMPLATE/'map_source/zm/template.map').read_text()
template_entities=parse_kv_entities(template_map)
world=next(e for e in template_entities if e.get('classname')=='worldspawn')
box_source=parse_kv_entities((TOOLS/'map_source/_prefabs/zm/zm_giant/script/zm_giant_magicboxes.map').read_text())
box_barrier=next(e for e in box_source if e.get('script_noteworthy')=='start_chest_zbarrier')

for m in g.MARKERS:
    x,y,z=m['origin']; kind=m['kind']; label=m['id']
    if kind=='player_spawn':
        emit(label,{'classname':'script_struct','origin':g.point((x,y,24)), 'angles':'0 0 0','targetname':'initial_spawn_points'})
    elif kind=='difficulty_terminal':
        mode=label.removeprefix('difficulty_')
        trigger(label,'egg_difficulty',(x,y,z),script_string=mode)
        # Low projector foot; the floating selector itself is non-colliding.
        world_brushes.append(('projector_'+mode,block('projector_'+mode,(x-32,y-32,0),(x+32,y+32,8),egg_art.DARK)))
    elif kind=='perk':
        paths={'quick_revive':'revive','juggernog':'juggernaut','double_tap':'doubletap',
               'stamin_up':'marathon','speed_cola':'sleight','mule_kick':'additionalprimaryweapon','deadshot':'deadshot'}
        if label in paths:
            # In-engine audit: vending fronts face local -Y at yaw zero.
            prefab(label,f'_prefabs/zm/zm_core/vending_{paths[label]}_struct.map',(x,706,3),0)
    elif kind in ('mystery_box_start','mystery_box_move'):
        note='start_chest' if kind=='mystery_box_start' else label
        if kind=='mystery_box_start': x=-320
        y=-690
        box_clip_centres.append((x,y,33))
        emit(label,{'classname':'script_struct','origin':g.point((x,y,0)), 'angles':'0 0 0',
                    'targetname':'treasure_chest_use','script_noteworthy':note,'zombie_cost':'950'})
        barrier=dict(box_barrier)
        barrier.update(origin=g.point((x,y,0)),angles='0 0 0',script_noteworthy=note+'_zbarrier')
        barrier['targetname']='egg_box_barrier'
        emit(label+'_barrier',barrier)
        # The animated stock model is not dependable player collision. A dynamic
        # clip follows the active chest and is removed when that chest moves.
        collision=block(label+'_collision',(x-72,y-30,0),(x+72,y+30,66),'clip')
        emit(label+'_collision',{'classname':'script_brushmodel','targetname':'egg_box_collision',
             'script_string':note,'spawnflags':'2','DYNAMICPATH':'1','static_navmesh':'0'},[collision])
    elif kind=='power_switch':
        prefab(label,'_prefabs/zm/zm_core/power_switch.map',(x,-736,24),180)
    elif kind=='pack_a_punch':
        prefab(label,'_prefabs/zm/zm_core/vending_weapon_upgrade_spawnable.map',(x,-704,0),270)
    elif kind=='upgrade_station':
        tier={'shellcracker':1,'yolk_storm':2,'golden_hatch':3}[label]
        trigger(label,'egg_upgrade_use',(x,y+(-90 if y>0 else 90),z),script_int=str(tier))
        emit(label+'_console',{'classname':'misc_model','model':'p7_zm_der2_teleporter_control_panel',
             'origin':g.point((x,y,58)),'angles':f'0 {0 if y>0 else 180} -16','modelscale':'1.6'})
    elif kind=='host_admin_locker':
        trigger(label,'egg_admin_use',(x,y+96,z))
        emit(label+'_console',{'classname':'misc_model','model':'p7_zm_der2_teleporter_control_panel',
             'origin':g.point((x,y,58)),'angles':'0 180 -16','modelscale':'1.6'})
    elif kind=='wall_buy':
        weapons={'nest':'pistol_burst','shellworks':'smg_standard','hatchery':'ar_standard',
                 'reactor':'shotgun_pump','kitchen':'ar_standard','vault':'smg_fastfire'}
        prefab(label,'_prefabs/zm/zm_core/spawnable_weapon_'+weapons[m['room']]+'.map',(x,740,0),180)
    elif kind=='zombie_spawn_candidate':
        emit(label,{'classname':'script_struct','origin':g.point((x,y,0)),'angles':f'0 {90 if y<0 else 270} 0',
                    'script_noteworthy':'riser_location','script_string':'find_flesh',
                    'targetname':m['room']+'_spawners'})
    elif kind=='buyable_door':
        index=int(m['shared_purchase'].split('_')[-1])
        gate=block(label+'_solid',(x-14,y-160,0),(x+14,y+160,256),'caulk')
        emit(label,{'classname':'script_brushmodel','targetname':'egg_gate_'+str(index),
                    'spawnflags':'2','DYNAMICPATH':'1','static_navmesh':'0'},[gate])
        emit(label+'_visual',{'classname':'script_model','targetname':'egg_gate_visual_'+str(index),
             'origin':g.point((x,y,127)),'angles':'0 0 0','model':'egg_bulkhead'})
        trigger(label+'_use','egg_gate_use',(x-72,y,z),script_int=str(index))

# Inline the community machine entities using the already-loaded BO3 models.
gum_entities=parse_kv_entities((ROOT/'source/vendor/gobblegum/machine.map').read_text())
for n,entity in enumerate(gum_entities):
    if entity.get('classname')=='worldspawn':continue
    kv=dict(entity)
    if kv.get('classname','').startswith('zbarrier_'):
        kv['classname']='zbarrier_zmcore_bgb_machine';kv['type']='zmcore_bgb_machine'
    kv['origin']='0 700 '+('16' if kv.get('classname')=='script_struct' else '0')
    kv['angles']='0 270 0' if kv.get('classname')=='script_struct' else '0 0 0'
    emit('native_gum_'+str(n),kv)
world_brushes.append(('gum_collision',block('gum_collision',(-22,678,0),(22,722,96),'clip')))

for i,(slug,_,_) in enumerate(g.ROOMS):
    cx=i*1536
    volume=block('volume_'+slug,(cx-768,-768,-16),(cx+768,768,640),'volume')
    emit('zone_'+slug,{'classname':'info_volume','targetname':slug+'_zone','script_noteworthy':'player_volume',
                       'target':slug+'_spawners'},[volume])
    for dx in (-384,384):
        for y in (-384,384):
            emit(f'light_{i}_{dx}_{y}',{'classname':'light','origin':g.point((cx+dx,y,352)),
                'PRIMARY_TYPE':'PRIMARY_OMNI','_color':'1 0.83 0.59','radius':'1000','stops':'8',
                'def':'white_light','bulbRadius':'8','spawnflags':'0','shadowUpdate':'Never',
                'lightingstate1':'1','lightingstate2':'1','lightingstate3':'1','lightingstate4':'1'},layer='Eggstinction/Lights')
    probe=dict(next(e for e in template_entities if e.get('classname')=='reflection_probe'))
    probe.update(origin=g.point((cx,-320,160)),name='egg_probe_'+str(i))
    emit('probe_'+str(i),probe,layer='Eggstinction/Lights')
    for dx in (-520,520):
        emit(f'fill_{i}_{dx}',{'classname':'light','origin':g.point((cx+dx,0,128)),
             'PRIMARY_TYPE':'PRIMARY_OMNI','_color':'0.6 0.8 1','radius':'850','stops':'6',
             'def':'white_light','bulbRadius':'32','spawnflags':'0','shadowUpdate':'Never',
             'lightingstate1':'1','lightingstate2':'1','lightingstate3':'1','lightingstate4':'1'},layer='Eggstinction/Lights')

sun=block('sun_bounds',(-1024,-1024,-128),(8704,1024,1024),'sun_volume')
emit('sun_volume',{'classname':'volume_sun','ssi':'default_day','ssi1':'default_day',
    'grid_density':'64','shadowBiasScale':'1','shadowSplitDistance':'2000','streamLighting':'1'},[sun],layer='Eggstinction/Lights')
umbra=block('visibility_bounds',(-1024,-1024,-128),(8704,1024,1024),'umbra_volume')
emit('visibility_volume',{'classname':'umbra_volume'},[umbra])

emit('debug_start',{'classname':'info_player_start','origin':'-320 -144 24','angles':'0 0 0'})
respawn=dict(next(e for e in template_entities if e.get('targetname')=='player_respawn_point'))
respawn.update(origin='-320 0 24',angles='0 0 0',script_noteworthy='nest_zone')
emit('respawn',respawn)
actor=dict(next(e for e in template_entities if e.get('classname')=='actor_spawner_zm_factory_zombie'))
actor.update(origin='-640 640 32')
emit('zombie_actor',actor)
dog_source=parse_kv_entities((TOOLS/'map_source/_prefabs/zm/zm_giant/script/zm_giant_nodes.map').read_text())
dog=dict(next(e for e in dog_source if e.get('classname')=='actor_spawner_zm_factory_zombie_dog'))
dog.update(origin='-600 560 32')
emit('dog_actor',dog)
trigger('crosshair_setup','egg_crosshair_use',(176,-528,0))
emit('crosshair_console',{'classname':'misc_model','model':'p7_zm_der_trap_control_box',
     'origin':'176 -700 64','angles':'0 180 0'})

# Dressing stays in wall pockets, clear of the two broad training routes,
# perk fronts, wall purchases, power and the mystery-box reward space.
for i in range(6):
    cx=i*1536
    props=[('p7_crate_wood_01',cx-640,-704,0,0),
           ('p7_barrel_plastic_blue',cx-545,-710,0,0),
           ('p7_fan_electric_floor',cx-610,700,0,180)]
    prefab(f'lab_bench_{i}','_prefabs/zm/zm_giant/geo/asylum_storage_table.map',(cx+510,720,0),180)
    prefab(f'wall_cabinet_{i}','_prefabs/zm/zm_giant/geo/asylum_cabinets_hang2.map',(cx+510,752,118),180)
    if i in (0,3,5):
        prefab(f'bench_lantern_{i}','_prefabs/zm/zm_giant/geo/lantern_lit.map',(cx+485,716,37),0)
    if i in (1,3,5): props.append(('p7_zm_der_generator_01',cx+470,-700,0,180))
    for j,(model,x,y,z,yaw) in enumerate(props):
        emit(f'dressing_{i}_{j}',{'classname':'misc_model','model':model,'origin':g.point((x,y,z)),
             'angles':f'0 {yaw} 0'},layer='Eggstinction/Geometry')
egg_art.decorate(g,world_brushes,block)
build_models.prepare(BUILD)
build_admin_weapon.prepare(BUILD,TOOLS)

# Reuse the supported stock template structure and sound configuration.
for original in TEMPLATE.rglob('*'):
    if not original.is_file(): continue
    relative=str(original.relative_to(TEMPLATE)).replace('template',NAME)
    target=BUILD/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    if original.suffix.lower() in ('.map','.gsc','.csc','.zone','.szc','.csv','.json','.txt'):
        target.write_text(original.read_text(encoding='utf-8-sig').replace('template',NAME),encoding='utf-8')
    else:
        shutil.copyfile(original,target)

art=ROOT/'art/eggstinction-loading.png'
if art.is_file():
    for image_name in ('loadingimage.png','preview.png','zone/loadingimage.png','zone/previewimage.png'):
        shutil.copyfile(art,BUILD/f'usermaps/{NAME}'/image_name)
video=ROOT/f'art/video/{NAME}_load.mkv'
if video.is_file():
    videodir=BUILD/f'usermaps/{NAME}/zone/video'
    videodir.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(video,videodir/video.name)

audio_aliases=build_audio.prepare(BUILD)
soundconfig=BUILD/f'usermaps/{NAME}/sound/zoneconfig/{NAME}.szc'
soundconfig.write_text(soundconfig.read_text().replace('"Name" : "user_aliases"','"Name" : "eggstinction"').replace('"Filename" : "user_aliases.csv"','"Filename" : "eggstinction.csv"'))

import build_gobblegum
build_gobblegum.prepare(ROOT,BUILD,args.test)
server=BUILD/f'usermaps/{NAME}/scripts/zm/{NAME}.gsc'
s=server.read_text()
s=s.replace('#using scripts\\zm\\zm_usermap;', '#using scripts\\zm\\zm_usermap;\n#using scripts\\zm\\eggstinction;\n#using scripts\\zm\\egg_bgb_machine;')
s=s.replace('zm_usermap::main();','clientfield::register("toplayer","egg_upgrade_tier",VERSION_SHIP,2,"int");\n\tclientfield::register("toplayer","egg_reticle_mode",VERSION_SHIP,2,"int");\n\tzm_usermap::main();')
s=s.replace('zm_usermap::main();','level.dog_rounds_allowed = 1;\n\tlevel.dog_round_track_override = &eggstinction::dog_schedule;\n\tlevel.dog_spawn_func = &eggstinction::dog_spawn_point;\n\tzm_usermap::main();\n\tlevel.perk_purchase_limit = 8;\n\teggstinction::init();')
if args.test:
    s=s.replace('eggstinction::init();',f'level.egg_selftest_mode = "{args.test}";\n\teggstinction::init();')
s=s.replace('init_zones[0] = "start_zone";', 'init_zones[0] = "nest_zone";')
links=''
for i in range(5):
    links+=f'\n\tlevel flag::init("egg_open_{i}");\n\tzm_zonemgr::add_adjacent_zone("{g.ROOMS[i][0]}_zone", "{g.ROOMS[i+1][0]}_zone", "egg_open_{i}");'
s=s.replace('level flag::set( "always_on" );','level flag::set( "always_on" );'+links)
server.write_text(s,encoding='utf-8')
s=server.read_text().replace('zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);','zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);\n\tzm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/eggstinction_weapons.csv", 1);')
server.write_text(s,encoding='utf-8')
client=server.with_suffix('.csc')
c=client.read_text().replace('#using scripts\\zm\\zm_usermap;', '#using scripts\\zm\\zm_usermap;\n#using scripts\\zm\\egg_bgb_machine;').replace('util::waitforclient( 0 );','util::waitforclient( 0 );\n\tthread egg_hide_wallbuy_models();')
c=c.replace('zm_usermap::main();','clientfield::register("toplayer","egg_reticle_mode",VERSION_SHIP,2,"int",&egg_reticle_changed,!CF_HOST_ONLY,CF_CALLBACK_ZERO_ON_NEW_ENT);\n\tSetDvar("cg_drawCrosshair",1);\n\tzm_usermap::main();')
c=c.replace('zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);','zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);\n\tzm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/eggstinction_weapons.csv", 1);')
c=c.replace('function main()', '#precache("client_fx","zombie/fx_tesla_tube_view_zmb");\n#precache("client_fx","zombie/fx_tesla_tube_view_ug_zmb");\n#precache("client_fx","zombie/fx_tesla_rail_view_ug_zmb");\nfunction main()',1)
c=c.replace('SetDvar("cg_drawCrosshair",1);','clientfield::register("toplayer","egg_upgrade_tier",VERSION_SHIP,2,"int",&egg_tier_changed,!CF_HOST_ONLY,CF_CALLBACK_ZERO_ON_NEW_ENT);\n\tSetDvar("cg_drawCrosshair",1);',1)
c+='''
function egg_tier_changed(localClientNum,oldVal,newVal,bNewEnt,bInitialSnap,fieldName,bWasTimeJump)
{
    if(!IsDefined(level.egg_visual_tiers)) level.egg_visual_tiers=[];
    level.egg_visual_tiers[localClientNum]=newVal;
    __EGG_AURA_LOG__
}
function egg_weapon_aura(client)
{
    effect=undefined;
    while(true)
    {
        tier=0;
        if(IsDefined(level.egg_visual_tiers) && IsDefined(level.egg_visual_tiers[client])) tier=level.egg_visual_tiers[client];
        weapon=GetCurrentWeapon(client);
        if(IsDefined(effect)) {DeleteFx(client,effect,true);effect=undefined;}
        if(tier>0 && IsDefined(weapon) && weapon.name!="none" && weapon.name!="zombie_bgb_grab")
        {
            fx="zombie/fx_tesla_tube_view_zmb";
            if(tier==2) fx="zombie/fx_tesla_tube_view_ug_zmb";
            if(tier==3) fx="zombie/fx_tesla_rail_view_ug_zmb";
            effect=PlayViewmodelFx(client,fx,"tag_flash");
        }
        wait(0.65);
    }
}
function egg_start_auras()
{
    players=GetLocalPlayers();
    for(i=0;i<players.size;i++) thread egg_weapon_aura(i);
}

'''
c+=''' 
function egg_reticle_changed(localClientNum,oldVal,newVal,bNewEnt,bInitialSnap,fieldName,bWasTimeJump)
{
    if (newVal==0) SetDvar("cg_drawCrosshair",1);
    else SetDvar("cg_drawCrosshair",0);
}

// Keep chalk wall buys; omit the stock floating display guns after purchases.
function egg_hide_wallbuy_models()
{
    while (true)
    {
        if (IsDefined(level._active_wallbuys))
        {
            foreach (wallbuy in level._active_wallbuys)
                if (IsDefined(wallbuy.models))
                    foreach (model in wallbuy.models) if (IsDefined(model)) model Hide();
        }
        wait(0.05);
    }
}

// Cache only the permanent collision movers at their generated centres.
// Native reward models are separate entities and are never put in this list.
function egg_hide_collision_proxies()
{
    centres=[];
    __EGG_PROXY_CENTRES__
    proxies=[];
    while (true)
    {
        need_scan=false;
        for (i=0;i<centres.size;i++)
        {
            if (IsDefined(proxies[i])) proxies[i] Hide();
            else need_scan=true;
        }
        if (need_scan)
        {
            foreach (entity in GetEntArray(0))
            {
                if (!IsDefined(entity.type) || entity.type!="scriptmover" || !IsDefined(entity.origin)) continue;
                for (i=0;i<centres.size;i++)
                {
                    if (IsDefined(proxies[i])) continue;
                    if (DistanceSquared(entity.origin,centres[i])>0.1) continue;
                    proxies[i]=entity;
                    entity Hide();
                    __EGG_PROXY_LOG__
                }
            }
        }
        wait(0.1);
    }
}
'''
c=c.replace('__EGG_PROXY_CENTRES__','\n    '.join(f'centres[{i}]=({x},{y},{z});' for i,(x,y,z) in enumerate(box_clip_centres)))
probe=''
if args.test:
    probe='''message="EGGPROXY hidden collision mover at "+entity.origin;
                    if (IsDefined(entity.model)) message=message+" model="+entity.model;
                    /# PrintLn(message); #/'''
c=c.replace('__EGG_PROXY_LOG__',probe)
aura_probe=''
if args.test: aura_probe='message="EGGAURA tier="+newVal+" client="+localClientNum; /# PrintLn(message); #/'
c=c.replace('__EGG_AURA_LOG__',aura_probe)
c=c.replace('thread egg_hide_wallbuy_models();','thread egg_hide_wallbuy_models();\n\tthread egg_start_auras();')
if args.test:
    c+='''
function egg_dump_movers()
{
    wait(20);
    foreach(entity in GetEntArray(0))
    {
        if (!IsDefined(entity.type) || entity.type!="scriptmover") continue;
        model="none";if(IsDefined(entity.model)) model=entity.model;
        message="EGGMOVER "+entity.origin+" model="+model;
        /# PrintLn(message); #/
    }
}
'''
    c=c.replace('thread egg_hide_wallbuy_models();','thread egg_hide_wallbuy_models();\n\tthread egg_dump_movers();')

c=c.replace('thread egg_hide_wallbuy_models();','thread egg_hide_wallbuy_models();\n\tthread egg_hide_collision_proxies();')
client.write_text(c,encoding='utf-8')
# Restore the map-local stock copy byte-for-byte; global sources stay untouched.
client.with_name('_zm_magicbox.csc').write_text((TOOLS/'share/raw/scripts/zm/_zm_magicbox.csc').read_text(),encoding='utf-8')
runtime_source=(ROOT/'gameplay/eggstinction.gsc').read_text()
if args.test:
    runtime_source+='\n'+(ROOT/'gameplay/repair_test.gsc').read_text()
    weapon_rows=list(csv.DictReader((TOOLS/'share/raw/gamedata/weapons/zm/zm_levelcommon_weapons.csv').open()))
    weapon_names=sorted({row[field] for row in weapon_rows for field in ('weapon_name','upgrade_name')
                        if row.get(field) and row.get('class')!='grenade' and row.get('weapon_name') not in ('knife','bowie_knife','zod_riotshield','hero_gravityspikes_melee')})
    weapon_names.append('eggmin_cannon')
    audit='\nfunction weapon_sound_audit()\n{\n'
    for name in weapon_names:
        audit+=f'    weapon=GetWeapon("{name}");\n'
        audit+=f'    test_log("EGGWEAPON {name} player_field="+IsDefined(weapon.fireSoundPlayer)+" native_field="+IsDefined(weapon.firesoundplayer));\n    wait(0.03);\n'
        for field in ('firesound','firesoundplayer','loopfiresound','loopfiresoundplayer','loopfireendsound','loopfireendsoundplayer','startfiresound','startfiresoundplayer','reloadsound','reloadsoundplayer'):
            audit+=f'    alias=weapon.{field};\n    if (IsDefined(alias)) test_log("EGGSOUND {name} {field}: "+alias+" exists="+SoundExists(alias));\n    wait(0.03);\n'
    audit+='}\n'
    audit+='\nfunction map_sound_audit()\n{\n'
    dog_script=(TOOLS/'share/raw/scripts/zm/_zm_ai_dogs.gsc').read_text()
    dog_script=re.sub(r'/\*.*?\*/|//[^\n]*','',dog_script,flags=re.S)
    dog_aliases=re.findall(r'(?:playsound|playlocalsound|playsoundatposition|playloopsound)\s*\(\s*"([^"]+)"',dog_script,re.I)
    cannon_source=(BUILD/'source_data/eggstinction_admin.gdt').read_text()
    cannon_aliases=re.findall(r'"(?:loopFireSound|loopFireSoundPlayer|loopFireEndSound|loopFireEndSoundPlayer)"\s+"([^"]+)"',cannon_source)
    for alias in sorted(set(audio_aliases+dog_aliases+cannon_aliases)):
        audit+=f'    smoke_check("sound alias {alias}",SoundExists("{alias}"));\n    wait(0.04);\n'
    audit+='}\n'
    runtime_source+=audit
if not args.records:
    runtime_source=runtime_source.replace('    record_run("start");\n','')
    runtime_source=runtime_source.replace('        record_run("end");\n','')
    runtime_source=re.sub(r'function record_run\(event\)\n\{.*?\n\}\n', '', runtime_source, flags=re.S)
    runtime_source=runtime_source.replace('    record_run("end");\n','')
if not args.test:
    # Ship only gameplay. Test points, invulnerability and camera movement are
    # omitted from the normal compiled module, not merely toggled off.
    runtime_source=runtime_source.split('// Explicit development-only integration check.')[0]
    runtime_source=runtime_source.replace('    if (IsDefined(level.egg_selftest_mode) && self IsHost()) self thread smoke_test();\n','')
    runtime_source=runtime_source.replace('if (!IsDefined(level.egg_selftest_mode) || level.egg_selftest_mode != "audit") level thread selection_timeout();','level thread selection_timeout();')
    runtime_source=runtime_source.replace('    if (IsDefined(level.egg_selftest_mode) && level.egg_selftest_mode == "restart")\n        IPrintLn("EGGRESTART REQUEST instant="+instant);\n','')
server.with_name('eggstinction.gsc').write_text(runtime_source,encoding='utf-8')
zone=BUILD/f'usermaps/{NAME}/zone_source/{NAME}.zone'
zone.write_text(zone.read_text()+'\nscriptparsetree,scripts/zm/eggstinction.gsc\nxmodel,egg_bulkhead\nxmodel,egg_hatchery_beast\nweapon,eggmin_cannon\nstringtable,gamedata/weapons/zm/eggstinction_weapons.csv\n',encoding='utf-8')
zone.write_text(zone.read_text()+'\nscriptparsetree,scripts/zm/_zm_magicbox.csc\n',encoding='utf-8')
zone.write_text(zone.read_text()+'\nxmodel,tag_origin\nstringtable,gamedata/weapons/zm/zm_levelcommon_bgb.csv\nscriptparsetree,scripts/zm/egg_bgb_machine.gsc\nscriptparsetree,scripts/zm/egg_bgb_machine.csc\n',encoding='utf-8')

head=['iwmap 4','"script_startingnumber" 0','"Eggstinction" flags expanded active',
      '"Eggstinction/Geometry" flags','"Eggstinction/Gameplay" flags','"Eggstinction/Lights" flags',
      '"_prefabs" flags prefab expanded']
head += [f'"{p}" flags prefab' for p in sorted(prefabs)]
lines=head+['// entity 0','{',f'guid "{g.guid("playable/world")}"','layer "Eggstinction/Geometry"']
lines += [f'"{k}" "{v}"' for k,v in world.items()]
for i,(label,brush) in enumerate(world_brushes): lines += [f'// brush {i} : {label}',brush]
lines+=['}',*entities]
mapfile=BUILD/f'map_source/zm/{NAME}.map'
mapfile.write_text('\n'.join(lines)+'\n',encoding='utf-8')
report={'name':NAME,'world_brushes':len(world_brushes),'entities':len(entities)+1,
        'stock_prefabs':sorted(prefabs),'gameplay_status':'source integrated; compilation and playtest pending',
        'BO6_pack':'public download quota exceeded; stock weapons used',
        'widows_wine':'not included in first build; seven standard perks placed'}
(ROOT/'project-status.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
