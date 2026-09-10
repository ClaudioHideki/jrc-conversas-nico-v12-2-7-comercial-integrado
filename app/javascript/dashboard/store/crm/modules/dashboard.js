/* eslint-disable no-console */
import { dashboardAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    metrics: {},
    isLoading: false,
  },
  getters: {
    metrics: state => state.metrics,
    isLoading: state => state.isLoading,
  },
  mutations: {
    SET_METRICS(state, payload) {
      state.metrics = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
  },
  actions: {
    async fetchMetrics({ commit }, params) {
      commit('SET_LOADING', true);
      try {
        const response = await dashboardAPI.metrics(params);
        commit('SET_METRICS', response.data);
      } catch (error) {
        console.error(error);
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
