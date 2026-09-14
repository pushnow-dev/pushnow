export interface DiscoveryChannel { id: string; title: string; summary: string; badge: string; icon?: Resource; color: string; }
export const discoveryChannels: DiscoveryChannel[] = [
  { id: 'weibo', title: 'Weibo', summary: 'Trending topics and entertainment news', badge: 'Social', color: '#E6162D', icon: $r('app.media.discovery_weibo') },
  { id: 'zhihu', title: 'Zhihu', summary: 'Popular questions and expert discussions', badge: 'Questions', color: '#0084FF', icon: $r('app.media.discovery_zhihu') },
  { id: 'bilibili', title: 'Bilibili', summary: 'Popular videos and creator updates', badge: 'Video', color: '#00A1D6', icon: $r('app.media.discovery_bilibili') },
  { id: 'github', title: 'GitHub', summary: 'Project releases and open-source trends', badge: 'Development', color: '#181717', icon: $r('app.media.discovery_github') },
  { id: 'youtube', title: 'YouTube', summary: 'Channel videos and creator updates', badge: 'Video', color: '#FF0000', icon: $r('app.media.discovery_youtube') },
  { id: 'telegram', title: 'Telegram', summary: 'Public channels and community announcements', badge: 'Messaging', color: '#26A5E4', icon: $r('app.media.discovery_telegram') },
  { id: 'rss', title: 'RSS', summary: 'Blogs, articles and independent publications', badge: 'Feeds', color: '#FFA500', icon: $r('app.media.discovery_rss') },
  { id: 'reddit', title: 'Reddit', summary: 'Community discussions and interest groups', badge: 'Social', color: '#FF4500', icon: $r('app.media.discovery_reddit') },
  { id: 'hackernews', title: 'Hacker News', summary: 'Technology, startups and developer discussions', badge: 'Technology', color: '#FF6600', icon: $r('app.media.discovery_hackernews') },
  { id: 'stackoverflow', title: 'Stack Overflow', summary: 'Programming questions and technical answers', badge: 'Development', color: '#F58025', icon: $r('app.media.discovery_stackoverflow') },
  { id: 'ai', title: 'AI daily picks', summary: 'AI research, product launches and industry news', badge: 'Technology', color: '#F2F2F7' },
  { id: 'gold', title: 'Gold and silver', summary: 'Precious metals, markets and economic updates', badge: 'Finance', color: '#F2F2F7' },
];
