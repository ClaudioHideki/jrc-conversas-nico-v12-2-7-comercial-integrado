import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import store from 'dashboard/store';

const JrcCampaignsPage = () => import('./JrcCampaignsAccountPage.vue');

const meta = {
  featureFlag: FEATURE_FLAGS.JRC_CAMPAIGNS,
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/jrc-campanhas'),
    name: 'jrc_campaigns_index',
    component: JrcCampaignsPage,
    meta,
    beforeEnter: async to => {
      await store.dispatch('accounts/get', { silent: true });
      const enabled = store.getters['accounts/isFeatureEnabledonAccount'](
        Number(to.params.accountId),
        FEATURE_FLAGS.JRC_CAMPAIGNS
      );
      return enabled
        ? true
        : frontendURL(`accounts/${to.params.accountId}/dashboard`);
    },
  },
];
