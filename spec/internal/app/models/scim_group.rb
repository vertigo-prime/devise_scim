# frozen_string_literal: true

class ScimGroup < ActiveRecord::Base
  include DeviseScim::Concerns::ScimGroupIdentifiable
end
