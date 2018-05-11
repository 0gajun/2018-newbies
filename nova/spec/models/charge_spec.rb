# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Charge, type: :model do
  context "when charge request" do
    it "get stripe_id" do
      user = User.create(nickname: 'foo', email: 'baz@foo.com', password: 'foobar', password_confirmation: 'foobar')
      charge = user.charges.create!(amount: 100)
      expect(charge.stripe_id).not_to eq nil
    end
  end
end


