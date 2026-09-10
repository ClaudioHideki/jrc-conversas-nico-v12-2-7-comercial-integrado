/* global axios */

import ApiClient from './ApiClient';

class CallHistoryAPI extends ApiClient {
  constructor() {
    super('call_history', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new CallHistoryAPI();
