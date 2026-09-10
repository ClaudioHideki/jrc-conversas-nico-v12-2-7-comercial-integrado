/* global axios */
import ApiClient from './ApiClient';

class JrcCopilotAPI extends ApiClient {
  constructor() {
    super('jrc_copilot', { accountScoped: true });
  }

  ask(payload) {
    return axios.post(`${this.url}/ask`, payload);
  }

  context(routeName) {
    return axios.get(`${this.url}/context`, {
      params: { route_name: routeName },
    });
  }
}

export default new JrcCopilotAPI();
