import deals from './modules/deals';
import leads from './modules/leads';
import pipelines from './modules/pipelines';
import activities from './modules/activities';
import products from './modules/products';
import proposals from './modules/proposals';
import dashboard from './modules/dashboard';

export default {
  namespaced: true,
  modules: {
    deals,
    leads,
    pipelines,
    activities,
    products,
    proposals,
    dashboard,
  },
};
