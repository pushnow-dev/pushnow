import { readFileSync, writeFileSync } from 'node:fs';
const path = 'JiZhi/Resources/Localizable.xcstrings';
const catalog = JSON.parse(readFileSync(path, 'utf8'));
const translations = {
 'Sender keys':'发送密钥','Notification logs':'通知日志','No sender keys':'暂无发送密钥',
 'No notification logs':'暂无通知日志','Key expiry':'密钥有效期','Never':'永不过期',
 '7 days':'7 天','30 days':'30 天','90 days':'90 天','Active':'有效','Expired':'已过期','Revoked':'已撤销',
 'Edit expiry':'修改有效期','Current expiry':'当前有效期','Create another key':'创建另一个密钥',
 'Create key':'创建密钥','New sender key':'新发送密钥','Revoke key':'撤销密钥','Revoke key?':'撤销此密钥？',
 'This key will no longer be able to send notifications.':'此密钥将无法再发送通知。',
 'Keep this key safe. It will only be shown once.':'请妥善保存此密钥，它只显示一次。',
 'Created':'创建时间','Expires':'到期时间','Last used':'上次使用','Not used yet':'尚未使用',
 'Not available':'暂无','Retry':'重试','Load more':'加载更多','Save':'保存','Done':'完成',
 'Notification':'通知','Notification details':'通知详情','Source':'来源','Message ID':'消息 ID',
 'Key ID':'密钥 ID','Scheduled':'计划发送时间','Immediately':'立即','Read':'阅读时间','Unread':'未读',
 'Device deliveries':'设备投递记录','No device deliveries':'暂无设备投递记录','Devices: %lld':'设备数：%lld',
 'Status':'状态','Attempts':'尝试次数','Accepted by push service':'推送服务已接受','Pending':'等待发送',
 'Retrying':'正在重试','Blocked':'已阻止','Failed':'失败','Suppressed':'已跳过','Sent':'已发送',
 'Pairing code':'配对码','Waiting for device approval':'等待设备确认'
};
for (const [key, value] of Object.entries(translations)) {
 const entry = catalog.strings[key] ??= {};
 entry.localizations ??= {};
 for (const [locale,text] of [['en',key],['zh-Hans',value]]) {
  entry.localizations[locale] = {stringUnit:{state:'translated',value:text}};
 }
}
writeFileSync(path, JSON.stringify(catalog,null,2)+'\n');
