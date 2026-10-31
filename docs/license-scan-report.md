# 「知踪」代码许可证扫描分析报告

## 0. 扫描概况

| 项目 | 内容 |
| --- | --- |
| 扫描对象 | https://github.com/Menquan754/eaxm-blind-spot-tracker |
| 扫描提交 | `0f3a922`（2026-10-29，强制推送前的仓库快照） |
| 扫描时间 | 2026-10-29，耗时约 4 分钟 |
| 扫描工具 | ScanCode Toolkit 32.5.0 |
| 许可证库 | SPDX License List 3.27 |
| 输出格式 | ScanCode Output Format 4.1.0 |
| 扫描选项 | `--license --copyright --package --info --classify` |
| 扫描范围 | 仓库全部 64 个受版本控制的文件 |

文件构成：29 个 `.ets` 源码、2 个 `.ts` 构建脚本、11 个 `.json5` 配置、9 个 `.json` 配置、8 个 `.png` 图片、1 个 `.svg` 图标、2 个 `.gitignore`、1 个混淆规则 `.txt`、1 个 `LICENSE`。

> 说明：主扫描中有 2 个文件（`EntryAbility.ets`、`EntryBackupAbility.ets`）触发单文件 120 秒超时；已用 600 秒超时单独重扫，两文件均无许可证发现、无扫描错误。因此最终覆盖 64/64 个文件。

---

## 1. 结论摘要

1. **仓库只检测到 1 处许可证声明**：根目录 `LICENSE`，为 **Apache License 2.0**，文本匹配覆盖率 100%。
2. **源代码、资源与配置文件中未检测到其他第三方许可证文本**，也未检测到任何第三方版权声明或 SPDX 许可证头。
3. **未发现从外部项目直接复制的代码片段**（基于 ScanCode 的许可证文本指纹匹配结果）。
4. 项目声明的两个开发依赖 `@ohos/hypium` 与 `@ohos/hamock` 均为 **Apache-2.0**，且仅用于单元测试，不随应用发布包分发。
5. 结论：**当前仓库代码可视为自有代码，整体以 Apache-2.0 授权；没有发现需要额外遵守的其他开源许可证。**

---

## 2. 许可证检测明细

### 2.1 检测到许可证的文件

| 文件 | 许可证（SPDX） | 匹配方式 | 匹配分数 | 覆盖文本比例 | 匹配行范围 |
| --- | --- | --- | --- | --- | --- |
| `LICENSE` | Apache-2.0 | 1-hash（整文件哈希） | 100 | 100% | 第 1–201 行（1584 个 token） |

`LICENSE` 为 Apache License 2.0 的完整标准文本，与 ScanCode 许可证库中的 `apache-2.0.LICENSE` 规则完全一致。

### 2.2 未检测到许可证的文件

其余 **63 个文件**（含 29 个 ArkTS 源码文件）均无许可证发现，包括：

- `entry/src/main/ets/`：`entryability`、`entrybackupability`、`common`、`components`、`database`、`model`、`pages`、`service` 等业务源码；
- `entry/src/test/`、`entry/src/ohosTest/` 测试代码；
- `AppScope/`、`entry/src/main/resources/` 应用资源；
- 根目录与模块级 `*.json5`、`hvigorfile.ts`、`app_icon.png`、`app_icon.svg` 等。

### 2.3 版权声明

ScanCode 的 `--copyright` 扫描在业务源码、资源和配置中均**未发现版权声明**。`LICENSE` 中的 "Copyright" 字样属于 Apache-2.0 标准条文及附录模板，不计为项目版权声明。

### 2.4 包识别

仓库中的 `oh-package.json5` / `oh-package-lock.json5` 为 HarmonyOS ohpm 格式，ScanCode 的通用包识别器未将其识别为第三方包清单，因此本报告的依赖分析采用人工核对 `oh-package.json5`、`oh-package-lock.json5` 及本地 `oh_modules` 中许可证文件的方式完成。

---

## 3. 依赖与运行时的许可证

| 组件 | 版本 | 用途 | 许可证 | 是否进入发布包 |
| --- | --- | --- | --- | --- |
| `@ohos/hypium` | 1.0.25 | 单元测试框架（devDependency） | Apache-2.0 | 否（仅测试） |
| `@ohos/hamock` | 1.0.0 | Mock 测试框架（devDependency） | Apache-2.0 | 否（仅测试） |
| HarmonyOS SDK / ArkUI / DevEco Studio | 6.1.1(24) / 26.0.0 | 编译与运行时平台 | 华为闭源 SDK 许可（非开源许可证） | 否（系统运行时） |

核对依据：

- `oh-package.json5` 的 `devDependencies` 中仅声明上述两个测试依赖；
- 两个依赖包内的 `LICENSE` 均为 Apache License 2.0 全文；
- `@ohos/hypium` 的 `oh-package.json5` 标注 `"license": "Apache-2.0"`，仓库来源为 `https://gitee.com/openharmony/testfwk_arkxtest`；
- `@ohos/hamock` 的 `oh-package.json5` 标注 `license: 'Apache-2.0'`；
- `oh_modules/` 已被 `.gitignore` 排除，仓库中不包含依赖源码，因此不构成对这两个依赖的源码再分发。

---

## 4. Apache-2.0 义务与合规建议

项目整体以 Apache-2.0 发布，分发（包括上传应用市场、提供源码或二进制）时需注意：

1. **随附许可证**：分发时保留根目录 `LICENSE`，并在文档/关于页面中注明使用 Apache-2.0。
2. **保留声明**：如分发修改后的源码，需保留原有的版权、专利、商标和归属声明，并在修改过的文件中显著说明修改内容。
3. **NOTICE 文件**：若未来引入带 `NOTICE` 文件的第三方 Apache-2.0 组件，需一并保留其 NOTICE 内容；当前项目没有 NOTICE 文件。
4. **商标限制**：Apache-2.0 不授予使用 "Apache" 等商标的权利，不得暗示官方背书。
5. **免责声明**：Apache-2.0 按 "AS IS" 提供，建议在应用内保留相应免责说明。

### 建议改进项（不影响当前扫描结论）

- `LICENSE` 末尾的版权模板仍为占位符 `Copyright [yyyy] [name of copyright owner]`，建议补充实际版权所有者与年份，便于维权与合规审查。
- 根目录 `oh-package.json5` 未声明 `license`，`entry/oh-package.json5` 的 `license` 字段为空，建议统一填写 `"Apache-2.0"`。
- 可在核心源码文件头部添加 SPDX 标识（如 `SPDX-License-Identifier: Apache-2.0`），便于自动化工具识别。
- 保持签名私钥、证书、`local.properties`、构建产物不进入仓库（当前仓库已排除这些文件）。
- 建议在 CI 中定期执行本扫描命令，新增依赖或许可证文件时自动预警。

---

## 5. 方法与局限

- ScanCode 通过许可证文本指纹匹配识别许可证；它能可靠识别标准许可证全文、版权头和 SPDX 标识，但**不能证明代码绝对没有第三方来源**。
- 若第三方代码被改写注释、重命名标识符、拆分重组或仅复用少量逻辑，文本匹配可能无法识别；本报告**不包含代码相似度或语义级抄袭检测**。
- 图片、图标等二进制资源仅做了文件类型识别，未做视觉溯源；`app_icon.png` / `app_icon.svg` 为本项目自有资源。
- 本报告基于指定提交的静态扫描结果，不构成法律意见；正式商用发布前建议由法务复核。

---

## 6. 附录：复现命令

```powershell
# 1. 克隆仓库
git clone --depth 1 https://github.com/Menquan754/eaxm-blind-spot-tracker.git repo

# 2. 执行许可证 / 版权 / 包信息扫描
scancode --license --copyright --package --info --classify \
  --strip-root --json-pp scan-result.json repo --quiet

# 3. 查看检测到许可证的文件
#    scan-result.json -> files[].detected_license_expression
```

扫描原始结果（JSON）仅用于本次分析，未纳入仓库，避免引入与项目无关的大文件。
