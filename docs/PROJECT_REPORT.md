# SmartChatBot Project Report

## 1. Project Summary

SmartChatBot is a Rails 8 application that implements an e-commerce chatbot with retrieval-augmented generation (RAG), semantic product search, query caching, and session-based conversation memory.

The project is designed to:

- accept a user question from a web chat widget
- convert the question into an embedding
- check whether a similar question has already been answered
- retrieve relevant products from a vector-enabled PostgreSQL database
- send the question plus product context to a large language model
- return a conversational response and product recommendations
- save the answer for future cache hits

At a high level, this is a Rails-based AI assistant for product discovery and customer support.

## 2. Main Business Goal

The purpose of the application is to help users ask natural language product questions such as:

- "Which phone has the best camera under 20,000?"
- "How many products do I have?"
- "Recommend a laptop for office work"
- "Show me budget headphones"

Instead of building a traditional search form with filters, the application lets the customer interact through a chatbot-style interface.

## 3. Technology Stack

### Backend

- Ruby on Rails `8.1.3`
- PostgreSQL
- `pgvector` extension for vector storage and similarity search
- `neighbor` gem for nearest-neighbor vector queries
- `faraday` for external HTTP requests
- `dotenv-rails` for loading environment variables from `.env`

### AI / Retrieval

- Hugging Face Inference Router for:
  - embeddings
  - chat completions
- Sentence-transformers embedding model:
  - `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`
- Chat completion model:
  - `openai/gpt-oss-120b:groq`

### Frontend

- Rails views with ERB
- Stimulus for interaction logic
- Importmap for JavaScript loading
- Custom CSS for the floating chat widget UI

### Supporting Gems

- `langchainrb` for CSV/document loading
- `sidekiq`, `redis`, `solid_queue`, `solid_cache`, `solid_cable` are present, although the current chat flow is still synchronous
- `devise` is installed but not yet used in the visible app flow

## 4. Current Application Structure

### Controllers

- [app/controllers/chat_controller.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/controllers/chat_controller.rb:1)
  - `index` renders the chat page and loads message history for the current session
  - `message` receives a user query, runs the cache/RAG/LLM pipeline, and returns JSON

### Models

- [app/models/product.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/models/product.rb:1)
  - stores product data and a vector embedding
  - supports semantic nearest-neighbor search

- [app/models/cached_query.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/models/cached_query.rb:1)
  - stores previous user questions, their embeddings, AI responses, related product IDs, and cache hit count
  - supports semantic cache lookup

- [app/models/message.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/models/message.rb:1)
  - stores chat history by `session_id`
  - used to provide conversational context to the LLM

### Services

- [app/services/ai/embedding_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/embedding_service.rb:1)
  - sends text to Hugging Face
  - returns a normalized embedding vector
  - validates API key presence and upstream response shape

- [app/services/ai/query_cache_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/query_cache_service.rb:1)
  - checks whether a semantically similar query already exists
  - saves new query/response pairs for future cache hits

- [app/services/ai/rag_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/rag_service.rb:1)
  - retrieves the nearest products by embedding similarity

- [app/services/ai/chat_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/chat_service.rb:1)
  - builds the prompt
  - includes conversation history and product context
  - sends a chat completion request
  - normalizes the model output into a plain string
  - saves chat messages into the database

- [app/services/ai/product_loader_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/product_loader_service.rb:1)
  - loads products from CSV
  - generates embeddings for each product
  - stores them in the `products` table

### Views / Frontend

- [app/views/chat/index.html.erb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/views/chat/index.html.erb:1)
  - renders a landing page plus floating chatbot widget

- [app/javascript/controllers/chat_widget_controller.js](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/javascript/controllers/chat_widget_controller.js:1)
  - handles open/close behavior
  - submits chat messages via AJAX
  - renders bot responses and product cards
  - shows typing state

- [app/assets/stylesheets/application.css](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/assets/stylesheets/application.css:1)
  - defines the complete chatbot visual system and layout

### Configuration

- [config/routes.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/config/routes.rb:1)
  - `root "chat#index"`
  - `post "/chat/message", to: "chat#message"`

- [config/application.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/config/application.rb:1)
  - explicitly autoloads `app/services`

## 5. Database Design

The database uses PostgreSQL with `pgvector`.

### `products`

Stores product catalog data.

Fields:

- `name`
- `description`
- `price`
- `category`
- `brand`
- `specifications` (`jsonb`)
- `stock`
- `embedding` (`vector(384)`)

Purpose:

- supports semantic product search using nearest-neighbor similarity

### `cached_queries`

Stores semantic cache entries for previous chatbot requests.

Fields:

- `query_text`
- `query_embedding` (`vector(384)`)
- `ai_response`
- `product_ids` (`integer[]`)
- `hit_count`

Purpose:

- avoids repeating expensive LLM calls for semantically similar questions

### `messages`

Stores per-session conversation history.

Fields:

- `session_id`
- `role`
- `content`

Purpose:

- preserves short-term chat memory
- gives the LLM recent context

## 6. End-to-End Request Flow

When a user sends a message, the system works like this:

1. The browser sends a `POST /chat/message` request.
2. `ChatController#message` reads the `query`.
3. `Ai::QueryCacheService` generates an embedding for the query.
4. The app searches `cached_queries` for the nearest semantically similar question.
5. If a close match is found:
   - the cached response is returned immediately
   - `hit_count` is incremented
6. If no cache match is found:
   - `Ai::RagService` retrieves the nearest products from the `products` table
   - `Ai::ChatService` builds a system prompt plus product context plus recent chat history
   - the prompt is sent to Hugging Face chat completions
   - the response is normalized into a string
   - the new query and answer are stored in `cached_queries`
   - the user and assistant messages are stored in `messages`
7. The frontend renders:
   - assistant text
   - optional product cards
   - cache indicator if the answer came from the semantic cache

## 7. RAG and Cache Strategy

This project uses two separate vector use cases:

### Product Retrieval

The app embeds each product and stores it in `products.embedding`. When a user asks a question, the query embedding is compared against product embeddings to find the most relevant products.

This is the RAG part of the system.

### Query Cache

The app also embeds the user’s question and compares it against earlier user questions stored in `cached_queries.query_embedding`.

If a similar query already exists, the app can skip product retrieval and skip the LLM call entirely.

This makes the system faster and cheaper.

## 8. Frontend Experience

The UI is designed to look like a real website chat assistant.

Key UI behaviors:

- floating launcher button at bottom-right
- slide-up chat window
- preloaded chat history on page load
- auto-resizing input box
- Enter-to-send
- typing animation while waiting
- recommended product cards in responses
- mobile-friendly responsive layout

This gives the app a more production-like feel than a plain textarea form.

## 9. External Dependencies and Environment

The app depends on:

- PostgreSQL with `pgvector` installed and enabled
- Hugging Face API key in `.env`
- Rails server with `.env` loaded through `dotenv-rails`

Important environment variable:

- `HUGGINGFACE_API_KEY`

Without it, the embedding and chat services fail.

## 10. Current Strengths

- Clean separation of responsibilities using service objects
- Real vector search using PostgreSQL + pgvector
- Semantic cache reduces repeated LLM cost
- Conversation memory is persisted by session
- Frontend widget is substantially better than a basic demo UI
- Error handling for embedding/chat failures is better than raw crash behavior
- Autoloading for service objects has been configured

## 11. Current Weaknesses / Risks

### 1. Synchronous AI requests

The chat request currently runs embeddings, cache lookup, retrieval, and LLM calls inside the web request cycle. This can make responses slow and ties performance directly to external API latency.

### 2. Product loader path bug

[app/services/ai/product_loader_service.rb](/home/startbit/Desktop/ALL%20My%20Data%20Store/AI%20learning/smartchatbot/app/services/ai/product_loader_service.rb:4) ignores the `csv_path` argument and hardcodes `./products_export_1.csv`. That reduces flexibility and can break execution depending on working directory.

### 3. Minimal validation / normalization around domain data

Product import logic is still loose. Price, stock, and specifications parsing are basic and not strongly validated.

### 4. Limited observability

The app has basic logs, but no explicit telemetry, request tracing, or structured monitoring for AI failures, cache hit rates, or provider errors.

### 5. Prompt and model coupling

The project currently hardcodes the prompt and Hugging Face model/provider in the code. This makes experimentation possible, but operational flexibility is limited.

### 6. Tests are missing

No meaningful automated tests are present yet for:

- controller request flow
- service objects
- vector search behavior
- chat parsing behavior
- CSV import behavior

### 7. Some unused or partially integrated dependencies

The repo includes gems such as `devise`, `sidekiq`, `solid_queue`, `solid_cache`, and `solid_cable`, but the visible core flow does not fully use them yet.

## 12. Suggested Improvements

### Short Term

- add request specs for `POST /chat/message`
- add unit tests for `EmbeddingService`, `ChatService`, `QueryCacheService`, and `CachedQuery.find_similar`
- fix `ProductLoaderService` to respect the provided CSV path
- improve error messages shown in the frontend
- add a fallback response when no products are available

### Medium Term

- move slow AI work to background jobs
- track cache hit ratio and average response time
- support configurable model/provider via environment variables
- improve CSV ingestion and structured product parsing
- add authentication/admin tools for product management

### Longer Term

- add multi-tenant or merchant-specific product catalogs
- introduce analytics dashboards
- allow richer citations/explanations for recommendations
- support multilingual UI text, not just multilingual AI responses

## 13. How to Explain This Project to Others

Use this short explanation:

> SmartChatBot is a Rails-based AI shopping assistant. It uses vector embeddings and PostgreSQL pgvector to understand both user questions and product data semantically. When a user asks a question, the system first checks whether a similar question was answered before. If not, it retrieves relevant products using vector similarity, sends the question plus product context to an LLM, and returns a natural-language answer. It also stores chat memory and cached answers so the system becomes faster over time.

## 14. Simple Architecture Explanation

You can describe the architecture in one line like this:

> UI chat widget -> Rails controller -> embedding service -> semantic cache -> vector product retrieval -> LLM response -> cache + message persistence -> JSON response back to UI

## 15. Demo Talking Points

If you need to present the project live, focus on these points:

- It is not a static chatbot. It uses real retrieval from a product database.
- It supports semantic understanding, not just keyword matching.
- It uses caching to reduce repeated AI cost.
- It preserves conversation context using session history.
- The interface behaves like a real website support widget.
- The system is modular, so embeddings, retrieval, and chat can evolve independently.

## 16. Current State Summary

The project already demonstrates the core AI commerce assistant pattern:

- product ingestion
- vector search
- retrieval-augmented generation
- semantic caching
- session memory
- responsive chatbot UI

It is a solid prototype / early application architecture. The main work remaining is production hardening: testing, reliability, configuration cleanup, background processing, and better operational controls.
