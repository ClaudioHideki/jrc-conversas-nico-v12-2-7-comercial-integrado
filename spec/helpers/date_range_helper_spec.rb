require 'rails_helper'

RSpec.describe DateRangeHelper, type: :helper do
  describe '#parse_date_time' do
    it 'keeps DateTime values unchanged' do
      datetime = DateTime.current

      expect(helper.parse_date_time(datetime)).to eq(datetime)
    end

    it 'converts Time values to DateTime' do
      time = Time.current

      expect(helper.parse_date_time(time)).to eq(time.to_datetime)
    end

    it 'converts Date values to DateTime' do
      date = Date.current

      expect(helper.parse_date_time(date)).to eq(date.to_datetime)
    end

    it 'accepts integer unix timestamps' do
      timestamp = Time.zone.local(2026, 8, 20, 12, 0, 0).to_i

      expect(helper.parse_date_time(timestamp).to_i).to eq(timestamp)
    end
  end
end
