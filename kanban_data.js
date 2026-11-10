// EpiStack 项目进展看板 · 唯一数据源（v2 体系版）
// 任务状态变化时只改本文件，刷新 项目进展看板.html 即生效，无需改动 HTML。
// status: done | doing | todo | backlog
window.KANBAN_DATA = {
  project: {
    name: "EpiStack",
    subtitle: "端到端传染病时空分析与健康不平等体系 · 2026-11 立项",
    repo: "github.com/Rythonme/EpiStack（公开 · MIT · 2026-11-11 发布）+ 卫星仓 epi-core/",
    updated: "2026-11-11 00:35",
    owner: "本人",
    target: "已公开发布，按 ROADMAP.md 逐月更新 ｜ 12 月 epi-ingest · v0.2 ｜ EpiStack 1.0 · 2027-10"
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
    { id: "T7", title: "契约版本化 + 集成冒烟测试（W2）", desc: "golden 27 项指标 + 10 项结构断言 = 37 PASS / 0 FAIL；契约探针校验字段/质控/权重行和；注入暴发 6 周必须命中", tag: "质量", week: "W2", status: "done" },
    { id: "T8", title: "targets 编排雏形 + renv（W2/W3）", desc: "pipeline.R 声明式分层计划 + md5 指纹缓存（skip-if-unchanged 已验证）+ 统一 manifest + 静态报告站；零依赖 renv.lock", tag: "工程", week: "W2", status: "done" },
    { id: "T9", title: "GitHub Actions 与 gh-pages（W3）", desc: "R-CMD-check（build + 0 ERROR 门禁 + 冒烟）、nightly e2e + 隐私守卫 + Pages、README.en.md 英文说明", tag: "工程", week: "W3", status: "done" },
    { id: "T10", title: "面板适配器与 v0.1 发布（W4）", desc: "默认走内置模拟数据；本机私有面板本地验收（数据与结果不公开）；--monthly 月度切换接口；CHANGELOG / MIT / v0.1 tag。口径修正：本机私有面板仅地区-年粒度，公开版本用模拟数据完整演示月度链路", tag: "发布", week: "W4", status: "done" },
    { id: "T11", title: "包质量验证", desc: "R CMD INSTALL + library 可用；R CMD build + check 0 ERROR / 0 NOTE / 1 WARNING（中文注释可移植性）；两条链路最终回归通过", tag: "质量", week: "W1", status: "done" },
    { id: "T12", title: "公开发布 + 逐月更新机制", desc: "发布 Rythonme/EpiStack 公开仓（MIT）；ROADMAP.md 状态表/SOP、docs/monthly/2026-11.md 本月归档与模板；内置模拟数据生成器替代全部真实数据示例，公开仓库不含本机路径与真实观测值；v0.1 / v0.1.1 Release；中英文 README 补仓库地址与 clone 快速开始", tag: "发布", week: "W4+", status: "done" },
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
    { name: "W2 契约版本化 + 冒烟 + 编排", date: "11/10 提前", state: "done" },
    { name: "W3 CI + renv + gh-pages", date: "11/10 提前", state: "done" },
    { name: "W4 HFRS 实测 + v0.1 tag", date: "11/10 提前", state: "done" },
    { name: "公开发布 + 逐月更新机制", date: "11/11", state: "done" }
  ],
  changelog: [
    { date: "2026-11-10 21:15", text: "v1 立项：竞品直验、单点周报工具提案、零依赖原型跑通、看板建立。" },
    { date: "2026-11-10 21:30", text: "升级 v2：L0–L6 体系架构 + 主仓/卫星仓拓扑 + 12 个月路线图；run_e2e.R 六层全通（R 4.6.0，1.3 秒，Moran p=0.031，CI=-0.067）。" },
    { date: "2026-11-10 22:05", text: "W1+W4 提前完成：epi-core 正式 R 包（40 项单测 / R CMD check 0 ERROR）；切片 L0/L1 换成包调用且数值逐位一致；本机私有面板端到端验收（数据与结果不公开）；--monthly 月度接口冒烟通过；v0.1 tag 已打。" },
    { date: "2026-11-10 23:45", text: "W2+W3 提前完成：pipeline.R 分层编排（md5 指纹缓存 / 统一 manifest / 静态报告站）；tests/golden 契约基线 + 冒烟 37 PASS / 0 FAIL；R-CMD-check 与 nightly-e2e+Pages 两个工作流（含隐私守卫）；零依赖 renv.lock、英文 README、R/epi_json.R 零依赖 JSON 读写。四周任务全部完成，v0.1.1 待发。" },
    { date: "2026-11-11 00:20", text: "首次公开发布到 github.com/Rythonme/EpiStack（公开 / MIT）；新增 ROADMAP.md（12 个月状态表 + 逐月更新 SOP + 版本/隐私约定）、docs/monthly/2026-11.md 本月任务归档与 TEMPLATE.md；发布前做隐私加固：移除公开仓库所有本机路径、真实数据文件名与真实汇总数值，新增 demo/make_demo_data.R 内置模拟数据生成器，面板适配器默认走模拟数据、--local 才读本机私有配置；中英文 README 补仓库地址、CI 徽章与 clone 快速开始；同步 v0.1 / v0.1.1 GitHub Release；R-CMD-check 首次远端运行通过，Pages 已启用（仅合成数据站点）。" }
  ],
  note: "本看板只读 kanban_data.js。任务状态变化后改本文件并刷新页面即可，不必改 HTML。数据分析仍在本地执行，原始数据不上传。"
};
