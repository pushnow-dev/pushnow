export const site = {
  name: "PushNow",
  displayName: "PushNow 即知",
  domain: "https://pushnow.dev",
  api: "https://api.pushnow.dev",
  supportEmail: "support@pushnow.dev",
  bundleId: "com.createitv.pushnow",
  appStoreURL: "",
  downloadURL: "https://pushnow.dev/#download",
  lastUpdated: "September 12, 2026"
};

export const languages = [
  { code: "en", locale: "en-US", label: "English", prefix: "" },
  { code: "zh-Hans", locale: "zh-Hans", label: "简体中文", prefix: "/zh-Hans" },
  { code: "ja", locale: "ja", label: "日本語", prefix: "/ja" },
  { code: "ko", locale: "ko", label: "한국어", prefix: "/ko" },
  { code: "es", locale: "es", label: "Español", prefix: "/es" },
  { code: "de", locale: "de", label: "Deutsch", prefix: "/de" }
];

export const pathFor = (lang: string, slug = "") => {
  const language = languages.find((item) => item.code === lang) ?? languages[0];
  const cleanSlug = slug.replace(/^\/+|\/+$/g, "");
  const pathname = `${language.prefix}${cleanSlug ? `/${cleanSlug}` : ""}`;
  // Workers Static Assets serves directory pages with a trailing slash.
  return pathname ? `${pathname}/` : "/";
};

const sharedFeatures = {
  en: [
    ["Inbox for agent results", "Collect reports, monitor alerts, and subscriptions in one user-bound notification space."],
    ["P0/P1 urgency", "Use normal, important, urgent, or custom levels for different kinds of work."],
    ["App push or in-app only", "Choose whether an item should notify the device or wait quietly inside the app."],
    ["Source keys", "Create scoped keys for agents, CLIs, and webhooks without sharing account credentials."]
  ],
  "zh-Hans": [
    ["Agent 结果收件箱", "把报告、监控、订阅和自动化结果收在同一个用户空间。"],
    ["P0/P1 紧急级别", "支持普通、重要、P0、P1 等自定义提醒级别。"],
    ["App 推送或仅 App 内查看", "每条事项都能选择通知设备，或静默保存到 App。"],
    ["来源密钥", "为 Agent、CLI、Webhook 创建受限密钥，不暴露账号登录凭证。"]
  ],
  ja: [
    ["Agent 結果の受信箱", "レポート、監視アラート、購読結果をユーザーに紐づく通知スペースへ集約します。"],
    ["P0/P1 の緊急度", "通常、重要、緊急、カスタムのレベルで作業ごとに扱いを分けられます。"],
    ["App プッシュまたはアプリ内のみ", "端末へ通知するか、アプリ内で静かに待たせるかを選べます。"],
    ["ソースキー", "Agent、CLI、Webhook に限定キーを発行し、アカウント資格情報を共有しません。"]
  ],
  ko: [
    ["Agent 결과 수신함", "보고서, 모니터링 알림, 구독 결과를 사용자 계정에 묶인 공간에 모읍니다."],
    ["P0/P1 긴급도", "일반, 중요, 긴급, 사용자 지정 단계로 업무별 우선순위를 나눕니다."],
    ["App 푸시 또는 앱 내 확인", "기기로 알릴지, 앱 안에 조용히 보관할지 항목마다 선택합니다."],
    ["소스 키", "Agent, CLI, Webhook 에 범위가 제한된 키를 발급해 계정 인증 정보를 보호합니다."]
  ],
  es: [
    ["Bandeja para resultados de agentes", "Reúne reportes, alertas y suscripciones en un espacio ligado al usuario."],
    ["Urgencia P0/P1", "Usa niveles normal, importante, urgente o personalizados para cada tipo de trabajo."],
    ["Push de App o solo dentro de la App", "Decide si un elemento avisa al dispositivo o espera en silencio dentro de la App."],
    ["Claves de origen", "Crea claves limitadas para agentes, CLI y webhooks sin compartir credenciales de cuenta."]
  ],
  de: [
    ["Eingang fur Agent-Ergebnisse", "Sammelt Berichte, Monitoring-Warnungen und Abos in einem nutzergebundenen Bereich."],
    ["P0/P1 Dringlichkeit", "Nutze normale, wichtige, dringende oder eigene Stufen fur unterschiedliche Arbeit."],
    ["App-Push oder nur in der App", "Wahle pro Eintrag, ob das Gerat benachrichtigt wird oder der Eintrag ruhig in der App bleibt."],
    ["Source Keys", "Erstelle begrenzte Schlussel fur Agents, CLIs und Webhooks, ohne Konto-Zugangsdaten zu teilen."]
  ]
};

const englishApi = {
  metaTitle: "Pushnow API Docs - Send agent results to your iOS inbox",
  metaDescription: "Create user-bound source keys, ingest agent results, sync inbox items, and bind iOS devices for Pushnow App push readiness.",
  navHome: "Home",
  eyebrow: "Developer API",
  title: "Send agent results into a user-bound iOS inbox.",
  intro: "Pushnow's API lets a verified user create source keys for agents, CLIs, webhooks, and subscriptions. External systems write items with a source key; the iOS app reads those items with the user's session token.",
  baseUrl: "Base URL",
  statusTitle: "Current backend status",
  statusItems: [
    ["User binding", "Email login creates the user account. Sources, source keys, items, reminders, sessions, and APNs tokens are stored against that user."],
    ["Device binding", "The iOS app requests APNs permission after login and calls PUT /v1/devices/apns-token with the verified user's Bearer token."],
    ["External ingest", "Agents call POST /v1/ingest/items with a source key. The backend validates the key, writes the item under the key owner's user_id, and supports idempotency."],
    ["Push delivery", "The backend implements APNs delivery and encrypted notification previews. API acceptance, provider delivery, and a visible notification are separate stages. Verify the intended environment, delivery records, device enrollment, and iOS notification settings when testing."]
  ],
  flowTitle: "Recommended flow",
  flowItems: [
    "User signs in with email verification in the iOS app.",
    "The app registers the APNs token and binds it to the verified user.",
    "User creates a Source and a scoped Source Key.",
    "Agent, CLI, or webhook sends items with that Source Key.",
    "The app reads the user's inbox. Test push delivery on the enrolled device and inspect delivery records separately from API acceptance."
  ],
  authTitle: "Authentication",
  authText: "Account endpoints use an app session Bearer token. Ingest endpoints use a Source Key in either Authorization: Bearer <source_key> or x-jizhi-source-key.",
  endpointsTitle: "Endpoints",
  endpoints: [
    ["POST", "/v1/auth/email/start", "Send an email verification code."],
    ["POST", "/v1/auth/email/verify", "Verify the code and return access and refresh tokens."],
    ["POST", "/v1/auth/refresh", "Rotate a refresh token into a new app session."],
    ["GET", "/v1/me", "Return the current verified user."],
    ["POST", "/v1/sources", "Create a source owned by the current user."],
    ["POST", "/v1/sources/:source_id/keys", "Create a scoped source key. The plaintext key is returned only once."],
    ["POST", "/v1/ingest/items", "Create or deduplicate an inbox item from an external source key."],
    ["GET", "/v1/items", "List the user's inbox items."],
    ["PATCH", "/v1/items/:item_id/state", "Mark an item read, archived, or acknowledged."],
    ["POST", "/v1/items/:item_id/reminders", "Create a reminder plan for an item."],
    ["GET", "/v1/reminders", "List reminder plans."],
    ["PUT", "/v1/devices/apns-token", "Bind the current iOS APNs token to the verified user."]
  ],
  examplesTitle: "Examples",
  sourceExampleTitle: "Create a source key",
  ingestExampleTitle: "Ingest an item",
  deviceExampleTitle: "Bind an iOS device token",
  limitsTitle: "Important notes",
  limits: [
    "Always send an Idempotency-Key when ingesting items; duplicate keys return the existing item.",
    "Source keys should be stored like passwords. They are hashed in the backend and cannot be recovered after creation.",
    "Current active reminder delivery is App push or in-app viewing only. SMS and phone calls are not supported.",
    "APNs sending and delivery records are implemented. End-to-end verification still requires checking the actual enrolled device and its notification settings."
  ]
};

const zhApi = {
  metaTitle: "Pushnow 即知 API 文档 - 把 Agent 结果发送到 iOS 收件箱",
  metaDescription: "创建用户绑定的来源密钥，写入 Agent 结果，同步收件箱事项，并绑定 iOS 设备以准备 App 推送。",
  navHome: "首页",
  eyebrow: "开发者 API",
  title: "把 Agent 结果发送到用户绑定的 iOS 收件箱。",
  intro: "Pushnow 即知 API 允许已验证用户为 Agent、CLI、Webhook 和订阅创建来源密钥。外部系统用来源密钥写入事项；iOS App 用用户会话读取这些事项。",
  baseUrl: "基础地址",
  statusTitle: "当前后端状态",
  statusItems: [
    ["用户绑定", "邮箱登录会创建用户账号。来源、来源密钥、事项、提醒、会话和 APNs token 都存储在该用户下面。"],
    ["设备绑定", "iOS App 在登录后请求 APNs 权限，并使用已验证用户的 Bearer token 调用 PUT /v1/devices/apns-token。"],
    ["外部写入", "Agent 调用 POST /v1/ingest/items 并携带来源密钥。后端校验密钥后，把事项写到密钥所属用户的 user_id 下，并支持幂等。"],
    ["推送送达", "后端已实现 APNs 投递和加密通知预览。API 接受、推送服务投递和手机实际显示是不同环节，测试时应核对服务环境、投递记录、设备注册及 iOS 通知设置。"]
  ],
  flowTitle: "推荐流程",
  flowItems: [
    "用户在 iOS App 中通过邮箱验证码登录。",
    "App 注册 APNs token，并绑定到已验证用户。",
    "用户创建 Source 和受限 Source Key。",
    "Agent、CLI 或 Webhook 使用 Source Key 发送事项。",
    "App 读取用户收件箱。请在已注册设备上测试推送，并单独核对投递记录，不要把 API 接受当作手机收到。"
  ],
  authTitle: "认证方式",
  authText: "账号端点使用 App 会话 Bearer token。写入端点使用 Source Key，可放在 Authorization: Bearer <source_key> 或 x-jizhi-source-key。",
  endpointsTitle: "端点",
  endpoints: [
    ["POST", "/v1/auth/email/start", "发送邮箱验证码。"],
    ["POST", "/v1/auth/email/verify", "验证邮箱验证码，并返回 access token 和 refresh token。"],
    ["POST", "/v1/auth/refresh", "用 refresh token 换取新的 App 会话。"],
    ["GET", "/v1/me", "返回当前已验证用户。"],
    ["POST", "/v1/sources", "创建当前用户拥有的来源。"],
    ["POST", "/v1/sources/:source_id/keys", "创建受限来源密钥。明文密钥只返回一次。"],
    ["POST", "/v1/ingest/items", "使用外部来源密钥创建或幂等返回收件事项。"],
    ["GET", "/v1/items", "列出当前用户的收件箱事项。"],
    ["PATCH", "/v1/items/:item_id/state", "把事项标记为已读、归档或已确认。"],
    ["POST", "/v1/items/:item_id/reminders", "为事项创建提醒计划。"],
    ["GET", "/v1/reminders", "列出提醒计划。"],
    ["PUT", "/v1/devices/apns-token", "把当前 iOS APNs token 绑定到已验证用户。"]
  ],
  examplesTitle: "示例",
  sourceExampleTitle: "创建来源密钥",
  ingestExampleTitle: "写入事项",
  deviceExampleTitle: "绑定 iOS 设备 token",
  limitsTitle: "重要说明",
  limits: [
    "写入事项时必须发送 Idempotency-Key；重复 key 会返回已有事项。",
    "Source Key 要像密码一样保存。后端只保存哈希，创建后不能再次查看明文。",
    "当前主动提醒只支持 App 推送或 App 内查看，不支持短信和电话。",
    "APNs 发送和投递记录已实现；端到端验证仍需检查实际注册设备及其通知设置。"
  ]
};

export const apiCopy = {
  en: englishApi,
  "zh-Hans": zhApi,
  ja: englishApi,
  ko: englishApi,
  es: englishApi,
  de: englishApi
} as const;

export const localizedApi = (lang: string) => apiCopy[isLang(lang) ? lang : "en"];

export const copy = {
  en: {
    metaTitle: "PushNow - The notification inbox for agent results",
    metaDescription: "PushNow collects agent results, monitor alerts, subscriptions, and reminders in one iOS inbox with P0/P1 priority and App push controls.",
    navPrivacy: "Privacy",
    navTerms: "Terms",
    navSupport: "Support",
    navApi: "API",
    heroPill: "iOS 18 · Agent inbox · App push",
    heroTitle: "Pushnow",
    heroCopy: "A focused iOS inbox for agent results, urgent events, and reminders. Sign in on the web to review your account, devices, and membership.",
    download: "Download on the App Store",
    comingSoon: "App Store link pending",
    qrTitle: "Scan for the download page",
    featuresTitle: "Control attention before it becomes noise.",
    privacyPromise: "Pushnow uses email login, stores user-bound sources and device tokens, and keeps active reminders to App push or in-app viewing only.",
    faqTitle: "What Pushnow does",
    pricing: "Free includes 50 notification items per day. Plus is CNY 8/month for 500 items per day. Pro is CNY 18/month for unlimited daily items, subject to platform and abuse limits.",
    footerSupport: "PushNow support",
    features: sharedFeatures.en,
    faq: [
      ["Does Pushnow send SMS or phone calls?", "No. Current active reminders are App push or in-app viewing only."],
      ["How does login work?", "Pushnow uses email verification codes. Sources, items, reminders, and device tokens are bound to the verified user."],
      ["Where is the backend hosted?", "The production API runs on Cloudflare Workers with D1 and Cloudflare Email Service."]
    ]
  },
  "zh-Hans": {
    metaTitle: "PushNow 即知 - Agent 结果与提醒收件箱",
    metaDescription: "PushNow 即知把 Agent 结果、监控告警、订阅和提醒收进一个 iOS 收件箱，支持 P0/P1、App 推送和仅 App 内查看。",
    navPrivacy: "隐私",
    navTerms: "条款",
    navSupport: "支持",
    navApi: "API",
    heroPill: "iOS 18 · Agent 收件箱 · App 推送",
    heroTitle: "Pushnow 即知",
    heroCopy: "一个面向 Agent 结果、重要事件和提醒的 iOS 收件箱。网页端可以登录查看账号、授权设备和会员状态。",
    download: "前往 App Store",
    comingSoon: "App Store 链接待上线",
    qrTitle: "扫码打开下载页",
    featuresTitle: "先管理注意力，再接收通知。",
    privacyPromise: "Pushnow 即知使用邮箱登录，来源、设备 token 和提醒规则绑定到同一用户；当前主动提醒只使用 App 推送或 App 内查看。",
    faqTitle: "Pushnow 即知可以做什么",
    pricing: "免费版每天 50 次通知事项。Plus 每月 ¥8，每天 500 次。Pro 每月 ¥18，每日不限次数，但仍受平台和防滥用规则限制。",
    footerSupport: "PushNow 即知支持",
    features: sharedFeatures["zh-Hans"],
    faq: [
      ["Pushnow 即知会发送短信或电话提醒吗？", "不会。当前主动提醒只支持 App 推送，或者仅在 App 内查看。"],
      ["登录如何工作？", "Pushnow 即知使用邮箱验证码登录。来源、事项、提醒和设备 token 都绑定到已验证用户。"],
      ["后端部署在哪里？", "生产 API 运行在 Cloudflare Workers，并使用 D1 和 Cloudflare Email Service。"]
    ]
  },
  ja: {
    metaTitle: "Pushnow - Agent 結果の通知受信箱",
    metaDescription: "Pushnow は Agent 結果、アラート、購読、P0/P1 優先度、App プッシュ制御をまとめる iOS 受信箱です。",
    navPrivacy: "プライバシー",
    navTerms: "規約",
    navSupport: "サポート",
    navApi: "API",
    heroPill: "iOS 18 · Agent 受信箱 · App プッシュ",
    heroTitle: "Pushnow",
    heroCopy: "Agent 結果、重要イベント、リマインダーを、通知するかアプリ内に静かに残すか選べる iOS 受信箱です。",
    download: "App Store でダウンロード",
    comingSoon: "App Store リンク準備中",
    qrTitle: "ダウンロードページをスキャン",
    featuresTitle: "通知になる前に、注意を制御する。",
    privacyPromise: "Pushnow はメールログインを使い、ソース、デバイストークン、リマインダーをユーザーに紐づけます。現在の能動通知は App プッシュまたはアプリ内表示のみです。",
    faqTitle: "Pushnow でできること",
    pricing: "無料機能を提供予定です。Pro 機能は RevenueCat の pro 権限と App Store 購入で提供します。",
    footerSupport: "Pushnow サポート",
    features: sharedFeatures.ja,
    faq: [
      ["SMS や電話通知を送りますか？", "いいえ。現在の能動通知は App プッシュまたはアプリ内表示のみです。"],
      ["ログインはどのように動きますか？", "Pushnow はメール確認コードを使います。ソース、項目、リマインダー、デバイストークンは確認済みユーザーに紐づきます。"],
      ["バックエンドはどこで動いていますか？", "本番 API は Cloudflare Workers、D1、Cloudflare Email Service で動作します。"]
    ]
  },
  ko: {
    metaTitle: "Pushnow - Agent 결과 알림 수신함",
    metaDescription: "Pushnow는 Agent 결과, 알림, 구독, P0/P1 우선순위, App 푸시 제어를 하나로 모으는 iOS 수신함입니다.",
    navPrivacy: "개인정보",
    navTerms: "약관",
    navSupport: "지원",
    navApi: "API",
    heroPill: "iOS 18 · Agent 수신함 · App 푸시",
    heroTitle: "Pushnow",
    heroCopy: "Agent 결과, 중요한 이벤트, 리마인더를 기기로 알리거나 앱 안에 조용히 보관할 수 있는 iOS 수신함입니다.",
    download: "App Store에서 다운로드",
    comingSoon: "App Store 링크 준비 중",
    qrTitle: "다운로드 페이지 QR 스캔",
    featuresTitle: "알림이 소음이 되기 전에 주의를 제어하세요.",
    privacyPromise: "Pushnow는 이메일 로그인을 사용하고 소스, 기기 토큰, 리마인더 규칙을 사용자에 연결합니다. 현재 활성 알림은 App 푸시 또는 앱 내 확인만 지원합니다.",
    faqTitle: "Pushnow 기능",
    pricing: "무료 기능을 제공할 예정입니다. Pro 기능은 RevenueCat의 pro 권한과 App Store 구매로 제공됩니다.",
    footerSupport: "Pushnow 지원",
    features: sharedFeatures.ko,
    faq: [
      ["SMS나 전화 알림을 보내나요?", "아니요. 현재 활성 알림은 App 푸시 또는 앱 내 확인만 지원합니다."],
      ["로그인은 어떻게 작동하나요?", "Pushnow는 이메일 인증 코드를 사용합니다. 소스, 항목, 리마인더, 기기 토큰은 인증된 사용자에 연결됩니다."],
      ["백엔드는 어디에 배포되어 있나요?", "프로덕션 API는 Cloudflare Workers, D1, Cloudflare Email Service에서 실행됩니다."]
    ]
  },
  es: {
    metaTitle: "Pushnow - Bandeja de notificaciones para agentes",
    metaDescription: "Pushnow reúne resultados de agentes, alertas, suscripciones, prioridad P0/P1 y controles de push de App en una bandeja iOS.",
    navPrivacy: "Privacidad",
    navTerms: "Términos",
    navSupport: "Soporte",
    navApi: "API",
    heroPill: "iOS 18 · Bandeja de agentes · Push de App",
    heroTitle: "Pushnow",
    heroCopy: "Una bandeja iOS para resultados de agentes, eventos urgentes y recordatorios que pueden avisarte o esperar dentro de la App.",
    download: "Descargar en App Store",
    comingSoon: "Enlace de App Store pendiente",
    qrTitle: "Escanea la página de descarga",
    featuresTitle: "Controla la atención antes de que sea ruido.",
    privacyPromise: "Pushnow usa inicio de sesión por email, vincula fuentes, tokens de dispositivo y reglas de recordatorio al usuario, y limita los avisos activos a push de App o vista dentro de la App.",
    faqTitle: "Que hace Pushnow",
    pricing: "Habra acceso gratuito. Las funciones Pro se planean con RevenueCat, el entitlement pro y compras de App Store.",
    footerSupport: "Soporte de Pushnow",
    features: sharedFeatures.es,
    faq: [
      ["Pushnow envia SMS o llamadas?", "No. Los recordatorios activos actuales son push de App o vista dentro de la App."],
      ["Como funciona el inicio de sesion?", "Pushnow usa codigos de verificacion por email. Fuentes, elementos, recordatorios y tokens de dispositivo se vinculan al usuario verificado."],
      ["Donde esta alojado el backend?", "La API de produccion corre en Cloudflare Workers con D1 y Cloudflare Email Service."]
    ]
  },
  de: {
    metaTitle: "Pushnow - Benachrichtigungs-Eingang fur Agent-Ergebnisse",
    metaDescription: "Pushnow sammelt Agent-Ergebnisse, Warnungen, Abos, P0/P1 Prioritaten und App-Push-Steuerung in einem iOS-Eingang.",
    navPrivacy: "Datenschutz",
    navTerms: "Bedingungen",
    navSupport: "Support",
    navApi: "API",
    heroPill: "iOS 18 · Agent-Eingang · App-Push",
    heroTitle: "Pushnow",
    heroCopy: "Ein fokussierter iOS-Eingang fur Agent-Ergebnisse, wichtige Ereignisse und Erinnerungen, die benachrichtigen oder ruhig in der App bleiben.",
    download: "Im App Store laden",
    comingSoon: "App-Store-Link ausstehend",
    qrTitle: "Downloadseite scannen",
    featuresTitle: "Steuere Aufmerksamkeit, bevor sie zu Larm wird.",
    privacyPromise: "Pushnow nutzt E-Mail-Login, bindet Quellen, Gerate-Token und Erinnerungsregeln an den Nutzer und beschrankt aktive Hinweise auf App-Push oder Ansicht in der App.",
    faqTitle: "Was Pushnow macht",
    pricing: "Kostenloser Zugriff ist geplant. Pro-Funktionen werden uber RevenueCat, das pro Entitlement und App-Store-Kaufe geplant.",
    footerSupport: "Pushnow Support",
    features: sharedFeatures.de,
    faq: [
      ["Sendet Pushnow SMS oder Telefonanrufe?", "Nein. Aktive Erinnerungen sind derzeit App-Push oder Ansicht in der App."],
      ["Wie funktioniert der Login?", "Pushnow nutzt E-Mail-Bestatigungscodes. Quellen, Eintrage, Erinnerungen und Gerate-Token sind an den bestatigten Nutzer gebunden."],
      ["Wo lauft das Backend?", "Die Produktions-API lauft auf Cloudflare Workers mit D1 und Cloudflare Email Service."]
    ]
  }
} as const;

export type Lang = keyof typeof copy;

export const isLang = (lang: string): lang is Lang => Object.prototype.hasOwnProperty.call(copy, lang);

export const localizedCopy = (lang: string) => copy[isLang(lang) ? lang : "en"];

const englishLegal = {
  updatedPrefix: "Last updated",
  privacy: {
    title: "Privacy Policy",
    description: "How Pushnow handles email login, sources, reminders, device tokens, payments, and deletion requests.",
    sections: [
      ["Data we collect", "Pushnow collects your email address, email verification status, account identifiers, source settings, source keys, inbox items, reminder plans, notification preferences, device push tokens, and basic technical metadata needed to operate the service."],
      ["How we use data", "We use this data to verify login, bind agents and devices to your account, deliver App push notifications, keep in-app reminders available, prevent duplicate ingest requests, and support account recovery or deletion requests."],
      ["Third-party services", "The backend runs on Cloudflare Workers, D1, and Cloudflare Email Service. App push delivery uses Apple Push Notification service. Paid features are planned through RevenueCat and App Store purchases."],
      ["Reminder channels", "Pushnow does not use SMS or phone-call reminders in the current version. Active reminder delivery is limited to App push or in-app viewing."],
      ["Your choices", "You can disable App push for an item or level, keep items in-app only, request account deletion, or contact support."]
    ]
  },
  terms: {
    title: "Terms of Use",
    description: "Terms for using Pushnow, including account access, reminders, subscriptions, refunds, and acceptable use.",
    sections: [
      ["License", "Pushnow grants you a personal, non-transferable license to use the app for collecting and managing your own notifications, agent results, and reminders."],
      ["Accounts and sources", "You are responsible for protecting your email account and source keys. Do not use Pushnow to ingest illegal, abusive, infringing, or harmful content."],
      ["Notifications", "Reminder delivery depends on device settings, network state, Apple Push Notification service, and Cloudflare availability. You should not rely on Pushnow for emergency services or safety-critical alerts."],
      ["Purchases and refunds", "Planned Pro features use RevenueCat and App Store purchases. Refund requests are handled through Apple according to App Store rules."],
      ["Contact", "Questions about these terms can be sent to support."]
    ]
  },
  support: {
    title: "Support",
    description: "Contact Pushnow support and review common questions about login, notifications, subscriptions, and data deletion.",
    sections: [
      ["Contact", "Email support for login, notification, subscription, privacy, or deletion support."],
      ["Email login", "Enter your email in the app, then use the verification code sent from login@pushnow.dev. Check your inbox and updates folder if it is not visible."],
      ["App push", "After email verification, enable App push in Settings. You can keep individual reminders in-app only when you do not want a device notification."],
      ["Purchases", "When Pro is available, use Restore Purchases in the paywall or settings flow before buying again on a reinstalled device."]
    ]
  }
};

export const legalCopy = {
  en: englishLegal,
  "zh-Hans": {
    updatedPrefix: "最后更新",
    privacy: {
      title: "隐私政策",
      description: "Pushnow 即知如何处理邮箱登录、来源、提醒、设备 token、购买和删除请求。",
      sections: [
        ["我们收集的数据", "Pushnow 即知会收集邮箱地址、邮箱验证状态、账号标识、来源设置、来源密钥、收件事项、提醒计划、通知偏好、设备推送 token，以及运行服务所需的基础技术信息。"],
        ["数据用途", "这些数据用于验证登录、把 Agent 和设备绑定到账号、发送 App 推送、保留 App 内提醒、防止重复写入，并支持账号恢复或删除请求。"],
        ["第三方服务", "后端运行在 Cloudflare Workers、D1 和 Cloudflare Email Service。App 推送使用 Apple Push Notification service。付费能力计划通过 RevenueCat 和 App Store 购买实现。"],
        ["提醒渠道", "当前版本不使用短信或电话提醒。主动提醒仅限 App 推送或 App 内查看。"],
        ["你的选择", "你可以关闭某个事项或级别的 App 推送、仅在 App 内查看、请求删除账号，或联系支持。"]
      ]
    },
    terms: {
      title: "使用条款",
      description: "Pushnow 即知的账号、提醒、订阅、退款和可接受使用条款。",
      sections: [
        ["许可", "Pushnow 即知授予你个人、不可转让的使用许可，用于收集和管理你自己的通知、Agent 结果和提醒。"],
        ["账号与来源", "你需要保护自己的邮箱账号和来源密钥。不得使用 Pushnow 即知写入违法、滥用、侵权或有害内容。"],
        ["通知", "提醒送达取决于设备设置、网络状态、Apple Push Notification service 和 Cloudflare 可用性。不要把 Pushnow 即知用于紧急服务或安全关键告警。"],
        ["购买与退款", "计划中的 Pro 能力使用 RevenueCat 和 App Store 购买。退款请求按照 App Store 规则通过 Apple 处理。"],
        ["联系", "关于条款的问题可以发送给支持邮箱。"]
      ]
    },
    support: {
      title: "支持",
      description: "联系 Pushnow 即知支持，并查看登录、通知、订阅和数据删除的常见问题。",
      sections: [
        ["联系", "如需登录、通知、订阅、隐私或删除支持，请发送邮件给支持邮箱。"],
        ["邮箱登录", "在 App 中输入邮箱，然后使用 login@pushnow.dev 发出的验证码。如果没有看到邮件，请检查收件箱和分类文件夹。"],
        ["App 推送", "邮箱验证后，可在设置里开启 App 推送。你也可以把单个提醒设为仅 App 内查看。"],
        ["购买", "Pro 上线后，重装设备时请先在付费墙或设置流程中使用恢复购买，再考虑重新购买。"]
      ]
    }
  }
} as const;

export const localizedLegal = (lang: string) => legalCopy[lang === "zh-Hans" ? "zh-Hans" : "en"];
