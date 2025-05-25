# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module AttributeNormalizer
        # Normalise Issue attributes before they hit Jira’s REST API
        def normalize_issue_attrs(attrs)
          attrs = attrs.dup
          attrs[:summary] = attrs.delete(:title) if attrs.key?(:title)
          attrs
        end
      end
    end
  end
end
