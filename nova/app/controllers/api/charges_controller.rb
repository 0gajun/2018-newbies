# frozen_string_literal: true

class Api::ChargesController < Api::ApplicationController
  def index
    @charges = current_user.charge

    render json: { charges: @charges }
  end

  def create
    ActiveRecord::Base.transaction do
      @charge = current_user.create_charge!(amount: params[:amount])
      ChargeJob.perform_later(@charge)
      render json: @charge, status: :created
    end
  end
end
