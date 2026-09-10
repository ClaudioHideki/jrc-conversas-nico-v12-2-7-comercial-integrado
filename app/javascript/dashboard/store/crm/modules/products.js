/* eslint-disable no-console */
import { productsAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    products: [],
    filters: {},
    isLoading: false,
    pagination: {},
  },
  getters: {
    allProducts: state => state.products,
    isLoading: state => state.isLoading,
  },
  mutations: {
    SET_PRODUCTS(state, payload) {
      state.products = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
  },
  actions: {
    async fetchProducts({ commit }, params) {
      commit('SET_LOADING', true);
      try {
        const response = await productsAPI.list(params);
        commit('SET_PRODUCTS', response.data);
      } catch (error) {
        console.error(error);
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
