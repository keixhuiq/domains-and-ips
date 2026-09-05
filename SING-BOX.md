# sing-box 规则集

以下目录提供与各自 `DOMAIN.list` 对应的 sing-box 规则集：

Claude、OpenAI、TikTok、Crunchyroll、Abema、UNEXT、bookwalker.jp、bookwalker.tw、Amazon、Crypto、CustomProxy。

每个目录包含：

- `sing-box.json`：原生 source 格式，规则集版本 3，便于阅读及审查。
- `sing-box.srs`：编译后的 binary 格式，建议客户端引用；需要 sing-box 1.11 或更新版本。

例如：

```json
{
  "type": "remote",
  "tag": "claude-rules",
  "format": "binary",
  "url": "https://raw.githubusercontent.com/keixhuiq/domains-and-ips/main/Claude/sing-box.srs",
  "http_client": "rules-download",
  "update_interval": "1d"
}
```

`http_client` 需要引用完整配置中定义的 HTTP 客户端；上例适用于 sing-box 1.14。规则集本身不包含代理节点、密码、订阅链接或出站策略。

## 更新

修改原有 `DOMAIN.list` 后，在本仓库运行：

```shell
python tools/build-sing-box.py --sing-box /path/to/sing-box
```

将更新后的 JSON、SRS 和 `sing-box-manifest.json` 一并提交。目前为手动生成，没有设置自动拉取上游或自动提交。

转换保留 DOMAIN、DOMAIN-SUFFIX、DOMAIN-KEYWORD、IP-CIDR 和 IP-CIDR6 的匹配条件。各类型独立成规则，保持原列表的 OR 语义。IP 网段规范化但不扩大范围；未知规则类型会报错。

JSON 输出统一使用 UTF-8、LF 换行。清单中的文本 SHA-256 也按 UTF-8/LF（不含 BOM）计算，避免 Windows 的 CRLF 与 GitHub 的 LF 导致校验不一致；SRS 按原始二进制字节计算。

普通 iOS App Store 客户端不支持进程匹配，因此 Crypto 中 3 条 PROCESS-NAME 规则不进入此 iOS 规则集，仍保留在原始 DOMAIN.list 中。逐项说明、来源和输出 SHA-256 见 `sing-box-manifest.json`。

Mihomo 的 `no-resolve` 是路由解析行为，不能作为 SRS 匹配字段编码；使用者应在完整 sing-box 配置中安排 DNS 和路由解析。规则集不含路由动作，也不负责选择代理或直连。
