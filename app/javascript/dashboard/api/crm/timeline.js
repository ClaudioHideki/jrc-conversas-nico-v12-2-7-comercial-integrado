import ApiClient from '../ApiClient';

const timelineAPI = new ApiClient('crm/timeline', { accountScoped: true });

export default timelineAPI;
