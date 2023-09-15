#pragma semicolon 1
#pragma newdecls required

#define NEUVELLETE_MAIN_BEAM_SOUND "npc/combine_gunship/dropship_engine_distant_loop1.wav"	//"weapons/physcannon/energy_sing_loop4.wav"

#define NEUVELLETE_THROTTLE_SPEED 5.0/66.0	//this thing was a bitch to try and figure out correctly the timings, and even then its not perfect
#define NEUVELLETE_TE_DURATION 5.5/66.0

#define MAX_NEUVELLETE_TARGETS_HIT 10	//how many targets the laser can penetrate BASELINE!!!!

static Handle h_TimerNeuvellete_Management[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
static float fl_hud_timer[MAXTF2PLAYERS+1];

static float BEAM_Targets_Hit[MAXTF2PLAYERS+1];
static int BEAM_BuildingHit[MAX_NEUVELLETE_TARGETS_HIT+6];
static bool BEAM_HitDetected[MAXTF2PLAYERS+1];
static bool b_special_active[MAXTF2PLAYERS+1];
static float fl_beam_angle[MAXTF2PLAYERS+1][2];
static float fl_throttle[MAXTF2PLAYERS+1];
static float fl_throttle2[MAXTF2PLAYERS+1];
static float fl_extra_effects_timer[MAXTF2PLAYERS + 1];
static float fl_m2_timer[MAXTF2PLAYERS + 1];
static int i_Neuvellete_penetration[MAXTF2PLAYERS + 1];

static float fl_Neuvellete_Beam_Timeout[MAXTF2PLAYERS + 1];
static bool b_skill_points_give_at_pap[MAXTF2PLAYERS + 1][7];
static int i_skill_point_used[MAXTF2PLAYERS + 1];
static int i_Neuvellete_HEX_Array[MAXTF2PLAYERS + 1];
static int i_Neuvellete_Skill_Points[MAXTF2PLAYERS + 1];

static float fl_Special_Timer[MAXTF2PLAYERS + 1];

static int BeamWand_Laser;
static int BeamWand_Glow;
//static int BeamWand_LaserBeam;

static char gGlow1;
//static char gLaser2;
public void Ion_Beam_Wand_MapStart()
{
	Zero(fl_Special_Timer);
	Zero(fl_Neuvellete_Beam_Timeout);
	Zero(h_TimerNeuvellete_Management);
	Zero(fl_hud_timer);
	Zero(i_Neuvellete_Skill_Points);
	Zero(i_Neuvellete_HEX_Array);
	Zero2(b_skill_points_give_at_pap);
	Zero(i_skill_point_used);
	Zero(b_special_active);
	Zero2(fl_beam_angle);
	Zero(fl_throttle);
	Zero(fl_throttle2);
	Zero(fl_extra_effects_timer);
	Zero(fl_m2_timer);
	PrecacheSound(NEUVELLETE_MAIN_BEAM_SOUND);
	PrecacheModel("materials/sprites/laserbeam.vmt");
	BeamWand_Laser = PrecacheModel("materials/sprites/laser.vmt", false);
	//BeamWand_LaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	BeamWand_Glow = PrecacheModel("sprites/glow02.vmt", true);
	gGlow1 = PrecacheModel("sprites/blueglow2.vmt", true);
	//gLaser2= PrecacheModel("materials/sprites/lgtning.vmt");
}

#define NEUVELLETE_BASELINE_DAMAGE 100.0
#define NEUVELLETE_BASELINE_RANGE 1000.0
#define NEUVELLETE_BASELINE_TURN_SPEED 1.5	
#define NEUVELLETE_BASELINE_PITCH_SPEED 0.75
#define NEUVELLETE_BASELINE_MOVESPEED_PENALTY 0.5


#define FLAG_NEUVELLETE_PAP_1_DMG				(1 << 1)
#define FLAG_NEUVELLETE_PAP_1_TURNRATE			(1 << 2)
#define FLAG_NEUVELLETE_PAP_1_MANA_EFFICIENCY	(1 << 3)

#define FLAG_NEUVELLETE_PAP_2_DMG				(1 << 4)
#define FLAG_NEUVELLETE_PAP_2_RANGE				(1 << 5)
#define FLAG_NEUVELLETE_PAP_2_PENETRATION		(1 << 6)

#define FLAG_NEUVELLETE_PAP_3_MOVESPEED			(1 << 7)	//Player movespeed
#define FLAG_NEUVELLETE_PAP_3_TURNRATE			(1 << 8)
#define FLAG_NEUVELLETE_PAP_3_RANGE				(1 << 9)	

#define FLAG_NEUVELLETE_PAP_4_PENETRATION		(1 << 10)
#define FLAG_NEUVELLETE_PAP_4_TURNRATE			(1 << 11)
#define FLAG_NEUVELLETE_PAP_4_MANA_EFFICIENCY	(1 << 12)

//	"Overclocks" - Heavily changes the weapon, buffs one thing nerfs another, mostly optional stuff if the player wants to

#define FLAG_NEUVELLETE_PAP_5_NIGHTMARE			(1 << 13)	//Heavily reduces turnrate, heavily increases damage, heavily increases mana use
#define FLAG_NEUVELLETE_PAP_5_PULSE_CANNON		(1 << 14)	//Instead of the beam being constant, the beam only lasts for 2.5 seconds, but has huge turnrate, and resonable damage, increases the useage cooldown
#define FLAG_NEUVELLETE_PAP_5_FEEDBACK_LOOP		(1 << 15)	//the longer its active, the more damage it deals, mana cost grows with time active as well

static void Neuvellete_Adjust_Stats_To_Flags(int client, float &Turn_Speed, float &Pitch_Speed, float &DamagE, float &Range, int &Penetration, int &Mana_Cost, float &Move_Speed, int &Effects)
{
	int flags = i_Neuvellete_HEX_Array[client];
	float GameTime = GetGameTime();
	
	//note: These can be gotten in any order. so for example:
	/*
		Pap1: Turnrate
		Pap2: Dmg
		pap3: range
		pap4: Pen
		pap5: Pulse
	
	*/
	if(flags & FLAG_NEUVELLETE_PAP_1_DMG)
	{
		DamagE *= 1.1;
	}
	if(flags & FLAG_NEUVELLETE_PAP_1_TURNRATE)
	{
		Turn_Speed += 0.25;
		Pitch_Speed += 0.1;
		Effects |= (1 << 2);	//adds +1 to the spinning shape
	}
	if(flags & FLAG_NEUVELLETE_PAP_1_MANA_EFFICIENCY)
	{
		Mana_Cost -= RoundToFloor(float(Mana_Cost) * 0.25);
		Effects |= (1 << 1); //adds the spinning shape
	}
	
	
	if(flags & FLAG_NEUVELLETE_PAP_2_DMG)
	{
		DamagE *= 1.2;
		Effects |= (1 << 1);	//adds the spinning shape
	}
	if(flags & FLAG_NEUVELLETE_PAP_2_PENETRATION)	//baseline+6 is array size!
	{
		Penetration += 2;
		Effects |= (1 << 1);	//adds the spinning shape
		Effects |= (1 << 3);	//adds +1 to the spinning shape
	}
	if(flags & FLAG_NEUVELLETE_PAP_2_RANGE)
	{
		Range *= 1.15;
		Effects |= (1 << 1);	//adds the spinning shape
	}
	
	
	if(flags & FLAG_NEUVELLETE_PAP_3_RANGE)	//heavy increase due to the other relative upgrades
	{
		Range *= 1.5;
		Effects |= (1 << 4);	//adds +1 to the spinning shape
	}
	if(flags & FLAG_NEUVELLETE_PAP_3_MOVESPEED)
	{
		Move_Speed *= 1.5;
	}
	if(flags & FLAG_NEUVELLETE_PAP_3_TURNRATE)
	{
		Turn_Speed += 0.25;
		Pitch_Speed += 0.1;
	}
	
	
	if(flags & FLAG_NEUVELLETE_PAP_4_TURNRATE)
	{
		Turn_Speed += 0.25;
		Pitch_Speed += 0.1;
	}
	if(flags & FLAG_NEUVELLETE_PAP_4_PENETRATION)
	{
		Penetration += 2;
	}
	if(flags & FLAG_NEUVELLETE_PAP_4_MANA_EFFICIENCY)
	{
		Mana_Cost -= RoundToFloor(float(Mana_Cost) * 0.25);
		Effects |= (1 << 5);	//adds +1 to the spinning shape
	}
	
	
	if(flags & FLAG_NEUVELLETE_PAP_5_NIGHTMARE)
	{
		Move_Speed *=0.75;
		Range *= 1.25;
		Mana_Cost += RoundToFloor(float(Mana_Cost) * 1.25);
		
		Turn_Speed *= 0.3;
		Pitch_Speed *= 0.3;
		
		DamagE *= 2.5;
		
		Effects |= (1 << 6);	//nightmare
	}
	
	if(flags & FLAG_NEUVELLETE_PAP_5_PULSE_CANNON)
	{
		
		if(GameTime > fl_Special_Timer[client] + 2.5)
		{
			Kill_Beam_Hook(client, 5.0);
			return;
		}
		
		Turn_Speed *= 2.0;
		Pitch_Speed *= 2.0;
		
		DamagE *= 1.15;
		
		Effects |= (1 << 7); //pulse
	}
	
	if(flags & FLAG_NEUVELLETE_PAP_5_FEEDBACK_LOOP)
	{
		float Duration = fl_Special_Timer[client] - GameTime; Duration *= -1.0;
		float Ration = Duration*1.3 - Duration;
		
		DamagE *= Ration;
		Mana_Cost += RoundToFloor(float(Mana_Cost) * Ration);
	
	
		Effects |= (1 << 8); //feedback
	}
	
	
}

public void Activate_Neuvellete(int client, int weapon)
{
	if (h_TimerNeuvellete_Management[client] != INVALID_HANDLE)
	{
		//This timer already exists.
		if(i_CustomWeaponEquipLogic[weapon] == WEAPON_ION_BEAM)
		{
			//Is the weapon it again?
			//Yes?
			KillTimer(h_TimerNeuvellete_Management[client]);
			h_TimerNeuvellete_Management[client] = INVALID_HANDLE;
			
			int pap = Get_Pap(weapon);
			if(pap!=0)
				Give_Skill_Points(client, pap);
			DataPack pack;
			h_TimerNeuvellete_Management[client] = CreateDataTimer(0.1, Timer_Management_Neuvellete, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			pack.WriteCell(client);
			pack.WriteCell(EntIndexToEntRef(weapon));
		}
		return;
	}
		
	if(i_CustomWeaponEquipLogic[weapon] == WEAPON_ION_BEAM)
	{
		int pap = Get_Pap(weapon);
		if(pap!=0)
			Give_Skill_Points(client, pap);
		
		DataPack pack;
		h_TimerNeuvellete_Management[client] = CreateDataTimer(0.1, Timer_Management_Neuvellete, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(client);
		pack.WriteCell(EntIndexToEntRef(weapon));
	}
}

public Action Timer_Management_Neuvellete(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	if(IsValidClient(client))
	{
		if (IsClientInGame(client))
		{
			if (IsPlayerAlive(client))
			{
				Neuvellete_Loop_Logic(client, EntRefToEntIndex(pack.ReadCell()));
			}
			else
				Kill_Neuvellete_Loop(client);
		}
		else
			Kill_Neuvellete_Loop(client);
	}
	else
		Kill_Neuvellete_Loop(client);
		
	return Plugin_Continue;
}
static void Neuvellete_Loop_Logic(int client, int weapon)
{
	int weapon_holding = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	

	if(IsValidEntity(weapon))
	{

		if(i_CustomWeaponEquipLogic[weapon] == WEAPON_ION_BEAM)	//this loop will work if the holder doesn't have it in there hands, but they have it bought
		{

			if(weapon_holding==weapon)	//And this will only work if they have the weapon in there hands and bought
			{	/*
				float GameTime = GetGameTime();
				if(fl_hud_timer[client]<GameTime)
				{
					fl_hud_timer[client] = GameTime + 0.5;
					Neuvellete_Hud(client);
				}*/
			}
		}
		else
		{
			Kill_Neuvellete_Loop(client);
		}
	}
	else
	{
		Kill_Neuvellete_Loop(client);
		
	}
}
/*
static void Neuvellete_Hud(int client)
{
	char HUDText[255] = "";
	
	Format(HUDText, sizeof(HUDText), "%sRaishi Concentration: %.1f％", HUDText, charge_percent);
	
	
	PrintHintText(client, HUDText);
	StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
}*/

public void Kill_Neuvellete_Loop(int client)
{
	if (h_TimerNeuvellete_Management[client] != INVALID_HANDLE)
	{
		KillTimer(h_TimerNeuvellete_Management[client]);
		h_TimerNeuvellete_Management[client] = INVALID_HANDLE;
		
		Kill_Beam_Hook(client, 2.5);
	}
}

public void Ion_Beam_On_Buy_Reset(int client)
{
	i_Neuvellete_HEX_Array[client] = 0;
	i_Neuvellete_Skill_Points[client] = 0;
	i_skill_point_used[client] = 0;
	for(int i=0 ; i < 7 ; i++)
	{
		b_skill_points_give_at_pap[client][i] = false;
	}
}

static int Get_Pap(int weapon)
{
	int pap = 0;
	pap = RoundFloat(Attributes_Get(weapon, 122, 0.0));
	return pap;
}
static void Give_Skill_Points(int client, int pap)
{
	if(!b_skill_points_give_at_pap[client][pap])	//no going back!
	{
		b_skill_points_give_at_pap[client][pap] = true;
		i_Neuvellete_Skill_Points[client]++;
	}
}

public void Weapon_Ion_Wand_Beam(int client, int weapon, bool crit)
{
	float GameTime = GetGameTime();
	if(!b_special_active[client])
	{
		if (fl_Neuvellete_Beam_Timeout[client]<=GameTime)
		{
			fl_Special_Timer[client] = GameTime;
			float Angles[3];
			GetClientEyeAngles(client, Angles);
			b_special_active[client]=true;
			SDKHook(client, SDKHook_PreThink, Neuvellete_tick);
			
			EmitSoundToClient(client, NEUVELLETE_MAIN_BEAM_SOUND, _, SNDCHAN_STATIC, 100, _, 0.5, 85);
			
			fl_beam_angle[client][0] = Angles[1];	//Yaw
			fl_beam_angle[client][1] = Angles[0];	//Pitch
			
			fl_throttle[client] = 0.0;
			fl_extra_effects_timer[client] = 0.0;
		}
		else
		{
			float Cooldown = fl_Neuvellete_Beam_Timeout[client] - GameTime;
				
			ClientCommand(client, "playgamesound items/medshotno1.wav");
			SetDefaultHudPosition(client);
			SetGlobalTransTarget(client);
			ShowSyncHudText(client,  SyncHud_Notifaction, "%t", "Ability has cooldown", Cooldown);
		}
		
	}
	else
	{
		Kill_Beam_Hook(client, 3.5);
	}
}
static float fl_m2_angle[MAXTF2PLAYERS + 1];
static float fl_m2_start_angles[MAXTF2PLAYERS + 1][3];
static float fl_m2_start_pos[MAXTF2PLAYERS + 1][3];
static bool b_first_tick[MAXTF2PLAYERS + 1];
public void Weapon_Ion_Wand_Beam_M2(int client, int weapon, bool &result, int slot)
{
	float GameTime = GetGameTime();
	SDKUnhook(client, SDKHook_PreThink, Neuvellete_tick_m2);
	fl_m2_timer[client] = GameTime + 5.0;
	SDKHook(client, SDKHook_PreThink, Neuvellete_tick_m2);
	fl_m2_angle[client] = 0.0;
	float Angles[3], Pos[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, Pos);
	fl_m2_start_angles[client] = Angles;
	fl_m2_start_pos[client] = Pos;
	b_first_tick[client] = true;
	
}

static float fl_spinning_angle[MAXTF2PLAYERS+1];
public Action Neuvellete_tick(int client)
{
	if(IsValidClient(client))
	{
		float GameTime = GetGameTime();
				
		if(fl_throttle[client]>GameTime)
			return Plugin_Continue;
			
		int weapon_holding = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if(i_CustomWeaponEquipLogic[weapon_holding] != WEAPON_ION_BEAM)
		{
			Kill_Beam_Hook(client, 3.5);
			return Plugin_Stop;
		}
		
		float Angles[3], Beam_Angles[3], Start_Loc[3], Target_Loc[3];
		GetClientEyeAngles(client, Angles);
			
		fl_throttle[client] = GameTime + NEUVELLETE_THROTTLE_SPEED;
		
		float travel_distance = fl_beam_angle[client][0] - Angles[1];
		float travel_distance_pitch = fl_beam_angle[client][1] - Angles[0];
		
		
		float Turn_Speed = NEUVELLETE_BASELINE_TURN_SPEED;
		float Pitch_Speed = NEUVELLETE_BASELINE_PITCH_SPEED;
		float DamagE = NEUVELLETE_BASELINE_DAMAGE;
		float Range = NEUVELLETE_BASELINE_RANGE;
		float Move_Speed = NEUVELLETE_BASELINE_MOVESPEED_PENALTY;
		int Penetration = MAX_NEUVELLETE_TARGETS_HIT;
		
		int Effects;
		
		int mana_cost;
		mana_cost = RoundToCeil(Attributes_Get(weapon_holding, 733, 1.0));
						
		Neuvellete_Adjust_Stats_To_Flags(client, Turn_Speed, Pitch_Speed, DamagE, Range, Penetration, mana_cost, Move_Speed, Effects);
		int flags = i_Neuvellete_HEX_Array[client];
		
		if(Current_Mana[client]<=mana_cost)
		{
			Kill_Beam_Hook(client, 6.0);
			return Plugin_Stop;
		}
		
		DamagE *=Attributes_Get(weapon_holding, 410, 1.0);
		
		Range *= Attributes_Get(weapon_holding, 103, 1.0);
		Range *= Attributes_Get(weapon_holding, 104, 1.0);
		Range *= Attributes_Get(weapon_holding, 475, 1.0);
		Range *= Attributes_Get(weapon_holding, 101, 1.0);
		Range *= Attributes_Get(weapon_holding, 102, 1.0);
		/*
		float firerate1 = Attributes_Get(weapon_holding, 6, 1.0);
		float firerate2 = Attributes_Get(weapon_holding, 5, 1.0);	//nerf turnrate bonus if too high
		Turn_Speed /= firerate1;
		Turn_Speed /= firerate2;
		Pitch_Speed /= firerate1;
		Pitch_Speed /= firerate2;*/
		
		//Attributes_Set(weapon_holding, 107, Move_Speed);
		
		Current_Mana[client] -=mana_cost;
		Mana_Regen_Delay[client] = GameTime + 1.0;
		
		i_Neuvellete_penetration[client] = Penetration;
		
		if(travel_distance<180.0 && -180.0<travel_distance)	//travel distance is less then 180.0 we do it normaly
		{
			if(travel_distance>Turn_Speed)		
			{
				fl_beam_angle[client][0] -= Turn_Speed;
			}
			else if(travel_distance < Turn_Speed*-1.0)
			{
				fl_beam_angle[client][0] += Turn_Speed;
			}
			
			if(travel_distance<Turn_Speed && travel_distance>0.1)			//finetune control
			{
				fl_beam_angle[client][0] -= 0.1;
			}
			else if(travel_distance > Turn_Speed*-1.0 && travel_distance<-0.1)
			{
				fl_beam_angle[client][0] += 0.1;
			}
		}
		else	//otherwise we invert
		{
			if(travel_distance>0.5)		
			{
				fl_beam_angle[client][0] += Turn_Speed;
			}
			else if(travel_distance < -0.5)
			{
				fl_beam_angle[client][0] -= Turn_Speed;
			}
		}
		
		if(travel_distance_pitch<90.0 && -90.0<travel_distance_pitch)	//unlike YAW pitch should be pretty easy to do
		{
			if(travel_distance_pitch>Pitch_Speed)		
			{
				fl_beam_angle[client][1] -= Pitch_Speed;
			}
			else if(travel_distance_pitch < Pitch_Speed*-1.0)
			{
				fl_beam_angle[client][1] += Pitch_Speed;
			}
			
			if(travel_distance_pitch<Pitch_Speed && travel_distance_pitch>0.1)			//finetune control
			{
				fl_beam_angle[client][1] -= 0.1;
			}
			else if(travel_distance_pitch > Pitch_Speed*-1.0 && travel_distance_pitch<-0.1)
			{
				fl_beam_angle[client][1] += 0.1;
			}
		}
		
		if(fl_beam_angle[client][0]>180.0)
			fl_beam_angle[client][0] = -180.0;
			
		if(fl_beam_angle[client][0]<-180.0)
			fl_beam_angle[client][0] = 180.0;
		
		//TODO: issue will arise if the client's angle are say 359 and then they turn making angles say 0, this code doesn't acount for that meaning it will just go around, FIX IT SOMEHOW
		/*
			Possible sollution: check distances for both sides, whichever one is less turn that way
			
			Client is looking at 10.0
			Beam is at -170.0
			with current logic it will start going around the long way around the entire player.
			
			When in reality all it needs to do is travel 20 units in the other direction
			
			So, say we 
			
			if travel distance above 180 we invert
			
			
			
			Mouse 2: Uses up extra mana to do 1? of these:
			
			Defensive Stance - Adds dmg reistance
			
			Offensive Stance - Adds extra damage
			
			Light Stance - Increases turn speed of laser
			
		*/
		
			
		Beam_Angles[0] = fl_beam_angle[client][1]; Beam_Angles[2] = 0.0; Beam_Angles[1] = fl_beam_angle[client][0];
		
		float Pos[3];
		GetClientEyePosition(client, Pos);
		Pos[2] -= 35.0;	//somewhere near the torso
		
		
		
		Handle trace = TR_TraceRayFilterEx(Pos, Beam_Angles, 11, RayType_Infinite, BeamWand_TraceWallsOnly);
		TR_GetEndPosition(Target_Loc, trace);
		delete trace;
		
		ConformLineDistance(Target_Loc, Pos, Target_Loc, Range);
		
		float Main_Beam_Dist = GetVectorDistance(Pos, Target_Loc);
		
		if(Main_Beam_Dist>30.0)
		{
			Get_Fake_Forward_Vec(30.0, Beam_Angles, Start_Loc, Pos);	//make the beam origin not inside but a bit further away from the player
		}
		else
		{
			Get_Fake_Forward_Vec(Main_Beam_Dist, Beam_Angles, Start_Loc, Pos);	//make the beam origin not inside but a bit further away from the player
		}
		
		
		
		
		fl_spinning_angle[client]+=5.0;
		
		if(fl_spinning_angle[client]>=360.0)
		fl_spinning_angle[client] = 0.0;
		
		if(flags & FLAG_NEUVELLETE_PAP_5_PULSE_CANNON)
			Neuvellete_Create_Spinning_Beams_ALT_ALT(client, Start_Loc, Beam_Angles, 3, Main_Beam_Dist, 2.5);		//Infuser (it cycles a triangle from start to end)
			
		if(flags & FLAG_NEUVELLETE_PAP_5_NIGHTMARE)
		{
			int Amt_Spin = 4;
			if(Effects & (1<<2))
				Amt_Spin++;
			if(Effects & (1<<3))
				Amt_Spin++;
			if(Effects & (1<<4))
				Amt_Spin++;
			if(Effects & (1<<5))
				Amt_Spin++;
			float diststance_moonlight[2]; diststance_moonlight[0] = 40.0; diststance_moonlight[1] = 80.0;
			//Neuvellete_Create_Spinning_Beams_ALT_ALT_ALT(client, Start_Loc, Beam_Angles, Main_Beam_Dist, diststance_moonlight, 1.5);	//Moonlight
			Neuvellete_Create_Spinning_Beams(client, Start_Loc, Beam_Angles, Amt_Spin,  Main_Beam_Dist, true, diststance_moonlight[0], 1.0);						//Spining beams
			Neuvellete_Create_Spinning_Beams(client, Start_Loc, Beam_Angles, 3,  Main_Beam_Dist, false, diststance_moonlight[1], -1.0);						//Spining beams
		}
		
		//Neuvellete_Create_Spinning_Beams_ALT(client, Start_Loc, Beam_Angles, 6, Main_Beam_Dist, 5.0);				//Spiral
		
		if(Effects & (1<<1) && !(flags & FLAG_NEUVELLETE_PAP_5_NIGHTMARE))
		{
			int Amt_Spin = 3;
			if(Effects & (1<<2))
				Amt_Spin++;
			if(Effects & (1<<3))
				Amt_Spin++;
			if(Effects & (1<<4))
				Amt_Spin++;
			if(Effects & (1<<5))
				Amt_Spin++;
				
			Neuvellete_Create_Spinning_Beams(client, Start_Loc, Beam_Angles, Amt_Spin,  Main_Beam_Dist, true, 40.0, 1.0);
		}

		Neuvellete_Base_Central_Beam(Start_Loc, Target_Loc);
		Beam_Wand_Laser_Attack(client, Start_Loc, Target_Loc, DamagE);
		
		
		
	}
	
	return Plugin_Continue;
}
static void Kill_Beam_Hook(int client, float time)
{
	
	fl_Neuvellete_Beam_Timeout[client] = GetGameTime()+time; 
		
	SDKUnhook(client, SDKHook_PreThink, Neuvellete_tick);
	b_special_active[client]=false;
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);	//CEASE THY SOUND
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);
	StopSound(client, SNDCHAN_STATIC, NEUVELLETE_MAIN_BEAM_SOUND);
	
	//int weapon_holding = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	//Attributes_Set(weapon_holding, 107, 1.0);
}

static void Neuvellete_Base_Central_Beam(float Start_Loc[3], float Target_Loc[3])
{
	int r=1, g=255, b=255, a=75;
	float diameter = 40.0;
	int colorLayer4[4];  
	SetColorRGBA(colorLayer4, r, g, b, a);
	int colorLayer1[4];
	SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, a);
	
	TE_SetupBeamPoints(Start_Loc, Target_Loc, BeamWand_Laser, 0, 0, 66, NEUVELLETE_TE_DURATION, ClampBeamWidth(diameter * 0.7 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 1.25, colorLayer1, 15);
								
	TE_SendToAll(0.0);
	
	TE_SetupGlowSprite(Start_Loc, gGlow1, NEUVELLETE_TE_DURATION, 0.5, 255);
	TE_SendToAll(0.0);
	
	int glowColor[4];
	
	diameter /= 1.5;
	SetColorRGBA(glowColor, r, g, b, a);
	TE_SetupBeamPoints(Start_Loc, Target_Loc, BeamWand_Glow, 0, 0, 66, NEUVELLETE_TE_DURATION, ClampBeamWidth(diameter * 0.7 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, glowColor, -25);								
	TE_SendToAll(0.0);
}
static float fl_buffer_vector[MAXTF2PLAYERS + 1][2][3];
public Action Neuvellete_tick_m2(int client)
{
	if(IsValidClient(client))
	{
		float GameTime = GetGameTime();
		if(fl_throttle2[client]>GameTime)
			return Plugin_Continue;
			
		float Duration = fl_m2_timer[client] - GameTime;
		if(fl_m2_timer[client]<GameTime)
		{
			SDKUnhook(client, SDKHook_PreThink, Neuvellete_tick_m2);
		}
			
		float range = 1000.0;
		float Range = range - (range * (Duration / 5.0));
		fl_throttle2[client] = GameTime + 0.05;
				
		fl_m2_angle[client] += 25.0;
		if(fl_m2_angle[client]>360.0)
			fl_m2_angle[client] = 0.0;
		
		float Angles[3], Buffer[2][3], Origin_New[3], Buffer_2[2][3];
		if(!b_first_tick[client])
		{
			Buffer_2[0] = fl_buffer_vector[client][0];
			Buffer_2[1] = fl_buffer_vector[client][1];
		}
		Angles = fl_m2_start_angles[client];
		float Origin[3]; Origin = fl_m2_start_pos[client];
		int loop_for = 2;
		Get_Fake_Forward_Vec(Range, Angles, Origin_New, Origin);
		//fl_m2_start_pos[client] = Origin_New;
		for(int i=1 ; i<=loop_for ; i++)
		{	
			float tempAngles[3], Direction[3], endLoc[3], End_Loc[3];
			tempAngles[0] = Angles[0];
			tempAngles[1] = Angles[1];	//has to the same as the beam
			tempAngles[2] = fl_m2_angle[client]+((360.0/loop_for)*float(i));	//we use the roll angle vector to make it speeen
			
			if(tempAngles[2]>360.0)
				tempAngles[2] -= 360.0;
		
						
			GetAngleVectors(tempAngles, Direction, NULL_VECTOR, Direction);
			ScaleVector(Direction, 75.0);
			AddVectors(Origin, Direction, endLoc);
			
			Get_Fake_Forward_Vec(Range, Angles, End_Loc, endLoc);
			
			
			
			Buffer[i - 1] = End_Loc;
			
			fl_buffer_vector[client][i-1] = End_Loc;
			
		}
		int r=1, g=1, b=255, a=255;
		float diameter = 15.0;
		int colorLayer4[4];
		SetColorRGBA(colorLayer4, r, g, b, a);
		int colorLayer1[4];
		SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, a);
										
		TE_SetupBeamPoints(Buffer[0], Buffer[1], BeamWand_Laser, 0, 0, 0, Duration+1.0, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, colorLayer1, 3);
	
		TE_SendToAll();
		
		if(!b_first_tick[client])
		{
			TE_SetupBeamPoints(Buffer_2[0], Buffer[0], BeamWand_Laser, 0, 0, 0, Duration+1.0, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, colorLayer1, 3);
			TE_SendToAll();
			TE_SetupBeamPoints(Buffer_2[1], Buffer[1], BeamWand_Laser, 0, 0, 0, Duration+1.0, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, colorLayer1, 3);
			TE_SendToAll();
		}
		b_first_tick[client] = false;
		
	}
	
	return Plugin_Continue;
}

static void Get_Fake_Forward_Vec(float Range, float vecAngles[3], float Vec_Target[3], float Pos[3])
{
	float Direction[3];
	
	GetAngleVectors(vecAngles, Direction, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(Direction, Range);
	AddVectors(Pos, Direction, Vec_Target);
}
static void Neuvellete_Create_Spinning_Beams(int client, float Origin[3], float Angles[3], int loop_for, float Main_Beam_Dist, bool Type=true, float distance_stuff, float ang_multi)
{
	
	float buffer_vec[10][3];
		
	for(int i=1 ; i<=loop_for ; i++)
	{	
		float tempAngles[3], Direction[3], endLoc[3], End_Loc[3];
		tempAngles[0] = Angles[0];
		tempAngles[1] = Angles[1];	//has to the same as the beam
		tempAngles[2] = (fl_spinning_angle[client]+((360.0/loop_for)*float(i)))*ang_multi;	//we use the roll angle vector to make it speeen
		
		if(tempAngles[2]>360.0)
			tempAngles[2] -= 360.0;
	
					
		GetAngleVectors(tempAngles, Direction, NULL_VECTOR, Direction);
		ScaleVector(Direction, distance_stuff);
		AddVectors(Origin, Direction, endLoc);
		
		buffer_vec[i] = endLoc;
		
		Get_Fake_Forward_Vec(Main_Beam_Dist, Angles, End_Loc, endLoc);
		
		if(Type)
		{
			int r=1, g=1, b=255, a=255;
			float diameter = 15.0;
			int colorLayer4[4];
			SetColorRGBA(colorLayer4, r, g, b, a);
			int colorLayer1[4];
			SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, a);
										
			TE_SetupBeamPoints(endLoc, End_Loc, BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, colorLayer1, 3);
										
			if(!LastMann)
				TE_SendToClient(client);
			else
				TE_SendToAll();
		}
		
	}
	
	int color[4]; color[0] = 1; color[1] = 255; color[2] = 255; color[3] = 255;
	
	TE_SetupBeamPoints(buffer_vec[1], buffer_vec[loop_for], BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, 5.0, 5.0, 0, 0.01, color, 3);	
	TE_SendToAll(0.0);
	for(int i=1 ; i<loop_for ; i++)
	{
		TE_SetupBeamPoints(buffer_vec[i], buffer_vec[i+1], BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, 5.0, 5.0, 0, 0.01, color, 3);	
		TE_SendToAll(0.0);
	}
	
}
/*
static void Neuvellete_Create_Spinning_Beams_ALT(int client, float Origin[3], float Angles[3], int loop_for, float Main_Beam_Dist, float Cycle_Speed)
{
	
	float buffer_vec[10][3];
	float GameTime = GetGameTime();
	
	
	if(fl_extra_effects_timer[client] < GameTime)
	{
		fl_extra_effects_timer[client] = GameTime + Cycle_Speed;
	}
	
	float Duration = fl_extra_effects_timer[client] - GameTime;
	
	float Range_Current = Main_Beam_Dist - (Main_Beam_Dist * (Duration / Cycle_Speed));
	if(Range_Current<1.0)
		Range_Current = 1.0;
		
	for(int i=1 ; i<=loop_for ; i++)
	{	
		float tempAngles[3], Direction[3], endLoc[3], End_Loc[3];
		tempAngles[0] =	Angles[0];
		tempAngles[1] = Angles[1];	//has to the same as the beam
		tempAngles[2] = fl_spinning_angle[client]+((360.0/loop_for)*float(i));	//we use the roll angle vector to make it speeen
		
		if(tempAngles[2]>360.0)
			tempAngles[2] -= 360.0;
	
					
		GetAngleVectors(tempAngles, Direction, NULL_VECTOR, Direction);
		ScaleVector(Direction, 40.0);
		AddVectors(Origin, Direction, endLoc);

		buffer_vec[i] = endLoc;
		
		
		Get_Fake_Forward_Vec(Range_Current, Angles, End_Loc, endLoc);
		
		float Extra_EndLoc[3];
		Get_Fake_Forward_Vec(50.0, Angles, Extra_EndLoc, End_Loc);
			
			
		int r=1, g=1, b=255, a=255;
		float diameter = 15.0;
		int colorLayer4[4];
		SetColorRGBA(colorLayer4, r, g, b, a);
		int colorLayer1[4];
		SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, a);
										
		TE_SetupBeamPoints(Extra_EndLoc, End_Loc, BeamWand_Laser, 0, 0, 0, 5.0, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 0.25, colorLayer1, 3);
										
		if(!LastMann)
			TE_SendToClient(client);
		else
			TE_SendToAll();	
	}
	
	int color[4]; color[0] = 1; color[1] = 255; color[2] = 255; color[3] = 255;
	
	TE_SetupBeamPoints(buffer_vec[1], buffer_vec[loop_for], BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, 5.0, 5.0, 0, 0.01, color, 3);	
	TE_SendToAll(0.0);
	for(int i=1 ; i<loop_for ; i++)
	{
		TE_SetupBeamPoints(buffer_vec[i], buffer_vec[i+1], BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, 5.0, 5.0, 0, 0.01, color, 3);	
		TE_SendToAll(0.0);
	}
	
}
*/
static void Neuvellete_Create_Spinning_Beams_ALT_ALT(int client, float Origin[3], float Angles[3], int loop_for, float Main_Beam_Dist, float Cycle_Speed)
{
	float GameTime = GetGameTime();
	
	
	if(fl_extra_effects_timer[client] < GameTime)
	{
		fl_extra_effects_timer[client] = GameTime + Cycle_Speed;
	}
	
	float Duration = fl_extra_effects_timer[client] - GameTime;
	
	float Range_Current = Main_Beam_Dist - (Main_Beam_Dist * (Duration / Cycle_Speed));
	if(Range_Current<1.0)
		Range_Current = 1.0;
		
	for(int i=1 ; i<=loop_for ; i++)
	{	
		float tempAngles[3], Direction[3], endLoc[3], End_Loc[3];
		tempAngles[0] =	Angles[0];
		tempAngles[1] = Angles[1];	//has to the same as the beam
		tempAngles[2] = fl_spinning_angle[client]+((360.0/loop_for)*float(i));	//we use the roll angle vector to make it speeen
		
		if(tempAngles[2]>360.0)
			tempAngles[2] -= 360.0;
	
		
		Get_Fake_Forward_Vec(Range_Current, Angles, End_Loc, Origin);
		
		GetAngleVectors(tempAngles, Direction, NULL_VECTOR, Direction);
		ScaleVector(Direction, 40.0);
		AddVectors(End_Loc, Direction, endLoc);
			
			
		int r=1, g=1, b=255, a=255;
		float diameter = 15.0;
		int colorLayer4[4];
		SetColorRGBA(colorLayer4, r, g, b, a);
		int colorLayer1[4];
		SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, a);
									
		TE_SetupBeamPoints(endLoc, End_Loc, BeamWand_Laser, 0, 0, 0, NEUVELLETE_TE_DURATION, ClampBeamWidth(diameter * 0.3 * 1.28), ClampBeamWidth(diameter * 0.3 * 1.28), 0, 2.5, colorLayer1, 3);
									
		if(!LastMann)
			TE_SendToClient(client);
		else
			TE_SendToAll();
		
		
	}
	
}
/*
static void Neuvellete_Create_Spinning_Beams_ALT_ALT_ALT(int client, float Origin[3], float Angles[3], float Main_Beam_Dist, float distance_base[2], float diameter)
{
	
	int loop_for = 5;
	float angl_multi;
	float distance;
	for(int j=0; j<2 ; j++)
	{
		switch(j)
		{
			case 0:
			{
				distance = distance_base[0];
				angl_multi = 1.0;
			}
			case 1:
			{
				distance = distance_base[1];
				angl_multi = -1.0;
			}
		}
			
		for(int i=1 ; i<=loop_for ; i++)
		{	
			float tempAngles[3], Direction[3], endLoc[3], End_Loc[3];
			tempAngles[0] =	Angles[0];
			tempAngles[1] = Angles[1];	//has to the same as the beam
			tempAngles[2] = (fl_spinning_angle[client]+((360.0/loop_for)*float(i)))*angl_multi;	//we use the roll angle vector to make it speeen
			
			if(tempAngles[2]>360.0)
				tempAngles[2] -= 360.0;
				
			if(tempAngles[2]<-360.0)
				tempAngles[2] += 360.0;
		
		
			GetAngleVectors(tempAngles, Direction, NULL_VECTOR, Direction);
			ScaleVector(Direction, distance);
			AddVectors(Origin, Direction, endLoc);
			
			Get_Fake_Forward_Vec(Main_Beam_Dist, Angles, End_Loc, endLoc);
			
			int color[4];
			color[0] = 0;
			color[1] = 255;
			color[2] = 135;
			color[3] = 125;
			
			TE_SetupBeamPoints(endLoc, End_Loc, BeamWand_LaserBeam, 0, 0, 0, NEUVELLETE_TE_DURATION, diameter, diameter, 1, 0.1, color, 1);
										
			
			if(!LastMann)
				TE_SendToClient(client);
			else
				TE_SendToAll();
			
			
		}
	}
}*/

static void Beam_Wand_Laser_Attack(int client, float playerPos[3], float endVec_2[3], float damage)
{
		static float hullMin[3];
		static float hullMax[3];

		for (int i = 1; i < MAXTF2PLAYERS; i++)
		{
			BEAM_HitDetected[i] = false;
		}
		
		
		for (int building = 1; building < i_Neuvellete_penetration[client]; building++)
		{
			BEAM_BuildingHit[building] = false;
		}
		
		
		hullMin[0] = -25.0;
		hullMin[1] = hullMin[0];
		hullMin[2] = hullMin[0];
		hullMax[0] = -hullMin[0];
		hullMax[1] = -hullMin[1];
		hullMax[2] = -hullMin[2];
		b_LagCompNPC_No_Layers = true;
		StartLagCompensation_Base_Boss(client);
		Handle trace;
		trace = TR_TraceHullFilterEx(playerPos, endVec_2, hullMin, hullMax, 1073741824, BEAM_TraceUsers, client);	// 1073741824 is CONTENTS_LADDER?
		delete trace;
		FinishLagCompensation_Base_boss();
		
		float vecForward[3];
		float vecAngles[3];
		GetAngleVectors(vecAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
		BEAM_Targets_Hit[client] = 1.0;
		int weapon_active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		for (int building = 0; building < i_Neuvellete_penetration[client]; building++)
		{
			if (BEAM_BuildingHit[building])
			{
				if(IsValidEntity(BEAM_BuildingHit[building]))
				{
					float trg_loc[3];
					trg_loc = WorldSpaceCenter(BEAM_BuildingHit[building]);
					
					
					float damage_force[3];
					damage_force = CalculateDamageForce(vecForward, 10000.0);
					DataPack pack = new DataPack();
					pack.WriteCell(EntIndexToEntRef(BEAM_BuildingHit[building]));
					pack.WriteCell(EntIndexToEntRef(client));
					pack.WriteCell(EntIndexToEntRef(client));
					pack.WriteFloat(damage/BEAM_Targets_Hit[client]);
					pack.WriteCell(DMG_PLASMA);
					pack.WriteCell(EntIndexToEntRef(weapon_active));
					pack.WriteFloat(damage_force[0]);
					pack.WriteFloat(damage_force[1]);
					pack.WriteFloat(damage_force[2]);
					pack.WriteFloat(trg_loc[0]);
					pack.WriteFloat(trg_loc[1]);
					pack.WriteFloat(trg_loc[2]);
					RequestFrame(CauseDamageLaterSDKHooks_Takedamage, pack);

					
					BEAM_Targets_Hit[client] *= LASER_AOE_DAMAGE_FALLOFF;
				}
				else
					BEAM_BuildingHit[building] = false;
			}
		}
}

static bool BEAM_TraceUsers(int entity, int contentsMask, int client)
{
	if (IsValidEntity(entity))
	{
		entity = Target_Hit_Wand_Detection(client, entity);
		if(0 < entity)
		{
			for(int i=1; i <= (i_Neuvellete_penetration[client] -1 ); i++)
			{
				if(!BEAM_BuildingHit[i])
				{
					BEAM_BuildingHit[i] = entity;
					break;
				}
			}
			
		}
	}
	return false;
}
static bool BeamWand_TraceWallsOnly(int entity, int contentsMask)
{
	return !entity;
}

public void Neuvellete_Menu(int client, int weapon)
{	
	Menu menu2 = new Menu(Neuvellete_Menu_Selection);
	int flags = i_Neuvellete_HEX_Array[client];
	
	if(i_Neuvellete_Skill_Points[client]>0)
	{
		menu2.SetTitle("%t", "Neuvellete Menu First", i_Neuvellete_Skill_Points[client]);
		
		switch(i_skill_point_used[client]+1)
		{
			case 1:
			{
				char buffer[255];
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete dmg");
				menu2.AddItem("1", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
				menu2.AddItem("2", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Mana");
				menu2.AddItem("3", buffer);
			}
			case 2:
			{
				char buffer[255];
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete dmg");
				menu2.AddItem("1", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Range");
				menu2.AddItem("2", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pen");
				menu2.AddItem("3", buffer);
			}
			case 3:
			{
				char buffer[255];
				//FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete MoveSpeed");
				//menu2.AddItem("1", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
				menu2.AddItem("2", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Range");
				menu2.AddItem("3", buffer);
			}
			case 4:
			{
				char buffer[255];
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pen");
				menu2.AddItem("1", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
				menu2.AddItem("2", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Mana");
				menu2.AddItem("3", buffer);
			}
			case 5:
			{
				char buffer[255];
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Overclock Info");
				menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
			
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Nightmare");
				menu2.AddItem("1", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pulse");
				menu2.AddItem("2", buffer);
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Feedback");
				menu2.AddItem("3", buffer);
			}
		}
	}
	else
	{
		if(i_skill_point_used[client]!=0)
		{
			menu2.SetTitle("%t", "Neuvellete Menu Third");
			
			char buffer[255];
			
			FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete pap0");
			menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
			
			if(flags & FLAG_NEUVELLETE_PAP_1_DMG)
			{
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete dmg");
				menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
			}
			if(flags & FLAG_NEUVELLETE_PAP_1_TURNRATE)
			{
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
				menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
				
			}
			if(flags & FLAG_NEUVELLETE_PAP_1_MANA_EFFICIENCY)
			{
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Mana");
				menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
			}
			
			if(i_skill_point_used[client]>=2)
			{
				
				FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete pap1");
				menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
				if(flags & FLAG_NEUVELLETE_PAP_2_DMG)
				{
					FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete dmg");
					menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
				}
				if(flags & FLAG_NEUVELLETE_PAP_2_PENETRATION)
				{
					FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pen");
					menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
				}
				if(flags & FLAG_NEUVELLETE_PAP_2_RANGE)
				{
					FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Range");
					menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
				}
				
				if(i_skill_point_used[client]>=3)
				{
					FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete pap2");
					menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
					if(flags & FLAG_NEUVELLETE_PAP_3_RANGE)
					{
						FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Range");
						menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
					}
					if(flags & FLAG_NEUVELLETE_PAP_3_MOVESPEED)
					{
						//FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete MoveSpeed");
						//menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
					}
					if(flags & FLAG_NEUVELLETE_PAP_3_TURNRATE)
					{
						FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
						menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
					}
					
					if(i_skill_point_used[client]>=4)
					{
						FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete pap3");
						menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
						if(flags & FLAG_NEUVELLETE_PAP_4_TURNRATE)
						{
							FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Turn");
							menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
						}
						if(flags & FLAG_NEUVELLETE_PAP_4_PENETRATION)
						{
							FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pen");
							menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
						}
						if(flags & FLAG_NEUVELLETE_PAP_4_MANA_EFFICIENCY)
						{
							FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Mana");
							menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
						}
						
						if(i_skill_point_used[client]>=5)
						{
							FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete pap4");
							menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
							if(flags & FLAG_NEUVELLETE_PAP_5_NIGHTMARE)
							{
								FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Nightmare");
								menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
							}
							
							if(flags & FLAG_NEUVELLETE_PAP_5_PULSE_CANNON)
							{
								FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Pulse");
								menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
							}
							
							if(flags & FLAG_NEUVELLETE_PAP_5_FEEDBACK_LOOP)
							{
								FormatEx(buffer, sizeof(buffer), "%t", "Neuvellete Feedback");
								menu2.AddItem("4", buffer, ITEMDRAW_DISABLED);
							}
						}
					}
				}
			}
		}
	}
	
	
	menu2.Display(client, MENU_TIME_FOREVER); // they have 3 seconds.
	
}

static int Neuvellete_Menu_Selection(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char buffer[24];
			menu.GetItem(choice, buffer, sizeof(buffer));
			int id = StringToInt(buffer);
			
			if(id==4)
			{
				return 0;	//do nothing
			}
			
			i_Neuvellete_Skill_Points[client]--;
			
			switch(i_skill_point_used[client]+1)
			{
				case 1:
				{
					switch(id)
					{
						case 1:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_1_DMG;
						}
						case 2:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_1_TURNRATE;
						}
						case 3:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_1_MANA_EFFICIENCY;
						}
					}
				}
				case 2:
				{
					switch(id)
					{
						case 1:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_2_DMG;
						}
						case 2:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_2_RANGE;
						}
						case 3:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_2_PENETRATION;
						}
					}
				}
				case 3:
				{
					switch(id)
					{
						case 1:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_3_MOVESPEED;
						}
						case 2:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_3_TURNRATE;
						}
						case 3:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_3_RANGE;
						}
					}
				}
				case 4:
				{
					switch(id)
					{
						case 1:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_4_PENETRATION;
						}
						case 2:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_4_TURNRATE;
						}
						case 3:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_4_MANA_EFFICIENCY;
						}
					}
				}
				case 5:
				{
					switch(id)
					{
						case 1:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_5_NIGHTMARE;
						}
						case 2:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_5_PULSE_CANNON;
						}
						case 3:
						{
							i_Neuvellete_HEX_Array[client] |= FLAG_NEUVELLETE_PAP_5_FEEDBACK_LOOP;
						}
					}
				}
			}
			i_skill_point_used[client]++;
		}
	}
	return 0;	//do nothing
}

/*
"Neuv"
			{
				"cost"		"1"
				"desc"		"Neuv pap0"
				"tags"		"medieval"
				
				"classname"	"tf_weapon_bonesaw"
				"index"		"173"
				"attributes"	"1 ; 0 ; 410 ; 1.25 ; 264 ; 0 ; 733 ; 10 ; 122 ; 0" 
				
				"func_onbuy"	"Ion_Beam_On_Buy_Reset"
				
				// 410 = % increased wand dmg
				// 733 = Mana cost
				
				"tier"		"0"
				"rarity"	"1"
				"model_weapon_override"					"models/empty.mdl"
				
				"func_attack"	"Weapon_Ion_Wand_Beam"
				
				"is_a_wand"		"1"
				
				"lag_comp" 						"0"
				"lag_comp_collision" 		"0"
				"lag_comp_extend_boundingbox" 		"0"
				"lag_comp_dont_move_building" 	"1"
				"weapon_archetype"	"26"
				"int_ability_onequip"	"56"
				
				"pap_1_desc"		"Neuv pap1"
				
				"pap_1_cost"			"2550"
				"pap_1_classname"		"tf_weapon_bonesaw"
				"pap_1_index"			"173"
				"pap_1_attributes"	"1 ; 0 ; 410 ; 1.5 ; 264 ; 0 ; 733 ; 10 ; 122 ; 1" 
				
				"pap_1_func_attack"	"Weapon_Ion_Wand_Beam"
				"pap_1_model_weapon_override"					"models/empty.mdl"
				
				"pap_1_lag_comp" 						"0"
				"pap_1_lag_comp_collision" 		"0"
				"pap_1_lag_comp_extend_boundingbox" 		"0"
				"pap_1_lag_comp_dont_move_building" 	"1"
				
				"pap_1_is_a_wand"		"1"
				"pap_1_weapon_archetype"	"26"
				"pap_1_int_ability_onequip"	"56"
				
				"pap_2_desc"		"Neuv pap2"
				
				"pap_2_cost"			"3300"
				"pap_2_classname"		"tf_weapon_bonesaw"
				"pap_2_index"			"173"
				"pap_2_attributes"	"1 ; 0 ; 410 ; 1.75 ; 264 ; 0 ; 733 ; 10 ; 122 ; 2" 
				
				"pap_2_func_attack"	"Weapon_Ion_Wand_Beam"
				
				"pap_2_lag_comp" 						"0"
				"pap_2_lag_comp_collision" 		"0"
				"pap_2_lag_comp_extend_boundingbox" 		"0"
				"pap_2_lag_comp_dont_move_building" 	"1"
				
				"pap_2_is_a_wand"		"1"
				"pap_2_weapon_archetype"	"26"
				"pap_2_int_ability_onequip"	"56"
				"pap_2_model_weapon_override"					"models/empty.mdl"
				
				"pap_3_desc"		"Neuv pap3"
				
				"pap_3_cost"			"4000"
				"pap_3_classname"		"tf_weapon_bonesaw"
				"pap_3_index"			"173"
				"pap_3_attributes"	"1 ; 0 ; 410 ; 2.0 ; 264 ; 0 ; 733 ; 10 ; 122 ; 3" 
				
				"pap_3_func_attack"	"Weapon_Ion_Wand_Beam"
				
				"pap_3_lag_comp" 						"0"
				"pap_3_lag_comp_collision" 		"0"
				"pap_3_lag_comp_extend_boundingbox" 		"0"
				"pap_3_lag_comp_dont_move_building" 	"1"
				
				"pap_3_is_a_wand"		"1"
				"pap_3_weapon_archetype"	"26"
				"pap_3_int_ability_onequip"	"56"
				"pap_3_model_weapon_override"					"models/empty.mdl"
				
				"pap_4_desc"		"Neuv pap4"
				
				"pap_4_func_attack"	"Weapon_Ion_Wand_Beam"
				
				"pap_4_cost"			"5000"
				"pap_4_classname"		"tf_weapon_bonesaw"
				"pap_4_index"			"173"
				"pap_4_attributes"	"1 ; 0 ; 410 ; 2.25 ; 264 ; 0 ; 733 ; 10 ; 122 ; 4" 
				
				"pap_4_lag_comp" 						"0"
				"pap_4_lag_comp_collision" 		"0"
				"pap_4_lag_comp_extend_boundingbox" 		"0"
				"pap_4_lag_comp_dont_move_building" 	"1"
				
				"pap_4_is_a_wand"		"1"
				"pap_4_weapon_archetype"	"26"
				"pap_4_int_ability_onequip"	"56"
				"pap_4_model_weapon_override"					"models/empty.mdl"
				
				"pap_5_desc"		"Neuv pap5"
				
				"pap_5_cost"			"5000"
				"pap_5_classname"		"tf_weapon_bonesaw"
				"pap_5_index"			"173"
				"pap_5_attributes"	"1 ; 0 ; 410 ; 2.5 ; 264 ; 0 ; 733 ; 10 ; 122 ; 5" 
				
				"pap_5_func_attack"	"Weapon_Ion_Wand_Beam"
				
				"pap_5_lag_comp" 						"0"
				"pap_5_lag_comp_collision" 		"0"
				"pap_5_lag_comp_extend_boundingbox" 		"0"
				"pap_5_lag_comp_dont_move_building" 	"1"
				
				"pap_5_is_a_wand"		"1"
				"pap_5_weapon_archetype"	"26"
				"pap_5_int_ability_onequip"	"56"
				"pap_5_model_weapon_override"					"models/empty.mdl"
				
			}
*/