# frozen_string_literal: true

class Api::BalancesController < Api::ApplicationController
  def show
    render json: current_user.balance.as_json(only: :amount)
  end
end
