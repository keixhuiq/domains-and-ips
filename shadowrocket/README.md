# Shadowrocket rules

这些规则以本机生产环境的 sing-box 规则快照 `20261008-live/post-deploy-v11` 为主体，并保留原 iOS 配置所用 Blackmatrix 规则在提交 `036c097eb26c6a52c4f04ebcb6633043cb942669` 中的 iOS 专属 `USER-AGENT` 与 `IP-ASN` 条目，供 Shadowrocket 的 `RULE-SET` 与 `DOMAIN-SET` 使用。

## 约定

- `*.list` 是带类型的 `RULE-SET` 文件。
- `*_Domain.list` 是纯域名 `DOMAIN-SET` 文件。为避免超大规则集重复解析，Apple、China、CustomProxy 的域名和后缀放在此类文件中，其余类型仍在同名 `*.list` 中。
- IPv4 和 IPv6 均使用 Shadowrocket 的 `IP-CIDR` 规则名，并带 `no-resolve`。
- 所有 `PROCESS-NAME` 规则均不进入此目录。
- iOS 专属补充只导入原配置实际使用的上游规则中的 `USER-AGENT` 与 `IP-ASN`，不会用上游域名/IP 覆盖本机生产规则。
- 本次保留 112 条 `USER-AGENT` 与 7 条 `IP-ASN` iOS 专属规则；来源为 [blackmatrix7/ios_rule_script 固定提交](https://github.com/blackmatrix7/ios_rule_script/commit/036c097eb26c6a52c4f04ebcb6633043cb942669)，该上游采用 GPL-2.0 许可证。
- 不能无损转换的复合条件以及正则转换详情见 `conversion-report.json`。
- `manifest.json` 记录每个生成文件的规则数和 SHA-256，便于维护时复核。

## 维护

在已获取当前生产规则快照后运行：

```powershell
pwsh -File .\tools\build-shadowrocket.ps1 `
  -SourceRoot <rules-snapshot-directory> `
  -ShadowrocketUpstreamRoot <pinned-ios_rule_script-rule-Shadowrocket-directory>
pwsh -File .\tools\validate-shadowrocket.ps1
```

生成后应先检查 `conversion-report.json`、运行仓库校验，再提交。实际 iOS 导入和运行效果仍需在 Shadowrocket 客户端验证。

如需从现有配置生成只替换 `[Rule]` 远程引用的副本，可运行：

```powershell
pwsh -File .\tools\update-shadowrocket_config.ps1 -InputPath <source.conf> -OutputPath <updated.conf>
pwsh -File .\tools\validate-shadowrocket.ps1 -ConfigPath <updated.conf>
```

更新脚本不会覆盖输入文件，也不会把节点、订阅或其他敏感配置写入仓库。
