import ApiClient from '../ApiClient';

const walletAPI = new ApiClient('crm/wallet', { accountScoped: true });

export default walletAPI;
