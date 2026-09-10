import { frontendURL } from 'dashboard/helper/URLHelper';

const WhatsAppCallingPage = () => import('./WhatsAppCallingPage.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/whatsapp'),
    name: 'whatsapp_calling_index',
    component: WhatsAppCallingPage,
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
  },
  {
    path: frontendURL('accounts/:accountId/whatsapp-calling'),
    name: 'whatsapp_calling_legacy',
    redirect: to => ({
      name: 'whatsapp_calling_index',
      params: to.params,
      query: to.query,
      hash: to.hash,
    }),
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
  },
];
