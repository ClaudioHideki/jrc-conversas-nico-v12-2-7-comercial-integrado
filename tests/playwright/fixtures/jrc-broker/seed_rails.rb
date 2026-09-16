# Run with rails runner only against the disposable contract database.
abort('ISOLATED_TEST_REQUIRED') unless Rails.env.test? && ENV['CONTRACT_TEST_ONLY'] == 'true' &&
                                       ActiveRecord::Base.connection_db_config.database == 'jrc_broker_native_test'

require 'json'
path = '/contract/rails-fixture.json'
abort('FIXTURE_ALREADY_EXISTS') if File.exist?(path)
password = "Synthetic!#{SecureRandom.hex(16)}"
account = Account.create!(name: 'Synthetic Broker contract', locale: 'en')
account.enable_features!('jrc_broker')
admin = User.new(name: 'Synthetic Administrator', email: "admin-#{SecureRandom.hex(6)}@example.test", password: password)
admin.skip_confirmation!
admin.save!
AccountUser.create!(account: account, user: admin, role: :administrator)
agent = User.new(name: 'Synthetic Agent', email: "agent-#{SecureRandom.hex(6)}@example.test", password: password)
agent.skip_confirmation!
agent.save!
AccountUser.create!(account: account, user: agent, role: :agent)
other = Account.create!(name: 'Synthetic second tenant', locale: 'en')
other.enable_features!('jrc_broker')
AccountUser.create!(account: other, user: admin, role: :administrator)
File.write(path, JSON.generate(accountId: account.id, otherAccountId: other.id, adminId: admin.id, agentId: agent.id,
                               email: admin.email, agentEmail: agent.email, password: password,
                               chatwootToken: admin.access_token.token))
puts 'Synthetic Rails contract identities created (credentials omitted)'
