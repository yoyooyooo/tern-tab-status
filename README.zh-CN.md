<h1 align="center">Tern Tab Status</h1>

> 在 Tern 标签栏里，直接看到哪些 OMP、pi 会话正在运行、等待输入，或需要查看。

<p align="center">
  <a href="./README.md">English</a> · <a href="./README.zh-CN.md">简体中文</a>
</p>
<p align="center">
  <a href="#安装">安装</a> · <a href="#试用">试用</a> ·
  <a href="#读懂圆点">圆点含义</a> · <a href="#限制">限制</a>
</p>

<p align="center">
  <img src="./docs/images/tab-status-sidebar.png" width="360" alt="Tern 垂直侧栏中显示蓝、绿、黄、红状态圆点，以及没有圆点的空闲标签。">
  <br>
  <sub>Tern 0.8.3 垂直标签栏中的会话状态演示。</sub>
</p>

OMP、pi 会话分散在不同 Tab 或分屏里时，来回切换会打断正在关注的工作。Tern Tab Status 把每个 Tab 中支持的 Agent 状态汇总到原生颜色圆点上，保留原来的标题，两者都不需要安装状态 hook 或扩展。

原生检查覆盖 **macOS arm64 上的 Tern 0.8.3、OMP 18.11.0 和 pi 1.1.0** 的部分场景。较大的原生 Tab ID 和部分 OMP 确认对话框存在下文所列限制。其他宿主版本和平台尚未验证。具体结果与证据边界见[就绪记录](./docs/readiness.md)。

## 读懂圆点

| 圆&#8288;点 | 含义 |
| --- | --- |
| 蓝&#8288;色 | OMP 或 pi pane 正在运行 |
| 绿&#8288;色 | 存在原生未查看提醒，通常来自运行完成 |
| 黄&#8288;色 | OMP 或 pi pane 报告 `waiting_input` |
| 红&#8288;色 | 失败、错误或非零退出后，仍有原生未查看提醒 |
| 原&#8288;色 | 没有支持的 Agent 活动或提醒；原先没颜色则不显示圆点 |

同一个 Tab 汇总其中的 OMP、pi pane，优先级为 **红 → 黄 → 绿 → 蓝 → 原色**。绿色表示有提醒待查看，不代表任务已通过验收。

## 安装

需要带插件 CLI 的 Tern，以及能在其 shell PATH 中找到的 OMP 或 pi。通过 URL 安装还需要 Git。插件没有运行依赖，也不需要构建；只有开发检查需要 Node.js。如果 macOS 的 PATH 中没有 `tern`，用 `/Applications/Tern.app/Contents/MacOS/tern` 替换。

### 从 GitHub 安装

Tern 可以直接从 GitHub 克隆并安装本插件：

```sh
tern plugin install https://github.com/yoyooyooo/tern-tab-status.git
tern plugin list --json
```

确认 `tern-tab-status` 状态为 `ready`，且没有该插件的问题。URL 安装会把插件复制到 Tern 插件目录，不需要自己维护一份克隆。等价的 GitHub 简写是 `tern plugin install github.com/yoyooyooo/tern-tab-status`。

<details>
<summary>从本地源码安装</summary>

在解压或克隆后的仓库根目录执行：

```sh
tern plugin link "$PWD"
tern plugin list --json
```

插件列表应包含 `tern-tab-status`，状态为 `"ready"`，且没有该插件的问题。链接安装直接读取当前目录，请保留目录位置。

若希望复制安装、不依赖源码目录位置，执行：

```sh
tern plugin install "$PWD"
```

插件位于仓库子目录时，Tern 也接受 `github.com/OWNER/REPO/PATH`。

</details>

## 试用

1. 在命令面板搜索 `new`，选择 **Agents** 分组中的 **New OMP Tab** 或 **New Pi Tab**。发起请求后切到另一个 Tab，运行时原 Tab 显示蓝色。
2. 等待请求结束。如果 Tern 将该 pane 标为需要查看，Tab 会显示绿色。
3. 回到该 pane，或从 Tern 的 **Needs attention** 跳转过去。提醒清除后，空闲 Tab 恢复原色。

有多个分屏时，聚焦一个 pane 不会将其他 pane 的提醒标为已读。等待输入的黄色会保留到 agent 离开 `waiting_input` 状态。

Tern 也可能在当前 pane 保持聚焦时产生新的完成或确认结束提醒。若圆点仍在，切到其他 pane 后再回来，按原生规则确认这次提醒。

## 操作

命令面板提供：

- **New OMP Tab**（Agents 分组）：在当前目录新开一个 OMP Agent Block Tab。
- **New Pi Tab**（Agents 分组）：在当前目录新开一个 pi Agent Block Tab。
- **Tern Tab Status: Pause and Restore Tab Colors**：恢复保存的 Tab 原色，暂停状态颜色。
- **Tern Tab Status: Resume**：恢复状态颜色。

两个启动命令分别运行 `omp`、`pi`，不自动发送初始消息，并保留配置中的默认 Agent 命令和放置方式，普通 **New agent block** 仍沿用这两个偏好。Tern 0.8.3 需要在同步创建时短暂选定程序及 `new_tab` 放置方式，插件会立即恢复两个设置，创建失败时也会恢复。暂停状态颜色不影响启动命令。

两个命令可在命令面板搜索，也可在 Tern 的 Keyboard 设置中绑定快捷键。动作 ID 分别为 `plugin.tern-tab-status.new_omp_tab`、`plugin.tern-tab-status.new_pi_tab`。

窗口打开时，每 750 ms 从 `cx.agents:list()` 轮询直接元数据。快照提供 Agent 状态、Tab、焦点及原生提醒，无需为每个 Agent 单独查询 pane；有大小限制的 `omp.session` 描述查询保留为识别回退。焦点、标题、pane、Tab、命令和完成事件会请求提前刷新。仅在颜色变化时写入。活动期间观察到的手动颜色会成为下次恢复的原色。

### 升级与卸载

链接安装更新源码后执行 `tern plugin reload`。复制安装重新执行原来的 `tern plugin install` 命令并加上 `--force`：GitHub 安装可用 `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git --force`，本地复制安装在更新后的源码目录执行 `tern plugin install "$PWD" --force`。更新需要手动执行，`--force` 只替换复制安装；从链接安装改为复制安装时，先暂停，再取消链接，然后安装。

禁用、取消链接或卸载前，先执行 **Pause and Restore Tab Colors**，恢复临时状态色。再按安装方式执行：

```sh
tern plugin unlink tern-tab-status
# 复制安装则改用：
tern plugin remove tern-tab-status
```

暂停状态会持久保存。重新安装后若没有状态颜色，请执行 **Resume**。原色、启用状态和完成结果保存在 Tern 配置目录下的 `plugin-data/tern-tab-status/kv.json`；取消链接不会擦除这些状态。

## 限制

- 一个圆点只能显示最高优先级状态，细节需要查看 **Needs attention** 和具体 pane。
- 已读与未读跟随 Tern 原生 pane 提醒；插件不统计消息未读数，也不主动确认提醒。
- 绿色对应一般原生提醒，不是单独记录的成功结果。若完成提醒已经被 Tern 确认，可能不会显示绿色。
- OMP 通过可执行文件名或有大小限制的 `omp.session` 描述回退识别，pi 通过 Tern Agent 列表中的可执行文件名识别。请用 **New Pi Tab** 或 pi Agent Block；普通 shell 中输入 `pi` 不会进入该列表。pi 1.1.0 通过 OSC 7501 报告状态，旧版 pi 尚未验证；自定义包装程序名不会自动识别。
- Tern 0.8.3 在已有日常会话中可能静默忽略针对较大原生 Tab ID 的颜色调用，即使 SDK 接受调用也不变色。这些 Tab 可能不显示状态，Pause 也不能可靠恢复其原色。新 daemon 中小 ID 的验证通过，不能证明这些 Tab 可用。详见[已知原生阻塞项](./docs/readiness.md#known-native-blockers)。
- OMP 18.11.0 的独立扩展命令使用 `ctx.ui.confirm` 时，可能显示真实阻塞对话框，但 Tern 仍报告 `idle`。该路径不会显示黄色，不能算作输入等待验证通过。pi 主动取消后回到空闲；普通模型、会话选择器并非都会报告等待。黄色跟随实际原生 `waiting_input` 元数据。
- 短暂状态可能在两次刷新之间经过。手动颜色若与当前状态色相同，插件无法区分两者。
- 暂停状态通过插件存储跨窗口共享，其他窗口在下次刷新时恢复原色。没有窗口时，窗口插件不执行同步。

## 隐私

插件读取 Tern 的直接 Agent 元数据、有大小限制的 surface 描述回退、Tab 颜色及默认 Agent 命令和放置方式，写入 Tab 颜色及自己的本地键值状态。用户执行启动命令时，会让 Tern 启动 `omp` 或 `pi`，临时选定、随后恢复两个偏好。不发网络请求、不安装 Agent 扩展、不保存对话文本。报告渠道与信任边界见 [SECURITY.md](./SECURITY.md)。

## 开发

检查需要 Node.js 22 或更高版本和 npm：

```sh
npm ci --ignore-scripts
npm run check
```

检查用固定版本的开发用 Luau 运行时编译并执行实际模块，覆盖状态切换、原色恢复，同时验证文档相对链接与插件 manifest。它不能代替真实 Tern smoke 验证。

在源码目录执行原生验证：

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --case launch
node scripts/verify-native.mjs
```

doctor 仅检查前置条件，不打开 Tern；launch 场景执行两个命令面板启动器；完整验证使用隔离的原生窗口、daemon 及离线模型 provider，运行真实 OMP、pi 进程。每次运行都会在输出的目录保留 `summary.json`、快照、截图及进程清理证据。不支持的场景仍算失败，不计为通过。[验证技能](./.cursor/skills/verify-tern-tab-status/SKILL.md)和[功能地图](./.cursor/skills/verify-tern-tab-status/features/README.md)记录前置条件、操作路径、预期结果与证据要求。

架构与手工验收步骤见 [CONTRIBUTING.md](./CONTRIBUTING.md)，变更见 [CHANGELOG.md](./CHANGELOG.md)，验证范围见[开源就绪记录](./docs/readiness.md)。npm manifest 仅供开发，插件通过 Tern 安装。

问题反馈与贡献讨论请使用 [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues)，安全漏洞请通过 [GitHub Security Advisories](https://github.com/yoyooyooo/tern-tab-status/security/advisories/new) 私密报告。

## 许可证

[MIT](./LICENSE)。本项目为独立插件，并非 Tern、OMP 或 pi 官方项目。
