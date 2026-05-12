import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "launcher", "messages", "input", "submit"]
  static values = { history: Array, endpoint: String }

  connect() {
    this.opened = false
    console.log("History:", this.historyValue) 
    this.renderHistory()
    this.resizeInput()
  }

  renderProductCards(products) {
    const container = document.createElement("div")
    container.className = "product-grid"

    products.forEach(product => {
      const card = document.createElement("div")
      card.className = "product-card"

      card.innerHTML = `
        <img src="${product.image}" class="product-image" />
        <h3>${product.name}</h3>
        <p>${product.brand}</p>
        <p>₹${product.price}</p>
        <button data-id="${product.id}" class="add-to-cart-btn">
          Add to Cart
        </button>
      `

      container.appendChild(card)
    })

    this.messagesTarget.appendChild(container)
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

     
// alert(messagesTarget)
      typingNode.remove()
      // if (payload.checkout_url) {
      //   window.location.href = payload.checkout_url
      //   return
      // }

     if (payload.intent === "checkout") {
        await this.handleCheckout()
        return
      }

      // Handle navigation commands from the agent tools
      if (payload.navigation) {
        const targetUrl = payload.navigation.url || payload.navigation.path;
        if (targetUrl) {
          window.location.href = targetUrl;
          return;
        }
      }

      console.log("Received response:", payload.checkout_url); // Debug log for response payload
      

      // if (payload.products && payload.products.length > 0) {
      //   this.renderProductCards(payload.products)
      // }

      this.appendMessage("assistant", payload.response, payload.products, payload.cache_hit, payload.cart_url, payload.checkout_url)
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
   // Debug log for history value
  

  appendMessage(role, content, products = [], cacheHit = false,cartUrl = null,checkoutUrl = null) {
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

   // ✅ Buttons container
if (role === "assistant" && (cartUrl || checkoutUrl)) {
  const actions = document.createElement("div")
  actions.className = "chat-actions"
  actions.style.display = "grid"

  if (cartUrl) {
    const cartBtn = document.createElement("a")
    cartBtn.href = cartUrl
    cartBtn.style.marginTop = "1rem"
    cartBtn.style.background="pink"
    cartBtn.style.textAlign="center"
    cartBtn.style.border="none"
    cartBtn.style.textDecoration = "none"
    cartBtn.className = "view-cart-btn"
    cartBtn.textContent = "🛒 View Cart"
    actions.appendChild(cartBtn)
  }

  if (checkoutUrl) {
  const checkoutBtn = document.createElement("button")
  checkoutBtn.className = "checkout-btn"
  checkoutBtn.style.marginTop = "1rem"
  checkoutBtn.textContent = "🛍️ Checkout Now"

  checkoutBtn.onclick = this.handleCheckout.bind(this)

  actions.appendChild(checkoutBtn)
}


  bubble.appendChild(actions)
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

    products.forEach(product => {
      const card = document.createElement("section")
      card.className = "chat-product-card"
      console.log("Building product card for:", product) // Debug log for product data
     
        const imageUrl =
          product.image && product.image.length > 0
            ? product.image[0]   // first image
            : null
        console.log("Selected image URL:", imageUrl) // Debug log for selected image URL
        const imageHtml = imageUrl
          ? `<img src="${this.escape(imageUrl)}"
                alt="${this.escape(product.name || "Product")}"
                style="width: 100%; aspect-ratio: 6 / 4; object-fit: cover; border-radius: 4px; margin-bottom: 1rem;" />`
          : `<div style="width: 100%; aspect-ratio: 6 / 4; background: #f0f0f0; display: flex; align-items: center; justify-content: center; border-radius: 4px; margin-bottom: 1rem;">
              <img src="" style="width: 50px; height: 50px; opacity: 0.5;" />
            </div>`

      card.innerHTML = `
        ${imageHtml}
        <p><strong>${this.escape(product.name || "Unnamed Product")}</strong></p>
        <dl>
          <div><dt>Brand</dt><dd>${this.escape(product.brand || "N/A")}</dd></div>
          <div><dt>Category</dt><dd>${this.escape(product.category || "N/A")}</dd></div>
          <div><dt>Price</dt><dd>${this.escape(product.price || "N/A")}</dd></div>
          <div style="margin-top: 12px; display: flex; gap: 8px;">
            <button type="button" class="chat-product-btn" data-action="click->chat-widget#addToCart" data-product-id="${this.escape(product.id || product.product_id)}" style="flex: 1; padding: 6px 0; border: 1px solid #ccc; border-radius: 6px; cursor: pointer; background: #fff; font-size: 0.85rem;">Add to Cart</button>
            <a href="/products/${this.escape(product.id || product.product_id)}" class="chat-product-btn" style="flex: 1; padding: 6px 0; text-align: center; background: pink; border-radius: 6px; text-decoration: none; color: inherit; font-size: 0.85rem; border: 1px solid transparent; box-sizing: border-box;">View Details</a>
          </div>
        </dl>
      `

   
      grid.appendChild(card)
    })
    //  <p class="description">${this.escape(product.description || "Product details available in chat.")}</p>

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

  async handleCheckout() {
    try {
      const res = await fetch("/checkout", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        }
      })

      const data = await res.json()

      if (data.url) {
        window.location.href = data.url
      }
    } catch (e) {
      console.error(e)
      alert("Checkout failed")
    }
  }

  // async handleCart() {
   
  // }

  async addToCart(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const productId = btn.dataset.productId
    if (!productId) return

    btn.disabled = true
    const originalText = btn.textContent
    btn.textContent = "Adding..."

    try {
      const res = await fetch(`/cart/add_item?product_id=${productId}`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        }
      })

      if (res.ok) {
        btn.textContent = "Added!"
        setTimeout(() => { btn.textContent = originalText; btn.disabled = false }, 2000)
      } else {
        throw new Error("Failed to add to cart")
      }
    } catch (e) {
      console.error("Cart error:", e)
      btn.textContent = "Error"
      setTimeout(() => { btn.textContent = originalText; btn.disabled = false }, 2000)
    }
  }
}
