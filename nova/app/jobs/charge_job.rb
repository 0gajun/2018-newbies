class ChargeJob < ApplicationJob
  queue_as :default

  around_perform do |job, block|
    # 実行前に行なう作業
    block.call
    # 実行後に行なう作業
    # DBへのトランザクション処理がここに入る？
  end

  def perform(charge)
    #charge objectを受ける方が良いかも
    @capture_response = Stripe::Charge.retrieve(charge.stripe_id).capture
    Rails.logger.info('[DEBUG] got response')
  rescue Stripe::StripeError => e
    errors.add(:user, e.code.to_s.to_sym)
    throw :abort
  end

  def execute!(charge) 
    ActiveRecord::Base.transaction do
      user_balance = charge.user.balance

      aquire_lock!(user_balance)

      increase_balance!(user_balance, charge.amount)

      release_lock!(user_balance)
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
