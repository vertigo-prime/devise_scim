# frozen_string_literal: true

require "json"

module DeviseScim
  module Scim
    LIST_RESPONSE_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:ListResponse"

    class ListResponse
      def initialize(resources:, total_results: nil, start_index: 1, items_per_page: 100)
        @resources     = resources
        @total_results = total_results || resources.size
        @start_index   = start_index
        @items_per_page = items_per_page
      end

      def to_h
        {
          "schemas" => [LIST_RESPONSE_SCHEMA],
          "totalResults" => @total_results,
          "startIndex" => @start_index,
          "itemsPerPage" => @items_per_page,
          "Resources" => @resources.map { |r| r.respond_to?(:to_h) ? r.to_h : r }
        }
      end

      def to_json(*)
        to_h.to_json
      end
    end
  end
end
