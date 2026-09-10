/* global axios */
import ApiClient from '../ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new PipelinesAPI();
