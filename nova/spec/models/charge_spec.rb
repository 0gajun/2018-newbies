# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Charge, type: :model do
  describe "#create_stripe_charge" do
    let(:user) { create(:user) }

    context "without credit card" do
      it "return error" do
        StripeMock.prepare_card_error(:missing)
        expect { user.charges.create!(amount: 100) }.to raise_error do |e|
          expect(e).to be_a ActiveRecord::RecordNotSaved
          expect(e.message).to eq("Failed to save the record")
        end
      end
    end

    context "with credit card" do
      it "get stripe_id" do
        charge = user.charges.create!(amount: 100)
        expect(charge.stripe_id).not_to eq nil
      end
    end

    context "minus amount" do
      it "return error" do
        expect { user.charges.create!(amount: -100) }.to raise_error do |e|
          expect(e).to be_a ActiveRecord::RecordInvalid
        end
      end
    end

    context "too much amount" do
      it "return error" do
        expect { user.charges.create!(amount: 100_000_000) }.to raise_error do |e|
          expect(e).to be_a ActiveRecord::RecordInvalid
        end
      end
    end
  end
end
