# frozen_string_literal: true

class RemitRequest < ApplicationRecord
  belongs_to :user
  belongs_to :target, class_name: 'User'

  validates :user_id, presence: true
  validates :target_id, presence: true
  validates :amount, numericality: { greater_than: 0 }

  validate :user_id_and_target_id_should_not_be_same
  validate :multiple_statuses_should_not_exist


  scope :outstanding, ->(at = Time.current) { not_accepted(at).not_rejected(at).not_canceled(at) }
  scope :accepted, ->(at = Time.current) { where(RemitRequest.arel_table[:accepted_at].lteq(at)) }
  scope :not_accepted, ->(at = Time.current) { where(accepted_at: nil).or(where(RemitRequest.arel_table[:accepted_at].gt(at))) }
  scope :rejected, ->(at = Time.current) { where(RemitRequest.arel_table[:rejected_at].lteq(at)) }
  scope :not_rejected, ->(at = Time.current) { where(rejected_at: nil).or(where(RemitRequest.arel_table[:rejected_at].gt(at))) }
  scope :canceled, ->(at = Time.current) { where(RemitRequest.arel_table[:canceled_at].lteq(at)) }
  scope :not_canceled, ->(at = Time.current) { where(canceled_at: nil).or(where(RemitRequest.arel_table[:canceled_at].gt(at))) }

  def outstanding?(at = Time.current)
    !accepted?(at) && !rejected?(at) && !canceled?(at)
  end

  def accepted?(at = Time.current)
    accepted_at && accepted_at <= at
  end

  def rejected?(at = Time.current)
    rejected_at && rejected_at <= at
  end

  def canceled?(at = Time.current)
    canceled_at && canceled_at <= at
  end

  private
    def multiple_statuses_should_not_exist
      if [accepted_at?, rejected_at?, canceled_at?].count(true) > 1
        errors.add(:accepted_at?, "RemitRequest cannot have multiple statuses")
        errors.add(:rejected_at?, "RemitRequest cannot have multiple statuses")
        errors.add(:canceled_at?, "RemitRequest cannot have multiple statuses")
      end
    end

    def user_id_and_target_id_should_not_be_same
      if user_id == target_id
        errors.add(:user_id, "User id and target id shouldn't be same")
        errors.add(:target_id, "User id and target id shouldn't be same")
      end
    end
end
