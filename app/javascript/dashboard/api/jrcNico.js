/* global axios */

const base = accountId => `/api/v1/accounts/${Number(accountId)}/jrc_nico/runs`;

export default {
  assistance: (accountId, conversationId, signal) =>
    axios.get(`/api/v1/accounts/${Number(accountId)}/jrc_nico/assistance`, {
      params: { conversation_id: conversationId },
      signal,
    }),
  authorize: (accountId, conversationId, input, signal) =>
    axios.post(
      `/api/v1/accounts/${Number(accountId)}/jrc_nico/assistance/authorize`,
      input,
      {
        params: { conversation_id: conversationId },
        signal,
      }
    ),
  dismiss: (accountId, conversationId, signal) =>
    axios.post(
      `/api/v1/accounts/${Number(accountId)}/jrc_nico/assistance/dismiss`,
      {},
      {
        params: { conversation_id: conversationId },
        signal,
      }
    ),
  agents: (accountId, signal) =>
    axios.get(`/api/v1/accounts/${Number(accountId)}/jrc_nico/agents`, {
      signal,
    }),
  index: (accountId, conversationId, signal) =>
    axios.get(base(accountId), {
      params: { conversation_id: conversationId },
      signal,
    }),
  create: (accountId, input, signal) =>
    axios.post(base(accountId), input, { signal }),
  show: (accountId, id, signal) =>
    axios.get(`${base(accountId)}/${id}`, { signal }),
  cancel: (accountId, id, signal) =>
    axios.post(`${base(accountId)}/${id}/cancel`, {}, { signal }),
};
