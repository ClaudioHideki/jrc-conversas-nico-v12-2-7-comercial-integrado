const active = run => ['queued', 'running'].includes(run?.status);

export const createNicoRunSession = (
  api,
  accountId,
  conversationId,
  update
) => {
  let disposed = false;
  let timer;
  let current;
  let request;
  let controller = new AbortController();

  const publish = value => {
    if (disposed) return;
    current = value;
    update(value);
  };
  const reportError = () => {
    if (!disposed) update({ ...current, network_error: true });
  };
  const poll = () => {
    clearTimeout(timer);
    if (disposed || !active(current)) return;
    timer = setTimeout(async () => {
      try {
        const { data } = await api.show(
          accountId,
          current.id,
          controller.signal
        );
        publish(data);
        poll();
      } catch {
        reportError();
      }
    }, 750);
  };

  return {
    async load() {
      try {
        const { data } = await api.index(
          accountId,
          conversationId,
          controller.signal
        );
        publish(data[0] || null);
        poll();
      } catch {
        reportError();
      }
    },
    async start(message, agentKey = 'nico') {
      if (disposed || active(current)) return;
      if (
        !request ||
        request.message !== message ||
        request.agent_key !== agentKey
      ) {
        request = {
          message,
          agent_key: agentKey,
          conversation_id: conversationId,
          request_id: crypto.randomUUID(),
        };
      }
      try {
        const { data } = await api.create(
          accountId,
          request,
          controller.signal
        );
        if (disposed) return;
        request = null;
        publish(data);
        poll();
      } catch {
        reportError();
      }
    },
    async cancel() {
      if (disposed || !current?.id) return;
      clearTimeout(timer);
      try {
        const { data } = await api.cancel(
          accountId,
          current.id,
          controller.signal
        );
        publish(data);
      } catch {
        reportError();
      }
    },
    dispose() {
      disposed = true;
      clearTimeout(timer);
      controller.abort();
      controller = null;
    },
  };
};
