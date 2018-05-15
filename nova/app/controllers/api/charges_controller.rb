# frozen_string_literal: true

class Api::ChargesController < Api::ApplicationController
  def index
    charge_total = 0
    current_user.charges.each do |charge|
      charge_total += charge.amount
    end
    remit_total = 0
    current_user.received_remit_request_results.accepted.each do |remit|
      remit_total += remit.amount
    end
    current_user.sent_remit_request_results.accepted.each do |remit|
      remit_total -= remit.amount
    end
    balance_total = charge_total - remit_total

    @charges = current_user.charges.order(id: :desc).limit(50)

    render json: { amount: balance_total, charges: @charges }
  end

  def create
    @charge = current_user.charges.create(amount: params[:amount])
    if @charge.save
      render json: @charge, status: :created
    else
      render json: { errors: @charge.errors.messages }, status: :bad_request
    end
  end
end
