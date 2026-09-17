import { frontendURL } from 'dashboard/helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/whatsapp-connections'),
    name: 'jrc_broker_connections',
    component: () => import('./ConnectionsPage.vue'),
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
  },
];
