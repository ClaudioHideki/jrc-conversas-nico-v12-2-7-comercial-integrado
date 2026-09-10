import { frontendURL } from 'dashboard/helper/URLHelper';

const JrcCockpit = () => import('./JrcCockpit.vue');
const JrcEmailCenter = () => import('./JrcEmailCenter.vue');
const JrcCallsCenter = () => import('./JrcCallsCenter.vue');

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/cockpit'),
    name: 'jrc_cockpit',
    component: JrcCockpit,
    meta,
  },
  {
    // Compatibilidade: Central de Atendimento foi consolidada no Cockpit.
    path: frontendURL('accounts/:accountId/central-atendimento'),
    name: 'jrc_service_center',
    redirect: to => ({
      name: 'jrc_cockpit',
      params: to.params,
      query: to.query,
      hash: to.hash,
    }),
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/emails'),
    name: 'jrc_email_center',
    component: JrcEmailCenter,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/chamadas'),
    name: 'jrc_calls_center',
    component: JrcCallsCenter,
    meta,
  },
];
