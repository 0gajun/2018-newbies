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
          expect(e).to be_a ActiveRecord::RecordNotSaved
        end
      end
    end

    context "too much amount" do
      it "return error" do
        amount = 10_000_000
        if amount >= 10_000_000
          custom_error = ActiveRecord::RecordNotSaved.new("too much amount")
          StripeMock.prepare_error(custom_error, :new_charge)
          expect { user.charges.create!(amount: amount) }.to raise_error do |e|
            expect(e).to be_a ActiveRecord::RecordNotSaved
          end
        end
      end
    end
  end
end
