/* eslint-disable no-console */
import { activitiesAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    activities: [],
    filters: {},
    isLoading: false,
    pagination: {},
    error: null,
  },
  getters: {
    allActivities: state => state.activities,
    isLoading: state => state.isLoading,
    error: state => state.error,
  },
  mutations: {
    SET_ACTIVITIES(state, payload) {
      state.activities = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
    SET_ERROR(state, payload) {
      state.error = payload;
    },
  },
  actions: {
    async fetchActivities({ commit }, params) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await activitiesAPI.list(params);
        commit('SET_ACTIVITIES', response.data);
      } catch (error) {
        console.error(error);
        commit(
          'SET_ERROR',
          error.response?.data?.error ||
            'Não foi possível carregar as atividades.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
