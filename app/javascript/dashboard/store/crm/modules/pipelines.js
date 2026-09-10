/* eslint-disable no-console */
import { pipelinesAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    pipelines: [],
    isLoading: false,
  },
  getters: {
    allPipelines: state => state.pipelines,
    isLoading: state => state.isLoading,
  },
  mutations: {
    SET_PIPELINES(state, payload) {
      state.pipelines = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
  },
  actions: {
    async fetchPipelines({ commit }) {
      commit('SET_LOADING', true);
      try {
        const response = await pipelinesAPI.list();
        commit('SET_PIPELINES', response.data);
      } catch (error) {
        console.error(error);
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
