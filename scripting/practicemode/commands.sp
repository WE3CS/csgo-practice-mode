public Action Command_LaunchPracticeMode(int client, int args) {
  if (!CanStartPracticeMode(client)) {
    PM_Message(client, "您现在不能启动练习模式。");
    return Plugin_Handled;
  }

  if (!g_InPracticeMode) {
    if (g_PugsetupLoaded && PugSetup_GetGameState() >= GameState_Warmup) {
      return Plugin_Continue;
    }
    LaunchPracticeMode();
    if (IsPlayer(client)) {
      GivePracticeMenu(client);
    }
  }
  return Plugin_Handled;
}

public Action Command_ExitPracticeMode(int client, int args) {
  if (g_InPracticeMode) {
    ExitPracticeMode();
  }
  return Plugin_Handled;
}

public Action Command_NoFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_ClientNoFlash[client] = !g_ClientNoFlash[client];
  if (g_ClientNoFlash[client]) {
    PM_Message(client, "已屏蔽闪光效果。 再次输入 .noflash 以关闭");
    RequestFrame(KillFlashEffect, GetClientSerial(client));
  } else {
    PM_Message(client, "已禁用屏蔽闪光功能。");
  }
  return Plugin_Handled;
}

public Action Command_Time(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "当你开始移动时计时器将会开始计时，停止移动则计时停止。");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Movement;
  } else {
    // Early stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_Time2(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "输入 .timer2 以再次停止计时器。");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Manual;
    StartClientTimer(client);
  } else {
    // Stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_CountDown(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  float timer_duration = float(GetRoundTimeSeconds());
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    timer_duration = StringToFloat(arg);
  }

  PM_Message(client, "当你开始移动时，倒计时即开始， 输入 .stop 以取消倒计时。");
  g_RunningTimeCommand[client] = true;
  g_RunningLiveTimeCommand[client] = false;
  g_TimerType[client] = TimerType_Countdown_Movement;
  g_TimerDuration[client] = timer_duration;
  StartClientTimer(client);

  return Plugin_Handled;
}

public void StartClientTimer(int client) {
  g_LastTimeCommand[client] = GetEngineTime();
  CreateTimer(0.1, Timer_DisplayClientTimer, GetClientSerial(client),
              TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void StopClientTimer(int client) {
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;

  // Only display the elapsed duration for increasing timers (not a countdown).
  TimerType timer_type = g_TimerType[client];
  if (timer_type == TimerType_Increasing_Manual || timer_type == TimerType_Increasing_Movement) {
    float dt = GetEngineTime() - g_LastTimeCommand[client];
    PM_Message(client, "计时结果： %.2f 秒", dt);
    PrintCenterText(client, "计时结果: %.2f 秒", dt);
  }
}

public Action Timer_DisplayClientTimer(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_RunningTimeCommand[client]) {
    TimerType timer_type = g_TimerType[client];
    if (timer_type == TimerType_Countdown_Movement) {
      float time_left = g_TimerDuration[client];
      if (g_RunningLiveTimeCommand[client]) {
        float dt = GetEngineTime() - g_LastTimeCommand[client];
        time_left -= dt;
      }
      if (time_left >= 0.0) {
        int seconds = RoundToCeil(time_left);
        PrintCenterText(client, "时间: %d:%2d", seconds / 60, seconds % 60);
      } else {
        StopClientTimer(client);
      }
      // TODO: can we clear the hint text here quicker? Perhaps an empty PrintHintText(client, "")
      // call works?
    } else {
      float dt = GetEngineTime() - g_LastTimeCommand[client];
      PrintCenterText(client, "时间: %.1f 秒", dt);
    }
    return Plugin_Continue;
  }
  return Plugin_Stop;
}

public Action Command_CopyGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!IsPlayer(client) || args != 1) {
    PM_Message(client, "用法: .copy <ID>");
    return Plugin_Handled;
  }

  char name[MAX_NAME_LENGTH];
  char id[GRENADE_ID_LENGTH];
  GetCmdArg(1, id, sizeof(id));

  char targetAuth[AUTH_LENGTH];
  if (FindId(id, targetAuth, sizeof(targetAuth))) {
    int newid = CopyGrenade(targetAuth, id, client);
    if (newid != -1) {
      PM_Message(client, "已复制投掷至新 ID %d", newid);
    } else {
      PM_Message(client, "无法找到投掷物 %s 从 %s", newid, name);
    }
  }

  return Plugin_Handled;
}

public Action Command_Respawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
    return Plugin_Handled;
  }

  g_SavedRespawnActive[client] = true;
  GetClientAbsOrigin(client, g_SavedRespawnOrigin[client]);
  GetClientEyeAngles(client, g_SavedRespawnAngles[client]);
  PM_Message(
      client,
      "已保存重生点，当你死亡将重生至此，使用 {GREEN}.stop {NORMAL}以取消。");
  return Plugin_Handled;
}

public Action Command_StopRespawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_SavedRespawnActive[client] = false;
  PM_Message(client, "已取消从已保存的位置重生。");
  return Plugin_Handled;
}

public Action Command_Spec(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 1");
  return Plugin_Handled;
}

public Action Command_JoinT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 2");
  return Plugin_Handled;
}

public Action Command_JoinCT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 3");
  return Plugin_Handled;
}

public Action Command_StopAll(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (g_SavedRespawnActive[client]) {
    Command_StopRespawn(client, 0);
  }
  if (g_TestingFlash[client]) {
    Command_StopFlash(client, 0);
  }
  if (g_RunningTimeCommand[client]) {
    StopClientTimer(client);
  }
  if (g_RunningRepeatedCommand[client]) {
    Command_StopRepeat(client, 0);
  }
  if (g_BotMimicLoaded && IsReplayPlaying()) {
    CancelAllReplays();
  }
  if (g_BotMimicLoaded && BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  }
  return Plugin_Handled;
}

public Action Command_FastForward(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (g_FastfowardRequiresZeroVolumeCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && g_ClientVolume[i] > 0.01) {
        PM_Message(client, "所有玩家必须将音量降低至 0.01 以允许使用 .ff 指令。");
        return Plugin_Handled;
      }
    }
  }

  // Freeze clients so it's not really confusing.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      g_PreFastForwardMoveTypes[i] = GetEntityMoveType(i);
      SetEntityMoveType(i, MOVETYPE_NONE);
    }
  }

  // Smokes last around 18 seconds.
  PM_MessageToAll("快进20秒。。。。");
  SetCvar("host_timescale", 10);
  CreateTimer(20.0, Timer_ResetTimescale);

  return Plugin_Handled;
}

public Action Timer_ResetTimescale(Handle timer) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  SetCvar("host_timescale", 1);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      SetEntityMoveType(i, g_PreFastForwardMoveTypes[i]);
    }
  }
  return Plugin_Handled;
}

public Action Command_Repeat(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (args < 2) {
    PM_Message(client, "用法: .repeat <时间间隔（秒）> <任何聊天指令>");
    return Plugin_Handled;
  }

  char timeString[64];
  char fullString[256];
  if (GetCmdArgString(fullString, sizeof(fullString)) &&
      SplitOnSpace(fullString, timeString, sizeof(timeString), g_RunningRepeatedCommandArg[client],
                   sizeof(fullString))) {
    float time = StringToFloat(timeString);
    if (time <= 0.0) {
      PM_Message(client, "用法: .repeat <时间间隔（秒）> <任何聊天指令>");
      return Plugin_Handled;
    }

    g_RunningRepeatedCommand[client] = true;
    FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
    CreateTimer(time, Timer_RepeatCommand, GetClientSerial(client),
                TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    PM_Message(client, "每 %.1f 秒将运行一次该指令。", time);
    PM_Message(client, "需要结束时可使用 {GREEN}.stop {NORMAL}指令");
  }

  return Plugin_Handled;
}

public Action Timer_RepeatCommand(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (!IsPlayer(client) || !g_RunningRepeatedCommand[client]) {
    return Plugin_Stop;
  }

  FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
  return Plugin_Continue;
}

public Action Command_RoundRepeat(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (args < 2) {
    PM_Message(client,
               "用法: .roundrepeat <当回合开始后的时间间隔（秒）> <任何聊天指令>");
    return Plugin_Handled;
  }

  char timeString[64];
  char fullString[256];
  char cmd[256];
  if (GetCmdArgString(fullString, sizeof(fullString)) &&
      SplitOnSpace(fullString, timeString, sizeof(timeString), cmd, sizeof(cmd))) {
    float time = StringToFloat(timeString);
    if (time < 0.0) {
      PM_Message(client,
                 "用法: .roundrepeat <当回合开始后的时间间隔（秒）> <任何聊天指令>");
      return Plugin_Handled;
    }

    g_RunningRepeatedCommand[client] = true;
    PM_Message(client, "当回合开始后每 %.1f 秒运行一次该指令。", time);
    PM_Message(client, "需要结束时可使用 {GREEN}.stop {NORMAL}指令");
    g_RunningRoundRepeatedCommandDelay[client].Push(time);
    g_RunningRoundRepeatedCommandArg[client].PushString(cmd);
  }

  return Plugin_Handled;
}

public void FreezeEnd_RoundRepeat(int client) {
  if (g_RunningRepeatedCommand[client]) {
    for (int i = 0; i < g_RunningRoundRepeatedCommandDelay[client].Length; i++) {
      float delay = g_RunningRoundRepeatedCommandDelay[client].Get(i);
      char cmd[256];
      g_RunningRoundRepeatedCommandArg[client].GetString(i, cmd, sizeof(cmd));
      DataPack p = new DataPack();
      p.WriteCell(GetClientSerial(client));
      p.WriteString(cmd);
      CreateTimer(delay, Timer_RoundRepeatCommand, p);
    }
  }
}

public Action Timer_RoundRepeatCommand(Handle timer, DataPack p) {
  p.Reset();
  int client = GetClientFromSerial(p.ReadCell());
  if (!IsPlayer(client) || !g_RunningRepeatedCommand[client]) {
    return Plugin_Stop;
  }

  char cmd[256];
  p.ReadString(cmd, sizeof(cmd));
  FakeClientCommand(client, "say %s", cmd);
  return Plugin_Continue;
}

public Action Command_StopRepeat(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (g_RunningRepeatedCommand[client]) {
    g_RunningRepeatedCommand[client] = false;
    g_RunningRoundRepeatedCommandArg[client].Clear();
    g_RunningRoundRepeatedCommandDelay[client].Clear();
    PM_Message(client, "已取消.repeat指令。");
  }
  return Plugin_Handled;
}

public Action Command_Delay(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (args < 2) {
    PM_Message(client, "用法: .delay <时间间隔(秒)> <任何聊天指令>");
    return Plugin_Handled;
  }

  char timeString[64];
  char fullString[256];
  if (GetCmdArgString(fullString, sizeof(fullString)) &&
      SplitOnSpace(fullString, timeString, sizeof(timeString), g_RunningRepeatedCommandArg[client],
                   sizeof(fullString))) {
    float time = StringToFloat(timeString);
    if (time <= 0.0) {
      PM_Message(client, "用法: .repeat <时间间隔(秒)> <任何聊天指令>");
      return Plugin_Handled;
    }

    CreateTimer(time, Timer_DelayedComand, GetClientSerial(client));
  }

  return Plugin_Handled;
}

public Action Timer_DelayedComand(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
  }
  return Plugin_Stop;
}

public Action Command_Map(int client, int args) {
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    // Before trying to change to the arg first, check to see if
    // there's a clear match in the maplist
    for (int i = 0; i < g_MapList.Length; i++) {
      char map[PLATFORM_MAX_PATH];
      g_MapList.GetString(i, map, sizeof(map));
      if (StrContains(map, arg, false) >= 0) {
        ChangeMap(map);
        return Plugin_Handled;
      }
    }
    ChangeMap(arg);

  } else {
    Menu menu = new Menu(ChangeMapHandler);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.SetTitle("选择一个地图：");
    for (int i = 0; i < g_MapList.Length; i++) {
      char map[PLATFORM_MAX_PATH];
      g_MapList.GetString(i, map, sizeof(map));
      char cleanedMapName[PLATFORM_MAX_PATH];
      CleanMapName(map, cleanedMapName, sizeof(cleanedMapName));
      AddMenuInt(menu, i, cleanedMapName);
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  }

  return Plugin_Handled;
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int index = GetMenuInt(menu, param2);
    char map[PLATFORM_MAX_PATH];
    g_MapList.GetString(index, map, sizeof(map));
    ChangeMap(map);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void ChangeSettingById(const char[] id, bool setting) {
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionIds.GetString(i, name, sizeof(name));
    if (StrEqual(name, id, false)) {
      ChangeSetting(i, setting, true);
    }
  }
}

public Action Command_DryRun(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  SetCvar("mp_freezetime", g_DryRunFreezeTimeCvar.IntValue);
  ChangeSettingById("allradar", false);
  ChangeSettingById("blockroundendings", false);
  ChangeSettingById("grenadetrajectory", false);
  ChangeSettingById("infiniteammo", false);
  ChangeSettingById("noclip", false);
  ChangeSettingById("respawning", false);
  ChangeSettingById("showimpacts", false);

  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    g_RunningRepeatedCommand[i] = false;
    g_SavedRespawnActive[i] = false;
    g_ClientNoFlash[client] = false;
    if (IsPlayer(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}

static void ChangeSettingArg(int client, const char[] arg, bool enabled) {
  if (StrEqual(arg, "all", false)) {
    for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
      ChangeSetting(i, enabled, true);
    }
    return;
  }

  ArrayList indexMatches = new ArrayList();
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionNames.GetString(i, name, sizeof(name));
    if (StrContains(name, arg, false) >= 0) {
      indexMatches.Push(i);
    }
  }

  if (indexMatches.Length == 0) {
    PM_Message(client, "无设置相符 \"%s\"", arg);
  } else if (indexMatches.Length == 1) {
    if (!ChangeSetting(indexMatches.Get(0), enabled, true)) {
      PM_Message(client, "该设置已启动。");
    }
  } else {
    PM_Message(client, "多个设置相符 \"%s\"", arg);
  }

  delete indexMatches;
}

public Action Command_Enable(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, true);
  return Plugin_Handled;
}

public Action Command_Disable(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, false);
  return Plugin_Handled;
}

public Action Command_God(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!GetCvarIntSafe("sv_cheats")) {
    PM_Message(client, ".god 需要 sv_cheats 1");
    return Plugin_Handled;
  }

  FakeClientCommand(client, "god");
  return Plugin_Handled;
}

public Action Command_EndRound(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!GetCvarIntSafe("sv_cheats")) {
    PM_Message(client, ".endround 需要 sv_cheats 1");
    return Plugin_Handled;
  }

  ServerCommand("endround");
  return Plugin_Handled;
}

public Action Command_Break(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int ent = -1;
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    AcceptEntityInput(ent, "Break");
  }
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    AcceptEntityInput(ent, "Break");
  }

  PM_MessageToAll("已破坏所有可破坏实体.");
  return Plugin_Handled;
}
