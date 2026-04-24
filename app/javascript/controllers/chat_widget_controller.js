import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "launcher", "messages", "input", "submit"]
  static values = { history: Array, endpoint: String }

  connect() {
    this.opened = false
    this.renderHistory()
    this.resizeInput()
  }

  toggle() {
    this.opened ? this.close() : this.open()
  }

  open() {
    this.opened = true
    this.panelTarget.classList.add("is-open")
    this.launcherTarget.classList.add("is-hidden")
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.scrollToBottom()
    this.inputTarget.focus()
  }

  close() {
    this.opened = false
    this.panelTarget.classList.remove("is-open")
    this.launcherTarget.classList.remove("is-hidden")
    this.panelTarget.setAttribute("aria-hidden", "true")
  }

  async submit(event) {
    event.preventDefault()

    const query = this.inputTarget.value.trim()
    if (!query || this.submitTarget.disabled) return

    this.appendMessage("user", query)
    this.inputTarget.value = ""
    this.resizeInput()
    this.setBusy(true)

    const typingNode = this.appendTypingState()

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: JSON.stringify({ query })
      })

      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload.error || "Unable to send message")
      }

      typingNode.remove()
      this.appendMessage("assistant", payload.response, payload.products, payload.cache_hit)
    } catch (error) {
      typingNode.remove()
      this.appendMessage("assistant", error.message || "Something went wrong. Please try again.")
    } finally {
      this.setBusy(false)
    }
  }

  handleKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return

    event.preventDefault()
    this.submit(event)
  }

  resizeInput() {
    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = `${Math.min(this.inputTarget.scrollHeight, 140)}px`
  }

  renderHistory() {
    if (!this.hasHistoryValue || this.historyValue.length === 0) return

    this.messagesTarget.innerHTML = ""

    this.historyValue.forEach((entry) => {
      this.appendMessage(entry.role, entry.content)
    })
  }

  appendMessage(role, content, products = [], cacheHit = false) {
    const wrapper = document.createElement("article")
    wrapper.className = `chat-message chat-message-${role}`

    const avatar = document.createElement("div")
    avatar.className = "chat-avatar"
    avatar.textContent = role === "user" ? "You" : "AI"

    const bubble = document.createElement("div")
    bubble.className = "chat-bubble"

    const text = document.createElement("p")
    text.textContent = content
    bubble.appendChild(text)

    if (role === "assistant" && cacheHit) {
      const badge = document.createElement("span")
      badge.className = "chat-cache-badge"
      badge.textContent = "Instant answer"
      bubble.appendChild(badge)
    }

    if (role === "assistant" && products && products.length > 0) {
      bubble.appendChild(this.buildProducts(products))
    }

    if (role === "user") {
      wrapper.appendChild(bubble)
      wrapper.appendChild(avatar)
    } else {
      wrapper.appendChild(avatar)
      wrapper.appendChild(bubble)
    }

    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()

    return wrapper
  }

  appendTypingState() {
    const wrapper = document.createElement("article")
    wrapper.className = "chat-message chat-message-assistant chat-message-typing"
    wrapper.innerHTML = `
      <div class="chat-avatar">AI</div>
      <div class="chat-bubble">
        <div class="chat-typing-dots" aria-label="Assistant is typing">
          <span></span><span></span><span></span>
        </div>
      </div>
    `

    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
    return wrapper
  }

  buildProducts(products) {
    const grid = document.createElement("div")
    grid.className = "chat-product-grid"

    products.forEach((product) => {
      const card = document.createElement("section")
      card.className = "chat-product-card"
      card.innerHTML = `
        <h3>${this.escape(product.name || "Recommended product")}</h3>
        <p>${this.escape(product.description || "Product details available in chat.")}</p>
        <dl>
          <div><dt>Brand</dt><dd>${this.escape(product.brand || "N/A")}</dd></div>
          <div><dt>Category</dt><dd>${this.escape(product.category || "N/A")}</dd></div>
          <div><dt>Price</dt><dd>${this.escape(product.price || "N/A")}</dd></div>
        </dl>
      `
      grid.appendChild(card)
    })

    return grid
  }

  setBusy(state) {
    this.submitTarget.disabled = state
    this.inputTarget.disabled = state
    this.submitTarget.textContent = state ? "Thinking..." : "Send"
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  escape(value) {
    const node = document.createElement("div")
    node.textContent = `${value}`
    return node.innerHTML
  }
}
