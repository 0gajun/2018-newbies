# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RemitRequest, type: :model do
  subject(:remit_request) { build(:remit_request) }

  it { is_expected.to be_valid }

  statuses = %i[outstanding accepted rejected canceled]
  statuses.each do |status|
    context "with #{status}" do
      subject(:remit_request) { create(:remit_request, status) }

      it { is_expected.to send(:"be_#{status}") }
      it("should record of #{status} scope") { expect(RemitRequest.send(status)).to include(remit_request) }

      other_statuses = statuses.reject { |s| s == status }
      other_statuses.each do |other_status|
        it { is_expected.to_not send(:"be_#{other_status}") }
        it("should not record of #{other_status} scope") { expect(RemitRequest.send(other_status)).to_not include(remit_request) }
      end
    end
  end

  statuses = %i[accepted rejected canceled]
  statuses.combination(2).each do |status1, status2|
    context "with both #{status1} and #{status2}" do
      subject(:remit_request) { build_stubbed(:remit_request, status1, "#{status2}_at": Time.current) }
      it { is_expected.not_to be_valid }
    end
  end

  describe "amount validation" do
    context "with negative amount" do
      subject(:remit_request) { build_stubbed(:remit_request, amount: -1) }

      it { is_expected.not_to be_valid }
    end
  end

  describe "user_id validation" do
    context "with nil" do
      subject(:remit_request) { build_stubbed(:remit_request, user_id: nil) }

      it { is_expected.not_to be_valid }
    end
  end

  describe "target_id validation" do
    context "with nil" do
      subject(:remit_request) { build_stubbed(:remit_request, target_id: nil) }

      it { is_expected.not_to be_valid }
    end
  end

  describe "user_id and target_id validation" do
    context "when user_id and target_id are same" do
      let (:user) { create(:user) }
      subject(:remit_request) { build_stubbed(:remit_request, user_id: user.id, target_id: user.id) }

      it { is_expected.not_to be_valid }
    end
  end
end
