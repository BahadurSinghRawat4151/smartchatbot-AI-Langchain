# class WebhooksController < ApplicationController
#   skip_before_action :verify_authenticity_token

#   def stripe
#     payload = request.body.read
#     sig_header = request.env['HTTP_STRIPE_SIGNATURE']
#     endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

#     event = Stripe::Webhook.construct_event(
#       payload, sig_header, endpoint_secret
#     )

#     case event.type
#     when 'checkout.session.completed'
#       session = event.data.object
#       # Update order / property / user here
#     end

#     render json: { status: 'success' }
#   rescue JSON::ParserError, Stripe::SignatureVerificationError
#     render json: { error: 'Invalid payload' }, status: 400
#   end
# end

class WebhooksController < ApplicationController
  # Stripe webhooks are server-to-server
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    # Verify webhook signature
    event = Stripe::Webhook.construct_event(
      payload,
      sig_header,
      endpoint_secret
    )

    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event.data.object)

    when 'checkout.session.expired'
      handle_checkout_expired(event.data.object)

    when 'payment_intent.payment_failed'
      handle_payment_failed(event.data.object)
    end

    render json: { status: 'success' }

  rescue JSON::ParserError
    render json: { error: 'Invalid payload' }, status: 400

  rescue Stripe::SignatureVerificationError
    render json: { error: 'Invalid signature' }, status: 400
  end

  private

  # ----------------------------
  # SUCCESSFUL PAYMENT
  # ----------------------------
  def handle_checkout_completed(session)
    return unless session.payment_status == 'paid'
    session = event.data.object
    book = Book.find_by(stripe_session_id: session.id)

    book.update!(status: 'sold')
   
    book.booking_items.destroy_all

    property_id = session.metadata.property_id
    user_id     = session.metadata.user_id

    property = Property.find_by(id: property_id, user_id: user_id)
    

    return unless property

    # Idempotent update (safe if webhook retries)
    property.update(is_featured: true)
  end

  # ----------------------------
  # USER CANCELLED / SESSION EXPIRED
  # ----------------------------
  def handle_checkout_expired(session)
    Rails.logger.info(
      "Stripe checkout expired: #{session.id}"
    )
    # No DB update needed
  end

  # ----------------------------
  # PAYMENT FAILED
  # ----------------------------
  def handle_payment_failed(payment_intent)
    Rails.logger.warn(
      "Stripe payment failed: #{payment_intent.id}"
    )
    # Optional: notify user, log, etc.
  end
end
