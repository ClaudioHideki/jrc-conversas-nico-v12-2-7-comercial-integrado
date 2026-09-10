import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SalesPipelinePage from './SalesPipelinePage.vue';
import store from 'dashboard/store';

const meta = {
  featureFlag: FEATURE_FLAGS.SALES,
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/vendas/pipeline'),
    name: 'sales_pipeline_index',
    component: SalesPipelinePage,
    meta,
    beforeEnter: async to => {
      await store.dispatch('accounts/get', { silent: true });
      const enabled = store.getters['accounts/isFeatureEnabledonAccount'](
        Number(to.params.accountId),
        FEATURE_FLAGS.SALES
      );
      const crmEnabled = store.getters['accounts/isFeatureEnabledonAccount'](
        Number(to.params.accountId),
        FEATURE_FLAGS.JRC_CRM
      );
      if (crmEnabled) {
        return frontendURL(`accounts/${to.params.accountId}/crm/funnel`);
      }
      return enabled
        ? true
        : frontendURL(`accounts/${to.params.accountId}/dashboard`);
    },
  },
];
