# frozen_string_literal: true

class ErrorsController < ApplicationController
  layout "page"

  def not_found
    render status: 404
  end

  def internal_server_error
    render status: 500
  end
end
