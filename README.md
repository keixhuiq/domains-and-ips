# proxy-rules-clean

Cleaned proxy rule sets for Surge, Mihomo, and Quantumult X.

Current Surge rule layout:

```text
Surge/
  Abema.list
  Apple.list
  Bahamut.list
  Bilibili.list
  ChinaDirect.list
  ChinaIPv4.list
  ChinaIPv6.list
  Claude.list
  Crypto.list
  CustomProxy.list
  DisneyPlus.list
  Epic.list
  Google.list
  HBO.list
  LINE.list
  Microsoft.list
  MyTVSuper.list
  Netflix.list
  OpenAI.list
  PlayStation.list
  Scholar.list
  Steam.list
  Telegram.list
  TikTok.list
  UNEXT.list
  X.list
  Xbox.list
  YouTube.list
```

The original `whxhuiq-creator/proxy-rules` repository is kept untouched.

## Surge Sources

Direct-source rules:

- `Surge/ChinaDirect.list`: `blackmatrix7/ios_rule_script` ChinaMax_All
- `Surge/Apple.list`: `blackmatrix7/ios_rule_script` Apple_All
- `Surge/Google.list`: `blackmatrix7/ios_rule_script` Google plus uncovered GoogleFCM IP rules
- `Surge/ChinaIPv4.list`: `blackmatrix7/ios_rule_script` ChinaIPsBGP
- `Surge/ChinaIPv6.list`: `ACL4SSR/ACL4SSR` ChinaIpV6

Merged rules use the old manual `whxhuiq-creator/proxy-rules` Surge files as the first source, then supplement from community rule sets including `blackmatrix7/ios_rule_script`, `QuixoticHeart/rule-set`, `ACL4SSR/ACL4SSR`, `HotKids/Rules`, and `geekdada/surge-list`.
