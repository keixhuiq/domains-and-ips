# proxy-rules-clean

Cleaned proxy rule sets for Surge, Mihomo, and Quantumult X.

Current rule layout:

```text
Surge/
  ChinaDirect.list
  Apple.list
  Google.list
  ChinaIPv4.list
  ChinaIPv6.list
  Abema.list
  UNEXT.list
  X.list
  TikTok.list
  OpenAI.list
  Claude.list
```

The original `whxhuiq-creator/proxy-rules` repository is kept untouched.

## Surge Sources

Single-source rules:

- `Surge/ChinaDirect.list`: `blackmatrix7/ios_rule_script` ChinaMax_All
- `Surge/Apple.list`: `blackmatrix7/ios_rule_script` Apple_All
- `Surge/Google.list`: `blackmatrix7/ios_rule_script` Google
- `Surge/ChinaIPv4.list`: `blackmatrix7/ios_rule_script` ChinaIPsBGP
- `Surge/ChinaIPv6.list`: `ACL4SSR/ACL4SSR` ChinaIpV6

Merged rules:

- `Surge/Abema.list`: old manual rules, `blackmatrix7/ios_rule_script` Abema/AbemaTV, `QuixoticHeart/rule-set` abema
- `Surge/UNEXT.list`: old manual rules, `HotKids/Rules` U-NEXT
- `Surge/X.list`: old manual rules, `blackmatrix7/ios_rule_script` Twitter, `ACL4SSR/ACL4SSR` Twitter
- `Surge/TikTok.list`: old manual rules, `blackmatrix7/ios_rule_script` TikTok, `QuixoticHeart/rule-set` tiktok
- `Surge/OpenAI.list`: old manual rules, `blackmatrix7/ios_rule_script` OpenAI, `geekdada/surge-list` openai
- `Surge/Claude.list`: old manual rules, `blackmatrix7/ios_rule_script` Claude/Anthropic, `HotKids/Rules` Anthropic
