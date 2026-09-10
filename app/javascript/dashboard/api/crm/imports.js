/* global axios */
import ApiClient from '../ApiClient';

const importsAPI = new ApiClient('crm/imports', { accountScoped: true });
importsAPI.upload = data =>
  axios.post(importsAPI.url, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

export default importsAPI;
