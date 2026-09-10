/* global axios */
import ApiClient from '../ApiClient';

const rankingAPI = new ApiClient('crm/ranking', { accountScoped: true });
rankingAPI.list = params => axios.get(rankingAPI.url, { params });

export default rankingAPI;
