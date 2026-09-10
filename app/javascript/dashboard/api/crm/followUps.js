/* global axios */
import ApiClient from '../ApiClient';

const followUpsAPI = new ApiClient('crm/follow_ups', { accountScoped: true });
followUpsAPI.complete = id => axios.post(`${followUpsAPI.url}/${id}/complete`);

export default followUpsAPI;
