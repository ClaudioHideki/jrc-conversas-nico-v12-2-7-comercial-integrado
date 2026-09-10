module JrcCrm
  # CompanyAdapter allows the CRM module to work seamlessly with:
  # 1. Chatwoot Enterprise `Company` model (if available and licensed)
  # 2. Native `JrcCrm::Organization` model (independent standalone fallback)
  #
  # This guarantees zero hard dependency on Enterprise code and 100% redistribution safety.
  class CompanyAdapter
    def self.enterprise_company_available?(account)
      defined?(::Company) && account.respond_to?(:companies) && account.feature_enabled?('companies') rescue false
    end

    def self.find_or_create(account:, name:, attributes: {})
      if enterprise_company_available?(account)
        company = account.companies.find_or_initialize_by(name: name)
        company.assign_attributes(attributes.slice(:domain, :description, :phone_number, :website))
        company.save! if company.new_record? || company.changed?
        { type: :enterprise_company, record: company, id: company.id }
      else
        org = account.jrc_crm_organizations.find_or_initialize_by(name: name)
        org.assign_attributes(attributes.slice(:domain, :description, :phone, :website, :custom_attributes))
        org.save! if org.new_record? || org.changed?
        { type: :crm_organization, record: org, id: org.id }
      end
    end

    def self.resolve_entity(account:, organization_id: nil, company_id: nil)
      if organization_id.present?
        account.jrc_crm_organizations.find_by(id: organization_id)
      elsif company_id.present? && enterprise_company_available?(account)
        account.companies.find_by(id: company_id)
      else
        nil
      end
    end
  end
end
