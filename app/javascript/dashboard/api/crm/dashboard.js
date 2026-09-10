/* global axios */
import ApiClient from '../ApiClient';

const dashboardAPI = new ApiClient('crm/dashboard', { accountScoped: true });
dashboardAPI.metrics = params => axios.get(dashboardAPI.url, { params });

export default dashboardAPI;
