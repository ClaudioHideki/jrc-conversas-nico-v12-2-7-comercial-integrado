/* global axios */
import ApiClient from './ApiClient';

class SalesAPI extends ApiClient {
  constructor() {
    super('sales', { accountScoped: true });
  }

  pipeline() {
    return axios.get(`${this.url}/pipeline`);
  }

  opportunities(params = {}) {
    return axios.get(`${this.url}/opportunities`, { params });
  }

  opportunity(id) {
    return axios.get(`${this.url}/opportunities/${id}`);
  }

  createOpportunity(opportunity) {
    return axios.post(`${this.url}/opportunities`, { opportunity });
  }

  updateOpportunity(id, opportunity) {
    return axios.patch(`${this.url}/opportunities/${id}`, { opportunity });
  }

  moveOpportunity(id, opportunity) {
    return axios.patch(`${this.url}/opportunities/${id}/move`, {
      opportunity,
    });
  }

  archiveOpportunity(id) {
    return axios.patch(`${this.url}/opportunities/${id}/archive`);
  }

  createActivity(opportunityId, activity) {
    return axios.post(`${this.url}/opportunities/${opportunityId}/activities`, {
      activity,
    });
  }

  updateActivity(id, activity) {
    return axios.patch(`${this.url}/activities/${id}`, { activity });
  }

  summary() {
    return axios.get(`${this.url}/summary`);
  }

  metadata() {
    return axios.get(`${this.url}/metadata`);
  }
}

export default new SalesAPI();
