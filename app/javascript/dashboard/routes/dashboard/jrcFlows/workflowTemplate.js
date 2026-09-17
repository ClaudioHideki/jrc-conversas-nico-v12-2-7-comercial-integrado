export function workflowTemplate(name) {
  return {
    name,
    nodes: [
      {
        id: 'entry',
        name: 'Entrada JRC',
        type: 'n8n-nodes-base.webhook',
        typeVersion: 2,
        position: [60, 160],
        parameters: {
          httpMethod: 'POST',
          path: 'entrada-jrc',
          responseMode: 'responseNode',
        },
      },
      {
        id: 'code',
        name: 'Preparar resposta',
        type: 'n8n-nodes-base.code',
        typeVersion: 2,
        position: [420, 160],
        parameters: {
          jsCode:
            'const entrada = $input.first().json.body;\nreturn [{ json: { messages: ["Olá! Recebi sua mensagem: " + entrada.mensagem], close: false } }];',
        },
      },
      {
        id: 'reply',
        name: 'Responder ao cliente',
        type: 'n8n-nodes-base.respondToWebhook',
        typeVersion: 1,
        position: [780, 160],
        parameters: { respondWith: 'json', responseBody: '={{ $json }}' },
      },
    ],
    connections: {
      'Entrada JRC': {
        main: [[{ node: 'Preparar resposta', type: 'main', index: 0 }]],
      },
      'Preparar resposta': {
        main: [[{ node: 'Responder ao cliente', type: 'main', index: 0 }]],
      },
    },
    settings: { executionOrder: 'v1' },
    active: false,
  };
}
