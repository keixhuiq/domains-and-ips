# Shadowrocket rules

本目录以本机生产环境的 sing-box 规则快照 `20261008-live/post-deploy-v11` 为准，文件名和分类与本机规则集一一对应：

- `ABEMA-domain.json` → `ABEMA-domain.list`
- `LINE-domain.json` → `LINE-domain.list`
- `LINE-ip.json` → `LINE-ip.list`
- `BookWalker-domain.json` → `BookWalker-domain.list`

每个 `.list` 都是带规则类型的 Shadowrocket `RULE-SET`。域名、IP、端口不会跨本机规则集重新合并；同一服务的多份文件在配置中指向同一策略组。

## 转换约定

- 52 个本机 JSON 中，只有 `direct-process.json` 不生成文件，因为 Shadowrocket 不支持 `PROCESS-NAME`。
- 其余 51 个 JSON 各生成一个同名 `.list`，包括内容为空的 `block-ip.list` 与 `Meta-ip.list`。
- IPv4 和 IPv6 均使用 Shadowrocket 的 `IP-CIDR` 规则名并带 `no-resolve`。
- `block-port.json` 的 UDP 与端口复合条件转换为等价的 `AND,((PROTOCOL,UDP),(DST-PORT,...))`。
- 本机域名正则会转换为后缀或通配符；详情记录在 `conversion-report.json`。
- 原 iOS 配置使用的上游专属 `USER-AGENT` 放入对应 `*-domain.list`，`IP-ASN` 放入对应 `*-ip.list`。
- iOS 专属补充来自 [blackmatrix7/ios_rule_script 固定提交](https://github.com/blackmatrix7/ios_rule_script/commit/036c097eb26c6a52c4f04ebcb6633043cb942669)，该上游采用 GPL-2.0 许可证。

## 策略组

配置生成脚本使用本机策略组名称，包括 `ABEMA`、`BookWalker`、`Amazon`、`NVIDIA`、`Direct` 与 `Block`。同一服务的 domain/IP 规则集指向同一策略组。小火箭原配置特有的 `✈️Final` 组仍作为最终兜底保留。

## 维护

```powershell
pwsh -File .\tools\build_shadowrocket.ps1 `
  -SourceRoot <rules-snapshot-directory> `
  -ShadowrocketUpstreamRoot <pinned-ios_rule_script-rule-Shadowrocket-directory>

pwsh -File .\tools\update_shadowrocket_config.ps1 `
  -InputPath <source.conf> `
  -OutputPath <updated.conf>

pwsh -File .\tools\validate_shadowrocket.ps1 -ConfigPath <updated.conf>
```

生成脚本不会把节点、订阅或其他敏感配置写入仓库。实际 iOS 导入、远程更新和规则命中仍需在 Shadowrocket 客户端验证。
