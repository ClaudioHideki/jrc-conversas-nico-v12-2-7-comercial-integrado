/* global axios */

import ApiClient from './ApiClient';

class CallQualityAnalysesAPI extends ApiClient {
  constructor() {
    super('call_quality_analyses', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  analyze(call) {
    return axios.post(this.url, { call });
  }
}

export default new CallQualityAnalysesAPI();
