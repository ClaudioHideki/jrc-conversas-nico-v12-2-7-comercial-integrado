/* global axios */
import ApiClient from '../ApiClient';

const lostReasonsAPI = new ApiClient('crm/lost_reasons', {
  accountScoped: true,
});
lostReasonsAPI.list = () => axios.get(lostReasonsAPI.url);

export default lostReasonsAPI;
