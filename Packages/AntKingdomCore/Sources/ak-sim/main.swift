// 命令行入口：输出与 `python tools/economy_sim.py --json` 同结构的结果，供差分比较。
// C00 只打印基线信息；C01–C03 补齐真实输出。
import AntKingdomCore

print("{\"rules_baseline\": \"\(CoreInfo.rulesBaseline)\"}")
