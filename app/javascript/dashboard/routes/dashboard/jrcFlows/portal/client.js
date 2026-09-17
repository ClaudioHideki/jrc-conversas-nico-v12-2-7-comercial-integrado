// Tokens stay in memory, never in the iframe URL, localStorage or postMessage.
export function makeClient(headers) {
  return async (path, method = 'GET', body = undefined) => {
    const response = await fetch(path, {
      method,
      credentials: 'omit',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...headers,
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    ['access-token', 'client', 'uid', 'token-type'].forEach(key => {
      const value = response.headers.get(key);
      if (value) headers[key] = value;
    });
    const data = response.status === 204 ? {} : await response.json();
    if (!response.ok) {
      const error = new Error(
        data.error ||
          data.message ||
          data.errors?.join?.(' ') ||
          `HTTP ${response.status}`
      );
      error.response = { status: response.status, data };
      throw error;
    }
    return { data };
  };
}

export function flowsClient(request, accountId, connectionId) {
  const base = `/api/v1/accounts/${accountId}/jrc_flow_connections/${connectionId}/flows`;
  return {
    get: () => request(base),
    show: id => request(`${base}/${id}`),
    create: data => request(base, 'POST', data),
    update: (id, data) => request(`${base}/${id}`, 'PATCH', data),
    delete: id => request(`${base}/${id}`, 'DELETE'),
    metadata: () => request(`${base}/metadata`),
    importPreview: data => request(`${base}/import_preview`, 'POST', data),
    importDefinition: data =>
      request(`${base}/import_definition`, 'POST', data),
    exportDefinition: (id, original) =>
      request(`${base}/${id}/export_definition?original=${!!original}`),
    action: (id, action, data = {}) =>
      request(`${base}/${id}/${action}`, 'POST', data),
    runs: (id, before) =>
      request(`${base}/${id}/runs${before ? `?before=${before}` : ''}`),
  };
}
