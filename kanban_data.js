// EpiStack 交付看板 · 唯一数据源
// 状态变化时只改本文件，刷新 项目进展看板.html 即生效，无需改动 HTML。
// status: done | doing | todo | backlog
window.KANBAN_DATA = {
  project: {
    name: "EpiStack",
    subtitle: "传染病监测数据的分析链路 · 分层实现，契约统一",
    repo: "github.com/Rythonme/EpiStack（公开 · MIT）",
    updated: "2026-11-13",
    owner: "Rythonme",
    target: "逐月补全 L2–L6，每层可独立安装"
  },
  columns: [
    { id: "todo",    title: "待办",   color: "#718096" },
    { id: "doing",   title: "进行中", color: "#2c7bc9" },
    { id: "done",    title: "已完成", color: "#2e9e6b" },
    { id: "backlog", title: "后续层", color: "#8e7cc3" }
  ],
  tasks: [
    { id: "E1", title: "L0 契约层 epiCore 0.1.0", desc: "契约 schema、地区编码、邻接权重、read_counts()、质控与周期映射；40 项单测，R CMD check 0 ERROR", tag: "发布", week: "v0.1", status: "done" },
    { id: "E2", title: "六层端到端示例", desc: "合成 16 地区面板跑通 L0 → L6，产出预警清单与单文件 HTML 报告；固定种子，结果可复现", tag: "示例", week: "v0.1", status: "done" },
    { id: "E3", title: "编排与集成基线", desc: "pipeline.R 分层计划、输入指纹缓存、统一 manifest；27 项指标与 10 项结构断言作为回归基线", tag: "工程", week: "v0.1", status: "done" },
    { id: "E4", title: "CI 与报告站", desc: "R CMD build/check 作为门禁，每晚重跑链路并把合成数据报告发布到 Pages", tag: "工程", week: "v0.1.1", status: "done" },
    { id: "E5", title: "源码包分发", desc: "Release 附带源码 tarball，一行 install.packages(URL) 即可安装，无需 clone 与 Rtools", tag: "发布", week: "v0.1.1", status: "done" },
    { id: "E6", title: "L1 接入层 epiIngest 0.2.0", desc: "多源读取、8 类质控规则、质控单、血缘 JSON、脱敏、可选适配器；16 个导出函数，96 项断言", tag: "发布", week: "v0.2.0", status: "done" },
    { id: "L2", title: "L2 epiAlert", desc: "季节性基线、异常信号与阈值配置；与 surveillance / WarnEpi 的接口对齐", tag: "预警", week: "下一层", status: "todo" },
    { id: "L3", title: "L3 epiSpace", desc: "Moran / LISA / 热点分析，BYM2 与 INLA 模板", tag: "空间", week: "计划", status: "backlog" },
    { id: "L4", title: "L4 epiIneq", desc: "集中指数、SII、分解，以及医疗可达性分析", tag: "不平等", week: "计划", status: "backlog" },
    { id: "L5", title: "L5 epiReport", desc: "多层结果汇编、报告脱敏开关、交互看板", tag: "报告", week: "计划", status: "backlog" },
    { id: "L6", title: "L6 epiFlow", desc: "全流水线编排、增量重跑、定时调度", tag: "编排", week: "计划", status: "backlog" }
  ],
  milestones: [
    { name: "v0.1 · epiCore", date: "2026-11-10", state: "done" },
    { name: "v0.1.1 · 安装渠道", date: "2026-11-11", state: "done" },
    { name: "v0.2.0 · epiIngest", date: "2026-11-13", state: "done" },
    { name: "v0.3 · epiAlert", date: "计划中", state: "" },
    { name: "v1.0 · 全层集成", date: "计划中", state: "" }
  ],
  changelog: [
    { date: "2026-11-13", text: "仓库整理：面板用例目录改为 case_panel，v1 周报原型移出仓库；链路与基线数值不变。" },
    { date: "2026-11-13", text: "v0.2.0：L1 接入层 epiIngest 发布，主仓链路改用它输出契约，数值与之前一致。" },
    { date: "2026-11-11", text: "v0.1.1：Release 附带源码 tarball，可用一行命令联网安装。" },
    { date: "2026-11-10", text: "v0.1：epiCore 首个版本，六层示例与编排入口跑通。" }
  ],
  note: "数据与结果均为合成示例；真实监测数据不入库、不上传。"
};
