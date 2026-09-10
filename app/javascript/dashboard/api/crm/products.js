/* global axios */
import ApiClient from '../ApiClient';

const productsAPI = new ApiClient('crm/products', { accountScoped: true });
productsAPI.list = params => axios.get(productsAPI.url, { params });
productsAPI.toggleActive = id =>
  axios.patch(`${productsAPI.url}/${id}/toggle_active`);

export default productsAPI;
