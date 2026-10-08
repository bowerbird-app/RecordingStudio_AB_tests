import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "results", "emptyState", "item"]

  connect() {
    this.lastSubmittedQuery = this.query
    this.filter()
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  filter(event) {
    const query = this.query
    let visibleCount = 0

    this.itemTargets.forEach((item) => {
      const searchText = item.dataset.searchText || ""
      const matches = query.length > 0 && searchText.includes(query)

      item.hidden = !matches

      if (matches) {
        visibleCount += 1
      }
    })

    if (this.hasResultsTarget) {
      this.resultsTarget.hidden = query.length === 0 || visibleCount === 0
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.hidden = query.length === 0 || visibleCount > 0
    }

    if (event?.type === "input" || event?.type === "search") {
      this.queueSearch(query)
    }
  }

  queueSearch(query) {
    if (!this.hasFormTarget) return

    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      if (query === this.lastSubmittedQuery) return

      this.lastSubmittedQuery = query
      this.formTarget.requestSubmit()
    }, 150)
  }

  get query() {
    return this.hasInputTarget ? this.inputTarget.value.trim().toLowerCase() : ""
  }
}