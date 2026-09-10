import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import { isOnOnboardingView } from 'v3/helpers/RouteHelper';
import AnalyticsHelper from '../helper/AnalyticsHelper';
import types from 'dashboard/store/mutation-types';

const ONBOARDING_STEPS = ['account_details', 'enrichment', 'inbox_setup'];
const routes = [...dashboard.routes];
const SUPER_ADMIN_INBOX_ROUTE_MAP = {
  settings_inbox_list: 'super_admin_settings_inbox_list',
  settings_inbox_new: 'super_admin_settings_inbox_new',
  settings_inbox_finish: 'super_admin_settings_inbox_finish',
  settings_inboxes_page_channel: 'super_admin_settings_inboxes_page_channel',
  settings_inboxes_add_agents: 'super_admin_settings_inboxes_add_agents',
  settings_inbox_show: 'super_admin_settings_inbox_show',
  inbox_dashboard: 'super_admin_settings_inbox_show',
  assignment_policy_index: 'super_admin_assignment_policy_index',
  agent_assignment_policy_index: 'super_admin_agent_assignment_policy_index',
  agent_assignment_policy_create: 'super_admin_agent_assignment_policy_create',
  agent_assignment_policy_edit: 'super_admin_agent_assignment_policy_edit',
};

const onboardingPath = step =>
  step === 'inbox_setup' ? 'onboarding/inbox-setup' : 'onboarding';

export const router = createRouter({ history: createWebHistory(), routes });

const isSuperAdminAccountRoute = route =>
  route.path?.startsWith('/super_admin/accounts') ||
  route.matched?.some(record => record.meta?.superAdminAccountSettings);

const setupSuperAdminAccountContext = route => {
  const accountId = Number(route.params?.accountId);
  const accountConfig = window.globalConfig?.SUPER_ADMIN_ACCOUNT;
  const userConfig = window.globalConfig?.SUPER_ADMIN_USER;

  if (!accountId || !accountConfig) return;

  const account = {
    ...accountConfig,
    id: accountId,
    role: 'administrator',
    permissions: ['administrator'],
    status: accountConfig.status || 'active',
    availability: 'online',
    availability_status: 'online',
  };

  store.commit(types.SET_CURRENT_USER, {
    id: userConfig?.id || -1,
    account_id: accountId,
    accounts: [account],
    email: userConfig?.email,
    name: userConfig?.name || 'Super Admin',
  });
  store.commit(`accounts/${types.ADD_ACCOUNT}`, account);
};

export const validateAuthenticateRoutePermission = async (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  const { accounts = [], account_id: accountId } = user;

  if (!accounts.length) {
    if (to.name === 'no_accounts') {
      return next();
    }
    return next(frontendURL('no-accounts'));
  }

  const routeAccountId = Number(to.params?.accountId || accountId);
  const userAccount = accounts.find(a => a.id === routeAccountId);
  const isAdmin = userAccount?.role === 'administrator';
  const isActive = userAccount?.status === 'active';
  const needsOnboarding =
    ONBOARDING_STEPS.includes(userAccount?.onboarding_step) &&
    isAdmin &&
    isActive;

  if (to.name === 'no_accounts' || !to.name) {
    const target = needsOnboarding
      ? onboardingPath(userAccount?.onboarding_step)
      : 'dashboard';
    return next(frontendURL(`accounts/${routeAccountId}/${target}`));
  }

  if (needsOnboarding && !isOnOnboardingView(to)) {
    return next(
      frontendURL(
        `accounts/${routeAccountId}/${onboardingPath(userAccount?.onboarding_step)}`
      )
    );
  }
  if (!needsOnboarding && isOnOnboardingView(to)) {
    return next(frontendURL(`accounts/${routeAccountId}/dashboard`));
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach(async (to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    await userAuthentication;

    if (
      isSuperAdminAccountRoute(_from) &&
      SUPER_ADMIN_INBOX_ROUTE_MAP[to.name]
    ) {
      return next({
        name: SUPER_ADMIN_INBOX_ROUTE_MAP[to.name],
        params: to.params,
        query: to.query,
      });
    }

    if (isSuperAdminAccountRoute(to)) {
      setupSuperAdminAccountContext(to);
      return next();
    }

    await validateAuthenticateRoutePermission(to, next, store);
  });
};

export default router;
