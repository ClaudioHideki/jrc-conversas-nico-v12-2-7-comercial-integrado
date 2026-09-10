/* global axios */

import ApiClient from './ApiClient';

class VideoConferenceSettingsAPI extends ApiClient {
  constructor() {
    super('video_conference_settings', { accountScoped: true });
  }

  getMine() {
    return axios.get(`${this.url}/me`);
  }

  getFreshMine() {
    return axios.get(`${this.url}/me`, { params: { _t: Date.now() } });
  }
}

export default new VideoConferenceSettingsAPI();
