## Domains & IP Addresses

自用的域名与 IP 规则集。以电脑上 sing-box 正在使用的规则集为准，手动更新，没有自动拉取上游。

```
sing-box/   电脑 D:\proxy\data\rule-sets 里的原文件（source 格式，版本 3）
surge/      由 sing-box/ 转换的 Surge RULE-SET，供 iOS 使用
manifest.json  每个规则集的源文件 SHA-256 和 Surge 规则数
tools/build_surge.py
```

不发布的规则集：

- 只有进程规则的 `*-process`（iOS 不支持进程匹配），以及内容为空的 `block-ip`、`block-process`、`Meta-ip`；
- `reject-ip`：电脑上拒绝 198.18.0.0/15 假 IP 段，Surge 自己用这一段做假 IP；
- `direct-domain`、`direct-ip`：自己的节点域名和网络地址，直接写在 Surge 配置里。

## 转换

- `domain` → `DOMAIN`，`domain_suffix` → `DOMAIN-SUFFIX`，`domain_keyword` → `DOMAIN-KEYWORD`；
- `ip_cidr` → `IP-CIDR` / `IP-CIDR6`，都带 `no-resolve`；
- `network` + `port` → `AND,((PROTOCOL,UDP),(DEST-PORT,…))`，逻辑规则 → `AND` / `OR` / `NOT`；
- Surge 没有正则规则。`^.+\.example\.com$` 换成等价的 `DOMAIN-WILDCARD,*.example.com`，其余正则在脚本的 `REGEX` 表里逐条写明，
  遇到表里没有的正则会直接报错；
- `Private-ip` 去掉 198.18.0.0/15（Surge 假 IP 段）。

## 更新

电脑上改了规则集后：

```shell
python tools/build_surge.py --source D:\proxy\data\rule-sets
```

脚本会覆盖 `sing-box/`、`surge/` 和 `manifest.json`。电脑上删掉的规则集需要手动从这两个目录删除。
