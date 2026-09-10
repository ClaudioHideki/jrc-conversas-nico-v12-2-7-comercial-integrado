/* global axios */
import ApiClient from './ApiClient';

class WhatsappCallingConfigurationAPI extends ApiClient {
  constructor() {
    super('whatsapp_calling_configuration', { accountScoped: true });
  }

  get() {
    return axios.get(this.url).then(response => response.data);
  }
}

export default new WhatsappCallingConfigurationAPI();
