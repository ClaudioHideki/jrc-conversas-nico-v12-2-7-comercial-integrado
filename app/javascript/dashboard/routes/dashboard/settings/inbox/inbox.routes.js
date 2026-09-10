import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import ChannelFactory from './ChannelFactory.vue';

import SettingsContent from '../Wrapper.vue';
import SettingsWrapper from '../SettingsWrapper.vue';
import InboxHome from './Index.vue';
import Settings from './Settings.vue';
import InboxChannel from './InboxChannels.vue';
import ChannelList from './ChannelList.vue';
import AddAgents from './AddAgents.vue';
import FinishSetup from './FinishSetup.vue';

const inboxRouteMeta = {
  featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
  permissions: ['administrator'],
};

const superAdminRouteMeta = {
  ...inboxRouteMeta,
  superAdminAccountSettings: true,
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/inboxes'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'settings_inbox_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'settings_inbox_list',
          component: InboxHome,
          meta: inboxRouteMeta,
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/inboxes'),
      component: SettingsContent,
      props: params => {
        const showBackButton = params.name !== 'settings_inbox_list';
        const fullWidth = params.name === 'settings_inbox_show';
        return {
          headerTitle: 'INBOX_MGMT.HEADER',
          icon: 'mail-inbox-all',
          showBackButton,
          fullWidth,
        };
      },
      children: [
        {
          path: 'new',
          component: InboxChannel,
          children: [
            {
              path: '',
              name: 'settings_inbox_new',
              component: ChannelList,
              meta: inboxRouteMeta,
            },
            {
              path: ':inbox_id/finish',
              name: 'settings_inbox_finish',
              component: FinishSetup,
              meta: inboxRouteMeta,
            },
            {
              path: ':sub_page',
              name: 'settings_inboxes_page_channel',
              component: ChannelFactory,
              meta: inboxRouteMeta,
              props: route => {
                return { channelName: route.params.sub_page };
              },
            },
            {
              path: ':inbox_id/agents',
              name: 'settings_inboxes_add_agents',
              meta: inboxRouteMeta,
              component: AddAgents,
            },
          ],
        },
        {
          path: ':inboxId/:tab?',
          name: 'settings_inbox_show',
          component: Settings,
          meta: inboxRouteMeta,
        },
      ],
    },
    {
      path: '/super_admin/accounts/:accountId/settings/inboxes',
      component: SettingsWrapper,
      meta: { superAdminAccountSettings: true },
      children: [
        {
          path: '',
          redirect: to => {
            return {
              name: 'super_admin_settings_inbox_list',
              params: to.params,
            };
          },
        },
        {
          path: 'list',
          name: 'super_admin_settings_inbox_list',
          component: InboxHome,
          meta: superAdminRouteMeta,
        },
      ],
    },
    {
      path: '/super_admin/accounts/:accountId/settings/inboxes',
      component: SettingsContent,
      meta: { superAdminAccountSettings: true },
      props: params => {
        const showBackButton = params.name !== 'super_admin_settings_inbox_list';
        const fullWidth = params.name === 'super_admin_settings_inbox_show';
        return {
          headerTitle: 'INBOX_MGMT.HEADER',
          icon: 'mail-inbox-all',
          showBackButton,
          fullWidth,
        };
      },
      children: [
        {
          path: 'new',
          component: InboxChannel,
          meta: { superAdminAccountSettings: true },
          children: [
            {
              path: '',
              name: 'super_admin_settings_inbox_new',
              component: ChannelList,
              meta: superAdminRouteMeta,
            },
            {
              path: ':inbox_id/finish',
              name: 'super_admin_settings_inbox_finish',
              component: FinishSetup,
              meta: superAdminRouteMeta,
            },
            {
              path: ':sub_page',
              name: 'super_admin_settings_inboxes_page_channel',
              component: ChannelFactory,
              meta: superAdminRouteMeta,
              props: route => {
                return { channelName: route.params.sub_page };
              },
            },
            {
              path: ':inbox_id/agents',
              name: 'super_admin_settings_inboxes_add_agents',
              meta: superAdminRouteMeta,
              component: AddAgents,
            },
          ],
        },
        {
          path: ':inboxId/:tab?',
          name: 'super_admin_settings_inbox_show',
          component: Settings,
          meta: superAdminRouteMeta,
        },
      ],
    },
  ],
};
