# YYYY-MM · <本月主题>：`epi-xxx` 卫星仓

> 复制本文件为 `docs/monthly/YYYY-MM.md` 后填写；不要改动已结束月份的归档。
> 逐月更新流程见 [ROADMAP.md](../../ROADMAP.md) 第 4 节。

| 项 | 内容 |
|---|---|
| 月度版本 | vX.Y |
| 卫星仓 | `epi-xxx`（独立仓库 / 本仓目录） |
| 加厚层 | L? |
| 状态 | 🔜 进行中 / ✅ 完成 / ⏸ 暂停 |
| Release | [vX.Y](https://github.com/Rythonme/EpiStack/releases/tag/vX.Y) |
| 归档建立 | YYYY-MM-DD |

---

## 1. 本月目标

> 一句话：这个月把哪一层从「薄实现」换成「正式实现」，解决什么真实痛点。
> 明确本月**不做什么**（范围控制）。

---

## 2. 任务清单与验收

| 周 | 任务 | 验收标准 | 状态 | 主要产物 |
|---|---|---|---|---|
| W1 | | | ⬜ | |
| W2 | | | ⬜ | |
| W3 | | | ⬜ | |
| W4 | | | ⬜ | |

状态图例：⬜ 待办 · 🔜 进行中 · ✅ 完成 · ⏸ 暂停。

---

## 3. 实测结果

```
L0 … L6 各层的实际输出（贴在跑 pipeline.R --all --check 后的关键行）
```

| 质量闸门 | 结果 |
|---|---|
| 卫星仓单测 / `R CMD check` | |
| `pipeline.R --all --check` | |
| golden 冒烟 | 37 PASS / 0 FAIL |
| 六层链路从头到尾 | |
| 契约口径是否变更（是否需 `--update`） | |

> 若口径变更，必须写明变更原因、人工审阅过 golden diff，并在 CHANGELOG 里记录。

---

## 4. 交付物清单

```
（目录树或文件列表，注明哪些入库、哪些仅本地）
```

---

## 5. 踩坑与关键决策

| 问题 | 处理 |
|---|---|
| | |

---

## 6. 已知边界 / 未决事项

- 

---

## 7. 下月交接

1. 
2. 
3. 
4. 

---

## 附：月末检查表（DoD）

- [ ] 卫星仓可 `R CMD INSTALL` + `library()`，且 `R CMD check` **0 ERROR**
- [ ] `Rscript pipeline.R --all --check` 退出码 0，golden 冒烟 37 PASS / 0 FAIL
- [ ] 六层链路仍能从头跑到尾（换层不炸链路）
- [ ] 仓库不含真实监测数据 / 本地报告 / `.rds` 缓存
- [ ] ROADMAP 状态表、CHANGELOG、README 摘要、看板四处一致
- [ ] `vX.Y` tag 与 GitHub Release 已创建，notes 指向本归档
- [ ] `R-CMD-check` 工作流全绿
