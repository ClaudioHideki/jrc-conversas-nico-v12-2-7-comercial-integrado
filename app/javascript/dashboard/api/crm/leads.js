/* global axios */
import ApiClient from '../ApiClient';

const leadsAPI = new ApiClient('crm/leads', { accountScoped: true });
leadsAPI.list = params => axios.get(leadsAPI.url, { params });

leadsAPI.convert = (id, params) =>
  axios.post(`${leadsAPI.url}/${id}/convert`, params);
leadsAPI.lose = (id, params) =>
  axios.post(`${leadsAPI.url}/${id}/lose`, params);
leadsAPI.fromConversation = conversationId =>
  axios.post(`${leadsAPI.url}/from_conversation`, {
    conversation_id: conversationId,
  });

export default leadsAPI;
