# 取证记录：ZCode 静默工作区快照上传（已脱敏）

> 基于本机 **ZCode 3.11.2**（Windows x64，构建 2026-09-04）的静态分析与本地残留物取证。
> 本文档是 `rules/zcode.json` 中 `maturity: verified` 的依据。

## 数据目录布局

```
%USERPROFILE%\.zcode\v2\
├── checkpoints\<workspace-hash>\
│   ├── manifests\<hash>.json         # 文件清单（含完整 .git 路径）
│   ├── extra-manifests\<hash>.json
│   ├── pending\<group>.tar.gz.enc    # ★ 加密快照包（待上传）
│   ├── pending\<group>.envelope.json # ★ 加密信封
│   └── state.json                    # 上传任务状态（凭证/失败计数）
├── logs\                             # 应用日志（对快照行为零记录）
├── telemetry-state.json              # deviceMid + 日活
└── certs\zcode-network-ca.key        # ⚠ 本地 CA 私钥明文存放
```

## 信封结构（repo_snapshot_encrypted_artifact/v2）

- 内容：`aes-256-ctr`，nonce 为密文前 16 字节（随机）
- 密钥包装：`rsa-oaep-sha256`，`keyId:"1"`（服务端静态密钥对），encryptedDataKey 为 256 字节 = RSA-2048
- AAD 绑定 workspaceKeyHash + manifestHash

**本地解密不可行**：客户端仅有公钥处理逻辑，无私钥、无明文数据密钥缓存。但 OSS 上传回调 `callbackBody` 携带 `encrypted_aes_key`（客户端代码 `encodeOssCallback` 可见）→ **上传成功瞬间服务端即获解密能力**。

## 上传状态（state.json）关键证据

```
activeUpload/pendingUpload:
  uploadCredentialHandle : <服务端下发凭证>
  kind: baseline          # 服务端 update_type = "full"
  captureStage: "terminal"    # ★ 会话结束触发
  failureCount: 7             # 上传失败，残留 pending 等待重试
```

实测时间线：`repoSnapshotIndexingEnabled=false` 已生效后，仍生成全量 baseline（212MB，含完整 `.git`：objects/pack/reflog/config/refs）并尝试上传。

## 客户端代码证据（app.asar）

- `encodeOssCallback` / `ossAttributionValues` / `toServerUpdateType(baseline→full)`
- 凭证：`max_size` / `snapshot_id` / `oss.path`
- 遍历器忽略集：`node_modules`、`.cache`、`.turbo`、顶层构建目录、疑似密钥文件（`.env`/`id_rsa`/`*.pem`）——但实际照打完整 `.git`，规则与行为不符
- 遥测：OTLP → `*.log.aliyuncs.com`（service `zcode-cli-agent`）、RUM → `sdk.rum.aliyuncs.com`

## 媒体与官方回应

- 官方（9/18）：归因「代码库索引/Repo Wiki」，称已修复、将开源、引入第三方审计（[全文](https://forum.trae.cn/t/topic/181727)）
- 本地行为（会话结束触发、开关无效）与「Repo Wiki 触发」的归因不完全吻合；最新包 3.12.3 构建于 9/16（早于声明）；开源与审计尚未落地
- 报道：[BlockBeats](https://en.theblockbeats.news/flash/367816)、[IT之家](https://www.ithome.com/1/004/310.htm)、[腾讯新闻](https://news.qq.com/rain/a/20260918A09XAY00)
