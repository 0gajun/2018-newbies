# frozen_string_literal: true

class Api::ChargesController < Api::ApplicationController
  def index
    charge_total = 0
    current_user.charges.each do |charge|
      charge_total += charge.amount
    end
    remit_total = 0
    current_user.received_remit_requests.where.not(accepted_at: nil).each do |remit|
      remit_total += remit.amount
    end
    current_user.sent_remit_requests.where.not(accepted_at: nil).each do |remit|
      remit_total -= remit.amount
    end
    balance_total = charge_total - remit_total

    @charges = current_user.charges.order(id: :desc).limit(50)

    render json: { amount: balance_total, charges: @charges }
  end

  def create
    ActiveRecord::Base.transaction do
      @charge = current_user.create_charge!(amount: params[:amount])
      ChargeJob.perform_later(@charge)
      render json: @charge, status: :created
    end
  end
end
