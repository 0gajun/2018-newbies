class ChargeJob < ApplicationJob
  queue_as :default

  def perform(charge)
    capture_response = Stripe::Charge.retrieve(charge.stripe_id).capture
    execute!(charge, 'charged')
  rescue Stripe::CardError => e
    # Since it's a decline, Stripe::CardError will be caught
    execute!(charge, 'faild')
  rescue => e
    body = e.json_body
    err  = body[:error]
    puts "Status is: #{e.http_status}"
    puts "Type is: #{err[:type]}"
    puts "Charge ID is: #{err[:charge]}"
    # The following fields are optional
    puts "Code is: #{err[:code]}" if err[:code]
    puts "Decline code is: #{err[:decline_code]}" if err[:decline_code]
    puts "Param is: #{err[:param]}" if err[:param]
    puts "Message is: #{err[:message]}" if err[:message]
    # automatical retry for sidekiq
    puts "-----"
    puts "Retry Job"
  end

  def execute!(charge, result) 
    ActiveRecord::Base.transaction do
      if charge.present?
        user_balance = charge.user.balance
      else
        return
      end
      # transactionが終了するとlockは解放される
      aquire_lock!(user_balance)

      increase_balance!(user_balance, charge.amount)

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

end
