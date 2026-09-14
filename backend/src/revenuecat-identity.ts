export type PaymentEnvironment='PRODUCTION'|'SANDBOX';
export function revenueCatPrefix(environment?:PaymentEnvironment):string {
 return environment==='SANDBOX'?'jizhi_sandbox_':'jizhi_';
}
export function revenueCatIdentity(user:string,environment?:PaymentEnvironment):string {
 return `${revenueCatPrefix(environment)}${user}`;
}
