// EpiStack 项目进展看板 · 唯一数据源（v2 体系版）
// 任务状态变化时只改本文件，刷新 项目进展看板.html 即生效，无需改动 HTML。
// status: done | doing | todo | backlog
window.KANBAN_DATA = {
  project: {
    name: "EpiStack",
    subtitle: "端到端传染病时空分析与健康不平等体系 · 2026-11 立项",
    repo: "epistack 主仓（本地 v0.1.0 已打 tag）+ 卫星仓 epi-core/",
    updated: "2026-11-10 22:05",
    owner: "本人",
    target: "v0.1.0 已发布（11/10 提前完成）｜ W2/W3 工程化待办 ｜ EpiStack 1.0 · 2027-10"
  },
  columns: [
    { id: "todo",    title: "待办",   color: "#718096" },
    { id: "doing",   title: "进行中", color: "#2c7bc9" },
    { id: "done",    title: "已完成", color: "#2e9e6b" },
    { id: "backlog", title: "后续月份", color: "#8e7cc3" }
  ],
  tasks: [
    { id: "T1", title: "竞品调研与空白定位", desc: "直验 epichannel / WarnEpi / EpiSignalDetection / sitrep，确认算法层拥挤、交付层空白", tag: "调研", week: "W0", status: "done" },
    { id: "T2", title: "v1 单点原型跑通（L5）", desc: "纯 base R：CSV → 单文件中文 HTML 周报；3 地区，注入暴发全部识别", tag: "原型", week: "W0", status: "done" },
    { id: "T3", title: "端到端体系架构设计", desc: "L0–L6 分层、统一数据契约、主仓+卫星仓拓扑、12 个月路线图", tag: "架构", week: "W0", status: "done" },
    { id: "T4", title: "薄切片六层全通", desc: "run_e2e.R：16 地区 / Moran p=0.031 / CI=-0.067 / 暴发 6 周全中 / manifest", tag: "原型", week: "W0", status: "done" },
    { id: "T5", title: "体系版提案 v2", desc: "README 重写：架构、HFRS 用例、垂直切片策略、技术决策、体系级验收", tag: "规划", week: "W0", status: "done" },
    { id: "T6", title: "epi-core 正式 R 包（W1）", desc: "契约 schema / 地区编码 / 邻接权重 / read_counts() / epi_qc；标准包骨架 + Rd 文档 + 40 项单测；切片 L0/L1 已替换为包调用且回归逐位一致", tag: "开发", week: "W1", status: "done" },
    { id: "T7", title: "契约版本化 + 集成冒烟测试", desc: "schema 版本与 golden-file；注入暴发必须命中，换层不炸链路", tag: "质量", week: "W2", status: "todo" },
    { id: "T8", title: "targets 编排雏形 + renv", desc: "pipeline.R 按层调用卫星仓；renv.lock 锁定依赖", tag: "工程", week: "W2", status: "todo" },
    { id: "T9", title: "GitHub Actions 与 gh-pages", desc: "R-CMD-check + 每晚 e2e + 示例报告自动发布", tag: "工程", week: "W3", status: "todo" },
    { id: "T10", title: "HFRS 实测与 v0.1 发布（W4）", desc: "真实省-年面板 651 行 + 真实 31 省邻接 + 真实人均 GDP 本地实测；--monthly 月度切换接口；CHANGELOG / MIT / v0.1 tag。口径修正：本机无真实月度发病序列，月度仅完成合成数据接口冒烟", tag: "发布", week: "W4", status: "done" },
    { id: "T11", title: "包质量验证", desc: "R CMD INSTALL + library 可用；R CMD build + check 0 ERROR / 0 NOTE / 1 WARNING（中文注释可移植性）；两条链路最终回归通过", tag: "质量", week: "W1", status: "done" },
    { id: "B1", title: "2026-12 · epi-ingest（L1）", desc: "多源读取器 + 质控报告 + 栅格协变量 zonal stats", tag: "路线图", week: "12月", status: "backlog" },
    { id: "B2", title: "2027-01 · epi-alert（L2）", desc: "4 种预警算法统一接口；WarnEpi / surveillance 适配器", tag: "路线图", week: "1月", status: "backlog" },
    { id: "B3", title: "2027-02/03 · epi-space（L3）", desc: "Moran / LISA / GWR，再上 BYM2 与景观格局指数", tag: "路线图", week: "2–3月", status: "backlog" },
    { id: "B4", title: "2027-04 · epi-ineq（L4）", desc: "CI / SII / 分解 + 中文报告，呼应统计大赛课题", tag: "路线图", week: "4月", status: "backlog" },
    { id: "B5", title: "2027-05 · epi-access（L4）", desc: "OSM 路网出行时间 + 基层医疗服务区 delineation", tag: "路线图", week: "5月", status: "backlog" },
    { id: "B6", title: "2027-06/07 · report + dashboard（L5）", desc: "多层结果自动汇编、脱敏开关、交互看板与 Pages 发布", tag: "路线图", week: "6–7月", status: "backlog" },
    { id: "B7", title: "2027-08 · epi-flow（L6）", desc: "targets 全流水线、CI、每月定时重跑", tag: "路线图", week: "8月", status: "backlog" },
    { id: "B8", title: "2027-09 · epi-geoai（D 区）", desc: "遥感协变量批处理、GeoFM 评测审计（清单 D32–D35）", tag: "路线图", week: "9月", status: "backlog" },
    { id: "B9", title: "2027-10 · EpiStack 1.0", desc: "集成发布 + HFRS 完整案例复现 + 文档站", tag: "路线图", week: "10月", status: "backlog" }
  ],
  milestones: [
    { name: "W0 立项 + 薄切片全通", date: "11/10", state: "done" },
    { name: "W1 epi-core 正式包", date: "11/10 提前", state: "done" },
    { name: "W2 契约版本化 + 冒烟测试", date: "11/24", state: "todo" },
    { name: "W3 CI + renv + gh-pages", date: "12/01", state: "todo" },
    { name: "W4 HFRS 实测 + v0.1 tag", date: "11/10 提前", state: "done" }
  ],
  changelog: [
    { date: "2026-11-10 21:15", text: "v1 立项：竞品直验、单点周报工具提案、零依赖原型跑通、看板建立。" },
    { date: "2026-11-10 21:30", text: "升级 v2：L0–L6 体系架构 + 主仓/卫星仓拓扑 + 12 个月路线图；run_e2e.R 六层全通（R 4.6.0，1.3 秒，Moran p=0.031，CI=-0.067）。" },
    { date: "2026-11-10 22:05", text: "W1+W4 提前完成：epi-core 正式 R 包（40 项单测 / R CMD check 0 ERROR）；切片 L0/L1 换成包调用且数值逐位一致；HFRS 真实省-年面板 651 行 + 真实 31 省邻接 + 真实 GDP 端到端实测；--monthly 月度接口冒烟通过；v0.1 tag 已打。" }
  ],
  note: "本看板只读 kanban_data.js。任务状态变化后改本文件并刷新页面即可，不必改 HTML。数据分析仍在本地执行，原始数据不上传。"
};
