/* global axios */

const base = accountId =>
  `/api/v1/accounts/${Number(accountId)}/jrc_nico/proposals`;
export default {
  create: (accountId, data, signal) =>
    axios.post(base(accountId), data, { signal }),
  approve: (accountId, id, digest, signal) =>
    axios.post(`${base(accountId)}/${id}/approve`, { digest }, { signal }),
};
