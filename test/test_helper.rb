ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "solid_objects/test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    include SolidObjects::TestHelper
  end
end
