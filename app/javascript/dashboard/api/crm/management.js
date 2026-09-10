import ApiClient from '../ApiClient';

const managementAPI = new ApiClient('crm/management', { accountScoped: true });

export default managementAPI;
