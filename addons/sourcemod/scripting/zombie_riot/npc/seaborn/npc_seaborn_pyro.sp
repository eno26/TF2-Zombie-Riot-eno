#pragma semicolon 1
#pragma newdecls required

static const char g_DeathSounds[][] =
{
	"vo/pyro_paincrticialdeath01.mp3",
	"vo/pyro_paincrticialdeath02.mp3",
	"vo/pyro_paincrticialdeath03.mp3"
};

static const char g_HurtSounds[][] =
{
	"vo/pyro_painsharp01.mp3",
	"vo/pyro_painsharp02.mp3",
	"vo/pyro_painsharp03.mp3",
	"vo/pyro_painsharp04.mp3",
	"vo/pyro_painsharp05.mp3"
};

static const char g_IdleAlertedSounds[][] =
{
	"vo/taunts/pyro_taunts01.mp3",
	"vo/taunts/pyro_taunts02.mp3",
	"vo/taunts/pyro_taunts03.mp3"
};

static const char g_MeleeHitSounds[][] =
{
	"weapons/axe_hit_flesh1.wav",
	"weapons/axe_hit_flesh2.wav",
	"weapons/axe_hit_flesh3.wav"
};

static const char g_MeleeAttackSounds[][] =
{
	"weapons/machete_swing.wav"
};

methodmap SeabornPyro < CClotBody
{
	public void PlayIdleSound()
	{
		if(this.m_flNextIdleSound > GetGameTime(this.index))
			return;
		
		EmitSoundToAll(g_IdleAlertedSounds[GetRandomInt(0, sizeof(g_IdleAlertedSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 80);
		this.m_flNextIdleSound = GetGameTime(this.index) + GetRandomFloat(12.0, 24.0);
	}
	public void PlayHurtSound()
	{
		EmitSoundToAll(g_HurtSounds[GetRandomInt(0, sizeof(g_HurtSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 80);
	}
	public void PlayDeathSound() 
	{
		EmitSoundToAll(g_DeathSounds[GetRandomInt(0, sizeof(g_DeathSounds) - 1)], this.index, SNDCHAN_VOICE, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, 80);
	}
	public void PlayMeleeSound()
 	{
		EmitSoundToAll(g_MeleeAttackSounds[GetRandomInt(0, sizeof(g_MeleeAttackSounds) - 1)], this.index, SNDCHAN_AUTO, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, _);
	}
	public void PlayMeleeHitSound()
	{
		EmitSoundToAll(g_MeleeHitSounds[GetRandomInt(0, sizeof(g_MeleeHitSounds) - 1)], this.index, SNDCHAN_AUTO, NORMAL_ZOMBIE_SOUNDLEVEL, _, NORMAL_ZOMBIE_VOLUME, _);	
	}
	
	public SeabornPyro(int client, float vecPos[3], float vecAng[3], bool ally)
	{
		SeabornPyro npc = view_as<SeabornPyro>(CClotBody(vecPos, vecAng, "models/player/pyro.mdl", "1.0", "1500", ally));
		
		i_NpcInternalId[npc.index] = SEABORN_SOLDIER;
		npc.SetActivity("ACT_MP_RUN_MELEE");
		
		npc.m_iBleedType = BLEEDTYPE_SEABORN;
		npc.m_iStepNoiseType = STEPSOUND_NORMAL;
		npc.m_iNpcStepVariation = STEPTYPE_SEABORN;
		
		SetEntProp(npc.index, Prop_Send, "m_nSkin", 1);

		SDKHook(npc.index, SDKHook_Think, SeabornPyro_ClotThink);
		
		npc.m_flSpeed = 300.0;
		npc.m_flGetClosestTargetTime = 0.0;
		
		SetEntityRenderMode(npc.index, RENDER_TRANSCOLOR);
		SetEntityRenderColor(npc.index, 155, 155, 255, 255);
		
		npc.m_iWearable1 = npc.EquipItem("head", "models/weapons/c_models/c_rift_fire_axe/c_rift_fire_axe.mdl");
		npc.m_iWearable2 = npc.EquipItem("head", "models/workshop/player/items/pyro/sbox2014_sole_mate/sbox2014_sole_mate.mdl");

		return npc;
	}
}

public void SeabornPyro_ClotThink(int iNPC)
{
	SeabornPyro npc = view_as<SeabornPyro>(iNPC);

	float gameTime = GetGameTime(npc.index);
	if(npc.m_flNextDelayTime > gameTime)
		return;
	
	npc.m_flNextDelayTime = gameTime + DEFAULT_UPDATE_DELAY_FLOAT;
	npc.Update();

	if(npc.m_blPlayHurtAnimation)
	{
		npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST", false);
		npc.PlayHurtSound();
		npc.m_blPlayHurtAnimation = false;
	}
	
	if(npc.m_flNextThinkTime > gameTime)
		return;
	
	npc.m_flNextThinkTime = gameTime + 0.1;

	if(npc.m_iTarget && !IsValidEnemy(npc.index, npc.m_iTarget))
		npc.m_iTarget = 0;
	
	if(!npc.m_iTarget || npc.m_flGetClosestTargetTime < gameTime)
	{
		npc.m_iTarget = GetClosestTarget(npc.index);
		npc.m_flGetClosestTargetTime = gameTime + 1.0;
	}
	
	if(npc.m_iTarget > 0)
	{
		float vecTarget[3]; vecTarget = WorldSpaceCenter(npc.m_iTarget);
		float distance = GetVectorDistance(vecTarget, WorldSpaceCenter(npc.index), true);		
		
		if(distance < npc.GetLeadRadius())
		{
			float vPredictedPos[3]; vPredictedPos = PredictSubjectPosition(npc, npc.m_iTarget);
			PF_SetGoalVector(npc.index, vPredictedPos);
		}
		else 
		{
			PF_SetGoalEntity(npc.index, npc.m_iTarget);
		}

		npc.StartPathing();
		
		if(npc.m_flAttackHappens)
		{
			if(npc.m_flAttackHappens < gameTime)
			{
				npc.m_flAttackHappens = 0.0;
				
				Handle swingTrace;
				npc.FaceTowards(vecTarget, 15000.0);
				if(npc.DoSwingTrace(swingTrace, npc.m_iTarget, _, _, _, _))
				{
					int target = TR_GetEntityIndex(swingTrace);
					if(target > 0)
					{
						if(!NpcStats_IsEnemySilenced(npc.index))
						{
							if(target > MaxClients)
							{
								NPC_Ignite(target, npc.index, 5.0, -1);
							}
							else
							{
								TF2_AddCondition(target, TFCond_Gas, 1.5);
							}
						}
						
						npc.PlayMeleeHitSound();
						SDKHooks_TakeDamage(target, npc.index, npc.index, 100.0, DMG_CLUB);
					}
				}

				delete swingTrace;
			}
		}

		if(distance < 10000.0 && npc.m_flNextMeleeAttack < gameTime)
		{
			int target = Can_I_See_Enemy(npc.index, npc.m_iTarget);
			if(IsValidEnemy(npc.index, target))
			{
				npc.m_iTarget = target;

				npc.AddGesture("ACT_MP_ATTACK_STAND_MELEE");

				npc.PlayMeleeSound();
				
				npc.m_flAttackHappens = gameTime + 0.35;
				npc.m_flNextMeleeAttack = gameTime + 0.95;
			}
		}
	}
	else
	{
		npc.StopPathing();
	}

	npc.PlayIdleSound();
}

void SeabornPyro_NPCDeath(int entity)
{
	SeabornPyro npc = view_as<SeabornPyro>(entity);
	if(!npc.m_bGib)
		npc.PlayDeathSound();
	
	if(IsValidEntity(npc.m_iWearable1))
		RemoveEntity(npc.m_iWearable1);
	
	if(!NpcStats_IsEnemySilenced(npc.index))
	{
		float startPosition[3];
		GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", startPosition); 
		startPosition[2] += 45;

		Explode_Logic_Custom(50.0, -1, npc.index, -1, startPosition, 100.0, _, _, true, _, true);

		DataPack pack_boom = new DataPack();
		pack_boom.WriteFloat(startPosition[0]);
		pack_boom.WriteFloat(startPosition[1]);
		pack_boom.WriteFloat(startPosition[2]);
		pack_boom.WriteCell(1);
		RequestFrame(MakeExplosionFrameLater, pack_boom);
	}
	
	SDKUnhook(npc.index, SDKHook_Think, SeabornPyro_ClotThink);
}