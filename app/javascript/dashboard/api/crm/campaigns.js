import ApiClient from '../ApiClient';

const campaignsAPI = new ApiClient('crm/campaigns', { accountScoped: true });

export default campaignsAPI;
