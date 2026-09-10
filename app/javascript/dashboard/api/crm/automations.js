/* global axios */
import ApiClient from '../ApiClient';

const automationsAPI = new ApiClient('crm/automations', {
  accountScoped: true,
});
automationsAPI.toggleActive = id =>
  axios.post(`${automationsAPI.url}/${id}/toggle_active`);

export default automationsAPI;
