/* global axios */
const proposalUrl = (accountId, token) =>
  `/api/v1/accounts/${accountId}/crm/public/proposals/${token}`;

export default {
  show: (accountId, token) => axios.get(proposalUrl(accountId, token)),
  recordView: (accountId, token) =>
    axios.post(`${proposalUrl(accountId, token)}/view`),
  accept: (accountId, token, payload) =>
    axios.post(`${proposalUrl(accountId, token)}/accept`, payload),
  reject: (accountId, token, reason) =>
    axios.post(`${proposalUrl(accountId, token)}/reject`, { reason }),
};
