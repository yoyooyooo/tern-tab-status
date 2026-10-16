<h1 align="center">Tern Tab Status</h1>

> 在 Tern 标签栏里，直接看到哪些 OMP、pi 会话正在运行、等待输入，或需要查看。

<p align="center">
  <a href="./README.md">English</a> · <a href="./README.zh-CN.md">简体中文</a>
</p>
<p align="center">
  <a href="#安装">安装</a> · <a href="#试用">试用</a> ·
  <a href="#使用-new-pi-tab">New Pi Tab</a> · <a href="#读懂圆点">圆点含义</a> · <a href="#限制">限制</a>
</p>

<p align="center">
  <img src="./docs/images/tab-status-sidebar.png" width="360" alt="Tern 垂直侧栏中显示蓝、绿、黄、红状态圆点，以及没有圆点的空闲标签。">
  <br>
  <sub>Tern 0.8.3 垂直标签栏中的历史会话状态演示。</sub>
</p>

OMP、pi 会话分散在不同 Tab 或分屏里时，来回切换会打断正在关注的工作。Tern Tab Status 把每个 Tab 中支持的 pane 状态汇总到横向标签栏和垂直侧栏右侧的状态圆点上。Agent 图标并排保留，标题仍由你控制，两者都不需要安装状态 hook 或扩展。手动选择的原生 Tab 颜色独立保留，在没有更高优先级状态时显示。

部分原生检查覆盖 **macOS arm64 上的 Tern 0.8.3–0.8.4、OMP 18.11.0–18.11.1 和 pi 1.1.0**。最终复制安装的 CSS 运行时验收通过 14 项中的 13 项，覆盖运行、完成、失败、已读、Pi 确认等待、混合分屏优先级、横竖标签栏，以及 Pause/Resume/重载期间的手动颜色保留。正式日常插件重载后也观察到 Gmail 蓝点。唯一失败项是 OMP 独立确认框仍报告原生 idle，该路径不支持。宿主定时预算机制、日常大 ID 的完整生命周期和旧版大 ID 原色记录恢复仍有限制。版本与证据见[就绪记录](./docs/readiness.md#current-css-cutover-evidence)。其他平台尚未验证。

## 读懂圆点

| 圆&#8288;点 | 含义 |
| --- | --- |
| 蓝&#8288;色 | OMP 或 pi pane 正在运行 |
| 绿&#8288;色 | 存在尚未查看的原生结果提醒，通常来自运行完成 |
| 黄&#8288;色 | OMP 或 pi pane 报告 `waiting_input` |
| 红&#8288;色 | 失败、错误或非零退出的结果仍待查看 |
| 原&#8288;色 | 没有支持的 Agent 活动或提醒；原先没颜色则不显示圆点 |

同一个 Tab 汇总其中的 OMP、pi pane，优先级为 **红 → 黄 → 绿 → 蓝 → 原色**。绿色表示有提醒待查看，不代表任务已通过验收。

## 安装

需要带插件 CLI 的 Tern，以及能在其 shell PATH 中找到的 OMP 或 pi。通过 URL 安装还需要 Git。插件本身没有运行依赖，也不需要构建；只有插件的开发检查需要 Node.js。Agent 有各自的运行要求，pi 的安装与配置见[使用 New Pi Tab](#使用-new-pi-tab)。如果 macOS 的 PATH 中没有 `tern`，用 `/Applications/Tern.app/Contents/MacOS/tern` 替换。

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
3. 回到该 pane，或从 Tern 的 **Needs attention** 跳转过去。查看结果后，空闲 Tab 恢复原色。

有多个分屏时，聚焦一个 pane 不会将其他 pane 的提醒标为已读。黄色会保留到 agent 离开原生 `waiting` 状态；聚焦时运行仍显示蓝色。多个圆点在同一位置重叠，显示最高优先级状态。

结果到达时仍聚焦在该 pane，视为已经查看，完成或失败后立即露出原生手动颜色。之后切走或重载插件，也不会重新出现这次结果的圆点。插件持久保存逐 pane 已读标记，不清除 Tern 原生提醒；后续在离开时到达的新结果仍会显示绿点或红点。已读标记只抑制原生 `done`、`bell`、`failed`，不抑制 `working`、`waiting`。

## 操作

命令面板提供：

- **New OMP Tab**（Agents 分组）：在当前目录新开一个 OMP Agent Block Tab。
- **New Pi Tab**（Agents 分组）：在当前目录新开一个 pi Agent Block Tab。
- **Tern Tab Status: Pause and Restore Tab Colors**：隐藏状态样式，露出原生手动颜色，并重试旧版原色记录的恢复。
- **Tern Tab Status: Resume**：重新启用状态样式。

两个启动命令分别运行 `omp`、`pi`，不自动发送初始消息，并保留配置中的默认 Agent 命令和放置方式，普通 **New agent block** 仍沿用这两个偏好。Tern 0.8.3 需要在同步创建时短暂选定程序及 `new_tab` 放置方式，插件会立即恢复两个设置，创建失败时也会恢复。暂停状态颜色不影响启动命令。

两个命令可在命令面板搜索，也可在 Tern 的 Keyboard 设置中绑定快捷键。动作 ID 分别为 `plugin.tern-tab-status.new_omp_tab`、`plugin.tern-tab-status.new_pi_tab`。

host 模块在 shell 生命周期事件及 750 ms 补漏轮询中检查 pane 名单，变化时发布完整原生 pane ID 字符串。window 模块用精确 ID 识别支持的 pane，并生成指向原生 `.tn-dk-c[data-pane][data-st]` 元素的 CSS。原生状态变化直接驱动圆点，生产运行不再轮询 `agents:list()`，也不把状态写入 `tab.color`。直接运行的 `omp`、`pi` 按可执行文件 basename 识别；shell 承载的 OMP 用有界 `omp.session` 描述查询识别（一个节点、深度一、128 字符）。窗口启动、pane/Tab、命令、目录和标题事件直接同步识别及共享暂停，焦点与完成事件更新持久已读标记；定时器补漏，不再负责派发这些事件的更新。暂停刷新跳过识别。运行、Pause、Resume、重载期间，手动颜色始终保持为真实原生 Tab 颜色。

### 使用 New Pi Tab

pi 需要单独安装，详见其[官方安装说明](https://github.com/earendil-works/pi#getting-started)。通过 npm 安装时，pi 需要 Node.js **22.19 或更高版本**：

```sh
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

在 Tern 内的终端 pane 中确认其 shell 能找到可执行文件：

```sh
command -v pi
pi --version
```

在 Tern 命令面板搜索 `new`，选择 **Agents → New Pi Tab**，会使用 Tern shell PATH 中的 `pi` 命令，在当前目录打开空白 pi Agent Block。插件不负责安装 pi 或配置模型服务的访问凭据。首次使用内置服务商时，在 pi 中执行 `/login`，再用 `/model` 选择模型。启动沿用已有 pi 配置，并保留默认 Agent 命令和放置方式。

原生状态已验证 **pi 1.1.0**，通过 OSC 7501 报告，不需要额外的状态扩展。已验证的状态路径是本命令或 pi Agent Block；在普通终端 pane 中直接输入 `pi` 的状态表现尚未验证。等待输入与版本边界见[限制](#限制)。

若找不到 **New Pi Tab**，先[更新插件](#升级与卸载)，用 `tern plugin list --json` 确认 `tern-tab-status` 为 `ready`；链接安装还需在更新源码后重载。若能开 Tab 但 pi 无法启动，先解决上述 PATH 与版本检查。若 pi 已运行但状态圆点被隐藏，检查是否已暂停，并执行 **Tern Tab Status: Resume**。

### 升级与卸载

链接安装更新源码后执行 `tern plugin reload`。复制安装重新执行原来的 `tern plugin install` 命令并加上 `--force`：GitHub 安装可用 `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git --force`，本地复制安装在更新后的源码目录执行 `tern plugin install "$PWD" --force`。更新需要手动执行，`--force` 只替换复制安装；从链接安装改为复制安装时，先暂停，再取消链接，然后安装。

禁用、取消链接或卸载前，先执行 **Pause and Restore Tab Colors**，隐藏状态样式并重试旧版记录恢复。再按安装方式执行：

```sh
tern plugin unlink tern-tab-status
# 复制安装则改用：
tern plugin remove tern-tab-status
```

暂停状态会持久保存。重新安装后若没有状态圆点，请执行 **Resume**。启用状态、pane ID 和已读标记保存在 Tern 配置目录下的 `plugin-data/tern-tab-status/kv.json`；取消链接不会擦除这些状态。旧版还保存了原色/已应用颜色记录。升级仅在当前原生颜色仍等于旧 applied 色时写回原色，且实际观察到恢复成功后才清除记录。当前颜色已不同时，保留它并丢弃过时记录。大 ID 的 SDK 颜色调用失败可能让匹配的旧记录继续保留；这不阻止新状态点显示。

## 限制

- 一个圆点只能显示最高优先级状态，细节需要查看 **Needs attention** 和具体 pane。
- 绿点、红点跟随原生 `done`/`bell`/`failed` 状态，并结合逐 pane 已读标记；当前 pane 的结果在切走或重载后仍保持已读。插件不统计消息未读数，也不清除原生提醒。
- 绿色对应一般尚未查看的原生提醒，不是单独记录的成功结果；已经查看的完成结果可能不会显示绿色。
- OMP、pi 按可执行文件 basename 识别；shell 承载的 OMP 另有有界 `omp.session` 回退。pi 原生状态请使用 **New Pi Tab** 或 pi Agent Block。普通 shell 中的 pi 及自定义包装程序名没有已验证的状态契约。pi 1.1.0 通过 OSC 7501 报告状态，旧版尚未验证。
- 完整原生 pane 字符串让状态显示绕过 SDK 低 44 位颜色寻址路径。既有 daemon 上的受控窗口已用超过 `2^44` 的原生 ID 通过 12 项真实 OMP/pi 生命周期观察：运行、未读完成与失败、查看、重载保持已读，以及 Pi 等待与取消。部分日常 pane 也已精确识别并显示蓝点；这些样本不代表所有环境均兼容。SDK 限制仍影响旧版原色记录的升级恢复。详见[证据与限制](./docs/readiness.md#current-css-cutover-evidence)。
- CSS 依赖 Tern 原生标签 DOM 和 `data-st` 状态词汇，已验证部分 Tern 0.8.4 场景；未来 DOM 变化可能需要更新。当前精确 pane CSS 不同于已否决的历史 title-marker 实验，在已观察范围内覆盖横向与垂直布局。
- Tern 的定时回调超过 50 ms 墙钟预算后可能停用该插件 VM 的定时器，原生等待或被暂停调度也可能消耗预算。日常已捕获故障发生在现已移除的同步 `cx.agents:list()` 路径。原生 CSS 状态变化不再依赖该轮询，生命周期事件也已直接同步，不再等待定时回调。停用仍可能延迟没有生命周期事件送达的变化，例如安静窗口中的跨窗口暂停。宿主机制并未修复。详见[已知原生阻塞项](./docs/readiness.md#known-native-blockers)。
- OMP 18.11.0–18.11.1 的独立扩展命令使用 `ctx.ui.confirm` 时，可能显示真实阻塞对话框，但 Tern 仍报告 `idle`；Tern 0.8.4 上仍观察到此限制。该路径没有黄点，仍不支持。Pi 的阻塞确认框报告 `waiting_input` 并显示黄色，聚焦时也保留；取消后露出原生手动颜色。普通模型、会话选择器并非都会报告等待。黄色跟随原生 `waiting` 渲染。
- 观察器可能错过极短的原生状态。暂停通过插件存储跨窗口共享，其他窗口下次刷新时应用。没有窗口时，窗口插件不执行同步。

## 隐私

插件读取原生 pane ID、pane 元数据、用于识别 shell 承载 OMP 的有界 surface 描述、旧版原色记录，以及默认 Agent 命令和放置方式。它安装本地 CSS，并写入自己的本地键值状态。状态显示不写 Tab 颜色；仅升级恢复可能调用原生颜色 API。执行启动命令时，会让 Tern 启动 `omp` 或 `pi`，临时选定、随后恢复两个偏好。不发网络请求、不安装 Agent 扩展、不保存对话文本。报告渠道与信任边界见 [SECURITY.md](./SECURITY.md)。

## 开发

检查需要 Node.js 22 或更高版本和 npm：

```sh
npm ci --ignore-scripts
npm run check
```

检查用固定版本的开发用 Luau 运行时编译并执行实际 host/window 模块，覆盖识别、CSS 优先级、已读状态、旧记录恢复和启动行为，同时验证文档相对链接与插件 manifest。它不能代替真实 Tern 验收。

在源码目录执行原生验证：

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --case launch
node scripts/verify-native.mjs
```

doctor 仅检查前置条件，不打开 Tern；launch 场景执行两个命令面板启动器；完整验证使用隔离的原生窗口、daemon 及离线模型 provider，运行真实 OMP、pi 进程。状态断言从截图像素读取 `statusColor`，原生 `tab.color` 独立验证手动颜色。PNG 解码使用 Node 内置 zlib，不增加依赖。确认框 fixture 明示为自动验收、无需用户操作；runner 给原生等待五秒观察期，不支持的路径仍算失败，并发送 Escape 关闭弹框。每次运行都在输出目录保留 `summary.json`、快照、截图及进程清理证据。[验证技能](./.cursor/skills/verify-tern-tab-status/SKILL.md)和[功能地图](./.cursor/skills/verify-tern-tab-status/features/README.md)记录前置条件、操作路径、预期结果与证据要求。

架构与手工验收步骤见 [CONTRIBUTING.md](./CONTRIBUTING.md)，变更见 [CHANGELOG.md](./CHANGELOG.md)，验证范围见[开源就绪记录](./docs/readiness.md)。npm manifest 仅供开发，插件通过 Tern 安装。

问题反馈与贡献讨论请使用 [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues)，安全漏洞请通过 [GitHub Security Advisories](https://github.com/yoyooyooo/tern-tab-status/security/advisories/new) 私密报告。

## 许可证

[MIT](./LICENSE)。本项目为独立插件，并非 Tern、OMP 或 pi 官方项目。
