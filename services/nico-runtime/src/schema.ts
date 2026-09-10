export const analysisSchema = {
  type: 'object', additionalProperties: false,
  required: ['summary', 'suggested_reply', 'evidence', 'warnings'],
  properties: {
    summary: { type: 'string' }, suggested_reply: { type: 'string' },
    evidence: { type: 'array', items: {
      type: 'object', additionalProperties: false, required: ['source', 'reference'],
      properties: { source: { type: 'string', enum: ['conversation', 'crm', 'knowledge', 'erp'] }, reference: { type: 'string' } },
    } },
    warnings: { type: 'array', items: { type: 'string' } },
  },
};
