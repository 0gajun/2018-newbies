# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Charge, type: :model do
  context "when charge request" do
    let(:stripe_helper) { StripeMock.create_test_helper }
    before { StripeMock.start }
    after { StripeMock.stop }

    it "retrun error when without credit card" do
      user = User.create(nickname: 'foo', email: 'baz@foo.com', password: 'foobar', password_confirmation: 'foobar')
      StripeMock.prepare_card_error(:missing)
      expect { user.charges.create!(amount: 100) }.to raise_error { |e|
        expect(e).to be_a ActiveRecord::RecordNotSaved
        expect(e.message).to eq("Failed to save the record")
      }
    end

    it "get stripe_id" do
      user = User.create(nickname: 'foo', email: 'baz@foo.com', password: 'foobar', password_confirmation: 'foobar')
      charge = user.charges.create!(amount: 100)
      expect(charge.stripe_id).not_to eq nil
    end
  end
end


