/* eslint-disable no-console */
import { proposalsAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    proposals: [],
    filters: {},
    isLoading: false,
    pagination: {},
    error: null,
  },
  getters: {
    allProposals: state => state.proposals,
    isLoading: state => state.isLoading,
    error: state => state.error,
  },
  mutations: {
    SET_PROPOSALS(state, payload) {
      state.proposals = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
    SET_ERROR(state, payload) {
      state.error = payload;
    },
  },
  actions: {
    async fetchProposals({ commit }, params) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await proposalsAPI.list(params);
        commit('SET_PROPOSALS', response.data);
      } catch (error) {
        console.error(error);
        commit(
          'SET_ERROR',
          error.response?.data?.error ||
            'Não foi possível carregar as propostas.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
