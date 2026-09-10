/* global axios */
import ApiClient from '../ApiClient';

const activitiesAPI = new ApiClient('crm/activities', { accountScoped: true });
activitiesAPI.list = params => axios.get(activitiesAPI.url, { params });
activitiesAPI.complete = id =>
  axios.post(`${activitiesAPI.url}/${id}/complete`);

export default activitiesAPI;
