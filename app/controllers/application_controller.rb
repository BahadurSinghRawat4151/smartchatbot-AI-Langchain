class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!
  before_action :load_chat_history, if: :should_load_chat?
  helper_method :actor_id


  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def load_chat_history
    # redis_messages = Ai::UserMemoryService
    #   .new
    #   .get_active_conversation(actor_id)
    #   .map do |m|
    #     {
    #       role: m[:role],
    #       content: m[:content]
    #     }
    #   end
    #
    @messages ||= Ai::UserMemoryService
      .new
      .get_active_conversation(actor_id)

    # @messages = redis_messages
  end

def should_load_chat?
  user_signed_in? || session[:guest_id].present?
end

  private


  def current_or_guest_user
    current_user || guest_user
  end


  def actor_id
    @actor_id ||= begin
      if current_user
        "user:#{current_user.id}"
      else
        session[:guest_id] ||= SecureRandom.uuid
        "guest:#{session[:guest_id]}"
      end
    end
  end

  def guest_user_email
    # unique per browser (uses session internally, but you don't manage it)
    "guest_#{session.id}@example.com"
  end



  protected

  def after_sign_in_path_for(_resource)
    root_path
  end

  def after_sign_up_path_for(_resource)
    root_path
  end
end
