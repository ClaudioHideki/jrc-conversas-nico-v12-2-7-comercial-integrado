require 'csv'

module JrcCrm
  class ImportProcessorService
    def initialize(import_batch:)
      @batch = import_batch
      @account = import_batch.account
    end

    def call
      parsed_csv = CSV.parse(@batch.file.download, headers: true)
      
      success_count = 0
      error_count = 0

      parsed_csv.each.with_index(2) do |row, line_number|
        begin
          if @batch.import_type == 'leads'
            process_lead_row(row)
          end
          success_count += 1
        rescue StandardError => e
          error_count += 1
          JrcCrm::ImportRowError.create!(
            import_batch_id: @batch.id,
            row_number: line_number,
            error_message: e.message,
            raw_data: row.to_h
          )
        end
      end

      @batch.update!(
        status: 'completed',
        success_count: success_count,
        error_count: error_count
      )
    end

    private

    def process_lead_row(row)
      email = row['email']&.strip&.downcase
      phone = normalize_phone(row['phone'])

      existing = JrcCrm::Lead.find_by(account_id: @account.id, email: email) if email.present?
      existing ||= JrcCrm::Lead.find_by(account_id: @account.id, phone: phone) if phone.present?

      if existing
        existing.update!(
          name: row['name'],
          company_name: row['company_name']
        )
      else
        JrcCrm::Lead.create!(
          account_id: @account.id,
          name: row['name'],
          email: email,
          phone: phone,
          company_name: row['company_name'],
          source: row['source'] || 'import',
          status: 'new'
        )
      end
    end

    def normalize_phone(phone)
      return nil if phone.blank?
      phone.to_s.gsub(/\D/, '')
    end
  end
end
