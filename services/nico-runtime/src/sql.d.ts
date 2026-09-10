declare module '@elizaos/plugin-sql' {
  import type { IDatabaseAdapter, Plugin, UUID } from '@elizaos/core';
  type SqlAdapter = IDatabaseAdapter & {
    runPluginMigrations(plugins: { name: string; schema: unknown }[], options: { force: boolean }): Promise<void>;
  };
  export function createDatabaseAdapter(config: { postgresUrl?: string; dataDir?: string }, agentId: UUID): SqlAdapter;
  const sqlPlugin: Plugin & { schema: unknown };
  export default sqlPlugin;
}
