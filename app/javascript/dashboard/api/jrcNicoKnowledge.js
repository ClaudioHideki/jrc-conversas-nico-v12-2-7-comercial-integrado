/* global axios */

const base = accountId =>
  `/api/v1/accounts/${Number(accountId)}/jrc_nico/knowledge_documents`;
export default {
  index: (accountId, signal) => axios.get(base(accountId), { signal }),
  create: (accountId, data, signal) =>
    axios.post(base(accountId), data, { signal }),
  update: (accountId, id, data, signal) =>
    axios.patch(`${base(accountId)}/${id}`, data, { signal }),
  approve: (accountId, id, digest, signal) =>
    axios.post(`${base(accountId)}/${id}/approve`, { digest }, { signal }),
};
