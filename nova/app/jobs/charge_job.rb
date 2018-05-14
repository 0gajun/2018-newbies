class ChargeJob < ApplicationJob
  queue_as :default

  def perform(charge)
    capture_response = Stripe::Charge.retrieve(charge.stripe_id).capture
    execute!(charge, 'charged')
  rescue Stripe::CardError => e
    # Since it's a decline, Stripe::CardError will be caught
    execute!(charge, 'faild')
  rescue => e
    errors.add(:user, e.code.to_s.to_sym)
    throw :abort
  end

  def execute!(charge, result) 
    ActiveRecord::Base.transaction do
      if charge.present?
        user_balance = charge.user.balance
      else
        return
      end

      aquire_lock!(user_balance)

      increase_balance!(user_balance, charge.amount)

      release_lock!(user_balance)

      #add charge_history into charge_history table
      ChargeHistory.create!(amount: charge.amount, stripe_id: charge.stripe_id, result: result, user_id: charge.user_id)

      #delete charge clomun 
      charge.destroy!
    end
  end

  def increase_balance!(user_balance, amount)
    user_balance.deposit!(amount)
  end

  # balanceの整合性を担保するため悲観的行ロックを獲得する
  def aquire_lock!(balance)
    balance.lock!
  end

  # balanceの整合性を担保するため悲観的行ロックを開放する
  def release_lock!(balance)
    balance.save!
  end
end
