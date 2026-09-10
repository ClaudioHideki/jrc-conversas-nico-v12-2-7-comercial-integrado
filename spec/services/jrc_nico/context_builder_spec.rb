require 'rails_helper'

RSpec.describe JrcNico::ContextBuilder do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }

  it 'includes only the chosen conversation public messages and approved account knowledge' do
    message = create(:message, account: account, conversation: conversation, content: 'Preciso de implantação', private: false)
    create(:message, account: account, conversation: conversation, content: 'Nota interna confidencial', private: true)
    other = create(:conversation, account: account)
    create(:message, account: account, conversation: other, content: 'Outra conversa')
    JrcNico::KnowledgeDocument.create!(account: account, author: admin, approved_by: admin, title: 'Implantação', body: 'Checklist de implantação', approved_at: Time.current)
    JrcNico::KnowledgeDocument.create!(account: account, author: admin, title: 'Implantação não revisada', body: 'Rascunho')
    context = described_class.new(account: account, user: admin, conversation: conversation).build('implantação')
    expect(context[:conversation].map { |item| item[:reference] }).to eq(["message:#{message.id}"])
    expect(context[:knowledge].length).to eq(1)
    expect(context.to_json).not_to include('Nota interna', 'Outra conversa', 'Rascunho')
  end

  it 'rechecks membership rather than trusting an earlier request' do
    account.account_users.find_by!(user_id: admin.id).destroy!
    expect { described_class.new(account: account, user: admin, conversation: conversation).build('resumo') }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'denies a conversation from another account even for an administrator' do
    other = create(:conversation)
    expect { described_class.new(account: account, user: admin, conversation: other).build('resumo') }.to raise_error(Pundit::NotAuthorizedError)
  end
end
