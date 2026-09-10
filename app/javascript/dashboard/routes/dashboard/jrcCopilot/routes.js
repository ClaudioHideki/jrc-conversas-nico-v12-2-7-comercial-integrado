import { frontendURL } from 'dashboard/helper/URLHelper';

const JrcCopilotPage = () => import('./JrcCopilotPage.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/copiloto-jrc'),
    name: 'jrc_copilot_index',
    component: JrcCopilotPage,
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
  },
];
