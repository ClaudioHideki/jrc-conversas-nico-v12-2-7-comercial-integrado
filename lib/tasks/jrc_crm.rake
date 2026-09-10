namespace :jrc_crm do
  desc 'Importa dados do módulo sales_* para o JRC CRM de forma idempotente (ACCOUNT_ID obrigatório)'
  task import_sales: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    account = Account.find(account_id)
    counts = JrcCrm::SalesImportService.new(account: account).perform
    puts counts.to_json
  end
end
