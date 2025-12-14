# frozen_string_literal: true

# Pagy configuration
require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:overflow] = :last_page
