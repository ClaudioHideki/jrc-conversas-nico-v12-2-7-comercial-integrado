require 'rails_helper'

describe Messages::Facebook::MessageBuilder do
  subject(:message_builder) { described_class.new(incoming_fb_text_message, facebook_channel.inbox).perform }

  before do
    stub_request(:post, /graph.facebook.com/)
  end

  let!(:facebook_channel) { create(:channel_facebook_page) }
  let!(:message_object) { build(:incoming_fb_text_message).to_json }
  let!(:incoming_fb_text_message) { Integrations::Facebook::MessageParser.new(message_object) }
  let(:fb_object) { double }

  describe '#process_contact_params_result' do
    let(:builder) { described_class.new(incoming_fb_text_message, facebook_channel.inbox) }

    it 'uses both available name parts' do
      params = builder.send(:process_contact_params_result, { 'first_name' => 'Thiago', 'last_name' => 'Ribeiro' })
      expect(params[:name]).to eq('Thiago Ribeiro')
    end

    it 'uses only the first name when no last name is returned' do
      params = builder.send(:process_contact_params_result, { 'first_name' => 'Thiago' })
      expect(params[:name]).to eq('Thiago')
    end

    it 'uses only the last name when no first name is returned' do
      params = builder.send(:process_contact_params_result, { 'last_name' => 'Ribeiro' })
      expect(params[:name]).to eq('Ribeiro')
    end

    it 'uses the sender-specific neutral fallback for an empty profile' do
      params = builder.send(:process_contact_params_result, {})
      expect(params[:name]).to eq("Usuário do Facebook #{incoming_fb_text_message.sender_id}")
    end
  end

  describe '#perform' do
    it 'creates contact and message for the facebook inbox' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return(
        {
          first_name: 'Jane',
          last_name: 'Dae',
          account_id: facebook_channel.inbox.account_id,
          profile_pic: 'https://chatwoot-assets.local/sample.png'
        }.with_indifferent_access
      )
      message_builder

      contact = facebook_channel.inbox.contacts.first
      message = facebook_channel.inbox.messages.first

      expect(contact.name).to eq('Jane Dae')
      expect(message.content).to eq('facebook message')
    end

    it 'increments channel authorization_error_count when error is thrown' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::AuthenticationError.new(500, 'Error validating access token'))
      message_builder

      expect(facebook_channel.authorization_error_count).to eq(2)
    end

    it 'creates an identifiable neutral contact when the profile is unavailable' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::ClientError.new(400, '',
                                                                                          {
                                                                                            'type' => 'OAuthException',
                                                                                            'message' => '(#100) No profile available for this user.',
                                                                                            'error_subcode' => 2_018_218,
                                                                                            'code' => 100
                                                                                          }))
      message_builder

      contact = facebook_channel.inbox.contacts.first
      expect(facebook_channel.inbox.reload.contacts.count).to eq(1)
      expect(contact.name).to eq("Usuário do Facebook #{incoming_fb_text_message.sender_id}")
      expect(facebook_channel.inbox.messages.first.content).to eq('facebook message')
    end

    it 'preserves an existing real contact name when a later profile lookup fails' do
      contact = create(:contact, account: facebook_channel.inbox.account, name: 'Thiago Ribeiro')
      create(:contact_inbox, contact: contact, inbox: facebook_channel.inbox, source_id: incoming_fb_text_message.sender_id)
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::ClientError.new(400, '',
                                                                                          {
                                                                                            'type' => 'OAuthException',
                                                                                            'message' => 'Unsupported get request',
                                                                                            'error_subcode' => 33,
                                                                                            'code' => 100
                                                                                          }))

      message_builder

      expect(contact.reload.name).to eq('Thiago Ribeiro')
      expect(facebook_channel.inbox.messages.first.content).to eq('facebook message')
    end

    it 'enriches an existing Facebook fallback when the real profile becomes available' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return({})

      described_class.new(incoming_fb_text_message, facebook_channel.inbox).send(:build_contact_inbox)
      contact = facebook_channel.inbox.contacts.first
      expect(contact.name).to eq("Usuário do Facebook #{incoming_fb_text_message.sender_id}")

      allow(fb_object).to receive(:get_object).and_return(
        { first_name: 'Thiago', last_name: 'Ribeiro' }.with_indifferent_access
      )
      described_class.new(incoming_fb_text_message, facebook_channel.inbox).send(:build_contact_inbox)

      expect(contact.reload.name).to eq('Thiago Ribeiro')
      expect(facebook_channel.inbox.contact_inboxes.where(source_id: incoming_fb_text_message.sender_id).count).to eq(1)
    end

    it 'keeps different Facebook PSIDs in different contacts' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return({})

      %w[psid-111 psid-222].each do |sender_id|
        payload = {
          messaging: {
            sender: { id: sender_id },
            recipient: { id: facebook_channel.page_id },
            message: { mid: "message-#{sender_id}", text: 'Olá' }
          }
        }.to_json
        parser = Integrations::Facebook::MessageParser.new(payload)
        described_class.new(parser, facebook_channel.inbox).send(:build_contact_inbox)
      end

      contact_inboxes = facebook_channel.inbox.contact_inboxes.where(source_id: %w[psid-111 psid-222])
      expect(contact_inboxes.count).to eq(2)
      expect(contact_inboxes.distinct.count(:contact_id)).to eq(2)
    end
  
    it 'marks echo messages as external echo messages' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return(
        {
          first_name: 'Jane',
          last_name: 'Dae',
          account_id: facebook_channel.inbox.account_id,
          profile_pic: 'https://chatwoot-assets.local/sample.png'
        }.with_indifferent_access
      )

      echo_message_object = {
        messaging: {
          sender: { id: facebook_channel.page_id },
          recipient: { id: '3383290475046708' },
          message: { mid: 'm_echo_1', text: 'Echo testing', is_echo: true, app_id: '263902037430900' }
        }
      }.to_json
      echo_message = Integrations::Facebook::MessageParser.new(echo_message_object)

      described_class.new(echo_message, facebook_channel.inbox, outgoing_echo: true).perform

      message = facebook_channel.inbox.messages.find_by(source_id: 'm_echo_1')
      expect(message).to be_present
      expect(message.message_type).to eq('outgoing')
      expect(message.sender).to be_nil
      expect(message.status).to eq('delivered')
      expect(message.content_attributes['external_echo']).to be true
    end

    context 'when message contains a reel attachment' do
      let(:reel_message_object) do
        {
          messaging: {
            sender: { id: '3383290475046708' },
            recipient: { id: facebook_channel.page_id },
            timestamp: 1_772_452_164_516,
            message: {
              mid: 'm_reel_test',
              attachments: [
                {
                  type: 'reel',
                  payload: {
                    url: 'https://www.facebook.com/reel/123456',
                    title: 'Test Reel Title',
                    reel_video_id: 123_456
                  }
                }
              ]
            }
          }
        }.to_json
      end
      let(:reel_message) { Integrations::Facebook::MessageParser.new(reel_message_object) }

      before do
        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          { first_name: 'Jane', last_name: 'Dae', profile_pic: 'https://chatwoot-assets.local/sample.png' }.with_indifferent_access
        )
      end

      it 'creates an ig_reel attachment without downloading the file' do
        expect(Down).not_to receive(:download)
        described_class.new(reel_message, facebook_channel.inbox).perform

        message = facebook_channel.inbox.messages.find_by(source_id: 'm_reel_test')
        expect(message).to be_present
        expect(message.attachments.first.file_type).to eq('ig_reel')
        expect(message.attachments.first.external_url).to eq('https://www.facebook.com/reel/123456')
        expect(message.attachments.first.file.attached?).to be false
      end

      it 'sets the reel URL as message content' do
        described_class.new(reel_message, facebook_channel.inbox).perform

        message = facebook_channel.inbox.messages.find_by(source_id: 'm_reel_test')
        expect(message.content).to eq('https://www.facebook.com/reel/123456')
      end
    end

    context 'when message contains a sticker attachment' do
      let(:sticker_url) { 'https://scontent.xx.fbcdn.net/sticker.png' }
      let(:sticker_message_object) do
        {
          messaging: {
            sender: { id: '3383290475046708' },
            recipient: { id: facebook_channel.page_id },
            timestamp: 1_772_452_164_516,
            message: {
              mid: 'm_sticker_test',
              attachments: [
                { type: 'image', payload: { url: sticker_url } },
                { type: 'sticker', payload: { url: sticker_url } }
              ]
            }
          }
        }.to_json
      end
      let(:sticker_message) { Integrations::Facebook::MessageParser.new(sticker_message_object) }

      before do
        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          { first_name: 'Jane', last_name: 'Dae', profile_pic: 'https://chatwoot-assets.local/sample.png' }.with_indifferent_access
        )
        stub_request(:get, sticker_url).to_return(status: 200, body: 'sticker_data', headers: { 'Content-Type' => 'image/png' })
      end

      it 'stores the sticker as a single image attachment' do
        described_class.new(sticker_message, facebook_channel.inbox).perform

        message = facebook_channel.inbox.messages.find_by(source_id: 'm_sticker_test')
        expect(message.attachments.count).to eq(1)
        expect(message.attachments.first.file_type).to eq('image')
        expect(message.attachments.first.external_url).to eq(sticker_url)
      end

      it 'keeps duplicate non-sticker attachments that share a URL' do
        duplicate_image_object = {
          messaging: {
            sender: { id: '3383290475046708' },
            recipient: { id: facebook_channel.page_id },
            message: {
              mid: 'm_duplicate_image_test',
              attachments: [
                { type: 'image', payload: { url: sticker_url } },
                { type: 'image', payload: { url: sticker_url } }
              ]
            }
          }
        }.to_json
        duplicate_image_message = Integrations::Facebook::MessageParser.new(duplicate_image_object)

        described_class.new(duplicate_image_message, facebook_channel.inbox).perform

        message = facebook_channel.inbox.messages.find_by(source_id: 'm_duplicate_image_test')
        expect(message.attachments.count).to eq(2)
      end
    end

    [
      {
        source_id: 'm_fallback_test',
        attachment: { type: 'fallback', title: 'Shared link', url: 'https://www.example.com/shared-link' },
        title: 'Shared link',
        url: 'https://www.example.com/shared-link'
      },
      {
        source_id: 'm_share_test',
        attachment: { type: 'share', title: 'Shared Facebook post', payload: { url: 'https://www.facebook.com/example/posts/123' } },
        title: 'Shared Facebook post',
        url: 'https://www.facebook.com/example/posts/123'
      },
      {
        source_id: 'm_post_test',
        attachment: { type: 'post', payload: { title: 'Shared post caption', url: 'https://www.facebook.com/example/posts/456' } },
        title: 'Shared post caption',
        url: 'https://www.facebook.com/example/posts/456'
      }
    ].each do |message_data|
      it "stores #{message_data[:attachment][:type]} attachments as fallback links" do
        allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
        allow(fb_object).to receive(:get_object).and_return(
          { first_name: 'Jane', last_name: 'Dae', profile_pic: 'https://chatwoot-assets.local/sample.png' }.with_indifferent_access
        )
        expect(Down).not_to receive(:download)

        message_object = {
          messaging: {
            sender: { id: '3383290475046708' },
            recipient: { id: facebook_channel.page_id },
            message: { mid: message_data[:source_id], attachments: [message_data[:attachment]] }
          }
        }.to_json
        message = Integrations::Facebook::MessageParser.new(message_object)

        described_class.new(message, facebook_channel.inbox).perform

        attachment = facebook_channel.inbox.messages.find_by(source_id: message_data[:source_id]).attachments.first
        expect(attachment.file_type).to eq('fallback')
        expect(attachment.fallback_title).to eq(message_data[:title])
        expect(attachment.external_url).to eq(message_data[:url])
      end
    end

    context 'when lock to single conversation' do
      subject(:mocked_message_builder) do
        described_class.new(mocked_incoming_fb_text_message, facebook_channel.inbox).perform
      end

      let!(:mocked_message_object) { build(:mocked_message_text, sender_id: contact_inbox.source_id).to_json }
      let!(:mocked_incoming_fb_text_message) { Integrations::Facebook::MessageParser.new(mocked_message_object) }
      let(:contact) { create(:contact, name: 'Jane Dae') }
      let(:contact_inbox) { create(:contact_inbox, contact_id: contact.id, inbox_id: facebook_channel.inbox.id) }

      context 'when lock to single conversation is disabled' do
        before do
          facebook_channel.inbox.update!(lock_to_single_conversation: false)
          stub_request(:get, /graph.facebook.com/)
        end

        it 'creates a new conversation if existing conversation is not present' do
          inital_count = Conversation.count

          mocked_message_builder

          facebook_channel.inbox.reload

          expect(facebook_channel.inbox.conversations.count).to eq(1)
          expect(Conversation.count).to eq(inital_count + 1)
        end

        it 'will not create a new conversation if last conversation is not resolved' do
          existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id, inbox_id: facebook_channel.inbox.id,
                                                        contact_id: contact.id, contact_inbox_id: contact_inbox.id,
                                                        status: :open)

          mocked_message_builder

          facebook_channel.inbox.reload

          expect(facebook_channel.inbox.conversations.last.id).to eq(existing_conversation.id)
        end

        it 'creates a new conversation if last conversation is resolved' do
          existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id, inbox_id: facebook_channel.inbox.id,
                                                        contact_id: contact.id, contact_inbox_id: contact_inbox.id, status: :resolved)

          inital_count = Conversation.count

          mocked_message_builder

          facebook_channel.inbox.reload

          expect(facebook_channel.inbox.conversations.last.id).not_to eq(existing_conversation.id)
          expect(Conversation.count).to eq(inital_count + 1)
        end
      end

      context 'when lock to single conversation is enabled' do
        before do
          facebook_channel.inbox.update!(lock_to_single_conversation: true)
          stub_request(:get, /graph.facebook.com/)
        end

        it 'creates a new conversation if existing conversation is not present' do
          inital_count = Conversation.count
          mocked_message_builder

          facebook_channel.inbox.reload

          expect(facebook_channel.inbox.conversations.count).to eq(1)
          expect(Conversation.count).to eq(inital_count + 1)
        end

        it 'reopens last conversation if last conversation exists' do
          existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id, inbox_id: facebook_channel.inbox.id,
                                                        contact_id: contact.id, contact_inbox_id: contact_inbox.id)

          inital_count = Conversation.count

          mocked_message_builder

          facebook_channel.inbox.reload

          expect(facebook_channel.inbox.conversations.last.id).to eq(existing_conversation.id)
          expect(Conversation.count).to eq(inital_count)
        end
      end
    end
  end
end
