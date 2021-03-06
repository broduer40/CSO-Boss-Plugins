#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>

#define PLUGIN "Mad Machine"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define MM_MODEL "models/mad_machine/mad_machine.mdl"
#define MM_CLASSNAME "mad_machine"

#define MM_HEALTH 10000.0
#define MM_MOVESPEED 150.0
#define MM_ATTACK_RANGE 300.0
#define HEALTH_OFFSET 10000.0

// Start Origin
#define STARTORIGIN_X 0.0
#define STARTORIGIN_Y 0.0
#define STARTORIGIN_Z 100.0

// Attack 1
#define ATTACK1_RADIUS 300.0
#define ATTACK1_DAMAGE random_float(7.5, 12.5)

// Attack 2
#define ATTACK2_RADIUS 300.0
#define ATTACK2_DAMAGE random_float(10.0, 17.0)

// Laser
#define LASER_LIGHTDOT_SPR "sprites/3dmflared.spr"
#define LASER_DAMAGE random_float(10.0, 15.0)

// Flame
#define FLAME_SPR "sprites/mm_fire.spr"
#define FLAME_DAMAGE random_float(25.0, 50.0)

#define FIRE_CLASSNAME "fire"
#define FIRE_SPEED 1000.0

// Task
#define TASK_ATTACK 1962+100
#define TASK_ATTACK_LASER 1962+200
#define TASK_ATTACK_LASERING 1962+300
#define TASK_ATTACK_LASERFLAME 1962+600
#define TASK_ATTACK_FLAME 1962+400
#define TASK_ATTACK_FLAMING 1962+500

enum
{
	MM_ANIM_DUMMY = 0,
	MM_ANIM_IDLE,
	MM_ANIM_WALK,
	MM_ANIM_RUN,
	MM_ANIM_ATTACK1,
	MM_ANIM_ATTACK2,
	MM_ANIM_ATTACK_FLAME,
	MM_ANIM_ATTACK_LASER,
	MM_ANIM_JUMP_START,
	MM_ANIM_JUMP_LOOP,
	MM_ANIM_JUMP_END,
	MM_ANIM_SCENE01,
	MM_ANIM_DEATH
}

enum
{
	MM_STATE_IDLE = 0,
	MM_STATE_SEARCHING_ENEMY,
	MM_STATE_CHASE_ENEMY,
	MM_STATE_ATTACK_NORMAL,
	MM_STATE_ATTACK_FLAME,
	MM_STATE_ATTACK_LASER,
	MM_STATE_JUMP_START,
	MM_STATE_JUMP_LOOP,
	MM_STATE_JUMP_END,
	MM_STATE_SCENE01,
	MM_STATE_DEATH
}

#define MAX_SOUND 10
new const MM_Sound[MAX_SOUND][] =
{
	"mad_machine/mm_walk.wav",
	"mad_machine/mm_attack1.wav",
	"mad_machine/mm_attack2.wav",
	"mad_machine/mm_attack_flame.wav",
	"mad_machine/mm_attack_flame1.wav",
	"mad_machine/mm_lazer.wav",
	"mad_machine/mm_attack_jump1.wav",
	"mad_machine/mm_attack_jump3.wav",
	"mad_machine/mm_scene03.wav",
	"mad_machine/mm_death.wav"
}

enum
{
	MM_SOUND_WALK = 0,
	MM_SOUND_ATTACK1,
	MM_SOUND_ATTACK2,
	MM_SOUND_ATTACK_FLAME,
	MM_SOUND_FLAMING,
	MM_SOUND_ATTACK_LASER,
	MM_SOUND_JUMP_BEGIN,
	MM_SOUND_JUMP_END,
	MM_SOUND_SCENE03,
	MM_SOUND_DEATH
}


const pev_state = pev_iuser1
const pev_time = pev_fuser1
const pev_time2 = pev_fuser2

new g_MM_Ent, g_LC_Ent, g_Reg_Ham, LASER_LIGHTDOT_SPRID
new g_Msg_ScreenShake, g_MaxPlayers

new BeamSpr_Id, m_iBlood[2]
new Float:StartOrigin[3]

#define FIGHT_MUSIC "cso_angra/bg/Scenario_Normal.mp3"

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_think(MM_CLASSNAME, "fw_MM_Think")
	register_think("AutoRemove", "fw_AM_Think")
	register_think("LaserControl", "fw_LC_Think")
	register_think("FlameControl", "fw_FC_Think")
	
	register_think(FIRE_CLASSNAME, "fw_Fire_Think")
	register_touch(FIRE_CLASSNAME, "*", "fw_Fire_Touch")	
	
	g_Msg_ScreenShake = get_user_msgid("ScreenShake")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "get_origin")
	register_clcmd("say /mm", "Create_MadMachine")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, MM_MODEL)
	
	for(new i = 0; i < sizeof(MM_Sound); i++)
		engfunc(EngFunc_PrecacheSound, MM_Sound[i])
		
	BeamSpr_Id = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
	
	LASER_LIGHTDOT_SPRID = engfunc(EngFunc_PrecacheModel, LASER_LIGHTDOT_SPR)
	engfunc(EngFunc_PrecacheModel, FLAME_SPR)
}

public get_origin(id)
{
	static Float:Origin[3]
	pev(id, pev_origin, StartOrigin)
	Origin = StartOrigin
	
	client_print(id, print_console, "%f %f %f", Origin[0], Origin[1], Origin[2])
}

public Create_MadMachine(id)
{
	if(pev_valid(g_MM_Ent))
		engfunc(EngFunc_RemoveEntity, g_MM_Ent)
	
	static MM; MM = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(MM)) return
	
	g_MM_Ent = MM

	// Set Origin & Angles
	StartOrigin[0] = STARTORIGIN_X; StartOrigin[1] = STARTORIGIN_Y; StartOrigin[2] = STARTORIGIN_Z
	set_pev(MM, pev_origin, StartOrigin)
	
	// Set Config
	set_pev(MM, pev_classname, MM_CLASSNAME)
	engfunc(EngFunc_SetModel, MM, MM_MODEL)
		
	set_pev(MM, pev_gamestate, 1)
	set_pev(MM, pev_solid, SOLID_BBOX)
	set_pev(MM, pev_movetype, MOVETYPE_NONE)
	
	// Set Size
	new Float:maxs[3] = {72.0, 72.0, 172.0}
	new Float:mins[3] = {-72.0, -72.0, 22.0}
	engfunc(EngFunc_SetSize, MM, mins, maxs)
	
	// Set Life
	set_pev(MM, pev_takedamage, DAMAGE_YES)
	set_pev(MM, pev_health, HEALTH_OFFSET + MM_HEALTH)
	
	// Set Config 2
	set_entity_anim(MM, MM_ANIM_IDLE, 1.0, 1)
	set_pev(MM, pev_state, MM_STATE_IDLE)
	
	set_pev(MM, pev_nextthink, get_gametime() + 3.0)
	engfunc(EngFunc_DropToFloor, MM)
	
	if(!g_Reg_Ham)
	{
		g_Reg_Ham = 1
		RegisterHamFromEntity(Ham_TraceAttack, MM, "fw_MM_TraceAttack")
	}
	
	PlaySound(0, FIGHT_MUSIC)
}

public MM_Death(ent)
{
	if(!pev_valid(ent))
		return
	
	remove_task(ent+TASK_ATTACK)
	remove_task(ent+TASK_ATTACK_LASER)
	remove_task(ent+TASK_ATTACK_LASERING)
	remove_task(ent+TASK_ATTACK_LASERFLAME)
	remove_task(ent+TASK_ATTACK_FLAME)
	remove_task(ent+TASK_ATTACK_FLAMING)
	
	Remove_LaserControl()	
	
	set_pev(ent, pev_state, MM_STATE_DEATH)

	set_pev(ent, pev_solid, SOLID_NOT)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	
	set_task(0.1, "MM_Death2", ent)
}

public MM_Death2(ent)
{
	set_task(1.5, "MM_Death_Sound", ent)
	set_entity_anim(ent, MM_ANIM_DEATH, 1.0, 1)
}

public MM_Death_Sound(ent)
{
	EmitSound(ent, MM_Sound[MM_SOUND_DEATH], CHAN_BODY)
}

public fw_MM_Think(ent)
{
	if(!pev_valid(ent))
		return
	if(pev(ent, pev_state) == MM_STATE_DEATH)
		return
	if((pev(ent, pev_health) - HEALTH_OFFSET) <= 0.0)
	{
		MM_Death(ent)
		return
	}
	
	// Set Next Think
	set_pev(ent, pev_nextthink, get_gametime() + 0.01)
	
	if(get_gametime() - 7.0 > pev(ent, pev_fuser4))
	{
		static RandomNum; RandomNum = random_num(0, 1)
	
		if(RandomNum == 1)
			MM_Attack_Laser(ent)
		else
			MM_Attack_Flame(ent)
			
		set_pev(ent, pev_fuser4, get_gametime())
	}
	
	switch(pev(ent, pev_state))
	{
		case MM_STATE_IDLE:
		{
			if(get_gametime() - 12.0 > pev(ent, pev_time))
			{
				set_entity_anim(ent, MM_ANIM_IDLE, 1.0, 1)
				set_pev(ent, pev_time, get_gametime())
			}
			if(get_gametime() - 1.0 > pev(ent, pev_time2))
			{
				set_pev(ent, pev_state, MM_STATE_SEARCHING_ENEMY)
				set_pev(ent, pev_time2, get_gametime())
			}			
		}
		case MM_STATE_SEARCHING_ENEMY:
		{
			static Victim;
			Victim = FindClosetEnemy(ent, 1)
			
			if(is_user_alive(Victim))
			{
				set_pev(ent, pev_enemy, Victim)
				Random_AttackMethod(ent)
			} else {
				set_pev(ent, pev_enemy, 0)
				set_pev(ent, pev_state, MM_STATE_IDLE)
			}
		}
		case MM_STATE_CHASE_ENEMY:
		{
			static Enemy; Enemy = pev(ent, pev_enemy)
			static Float:EnemyOrigin[3]
			pev(Enemy, pev_origin, EnemyOrigin)
			
			if(is_user_alive(Enemy))
			{
				if(entity_range(Enemy, ent) <= floatround(MM_ATTACK_RANGE))
				{
					set_pev(ent, pev_state, MM_STATE_ATTACK_NORMAL)
					set_entity_anim(ent, MM_ANIM_IDLE, 1.0, 1)
					MM_Aim_To(ent, EnemyOrigin) 
					
					if(random_num(0, 1) == 1)
						set_task(0.1, "MM_StartAttack1", ent+TASK_ATTACK)
					else 
						set_task(0.1, "MM_StartAttack2", ent+TASK_ATTACK)
				} else {
					if(pev(ent, pev_movetype) == MOVETYPE_PUSHSTEP)
					{
						static Float:OriginAhead[3]
						get_position(ent, 300.0, 0.0, 0.0, OriginAhead)
						
						MM_Aim_To(ent, EnemyOrigin) 
						hook_ent2(ent, OriginAhead, MM_MOVESPEED)
						
						set_entity_anim(ent, MM_ANIM_RUN, 1.0, 0)
						if(get_gametime() - 1.0 > pev(ent, pev_time))
						{
							EmitSound(ent, MM_Sound[MM_SOUND_WALK], CHAN_ITEM)
							set_pev(ent, pev_time, get_gametime())
						}
					} else {
						set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP)
					}
				}
			} else {
				set_pev(ent, pev_state, MM_STATE_SEARCHING_ENEMY)
			}
		}
	}
}

public fw_AM_Think(ent)
{
	if(!pev_valid(ent))
		return
		
	engfunc(EngFunc_RemoveEntity, ent)
}

public fw_MM_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_valid_ent(Ent)) 
		return
     
	static Classname[32]
	pev(Ent, pev_classname, Classname, charsmax(Classname)) 
	     
	if(!equal(Classname, MM_CLASSNAME)) 
		return
		 
	static Float:EndPos[3] 
	get_tr2(ptr, TR_vecEndPos, EndPos)

	create_blood(EndPos)
	if(is_user_alive(Attacker)) client_print(Attacker, print_center, "Mad Machine's Health: %i", floatround(pev(Ent, pev_health) - HEALTH_OFFSET))
}

public Random_AttackMethod(ent)
{
	static RandomNum; RandomNum = random_num(1, 99)
	
	if(RandomNum >= 0 && RandomNum <= 60)
		set_pev(ent, pev_state, MM_STATE_CHASE_ENEMY)
	else if(RandomNum >= 61 && RandomNum <= 80)
		MM_Attack_Laser(ent)
	else if(RandomNum >= 81 && RandomNum <= 100)
		MM_Attack_Flame(ent)
	else
		Random_AttackMethod(ent)
}

public MM_StartAttack1(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})	

	set_task(0.1, "MM_StartAttack1_2", ent+TASK_ATTACK)
}

public MM_StartAttack2(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})	

	set_task(0.1, "MM_StartAttack2_2", ent+TASK_ATTACK)	
}

public MM_StartAttack1_2(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
		
	set_entity_anim(ent, MM_ANIM_ATTACK1, 1.0, 1)
	set_task(0.5, "Attack1_Sound", ent)
	
	set_task(1.3, "MM_CheckAttack1", ent+TASK_ATTACK)
	set_task(3.3, "MM_DoneAttack", ent+TASK_ATTACK)	
}

public Attack1_Sound(ent)
{
	EmitSound(ent, MM_Sound[MM_SOUND_ATTACK1], CHAN_BODY)
}

public MM_StartAttack2_2(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
		
	set_entity_anim(ent, MM_ANIM_ATTACK2, 1.0, 1)
	EmitSound(ent, MM_Sound[MM_SOUND_ATTACK2], CHAN_BODY)
	
	set_task(1.0, "MM_Attack2_Effect", ent+TASK_ATTACK)
	set_task(1.0, "MM_CheckAttack2", ent+TASK_ATTACK)
	set_task(3.3, "MM_DoneAttack", ent+TASK_ATTACK)	
}

public MM_Attack2_Effect(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
	
	// Not Found
}

public MM_CheckAttack1(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return
		
	static Float:CheckPosition[3], Float:VicOrigin[3]
	get_position(ent, 200.0, 80.0, 0.0, CheckPosition)
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
			
		pev(i, pev_origin, VicOrigin)
		if(get_distance_f(VicOrigin, CheckPosition) > ATTACK1_RADIUS)
			continue
			
		ExecuteHamB(Ham_TakeDamage, i, 0, i, ATTACK1_DAMAGE, DMG_BLAST)
		
		static Float:Velocity[3]
		Velocity[0] = random_float(100.0, 200.0)
		Velocity[1] = random_float(100.0, 200.0)
		Velocity[2] = random_float(100.0, 400.0)
		set_pev(i, pev_velocity, Velocity)
		
		Make_PlayerShake(i)
	}
}

public MM_CheckAttack2(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return

	static Float:CheckPosition[3], Float:VicOrigin[3]
	pev(ent, pev_origin, CheckPosition)
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
			
		pev(i, pev_origin, VicOrigin)
		if(get_distance_f(VicOrigin, CheckPosition) > ATTACK2_RADIUS)
			continue
			
		ExecuteHamB(Ham_TakeDamage, i, 0, i, ATTACK2_DAMAGE, DMG_BLAST)
		Make_PlayerShake(i)
	}	
}

public MM_DoneAttack(ent)
{
	ent -= TASK_ATTACK
	if(!pev_valid(ent))
		return	
		
	set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP)		
	set_pev(ent, pev_state, MM_STATE_CHASE_ENEMY)
}

public MM_Attack_Laser(ent) 
{ 
	if((pev(ent, pev_state) == MM_STATE_CHASE_ENEMY || pev(ent, pev_state) == MM_STATE_IDLE)/* && is_user_alive(pev(ent, pev_enemy))*/)
	{
		set_pev(ent, pev_state, MM_STATE_ATTACK_LASER)
		set_pev(ent, pev_movetype, MOVETYPE_NONE)
		set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})	
		
		set_task(0.1, "MM_Start_Attack_Laser", ent+TASK_ATTACK_LASER)
	}
}

public MM_Start_Attack_Laser(ent)
{
	ent -= TASK_ATTACK_LASER
	if(!pev_valid(ent))
		return	
		
	set_entity_anim(ent, MM_ANIM_ATTACK_LASER, 1.0, 1)
	EmitSound(ent, MM_Sound[MM_SOUND_ATTACK_FLAME], CHAN_BODY)
	set_task(1.35, "MM_StartLaser", ent+TASK_ATTACK_LASER)
	set_task(8.6, "MM_Done_Attack_Laser_AND_Flame", ent+TASK_ATTACK_LASERFLAME)
}

public MM_StartLaser(ent)
{
	ent -= TASK_ATTACK_LASER
	if(!pev_valid(ent))
		return	
		
	PlaySound(0, MM_Sound[MM_SOUND_ATTACK_LASER])
	Create_LaserControl(ent)
	set_task(3.3, "Stop_Laser", ent+TASK_ATTACK_LASER)
}

public Create_LaserControl(ent)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent))
		return
		
	g_LC_Ent = Ent
		
	static Float:Vector[3]
	
	pev(ent, pev_origin, Vector); set_pev(Ent, pev_origin, Vector)
	pev(ent, pev_angles, Vector); set_pev(Ent, pev_angles, Vector)
	
	// Set Config
	set_pev(Ent, pev_classname, "LaserControl")
	engfunc(EngFunc_SetModel, Ent, MM_MODEL)
		
	set_pev(Ent, pev_gamestate, 1)
	set_pev(Ent, pev_solid, SOLID_NOT)
	set_pev(Ent, pev_movetype, MOVETYPE_NONE)
	
	set_pev(Ent, pev_iuser1, 1)
	set_pev(Ent, pev_fuser1, Vector[1])
	
	// Set Size
	new Float:maxs[3] = {72.0, 72.0, 172.0}
	new Float:mins[3] = {-72.0, -72.0, 22.0}
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	fm_set_rendering(Ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0)
	
	engfunc(EngFunc_DropToFloor, Ent)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	set_task(0.01, "Create_Laser2", Ent+TASK_ATTACK_LASERING)
	set_task(1.35, "Rotate_Right", Ent+TASK_ATTACK_LASERFLAME)
}

public Rotate_Right(ent)
{
	ent -= TASK_ATTACK_LASERFLAME
	if(!pev_valid(ent))
		return
	
	set_pev(ent, pev_iuser1, 2)
}

public Remove_LaserControl()
{
	remove_task(g_LC_Ent+TASK_ATTACK_FLAMING)
	remove_task(g_LC_Ent+TASK_ATTACK_LASERING)
	
	if(pev_valid(g_LC_Ent)) engfunc(EngFunc_RemoveEntity, g_LC_Ent)
}

public Create_Laser(ent)
{
	ent -= TASK_ATTACK_LASERING
	if(!pev_valid(ent))
		return		
	
	static Float:Origin[3], Float:TargetOrigin[3]
	if(pev(ent, pev_iuser1) == 1)
		get_position(ent, 130.0, 100.0, 50.0, Origin)
	else
		get_position(ent, 120.0, 100.0, 50.0, Origin)
		
	get_position(ent, 2000.0, 100.0, 0.0, TargetOrigin)
		
	static Trace_Result; Trace_Result = 0
	engfunc(EngFunc_TraceLine, Origin, TargetOrigin, DONT_IGNORE_MONSTERS, g_MM_Ent, Trace_Result)
		
	static Float:EndPos[3]
	get_tr2(Trace_Result, TR_vecEndPos, EndPos)
	
	EndPos[2] /= 1.5
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, EndPos[0])
	engfunc(EngFunc_WriteCoord, EndPos[1])
	engfunc(EngFunc_WriteCoord, EndPos[2])
	write_short(BeamSpr_Id)    // sprite index
	write_byte(1)	// starting frame
	write_byte(1)	// frame rate in 0.1's
	write_byte(5)	// life in 0.1's
	write_byte(70)	// line width in 0.1's
	write_byte(0)	// noise amplitude in 0.01's
	write_byte(255)	// Red
	write_byte(0)	// Green
	write_byte(0)	// Blue
	write_byte(255)	// brightness
	write_byte(0)	// scroll speed in 0.1's
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, EndPos[0])
	engfunc(EngFunc_WriteCoord, EndPos[1])
	engfunc(EngFunc_WriteCoord, EndPos[2])
	write_short(BeamSpr_Id)    // sprite index
	write_byte(1)	// starting frame
	write_byte(1)	// frame rate in 0.1's
	write_byte(5)	// life in 0.1's
	write_byte(20)	// line width in 0.1's
	write_byte(0)	// noise amplitude in 0.01's
	write_byte(255)	// Red
	write_byte(255)	// Green
	write_byte(85)	// Blue
	write_byte(255)	// brightness
	write_byte(0)	// scroll speed in 0.1's
	message_end()	
	
	engfunc(EngFunc_TraceLine, Origin, EndPos, DONT_IGNORE_MONSTERS, g_MM_Ent, Trace_Result)
	
	static pHit; pHit = get_tr2(Trace_Result, TR_pHit)
	if(pev_valid(pHit)) ExecuteHamB(Ham_TakeDamage, pHit, 0, pHit, LASER_DAMAGE, DMG_BLAST)
}

public Create_Laser2(ent)
{
	ent -= TASK_ATTACK_LASERING
	if(!pev_valid(ent))
		return		
	
	static Float:Origin[3]
	if(pev(ent, pev_iuser1) == 1)
		get_position(ent, 130.0, 100.0, 50.0, Origin)
	else
		get_position(ent, 120.0, 100.0, 50.0, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(LASER_LIGHTDOT_SPRID)
	write_byte(30)
	write_byte(255)
	message_end()
	
	set_task(0.1, "Create_Laser2", ent+TASK_ATTACK_LASERING)
}

public Stop_Laser(ent)
{
	ent -= TASK_ATTACK_LASER
	if(!pev_valid(ent))
		return		
	
	remove_task(ent+TASK_ATTACK_LASERING)
	Remove_LaserControl()
}

public fw_LC_Think(ent)
{
	if(!pev_valid(ent))
		return
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.025)
	
	static Float:Vector[3]
	pev(ent, pev_angles, Vector)
	
	if(pev(ent, pev_iuser1) == 1) // Rotating to the Right
	{
		Vector[1] -= 1.125
		set_pev(ent, pev_angles, Vector)
	} else if(pev(ent, pev_iuser1) == 2) {  // Rotating to the Left
		Vector[1] += 1.5
		set_pev(ent, pev_angles, Vector)
	}
	
	if(get_gametime() - 0.1 > pev(ent, pev_fuser4))
	{
		Create_Laser(ent+TASK_ATTACK_LASERING)
		set_pev(ent, pev_fuser4, get_gametime())
	}
}

public MM_Attack_Flame(ent) 
{ 
	if((pev(ent, pev_state) == MM_STATE_CHASE_ENEMY || pev(ent, pev_state) == MM_STATE_IDLE)/* && is_user_alive(pev(ent, pev_enemy))*/)
	{
		set_pev(ent, pev_state, MM_STATE_ATTACK_FLAME)
		set_pev(ent, pev_movetype, MOVETYPE_NONE)
		set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})	
		
		set_task(0.1, "MM_Start_Attack_Flame", ent+TASK_ATTACK_FLAME)
	}
}

public MM_Start_Attack_Flame(ent)
{
	ent -= TASK_ATTACK_FLAME
	if(!pev_valid(ent))
		return	
		
	EmitSound(ent, MM_Sound[MM_SOUND_ATTACK_FLAME], CHAN_BODY)
	
	set_entity_anim(ent, MM_ANIM_ATTACK_FLAME, 1.0, 1)
	set_task(1.35, "MM_StartFlame", ent+TASK_ATTACK_FLAME)
	set_task(8.6, "MM_Done_Attack_Laser_AND_Flame", ent+TASK_ATTACK_LASERFLAME)
}

public MM_StartFlame(ent)
{
	ent -= TASK_ATTACK_FLAME
	if(!pev_valid(ent))
		return	
		
	PlaySound(0, MM_Sound[MM_SOUND_FLAMING])
	Create_FlameControl(ent)
	set_task(3.3, "Stop_Flame", ent+TASK_ATTACK_FLAME)
}

public Create_Flame(ent)
{
	ent -= TASK_ATTACK_FLAMING
	if(!pev_valid(ent))
		return		
	
	static Float:Origin[3], Float:TargetOrigin[3]
	if(pev(ent, pev_iuser1) == 1)
		get_position(ent, 130.0, -100.0, 50.0, Origin)
	else
		get_position(ent, 120.0, -100.0, 50.0, Origin)
		
	get_position(ent, 2000.0, -100.0, 25.0, TargetOrigin)
	create_fire(ent, Origin, TargetOrigin, FIRE_SPEED)
}

public Create_FlameControl(ent)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent))
		return
		
	g_LC_Ent = Ent
		
	static Float:Vector[3]
	
	pev(ent, pev_origin, Vector); set_pev(Ent, pev_origin, Vector)
	pev(ent, pev_angles, Vector); set_pev(Ent, pev_angles, Vector)
	
	// Set Config
	set_pev(Ent, pev_classname, "FlameControl")
	engfunc(EngFunc_SetModel, Ent, MM_MODEL)
		
	set_pev(Ent, pev_gamestate, 1)
	set_pev(Ent, pev_solid, SOLID_NOT)
	set_pev(Ent, pev_movetype, MOVETYPE_NONE)
	
	set_pev(Ent, pev_iuser1, 1)
	set_pev(Ent, pev_fuser1, Vector[1])
	
	// Set Size
	new Float:maxs[3] = {72.0, 72.0, 172.0}
	new Float:mins[3] = {-72.0, -72.0, 22.0}
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	fm_set_rendering(Ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0)
	
	engfunc(EngFunc_DropToFloor, Ent)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	set_task(0.1, "Create_Flame", Ent+TASK_ATTACK_FLAMING, _, _, "b")
	set_task(1.35, "Rotate_Right", Ent+TASK_ATTACK_LASERFLAME)
}

public fw_FC_Think(ent)
{
	if(!pev_valid(ent))
		return
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.025)
	
	static Float:Vector[3]
	pev(ent, pev_angles, Vector)
	
	if(pev(ent, pev_iuser1) == 1) // Rotating to the Right
	{
		Vector[1] -= 1.125
		set_pev(ent, pev_angles, Vector)
	} else if(pev(ent, pev_iuser1) == 2) {  // Rotating to the Left
		Vector[1] += 1.5
		set_pev(ent, pev_angles, Vector)
	}
}

public create_fire(id, Float:Origin[3], Float:TargetOrigin[3], Float:Speed)
{
	new iEnt = create_entity("env_sprite")
	static Float:vfAngle[3], Float:MyOrigin[3], Float:Velocity[3]
	
	pev(id, pev_angles, vfAngle)
	pev(id, pev_origin, MyOrigin)
	
	vfAngle[2] = float(random(18) * 20)

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	set_pev(iEnt, pev_rendermode, kRenderTransAdd)
	set_pev(iEnt, pev_renderamt, 250.0)
	set_pev(iEnt, pev_fuser1, get_gametime() + 2.5)	// time remove
	set_pev(iEnt, pev_scale, 1.0)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	
	set_pev(iEnt, pev_classname, FIRE_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, FLAME_SPR)
	set_pev(iEnt, pev_mins, Float:{-10.0, -10.0, -10.0})
	set_pev(iEnt, pev_maxs, Float:{10.0, 10.0, 10.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_angles, vfAngle)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_frame, 0.0)
	
	get_speed_vector(Origin, TargetOrigin, Speed, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)
}

public fw_Fire_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	new Float:fFrame, Float:fNextThink, Float:fScale
	pev(iEnt, pev_frame, fFrame)
	pev(iEnt, pev_scale, fScale)
	
	// effect exp
	new iMoveType = pev(iEnt, pev_movetype)
	if (iMoveType == MOVETYPE_NONE)
	{
		fNextThink = 0.0015
		fFrame += 0.5
		
		if (fFrame > 21.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
	}
	
	// effect normal
	else
	{
		fNextThink = 0.045
		
		fFrame += 0.5
		fScale += 0.01
		
		fFrame = floatmin(21.0, fFrame)
		fScale = floatmin(5.0, fFrame)
	}
	
	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, fScale)
	set_pev(iEnt, pev_nextthink, halflife_time() + fNextThink)
	
	// time remove
	new Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
}

public fw_Fire_Touch(ent, id)
{
	if(!pev_valid(ent))
		return
		
	if(pev_valid(id))
	{
		static Classname[32]
		pev(id, pev_classname, Classname, sizeof(Classname))
		
		if(equal(Classname, FIRE_CLASSNAME)) return
		else if(equal(Classname, "player")) {
			if(is_user_alive(id)) ExecuteHamB(Ham_TakeDamage, id, 0, id, FLAME_DAMAGE, DMG_BURN)
		}
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}

public Stop_Flame(ent)
{
	ent -= TASK_ATTACK_FLAME
	if(!pev_valid(ent))
		return	
		
	remove_task(ent+TASK_ATTACK_FLAMING)
	Remove_LaserControl()
}

public MM_Done_Attack_Laser_AND_Flame(ent)
{
	ent -= TASK_ATTACK_LASERFLAME
	if(!pev_valid(ent))
		return	
		
	remove_task(ent+TASK_ATTACK_LASER)
	remove_task(ent+TASK_ATTACK_LASER)
	remove_task(ent+TASK_ATTACK_LASERING)
	remove_task(ent+TASK_ATTACK_LASERFLAME)
	remove_task(ent+TASK_ATTACK_FLAME)
	remove_task(ent+TASK_ATTACK_FLAMING)
	
	Remove_LaserControl()
	
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})	
	
	set_task(0.1, "Reset_Idle", ent)
}

public Reset_Idle(ent)
{
	set_entity_anim(ent, MM_ANIM_IDLE, 1.0, 1)
	set_pev(ent, pev_state, MM_STATE_SEARCHING_ENEMY)
}

public MM_Aim_To(ent, Float:Origin[3]) 
{
	if(!pev_valid(ent))	
		return
		
	static Float:Vec[3], Float:Angles[3]
	pev(ent, pev_origin, Vec)
	
	Vec[0] = Origin[0] - Vec[0]
	Vec[1] = Origin[1] - Vec[1]
	Vec[2] = Origin[2] - Vec[2]
	engfunc(EngFunc_VecToAngles, Vec, Angles)
	Angles[0] = Angles[2] = 0.0 
	
	set_pev(ent, pev_angles, Angles)
}

stock EmitSound(ent, const SoundFile[], Channel)
{
	if(!pev_valid(ent))
		return
		
	emit_sound(ent, Channel, SoundFile, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

stock set_entity_anim(ent, anim, Float:framerate, resetframe)
{
	if(!pev_valid(ent))
		return
	
	if(!resetframe)
	{
		if(pev(ent, pev_sequence) != anim)
		{
			set_pev(ent, pev_animtime, get_gametime())
			set_pev(ent, pev_framerate, framerate)
			set_pev(ent, pev_sequence, anim)
		}
	} else {
		set_pev(ent, pev_animtime, get_gametime())
		set_pev(ent, pev_framerate, framerate)
		set_pev(ent, pev_sequence, anim)
	}
}

public FindClosetEnemy(ent, can_see)
{
	new Float:maxdistance = 4980.0
	new indexid = 0	
	new Float:current_dis = maxdistance

	for(new i = 1 ;i <= g_MaxPlayers; i++)
	{
		if(can_see)
		{
			if(is_user_alive(i) && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		} else {
			if(is_user_alive(i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}			
		}
	}	
	
	return indexid
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}

public Make_PlayerShake(id)
{
	if(!id) 
	{
		message_begin(MSG_BROADCAST, g_Msg_ScreenShake)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	} else {
		if(!is_user_connected(id))
			return
			
		message_begin(MSG_BROADCAST, g_Msg_ScreenShake, _, id)
		write_short(8<<12)
		write_short(5<<12)
		write_short(4<<12)
		message_end()
	}
}

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	if(!pev_valid(ent))
		return
		
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_angles, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

stock create_blood(const Float:origin[3])
{
	// Show some blood :)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(5)
	message_end()
}

stock PlaySound(id, const sound[])
{
	if (equal(sound[strlen(sound)-4], ".mp3"))
		client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else
		client_cmd(id, "spk ^"%s^"", sound)
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}
