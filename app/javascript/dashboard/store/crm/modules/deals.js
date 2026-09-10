/* eslint-disable no-console */

import { dealsAPI, stagesAPI } from '../../../api/crm';

export default {
  namespaced: true,

  state: {
    deals: [],
    currentDeal: null,
    filters: {},
    isLoading: false,
    pagination: {},
    kanbanColumns: [],
    error: null,
  },

  getters: {
    allDeals: state => state.deals,
    currentDeal: state => state.currentDeal,

    dealById: state => id =>
      state.deals.find(deal => Number(deal.id) === Number(id)),

    dealsByStage: state => {
      return state.kanbanColumns.map(col => ({
        stage: col,
        deals: state.deals.filter(
          deal => Number(deal.stage_id) === Number(col.id)
        ),
      }));
    },

    openDeals: state => state.deals.filter(deal => deal.status === 'open'),

    overdue: state =>
      state.deals.filter(deal => deal.overdue || deal.is_overdue),

    isLoading: state => state.isLoading,
    error: state => state.error,
  },

  mutations: {
    SET_DEALS(state, payload) {
      state.deals = Array.isArray(payload) ? payload : [];
    },

    SET_CURRENT_DEAL(state, payload) {
      state.currentDeal = payload;

      if (!payload?.id) return;

      const index = state.deals.findIndex(
        deal => Number(deal.id) === Number(payload.id)
      );

      if (index !== -1) {
        state.deals.splice(index, 1, {
          ...state.deals[index],
          ...payload,
        });
      }
    },

    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },

    SET_ERROR(state, payload) {
      state.error = payload;
    },

    SET_FILTERS(state, payload) {
      state.filters = payload;
    },

    UPDATE_DEAL_STAGE(state, { dealId, stageId }) {
      const deal = state.deals.find(
        item => Number(item.id) === Number(dealId)
      );

      if (deal) {
        deal.stage_id = stageId;

        if (deal.stage) {
          deal.stage.id = stageId;
        }
      }

      if (
        state.currentDeal &&
        Number(state.currentDeal.id) === Number(dealId)
      ) {
        state.currentDeal.stage_id = stageId;
      }
    },

    ROLLBACK_DEAL_STAGE(state, { dealId, stageId }) {
      const deal = state.deals.find(
        item => Number(item.id) === Number(dealId)
      );

      if (deal) {
        deal.stage_id = stageId;

        if (deal.stage) {
          deal.stage.id = stageId;
        }
      }

      if (
        state.currentDeal &&
        Number(state.currentDeal.id) === Number(dealId)
      ) {
        state.currentDeal.stage_id = stageId;
      }
    },

    SET_KANBAN_COLUMNS(state, payload) {
      state.kanbanColumns = Array.isArray(payload) ? payload : [];
    },
  },

  actions: {
    async fetchDeals({ commit }, params = {}) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);

      try {
        const response = await dealsAPI.list(params);

        const payload = response.data?.payload || response.data;

        console.log(
          'JRC CRM DEALS API COMPLETO:',
          JSON.stringify(payload, null, 2)
        );

        commit('SET_DEALS', payload);
      } catch (error) {
        console.error('Erro ao carregar negócios:', error);

        commit(
          'SET_ERROR',
          error.response?.data?.error ||
          'Não foi possível carregar os negócios.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },

    async fetchDeal({ commit }, id) {
      if (!id) {
        commit('SET_CURRENT_DEAL', null);
        return;
      }

      commit('SET_LOADING', true);
      commit('SET_ERROR', null);

      try {
        const response = await dealsAPI.show(id);

        const payload = response.data?.payload || response.data;

        console.log(
          'JRC CRM DEAL INDIVIDUAL:',
          JSON.stringify(payload, null, 2)
        );

        commit('SET_CURRENT_DEAL', payload);
      } catch (error) {
        console.error('Erro ao carregar negócio:', error);

        commit(
          'SET_ERROR',
          error.response?.data?.error ||
          'Não foi possível carregar o negócio.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },

    async moveStage(_, { dealId, stageId, lostReasonId = null }) {
      await dealsAPI.moveStage(dealId, {
        stage_id: stageId,
        lost_reason_id: lostReasonId,
      });
    },

    async fetchKanbanData({ commit, dispatch }, filters = {}) {
      commit('SET_FILTERS', filters);

      const pipelineId = filters.pipeline_id || filters.pipelineId;

      if (!pipelineId) {
        commit('SET_KANBAN_COLUMNS', []);
        return;
      }

      commit('SET_LOADING', true);
      commit('SET_ERROR', null);

      try {
        const [stagesResponse] = await Promise.all([
          stagesAPI.list({
            pipeline_id: pipelineId,
          }),

          dispatch('fetchDeals', {
            ...filters,
            pipeline_id: pipelineId,
          }),
        ]);

        const stagesPayload =
          stagesResponse.data?.payload || stagesResponse.data;

        commit('SET_KANBAN_COLUMNS', stagesPayload);
      } catch (error) {
        console.error('Erro ao carregar funil:', error);

        commit(
          'SET_ERROR',
          error.response?.data?.error ||
          'Não foi possível carregar o funil.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};