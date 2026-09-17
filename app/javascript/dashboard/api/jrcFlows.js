/* global axios */
import ApiClient from './ApiClient';

class JrcFlowsAPI extends ApiClient {
  constructor() {
    super('jrc_flows', { accountScoped: true });
  }

  importPreview(data) {
    return axios.post(`${this.url}/import_preview`, data);
  }

  importDefinition(data) {
    return axios.post(`${this.url}/import_definition`, data);
  }

  exportDefinition(id, original) {
    return axios.get(`${this.url}/${id}/export_definition`, {
      params: { original },
    });
  }

  metadata() {
    return axios.get(`${this.url}/metadata`);
  }

  action(id, action, data = {}) {
    return axios.post(`${this.url}/${id}/${action}`, data);
  }

  runs(id, before) {
    return axios.get(`${this.url}/${id}/runs`, { params: { before } });
  }
}

export default new JrcFlowsAPI();
