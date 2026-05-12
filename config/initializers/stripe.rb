# This forces Rails to load the Stripe library on boot
require "stripe"

# Stripe.api_key = ENV["STRIPE_SECRET_KEY"]


Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) ||
                 ENV["STRIPE_SECRET_KEY"]

Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, :publishable_key) ||
                   ENV["STRIPE_PUBLISHABLE_KEY"]
}
