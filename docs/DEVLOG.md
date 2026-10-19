# 开发记录 / Implementation notes

## 一句话

把动作游戏的手感与固定 BPM 的音频时钟绑在一起：攻击可以随时出，但只有命中帧与
音频时钟的偏差决定音乐层、连击和最终评级。

## 技术栈

- Godot 4.7.2 / GDScript
- 1280×720 / GL Compatibility
- 无第三方插件
- numpy 生成全部音频
- 所有视觉由 `_draw()` 与 CanvasItem 图形 API 绘制

## 关键实现顺序

1. **时间轴先于战斗**：先写 `Rhythm`（纯数学）与 `Conductor`（音频时钟），
   再把玩家攻击命中接到 `Conductor.judge()`。
2. **把攻击的 active window 变成命中采样窗口**：玩家每帧扫描前方矩形，命中即结算。
3. **动态层用同一采样零点**：7 条 stem 等长、同帧 `play(0)`、锁相循环；
   未解锁层不是暂停而是 -70dB 静音，保证进入时无缝。
4. **封印系统**：不把音乐解锁绑在击杀数上，清场后生成封印，命中必须 GOOD+，
   后续封印要求 `J` 或三种攻击。
5. **Boss 以拍点调度**：telegraph 在拍点开始，strike time 由 `Conductor` 计算；
   phase 2 使用 1.5 拍/半拍 recovery 打破可预测性。
6. **终章四击**：把四种攻击放入四个乐句拍点，窗口 ±205ms；失败仍然通关。
7. **UI 状态机**：Main 管理 menu/play/pause/calibration/help/results；
   暂停时冻结树和音频，校准用独立单调时钟。
8. **首次游玩的六步互动教学**：真实关卡中的练习木桩 + 真实命中判定；完成后清空
   教程统计、开启教学门，再让普通敌人醒来。菜单可重玩，教程视频单独录制。

## 文件职责

| 文件 | 职责 |
|---|---|
| `scripts/core/rhythm.gd` | 纯节拍/判定数学 |
| `scripts/core/conductor.gd` | 音频时钟、stems、动态层、暂停 |
| `scripts/core/game_state.gd` | 一次演奏的统计与完美条件 |
| `scripts/core/audio_bank.gd` | stem 加载、loop 设置、SFX 池 |
| `scripts/data/game_config.gd` | 全部战斗/敌人/Boss 调参 |
| `scripts/player/player.gd` | 移动、W 跳跃、四种攻击、无敌帧、程序化绘制 |
| `scripts/enemies/enemy.gd` | 四型敌人、护甲、飞行、随机时值 |
| `scripts/enemies/note_projectile.gd` | 可被斩掉的音符弹 |
| `scripts/boss/boss.gd` | 三阶段、核心、终章、程序化绘制 |
| `scripts/world/world.gd` | 遭遇、门、封印、Boss 编排、检查点 |
| `scripts/world/level_art.gd` | 地形数据、碰撞、程序化场景 |
| `scripts/world/backdrop.gd` | 屏幕空间视差背景 |
| `scripts/ui/hud.gd` | 战斗中所有显示 |
| `scripts/ui/tutorial_overlay.gd` | 首次游玩的六步互动教学 |
| `scripts/world/training_dummy.gd` | 教学用练习木桩 |
| `scripts/ui/results.gd` | 结算/评级/完美演出 |
| `scripts/ui/calibration.gd` | 8 次点击校准 |
| `scripts/main.gd` | 应用流程/淡入/截图入口 |
| `tools/gen_audio.py` | 全部音乐与 SFX |

## 调参入口

**优先改**：

- `GameConfig.RUN_SPEED / JUMP_VELOCITY / DODGE_*`
- `GameConfig.ATTACKS`：startup / active / recovery / damage / hitstop
- `GameConfig.ENEMIES`：HP / windup / damage
- `GameConfig.BOSS`：HP / phase ratio
- `Rhythm.PERFECT_WINDOW / GREAT_WINDOW / GOOD_WINDOW`
- `Conductor.LEVEL_DB / BOSS_DB`

**不要**在 UI 里写死判定/伤害数字；现有 UI 只读取状态。

## 验证

```powershell
$godot = "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$proj  = "D:\Users\32747\Documents\deepseek-harness\default-workspace\Resonant"
& $godot --headless --path $proj res://tests/TestRunner.tscn
```

测试为场景而不是 `--script`，因为 `--script` 模式下 Godot 不注册 autoload 标识符。
当前 141 checks。

视觉截图：

```powershell
& $godot --path $proj -- --autostart --capture=boss --quit-after-capture
```

可用的 capture target：`menu`、`tutorial`、`game`、`combat`、`stage2`、`stage3`、`boss`、
`finale`、`pause`、`calibration`、`results`、`perfect`。

视频录制：

```powershell
# 互动教学（24s）
& $godot --path $proj --write-movie docs/resonant_tutorial.avi --fixed-fps 30 `
    --quit-after 800 -- --tutorial-demo

# 机制展示（28s）
& $godot --path $proj --write-movie docs/resonant_demo.avi --fixed-fps 30 `
    --quit-after 900 -- --demo
```

## 目前没有验证的

- 真实玩家的节奏感/手感；所有窗口和动作时长仍需人工试玩。
- 不同声卡/蓝牙耳机的实际延迟；校准界面提供补偿，但未做硬件矩阵测试。
- 出口构建（本机无 export templates）。
- 4K/高 DPI 缩放；当前按 1280×720 的 `canvas_items` 拉伸。
- 长按/连打下的音频池抢占；22 个池足够 Demo 密度，但极端多目标同帧命中可能复用。

## 下一步（如果继续）

1. 人工试玩 10 次，记录“重击前摇是否太长”“终章四击是否可读”。
2. 将终章改为可配置的 1/2 拍间隔，按试玩结果选择。
3. 给 Boss 核心窗口增加更明确的音效倒计时。
4. 增加一条失败/复活后的音乐“恢复”过门。
5. 导出 Windows 包并把 28 秒 showcase 扩成完整 60 秒实机流程。
