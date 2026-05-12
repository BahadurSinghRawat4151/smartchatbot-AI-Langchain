# Proof of Concept (POC)

## Project Overview
SmartChatBot is an AI shopping assistant built for an ecommerce flow. The chatbot helps users search products, understand product details, navigate collections, manage cart items, start checkout, ask policy questions, and check order status through natural language prompts.

The POC combines a Rails ecommerce application with an LLM-powered agent, retrieval-augmented product search, policy search, user memory, and tool execution. It is designed to make shopping easier by allowing users to ask normal questions instead of manually browsing every page.

## Tech Stack
- **Language**: Ruby
- **Framework**: Ruby on Rails 8.1.3
- **Frontend**: rails erb ,css,js
- **Database**: PostgreSQL
- **Vector Search**: pgvector, neighbor gem, 384-dimensional embeddings
- **LLM Framework**: langchainrb
- **Chat LLM Provider**: Groq API through an OpenAI-compatible endpoint
- **Chat Model**: `openai/gpt-oss-120b`
- **LLM Client Gem**: `ruby-openai` through `Langchain::LLM::OpenAI`
- **Embedding Provider**: Hugging Face Inference Router
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2`
- **HTTP Client**: Faraday gem
- **Authentication**: Devise gem
- **Cart and Checkout**: Rails session cart with Stripe Checkout
- **Background Jobs**: Sidekiq, sidekiq-scheduler
- Gems related langchain integration : langchainrb,pgvector,hugging-face




## System Architecture
The application follows a Rails MVC architecture with a separate AI service layer under `app/services/ai`.

1. The user sends a message from the chat widget.
2. `ChatController` receives the query and creates an embedding using Hugging Face.
3. `IntentClassifierService` classifies the query as general query(like greetings,offtopics etc) product search, cart, checkout, policy, navigation, order status, general, or off-topic.
4. Product and policy queries use RAG services to retrieve relevant records from PostgreSQL using pgvector similarity search.
5. Agent-based actions use `Ai::AgentService`, `Ai::Agent`, `Ai::AgentExecutor`, and `Ai::ToolRegistry`.
6. The LLM runs through LangChain Ruby with Groq's OpenAI-compatible API.
7. Redis stores active conversation memory and semantic cache data for faster repeated answers.
8. Rails returns a natural-language response plus optional UI actions such as navigation, add to cart, remove from cart, or checkout redirect.
9.- Multilingual response behavior, including various languagies inluding English, Hindi, and Hinglish-style , arabic,korien , russian etc queries.
- if user ask in any language it wll get its answer in their language like if user query in hindi  -> response is also in hindi

## AI Tools
The agent can call the following tools:
- `AddToCartTool`: Add a selected product to the cart.
- `RemoveFromCartTool`: Remove items from the cart.
- `GetCartItemsTool`: Show current cart items.
- `CheckoutTool`: Create a Stripe Checkout session.
- `ProductSearchTool`: Search products using product data and embeddings.
- `PolicyTool`: Answer return, refund, shipping, and store policy questions.
- `GoToCollectionTool`: Navigate to product collections.
- `GoToProductTool`: Navigate to a product page.
- `GoToCartTool`: Navigate to the cart page.
- `GoToHomeTool`: Navigate back to the home page.

## Key Features
- AI-powered shopping assistant named Nova.
- Product discovery through natural language search.
- Semantic product matching using embeddings and pgvector.
- Product detail answers for price, brand, description, images, stock, and specifications.
- Cart management through chat prompts.
- Stripe Checkout session creation from the chatbot flow.
- Policy question answering using policy chunks and vector search.
- Navigation commands for home, cart, products, and collections.
- User authentication and session handling with Devise.
- Active chat memory and semantic cache using Redis.
- Background conversation summarization through Sidekiq.
- Multilingual response behavior, including various languagies inluding English, Hindi, and Hinglish-style , arabic,korien , russian etc queries.
- if user ask in any language it wll get its answer in their language like if user query in hindi  -> response is also in hindi

## Proof of Concept Scope
This POC proves that a Rails ecommerce application can be connected with an LLM agent to support real shopping tasks. The current implementation focuses on product search, cart operations, checkout, policy responses, navigation, chat memory, and semantic retrieval.

The project is not only a generic chatbot. It is a task-oriented ecommerce assistant that can understand user intent, retrieve relevant store data, call backend tools, and return responses that help users continue shopping.

## Important Environment Variables
- `GROQ_API_KEY`: Required for chat completion with `openai/gpt-oss-120b`.
- `HUGGINGFACE_API_KEY`: Required for product, policy, memory, and query embeddings.
- Stripe credentials: Required for live checkout session creation.
- Redis configuration: Required for active memory, cache, and Sidekiq support.
