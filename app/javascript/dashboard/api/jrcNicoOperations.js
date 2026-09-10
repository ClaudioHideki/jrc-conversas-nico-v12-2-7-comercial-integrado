/* global axios */
const base = accountId =>
  `/api/v1/accounts/${Number(accountId)}/jrc_nico/operations`;
export default {
  show: (id, signal) => axios.get(base(id), { signal }),
  notices: (id, signal) => axios.get(`${base(id)}/notices`, { signal }),
  readNotice: (id, noticeId) =>
    axios.post(`${base(id)}/notices/${noticeId}/read`),
  retryNotice: (id, noticeId) =>
    axios.post(`${base(id)}/notices/${noticeId}/retry`),
  conversations: id => axios.get(`${base(id)}/conversations`),
  ask: (id, input) => axios.post(`${base(id)}/ask`, input),
  transcribe: (id, audio, signal) => {
    const form = new FormData();
    form.append('audio', audio, 'command');
    return axios.post(`${base(id)}/transcribe`, form, { signal });
  },
  prepare: (id, input) => axios.post(`${base(id)}/prepare`, input),
  command: (id, commandId, action, input = {}) =>
    axios.post(`${base(id)}/commands/${commandId}/${action}`, input),
  takeover: (id, conversationId) =>
    axios.post(`${base(id)}/takeover`, { conversation_id: conversationId }),
};
