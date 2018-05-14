# frozen_string_literal: true

class RemitRequest < ApplicationRecord
  belongs_to :user
  belongs_to :requested_user, class_name: 'User'

  validates :user_id, presence: true
  validates :requested_user_id, presence: true
  validates :amount, presence: true, numericality: { only_integer: true,
                                                     greater_than_or_equal_to: Constants::MIN_REMIT_AMOUNT,
                                                     less_than_or_equal_to: Constants::MAX_REMIT_AMOUNT, }

  validate :requested_user_should_be_different

  def accept!
    RemitService.execute!(self)
  end

  def reject!
    ActiveRecord::Base.transaction do
      RemitRequestResult.create_from_remit_request!(self, RemitRequestResult::RESULT_REJECTED)
      destroy!
    end
  end

  def cancel!
    RemitRequestResult.create_from_remit_request!(self, RemitRequestResult::RESULT_CANCELED)
    destroy!
  end

  private

  def requested_user_should_be_different
    return if user != requested_user

    errors.add(:requested_user, 'Cannot request a remit to yourself')
  end
end
