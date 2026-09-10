import { frontendURL } from 'dashboard/helper/URLHelper';

const WebphonePage = () => import('./WebphonePage.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/ramal'),
    name: 'ramal_index',
    component: WebphonePage,
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
  },
];
