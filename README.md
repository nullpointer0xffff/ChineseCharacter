# 中文写字 iPhone App

一个 SwiftUI 原型，帮助小朋友通过中文语音选择想学习书写的汉字。

## 功能

- App 录音后调用 Vercel 后端，OpenAI API key 不再保存在客户端。
- 后端调用 OpenAI `gpt-transcribe` 做中文语音转文字，优先提高当前文件转写接口的准确率。
- 后端调用 OpenAI `gpt-5-mini` 从自然语言里提取孩子真正想写的中文。
- 展示提取出的句子，点击单个汉字后显示拼音、读音按钮和笔顺区域。
- 本地 `CharacterData.json` 保存汉字、拼音、读音提示；笔顺动画使用 Hanzi Writer 和本地 `hanzi-writer-data` 字库。
- Vercel 后端支持每台设备默认 10 次免费使用、coupon 增加次数、基础管理后台。

## 运行

1. 安装 XcodeGen 后执行：

   ```sh
   xcodegen generate
   ```

2. 打开 `ChineseCharacter.xcodeproj`。
3. 部署 `backend/`，iOS app 已默认使用 `https://chinese-character-sigma.vercel.app`。
4. 选择 iPhone Simulator 或真机运行。

## Vercel 后端

后端在 `backend/`，使用 Next.js Route Handlers，可以直接部署到 Vercel。

需要配置的环境变量：

```sh
OPENAI_API_KEY=sk-your-key
POSTGRES_URL=postgres://user:password@host:5432/database
ADMIN_TOKEN=change-this-long-random-token
OPENAI_TEXT_MODEL=gpt-5-mini
```

数据库使用 Postgres。上线前先在数据库里执行：

```sh
backend/db/schema.sql
```

主要接口：

- `GET /api/me`：返回当前设备剩余次数，需要 `X-Device-Id`。
- `POST /api/voice/extract`：上传 `audio` 文件，转录并提取要学习的中文，成功后扣 1 次。
- `POST /api/coupons/redeem`：兑换 coupon，body 为 `{ "code": "YOURCODE" }`。

管理后台首页是 `/`，如果配置了 `ADMIN_TOKEN`，浏览器会要求 Basic Auth。用户名为 `admin`，密码为 `ADMIN_TOKEN`。

## 数据来源建议

当前仓库已内置 Hanzi Writer 的开源笔顺动画和 `hanzi-writer-data` 字库。后续还可以补充：

- CC-CEDICT 或自维护词表：拼音和释义补充。

OpenAI API key 只应放在 Vercel 环境变量里，不要放进 iOS App。
