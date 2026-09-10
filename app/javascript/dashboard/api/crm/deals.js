/* global axios */
import ApiClient from '../ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('crm/deals', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  moveStage(id, params) {
    return axios.post(`${this.url}/${id}/move_stage`, params);
  }

  win(id) {
    return axios.post(`${this.url}/${id}/win`);
  }

  lose(id, params) {
    return axios.post(`${this.url}/${id}/lose`, params);
  }

  listProducts(id) {
    return axios.get(`${this.url}/${id}/products`);
  }

  createProduct(id, data) {
    return axios.post(`${this.url}/${id}/products`, data);
  }

  updateProduct(id, itemId, data) {
    return axios.patch(`${this.url}/${id}/products/${itemId}`, data);
  }

  deleteProduct(id, itemId) {
    return axios.delete(`${this.url}/${id}/products/${itemId}`);
  }
}

export default new DealsAPI();
