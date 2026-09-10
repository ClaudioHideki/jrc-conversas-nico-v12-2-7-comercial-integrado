/* global axios */

import ApiClient from './ApiClient';

class SipCredentialsAPI extends ApiClient {
  constructor() {
    super('sip_credentials', { accountScoped: true });
  }

  getMine() {
    return axios.get(`${this.url}/me`);
  }

  saveForAgent(userId, sipCredential) {
    return axios.patch(`${this.url}/${userId}`, {
      sip_credential: sipCredential,
    });
  }

  removeFromAgent(userId) {
    return axios.delete(`${this.url}/${userId}`);
  }
}

export default new SipCredentialsAPI();
