/* global axios */
import ApiClient from '../ApiClient';

const reportsAPI = new ApiClient('crm/reports', { accountScoped: true });
reportsAPI.list = params => axios.get(reportsAPI.url, { params });

export default reportsAPI;
