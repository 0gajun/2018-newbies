# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true

  def after_sign_in_path_for(users)
    dashboard_path
  end
end
