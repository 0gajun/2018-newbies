class Api::RemitRequestResultsController < ApplicationController
  def index
    @results = current_user.received_remit_request_results.limit(50)

    render json: @results.as_json(include: { user: { only: %i[nickname email] } },
                                  only: %i[amount created_at updated_at])
  end
end
