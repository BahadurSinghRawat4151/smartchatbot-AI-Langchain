class Ai::IntentClassifierService
  GENERAL_INTENTS = %i[general off_topic].freeze
  PRODUCT_INTENTS = %i[product ].freeze

  GREETING_PATTERNS = [
    /\A\s*(hi|hello|hey|namaste|salaam|hola|bonjour|hii|helo)\b/i,
    /\b(good morning|good afternoon|good evening|how are you)\b/i
  ].freeze

  OFF_TOPIC_PATTERNS = [
    /\b(weather|politics|movie|cricket score|football|recipe|homework|dating|joke)\b/i,
    /\b(write code|programming|debug|essay|poem|story)\b/i
  ].freeze

  POLICY_PATTERNS = [
    /\b(return|refund|replace|replacement|warranty|guarantee|shipping|delivery|policy|policies|exchange)\b/i,
    /\b(cancel|cancellation|damaged|defective|late delivery)\b/i
  ].freeze

  CART_PATTERNS = [
    /\b(cart|basket|bag|add to cart|remove from cart|my items|quantity|qty)\b/i
  ].freeze

  CHECKOUT_PATTERNS = [
    /\b(checkout|check out|payment|pay|stripe|buy now|place order|purchase)\b/i
  ].freeze

  ORDER_PATTERNS = [
    /\b(order status|track order|tracking|shipment|where is my order|invoice)\b/i
  ].freeze

  PRODUCT_PATTERNS = [
    /\b(product|products|recommend|suggest|show|find|search|price|cost|brand|category|stock|available|availability|share|give|want|need|looking for)\b/i,
    /\b(phone|laptop|shirt|shoe|watch|bag|headphone|camera|charger|dress)\b/i
  ].freeze

  NAVIGATION_PATTERNS = [
    /\b(collection|collections|navigate|go to|take me|back to|page|home|main)\b/i
  ].freeze

  ACTION_INTENTS = %i[navigation cart order_status home main].freeze

  POLICY_INTENTS = %i[policy].freeze




  def classify(query:, embedding: nil)
  normalized_query = query.to_s.strip

  # 🚀 EARLY EXIT (no DB hit)
  return build(:general, embedding) if greeting_or_simple?(normalized_query)

  return build(:off_topic, embedding) if off_topic?(normalized_query)
  return build(:order_status, embedding) if matches?(normalized_query, ORDER_PATTERNS)
  return build(:checkout, embedding) if matches?(normalized_query, CHECKOUT_PATTERNS)
  return build(:cart, embedding) if matches?(normalized_query, CART_PATTERNS)
  return build(:policy, embedding) if policy?(normalized_query)
  return build(:navigation, embedding) if navigation?(normalized_query)

  # 🚨 Only now hit DB
  product_terms = product_terms_for(normalized_query)

  intent =
    if product_terms.any? || matches?(normalized_query, PRODUCT_PATTERNS)
      :product
    else
      :general
    end

  build(intent, embedding, product_terms)
end

def route_for(intent)
  return :general if GENERAL_INTENTS.include?(intent)
  return :product if intent == :product
  return :action  if ACTION_INTENTS.include?(intent)
  return :policy if intent == :policy

  :general
end

  private

  def matches?(query, patterns)
    patterns.any? { |pattern| query.match?(pattern) }
  end

  def short_general_query?(query)
    query.split.size <= 3 && !query.match?(/\d/)
  end

  def greeting_or_simple?(query)
    matches?(query, GREETING_PATTERNS) || short_general_query?(query)
  end

  def off_topic?(query)
    matches?(query, OFF_TOPIC_PATTERNS)
  end
  def policy?(query)
    matches?(query, POLICY_PATTERNS)
  end
  def navigation?(query)
    matches?(query, NAVIGATION_PATTERNS)
  end



# def build(intent, embedding, product_terms = [])
#   {
#     intent: intent,
#     route: GENERAL_INTENTS.include?(intent) ? :general : :product,
#     product_terms: product_terms,
#     embedding_used: embedding.present?
#   }
# end

def build(intent, embedding, product_terms = [])
  {
    intent: intent,
    route: route_for(intent),
    product_terms: product_terms,
    embedding_used: embedding.present?
  }
end

  def product_terms_for(query)
    normalized_query = query.downcase

    terms = Rails.cache.fetch("product_terms_v1", expires_in: 12.hours) do
      Product
        .pluck(:name, :brand, :category, :product_type, :tags)
        .flatten
        .compact
        .map(&:downcase)
        .uniq
    end

    terms.select { |term| term.length >= 3 && normalized_query.include?(term) }
  end
end
