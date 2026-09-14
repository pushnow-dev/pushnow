export interface ProductGuide {
  title: string; description: string; intro: string; updated: string;
  stepsTitle: string; steps: string[]; faqTitle: string; faq: [string, string][];
  docs: string; support: string;
}
export const productGuides: Record<string, ProductGuide> = {
  en: {
    title: 'How PushNow connects your automations to your iPhone',
    description: 'A practical guide to PushNow: approve senders, collect agent results, understand notification delivery, and protect message content.',
    intro: 'PushNow is an iOS inbox for results from AI agents, scripts, monitoring tools, and other automations. A sender submits a message to your account so you can review the result on your phone. Use it for a finished build, a monitoring event, or a report that deserves your attention, with a link back to the original context.',
    updated: 'Updated September 13, 2026', stepsTitle: 'How do I connect an automation?',
    steps: ['Sign in to PushNow on your iPhone and set up the device. Enable notifications if you want alerts outside the app; iOS settings determine how those alerts appear.', 'Start account-token sender authorization from the dashboard or SDK, then open the signed-in app to approve the new sender. Manual CLI authorization remains available when a token is not available.', 'Send a small test message with a recognizable title and a useful link. Check that it appears in the correct inbox, then confirm notification behavior on the phone before relying on the workflow.', 'Keep sender credentials private and use separate senders for separate integrations. If a sender is no longer needed, revoke its access. Consult the API docs when adding scheduling, files, or retry handling.'],
    faqTitle: 'Questions about PushNow',
    faq: [
      ['What can I send to PushNow?', 'Send results that your automation produces: build summaries, monitoring events, research notes, or scheduled reports. Messages can carry a title, body, and links to the source. The content guide documents file and media handling and the limits that apply; PushNow does not create or verify the underlying report for you.'],
      ['Does an accepted API request prove that my iPhone received an alert?', 'No. API acceptance, inbox storage, push delivery, and a visible notification are different steps. Check the inbox and the actual device. Network conditions, notification permissions, Focus settings, and preview processing can change when and how an alert appears. Do not use PushNow as the only channel for emergency or safety-critical alerts.'],
      ['Can I save a result without interrupting myself?', 'The product separates inbox content from notification behavior. Choose an in-app-only workflow when a result can wait, and use an alert for results that need attention. Consult the current API documentation for the delivery fields supported by your integration; setting a priority does not override iOS notification settings.'],
      ['Who can read encrypted message content?', 'The documented v2 flow encrypts message content for the account archive before upload. Trusted devices receive archive access through approval. Routing identifiers, source names, timing, ciphertext sizes, and delivery attempts remain service metadata. Avoid placing secrets in source names, and verify fingerprints when approving a sender or another device.'],
      ['How do plans and purchases work?', 'Review the membership screen for the products, currency, billing period, and limits currently available to your App Store account. Confirm the purchase sheet before subscribing and use Restore Purchases if access is missing after reinstalling. Website examples are not a substitute for the current store price or entitlement state.'],
      ['Where should I start when an integration fails?', 'First verify the account and authorized sender, then check the response and relevant logs without sharing credentials. Test a minimal message before adding links, attachments, or scheduling. If the item exists but no alert appears, inspect the phone notification settings separately. Send support the timestamp, error, and reproduction steps, with secrets removed.']
    ], docs: 'Read the integration documentation', support: 'Get support'
  },
  'zh-Hans': {
    title: '如何把自动化结果发送到 iPhone 上的 PushNow', description: '了解 PushNow 的发送端授权、Agent 结果收件箱、通知送达、内容加密和购买恢复，按步骤验证自己的工作流。',
    intro: 'PushNow 是用于接收 AI Agent、脚本、监控工具和其他自动化结果的 iOS 收件箱。发送端把消息写入你的账号，你可以在手机上查看构建摘要、监控事件或研究报告，并通过链接回到原始上下文。先验证一个简单流程，再逐步接入更多来源。',
    updated: '更新于 2026 年 9 月 13 日', stepsTitle: '如何接入一个自动化流程？',
    steps: ['在 iPhone 上登录 PushNow 并完成设备设置。如果需要 App 外提醒，请允许通知；具体显示方式由 iOS 通知设置决定。', '从 Dashboard 或 SDK 使用账号 token 发起发送端授权，然后在已登录 App 中批准新 sender。没有 token 的 CLI 场景仍可使用手动指纹授权。', '先发送标题容易辨认、附有实用链接的测试消息。确认内容进入正确的收件箱，再在手机上检查实际通知效果。', '妥善保管发送端凭据，为不同集成分别授权；停用的发送端应撤销权限。增加定时、文件或重试处理前，先查阅对应文档。'],
    faqTitle: '关于 PushNow 的常见问题', faq: [
      ['可以发送哪些内容？', '可以发送自动化已经产生的构建摘要、监控事件、研究笔记和定期报告。消息可包含标题、正文以及原始资料链接。文件和媒体的处理方式及限制请查看内容文档；PushNow 不会替你生成或核实报告本身。'],
      ['API 返回成功就说明手机收到提醒了吗？', '不代表。请求被接受、内容保存、推送送达和手机显示提醒是不同环节。应同时检查收件箱和实际设备。网络、通知权限、专注模式及预览处理都可能影响显示时间和方式。不要将其作为紧急或安全关键事件的唯一提醒渠道。'],
      ['可以只保存、不打断我吗？', '产品将收件箱内容和通知行为分开处理。可以等待的结果适合仅 App 内查看，需要关注的结果再使用提醒。具体发送字段以当前集成文档为准；消息优先级不会覆盖 iOS 通知设置。'],
      ['加密后服务端还能看到什么？', '文档中的 v2 流程在上传前为账号归档加密消息内容，受信任设备通过批准获得归档访问权限。路由标识、来源名称、时间、密文大小和投递记录仍属于服务元数据。不要在来源名称中填写秘密，授权发送端或新设备时应核对指纹。'],
      ['会员价格和恢复购买在哪里查看？', '请以 App 会员页和 App Store 购买确认页显示的商品、币种、计费周期及额度为准。重新安装后权益未显示，可使用恢复购买入口。网站上的价格示例不能代替当前商店价格或实际权益状态。'],
      ['接入失败时应该先检查什么？', '先确认账号和发送端授权，再检查响应及相关日志，避免暴露凭据。先测最小消息，再增加链接、附件和定时。若收件箱已有内容但没有提醒，应单独检查手机通知设置。联系支持时提供时间、错误和复现步骤，并删除密钥等敏感信息。']
    ], docs: '阅读接入文档', support: '获取支持'
  },
  ja: {
    title: '自動化の結果を PushNow で iPhone に届ける方法', description: '送信元の承認から受信箱、通知の確認、暗号化、購入の復元まで、PushNow の使い方を説明します。',
    intro: 'PushNow は AI エージェント、スクリプト、監視ツールなどの結果を受け取る iOS の受信箱です。ビルドの概要、監視イベント、調査レポートをアカウントに送り、iPhone で確認できます。元の情報へのリンクを添えると、必要な文脈に戻れます。', updated: '更新日：2026 年 9 月 13 日', stepsTitle: '自動化を接続する手順',
    steps: ['iPhone でログインして端末を設定します。アプリ外で通知を受ける場合は通知を許可してください。表示方法は iOS の設定に従います。', 'PushNow CLI で送信元の承認を開始します。アプリでコードと送信元の指紋を確認し、CLI でもアカウントの指紋を照合してください。', '識別しやすいタイトルとリンクを使ってテスト送信します。受信箱の内容と実機の通知をそれぞれ確認してください。', '認証情報を秘密に保ち、連携ごとに送信元を分けます。使わなくなった送信元を失効し、予約やファイルを追加する前に資料を確認します。'],
    faqTitle: 'よくある質問', faq: [
      ['何を送信できますか？', 'ビルドの概要、監視イベント、調査メモ、定期レポートなど、自動化が出力した結果を送れます。タイトル、本文、リンクで文脈を伝えます。ファイルやメディアの条件はコンテンツ資料をご覧ください。元のレポートの作成や正確性の確認は送信側で行います。'],
      ['API の成功は通知の到着を意味しますか？', 'いいえ。リクエストの受付、保存、配信、端末での表示は別々です。受信箱と実機を確認してください。ネットワーク、通知権限、集中モード、プレビュー処理が表示に影響します。緊急・安全上重要な連絡の唯一の手段にはしないでください。'],
      ['通知せず保存できますか？', '受信箱の内容と通知動作は分けて扱います。後で読む結果はアプリ内で確認し、注意が必要な結果には通知を使います。利用できる送信フィールドは最新の API 資料で確認してください。優先度は iOS の通知設定を変更しません。'],
      ['暗号化してもサーバーに見える情報は？', 'v2 の文書化されたフローでは、アップロード前にメッセージをアカウントのアーカイブ向けに暗号化します。ルーティング ID、送信元名、時刻、暗号文のサイズ、配信記録はメタデータとして残ります。送信元名に秘密を入れず、承認時に指紋を照合してください。'],
      ['料金と購入の復元はどこで確認しますか？', '利用可能な商品、通貨、請求期間、上限はアプリの会員画面と App Store の購入確認画面で確認します。再インストール後は購入の復元を利用できます。ウェブ上の例より現在のストア表示を優先してください。'],
      ['連携が動かない場合は？', 'アカウントと送信元の承認を確認し、秘密情報を除いたレスポンスとログを調べます。最小のメッセージからテストしてください。受信箱にあるのに通知が出ない場合は端末設定を別途確認します。サポートには時刻、エラー、再現手順をお知らせください。']
    ], docs: '連携ドキュメントを読む', support: 'サポート'
  },
  ko: {
    title: '자동화 결과를 PushNow로 iPhone에서 확인하는 방법', description: 'PushNow 발신자 승인, 결과 수신함, 알림 전달 확인, 메시지 암호화와 구매 복원을 안내합니다.',
    intro: 'PushNow는 AI 에이전트, 스크립트, 모니터링 도구 등 자동화 결과를 받는 iOS 수신함입니다. 빌드 요약, 모니터링 이벤트, 조사 보고서를 계정에 보내고 휴대폰에서 확인합니다. 원본 링크를 함께 보내면 결과의 맥락을 다시 살펴볼 수 있습니다.', updated: '업데이트: 2026년 9월 13일', stepsTitle: '자동화를 연결하는 순서',
    steps: ['iPhone에서 로그인하고 기기를 설정합니다. 앱 밖에서 알림을 받으려면 알림 권한을 허용하세요. 표시 방식은 iOS 설정을 따릅니다.', 'PushNow CLI에서 발신자 승인을 시작합니다. 앱에서 코드와 발신자 지문을 확인한 뒤 CLI에서도 계정 지문을 대조합니다.', '구분하기 쉬운 제목과 링크로 테스트 메시지를 보냅니다. 올바른 수신함에 저장되었는지 확인하고 실제 기기 알림도 따로 확인하세요.', '자격 증명을 안전하게 보관하고 연동마다 발신자를 구분합니다. 필요 없는 발신자는 해지하고 예약, 파일, 재시도 기능은 문서를 확인한 뒤 추가합니다.'],
    faqTitle: '자주 묻는 질문', faq: [
      ['어떤 내용을 보낼 수 있나요?', '자동화가 만든 빌드 요약, 모니터링 이벤트, 조사 메모와 정기 보고서를 보낼 수 있습니다. 제목, 본문, 원본 링크로 맥락을 전달합니다. 파일과 미디어 조건은 콘텐츠 문서를 확인하세요. 원본 보고서의 생성과 정확성 검증은 발신 측의 역할입니다.'],
      ['API 성공 응답이 휴대폰 알림 도착을 뜻하나요?', '아닙니다. 요청 접수, 저장, 푸시 전달과 기기 표시는 각각 다른 단계입니다. 수신함과 실제 기기를 확인하세요. 네트워크, 알림 권한, 집중 모드와 미리보기 처리가 영향을 줍니다. 긴급하거나 안전이 중요한 알림의 유일한 경로로 사용하지 마세요.'],
      ['방해받지 않고 저장만 할 수 있나요?', '수신함 내용과 알림 동작을 구분합니다. 나중에 읽을 결과는 앱에서 확인하고 주의가 필요한 결과에 알림을 사용합니다. 지원되는 전송 필드는 현재 API 문서를 확인하세요. 우선순위는 iOS 알림 설정을 무시하지 않습니다.'],
      ['암호화 후에도 서비스가 보는 정보는 무엇인가요?', '문서화된 v2 흐름은 업로드 전에 계정 아카이브를 대상으로 메시지를 암호화합니다. 라우팅 ID, 발신자 이름, 시각, 암호문 크기와 전달 기록은 메타데이터로 남습니다. 이름에 비밀을 넣지 말고 발신자나 기기 승인 시 지문을 확인하세요.'],
      ['요금과 구매 복원은 어디서 확인하나요?', '앱 멤버십 화면과 App Store 구매 확인 화면에서 상품, 통화, 청구 기간과 한도를 확인합니다. 재설치 후 권한이 없으면 구매 복원을 사용하세요. 웹 예시는 현재 스토어 가격이나 실제 권한 상태를 대신하지 않습니다.'],
      ['연동 실패 시 무엇부터 확인하나요?', '계정과 발신자 승인을 확인한 뒤 비밀 정보를 제거한 응답과 로그를 살펴보세요. 최소 메시지부터 시험합니다. 수신함에 있는데 알림이 없으면 기기 설정을 별도로 확인합니다. 지원 요청에는 시각, 오류와 재현 단계를 포함하세요.']
    ], docs: '연동 문서 읽기', support: '지원 받기'
  },
  es: {
    title: 'Cómo conectar tus automatizaciones con PushNow en el iPhone', description: 'Guía de PushNow para autorizar remitentes, recibir resultados, comprobar notificaciones y entender el cifrado y las compras.',
    intro: 'PushNow es una bandeja de entrada para iOS que recibe resultados de agentes de IA, scripts y herramientas de monitorización. Envía un resumen de compilación, un evento o un informe a tu cuenta y revísalo en el teléfono. Añade un enlace al origen para conservar el contexto del resultado.', updated: 'Actualizado el 13 de septiembre de 2026', stepsTitle: 'Cómo conectar una automatización',
    steps: ['Inicia sesión en el iPhone y configura el dispositivo. Permite las notificaciones si quieres avisos fuera de la app; su presentación depende de iOS.', 'Inicia la autorización con la CLI de PushNow. Comprueba el código y la huella del remitente en la app y después verifica la huella de la cuenta en la CLI.', 'Envía un mensaje de prueba con un título reconocible y un enlace útil. Comprueba la bandeja correcta y, por separado, la notificación en el teléfono.', 'Protege las credenciales y usa remitentes separados para cada integración. Revoca los que ya no utilices y consulta la documentación antes de añadir archivos, programación o reintentos.'],
    faqTitle: 'Preguntas frecuentes', faq: [
      ['¿Qué puedo enviar?', 'Resultados creados por tus automatizaciones: resúmenes de compilación, eventos, notas e informes periódicos. Incluye título, texto y enlaces al origen. La guía de contenido explica los archivos, los medios y sus límites. PushNow no genera ni verifica el informe original.'],
      ['¿Una respuesta correcta de la API confirma la llegada del aviso?', 'No. Aceptar la solicitud, guardar el contenido, entregar el push y mostrarlo son pasos distintos. Comprueba la bandeja y el dispositivo. La red, los permisos, los modos de concentración y la vista previa pueden afectar al aviso. No lo uses como único canal para emergencias o alertas de seguridad crítica.'],
      ['¿Puedo guardar un resultado sin interrupciones?', 'El contenido de la bandeja se trata por separado del comportamiento de las notificaciones. Revisa dentro de la app los resultados que pueden esperar y reserva los avisos para los que necesitan atención. Consulta los campos de envío en la API actual. La prioridad no anula los ajustes de iOS.'],
      ['¿Qué información sigue viendo el servicio con el cifrado?', 'El flujo v2 documentado cifra los mensajes para el archivo de la cuenta antes de subirlos. Los identificadores de enrutamiento, nombres de origen, horarios, tamaños y registros de entrega siguen siendo metadatos. Evita secretos en los nombres y compara las huellas al autorizar remitentes o dispositivos.'],
      ['¿Dónde consulto precios y restauro compras?', 'La pantalla de membresía y la confirmación de App Store muestran productos, moneda, periodo de cobro y límites disponibles. Usa Restaurar compras si falta el acceso tras reinstalar. Los ejemplos de la web no sustituyen el precio actual de la tienda ni el estado real de tus derechos.'],
      ['¿Cómo investigo un fallo?', 'Verifica la cuenta y el remitente autorizado; revisa la respuesta y los registros sin exponer credenciales. Prueba un mensaje mínimo antes de añadir archivos o programación. Si aparece en la bandeja pero no hay aviso, revisa por separado el teléfono. Facilita a soporte la hora, el error y los pasos para reproducirlo.']
    ], docs: 'Leer la documentación de integración', support: 'Obtener ayuda'
  },
  de: {
    title: 'Automatisierungen mit PushNow auf dem iPhone verbinden', description: 'PushNow erklärt: Absender freigeben, Ergebnisse empfangen, Benachrichtigungen prüfen sowie Verschlüsselung und Käufe verstehen.',
    intro: 'PushNow ist ein iOS-Posteingang für Ergebnisse von KI-Agenten, Skripten und Monitoring-Werkzeugen. Sende Build-Zusammenfassungen, Ereignisse oder Berichte an dein Konto und prüfe sie auf dem iPhone. Ein Link zur ursprünglichen Quelle hilft, den Zusammenhang des Ergebnisses nachzuvollziehen.', updated: 'Aktualisiert am 13. September 2026', stepsTitle: 'So verbindest du eine Automatisierung',
    steps: ['Melde dich auf dem iPhone an und richte das Gerät ein. Erlaube Mitteilungen für Hinweise außerhalb der App. Ihre Darstellung richtet sich nach den iOS-Einstellungen.', 'Starte die Absenderfreigabe mit der PushNow CLI. Prüfe Code und Absenderfingerabdruck in der App, danach den Kontofingerabdruck in der CLI.', 'Sende eine Testnachricht mit eindeutigem Titel und hilfreichem Link. Prüfe den richtigen Posteingang und anschließend die Benachrichtigung auf dem Gerät.', 'Bewahre Zugangsdaten sicher auf und nutze getrennte Absender je Integration. Widerrufe ungenutzte Zugänge. Lies die Dokumentation, bevor du Dateien, Zeitplanung oder Wiederholungen ergänzt.'],
    faqTitle: 'Häufige Fragen', faq: [
      ['Was kann ich senden?', 'Ergebnisse deiner Automatisierungen, etwa Build-Zusammenfassungen, Monitoring-Ereignisse, Notizen und regelmäßige Berichte. Titel, Text und Links liefern den Kontext. Die Inhaltsdokumentation beschreibt Dateien, Medien und Grenzen. PushNow erstellt oder überprüft den ursprünglichen Bericht nicht.'],
      ['Beweist eine erfolgreiche API-Antwort den Empfang am iPhone?', 'Nein. Annahme, Speicherung, Push-Zustellung und sichtbare Mitteilung sind verschiedene Schritte. Prüfe Posteingang und Gerät. Netzwerk, Berechtigungen, Fokus und Vorschauverarbeitung können die Anzeige beeinflussen. Verwende PushNow nicht als einzigen Kanal für Notfälle oder sicherheitskritische Meldungen.'],
      ['Kann ich Ergebnisse ohne Unterbrechung speichern?', 'Posteingang und Benachrichtigungsverhalten werden getrennt behandelt. Lies weniger dringende Ergebnisse in der App und nutze Hinweise für Inhalte, die Aufmerksamkeit brauchen. Die aktuelle API-Dokumentation beschreibt die unterstützten Felder. Eine Priorität setzt die iOS-Einstellungen nicht außer Kraft.'],
      ['Welche Daten sieht der Dienst trotz Verschlüsselung?', 'Der dokumentierte v2-Ablauf verschlüsselt Nachrichten vor dem Upload für das Kontoarchiv. Routing-IDs, Quellennamen, Zeitpunkte, Größen und Zustellversuche bleiben Metadaten. Schreibe keine Geheimnisse in Quellennamen und vergleiche Fingerabdrücke bei der Freigabe von Absendern oder Geräten.'],
      ['Wo finde ich Preise und stelle Käufe wieder her?', 'Mitgliedschaftsseite und App-Store-Kaufbestätigung zeigen verfügbare Produkte, Währung, Abrechnungszeitraum und Grenzen. Nutze Käufe wiederherstellen, wenn der Zugang nach einer Neuinstallation fehlt. Website-Beispiele ersetzen weder den aktuellen Store-Preis noch den tatsächlichen Berechtigungsstatus.'],
      ['Wie untersuche ich Integrationsfehler?', 'Prüfe Konto und Absenderfreigabe, danach Antworten und Protokolle ohne geheime Zugangsdaten. Beginne mit einer einfachen Nachricht. Ist sie im Posteingang, aber ohne Hinweis, prüfe die Geräteeinstellungen getrennt. Nenne dem Support Zeitpunkt, Fehler und Schritte zur Wiederholung.']
    ], docs: 'Integrationsdokumentation lesen', support: 'Support kontaktieren'
  }
};
