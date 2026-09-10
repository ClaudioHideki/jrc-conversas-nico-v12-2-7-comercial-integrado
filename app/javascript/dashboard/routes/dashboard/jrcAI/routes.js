import { frontendURL } from 'dashboard/helper/URLHelper';

const JrcAiAgentsPage = () => import('./JrcAiAgentsPage.vue');
const JrcAiInsightsPage = () => import('./JrcAiInsightsPage.vue');
const JrcAiSettingsPage = () => import('./JrcAiSettingsPage.vue');

const commonMeta = { permissions: ['administrator', 'agent', 'custom_role'] };
const adminMeta = { permissions: ['administrator'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/inteligencia/agentes'),
    name: 'jrc_ai_agents',
    component: JrcAiAgentsPage,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/insights'),
    name: 'jrc_ai_insights',
    component: JrcAiInsightsPage,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/configuracoes'),
    name: 'jrc_ai_settings',
    component: JrcAiSettingsPage,
    props: { initialTab: 'security' },
    meta: adminMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/provedores'),
    name: 'jrc_ai_providers',
    component: JrcAiSettingsPage,
    props: { initialTab: 'providers' },
    meta: adminMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/modelos'),
    name: 'jrc_ai_models',
    component: JrcAiSettingsPage,
    props: { initialTab: 'models' },
    meta: adminMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/consumo'),
    name: 'jrc_ai_usage',
    component: JrcAiSettingsPage,
    props: { initialTab: 'usage' },
    meta: adminMeta,
  },
  {
    path: frontendURL('accounts/:accountId/inteligencia/logs'),
    name: 'jrc_ai_logs',
    component: JrcAiSettingsPage,
    props: { initialTab: 'logs' },
    meta: adminMeta,
  },
];
