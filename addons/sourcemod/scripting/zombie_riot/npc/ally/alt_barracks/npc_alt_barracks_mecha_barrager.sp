#pragma semicolon 1
#pragma newdecls required

static const char g_RangedAttackSounds[][] = {
	"weapons/bison_main_shot_01.wav",
	"weapons/bison_main_shot_02.wav",
};
static const char g_IdleSounds[][] =
{
	"vo/mvm/norm/taunts/soldier_mvm_taunts01.mp3",
	"vo/mvm/norm/taunts/soldier_mvm_taunts09.mp3",
	"vo/mvm/norm/taunts/soldier_mvm_taunts14.mp3",
};

static const char g_IdleAlertedSounds[][] =
{
	"vo/mvm/norm/taunts/soldier_mvm_taunts18.mp3",
	"vo/mvm/norm/taunts/soldier_mvm_taunts19.mp3",
	"vo/mvm/norm/taunts/soldier_mvm_taunts20.mp3",
	"vo/mvm/norm/taunts/soldier_mvm_taunts21.mp3",
};
static const char g_RangedReloadSound[][] = {
	"weapons/bison_reload.wav",
};


public void Barrack_Alt_Mecha_Barrager_MapStart()
{
	PrecacheModel("models/player/medic.mdl");
	for (int i = 0; i < (sizeof(g_RangedAttackSounds));   i++)			{ PrecacheSound(g_RangedAttackSounds[i]);   }
	for (int i = 0; i < (sizeof(g_IdleSounds));   i++)					{ PrecacheSound(g_IdleSounds[i]);	}
	for (int i = 0; i < (sizeof(g_IdleAlertedSounds));   i++) 			{ PrecacheSound(g_IdleAlertedSounds[i]);	}
	for (int i = 0; i < (sizeof(g_RangedReloadSound));   i++) 			{ PrecacheSound(g_RangedReloadSound[i]);	}
	
	PrecacheModel("models/bots/soldier/bot_soldier.mdl", true);
}

static int i_ammo_count[MAXENTITIES];
static bool b_target_close[MAXENTITIES];
static bool b_we_are_reloading[MAXENTITIES];
static float fl_idle_timer[MAXENTITIES];

methodmap Barrack_Alt_Mecha_Barrager < BarrackBody
{

	public void PlayIdleAlertSound()
	{
		if(this.m_flNextIdleSound > GetGameTime(this.index))
			return;
		
		EmitSoundToAll(g_IdleAlertedSounds[GetRandomInt(0, sizeof(g_IdleAlertedSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 100);
		this.m_flNextIdleSound = GetGameTime(this.index) + GetRandomFloat(12.0, 24.0);
	}
	public void PlayRangedSound() {
		EmitSoundToAll(g_RangedAttackSounds[GetRandomInt(0, sizeof(g_RangedAttackSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 80);
		
		#if defined DEBUG_SOUND
		PrintToServer("CClot::PlayMeleeHitSound()");
		#endif
	}
	public void PlayRangedReloadSound() {
		EmitSoundToAll(g_RangedReloadSound[GetRandomInt(0, sizeof(g_RangedReloadSound) - 1)], this.index, _, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 80);
		
		#if defined DEBUG_SOUND
		PrintToServer("CClot::PlayRangedSound()");
		#endif
	}
	public Barrack_Alt_Mecha_Barrager(int client, float vecPos[3], float vecAng[3], bool ally)
	{
		Barrack_Alt_Mecha_Barrager npc = view_as<Barrack_Alt_Mecha_Barrager>(BarrackBody(client, vecPos, vecAng, "100", "models/bots/soldier/bot_soldier.mdl", STEPTYPE_NORMAL));
		
		i_NpcInternalId[npc.index] = ALT_BARRACK_MECHA_BARRAGER;
		i_NpcWeight[npc.index] = 1;
		
		SDKHook(npc.index, SDKHook_Think, Barrack_Alt_Mecha_Barrager_ClotThink);

		npc.m_flSpeed = 175.0;
		
		int iActivity = npc.LookupActivity("ACT_MP_RUN_SECONDARY2");
		if(iActivity > 0) npc.StartActivity(iActivity);
		
		
		i_ammo_count[npc.index]=0;
		b_target_close[npc.index]=false;
		b_we_are_reloading[npc.index]=false;
		fl_idle_timer[npc.index] = 2.0 + GetGameTime(npc.index);
		
		int skin = 1;
		SetEntProp(npc.index, Prop_Send, "m_nSkin", skin);
		
		npc.m_iWearable1 = npc.EquipItem("head", "models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl");
		SetVariantString("1.0");
		AcceptEntityInput(npc.m_iWearable1, "SetModelScale");
		
		npc.m_iWearable2 = npc.EquipItem("head", "models/player/items/soldier/soldier_officer.mdl");
		SetVariantString("1.0");
		AcceptEntityInput(npc.m_iWearable2, "SetModelScale");
		
		npc.m_iWearable3 = npc.EquipItem("head", "models/workshop/player/items/soldier/dec15_diplomat/dec15_diplomat.mdl");
		SetVariantString("1.0");
		AcceptEntityInput(npc.m_iWearable3, "SetModelScale");
		
		SetEntityRenderMode(npc.index, RENDER_TRANSCOLOR);
		SetEntityRenderColor(npc.index, 125, 100, 100, 255);
		
		SetEntityRenderMode(npc.m_iWearable2, RENDER_TRANSCOLOR);
		SetEntityRenderColor(npc.m_iWearable2, 125, 100, 100, 255);
		
		SetEntityRenderMode(npc.m_iWearable3, RENDER_TRANSCOLOR);
		SetEntityRenderColor(npc.m_iWearable3, 125, 100, 100, 255);
		
		AcceptEntityInput(npc.m_iWearable1, "Enable");
		
		return npc;
	}
}

public void Barrack_Alt_Mecha_Barrager_ClotThink(int iNPC)
{
	Barrack_Alt_Mecha_Barrager npc = view_as<Barrack_Alt_Mecha_Barrager>(iNPC);
	float GameTime = GetGameTime(iNPC);
	if(BarrackBody_ThinkStart(npc.index, GameTime))
	{
		BarrackBody_ThinkTarget(npc.index, true, GameTime);
		int PrimaryThreatIndex = npc.m_iTarget;
		if(i_ammo_count[npc.index]==0 && !b_we_are_reloading[npc.index] && !b_target_close[npc.index])	//the npc will prefer to fully reload the clip before attacking, unless the target is too close.
		{
			b_we_are_reloading[npc.index]=true;
		}
		if((b_we_are_reloading[npc.index] || (b_target_close[npc.index] && i_ammo_count[npc.index]<=0)) && npc.m_flReloadIn<GameTime)	//Reload IF. Target too close. Empty clip.
		{
			npc.AddGesture("ACT_MP_RELOAD_STAND_SECONDARY2");
			npc.m_flReloadIn = 0.75* npc.BonusFireRate + GameTime;
			i_ammo_count[npc.index]++;
			npc.PlayRangedReloadSound();
		}
		if(fl_idle_timer[npc.index] <= GameTime && npc.m_flReloadIn<GameTime && !b_we_are_reloading[npc.index] && !b_target_close[npc.index] && i_ammo_count[npc.index]<10)	//reload if not attacking/idle for long
		{
			npc.AddGesture("ACT_MP_RELOAD_STAND_SECONDARY2");
			npc.m_flReloadIn = 0.75* npc.BonusFireRate + GameTime;
			i_ammo_count[npc.index]++;
			npc.PlayRangedReloadSound();
		}
		if(i_ammo_count[npc.index]>=10)	//npc will stop reloading once clip size is full.
		{
			b_we_are_reloading[npc.index]=false;
		}
		if(PrimaryThreatIndex > 0)
		{
			npc.PlayIdleAlertSound();
			float vecTarget[3]; vecTarget = WorldSpaceCenter(PrimaryThreatIndex);
			float flDistanceToTarget = GetVectorDistance(vecTarget, WorldSpaceCenter(npc.index), true);
			if(flDistanceToTarget < 60000)
			{
				b_target_close[npc.index]=true;
			}
			else
			{
				b_target_close[npc.index]=false;
			}
			if((i_ammo_count[npc.index]==0 || b_we_are_reloading[npc.index]) && !b_target_close[npc.index])	//Run away if ammo is 0 or we are reloading. Don't run if target is too close
			{
				
				int Enemy_I_See;
				
				Enemy_I_See = Can_I_See_Enemy(npc.index, PrimaryThreatIndex);
				//Target close enough to hit
				if(IsValidEnemy(npc.index, Enemy_I_See)) //Check if i can even see.
				{
					BarrackBody_ThinkMove(npc.index, 175.0, "ACT_MP_RUN_SECONDARY2", "ACT_MP_RUN_SECONDARY2", 999999.0, _, false);
				}
			}
			else if(flDistanceToTarget < 120000 && i_ammo_count[npc.index]>0)
			{
				BarrackBody_ThinkMove(npc.index, 200.0, "ACT_MP_RUN_SECONDARY2", "ACT_MP_RUN_SECONDARY2", 100000.0, _, false);
				//Look at target so we hit.
			//	npc.FaceTowards(vecTarget, 1000.0);
				fl_idle_timer[npc.index] = 2.5 + GameTime;
				//Can we attack right now?
				if(npc.m_flNextMeleeAttack < GameTime)
				{
					if(npc.m_flNextMeleeAttack < GetGameTime(npc.index) && i_ammo_count[npc.index] >=0)
					{
						//Play attack anim
						npc.AddGesture("ACT_MP_ATTACK_STAND_PRIMARY");
						vecTarget = PredictSubjectPositionForProjectiles(npc, PrimaryThreatIndex, 1100.0);
						npc.FaceTowards(vecTarget, 20000.0);
						npc.PlayRangedSound();
						npc.FireParticleRocket(vecTarget, 100.0 * npc.BonusDamageBonus ,  1200.0, 200.0 , "raygun_projectile_blue", true , false, _, _,_, GetClientOfUserId(npc.OwnerUserId));
						npc.m_flNextMeleeAttack = GameTime + 0.5* npc.BonusFireRate;
						npc.m_flReloadIn = GameTime + 1.75* npc.BonusFireRate;
						i_ammo_count[npc.index]--;
					}
				}
			}
			else
			{
				BarrackBody_ThinkMove(npc.index, 200.0, "ACT_MP_RUN_SECONDARY2", "ACT_MP_RUN_SECONDARY2", 100000.0, _, false);
			}
		}
		else
		{
			BarrackBody_ThinkMove(npc.index, 200.0, "ACT_MP_RUN_SECONDARY2", "ACT_MP_RUN_SECONDARY2", 100000.0, _, false);
			npc.PlayIdleSound();
		}
	}
}

void Barrack_Alt_Mecha_Barrager_NPCDeath(int entity)
{
	Barrack_Alt_Mecha_Barrager npc = view_as<Barrack_Alt_Mecha_Barrager>(entity);
	BarrackBody_NPCDeath(npc.index);
	SDKUnhook(npc.index, SDKHook_Think, Barrack_Alt_Mecha_Barrager_ClotThink);
}