import type { MembershipPlanID, MembershipStatus, PlanQuota, UsageCounterRecord } from "./product-contracts";

export const membershipPlans: Record<MembershipPlanID, PlanQuota> = {
  free: {
    plan: "free",
    displayName: "Free",
    dailyNotificationLimit: 50
  },
  plus: {
    plan: "plus",
    displayName: "Plus",
    dailyNotificationLimit: 500
  },
  pro: {
    plan: "pro",
    displayName: "Pro",
    dailyNotificationLimit: null
  }
};

export function planForRevenueCatProduct(productID: string | null | undefined): MembershipPlanID {
  if (!productID) return "free";
  if (productID.includes(".plus.")) return "plus";
  if (productID.includes(".pro.") || productID.includes(".premium.")) return "pro";
  return "free";
}

export function usageWindowFor(date: Date): { windowStart: string; windowEnd: string } {
  const start = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { windowStart: start.toISOString(), windowEnd: end.toISOString() };
}

export function membershipStatus(plan: MembershipPlanID, usage: UsageCounterRecord | null, window: { windowStart: string; windowEnd: string }): MembershipStatus {
  const quota = membershipPlans[plan];
  const usedToday = usage?.usedCount ?? 0;
  return {
    plan,
    displayName: quota.displayName,
    dailyNotificationLimit: quota.dailyNotificationLimit,
    usedToday,
    remainingToday: quota.dailyNotificationLimit === null ? null : Math.max(quota.dailyNotificationLimit - usedToday, 0),
    windowStart: window.windowStart,
    windowEnd: window.windowEnd
  };
}
